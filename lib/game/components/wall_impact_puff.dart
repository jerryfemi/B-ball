import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders a subtle, temporary chalk/dust scuff mark on the brick wall
/// when a basketball impacts the back wall.
///
/// Features a faint masonry dust puff and chalk scuff that expands slightly
/// and smoothly dissolves over 1.0 second.
///
/// Highly optimized: Uses statically pre-baked radial soft-sprites rather than
/// per-frame [MaskFilter.blur] calls, eliminating GPU render pass stalls.
class WallImpactPuff extends PositionComponent {
  final double baseRadius;
  double _lifetime = 0.0;
  static const double duration = 1.0;

  // Statically cached radial textures for scuff and particles
  static ui.Image? _cachedWhitePuff;
  static ui.Image? _cachedCorePuff;
  static const int _textureSize = 64;
  static const Rect _srcRect = Rect.fromLTWH(0, 0, 64, 64);
  static final Paint _sharedSpritePaint = Paint()..filterQuality = FilterQuality.low;

  static void _ensurePuffSprites() {
    if (_cachedWhitePuff != null) return;

    // 1. White chalk/dust radial texture
    final whiteRec = ui.PictureRecorder();
    final whiteCanvas = Canvas(whiteRec);
    final whitePaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(32, 32),
        32,
        const [
          Color.fromRGBO(245, 238, 228, 0.90),
          Color.fromRGBO(245, 238, 228, 0.40),
          Color.fromRGBO(245, 238, 228, 0.0),
        ],
        const [0.0, 0.45, 1.0],
      );
    whiteCanvas.drawCircle(const Offset(32, 32), 32, whitePaint);
    _cachedWhitePuff = whiteRec.endRecording().toImageSync(_textureSize, _textureSize);

    // 2. Faint dark impact core radial texture
    final darkRec = ui.PictureRecorder();
    final darkCanvas = Canvas(darkRec);
    final darkPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(32, 32),
        32,
        const [
          Color.fromRGBO(45, 32, 28, 0.70),
          Color.fromRGBO(45, 32, 28, 0.25),
          Color.fromRGBO(45, 32, 28, 0.0),
        ],
        const [0.0, 0.40, 1.0],
      );
    darkCanvas.drawCircle(const Offset(32, 32), 32, darkPaint);
    _cachedCorePuff = darkRec.endRecording().toImageSync(_textureSize, _textureSize);
  }

  WallImpactPuff({
    required Vector2 position,
    required this.baseRadius,
  }) : super(
          position: position,
          anchor: Anchor.center,
          priority: 0, // Rendered on the back wall, strictly behind the backboard (priority 1)
        ) {
    _ensurePuffSprites();
  }

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
    if (_cachedWhitePuff == null || _cachedCorePuff == null) return;

    final progress = (_lifetime / duration).clamp(0.0, 1.0);
    // Smooth quadratic ease-out fade
    final fade = math.pow(1.0 - progress, 1.5).toDouble();
    if (fade <= 0.01) return;

    // 1. Soft chalky rubber scuff mark on the brick wall
    final scuffRadius = baseRadius * (0.85 + progress * 0.20);
    _sharedSpritePaint.color = Color.fromRGBO(255, 255, 255, (0.35 * fade).clamp(0.0, 1.0));
    _drawPuff(canvas, _cachedWhitePuff!, 0.0, 0.0, scuffRadius);

    // 2. Faint darker impact core
    _sharedSpritePaint.color = Color.fromRGBO(255, 255, 255, (0.22 * fade).clamp(0.0, 1.0));
    _drawPuff(canvas, _cachedCorePuff!, 0.0, 0.0, scuffRadius * 0.60);

    // 3. Subtle micro dust puff particles radiating outward
    final particleDistance = baseRadius * 0.65 * progress;
    final particleRadius = baseRadius * 0.12 * (1.0 - progress);
    _sharedSpritePaint.color = Color.fromRGBO(255, 255, 255, (0.28 * fade).clamp(0.0, 1.0));

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2.0 * math.pi / 5.0) + 0.35;
      final px = math.cos(angle) * particleDistance;
      final py = math.sin(angle) * particleDistance * 0.85; // Slight perspective squash
      _drawPuff(canvas, _cachedWhitePuff!, px, py, particleRadius);
    }
  }

  /// A unit circle's bounding box, reused for every puff: each one is drawn
  /// by moving and scaling the canvas instead of building a new Rect (seven
  /// fewer allocations per frame while a puff is showing).
  static const Rect _unitCircle = Rect.fromLTRB(-1.0, -1.0, 1.0, 1.0);

  void _drawPuff(Canvas canvas, ui.Image image, double cx, double cy, double radius) {
    if (radius <= 0.0) return;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(radius);
    canvas.drawImageRect(image, _srcRect, _unitCircle, _sharedSpritePaint);
    canvas.restore();
  }
}
