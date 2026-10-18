import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_backend.dart';

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
/// Sound output goes through [AudioBackend]:
///  • Web: the browser's own audio — sound effects as pre-decoded Web Audio
///    buffers, music as a decoded looping buffer. Both are mixed on the
///    browser's audio thread, so a slow game frame can't make the music skip
///    and audio can't make the game stutter. No SoLoud WASM on web.
///  • Native builds: SoLoud.
///
/// Players can switch MUSIC and SOUND EFFECTS off independently (pause menu).
/// With music off the track is never even downloaded; with effects off they
/// are never decoded.
class AudioEngine {
  static final AudioBackend _backend = createAudioBackend();

  static final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);
  static bool get isMuted => isMutedNotifier.value;
  static set isMuted(bool value) => isMutedNotifier.value = value;

  /// Volume scale for sound effects (0.0 to 1.0). Default 60%.
  static final ValueNotifier<double> sfxVolumeNotifier = ValueNotifier<double>(
    0.60,
  );
  static double get sfxVolume => sfxVolumeNotifier.value;
  static set sfxVolume(double value) =>
      sfxVolumeNotifier.value = value.clamp(0.0, 1.0);

  /// Volume scale for background music (0.0 to 1.0). Default 68%.
  static final ValueNotifier<double> musicVolumeNotifier =
      ValueNotifier<double>(0.68);
  static double get musicVolume => musicVolumeNotifier.value;
  static set musicVolume(double value) {
    musicVolumeNotifier.value = value.clamp(0.0, 1.0);
    _applyMusicState();
  }

  /// MUSIC on/off (persisted). Off = stopped and never downloaded.
  static final ValueNotifier<bool> musicEnabledNotifier = ValueNotifier<bool>(
    true,
  );
  static bool get musicEnabled => musicEnabledNotifier.value;

  /// SOUND EFFECTS on/off (persisted). Off = never decoded or played.
  static final ValueNotifier<bool> sfxEnabledNotifier = ValueNotifier<bool>(
    true,
  );
  static bool get sfxEnabled => sfxEnabledNotifier.value;

  static const String _prefKeyMusicTrack = 'selected_music_track_index';
  static const String _prefKeyMusicEnabled = 'music_enabled';
  static const String _prefKeySfxEnabled = 'sfx_enabled';

  /// Toggles mute state and notifies all reactive UI listeners.
  static void toggleMute() {
    isMutedNotifier.value = !isMutedNotifier.value;
    _applyMusicState();
  }

  /// Turns the soundtrack on or off and remembers the choice.
  static Future<void> setMusicEnabled(bool enabled) async {
    if (musicEnabledNotifier.value == enabled) return;
    musicEnabledNotifier.value = enabled;
    if (enabled) {
      if (_audioUnlocked) _startMusic();
    } else {
      _musicStarted = false;
      _backend.unloadMusic();
    }
    await _savePref(_prefKeyMusicEnabled, enabled);
  }

  /// Turns sound effects on or off and remembers the choice.
  static Future<void> setSfxEnabled(bool enabled) async {
    if (sfxEnabledNotifier.value == enabled) return;
    sfxEnabledNotifier.value = enabled;
    if (enabled && _initialized) unawaited(_loadSfx());
    await _savePref(_prefKeySfxEnabled, enabled);
  }

  static Future<void> _savePref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('[AudioEngine] Could not save $key: $e');
    }
  }

  static bool _initialized = false;
  static bool _isInitializing = false;
  static Completer<void>? _initCompleter;
  static bool _sfxLoaded = false;

  // ── Monotonic stopwatch (zero-allocation rate-limiting) ──
  static final Stopwatch _clock = Stopwatch();
  static int _lastBounceUs = 0;
  static int _lastRimUs = 0;
  static int _lastBackboardUs = 0;

  static const Map<Sfx, String> _sfxAssets = {
    Sfx.rim: 'assets/audio/rim_clank.wav',
    Sfx.backboard: 'assets/audio/backboard.wav',
    Sfx.swish: 'assets/audio/swish.wav',
    Sfx.bounce: 'assets/audio/bounce.wav',
    Sfx.buzzer: 'assets/audio/buzzer.wav',
  };

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

  static bool _musicStarted = false;
  static bool _audioUnlocked = false;
  static bool _isBackgrounded = false;

  // ── Minimum impact velocity thresholds (m/s) ──
  static const double _minRimSpeed = 0.5;
  static const double _minBackboardSpeed = 0.5;
  static const double _minBounceSpeed = 0.3;

  /// Master volume scale for all sound effects (scaled to 60%).
  static const double masterVolume = 0.60;

  /// Starts the audio engine and decodes the sound effects.
  ///
  /// Never throws and never blocks the game: if audio can't start, the game
  /// simply runs silent and the next tap retries.
  static Future<void> init() async {
    if (_initialized) return;
    if (_isInitializing) return _initCompleter?.future;
    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      _clock
        ..reset()
        ..start();

      await _loadPrefs();
      await _backend.init();
      // Ready for taps right away; effects finish decoding in the background.
      _initialized = true;
      if (sfxEnabled) unawaited(_loadSfx());
      debugPrint('[AudioEngine] Audio ready.');
    } catch (e) {
      debugPrint('[AudioEngine] Audio unavailable: $e');
    } finally {
      _isInitializing = false;
      _initCompleter?.complete();
    }
  }

  static Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_prefKeyMusicTrack) ?? 0;
      if (savedIndex >= 0 && savedIndex < availableTracks.length) {
        currentTrackIndexNotifier.value = savedIndex;
      }
      musicEnabledNotifier.value = prefs.getBool(_prefKeyMusicEnabled) ?? true;
      sfxEnabledNotifier.value = prefs.getBool(_prefKeySfxEnabled) ?? true;
    } catch (e) {
      debugPrint('[AudioEngine] Preference read error: $e');
    }
  }

  static Future<void> _loadSfx() async {
    if (_sfxLoaded) return;
    _sfxLoaded = true;
    try {
      await _backend.loadSfx(_sfxAssets);
    } catch (e) {
      _sfxLoaded = false;
      debugPrint('[AudioEngine] Sound effects failed to load: $e');
    }
  }

  /// Unlocks audio on iOS Safari / mobile browsers. Called on every pointer
  /// down/up; the first one inside a real tap starts the music.
  static void unlockAudio() {
    // Re-checked live on every tap (two property reads): a browser can
    // reject a play() after the fact, or suspend audio in the background.
    if (_audioUnlocked && _backend.isUnlocked) return;
    if (!_initialized) {
      // Audio failed to start earlier (or is still starting): retry.
      unawaited(init());
      return;
    }
    // Must stay synchronous: browsers only allow starting audio inside the
    // tap. Retried on every touch until the browser confirms audio is live
    // (iOS ignores the touch-down and only allows it on the release).
    _backend.unlock();
    if (!_musicStarted) _startMusic();
    _audioUnlocked = _backend.isUnlocked;
  }

  // ─────────────────────────── Background Music Player ───────────────────────────

  /// Selects and switches to the track at [index], and saves the choice.
  static Future<void> selectTrack(int index) async {
    if (index < 0 || index >= availableTracks.length) return;
    currentTrackIndexNotifier.value = index;

    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setInt(_prefKeyMusicTrack, index))
          .catchError((Object e) {
            debugPrint('[AudioEngine] Failed to save track preference: $e');
            return false;
          }),
    );

    if (_musicStarted) {
      await _backend.setMusicTrack(availableTracks[index].assetPath);
      _applyMusicState();
    }
  }

  /// Starts the selected track (only after the first tap, and only if MUSIC
  /// is on — otherwise nothing is downloaded).
  static void _startMusic() {
    if (availableTracks.isEmpty || !musicEnabled || !_initialized) return;
    _musicStarted = true;
    final index = currentTrackIndexNotifier.value.clamp(
      0,
      availableTracks.length - 1,
    );
    // Order matters on web: set the source and request playback in the same
    // synchronous tap.
    _backend.setMusicVolume(_effectiveMusicVolume);
    final load = _backend.setMusicTrack(availableTracks[index].assetPath);
    _backend.setMusicPlaying(_musicShouldPlay);
    unawaited(load.then((_) => _applyMusicState()));
  }

  static double get _effectiveMusicVolume =>
      (musicVolume * 0.6).clamp(0.0, 1.0);

  /// Whether the soundtrack should currently be audible. At 0% volume the
  /// player is PAUSED, not just silenced, so it costs nothing.
  static bool get _musicShouldPlay =>
      musicEnabled && !isMuted && !_isBackgrounded && musicVolume > 0.001;

  /// Pushes the current volume and play/pause state to the backend.
  static void _applyMusicState() {
    if (!_musicStarted) {
      // First unmute / volume-up after the first tap starts the music.
      if (_audioUnlocked && _musicShouldPlay) _startMusic();
      return;
    }
    _backend.setMusicVolume(_effectiveMusicVolume);
    _backend.setMusicPlaying(_musicShouldPlay);
  }

  /// Call when app goes to background or browser tab is hidden.
  static void onAppBackground() {
    _isBackgrounded = true;
    _applyMusicState();
  }

  /// Call when app returns to foreground.
  static void onAppForeground() {
    _isBackgrounded = false;
    // Mobile browsers may suspend audio while hidden: re-arm the unlock so
    // the next tap revives it if this resume attempt isn't allowed.
    _applyMusicState();
    if (_initialized) {
      _backend.unlock();
      _audioUnlocked = _backend.isUnlocked;
    }
  }

  // ─────────────────────────── Polyphonic SFX Playback ───────────────────────────

  static bool get _canPlaySfx => _initialized && sfxEnabled && !isMuted;

  /// Triggers a metallic rim clank with volume and heavy haptics scaled by impact velocity.
  static void playRimClank(double impactSpeed) {
    if (!_canPlaySfx) return;
    if (impactSpeed < _minRimSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastRimUs < 80000) return; // 80ms debounce
    _lastRimUs = now;

    // Scaled by impact velocity with 10% reduction
    final volume = ((impactSpeed / 6.0).clamp(0.35, 1.0) * 0.90);
    _safePlay(Sfx.rim, volume);
    _safeHaptic(HapticFeedback.heavyImpact);
  }

  /// Triggers a solid tempered-glass backboard thud with medium haptics.
  static void playBackboardThud(double impactSpeed) {
    if (!_canPlaySfx) return;
    if (impactSpeed < _minBackboardSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastBackboardUs < 80000) return; // 80ms debounce
    _lastBackboardUs = now;

    final volume = (impactSpeed / 7.0).clamp(0.35, 1.0);
    _safePlay(Sfx.backboard, volume);
    _safeHaptic(HapticFeedback.mediumImpact);
  }

  /// Triggers a crisp nylon net swish whoosh on clean baskets.
  static void playSwish() {
    if (!_canPlaySfx) return;
    _safePlay(Sfx.swish, 1.0);
    _safeHaptic(HapticFeedback.selectionClick);
  }

  /// Triggers a warm hardwood court floor bounce with velocity-scaled volume and light haptics.
  static void playFloorBounce(double impactSpeed) {
    if (!_canPlaySfx) return;
    if (impactSpeed < _minBounceSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastBounceUs < 60000) return; // 60ms debounce
    _lastBounceUs = now;

    final volume = (impactSpeed / 6.5).clamp(0.20, 1.0);
    _safePlay(Sfx.bounce, volume);

    if (impactSpeed > 2.0) {
      _safeHaptic(HapticFeedback.lightImpact);
    }
  }

  /// Triggers the arena shot-clock buzzer and long haptic vibration at 00:00.
  static void playBuzzer() {
    if (!_canPlaySfx) return;
    _safePlay(Sfx.buzzer, 1.0);
    _safeHaptic(HapticFeedback.vibrate);
  }

  static void _safePlay(Sfx sfx, double volume) {
    final effectiveVolume = (volume * masterVolume * sfxVolume).clamp(
      0.0,
      1.0,
    );
    if (effectiveVolume <= 0.001) return;
    try {
      _backend.playSfx(sfx, effectiveVolume);
    } catch (e) {
      debugPrint('[AudioEngine] Playback error: $e');
    }
  }

  static void _safeHaptic(Future<void> Function() hapticCall) {
    // Avoid navigator.vibrate DOM IPC overhead on Web/PWA.
    if (kIsWeb) return;
    try {
      hapticCall();
    } catch (_) {}
  }

  /// Releases all audio resources and stops music.
  static void dispose() {
    _backend.dispose();
    _musicStarted = false;
    _sfxLoaded = false;
    _clock
      ..stop()
      ..reset();
    _lastBounceUs = 0;
    _lastRimUs = 0;
    _lastBackboardUs = 0;
    _initialized = false;
    _audioUnlocked = false;
  }
}
