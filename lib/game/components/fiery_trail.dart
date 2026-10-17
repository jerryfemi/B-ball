import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../physics/perspective_camera.dart';

/// Historical 3D point along the ball's flight path.
class _TrailNode {
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
  double age = 0.0; // Seconds elapsed since recorded
  double radius = 0.0;
  bool active = false;
}

/// Lightweight, pre-allocated ember spark particle.
class _FieryEmber {
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
  double vx = 0.0;
  double vy = 0.0;
  double vz = 0.0;
  double life = 0.0; // 0.0 (fresh) to 1.0 (dead)
  double invMaxLife = 1.0 / 0.22;
  double size = 1.0;
  int colorIndex = 0; // into _emberColors
  bool active = false;
}

/// Streak flight effect: a comet/flame plume wrapped around the ball plus
/// ember sparks. Lightning for streaks 3–5, fire for 6–9, inferno for 10+.
///
/// Shape (tuned after playtesting — the old long, thin, wiggling tail read as
/// "a sperm"):
/// - Short plume (0.12s of travel) that starts at the ball's FULL width, so the
///   ball looks like it is burning rather than being followed by a tail.
/// - Gradual taper that stays fat, then fades softly (no thin thread).
/// - Two layers: a wide dim outer glow + a narrow bright core for volume.
/// - Lightning crackles with small random jagged offsets (no smooth sine
///   "swimming"); fire doesn't wiggle at all, it flickers in brightness.
///
/// Zero allocations per frame: projections go into typed arrays, the path is
/// reused, and every color-with-alpha comes from a precomputed lookup table.
class FieryBallTrail {
  static const int maxNodes = 8;
  static const double maxAge = 0.12; // short, punchy plume
  static const double sampleInterval = 0.016; // ~60 Hz sample rate

  final List<_TrailNode> _nodes = List.generate(
    maxNodes,
    (_) => _TrailNode(),
    growable: false,
  );
  int _nodeCount = 0;
  double _timeSinceLastSample = 0.0;
  bool _hasActiveContent = false;

  static const int maxEmbers = 8;
  int _activeEmberCount = 0;
  final List<_FieryEmber> _embers = List.generate(
    maxEmbers,
    (_) => _FieryEmber(),
    growable: false,
  );
  final math.Random _rng = math.Random();

  // Reusable paints & path
  final Paint _plumePaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  final Paint _emberPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  final Path _path = Path();

  // Per-frame projection buffers (index 0 = ball center, 1.. = trail nodes)
  static const int _maxPoints = maxNodes + 1;
  final Float64List _px = Float64List(_maxPoints);
  final Float64List _py = Float64List(_maxPoints);
  final Float64List _halfW = Float64List(_maxPoints);
  final Float64List _alpha = Float64List(_maxPoints);
  final Float64List _jitter = Float64List(_maxPoints);

  // ── Precomputed color tables ──────────────────────────────────────────────
  static const int _alphaSteps = 32;
  static const int _paletteLightning = 0;
  static const int _paletteFire = 1;
  static const int _paletteInferno = 2;

  /// [palette][layer 0=outer,1=core] → (head color, tail color)
  static const List<List<List<Color>>> _plumeStops = [
    [
      [Color(0xFF7DD3FC), Color(0xFF6366F1)], // lightning outer: cyan → violet
      [Color(0xFFF0F9FF), Color(0xFFA5B4FC)], // lightning core: plasma white
    ],
    [
      [Color(0xFFFFB020), Color(0xFFFF3D00)], // fire outer: gold → flame red
      [Color(0xFFFFF4D6), Color(0xFFFFB347)], // fire core: white-hot → amber
    ],
    [
      [Color(0xFFFFC31E), Color(0xFFD70A0A)], // inferno outer: solar gold → crimson
      [Color(0xFFFFFBEB), Color(0xFFFF6A00)], // inferno core
    ],
  ];

  /// [palette][layer][point index][alpha step]
  static final List<List<List<List<Color>>>> _plumeColors = List.generate(
    _plumeStops.length,
    (p) => List.generate(
      2,
      (layer) => List.generate(
        _maxPoints,
        (i) {
          final t = i / (_maxPoints - 1);
          final c = Color.lerp(
            _plumeStops[p][layer][0],
            _plumeStops[p][layer][1],
            t,
          )!;
          return List.generate(
            _alphaSteps,
            (a) => c.withValues(alpha: a / (_alphaSteps - 1)),
            growable: false,
          );
        },
        growable: false,
      ),
      growable: false,
    ),
    growable: false,
  );

  static const List<Color> _emberBase = [
    Color(0xFFFFFFFF), // lightning: plasma white
    Color(0xFF38BDF8), // lightning: electric cyan
    Color(0xFF818CF8), // lightning: cobalt violet
    Color(0xFFFFFBEB), // fire: incandescent white
    Color(0xFFFF2E2E), // fire: crimson
    Color(0xFFFF7A00), // fire: flame orange
  ];

