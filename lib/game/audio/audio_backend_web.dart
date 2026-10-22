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
  external JSPromise<JSAny?> suspend();
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
  external double get sampleRate;
  external int get length;
  external JSFloat32Array getChannelData(int channel);
}

extension type _BufferSource._(JSObject _) implements _AudioNode {
  external set buffer(_AudioBuffer b);
  external set loop(bool v);
  external set loopStart(num seconds);
  external set loopEnd(num seconds);
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

  // ── Ambience loop (independent of music) ──
  _GainNode? _ambGain;
  String? _ambKey;
  _AudioBuffer? _ambBuffer;
  _BufferSource? _ambSource;
  int _ambGen = 0;

  /// Loop points inside the decoded ambience (seconds). Compressed audio
  /// (MP3/AAC) adds a few milliseconds of silence at each end; looping
  /// between the first and last real sample keeps the loop seamless.
  double _ambLoopStart = 0.0;
  double _ambLoopEnd = 0.0;
  bool _wantAmbPlaying = false;
  double _ambVolume = 0.3;

  /// False while the tab is hidden or the window lost focus (another app,
  /// minimised). The whole audio context is suspended then: music, ambience
  /// and effects all stop, and pick up where they were when you come back.
  bool _pageActive = true;

  @override
  Future<void> init() async {
    if (_ctx != null) return;
    _applyAudioSession();
    _watchPage();
    final ctxCtor = (globalContext['AudioContext'] ??
        globalContext['webkitAudioContext']) as JSFunction?;
    if (ctxCtor == null) {
      throw StateError('Web Audio is not supported in this browser.');
    }
    final ctx = ctxCtor.callAsConstructor<_AudioContext>();
    _ctx = ctx;
    _sfxOut = ctx.destination;
  }

  /// Listens to the page itself (more reliable on the web than Flutter's
  /// lifecycle events): tab hidden, window blurred, page hidden/shown.
  void _watchPage() {
    try {
      final doc = globalContext['document'] as JSObject?;
      if (doc == null) return;
      void update() {
        final vis = (doc['visibilityState'] as JSString?)?.toDart ?? 'visible';
        final focused = (doc.callMethod<JSBoolean?>('hasFocus'.toJS))?.toDart ?? true;
        _setPageActive(vis != 'hidden' && focused);
      }

      final JSFunction listener = ((JSAny? _) => update()).toJS;
      doc.callMethod<JSAny?>('addEventListener'.toJS, 'visibilitychange'.toJS, listener);
      for (final type in const ['blur', 'focus', 'pagehide', 'pageshow']) {
        globalContext.callMethod<JSAny?>('addEventListener'.toJS, type.toJS, listener);
      }
    } catch (e) {
      debugPrint('[WebAudio] Page visibility watch unavailable: $e');
    }
  }

  void _setPageActive(bool active) {
    if (_pageActive == active) return;
    _pageActive = active;
    final ctx = _ctx;
    if (ctx == null) return;
    try {
      if (active) {
        ctx.resume().toDart.catchError((Object _) => null);
      } else {
        ctx.suspend().toDart.catchError((Object _) => null);
      }
    } catch (_) {}
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
    if (ctx == null || !_pageActive) return;
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
    if (_wantAmbPlaying) _startAmbSource();
  }

  // ── Ambience ─────────────────────────────────────────────────────────────

  @override
  Future<void> setAmbienceTrack(String? assetKey) async {
    final ctx = _ctx;
    if (ctx == null || _ambKey == assetKey) return;
    _ambKey = assetKey;
    final gen = ++_ambGen;
    _stopAmbSource();
    _ambBuffer = null; // frees the old loop
    if (assetKey == null) return;
    try {
      final data = await rootBundle.load(assetKey);
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final buffer = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
      if (gen != _ambGen) return;
      _ambBuffer = buffer;
      _findAmbLoopPoints(buffer);
      if (_wantAmbPlaying) _startAmbSource();
    } catch (e) {
      debugPrint('[WebAudio] Ambience load failed for $assetKey: $e');
    }
  }

  /// Finds the first and last audible sample (looking at most 0.25 s in from
  /// each end) and loops between them. Runs once per decoded file.
  void _findAmbLoopPoints(_AudioBuffer buffer) {
    _ambLoopStart = 0.0;
    _ambLoopEnd = 0.0;
    try {
      final Float32List data = buffer.getChannelData(0).toDart;
      final int n = data.length;
      final double rate = buffer.sampleRate;
      if (n == 0 || rate <= 0) return;
      final int scan = (rate * 0.25).round().clamp(0, n ~/ 2);
      const double floor = 1e-4;
      int first = 0;
      while (first < scan && data[first].abs() < floor) {
        first++;
      }
      int last = n - 1;
      while (last > n - 1 - scan && data[last].abs() < floor) {
        last--;
      }
      if (last > first) {
        _ambLoopStart = first / rate;
        _ambLoopEnd = (last + 1) / rate;
      }
    } catch (_) {
      // Loop the whole buffer.
    }
  }

  void _startAmbSource() {
    final ctx = _ctx;
    final buffer = _ambBuffer;
    if (ctx == null || buffer == null || _ambSource != null) return;
    try {
      var gain = _ambGain;
      if (gain == null) {
        gain = ctx.createGain();
        gain.connect(ctx.destination);
        _ambGain = gain;
      }
      gain.gain.value = _ambVolume;
      final source = ctx.createBufferSource();
      source.buffer = buffer;
      source.loop = true;
      if (_ambLoopEnd > _ambLoopStart) {
        source.loopStart = _ambLoopStart;
        source.loopEnd = _ambLoopEnd;
      }
      source.connect(gain);
      source.start(0, _ambLoopStart);
      _ambSource = source;
    } catch (e) {
      debugPrint('[WebAudio] Ambience start failed: $e');
    }
  }

  void _stopAmbSource() {
    final source = _ambSource;
    if (source == null) return;
    _ambSource = null;
    try {
      source.stop();
    } catch (_) {}
  }

  @override
  void setAmbiencePlaying(bool playing) {
    _wantAmbPlaying = playing;
    if (playing) {
      _startAmbSource();
    } else {
      _stopAmbSource();
    }
  }

  @override
  void setAmbienceVolume(double volume) {
    _ambVolume = volume;
    final gain = _ambGain;
    if (gain != null) gain.gain.value = volume;
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
    _stopAmbSource();
    _ambBuffer = null;
    _ambKey = null;
    _ambGain = null;
    _buffers.clear();
    try {
      _ctx?.callMethod('close'.toJS);
    } catch (_) {}
    _ctx = null;
    _sfxOut = null;
    _musicGain = null;
  }
}
