import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders a subtle, temporary chalk/dust scuff mark on the brick wall
/// when a basketball impacts the back wall.
///
/// Features a faint masonry dust puff and chalk scuff that expands slightly
/// and smoothly dissolves over 1.0 second.
class WallImpactPuff extends PositionComponent {
  final double baseRadius;
  double _lifetime = 0.0;
  static const double duration = 1.0;

  WallImpactPuff({
    required Vector2 position,
    required this.baseRadius,
  }) : super(
          position: position,
          anchor: Anchor.center,
          priority: 0, // Rendered on the back wall, strictly behind the backboard (priority 1)
        );

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifetime / duration).clamp(0.0, 1.0);
    // Smooth quadratic ease-out fade
    final fade = math.pow(1.0 - progress, 1.5).toDouble();
    if (fade <= 0.01) return;

    // 1. Soft chalky rubber scuff mark on the brick wall
    final scuffRadius = baseRadius * (0.85 + progress * 0.20);
    final scuffPaint = Paint()
      ..color = Color.fromRGBO(245, 238, 228, 0.30 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 0.30);

    canvas.drawCircle(Offset.zero, scuffRadius, scuffPaint);

    // 2. Faint darker impact core
    final corePaint = Paint()
      ..color = Color.fromRGBO(45, 32, 28, 0.16 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 0.18);

    canvas.drawCircle(Offset.zero, scuffRadius * 0.60, corePaint);

    // 3. Subtle micro dust puff particles radiating outward
    final particleDistance = baseRadius * 0.65 * progress;
    final particleRadius = baseRadius * 0.10 * (1.0 - progress);
    final particlePaint = Paint()
      ..color = Color.fromRGBO(250, 245, 235, 0.25 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 0.10);

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2.0 * math.pi / 5.0) + 0.35;
      final px = math.cos(angle) * particleDistance;
      final py = math.sin(angle) * particleDistance * 0.85; // Slight perspective squash
      canvas.drawCircle(Offset(px, py), particleRadius, particlePaint);
    }
  }
}
