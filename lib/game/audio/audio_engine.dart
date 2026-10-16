import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Represents a background soundtrack item with instant-start bundled asset support.
class MusicTrack {
  final String title;
  final String assetPath;
  final double durationSeconds;

  const MusicTrack({
    required this.title,
    required this.assetPath,
    required this.durationSeconds,
  });
}

/// Centralized audio and haptics coordinator for basketball collisions,
/// net swishes, floor bounces, round-ending buzzers, and background music.
///
/// Powered by [SoLoud] (C++ and WASM multi-channel game audio mixer):
/// - Zero-allocation preloaded SFX in RAM ([LoadMode.memory]).
/// - Synchronous, zero-latency polyphonic collision sound triggers.
/// - Single unified native audio engine (zero Android MediaPlayer leaks).
/// - Jukebox background music streaming 10 MB compressed offline soundtrack.
class AudioEngine {
  static final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);
  static bool get isMuted => isMutedNotifier.value;
  static set isMuted(bool value) => isMutedNotifier.value = value;

  /// Volume scale for sound effects (0.0 to 1.0). Default 45%.
  static final ValueNotifier<double> sfxVolumeNotifier = ValueNotifier<double>(
    0.45,
  );
  static double get sfxVolume => sfxVolumeNotifier.value;
  static set sfxVolume(double value) =>
      sfxVolumeNotifier.value = value.clamp(0.0, 1.0);

  /// Volume scale for background music (0.0 to 1.0). Default 35%.
  static final ValueNotifier<double> musicVolumeNotifier =
      ValueNotifier<double>(0.35);
  static double get musicVolume => musicVolumeNotifier.value;
  static set musicVolume(double value) {
    musicVolumeNotifier.value = value.clamp(0.0, 1.0);
    _applyMusicVolume();
  }

  /// Toggles mute state and notifies all reactive UI listeners.
  static void toggleMute() {
    isMutedNotifier.value = !isMutedNotifier.value;
    if (isMutedNotifier.value) {
      _pauseMusic();
    } else {
      _resumeMusic();
    }
  }

  static bool _initialized = false;
  static bool _isInitializing = false;
  static Completer<void>? _initCompleter;

  // ── Monotonic stopwatch (zero-allocation rate-limiting) ──
  static final Stopwatch _clock = Stopwatch();
  static int _lastBounceUs = 0;
  static int _lastRimUs = 0;
  static int _lastBackboardUs = 0;

  // ── Pre-allocated SoLoud AudioSource references ──
  // Preloaded once into RAM for 0ms latency in-flight playback.
  static AudioSource? _rimSource;
  static AudioSource? _backboardSource;
  static AudioSource? _swishSource;
  static AudioSource? _bounceSource;
  static AudioSource? _buzzerSource;
  static AudioSource? _preloadedMusicSource;

  // ── Background Music (Single Looping Track: Back Outside - BNXN, Sarz) ──
  static final List<MusicTrack> _playlist = [
    const MusicTrack(
      title: 'Back Outside - BNXN, Sarz',
      assetPath: 'assets/music/short/BNXN, Sarz - Back Outside.mp3',
      durationSeconds: 39.0,
    ),
  ];

  static const double _crossfadeSeconds = 3.0;
  static int _currentTrackIndex = 0;
  static SoundHandle? _musicHandle;
  static AudioSource? _currentMusicSource;
  static SoundHandle? _incomingMusicHandle;
  static AudioSource? _incomingMusicSource;
  static Timer? _crossfadeTriggerTimer;
  static Timer? _crossfadeRampTimer;
  static double _crossfadeProgress = 0.0;
  static bool _musicStarted = false;
  static int _musicGen = 0;

  static bool _audioUnlocked = false;

  // ── Minimum impact velocity thresholds (m/s) ──
  static const double _minRimSpeed = 0.5;
  static const double _minBackboardSpeed = 0.5;
  static const double _minBounceSpeed = 0.3;

  /// Master volume scale for all sound effects (scaled to 60%).
  static const double masterVolume = 0.60;

  /// Preloads SoLoud engine, all SFX, and the initial music track into RAM for zero-latency startup playback.
  static Future<void> init() async {
    if (_initialized) return;
    if (_isInitializing) return _initCompleter?.future;
    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      _clock.reset();
      _clock.start();

      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }

      // Preload the 5 collision SFX into RAM (LoadMode.memory)
      final results = await Future.wait([
        SoLoud.instance.loadAsset(
          'assets/audio/rim_clank.wav',
          mode: LoadMode.memory,
        ),
        SoLoud.instance.loadAsset(
          'assets/audio/backboard.wav',
          mode: LoadMode.memory,
        ),
        SoLoud.instance.loadAsset(
          'assets/audio/swish.wav',
          mode: LoadMode.memory,
        ),
        SoLoud.instance.loadAsset(
          'assets/audio/bounce.wav',
          mode: LoadMode.memory,
        ),
        SoLoud.instance.loadAsset(
          'assets/audio/buzzer.wav',
          mode: LoadMode.memory,
        ),
      ]);

      _rimSource = results[0];
      _backboardSource = results[1];
      _swishSource = results[2];
      _bounceSource = results[3];
      _buzzerSource = results[4];

      // Pre-warm initial track into RAM during startup so the first touch/swipe has 0ms audio latency
      if (_playlist.isNotEmpty) {
        _currentTrackIndex = 0;
        final initialTrack = _playlist[0];
        try {
          _preloadedMusicSource = await SoLoud.instance.loadAsset(
            initialTrack.assetPath,
            mode: LoadMode.memory,
          );
          debugPrint(
            '[AudioEngine] 🎵 Pre-warmed initial track: ${initialTrack.title}',
          );
        } catch (e) {
          debugPrint('[AudioEngine] Music pre-warm notice: $e');
        }
      }

      _initialized = true;
      _initCompleter?.complete();
      debugPrint(
        '[AudioEngine] SoLoud engine initialized with preloaded SFX and music track.',
      );
    } catch (e) {
      _initCompleter?.completeError(e);
      debugPrint('[AudioEngine] SoLoud preload error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Unlocks Web Audio playback on iOS Safari / mobile browsers upon user touch.
  static void unlockAudio() {
    if (_audioUnlocked) return;
    if (!_initialized) {
      unawaited(
        init().then((_) {
          if (_initialized) unlockAudio();
        }),
      );
      return;
    }
    _audioUnlocked = true;

    if (!_musicStarted) {
      _startMusic();
    } else if (_musicHandle != null && !isMuted) {
      _resumeMusic();
    }
  }

  // ─────────────────────────── Background Music Jukebox (DJ Crossfade Engine) ───────────────────────────

  /// Starts the background music jukebox following the BPM-ordered sequence.
  static void _startMusic() {
    if (_playlist.isEmpty || !SoLoud.instance.isInitialized) return;
    _musicStarted = true;

    // Fast-path: If initial track (Champion) was pre-warmed during init, play immediately
    if (_preloadedMusicSource != null) {
      _currentTrackIndex = 0;
      _playCurrentTrack(usePreloaded: true);
      return;
    }

    _currentTrackIndex = 0;
    _playCurrentTrack();
  }

  /// Plays the track at [_currentTrackIndex], cleaning up previous tracks and scheduling crossfade.
  static Future<void> _playCurrentTrack({bool usePreloaded = false}) async {
    final gen = ++_musicGen;
    try {
      if (!SoLoud.instance.isInitialized) return;

      await _cleanupCurrentMusicTrack();

      if (_currentTrackIndex >= _playlist.length) {
        _currentTrackIndex = 0;
      }
      final track = _playlist[_currentTrackIndex];

      AudioSource? source;
      if (usePreloaded && _preloadedMusicSource != null) {
        source = _preloadedMusicSource;
        _preloadedMusicSource = null;
      } else {
        source = await SoLoud.instance.loadAsset(
          track.assetPath,
          mode: LoadMode.memory,
        );
      }

      if (gen != _musicGen || source == null) {
        if (source != null) unawaited(SoLoud.instance.disposeSource(source));
        return;
      }

      _currentMusicSource = source;
      final effectiveVolume = isMuted
          ? 0.0
          : (musicVolume * 0.6).clamp(0.0, 1.0);

      final isSingleTrack = _playlist.length <= 1;
      _musicHandle = SoLoud.instance.play(
        source,
        volume: effectiveVolume,
        looping: isSingleTrack,
      );

      debugPrint(
        '[AudioEngine] 🎵 Now playing: ${track.title}'
        '${isSingleTrack ? ' (Continuous Loop)' : ' (${_currentTrackIndex + 1}/${_playlist.length})'}',
      );

      if (!isSingleTrack) {
        _scheduleNextCrossfade(track, gen);
      }
    } catch (e) {
      debugPrint('[AudioEngine] Music playback error: $e');
      if (_audioUnlocked && _musicStarted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (gen == _musicGen) _onTrackComplete();
        });
      }
    }
  }

  /// Schedules the next track's crossfade [crossfadeSeconds] before the current track ends.
  static void _scheduleNextCrossfade(MusicTrack track, int gen) {
    _crossfadeTriggerTimer?.cancel();
    final delaySeconds = (track.durationSeconds - _crossfadeSeconds).clamp(1.0, 300.0);

    _crossfadeTriggerTimer = Timer(Duration(milliseconds: (delaySeconds * 1000).toInt()), () {
      if (gen != _musicGen || !_musicStarted) return;
      _startCrossfadeToNext(gen);
    });
  }

  /// Initiates the smooth 3-second equal-power DJ crossfade into the next BPM track.
  static Future<void> _startCrossfadeToNext(int gen) async {
    final nextIndex = (_currentTrackIndex + 1) % _playlist.length;
    final nextTrack = _playlist[nextIndex];

    try {
      final nextSource = await SoLoud.instance.loadAsset(
        nextTrack.assetPath,
        mode: LoadMode.memory,
      );

      if (gen != _musicGen || !_musicStarted) {
        unawaited(SoLoud.instance.disposeSource(nextSource));
        return;
      }

      _incomingMusicSource = nextSource;
      _incomingMusicHandle = SoLoud.instance.play(
        nextSource,
        volume: 0.0,
        looping: false,
      );

      _crossfadeProgress = 0.0;
      const stepMs = 50;
      final totalSteps = (_crossfadeSeconds * 1000) ~/ stepMs;
      int currentStep = 0;

      _crossfadeRampTimer?.cancel();
      _crossfadeRampTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
        if (gen != _musicGen) {
          timer.cancel();
          return;
        }

        currentStep++;
        _crossfadeProgress = (currentStep / totalSteps).clamp(0.0, 1.0);

        final baseVolume = isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);
        // Equal-power cosine curve prevents middle dip in perceived loudness
        final outVol = baseVolume * cos(_crossfadeProgress * pi / 2);
        final inVol = baseVolume * sin(_crossfadeProgress * pi / 2);

        if (_musicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          SoLoud.instance.setVolume(_musicHandle!, outVol);
        }
        if (_incomingMusicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_incomingMusicHandle!)) {
          SoLoud.instance.setVolume(_incomingMusicHandle!, inVol);
        }

        if (currentStep >= totalSteps) {
          timer.cancel();
          _finalizeCrossfade(nextIndex, gen);
        }
      });
    } catch (e) {
      debugPrint('[AudioEngine] Crossfade load error: $e');
      _onTrackComplete();
    }
  }

  /// Finalizes the crossfade by disposing the outgoing track from RAM and promoting the incoming track.
  static void _finalizeCrossfade(int nextIndex, int gen) {
    if (gen != _musicGen) return;

    // 1. Immediately dispose outgoing track to free memory
    if (_musicHandle != null) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          SoLoud.instance.stop(_musicHandle!);
        }
      } catch (_) {}
      _musicHandle = null;
    }
    if (_currentMusicSource != null) {
      try {
        SoLoud.instance.disposeSource(_currentMusicSource!);
      } catch (_) {}
      _currentMusicSource = null;
    }

    // 2. Promote incoming track to primary
    _currentMusicSource = _incomingMusicSource;
    _musicHandle = _incomingMusicHandle;
    _incomingMusicSource = null;
    _incomingMusicHandle = null;
    _currentTrackIndex = nextIndex;
    _crossfadeProgress = 0.0;

    // 3. Ensure target volume is applied
    _applyMusicVolume();

    final track = _playlist[_currentTrackIndex];
    debugPrint(
      '[AudioEngine] 🎵 Seamlessly crossfaded into: ${track.title} '
      '(${_currentTrackIndex + 1}/${_playlist.length})',
    );

    // 4. Schedule crossfade for this track
    _scheduleNextCrossfade(track, gen);
  }

  /// Cleans up all active and incoming music handles and disposes all sources from RAM.
  static Future<void> _cleanupCurrentMusicTrack() async {
    _crossfadeTriggerTimer?.cancel();
    _crossfadeTriggerTimer = null;
    _crossfadeRampTimer?.cancel();
    _crossfadeRampTimer = null;
    _crossfadeProgress = 0.0;

    if (_musicHandle != null && SoLoud.instance.isInitialized) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          await SoLoud.instance.stop(_musicHandle!);
        }
      } catch (_) {}
      _musicHandle = null;
    }

    if (_incomingMusicHandle != null && SoLoud.instance.isInitialized) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_incomingMusicHandle!)) {
          await SoLoud.instance.stop(_incomingMusicHandle!);
        }
      } catch (_) {}
      _incomingMusicHandle = null;
    }

    if (_currentMusicSource != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.disposeSource(_currentMusicSource!);
      } catch (_) {}
      _currentMusicSource = null;
    }

    if (_incomingMusicSource != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.disposeSource(_incomingMusicSource!);
      } catch (_) {}
      _incomingMusicSource = null;
    }
  }

  /// Advance to the next track in the BPM sequence.
  static void _onTrackComplete() {
    if (!_musicStarted) return;
    _currentTrackIndex = (_currentTrackIndex + 1) % _playlist.length;
    _playCurrentTrack();
  }

  /// Applies the current music volume to the active player(s).
  static void _applyMusicVolume() {
    if (!SoLoud.instance.isInitialized) return;
    final baseVolume = isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);

    try {
      if (_crossfadeRampTimer?.isActive ?? false) {
        final outVol = baseVolume * cos(_crossfadeProgress * pi / 2);
        final inVol = baseVolume * sin(_crossfadeProgress * pi / 2);
        if (_musicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          SoLoud.instance.setVolume(_musicHandle!, outVol);
        }
        if (_incomingMusicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_incomingMusicHandle!)) {
          SoLoud.instance.setVolume(_incomingMusicHandle!, inVol);
        }
      } else {
        if (_musicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          SoLoud.instance.setVolume(_musicHandle!, baseVolume);
        }
      }
    } catch (_) {}
  }

  /// Pauses the background music (used when muting or backgrounding).
  static void _pauseMusic() {
    if (!SoLoud.instance.isInitialized) return;
    try {
      if (_musicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
        SoLoud.instance.setPause(_musicHandle!, true);
      }
      if (_incomingMusicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_incomingMusicHandle!)) {
        SoLoud.instance.setPause(_incomingMusicHandle!, true);
      }
    } catch (_) {}
  }

  /// Resumes the background music (used when unmuting or returning to foreground).
  static void _resumeMusic() {
    if (!SoLoud.instance.isInitialized) return;
    if (_musicStarted && (_musicHandle != null || _incomingMusicHandle != null)) {
      try {
        _applyMusicVolume();
        if (_musicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          SoLoud.instance.setPause(_musicHandle!, false);
        }
        if (_incomingMusicHandle != null && SoLoud.instance.getIsValidVoiceHandle(_incomingMusicHandle!)) {
          SoLoud.instance.setPause(_incomingMusicHandle!, false);
        }
        return;
      } catch (_) {}
    }
    if (_audioUnlocked) {
      _startMusic();
    }
  }

  /// Call when app goes to background or browser tab is hidden.
  static void onAppBackground() {
    _pauseMusic();
  }

  /// Call when app returns to foreground.
  static void onAppForeground() {
    if (!isMuted) {
      _resumeMusic();
    }
  }

  // ─────────────────────────── Polyphonic SFX Playback ───────────────────────────

  /// Triggers a metallic rim clank with volume and heavy haptics scaled by impact velocity.
  static void playRimClank(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minRimSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastRimUs < 80000) return; // 80ms debounce
    _lastRimUs = now;

    // Scaled by impact velocity with 10% reduction
    final volume = ((impactSpeed / 6.0).clamp(0.35, 1.0) * 0.90);
    _safePlay(_rimSource, volume);
    _safeHaptic(HapticFeedback.heavyImpact);
  }

  /// Triggers a solid tempered-glass backboard thud with medium haptics.
  static void playBackboardThud(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minBackboardSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastBackboardUs < 80000) return; // 80ms debounce
    _lastBackboardUs = now;

    final volume = (impactSpeed / 7.0).clamp(0.35, 1.0);
    _safePlay(_backboardSource, volume);
    _safeHaptic(HapticFeedback.mediumImpact);
  }

  /// Triggers a crisp nylon net swish whoosh on clean baskets.
  static void playSwish() {
    if (isMuted || !_initialized) return;
    _safePlay(_swishSource, 1.0);
    _safeHaptic(HapticFeedback.selectionClick);
  }

  /// Triggers a warm hardwood court floor bounce with velocity-scaled volume and light haptics.
  static void playFloorBounce(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minBounceSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastBounceUs < 60000) return; // 60ms debounce
    _lastBounceUs = now;

    final volume = (impactSpeed / 6.5).clamp(0.20, 1.0);
    _safePlay(_bounceSource, volume);

    if (impactSpeed > 2.0) {
      _safeHaptic(HapticFeedback.lightImpact);
    }
  }

  /// Triggers the arena shot-clock buzzer and long haptic vibration at 00:00.
  static void playBuzzer() {
    if (isMuted || !_initialized) return;
    _safePlay(_buzzerSource, 1.0);
    _safeHaptic(HapticFeedback.vibrate);
  }

  /// Plays from a pre-allocated SoLoud [AudioSource] synchronously.
  /// Zero-allocation, zero-latency polyphonic mixing across up to 64 voice channels.
  static void _safePlay(AudioSource? source, double volume) {
    if (source == null || isMuted || !SoLoud.instance.isInitialized) return;
    try {
      final effectiveVolume = (volume * masterVolume * sfxVolume).clamp(
        0.0,
        1.0,
      );
      if (effectiveVolume <= 0.001) return;
      SoLoud.instance.play(source, volume: effectiveVolume);
    } catch (e) {
      debugPrint('[AudioEngine] Playback error: $e');
    }
  }

  static void _safeHaptic(Future<void> Function() hapticCall) {
    // Avoid navigator.vibrate DOM IPC overhead on Web/PWA to ensure seamless Web Audio buffer scheduling
    if (kIsWeb) return;
    try {
      hapticCall();
    } catch (_) {}
  }

  /// Releases all audio resources, stops music, and deinits SoLoud engine.
  static void dispose() {
    unawaited(_cleanupCurrentMusicTrack());
    _preloadedMusicSource = null;
    _musicStarted = false;

    _rimSource = null;
    _backboardSource = null;
    _swishSource = null;
    _bounceSource = null;
    _buzzerSource = null;

    if (SoLoud.instance.isInitialized) {
      unawaited(SoLoud.instance.disposeAllSources());
      unawaited(SoLoud.instance.deinitAsync());
    }

    _clock.stop();
    _clock.reset();
    _lastBounceUs = 0;
    _lastRimUs = 0;
    _lastBackboardUs = 0;
    _initialized = false;
    _audioUnlocked = false;
  }
}
