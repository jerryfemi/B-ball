import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_backend.dart';

AudioBackend createAudioBackend() => WebAudioBackend();

// ── Minimal browser bindings (dart:js_interop, no extra packages) ──────────

extension type _AudioContext._(JSObject _) implements JSObject {
  external String get state;
  external double get currentTime;
  external JSObject get destination;
  external JSPromise<JSAny?> resume();
  external _GainNode createGain();
  external _BufferSource createBufferSource();
  external _AudioBuffer createBuffer(int channels, int length, num sampleRate);
  external JSPromise<_AudioBuffer> decodeAudioData(JSArrayBuffer data);
  external _AudioNode createMediaElementSource(_AudioElement element);
}

extension type _AudioNode._(JSObject _) implements JSObject {
  external JSObject connect(JSObject destination);
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(num v);
}

extension type _GainNode._(JSObject _) implements _AudioNode {
  external _AudioParam get gain;
}

extension type _AudioBuffer._(JSObject _) implements JSObject {}

extension type _BufferSource._(JSObject _) implements _AudioNode {
  external set buffer(_AudioBuffer b);
  external void start([num when]);
}

extension type _AudioElement._(JSObject _) implements JSObject {
  external set src(String v);
  external set loop(bool v);
  external set preload(String v);
  external bool get paused;
  external JSPromise<JSAny?> play();
  external void pause();
  external void load();
  external void removeAttribute(String name);
  external void setAttribute(String name, String value);
}

/// Browser-native audio for the web build.
///
///  • Sound effects: decoded once into Web Audio buffers. Each play is a
///    one-shot buffer source → gain → speakers, mixed on the browser's audio
///    thread: instant, overlapping, unaffected by game-frame hitches.
///  • Music: one reusable `<audio>` element that streams the track (no big
///    download or decode up front), routed through a Web Audio gain node so
///    the volume slider also works on iPhones (iOS ignores element.volume).
///
/// Hot-path note: [playSfx] makes two tiny native nodes per sound. Web Audio
/// source nodes are single-use by design and are freed by the browser, not
/// by Dart's garbage collector.
class WebAudioBackend implements AudioBackend {
  _AudioContext? _ctx;
  JSObject? _sfxOut;
  final Map<Sfx, _AudioBuffer> _buffers = {};

  _AudioElement? _musicEl;
  _GainNode? _musicGain;
  String? _musicKey;
  bool _wantMusicPlaying = false;
  double _musicVolume = 0.4;

  @override
  Future<void> init() async {
    if (_ctx != null) return;
    _applyAudioSession();
    final ctxCtor = (globalContext['AudioContext'] ??
        globalContext['webkitAudioContext']) as JSFunction?;
    if (ctxCtor == null) {
      throw StateError('Web Audio is not supported in this browser.');
    }
    final ctx = ctxCtor.callAsConstructor<_AudioContext>();
    _ctx = ctx;
    _sfxOut = ctx.destination;
  }

  /// iPhones: let the game's sound play even when the ring/silent switch is
  /// on silent (otherwise Safari mutes all Web Audio, which players reported
  /// as "the music doesn't play"). Safari 16.4+; ignored elsewhere.
  static void _applyAudioSession() {
    try {
      final navigator = globalContext['navigator'] as JSObject?;
      final session = navigator?['audioSession'] as JSObject?;
      session?['type'] = 'playback'.toJS;
    } catch (_) {}
  }

  @override
  Future<void> loadSfx(Map<Sfx, String> assetKeys) async {
    final ctx = _ctx;
    if (ctx == null) return;
    await Future.wait(
      assetKeys.entries.map((entry) async {
        if (_buffers.containsKey(entry.key)) return;
        try {
          final data = await rootBundle.load(entry.value);
          // decodeAudioData takes ownership of the bytes: hand it a copy.
          final bytes = Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          final buffer = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
          _buffers[entry.key] = buffer;
        } catch (e) {
          debugPrint('[WebAudio] Could not decode ${entry.value}: $e');
        }
      }),
    );
  }

