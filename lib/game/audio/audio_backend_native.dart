import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_backend.dart';

AudioBackend createAudioBackend() => SoLoudBackend();

/// Native builds (Android/iOS/desktop): SoLoud's C++ mixer, which runs on
/// its own audio thread there. (The web build uses the browser's own audio
/// instead — see audio_backend_web.dart.)
class SoLoudBackend implements AudioBackend {
  final Map<Sfx, AudioSource> _sources = {};
  AudioSource? _musicSource;
  SoundHandle? _musicHandle;
  String? _musicKey;
  bool _wantMusicPlaying = false;
  double _musicVolume = 0.4;
  int _musicGen = 0;

  bool get _ready => SoLoud.instance.isInitialized;

  @override
  Future<void> init() async {
    if (!_ready) await SoLoud.instance.init();
  }

  @override
  Future<void> loadSfx(Map<Sfx, String> assetKeys) async {
    if (!_ready) return;
    await Future.wait(
      assetKeys.entries.map((entry) async {
        if (_sources.containsKey(entry.key)) return;
        try {
          _sources[entry.key] = await SoLoud.instance.loadAsset(
            entry.value,
            mode: LoadMode.memory,
          );
        } catch (e) {
          debugPrint('[SoLoud] Could not load ${entry.value}: $e');
        }
      }),
    );
  }

  @override
  void playSfx(Sfx sfx, double volume) {
    final source = _sources[sfx];
    if (source == null || !_ready) return;
    try {
      SoLoud.instance.play(source, volume: volume);
    } catch (_) {}
  }

  @override
  Future<void> setMusicTrack(String assetKey) async {
    if (!_ready || _musicKey == assetKey) return;
    _musicKey = assetKey;
    final gen = ++_musicGen;
    try {
      final source = await SoLoud.instance.loadAsset(
        assetKey,
        mode: LoadMode.memory,
      );
      if (gen != _musicGen) {
        unawaited(SoLoud.instance.disposeSource(source));
        return;
      }
      await _releaseMusic();
      _musicSource = source;
      _musicHandle = SoLoud.instance.play(
        source,
        volume: _musicVolume,
        looping: true,
        paused: !_wantMusicPlaying,
      );
    } catch (e) {
      debugPrint('[SoLoud] Music load error: $e');
    }
  }

  @override
  void setMusicPlaying(bool playing) {
    _wantMusicPlaying = playing;
    final handle = _musicHandle;
    if (handle == null || !_ready) return;
    try {
      if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
        // Paused voices cost the mixer nothing.
        SoLoud.instance.setPause(handle, !playing);
      }
    } catch (_) {}
  }

  @override
  void setMusicVolume(double volume) {
    _musicVolume = volume;
    final handle = _musicHandle;
    if (handle == null || !_ready) return;
    try {
      if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
        SoLoud.instance.setVolume(handle, volume);
      }
    } catch (_) {}
  }

  Future<void> _releaseMusic() async {
    final handle = _musicHandle;
    _musicHandle = null;
    if (handle != null && _ready) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
          await SoLoud.instance.stop(handle);
        }
      } catch (_) {}
    }
    final source = _musicSource;
    _musicSource = null;
    if (source != null && _ready) {
      try {
        await SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
  }

  @override
  void unloadMusic() {
    _wantMusicPlaying = false;
    _musicKey = null;
    _musicGen++;
    unawaited(_releaseMusic());
  }

  // ── Ambience ─────────────────────────────────────────────────────────────

  AudioSource? _ambSource;
  SoundHandle? _ambHandle;
  String? _ambKey;
  int _ambGen = 0;
  bool _wantAmbPlaying = false;
  double _ambVolume = 0.3;

  @override
  Future<void> setAmbienceTrack(String? assetKey) async {
    if (!_ready || _ambKey == assetKey) return;
    _ambKey = assetKey;
    final gen = ++_ambGen;
    await _releaseAmbience();
    if (assetKey == null) return;
    try {
      final source = await SoLoud.instance.loadAsset(assetKey, mode: LoadMode.memory);
      if (gen != _ambGen) {
        unawaited(SoLoud.instance.disposeSource(source));
        return;
      }
      _ambSource = source;
      _ambHandle = SoLoud.instance.play(
        source,
        volume: _ambVolume,
        looping: true,
        paused: !_wantAmbPlaying,
      );
    } catch (e) {
      debugPrint('[SoLoud] Ambience load error: $e');
    }
  }

  Future<void> _releaseAmbience() async {
    final handle = _ambHandle;
    _ambHandle = null;
    if (handle != null && _ready) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
          await SoLoud.instance.stop(handle);
        }
      } catch (_) {}
    }
    final source = _ambSource;
    _ambSource = null;
    if (source != null && _ready) {
      try {
        await SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
  }

  @override
  void setAmbiencePlaying(bool playing) {
    _wantAmbPlaying = playing;
    final handle = _ambHandle;
    if (handle == null || !_ready) return;
    try {
      if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
        SoLoud.instance.setPause(handle, !playing);
      }
    } catch (_) {}
  }

  @override
  void setAmbienceVolume(double volume) {
    _ambVolume = volume;
    final handle = _ambHandle;
    if (handle == null || !_ready) return;
    try {
      if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
        SoLoud.instance.setVolume(handle, volume);
      }
    } catch (_) {}
  }

  @override
  void unlock() {}

  @override
  bool get isUnlocked => true;

  @override
  void dispose() {
    unloadMusic();
    unawaited(_releaseAmbience());
    _sources.clear();
    if (_ready) {
      unawaited(SoLoud.instance.disposeAllSources());
      unawaited(SoLoud.instance.deinitAsync());
    }
  }
}
