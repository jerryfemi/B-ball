import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Represents a background soundtrack item with instant-start bundled asset support.
class MusicTrack {
  final String title;
  final String assetPath;

  const MusicTrack({required this.title, required this.assetPath});
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

  // ── Background Music Jukebox (10 MB Compressed Offline Soundtrack) ──
  static const MusicTrack _bundledOfflineTrack = MusicTrack(
    title: 'Test The Sound - Mr. Scruff',
    assetPath: 'assets/music/Mr Scruff - Test The Sound - Ninja Tune.mp3',
  );

  static final List<MusicTrack> _playlist = [
    _bundledOfflineTrack,
    const MusicTrack(
      title: 'Get On Down - Mr. Scruff',
      assetPath: 'assets/music/Get On Down - Mr. Scruff.mp3',
    ),
    const MusicTrack(
      title: 'Bang The Floor - Mr. Scruff',
      assetPath: 'assets/music/Mr Scruff - Bang The Floor - Ninja Tune.mp3',
    ),
    const MusicTrack(
      title: 'Hairy Bumpercress - Mr. Scruff',
      assetPath: 'assets/music/Mr Scruff - Hairy Bumpercress - Ninja Tune.mp3',
    ),
    const MusicTrack(
      title: 'Music Takes Me Up - Mr. Scruff',
      assetPath:
          'assets/music/Mr Scruff - Music Takes Me Up - JoeStephens78.mp3',
    ),
    const MusicTrack(
      title: 'Whiplash - Mr. Scruff',
      assetPath: 'assets/music/Mr Scruff - Whiplash - Ninja Tune.mp3',
    ),
    const MusicTrack(
      title: 'Kalimba - Mr. Scruff',
      assetPath:
          'assets/music/Mr Scruff- Kalimba (Ninja Tuna) - Calum White.mp3',
    ),
  ];

  static final Random _rng = Random();
  static SoundHandle? _musicHandle;
  static AudioSource? _currentMusicSource;
  static StreamSubscription? _musicEventSub;
  static List<int> _shuffledIndices = [];
  static int _currentShufflePos = 0;
  static bool _musicStarted = false;
  static int _musicGen = 0;

  static bool _audioUnlocked = false;

  // ── Minimum impact velocity thresholds (m/s) ──
  static const double _minRimSpeed = 0.5;
  static const double _minBackboardSpeed = 0.5;
  static const double _minBounceSpeed = 0.3;

  /// Master volume scale for all sound effects (scaled to 60%).
  static const double masterVolume = 0.60;

