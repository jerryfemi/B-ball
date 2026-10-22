import 'package:flutter/material.dart';
import '../camera/archery_camera.dart';
import '../physics/target_scoring.dart';

/// Floating visual hit score popup rendered directly on the Flame canvas (Build Plan v2 §8.4, Review §1.2, §3, Bug #6).
///
/// Fixes Bug #6 by re-projecting 3D impact coordinates every frame so the popup
/// stays pinned to the arrow in perspective as the camera dollies into the close-up pose.
///
/// Features:
/// - Chunky rounded bold font with amber-gold fill (#F59E0B) and dark 3 px outline.
/// - Scales 0.6 -> 1.15 -> 1.0 (0.25 s, back-out).
/// - Rises ~40 px * uiScale over 1.1 s and fades out over the last 0.3 s.
/// - Standalone gold "X" badge for inner 10-ring hits.
/// - Zero heap allocations and zero saveLayer in render loop.
class HitPopupCanvas {
  static const double _duration = 1.1;

  double _worldX = 0.0;
  double _worldY = 0.0;
  double _worldZ = 0.0;

  ShotScore? _score;
  double _time = 0.0;
  bool _active = false;

  // Cached Paints for zero allocation & zero saveLayer alpha modulation
  final Paint _fillPaint = Paint()..color = const Color(0xFFF59E0B);
  final Paint _missFillPaint = Paint()..color = const Color(0xFFEF4444);
  final Paint _strokePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  final Paint _badgeBgPaint = Paint()..color = const Color(0xFFF59E0B);
  final Paint _badgeStrokePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _badgeTextPaint = Paint()..color = const Color(0xFF0F172A);

  // Cached TextPainters: key is label string (e.g. "+10", "MISS")
  final Map<String, TextPainter> _fillPainters = {};
  final Map<String, TextPainter> _strokePainters = {};
  late final TextPainter _badgePainter;

  HitPopupCanvas() {
    _initTextPainters();
  }

  void _initTextPainters() {
    final labels = [
      '+10', '+9', '+8', '+7', '+6', '+5', '+4', '+3', '+2', '+1', 'MISS'
    ];

    for (final label in labels) {
      final isMiss = label == 'MISS';
      final paintToUse = isMiss ? _missFillPaint : _fillPaint;

      final strokePainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
            foreground: _strokePaint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final fillPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
            foreground: paintToUse,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      _strokePainters[label] = strokePainter;
      _fillPainters[label] = fillPainter;
    }

    // Gold "X" badge
    _badgePainter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
          foreground: _badgeTextPaint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Triggers a new popup anchored to 3D world space at the arrow impact location.
  void trigger({
    required double worldX,
    required double worldY,
    required double worldZ,
    required ShotScore score,
  }) {
    _worldX = worldX;
    _worldY = worldY;
    _worldZ = worldZ;
    _score = score;
    _time = 0.0;
    _active = true;
  }

  /// Dismisses / resets active popup.
  void reset() {
    _active = false;
    _score = null;
    _time = 0.0;
  }

  bool get isActive => _active;

  void update(double dt) {
    if (!_active) return;
    _time += dt;
    if (_time >= _duration) {
      _active = false;
    }
  }

  void render(Canvas canvas, ArcheryCamera camera) {
    if (!_active || _score == null) return;

    // Reproject 3D world position each frame (fixes Bug #6 during camera dolly)
    if (!camera.project(_worldX, _worldY, _worldZ)) return;

    final double sx = camera.sx;
    final double sy = camera.sy;
    final double t = (_time / _duration).clamp(0.0, 1.0);

    // Punchy pop scale: 0.6 -> 1.15 -> 1.0 over first 250ms (0.23 of 1.1s)
    double scale = 1.0;
    if (t < 0.15) {
      final double st = t / 0.15;
      scale = 0.6 + (1.15 - 0.6) * Curves.easeOutBack.transform(st);
    } else if (t < 0.23) {
      final double st = (t - 0.15) / 0.08;
      scale = 1.15 + (1.0 - 1.15) * Curves.easeIn.transform(st);
    }

    // Drift upward ~40 px * uiScale
    final double driftY = -40.0 * camera.uiScale * Curves.easeOutCubic.transform(t);

    // Fade out over the last 0.3s (0.27 of 1.1s)
    double opacity = 1.0;
    if (t > 0.73) {
      opacity = (1.0 - Curves.easeOut.transform((t - 0.73) / 0.27)).clamp(0.0, 1.0);
    }

    final score = _score!;
    final String label = score.points > 0 ? '+${score.points}' : 'MISS';
    final strokePainter = _strokePainters[label];
    final fillPainter = _fillPainters[label];
    if (strokePainter == null || fillPainter == null) return;

    // Apply opacity to cached paints without allocating or using saveLayer
    final int alpha = (opacity * 255).round().clamp(0, 255);
    _strokePaint.color = Color.fromARGB(alpha, 15, 23, 42);
    _fillPaint.color = Color.fromARGB(alpha, 245, 158, 11);
    _missFillPaint.color = Color.fromARGB(alpha, 239, 68, 68);

    canvas.save();
    canvas.translate(sx, sy + driftY);
    canvas.scale(scale * camera.uiScale);

    final double textW = fillPainter.width;
    final double textH = fillPainter.height;

    // Center the label text at (0, 0)
    final double textDx = -textW * 0.5;
    final double textDy = -textH * 0.5;
    final textOffset = Offset(textDx, textDy);

    strokePainter.paint(canvas, textOffset);
    fillPainter.paint(canvas, textOffset);

    // Optional Gold "X" badge if it hit the inner X-ring
    if (score.isX) {
      _badgeBgPaint.color = Color.fromARGB(alpha, 245, 158, 11);
      _badgeStrokePaint.color = Color.fromARGB(alpha, 15, 23, 42);
      _badgeTextPaint.color = Color.fromARGB(alpha, 15, 23, 42);

      const double badgeW = 20.0;
      const double badgeH = 16.0;
      final double badgeLeft = textDx + textW + 4.0;
      final double badgeTop = textDy + (textH - badgeH) * 0.5;

      final badgeRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH),
        const Radius.circular(5.0),
      );

      canvas.drawRRect(badgeRRect, _badgeBgPaint);
      canvas.drawRRect(badgeRRect, _badgeStrokePaint);

      final double bx = badgeLeft + (badgeW - _badgePainter.width) * 0.5;
      final double by = badgeTop + (badgeH - _badgePainter.height) * 0.5;
      _badgePainter.paint(canvas, Offset(bx, by));
    }

    canvas.restore();
  }
}