  static final List<List<Color>> _emberColors = List.generate(
    _emberBase.length,
    (c) => List.generate(
      _alphaSteps,
      (a) => _emberBase[c].withValues(alpha: a / (_alphaSteps - 1)),
      growable: false,
    ),
    growable: false,
  );

  static int _step(double a) =>
      (a.clamp(0.0, 1.0) * (_alphaSteps - 1)).round();

  // ── Update ────────────────────────────────────────────────────────────────

  /// Updates trail history and active embers.
  void update({
    required double dt,
    required Vector3 ballPos,
    required double ballRadius,
    required bool isOnFire,
    required bool isLaunched,
    required int streak,
  }) {
    // 1. Age existing trail nodes
    for (int i = 0; i < _nodeCount; i++) {
      _nodes[i].age += dt;
      if (_nodes[i].age >= maxAge) _nodes[i].active = false;
    }
    while (_nodeCount > 0 && !_nodes[_nodeCount - 1].active) {
      _nodeCount--;
    }

    // 2. Sample a new node while the ball is launched on fire
    if (isOnFire && isLaunched) {
      _hasActiveContent = true;
      _timeSinceLastSample += dt;
      if (_timeSinceLastSample >= sampleInterval) {
        _timeSinceLastSample = 0.0;

        final int countToKeep = math.min(_nodeCount, maxNodes - 1);
        for (int i = countToKeep; i > 0; i--) {
          final src = _nodes[i - 1];
          final dst = _nodes[i];
          dst.x = src.x;
          dst.y = src.y;
          dst.z = src.z;
          dst.age = src.age;
          dst.radius = src.radius;
          dst.active = src.active;
        }

        final head = _nodes[0];
        head.x = ballPos.x;
        head.y = ballPos.y;
        head.z = ballPos.z;
        head.age = 0.0;
        head.radius = ballRadius;
        head.active = true;
        _nodeCount = math.min(_nodeCount + 1, maxNodes);

        _spawnEmber(ballPos, isLightning: streak < 6);
      }
    }

    // 3. Update embers (drag + upward thermal buoyancy)
    if (_activeEmberCount > 0) {
      final double drag = math.exp(-3.0 * dt);
      final double rise = 2.0 * dt;
      for (int i = 0; i < maxEmbers; i++) {
        final ember = _embers[i];
        if (!ember.active) continue;
        ember.life += dt * ember.invMaxLife;
        if (ember.life >= 1.0) {
          ember.active = false;
          _activeEmberCount--;
          continue;
        }
        ember.x += ember.vx * dt;
        ember.y += ember.vy * dt;
        ember.z += ember.vz * dt;
        ember.vy += rise;
        ember.vx *= drag;
        ember.vz *= drag;
      }
    }
  }

  void _spawnEmber(Vector3 ballPos, {required bool isLightning}) {
    for (int i = 0; i < maxEmbers; i++) {
      final ember = _embers[i];
      if (ember.active) continue;
      ember.active = true;
      _activeEmberCount++;
      _hasActiveContent = true;
      ember.life = 0.0;
      ember.invMaxLife = 1.0 / (0.18 + _rng.nextDouble() * 0.12);

      final angle = _rng.nextDouble() * math.pi * 2.0;
      final spread = 0.10 + _rng.nextDouble() * 0.12;
      ember.x = ballPos.x + math.cos(angle) * spread;
      ember.y = ballPos.y + math.sin(angle) * spread;
      ember.z = ballPos.z - 0.04 - _rng.nextDouble() * 0.10;

      final double velMult = isLightning ? 1.35 : 1.0;
      ember.vx =
          ((math.cos(angle) * 0.7) + (_rng.nextDouble() - 0.5) * 0.8) * velMult;
      ember.vy = (_rng.nextDouble() * 1.2) * velMult;
      ember.vz = (-0.4 - _rng.nextDouble() * 1.2) * velMult;
      ember.size = 0.04 + _rng.nextDouble() * 0.04;
      ember.colorIndex = (isLightning ? 0 : 3) + _rng.nextInt(3);
      break;
    }
  }

