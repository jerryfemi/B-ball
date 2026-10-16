import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a background soundtrack item with instant-start bundled asset support.
class MusicTrack {
  final String title;
  final String subtitle;
  final String assetPath;
  final double durationSeconds;

  const MusicTrack({
    required this.title,
    this.subtitle = '',
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

  // ── Available Background Music Tracks ──
  static const List<MusicTrack> availableTracks = [
    MusicTrack(
      title: 'Back Outside',
      subtitle: 'BNXN, Sarz (98 BPM)',
      assetPath: 'assets/music/short/BNXN, Sarz - Back Outside.mp3',
      durationSeconds: 39.0,
    ),
    MusicTrack(
      title: 'Back To Life',
      subtitle: 'Soul II Soul - Instrumental (101 BPM)',
      assetPath:
          'assets/music/short/Back To Life - Soul II Soul (Instrumental).mp3',
      durationSeconds: 30.0,
    ),
    MusicTrack(
      title: 'WAIT FOR U',
      subtitle: 'Future ft. Drake, Tems (83 BPM)',
      assetPath:
          'assets/music/short/Future - WAIT FOR U ft. Drake, Tems.mp3',
      durationSeconds: 55.0,
    ),
  ];

  /// Reactive notifier for the currently selected music track index.
  static final ValueNotifier<int> currentTrackIndexNotifier =
      ValueNotifier<int>(0);
  static int get currentTrackIndex => currentTrackIndexNotifier.value;

  static const String _prefKeyMusicTrack = 'selected_music_track_index';

  static int _currentTrackIndex = 0;
  static SoundHandle? _musicHandle;
  static AudioSource? _currentMusicSource;
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

      // Restore user's preferred track from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedIndex = prefs.getInt(_prefKeyMusicTrack) ?? 0;
        if (savedIndex >= 0 && savedIndex < availableTracks.length) {
          currentTrackIndexNotifier.value = savedIndex;
          _currentTrackIndex = savedIndex;
        }
      } catch (e) {
        debugPrint('[AudioEngine] Music preference read error: $e');
      }

      // Pre-warm the preferred track into RAM during startup for 0ms audio latency
      if (availableTracks.isNotEmpty) {
        final preferredTrack = availableTracks[currentTrackIndexNotifier.value];
        try {
          _preloadedMusicSource = await SoLoud.instance.loadAsset(
            preferredTrack.assetPath,
            mode: LoadMode.memory,
          );
          debugPrint(
            '[AudioEngine] 🎵 Pre-warmed preferred track: ${preferredTrack.title}',
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

  // ─────────────────────────── Background Music Player ───────────────────────────

  /// Selects and switches to the track at [index].
  ///
  /// Immediately loads the selected track into RAM with [LoadMode.memory],
  /// disposes the previous track to maintain a low RAM footprint (<15 MB),
  /// and saves the player's preference to [SharedPreferences].
  static Future<void> selectTrack(int index) async {
    if (index < 0 || index >= availableTracks.length) return;
    if (index == currentTrackIndexNotifier.value &&
        _currentMusicSource != null &&
        _musicHandle != null) {
      return;
    }

    currentTrackIndexNotifier.value = index;
    _currentTrackIndex = index;

    // Persist choice to local storage
    unawaited(
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_prefKeyMusicTrack, index);
      }).catchError((e) {
        debugPrint('[AudioEngine] Failed to save track preference: $e');
      }),
    );

    if (!SoLoud.instance.isInitialized) return;

    final track = availableTracks[index];
    final gen = ++_musicGen;

    try {
      // 1. Preload new track into RAM
      final newSource = await SoLoud.instance.loadAsset(
        track.assetPath,
        mode: LoadMode.memory,
      );

      if (gen != _musicGen) {
        unawaited(SoLoud.instance.disposeSource(newSource));
        return;
      }

      // 2. Clean up old track voice and RAM source
      await _cleanupCurrentMusicTrack();

      _currentMusicSource = newSource;

      // 3. Play or hold ready
      if (_musicStarted) {
        final effectiveVolume =
            isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);

        _musicHandle = SoLoud.instance.play(
          newSource,
          volume: effectiveVolume,
          looping: true,
        );

        debugPrint(
          '[AudioEngine] 🎵 Now looping preferred track: ${track.title}',
        );
      } else {
        _preloadedMusicSource = newSource;
        debugPrint(
          '[AudioEngine] 🎵 Pre-warmed preferred track: ${track.title}',
        );
      }
    } catch (e) {
      debugPrint('[AudioEngine] Error selecting track: $e');
    }
  }

  /// Starts background music playback using the selected track.
  static void _startMusic() {
    if (availableTracks.isEmpty || !SoLoud.instance.isInitialized) return;
    _musicStarted = true;
    _currentTrackIndex = currentTrackIndexNotifier.value.clamp(
      0,
      availableTracks.length - 1,
    );

    if (_preloadedMusicSource != null) {
      _playCurrentTrack(usePreloaded: true);
      return;
    }

    _playCurrentTrack();
  }

  /// Plays the currently selected track on an infinite native loop.
  static Future<void> _playCurrentTrack({bool usePreloaded = false}) async {
    final gen = ++_musicGen;
    try {
      if (!SoLoud.instance.isInitialized) return;

      await _cleanupCurrentMusicTrack();

      _currentTrackIndex = currentTrackIndexNotifier.value.clamp(
        0,
        availableTracks.length - 1,
      );
      final track = availableTracks[_currentTrackIndex];

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
      final effectiveVolume =
          isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);

      _musicHandle = SoLoud.instance.play(
        source,
        volume: effectiveVolume,
        looping: true,
      );

      debugPrint(
        '[AudioEngine] 🎵 Playing: ${track.title} (Continuous Loop)',
      );
    } catch (e) {
      debugPrint('[AudioEngine] Music playback error: $e');
    }
  }



  /// Cleans up the active music handle and disposes its source from RAM.
  static Future<void> _cleanupCurrentMusicTrack() async {
    if (_musicHandle != null && SoLoud.instance.isInitialized) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          await SoLoud.instance.stop(_musicHandle!);
        }
      } catch (_) {}
      _musicHandle = null;
    }

    if (_currentMusicSource != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.disposeSource(_currentMusicSource!);
      } catch (_) {}
      _currentMusicSource = null;
    }
  }

  /// Applies the current music volume to the active player.
  static void _applyMusicVolume() {
    if (!SoLoud.instance.isInitialized) return;
    final baseVolume = isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);

    try {
      if (_musicHandle != null &&
          SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
        SoLoud.instance.setVolume(_musicHandle!, baseVolume);
      }
    } catch (_) {}
  }

  /// Pauses the background music (used when muting or backgrounding).
  static void _pauseMusic() {
    if (!SoLoud.instance.isInitialized) return;
    try {
      if (_musicHandle != null &&
          SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
        SoLoud.instance.setPause(_musicHandle!, true);
      }
    } catch (_) {}
  }

  /// Resumes the background music (used when unmuting or returning to foreground).
  static void _resumeMusic() {
    if (!SoLoud.instance.isInitialized) return;
    if (_musicStarted && _musicHandle != null) {
      try {
        _applyMusicVolume();
        if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          SoLoud.instance.setPause(_musicHandle!, false);
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
