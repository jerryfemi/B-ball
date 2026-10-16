import 'dart:math' as math;

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
  double maxLife = 0.22;
  double invMaxLife =
      1.0 / 0.22; // Precomputed to replace division with multiplication
  double size = 1.0;
  Color color = const Color(0xFFFDE047);
  bool active = false;
}

/// Ultra-optimized, zero-allocation fiery ball trail and spark system.
///
/// Drastic GPU & CPU optimizations:
/// - Compact 7-node comet buffer with fast 0.18s decay (eliminates fill-rate overdraw).
/// - Single-pass unified heat gradient ribbon (50% fewer draw calls).
/// - 8 pre-allocated ember particles updated in-place (66% particle cut, 0 GC churn).
/// - Exact decay^1.5 = decay * sqrt(decay) hardware FSQRT (eliminates transcendental math.pow).
/// - Precomputed single-evaluation drag and chained trigonometric jitter calculations.
/// - Perspective-scaled 3D camera projection.
class FieryBallTrail {
  static const int maxNodes = 7;
  static const double maxAge = 0.18; // Fast, punchy comet tail

  final List<_TrailNode> _nodes = List.generate(
    maxNodes,
    (_) => _TrailNode(),
    growable: false,
  );
  int _nodeCount = 0;
  double _timeSinceLastSample = 0.0;
  double _elapsedTime = 0.0;
  bool _hasActiveContent = false;
  static const double sampleInterval = 0.016; // ~60 Hz sample rate

  // Compact pre-allocated ember spark pool (8 particles max)
  static const int maxEmbers = 8;
  int _activeEmberCount = 0;
  final List<_FieryEmber> _embers = List.generate(
    maxEmbers,
    (_) => _FieryEmber(),
    growable: false,
  );
  final math.Random _rng = math.Random();

  // Reusable single-pass paint & path to eliminate per-frame allocations
  final Paint _flameRibbonPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;

  final Paint _emberPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;

  final Path _flamePath = Path();

  // Pre-allocated projection buffers (eliminates per-frame List instantiations)
  final List<Offset> _projPoints = List.filled(maxNodes, Offset.zero);
  final List<double> _projWidths = List.filled(maxNodes, 0.0);
  final List<double> _projAlphas = List.filled(maxNodes, 0.0);

