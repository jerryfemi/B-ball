import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── Minimal Web Audio bindings (same pattern as the basketball backend) ────

extension type _AudioContext._(JSObject _) implements JSObject {
  external String get state;
  external double get currentTime;
  external JSObject get destination;
  external JSPromise<JSAny?> resume();
  external _GainNode createGain();
  external _BufferSource createBufferSource();
  external _AudioBuffer createBuffer(int channels, int length, num sampleRate);
  external JSPromise<_AudioBuffer> decodeAudioData(JSArrayBuffer data);
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
  external _AudioParam get playbackRate;
  external void start([num when]);
}

enum _Sfx { draw, click, release, thunk, ding, thud }

/// Archery sounds on the web: synthesised WAVs (tools/make_archery_sfx.py)
/// decoded once into Web Audio buffers; each play is a one-shot
/// buffer source → gain → speakers on the browser's audio thread.
class ArcheryAudioImpl {
  static const Map<_Sfx, String> _assets = {
    _Sfx.draw: 'assets/archery/sfx_draw.wav',
    _Sfx.click: 'assets/archery/sfx_click.wav',
    _Sfx.release: 'assets/archery/sfx_release.wav',
    _Sfx.thunk: 'assets/archery/sfx_thunk.wav',
    _Sfx.ding: 'assets/archery/sfx_ding.wav',
    _Sfx.thud: 'assets/archery/sfx_thud.wav',
  };

  _AudioContext? _ctx;
  final Map<_Sfx, _AudioBuffer> _buffers = {};
  bool _loading = false;

  void init() {
    _ensureContext();
    _load();
  }

  void _ensureContext() {
    if (_ctx != null) return;
    try {
      // iPhone: mix with the player's own music and respect the silent switch.
      final navigator = globalContext['navigator'] as JSObject?;
      final session = navigator?['audioSession'] as JSObject?;
      session?['type'] = 'ambient'.toJS;
    } catch (_) {}
    try {
      final ctor = (globalContext['AudioContext'] ??
          globalContext['webkitAudioContext']) as JSFunction?;
      if (ctor != null) _ctx = ctor.callAsConstructor<_AudioContext>();
    } catch (_) {}
  }

  Future<void> _load() async {
    final ctx = _ctx;
    if (ctx == null || _loading) return;
    _loading = true;
    await Future.wait(_assets.entries.map((e) async {
      try {
        final data = await rootBundle.load(e.value);
        // decodeAudioData takes ownership of the bytes: hand it a copy.
        final bytes = Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        _buffers[e.key] = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
      } catch (err) {
        debugPrint('[ArcheryAudio] Could not decode ${e.value}: $err');
      }
    }));
  }

  /// Call from a user gesture (touch down): browsers start audio suspended.
  void unlock() {
    final ctx = _ctx;
    if (ctx == null) return;
    if (ctx.state == 'running') return;
    try {
      ctx.resume().toDart.catchError((Object _) => null);
      // Classic iOS unlock: one silent sample inside the tap.
      final source = ctx.createBufferSource();
      source.buffer = ctx.createBuffer(1, 1, 22050);
      source.connect(ctx.destination);
      source.start();
    } catch (_) {}
  }

  void _play(_Sfx sfx, double volume, {double rate = 1.0}) {
    final ctx = _ctx;
    final buffer = _buffers[sfx];
    if (ctx == null || buffer == null || ctx.state != 'running') return;
    try {
      final gain = ctx.createGain();
      gain.gain.value = volume;
      gain.connect(ctx.destination);
      final source = ctx.createBufferSource();
      source.buffer = buffer;
      if (rate != 1.0) source.playbackRate.value = rate;
      source.connect(gain);
      source.start();
    } catch (_) {}
  }

  void playDrawCreak() {
    unlock();
    _play(_Sfx.draw, 0.55);
  }

  void playFullDrawClick() => _play(_Sfx.click, 0.5);

  void playReleaseTwang() => _play(_Sfx.release, 0.9);

  /// Impact heard after the sound has travelled back from the target
  /// (~340 m/s: about 45 ms at 50 ft, 135 ms at 150 ft).
  void playImpact({
    required double distance,
    required bool isX,
    required bool hitBoss,
    required bool hitGround,
  }) {
    final int delayMs = ((distance / 340.0) * 1000).round().clamp(0, 500);
    void fire() {
      if (hitBoss) {
        _play(_Sfx.thunk, 0.95);
        if (isX) _play(_Sfx.ding, 0.55);
      } else {
        _play(_Sfx.thud, 0.7);
      }
    }

    if (delayMs == 0) {
      fire();
    } else {
      Timer(Duration(milliseconds: delayMs), fire);
    }
  }

  void dispose() {
    _buffers.clear();
    try {
      _ctx?.callMethod('close'.toJS);
    } catch (_) {}
    _ctx = null;
    _loading = false;
  }
}

ArcheryAudioImpl createAudioImpl() => ArcheryAudioImpl();
