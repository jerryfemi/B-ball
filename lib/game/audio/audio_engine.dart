import 'dart:async';
import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a background soundtrack item with instant-start bundled asset support
/// and progressive streaming support for remote CDN / Firebase Storage URLs.
class MusicTrack {
  final String title;
  final String assetPath;
  final String? remoteUrl;

  const MusicTrack({
    required this.title,
    required this.assetPath,
    this.remoteUrl,
  });

  Source get source {
    if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      return UrlSource(remoteUrl!);
    }
    return AssetSource(assetPath);
  }
}

/// Centralized audio and haptics coordinator for basketball collisions,
/// net swishes, floor bounces, round-ending buzzers, and background music.
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

  // ── Pre-allocated audio player pools ──
  // Each pool maintains a fixed ring of AudioPlayer instances that are
  // reused across playback calls, avoiding the create-per-play overhead
  // of FlameAudio.play() which allocates native platform resources each time.
  static AudioPool? _rimPool;
  static AudioPool? _backboardPool;
  static AudioPool? _swishPool;
  static AudioPool? _bouncePool;
  static AudioPool? _buzzerPool;

  // ── Background Music Jukebox (Instant-Start + Stream Architecture) ──
  /// The lightweight (~800KB) bundled offline track guaranteed to start instantly with 0ms network latency.
  static const MusicTrack _bundledOfflineTrack = MusicTrack(
    title: 'Test The Sound - Mr. Scruff',
    assetPath: 'music/Mr Scruff - Test The Sound - Ninja Tune.mp3',
  );

  /// Full jukebox playlist. To stream tracks from Firebase Storage or a CDN, simply populate `remoteUrl`.
  /// The audio engine streams progressively and falls back smoothly to offline assets if network fails.
  static final List<MusicTrack> _playlist = [
    _bundledOfflineTrack,
    const MusicTrack(
      title: 'Get On Down - Mr. Scruff',
      assetPath: 'music/Get On Down - Mr. Scruff.mp3',
    ),
    const MusicTrack(
      title: 'Bang The Floor - Mr. Scruff',
      assetPath: 'music/Mr Scruff - Bang The Floor - Ninja Tune.mp3',
    ),
    const MusicTrack(
      title: 'Hairy Bumpercress - Mr. Scruff',
      assetPath: 'music/Mr Scruff - Hairy Bumpercress - Ninja Tune.mp3',
    ),
    const MusicTrack(
      title: 'Music Takes Me Up - Mr. Scruff',
      assetPath: 'music/Mr Scruff - Music Takes Me Up - JoeStephens78.mp3',
    ),
    const MusicTrack(
      title: 'Whiplash - Mr. Scruff',
      assetPath: 'music/Mr Scruff - Whiplash - Ninja Tune.mp3',
    ),
    const MusicTrack(
      title: 'Kalimba - Mr. Scruff',
      assetPath: 'music/Mr Scruff- Kalimba (Ninja Tuna) - Calum White.mp3',
    ),
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

  static int _musicGen = 0;
  static bool _audioUnlocked = false;
  static bool _unlocking = false;

  /// Unlocks Web Audio playback on iOS Safari / mobile browsers upon user touch.
  /// Uses a retryable unlock mechanism so that if a touch occurs before
  /// initialization completes or Safari rejects the initial play(), subsequent
  /// taps will continue attempting to unlock until playback succeeds.
  static void unlockAudio() {
    if (_audioUnlocked || _unlocking) return;
    if (!_initialized) {
      unawaited(init());
      return;
    }
    _unlocking = true;

    // Warm pooled SFX players inside the gesture context at near-silent volume.
    // This unlocks iOS WebKit audio playback restrictions for HTML/WebAudio elements.
    final warmUps = <Future>[];
    for (final pool in [_rimPool, _backboardPool, _swishPool, _bouncePool, _buzzerPool]) {
      if (pool != null) {
        warmUps.add(
          pool.start(volume: 0.001).then<void>((_) => null, onError: (_) => null),
        );
      }
    }

    Future.wait(warmUps).then((_) {
      _audioUnlocked = true;
    }).catchError((e) {
      debugPrint('[AudioEngine] Audio unlock retry needed: $e');
    }).whenComplete(() {
      _unlocking = false;
    });

    if (!_musicStarted) {
      _startMusic();
    } else if (_musicPlayer != null && !isMuted) {
      _musicPlayer!.resume();
    }
  }

  // ─────────────────────────── Background Music ───────────────────────────

  /// Generates a new random shuffle of track indices.
  static void _reshufflePlaylist() {
    _shuffledIndices = List<int>.generate(_playlist.length, (i) => i)
      ..shuffle(_rng);
    _currentShufflePos = 0;
  }

  /// Starts the background music jukebox, guaranteeing the instant-start bundled track plays first.
  static void _startMusic() {
    if (_playlist.isEmpty) return;
    _musicStarted = true;
    _reshufflePlaylist();

    // Place the instant-start bundled track at index 0 on startup
    final bundledIdx = _playlist.indexOf(_bundledOfflineTrack);
    if (bundledIdx != -1) {
      _shuffledIndices.remove(bundledIdx);
      _shuffledIndices.insert(0, bundledIdx);
    }
    _currentShufflePos = 0;

    _musicPlayer ??= AudioPlayer();
    _musicPlayer!.audioCache.prefix = 'assets/';
    _musicCompleteSub ??=
        _musicPlayer!.onPlayerComplete.listen((_) => _onTrackComplete());

    _playCurrentTrack();
  }

  /// Plays the track at the current shuffle position on the single reused player.
  /// If a streamed track fails due to network issues, it automatically falls back to the bundled offline track.
  static Future<void> _playCurrentTrack({bool fallbackToBundled = false}) async {
    final gen = ++_musicGen;
    try {
      if (_currentShufflePos >= _shuffledIndices.length) {
        _currentShufflePos = 0;
      }
      final track = fallbackToBundled
          ? _bundledOfflineTrack
          : _playlist[_shuffledIndices[_currentShufflePos]];

      final effectiveVolume =
          isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);

      _musicPlayer ??= AudioPlayer();
      _musicPlayer!.audioCache.prefix = 'assets/';
      await _musicPlayer!.setVolume(effectiveVolume);

      if (gen != _musicGen) return;

      final source = track.source;
      if (!isMuted) {
        await _musicPlayer!.play(source);
      } else {
        await _musicPlayer!.setSource(source);
      }

      debugPrint(
        '[AudioEngine] 🎵 Now playing: ${track.title} '
        '(${_currentShufflePos + 1}/${_shuffledIndices.length})',
      );
    } catch (e) {
      debugPrint('[AudioEngine] Music playback error: $e');
      // If a remote/streamed track errors out, smoothly fallback to bundled offline track once
      if (!fallbackToBundled) {
        _playCurrentTrack(fallbackToBundled: true);
        return;
      }
      if (_audioUnlocked && _musicStarted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (gen == _musicGen) _onTrackComplete();
        });
      }
    }
  }

  /// Called when a track finishes — advances to the next in the shuffle.
  static void _onTrackComplete() {
    if (!_musicStarted) return;
    _currentShufflePos++;
    if (_currentShufflePos >= _shuffledIndices.length) {
      final lastTrackIdx =
          _shuffledIndices.isNotEmpty ? _shuffledIndices.last : -1;
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
    if (_musicPlayer == null) return;
    final effectiveVolume =
        isMuted ? 0.0 : (musicVolume * 0.6).clamp(0.0, 1.0);
    _musicPlayer!.setVolume(effectiveVolume);
  }

  /// Pauses the background music (used when muting or backgrounding).
  static void _pauseMusic() {
    _musicPlayer?.pause();
  }

  /// Resumes the background music (used when unmuting or returning to foreground).
  static void _resumeMusic() {
    if (_musicStarted && _musicPlayer != null) {
      _applyMusicVolume();
      _musicPlayer!.resume();
    } else if (!_musicStarted && _audioUnlocked) {
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
