import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../physics/arrow_physics.dart';

/// Renders an arrow in flight with perspective foreshortening,
/// dynamic fletchings, archer's paradox flex, and a motion trail.
class FlyingArrow {
  final ArcheryCamera camera;
  final ArrowPhysics3D physics;

  FlyingArrow({required this.camera, required this.physics});

  // --- Cached Paints ---
  final Paint _shaftPaint = Paint()
    ..color = const Color(0xFF2E384D)
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _tipPaint = Paint()
    ..color = const Color(0xFFCBD5E1)
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _vanePaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..style = PaintingStyle.fill;
  final Paint _indexVanePaint = Paint()
    ..color = const Color(0xFF00FFCC)
    ..style = PaintingStyle.fill;
  final Paint _rearNockPaint = Paint()
    ..color = const Color(0xFF00FFCC)
    ..style = PaintingStyle.fill;
  final Paint _trailPaint = Paint()
    ..color = const Color(0x6638BDF8)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;

  // Reusable Paths
  final Path _vanePath = Path();

  // Trail Ring Buffer (last 12 tip screen positions: x, y)
  static const int _trailPoints = 12;
  final Float64List _trailX = Float64List(_trailPoints);
  final Float64List _trailY = Float64List(_trailPoints);
  int _trailHead = 0;
  int _trailCount = 0;

  void resetTrail() {
    _trailHead = 0;
    _trailCount = 0;
  }

  void updateTrail(double sx, double sy) {
    _trailX[_trailHead] = sx;
    _trailY[_trailHead] = sy;
    _trailHead = (_trailHead + 1) % _trailPoints;
    if (_trailCount < _trailPoints) _trailCount++;
  }

  void render(Canvas canvas) {
    if (!physics.inFlight) return;

    final double speed = physics.vel.length;
    if (speed < 0.1) return;

    // Unit velocity vector
    final double invSpeed = 1.0 / speed;
    final double ux = physics.vel.x * invSpeed;
    final double uy = physics.vel.y * invSpeed;
    final double uz = physics.vel.z * invSpeed;

    // 1. Tip position in 3D (meters)
    final double tipX = physics.pos.x;
    final double tipY = physics.pos.y;
    final double tipZ = physics.pos.z;

    // 2. Nock position in 3D (offset backward by arrowLength + wobble)
    // Archer's paradox wobble applies slight lateral offset to nock
    final double wobbleOffset = math.sin(physics.wobbleYaw) * ArcheryK.arrowLength;
    final double nockX = tipX - ux * ArcheryK.arrowLength + wobbleOffset;
    final double nockY = tipY - uy * ArcheryK.arrowLength;
    final double nockZ = tipZ - uz * ArcheryK.arrowLength;

    // 3. Project Tip and Nock onto screen
    if (!camera.project(tipX, tipY, tipZ)) return;
    final double sxTip = camera.sx;
    final double syTip = camera.sy;

    // Record trail point
    updateTrail(sxTip, syTip);

    // 4. Render Trail
    _renderTrail(canvas);

    if (!camera.project(nockX, nockY, nockZ)) return;
    final double sxNock = camera.sx;
    final double syNock = camera.sy;

    // 5. Projected 2D screen geometry
    final double dx = sxTip - sxNock;
    final double dy = syTip - syNock;
    final double projectedLen = math.sqrt(dx * dx + dy * dy);

    // Theoretical side-view length at this depth
    final double pxPerM = camera.pxPerMeterAt(camera.depth);
    final double fullSideLen = pxPerM * ArcheryK.arrowLength;

    // If arrow is flying nearly straight away (L < 25% of full length), draw rear-view
    if (fullSideLen > 0.0 && (projectedLen / fullSideLen) < 0.25) {
      _renderRearView(canvas, sxNock, syNock, (pxPerM * 0.03).clamp(3.0, 14.0));
      return;
    }

    // 6. Draw side-view arrow stretched between nock and tip
    final double shaftWidth = (pxPerM * ArcheryK.arrowShaftRadius * 2.0).clamp(1.5, 5.0);
    _shaftPaint.strokeWidth = shaftWidth;
    _tipPaint.strokeWidth = shaftWidth * 1.3;

    // Main carbon shaft
    canvas.drawLine(Offset(sxNock, syNock), Offset(sxTip, syTip), _shaftPaint);

    // Steel point tip (front 5% of shaft)
    final double tipRatio = 0.08;
    final double tipBaseX = sxTip - dx * tipRatio;
    final double tipBaseY = syTip - dy * tipRatio;
    canvas.drawLine(Offset(tipBaseX, tipBaseY), Offset(sxTip, syTip), _tipPaint);

    // 7. Render Vanes near Nock
    _renderVanes(canvas, sxNock, syNock, dx, dy, projectedLen, pxPerM);
  }

  void _renderVanes(
    Canvas canvas,
    double sxNock,
    double syNock,
    double dx,
    double dy,
    double len,
    double pxPerM,
  ) {
    if (len < 4.0) return;

    final double uX = dx / len;
    final double uY = dy / len;
    final double perpX = -uY;
    final double perpY = uX;

    final double vaneLen = (pxPerM * 0.08).clamp(6.0, 24.0);
    final double vaneHeight = (pxPerM * 0.018).clamp(2.5, 9.0);

    // Upper vane
    _vanePath.reset();
    _vanePath.moveTo(sxNock, syNock);
    _vanePath.lineTo(
      sxNock + uX * (vaneLen * 0.7) + perpX * vaneHeight,
      syNock + uY * (vaneLen * 0.7) + perpY * vaneHeight,
    );
    _vanePath.lineTo(sxNock + uX * vaneLen, syNock + uY * vaneLen);
    _vanePath.close();
    canvas.drawPath(_vanePath, _vanePaint);

    // Lower vane
    _vanePath.reset();
    _vanePath.moveTo(sxNock, syNock);
    _vanePath.lineTo(
      sxNock + uX * (vaneLen * 0.7) - perpX * vaneHeight,
      syNock + uY * (vaneLen * 0.7) - perpY * vaneHeight,
    );
    _vanePath.lineTo(sxNock + uX * vaneLen, syNock + uY * vaneLen);
    _vanePath.close();
    canvas.drawPath(_vanePath, _indexVanePaint);
  }

  void _renderRearView(Canvas canvas, double cx, double cy, double radius) {
    // Glowing nock at center
    canvas.drawCircle(Offset(cx, cy), radius * 0.6, _rearNockPaint);

    // 3 fletches radiating at 120°
    for (int i = 0; i < 3; i++) {
      final double angle = (i * 2.0 * math.pi / 3.0) - math.pi * 0.5;
      final double vx = cx + math.cos(angle) * radius * 2.2;
      final double vy = cy + math.sin(angle) * radius * 2.2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(vx, vy),
        i == 0 ? _indexVanePaint : _vanePaint,
      );
    }
  }

  void _renderTrail(Canvas canvas) {
    if (_trailCount < 2) return;

    for (int i = 0; i < _trailCount - 1; i++) {
      final int idx1 = (_trailHead - _trailCount + i + _trailPoints) % _trailPoints;
      final int idx2 = (idx1 + 1) % _trailPoints;

      final double alpha = (i / (_trailCount - 1)).clamp(0.05, 0.65);
      _trailPaint.color = const Color(0xFF38BDF8).withValues(alpha: alpha);

      canvas.drawLine(
        Offset(_trailX[idx1], _trailY[idx1]),
        Offset(_trailX[idx2], _trailY[idx2]),
        _trailPaint,
      );
    }
  }
}