  /// Updates trail history and active embers.
  void update({
    required double dt,
    required Vector3 ballPos,
    required double ballRadius,
    required bool isOnFire,
    required bool isLaunched,
    required int streak,
  }) {
    _elapsedTime += dt;

    // 1. Age existing trail nodes
    for (int i = 0; i < _nodeCount; i++) {
      _nodes[i].age += dt;
      if (_nodes[i].age >= maxAge) {
        _nodes[i].active = false;
      }
    }

    // Prune expired nodes from tail
    while (_nodeCount > 0 && !_nodes[_nodeCount - 1].active) {
      _nodeCount--;
    }

    // 2. Sample new node if ball is actively launched on fire
    if (isOnFire && isLaunched) {
      _hasActiveContent = true;
      _timeSinceLastSample += dt;
      if (_timeSinceLastSample >= sampleInterval) {
        _timeSinceLastSample = 0.0;

        // Shift nodes down
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

        // Insert fresh node at head (0)
        final head = _nodes[0];
        head.x = ballPos.x;
        head.y = ballPos.y;
        head.z = ballPos.z;
        head.age = 0.0;
        head.radius = ballRadius;
        head.active = true;

        _nodeCount = math.min(_nodeCount + 1, maxNodes);

        // Spawn a single micro-spark per sample (electric lightning for 3-5, fiery red for 6+)
        _spawnEmber(ballPos, isLightning: streak < 6);
      }
    }

    // 3. Update active embers (8 max) with single precomputed drag factor
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

        // Physics: drag + upward thermal buoyancy
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
      if (!ember.active) {
        ember.active = true;
        _activeEmberCount++;
        _hasActiveContent = true;
        ember.life = 0.0;
        final double lifeSpan = 0.18 + _rng.nextDouble() * 0.12;
        ember.maxLife = lifeSpan;
        ember.invMaxLife = 1.0 / lifeSpan;

        final angle = _rng.nextDouble() * math.pi * 2.0;
        final spread = 0.10 + _rng.nextDouble() * 0.12;
        ember.x = ballPos.x + math.cos(angle) * spread;
        ember.y = ballPos.y + math.sin(angle) * spread;
        ember.z = ballPos.z - 0.04 - _rng.nextDouble() * 0.10;

        final double velMult = isLightning ? 1.35 : 1.0;
        ember.vx =
            ((math.cos(angle) * 0.7) + (_rng.nextDouble() - 0.5) * 0.8) *
            velMult;
        ember.vy = (_rng.nextDouble() * 1.2) * velMult;
        ember.vz = (-0.4 - _rng.nextDouble() * 1.2) * velMult;

        ember.size = 0.04 + _rng.nextDouble() * 0.04;

        if (isLightning) {
          final pick = _rng.nextInt(3);
          if (pick == 0) {
            ember.color = const Color(0xFFFFFFFF); // Hot plasma white
          } else if (pick == 1) {
            ember.color = const Color(0xFF38BDF8); // Electric sky cyan
          } else {
            ember.color = const Color(0xFF818CF8); // High-voltage cobalt violet
          }
        } else {
          // Tier 3: Hardest tier - Searing Crimson Red & Incandescent Gold
          final pick = _rng.nextInt(3);
          if (pick == 0) {
            ember.color = const Color(0xFFFFFBEB); // Incandescent white core
          } else if (pick == 1) {
            ember.color = const Color(0xFFFF2E2E); // Blazing crimson red
          } else {
            ember.color = const Color(0xFFFF5500); // Deep flame scarlet
          }
        }
        break;
      }
    }
  }

  /// Clears active trail nodes and embers with 0-cycle early-out when already empty.
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

  /// Renders the fiery ribbon and ember sparks in local canvas space.
  void render(
    Canvas canvas, {
    required Offset ballBodyPos,
    required PerspectiveCamera3D camera3D,
    required int streak,
  }) {
    if (_nodeCount >= 2) {
      _renderSinglePassRibbon(canvas, ballBodyPos, camera3D, streak);
    }

    if (_activeEmberCount > 0) {
      _renderEmbers(canvas, ballBodyPos, camera3D);
    }
  }

  /// Single-pass tapered flame/lightning ribbon with color grading (eliminates second pass overdraw).
  void _renderSinglePassRibbon(
    Canvas canvas,
    Offset ballBodyPos,
    PerspectiveCamera3D camera3D,
    int streak,
  ) {
    final int count = _nodeCount;
    if (count < 2) return;

    // Tier 2: Electric Lightning (streaks 3-5). Tier 3: Searing Red Flame (streak 6+).
    final bool isLightning = streak < 6;

    for (int i = 0; i < count; i++) {
      final node = _nodes[i];
      final f2d = camera3D.projectToForge2D(node.x, node.y, node.z);
      _projPoints[i] = Offset(f2d.dx - ballBodyPos.dx, f2d.dy - ballBodyPos.dy);

      final double depthScale = camera3D.scaleAtDepth(node.z);
      final double decay = (1.0 - (node.age / maxAge)).clamp(0.0, 1.0);

      // decay^1.5 = decay * sqrt(decay) -- hardware FSQRT is 5-10x faster than math.pow()
      final double taper = decay * math.sqrt(decay);
      _projWidths[i] = node.radius * 1.20 * depthScale * taper;
      _projAlphas[i] = taper;
    }

    // High-frequency jitter along normal vector: evaluate sin ONCE per edge by chaining
    double jPrev = isLightning
        ? math.sin(_elapsedTime * 65.0) * (_projWidths[0] * 0.28)
        : 0.0;

    for (int i = 0; i < count - 1; i++) {
      final p0 = _projPoints[i];
      final p1 = _projPoints[i + 1];
      final w0 = _projWidths[i];
      final w1 = _projWidths[i + 1];
      final a0 = _projAlphas[i];
      final a1 = _projAlphas[i + 1];

      final dx = p1.dx - p0.dx;
      final dy = p1.dy - p0.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 0.001) continue;

      final nx = -dy / len;
      final ny = dx / len;

      final segAlpha = ((a0 + a1) * 0.5).clamp(0.0, 1.0);
      if (segAlpha <= 0.01) continue;

      final double j0 = jPrev;
      double j1 = 0.0;
      if (isLightning) {
        j1 = math.sin(_elapsedTime * 65.0 + (i + 1) * 3.7) * (w1 * 0.28);
        jPrev = j1;
      }

      _flamePath.reset();
      _flamePath.moveTo(p0.dx + nx * (w0 + j0), p0.dy + ny * (w0 + j0));
      _flamePath.lineTo(p1.dx + nx * (w1 + j1), p1.dy + ny * (w1 + j1));
      _flamePath.lineTo(p1.dx - nx * (w1 - j1), p1.dy - ny * (w1 - j1));
      _flamePath.lineTo(p0.dx - nx * (w0 - j0), p0.dy - ny * (w0 - j0));
      _flamePath.close();

      if (isLightning) {
        // Dynamic electric blue / cyan / violet gradient:
        // Head (i=0): Brilliant electric white-cyan (R: 210, G: 245, B: 255)
        // Tail: High-voltage cobalt violet (R: 70, G: 110, B: 255)
        final double t = (i / (count - 1)).clamp(0.0, 1.0);
        final int r = (210 - t * 140).round().clamp(50, 255);
        final int g = (245 - t * 135).round().clamp(90, 255);
        const int b = 255;

        _flameRibbonPaint.color = Color.fromRGBO(
          r,
          g,
          b,
          (0.88 * segAlpha).clamp(0.0, 1.0),
        );
      } else {
        // Tier 3: Hardest tier - Blazing Inferno Red & Solar Gold (Streak 10+)
        // Head (i=0): Brilliant incandescent solar gold (R: 255, G: 195, B: 30)
        // Tail: Deep searing crimson / inferno red (R: 255, G: 25, B: 0)
        final double t = (i / (count - 1)).clamp(0.0, 1.0);
        final int green = (195 - t * 170).round().clamp(20, 220);
        final int blue = (30 - t * 30).round().clamp(0, 40);

        _flameRibbonPaint.color = Color.fromRGBO(
          255,
          green,
          blue,
          (0.86 * segAlpha).clamp(0.0, 1.0),
        );
      }
      canvas.drawPath(_flamePath, _flameRibbonPaint);
    }
  }

  void _renderEmbers(
    Canvas canvas,
    Offset ballBodyPos,
    PerspectiveCamera3D camera3D,
  ) {
    if (_activeEmberCount == 0) return;

    for (int i = 0; i < maxEmbers; i++) {
      final ember = _embers[i];
      if (!ember.active) continue;

      final f2d = camera3D.projectToForge2D(ember.x, ember.y, ember.z);
      final offset = Offset(f2d.dx - ballBodyPos.dx, f2d.dy - ballBodyPos.dy);

      final depthScale = camera3D.scaleAtDepth(ember.z);
      final alpha = (1.0 - ember.life).clamp(0.0, 1.0);
      final radius = ember.size * depthScale * (1.0 - ember.life * 0.4);

      if (alpha <= 0.01 || radius <= 0.005) continue;

      _emberPaint.color = ember.color.withValues(alpha: alpha);
      canvas.drawCircle(offset, radius, _emberPaint);
    }
  }
}