  @override
  void playSfx(Sfx sfx, double volume) {
    final ctx = _ctx;
    final out = _sfxOut;
    final buffer = _buffers[sfx];
    if (ctx == null || out == null || buffer == null) return;
    // A suspended context would queue the sound and burst it out later.
    if (ctx.state != 'running') return;
    try {
      final gain = ctx.createGain();
      gain.gain.value = volume;
      gain.connect(out);
      final source = ctx.createBufferSource();
      source.buffer = buffer;
      source.connect(gain);
      source.start();
    } catch (_) {}
  }

  // ── Music ────────────────────────────────────────────────────────────────

  void _ensureMusicElement() {
    if (_musicEl != null) return;
    final ctx = _ctx;
    final document = globalContext['document'] as JSObject;
    final el = document.callMethod<_AudioElement>(
      'createElement'.toJS,
      'audio'.toJS,
    );
    el.loop = true;
    el.preload = 'auto';
    // iOS: play inline, never take over the screen.
    el.setAttribute('playsinline', '');
    _musicEl = el;
    if (ctx != null) {
      try {
        final gain = ctx.createGain();
        gain.gain.value = _musicVolume;
        gain.connect(ctx.destination);
        ctx.createMediaElementSource(el).connect(gain);
        _musicGain = gain;
      } catch (e) {
        // Fallback: plain element (volume control limited on iOS).
        debugPrint('[WebAudio] Music routing fallback: $e');
      }
    }
  }

  @override
  Future<void> setMusicTrack(String assetKey) async {
    _ensureMusicElement();
    final el = _musicEl!;
    if (_musicKey == assetKey) return;
    _musicKey = assetKey;
    el.src = ui_web.assetManager.getAssetUrl(assetKey);
    if (_wantMusicPlaying) _playElement();
  }

  @override
  void setMusicPlaying(bool playing) {
    _wantMusicPlaying = playing;
    final el = _musicEl;
    if (el == null || _musicKey == null) return;
    if (playing) {
      _playElement();
    } else if (!el.paused) {
      el.pause();
    }
  }

  void _playElement() {
    final el = _musicEl;
    if (el == null) return;
    try {
      // Rejected before the first tap on mobile; unlock() retries.
      el.play().toDart.catchError((Object _) => null);
    } catch (_) {}
  }

  @override
  void setMusicVolume(double volume) {
    _musicVolume = volume;
    final gain = _musicGain;
    if (gain != null) gain.gain.value = volume;
  }

  @override
  void unloadMusic() {
    _wantMusicPlaying = false;
    _musicKey = null;
    final el = _musicEl;
    if (el == null) return;
    try {
      el.pause();
      // Dropping the source stops any further downloading.
      el.removeAttribute('src');
      el.load();
    } catch (_) {}
  }

  @override
  void unlock() {
    final ctx = _ctx;
    if (ctx == null) return;
    try {
      if (ctx.state != 'running') {
        ctx.resume().toDart.catchError((Object _) => null);
      }
      // Classic iOS unlock: play one silent sample inside the tap.
      final source = ctx.createBufferSource();
      source.buffer = ctx.createBuffer(1, 1, 22050);
      source.connect(ctx.destination);
      source.start();
    } catch (_) {}
    if (_wantMusicPlaying) _playElement();
  }

  @override
  bool get isUnlocked {
    final ctx = _ctx;
    if (ctx == null || ctx.state != 'running') return false;
    final el = _musicEl;
    if (_wantMusicPlaying && el != null && _musicKey != null && el.paused) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    unloadMusic();
    _buffers.clear();
    try {
      _ctx?.callMethod('close'.toJS);
    } catch (_) {}
    _ctx = null;
    _sfxOut = null;
    _musicEl = null;
    _musicGain = null;
  }
}
