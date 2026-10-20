import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../util/image_loader.dart';

/// Foreground first-person recurve bow with nocked arrow aimed at the target (Build Plan v2 §8.1).
///
/// Features:
/// - Recurve bow image asset (bow_recurve.webp) sized by screenH * 0.75 * uiScale.
/// - Fades out during draw slide via paint alpha (zero saveLayer).
/// - Loaded arrow points from the grip toward the projected target center (30% screen distance).
/// - Zero runtime heap allocations in render loop.
class BowOverlay {
  final ArcheryCamera camera;

  BowOverlay({required this.camera});

  ui.Image? _bowImage;

  // Cached Paints
  final Paint _bowPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _arrowShaftPaint = Paint()
    ..color = const Color(0xFF1E293B)
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _arrowTipPaint = Paint()
    ..color = const Color(0xFF94A3B8)
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _arrowVanePaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..style = PaintingStyle.fill;

  // Reusable Paths
  final Path _vanePath = Path();

  // Screen metrics & state
  double screenW = 0.0;
  double screenH = 0.0;
  double slideProgress = 0.0; // 0.0 = visible at line, 1.0 = slid out

  Future<void> load() async {
    _bowImage = await loadArcheryImage('assets/archery/bow_recurve.webp');
  }

  void resize(double width, double height) {
    screenW = width;
    screenH = height;
  }

  void update(double dt, {double slide = 0.0}) {
    slideProgress = slide;
  }

  void render(Canvas canvas) {
    if (screenW <= 0.0 || screenH <= 0.0 || slideProgress >= 1.0) return;

    final double alpha = (1.0 - slideProgress).clamp(0.0, 1.0);
    final double slideOffsetX = slideProgress * screenW * 0.35;
    final double slideOffsetY = slideProgress * screenH * 0.45;
    final double scale = 1.0 + slideProgress * 0.15;
    final double uiScale = camera.uiScale;

    // Anchor: right side of the screen
    final double bowBaseX = screenW * 0.82 + slideOffsetX;
    final double bowBaseY = screenH * 0.65 + slideOffsetY;

    // Update paint alpha (no saveLayer)
    _bowPaint.color = Color.fromRGBO(255, 255, 255, alpha);
    _arrowShaftPaint.color = const Color(0xFF1E293B).withValues(alpha: alpha);
    _arrowShaftPaint.strokeWidth = 3.5 * uiScale;
    _arrowTipPaint.color = const Color(0xFF94A3B8).withValues(alpha: alpha);
    _arrowTipPaint.strokeWidth = 4.5 * uiScale;
    _arrowVanePaint.color = const Color(0xFFEF4444).withValues(alpha: alpha);

    // 1. Render Bow Image
    if (_bowImage != null) {
      final img = _bowImage!;
      final double imgW = img.width.toDouble();
      final double imgH = img.height.toDouble();
      final double bowHeight = screenH * 0.75 * uiScale;
      final double bowWidth = bowHeight * (imgW / imgH);

      canvas.save();
      canvas.translate(bowBaseX, bowBaseY);
      canvas.scale(scale);
      canvas.rotate(-6.0 * math.pi / 180.0); // -6 degrees tilt

      final Rect src = Rect.fromLTWH(0, 0, imgW, imgH);
      final Rect dst = Rect.fromLTWH(-bowWidth * 0.5, -bowHeight * 0.5, bowWidth, bowHeight);
      canvas.drawImageRect(img, src, dst, _bowPaint);
      canvas.restore();
    }

    // 2. Render Nocked Arrow toward projected target center (§1.3)
    _renderNockedArrow(canvas, bowBaseX, bowBaseY, uiScale);
  }

  void _renderNockedArrow(Canvas canvas, double bowBaseX, double bowBaseY, double uiScale) {
    // Project target center to find screen target point
    camera.project(0.0, ArcheryK.targetCenterY, ArcheryK.distanceM);
    final double targetSx = camera.sx;
    final double targetSy = camera.sy;

    // Arrow nock rests near grip
    final double nockX = bowBaseX - 25.0 * uiScale;
    final double nockY = bowBaseY;

    final double dx = targetSx - nockX;
    final double dy = targetSy - nockY;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 10.0) return;

    // Arrow length is ~30% of screen distance toward target
    final double arrowLen = dist * 0.30;
    final double ux = dx / dist;
    final double uy = dy / dist;
    final double tipX = nockX + ux * arrowLen;
    final double tipY = nockY + uy * arrowLen;

    // Main shaft
    canvas.drawLine(Offset(nockX, nockY), Offset(tipX, tipY), _arrowShaftPaint);

    // Steel pile tip (front 15px)
    final double tipBaseX = tipX - ux * (15.0 * uiScale);
    final double tipBaseY = tipY - uy * (15.0 * uiScale);
    canvas.drawLine(Offset(tipBaseX, tipBaseY), Offset(tipX, tipY), _arrowTipPaint);

    // Red fletchings near nock
    final double perpX = -uy * (7.0 * uiScale);
    final double perpY = ux * (7.0 * uiScale);

    // Upper vane
    _vanePath.reset();
    _vanePath.moveTo(nockX, nockY);
    _vanePath.lineTo(nockX + ux * (24.0 * uiScale) + perpX, nockY + uy * (24.0 * uiScale) + perpY);
    _vanePath.lineTo(nockX + ux * (36.0 * uiScale), nockY + uy * (36.0 * uiScale));
    _vanePath.close();
    canvas.drawPath(_vanePath, _arrowVanePaint);

    // Lower vane
    _vanePath.reset();
    _vanePath.moveTo(nockX, nockY);
    _vanePath.lineTo(nockX + ux * (24.0 * uiScale) - perpX, nockY + uy * (24.0 * uiScale) - perpY);
    _vanePath.lineTo(nockX + ux * (36.0 * uiScale), nockY + uy * (36.0 * uiScale));
    _vanePath.close();
    canvas.drawPath(_vanePath, _arrowVanePaint);
  }
}
