import 'dart:async';
import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized audio and haptics coordinator for basketball collisions,
/// net swishes, floor bounces, round-ending buzzers, and background music.
///
/// Performance architecture:
/// - **Pre-Warmed Player Pooling:** Fixed pools with [minPlayers] matching [maxPlayers]
///   are fully allocated upfront during [init], completely eliminating mid-gameplay
///   player creation and platform channel allocation churn.
/// - **Stopwatch Rate-Limiting:** A monotonic [Stopwatch] eliminates timing drift
///   and wall-clock shifts during the 240 Hz physics substep loop.
/// - **Velocity Gating:** Minimum impact speed thresholds prevent
///   trivially soft micro-collisions from ever reaching the audio pipeline.
/// - **Background Music Jukebox:** 7 tracks played in random shuffle order,
///   auto-advancing on completion, with independent volume control.
class AudioEngine {
  static final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);
  static bool get isMuted => isMutedNotifier.value;
  static set isMuted(bool value) => isMutedNotifier.value = value;

  /// Volume scale for sound effects (0.0 to 1.0).
  static final ValueNotifier<double> sfxVolumeNotifier = ValueNotifier<double>(
    0.65,
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

  // ── Pre-allocated audio player pools ──
  // Each pool maintains a fixed ring of AudioPlayer instances that are
  // reused across playback calls, avoiding the create-per-play overhead
  // of FlameAudio.play() which allocates native platform resources each time.
  static AudioPool? _rimPool;
  static AudioPool? _backboardPool;
  static AudioPool? _swishPool;
  static AudioPool? _bouncePool;
  static AudioPool? _buzzerPool;

  // ── Background Music Jukebox ──
  static final List<String> _musicTracks = [
    'music/Get On Down - Mr. Scruff.mp3',
    'music/Mr Scruff - Bang The Floor - Ninja Tune.mp3',
    'music/Mr Scruff - Hairy Bumpercress - Ninja Tune.mp3',
    'music/Mr Scruff - Music Takes Me Up - JoeStephens78.mp3',
    'music/Mr Scruff - Test The Sound - Ninja Tune.mp3',
    'music/Mr Scruff - Whiplash - Ninja Tune.mp3',
    'music/Mr Scruff- Kalimba (Ninja Tuna) - Calum White.mp3',
  ];
  static final Random _rng = Random();
  static AudioPlayer? _musicPlayer;
  static List<int> _shuffledIndices = [];
  static int _currentShufflePos = 0;
  static bool _musicStarted = false;
  static StreamSubscription? _musicCompleteSub;

  // ── Minimum impact velocity thresholds (m/s) ──
  // Impacts below these speeds produce no audible response, preventing
  // micro-collisions from saturating the platform channel queue.
  static const double _minRimSpeed = 0.5;
  static const double _minBackboardSpeed = 0.5;
  static const double _minBounceSpeed = 0.3;

  /// Preloads audio pools into memory for zero-latency in-flight playback.
  /// All five pools are loaded concurrently via [Future.wait].
  ///
  /// Specifying [minPlayers] equal to [maxPlayers] guarantees all instances
  /// are pre-created during loading, preventing cold mid-game allocations.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _clock.reset();
      _clock.start();

      // Bounce gets 3 pooled players (highest fire rate: rapid floor bouncing).
      // Rim, backboard, swish get 2 each for potential rapid overlaps.
      // Buzzer only needs 1 (fires once at game end).
      final results = await Future.wait([
        FlameAudio.createPool('rim_clank.wav', minPlayers: 2, maxPlayers: 2),
        FlameAudio.createPool('backboard.wav', minPlayers: 2, maxPlayers: 2),
        FlameAudio.createPool('swish.wav', minPlayers: 2, maxPlayers: 2),
        FlameAudio.createPool('bounce.wav', minPlayers: 3, maxPlayers: 3),
        FlameAudio.createPool('buzzer.wav', minPlayers: 1, maxPlayers: 1),
      ]);

      _rimPool = results[0];
      _backboardPool = results[1];
      _swishPool = results[2];
      _bouncePool = results[3];
      _buzzerPool = results[4];

      _initialized = true;
    } catch (e) {
      debugPrint('[AudioEngine] Audio preload warning: $e');
    }
  }

  static bool _audioUnlocked = false;

  /// Unlocks Web Audio playback on iOS Safari / mobile browsers upon user touch.
  static void unlockAudio() {
    if (_audioUnlocked) return;
    _audioUnlocked = true;
    if (!_initialized) {
      unawaited(init());
    }
    // Start background music on first user interaction (required by browsers).
    if (!_musicStarted) {
      _startMusic();
    }
  }

  // ─────────────────────────── Background Music ───────────────────────────

  /// Generates a new random shuffle of track indices.
  static void _reshufflePlaylist() {
    _shuffledIndices = List<int>.generate(_musicTracks.length, (i) => i)
      ..shuffle(_rng);
    _currentShufflePos = 0;
  }

  /// Starts the background music jukebox from a random track.
  static void _startMusic() {
    _musicStarted = true;
    _reshufflePlaylist();
    // Pick a random starting position in the shuffled list.
    _currentShufflePos = _rng.nextInt(_shuffledIndices.length);
    _playCurrentTrack();
  }

  /// Plays the track at the current shuffle position.
  static Future<void> _playCurrentTrack() async {
    try {
      _musicCompleteSub?.cancel();

      // Dispose previous player to free resources.
      await _musicPlayer?.dispose();
      _musicPlayer = AudioPlayer();

      final trackPath = _musicTracks[_shuffledIndices[_currentShufflePos]];
      final effectiveVolume = isMuted
          ? 0.0
          : (musicVolume * 0.6).clamp(0.0, 1.0);
      await _musicPlayer!.setVolume(effectiveVolume);
      await _musicPlayer!.setSource(AssetSource(trackPath));
      await _musicPlayer!.resume();

      // Listen for track completion to auto-advance.
      _musicCompleteSub = _musicPlayer!.onPlayerComplete.listen(
        (_) => _onTrackComplete(),
      );

      debugPrint(
        '[AudioEngine] 🎵 Now playing: $trackPath '
        '(${_currentShufflePos + 1}/${_shuffledIndices.length})',
      );
    } catch (e) {
      debugPrint('[AudioEngine] Music playback error: $e');
      // Try next track after a short delay on error.
      Future.delayed(const Duration(seconds: 2), _onTrackComplete);
    }
  }

  /// Called when a track finishes — advances to the next in the shuffle.
  static void _onTrackComplete() {
    _currentShufflePos++;
    if (_currentShufflePos >= _shuffledIndices.length) {
      _reshufflePlaylist(); // Loop: re-shuffle and start over.
    }
    _playCurrentTrack();
  }

  /// Applies the current music volume to the active player.
  static void _applyMusicVolume() {
    if (_musicPlayer == null) return;
    final effectiveVolume = isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);
    _musicPlayer!.setVolume(effectiveVolume);
  }

  /// Pauses the background music (used when muting).
  static void _pauseMusic() {
    _musicPlayer?.pause();
  }

  /// Resumes the background music (used when unmuting).
  static void _resumeMusic() {
    if (_musicStarted && _musicPlayer != null) {
      _applyMusicVolume();
      _musicPlayer!.resume();
    }
  }

  // ─────────────────────────── SFX Playback ───────────────────────────

  /// Triggers a metallic rim clank with volume and heavy haptics scaled by impact velocity.
  static void playRimClank(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minRimSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastRimUs < 80000) return; // 80ms debounce
    _lastRimUs = now;

    final volume = (impactSpeed / 6.0).clamp(0.35, 1.0);
    _safePoolPlay(_rimPool, volume);
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
    _safePoolPlay(_backboardPool, volume);
    _safeHaptic(HapticFeedback.mediumImpact);
  }

  /// Triggers a crisp nylon net swish whoosh on clean baskets.
  static void playSwish() {
    if (isMuted || !_initialized) return;
    _safePoolPlay(_swishPool, 1.0);
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
    _safePoolPlay(_bouncePool, volume);

    if (impactSpeed > 2.0) {
      _safeHaptic(HapticFeedback.lightImpact);
    }
  }

  /// Triggers the arena shot-clock buzzer and long haptic vibration at 00:00.
  static void playBuzzer() {
    if (isMuted || !_initialized) return;
    _safePoolPlay(_buzzerPool, 1.0);
    _safeHaptic(HapticFeedback.vibrate);
  }

  /// Master volume scale for all sound effects (scaled to 60%).
  static const double masterVolume = 0.60;

  /// Plays from a pre-allocated pooled player with error handling.
  /// Reuses existing [AudioPlayer] instances and catches both sync and async failures.
  static void _safePoolPlay(AudioPool? pool, double volume) {
    if (pool == null || isMuted) return;
    try {
      final effectiveVolume = (volume * masterVolume * sfxVolume).clamp(
        0.0,
        1.0,
      );
      if (effectiveVolume <= 0.001) return;
      unawaited(
        pool
            .start(volume: effectiveVolume)
            .then(
              (_) => null,
              onError: (e) {
                debugPrint('[AudioEngine] Pool playback error: $e');
              },
            ),
      );
    } catch (e) {
      debugPrint('[AudioEngine] Pool synchronous error: $e');
    }
  }

  static void _safeHaptic(Future<void> Function() hapticCall) {
    try {
      hapticCall();
    } catch (_) {}
  }

  /// Releases all pooled audio resources, stops music, and frees native player handles.
  /// Safe to call multiple times.
  static void dispose() {
    // Stop and dispose music player.
    _musicCompleteSub?.cancel();
    _musicCompleteSub = null;
    _musicPlayer?.dispose();
    _musicPlayer = null;
    _musicStarted = false;

    // Dispose SFX pools.
    final pools = [
      _rimPool,
      _backboardPool,
      _swishPool,
      _bouncePool,
      _buzzerPool,
    ];
    _rimPool = null;
    _backboardPool = null;
    _swishPool = null;
    _bouncePool = null;
    _buzzerPool = null;

    for (final pool in pools) {
      if (pool != null) {
        unawaited(
          pool.dispose().catchError((e) {
            debugPrint('[AudioEngine] Pool dispose warning: $e');
          }),
        );
      }
    }

    _clock.stop();
    _clock.reset();
    _lastBounceUs = 0;
    _lastRimUs = 0;
    _lastBackboardUs = 0;
    _initialized = false;
  }
}
