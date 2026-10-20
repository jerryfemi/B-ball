import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Web Audio API minimal bindings
@JS('window')
external JSObject? get _window;

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(num v);
  external void setValueAtTime(num value, num startTime);
  external void exponentialRampToValueAtTime(num value, num endTime);
  external void linearRampToValueAtTime(num value, num endTime);
}

extension type _AudioNode._(JSObject _) implements JSObject {
  external JSObject connect(JSObject destination);
}

extension type _GainNode._(JSObject _) implements _AudioNode {
  external _AudioParam get gain;
}

extension type _OscillatorNode._(JSObject _) implements _AudioNode {
  external set type(String t);
  external _AudioParam get frequency;
  external void start([num when]);
  external void stop([num when]);
}

extension type _AudioContext._(JSObject _) implements JSObject {
  external String get state;
  external double get currentTime;
  external JSObject get destination;
  external JSPromise<JSAny?> resume();
  external _GainNode createGain();
  external _OscillatorNode createOscillator();
}

class ArcheryAudioImpl {
  _AudioContext? _ctx;

  void init() {
    _ensureContext();
  }

  void unlock() {
    _ensureContext();
    if (_ctx != null && _ctx!.state == 'suspended') {
      _ctx!.resume();
    }
  }

  void _ensureContext() {
    if (_ctx != null) return;
    try {
      final JSObject? win = _window;
      final JSFunction? ctor =
          (win?['AudioContext'] ?? win?['webkitAudioContext']) as JSFunction?;
      if (ctor != null) {
        _ctx = ctor.callAsConstructor<_AudioContext>();
      }
    } catch (_) {}
  }

  void playDrawCreak() {
    unlock();
    if (_ctx == null) return;
    try {
      final double t = _ctx!.currentTime;
      final _OscillatorNode osc = _ctx!.createOscillator();
      final _GainNode gain = _ctx!.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(160, t);
      osc.frequency.exponentialRampToValueAtTime(80, t + 0.06);

      gain.gain.setValueAtTime(0.08, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.06);

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start(t);
      osc.stop(t + 0.07);
    } catch (_) {}
  }

  void playFullDrawClick() {
    unlock();
    if (_ctx == null) return;
    try {
      final double t = _ctx!.currentTime;
      final _OscillatorNode osc = _ctx!.createOscillator();
      final _GainNode gain = _ctx!.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(1400, t);
      osc.frequency.exponentialRampToValueAtTime(800, t + 0.04);

      gain.gain.setValueAtTime(0.25, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.04);

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start(t);
      osc.stop(t + 0.05);
    } catch (_) {}
  }

  void playReleaseTwang() {
    unlock();
    if (_ctx == null) return;
    try {
      final double t = _ctx!.currentTime;
      final _OscillatorNode osc = _ctx!.createOscillator();
      final _GainNode gain = _ctx!.createGain();

      // Plucked string frequency drop (140 Hz -> 60 Hz)
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(140, t);
      osc.frequency.exponentialRampToValueAtTime(60, t + 0.22);

      gain.gain.setValueAtTime(0.40, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.25);

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start(t);
      osc.stop(t + 0.26);
    } catch (_) {}
  }

  void playImpact({
    required double distance,
    required bool isX,
    required bool hitBoss,
    required bool hitGround,
  }) {
    // Sound travel speed in air: ~340 m/s
    final int delayMs = ((distance / 340.0) * 1000).toInt().clamp(0, 500);

    Timer(Duration(milliseconds: delayMs), () {
      unlock();
      if (_ctx == null) return;

      try {
        final double t = _ctx!.currentTime;

        if (isX) {
          // X-Ring golden bell harmonic ding
          _playBell(t, 1760, 0.45);
          _playThud(t, 180, 0.35);
        } else if (hitBoss) {
          // Sharp impact thwack
          _playThud(t, 140, 0.40);
        } else if (hitGround) {
          // Dull turf thud
          _playThud(t, 65, 0.25);
        }
      } catch (_) {}
    });
  }

  void _playThud(double t, double freq, double volume) {
    if (_ctx == null) return;
    final _OscillatorNode osc = _ctx!.createOscillator();
    final _GainNode gain = _ctx!.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, t);
    osc.frequency.exponentialRampToValueAtTime(35, t + 0.16);

    gain.gain.setValueAtTime(volume, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.18);

    osc.connect(gain);
    gain.connect(_ctx!.destination);

    osc.start(t);
    osc.stop(t + 0.19);
  }

  void _playBell(double t, double freq, double volume) {
    if (_ctx == null) return;
    final _OscillatorNode osc = _ctx!.createOscillator();
    final _GainNode gain = _ctx!.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, t);

    gain.gain.setValueAtTime(volume, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.65);

    osc.connect(gain);
    gain.connect(_ctx!.destination);

    osc.start(t);
    osc.stop(t + 0.70);
  }

  void dispose() {}
}

ArcheryAudioImpl createAudioImpl() => ArcheryAudioImpl();
