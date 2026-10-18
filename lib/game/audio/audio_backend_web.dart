import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

extension type _AudioBuffer._(JSObject _) implements JSObject {
  external double get duration;
}

extension type _BufferSource._(JSObject _) implements _AudioNode {
  external set buffer(_AudioBuffer b);
  external set loop(bool v);
  external void start([num when, num offset]);
  external void stop();
}

/// Browser-native audio for the web build.
///
///  • Sound effects: decoded once into Web Audio buffers. Each play is a
///    one-shot buffer source → gain → speakers, mixed on the browser's audio
///    thread: instant, overlapping, unaffected by game-frame hitches.
///  • Music: the track (~200 KB) is decoded once by the browser (off the
///    main thread) into a buffer and looped through a gain node — the same
///    proven path as the effects, so it plays wherever the effects play, the
///    volume slider works on iPhones, and it never competes with game frames.
///    (An `<audio>` element routed into Web Audio was tried first and stayed
///    silent on some browsers.) Pause remembers the position.
///
/// Hot-path note: [playSfx] makes two tiny native nodes per sound. Web Audio
/// source nodes are single-use by design and are freed by the browser, not
/// by Dart's garbage collector.
class WebAudioBackend implements AudioBackend {
  _AudioContext? _ctx;
  JSObject? _sfxOut;
  final Map<Sfx, _AudioBuffer> _buffers = {};

  _GainNode? _musicGain;
  String? _musicKey;
  _AudioBuffer? _musicBuffer;
  _BufferSource? _musicSource;
  int _musicGen = 0;
  bool _wantMusicPlaying = false;
  double _musicVolume = 0.4;

  /// Playback position bookkeeping for pause/resume (seconds).
  double _musicStartedAt = 0.0; // ctx.currentTime when the source started
  double _musicOffset = 0.0; // position within the track at that moment

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

  /// iPhones: 'ambient' = the game's sound MIXES with other apps (players can
  /// keep their own Spotify/Apple Music playing and still hear the swishes)
  /// and respects the ring/silent switch, like most mobile games.
  /// ('playback' would ignore the silent switch but pause the player's own
  /// music the moment the game made a sound.) Safari 16.4+; ignored elsewhere.
  static void _applyAudioSession() {
    try {
      final navigator = globalContext['navigator'] as JSObject?;
      final session = navigator?['audioSession'] as JSObject?;
      session?['type'] = 'ambient'.toJS;
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

  _GainNode? _ensureMusicGain() {
    final ctx = _ctx;
    if (ctx == null) return null;
    final existing = _musicGain;
    if (existing != null) return existing;
    final gain = ctx.createGain();
    gain.gain.value = _musicVolume;
    gain.connect(ctx.destination);
    _musicGain = gain;
    return gain;
  }

  @override
  Future<void> setMusicTrack(String assetKey) async {
    final ctx = _ctx;
    if (ctx == null || _musicKey == assetKey) return;
    _musicKey = assetKey;
    final gen = ++_musicGen;
    _stopMusicSource();
    _musicBuffer = null;
    _musicOffset = 0.0;
    try {
      final data = await rootBundle.load(assetKey);
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final buffer = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
      if (gen != _musicGen) return; // track changed or unloaded meanwhile
      _musicBuffer = buffer;
      if (_wantMusicPlaying) _startMusicSource();
    } catch (e) {
      debugPrint('[WebAudio] Music load failed for $assetKey: $e');
    }
  }

  void _startMusicSource() {
    final ctx = _ctx;
    final buffer = _musicBuffer;
    final gain = _ensureMusicGain();
    if (ctx == null || buffer == null || gain == null) return;
    if (_musicSource != null) return; // already playing
    try {
      final source = ctx.createBufferSource();
      source.buffer = buffer;
      source.loop = true;
      source.connect(gain);
      final duration = buffer.duration;
      final offset = duration > 0 ? _musicOffset % duration : 0.0;
      source.start(0, offset);
      _musicSource = source;
      _musicStartedAt = ctx.currentTime;
      _musicOffset = offset;
    } catch (e) {
      debugPrint('[WebAudio] Music start failed: $e');
    }
  }

  /// Stops the looping source, remembering where it was for resume.
  void _stopMusicSource() {
    final source = _musicSource;
    if (source == null) return;
    _musicSource = null;
    final ctx = _ctx;
    if (ctx != null) {
      _musicOffset += ctx.currentTime - _musicStartedAt;
    }
    try {
      source.stop();
    } catch (_) {}
  }

  @override
  void setMusicPlaying(bool playing) {
    _wantMusicPlaying = playing;
    if (playing) {
      _startMusicSource();
    } else {
      _stopMusicSource();
    }
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
    _musicGen++;
    _stopMusicSource();
    _musicBuffer = null; // frees the decoded track
    _musicOffset = 0.0;
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
    if (_wantMusicPlaying) _startMusicSource();
  }

  @override
  bool get isUnlocked {
    final ctx = _ctx;
    // Music needs no separate unlock: its buffer source plays through the
    // same (now running) context as the effects.
    return ctx != null && ctx.state == 'running';
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
    _musicGain = null;
  }
}