  /// Preloads SoLoud engine and all SFX into RAM for zero-latency in-flight playback.
  static Future<void> init() async {
    if (_initialized) return;
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

      _initialized = true;
      debugPrint(
        '[AudioEngine] SoLoud engine initialized with 5 preloaded SFX.',
      );
    } catch (e) {
      debugPrint('[AudioEngine] SoLoud preload error: $e');
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

  // ─────────────────────────── Background Music Jukebox ───────────────────────────

  /// Generates a new random shuffle of track indices.
  static void _reshufflePlaylist() {
    _shuffledIndices = List<int>.generate(_playlist.length, (i) => i)
      ..shuffle(_rng);
    _currentShufflePos = 0;
  }

  /// Starts the background music jukebox, guaranteeing the instant-start track plays first.
  static void _startMusic() {
    if (_playlist.isEmpty || !SoLoud.instance.isInitialized) return;
    _musicStarted = true;
    _reshufflePlaylist();

    // Place the lightweight offline track at index 0 on startup
    final bundledIdx = _playlist.indexOf(_bundledOfflineTrack);
    if (bundledIdx != -1) {
      _shuffledIndices.remove(bundledIdx);
      _shuffledIndices.insert(0, bundledIdx);
    }
    _currentShufflePos = 0;

    _playCurrentTrack();
  }

  /// Plays the track at the current shuffle position.
  static Future<void> _playCurrentTrack() async {
    final gen = ++_musicGen;
    try {
      if (!SoLoud.instance.isInitialized) return;

      // Stop and dispose previous track to conserve memory
      await _cleanupCurrentMusicTrack();

      if (_currentShufflePos >= _shuffledIndices.length) {
        _currentShufflePos = 0;
      }
      final track = _playlist[_shuffledIndices[_currentShufflePos]];

      // Load music track into RAM for zero-latency, zero-disk streaming
      final source = await SoLoud.instance.loadAsset(
        track.assetPath,
        mode: LoadMode.memory,
      );

      // Race guard: if another track was requested while loading, discard this one
      if (gen != _musicGen) {
        unawaited(SoLoud.instance.disposeSource(source));
        return;
      }

      _currentMusicSource = source;

      final effectiveVolume = isMuted
          ? 0.0
          : (musicVolume * 0.6).clamp(0.0, 1.0);

      _musicHandle = SoLoud.instance.play(
        source,
        volume: effectiveVolume,
        looping: false,
      );

      // Auto-advance to next track when playback finishes
      _musicEventSub = source.soundEvents.listen((event) {
        if (event.event == SoundEventType.handleIsNoMoreValid &&
            gen == _musicGen) {
          _onTrackComplete();
        }
      });

      debugPrint(
        '[AudioEngine] 🎵 Now playing: ${track.title} '
        '(${_currentShufflePos + 1}/${_shuffledIndices.length})',
      );
    } catch (e) {
      debugPrint('[AudioEngine] Music playback error: $e');
      if (_audioUnlocked && _musicStarted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (gen == _musicGen) _onTrackComplete();
        });
      }
    }
  }

  /// Cleans up current music handle and source.
  static Future<void> _cleanupCurrentMusicTrack() async {
    await _musicEventSub?.cancel();
    _musicEventSub = null;

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

  /// Called when a track finishes — advances to the next in the shuffle.
  static void _onTrackComplete() {
    if (!_musicStarted) return;
    _currentShufflePos++;
    if (_currentShufflePos >= _shuffledIndices.length) {
      final lastTrackIdx = _shuffledIndices.isNotEmpty
          ? _shuffledIndices.last
          : -1;
      _reshufflePlaylist();
      // Avoid playing the exact same track back-to-back across reshuffles
      if (_shuffledIndices.length > 1 &&
          _shuffledIndices.first == lastTrackIdx) {
        _shuffledIndices.add(_shuffledIndices.removeAt(0));
      }
    }
    _playCurrentTrack();
  }

  /// Applies the current music volume to the active player.
  static void _applyMusicVolume() {
    if (_musicHandle == null || !SoLoud.instance.isInitialized) return;
    try {
      if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
        final effectiveVolume = isMuted
            ? 0.0
            : (musicVolume * 0.6).clamp(0.0, 1.0);
        SoLoud.instance.setVolume(_musicHandle!, effectiveVolume);
      }
    } catch (_) {}
  }

  /// Pauses the background music (used when muting or backgrounding).
  static void _pauseMusic() {
    if (_musicHandle == null || !SoLoud.instance.isInitialized) return;
    try {
      if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
        SoLoud.instance.setPause(_musicHandle!, true);
      }
    } catch (_) {}
  }

  /// Resumes the background music (used when unmuting or returning to foreground).
  static void _resumeMusic() {
    if (!SoLoud.instance.isInitialized) return;
    if (_musicStarted && _musicHandle != null) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_musicHandle!)) {
          _applyMusicVolume();
          SoLoud.instance.setPause(_musicHandle!, false);
          return;
        }
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

    final volume = (impactSpeed / 6.0).clamp(0.35, 1.0);
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
    try {
      hapticCall();
    } catch (_) {}
  }

  /// Releases all audio resources, stops music, and deinits SoLoud engine.
  static void dispose() {
    _musicEventSub?.cancel();
    _musicEventSub = null;
    _musicHandle = null;
    _currentMusicSource = null;
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