  /// Clears active trail nodes and embers (0-cycle early-out when empty).
  void reset() {
    if (!_hasActiveContent) return;
    _hasActiveContent = false;
    _nodeCount = 0;
    _activeEmberCount = 0;
    for (int i = 0; i < maxNodes; i++) {
      _nodes[i].active = false;
    }
    for (int i = 0; i < maxEmbers; i++) {
      _embers[i].active = false;
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────

  /// Renders the plume and embers in the ball's local canvas space.
  /// [emberDensity] 1.0 = every ember, 0.5 = every other one (lighter tiers).
  void render(
    Canvas canvas, {
    required Offset ballBodyPos,
    required PerspectiveCamera3D camera3D,
    required int streak,
    double emberDensity = 1.0,
  }) {
    if (_nodeCount >= 1) {
      _renderPlume(canvas, ballBodyPos, camera3D, streak);
    }
    if (_activeEmberCount > 0) {
      _renderEmbers(canvas, ballBodyPos, camera3D, emberDensity);
    }
  }

  void _renderPlume(
    Canvas canvas,
    Offset ballBodyPos,
    PerspectiveCamera3D cam,
    int streak,
  ) {
    final bool isLightning = streak < 6;
    final int palette = streak >= 10
        ? _paletteInferno
        : (isLightning ? _paletteLightning : _paletteFire);

    // Point 0 is the ball itself, so the plume hugs the ball (no "neck").
    final head = _nodes[0];
    final headHalfW =
        head.radius * 1.38 * cam.scaleAtDepth(head.z) * 0.95;
    _px[0] = 0.0;
    _py[0] = 0.0;
    _halfW[0] = headHalfW;
    _alpha[0] = 1.0;
    _jitter[0] = 0.0;

    final int count = _nodeCount + 1;
    for (int k = 1; k < count; k++) {
      final node = _nodes[k - 1];
      cam.projectToForge2DFast(node.x, node.y, node.z);
      _px[k] = cam.projX - ballBodyPos.dx;
      _py[k] = cam.projY - ballBodyPos.dy;

      final decay = (1.0 - node.age / maxAge).clamp(0.0, 1.0);
      final along = k / (count - 1);
      // Stays fat (decay^0.6) and narrows gently toward the end.
      final ballHalfW =
          node.radius * 1.38 * cam.scaleAtDepth(node.z) * 0.95;
      _halfW[k] =
          ballHalfW * math.pow(decay, 0.6).toDouble() * (1.0 - 0.45 * along);
      _alpha[k] = math.pow(decay, 0.8).toDouble();
      // Lightning crackles with small random jags (re-rolled every frame);
      // fire stays smooth.
      _jitter[k] = isLightning
          ? (_rng.nextDouble() * 2.0 - 1.0) * _halfW[k] * 0.22
          : 0.0;
    }

    // Fire flickers in brightness instead of wiggling.
    final double flicker = isLightning ? 1.0 : 0.88 + _rng.nextDouble() * 0.12;

    // Layer 0: wide dim glow. Layer 1: narrow bright core.
    for (int layer = 0; layer < 2; layer++) {
      final widthScale = layer == 0 ? 1.0 : 0.42;
      final layerAlpha = (layer == 0 ? 0.40 : 0.85) * flicker;
      final colors = _plumeColors[palette][layer];

      for (int k = 0; k < count - 1; k++) {
        final x0 = _px[k], y0 = _py[k];
        final x1 = _px[k + 1], y1 = _py[k + 1];
        final dx = x1 - x0;
        final dy = y1 - y0;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 0.0005) continue;
        final nx = -dy / len;
        final ny = dx / len;

        final w0 = _halfW[k] * widthScale;
        final w1 = _halfW[k + 1] * widthScale;
        final j0 = _jitter[k];
        final j1 = _jitter[k + 1];
        final a = (_alpha[k] + _alpha[k + 1]) * 0.5 * layerAlpha;
        if (a <= 0.01) continue;

        _path
          ..reset()
          ..moveTo(x0 + nx * (w0 + j0), y0 + ny * (w0 + j0))
          ..lineTo(x1 + nx * (w1 + j1), y1 + ny * (w1 + j1))
          ..lineTo(x1 - nx * (w1 - j1), y1 - ny * (w1 - j1))
          ..lineTo(x0 - nx * (w0 - j0), y0 - ny * (w0 - j0))
          ..close();
        _plumePaint.color = colors[k][_step(a)];
        canvas.drawPath(_path, _plumePaint);
      }
    }
  }

  void _renderEmbers(
    Canvas canvas,
    Offset ballBodyPos,
    PerspectiveCamera3D cam,
    double emberDensity,
  ) {
    // Lighter tiers draw every other ember (same look, half the overdraw).
    final int stride = emberDensity >= 0.99 ? 1 : 2;
    for (int i = 0; i < maxEmbers; i += stride) {
      final ember = _embers[i];
      if (!ember.active) continue;

      final alpha = 1.0 - ember.life;
      final radius =
          ember.size * cam.scaleAtDepth(ember.z) * (1.0 - ember.life * 0.4);
      if (alpha <= 0.01 || radius <= 0.005) continue;

      cam.projectToForge2DFast(ember.x, ember.y, ember.z);
      _emberPaint.color = _emberColors[ember.colorIndex][_step(alpha)];
      canvas.save();
      canvas.translate(cam.projX - ballBodyPos.dx, cam.projY - ballBodyPos.dy);
      canvas.drawCircle(Offset.zero, radius, _emberPaint);
      canvas.restore();
    }
  }
}
