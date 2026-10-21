import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';

class _VanePoint {
  double sx = 0.0;
  double sy = 0.0;
}

class _VaneData {
  double dot = 0.0;
  final _VanePoint a = _VanePoint();
  final _VanePoint b = _VanePoint();
  final _VanePoint c = _VanePoint();
  final _VanePoint d = _VanePoint();
  bool valid = false;
}

/// Shared 3D perspective-correct arrow renderer (Build Plan v2 §1.3).
///
/// Features:
/// - True 3-vane geometry at 120° roll angles with facing-dependent lighting.
/// - Perspective-tapered carbon shaft (#1F2937) with steel tip (#94A3B8).
/// - Head-on circular cap when arrow points directly at camera.
/// - Launch depth culling (nockDepth < 0.35m) preventing pop-in.
/// - Zero heap allocations per frame via pre-allocated paths and registers.
class ArrowRenderer3D {
  static const double shaftR = 0.0045; // Arcade-thick shaft radius (meters)
  static const double vaneHeight = 0.024; // Vane radial extension (meters)
  static const double pointLength = 0.060; // Steel broadhead length (meters)

  // Cached Paints
  static final Paint _shaftPaint = Paint()
    ..color = const Color(0xFF8A5A30)
    ..style = PaintingStyle.fill;

  static final Paint _highlightPaint = Paint()
    ..color = const Color(0xFFC9935A)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _pointPaint = Paint()
    ..color = const Color(0xFFD1D5DB)
    ..style = PaintingStyle.fill;

  static final Paint _vanePaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _nockCapPaint = Paint()
    ..color = const Color(0xFF8A5A30)
    ..style = PaintingStyle.fill;

  static final Paint _entryHolePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;

  static const Color _shaftColor = Color(0xFF8A5A30); // wooden shaft
  static const Color _highlightColor = Color(0xFFC9935A);
  static const Color _pointColor = Color(0xFFD1D5DB); // steel broadhead

  /// 8 precomputed vane shades, dark (facing away) -> bright (facing camera).
  /// Avoids a Color.lerp allocation per vane per frame.
  static final List<Color> _vaneShades = List<Color>.generate(
    8,
    (i) => Color.lerp(const Color(0xFFB91C1C), const Color(0xFFEF4444), i / 7.0)!,
    growable: false,
  );

  static double _opacity = 1.0;

  static void _applyOpacity(double opacity) {
    if (opacity == _opacity) return;
    _opacity = opacity;
    final bool opaque = opacity >= 0.999;
    _shaftPaint.color = opaque ? _shaftColor : _shaftColor.withValues(alpha: opacity);
    _nockCapPaint.color = _shaftPaint.color;
    _highlightPaint.color = opaque ? _highlightColor : _highlightColor.withValues(alpha: opacity);
    _pointPaint.color = opaque ? _pointColor : _pointColor.withValues(alpha: opacity);
  }

  // Reusable Paths
  static final Path _shaftPath = Path();
  static final Path _pointPath = Path();
  static final Path _vanePath = Path();

  // Reusable Vane Registers
  static final List<_VaneData> _vanes = [
    _VaneData(),
    _VaneData(),
    _VaneData(),
  ];

  /// Renders a full 3D arrow from tip position and forward vector.
  static void render({
    required Canvas canvas,
    required ArcheryCamera camera,
    required double tipX,
    required double tipY,
    required double tipZ,
    required double forwardX,
    required double forwardY,
    required double forwardZ,
    double length = ArcheryK.arrowLength,
    double roll = 0.0,
    double quiverOffsetX = 0.0,
    bool drawEntryHole = false,
    double opacity = 1.0,
  }) {
    if (opacity <= 0.01) return;
    _applyOpacity(opacity);

    // 1. Calculate Nock Position in 3D
    final double nockX = tipX - forwardX * length + quiverOffsetX;
    final double nockY = tipY - forwardY * length;
    final double nockZ = tipZ - forwardZ * length;

    // 2. Cull if nock is too close to camera (prevents launch pop-in)
    final double nockDepth = nockZ - camera.eyeZ;
    if (nockDepth < 0.35) return;

    // 3. Project Tip and Nock
    if (!camera.project(tipX, tipY, tipZ)) return;
    final double sxTip = camera.sx;
    final double syTip = camera.sy;
    final double tipDepth = camera.depth;

    if (!camera.project(nockX, nockY, nockZ)) return;
    final double sxNock = camera.sx;
    final double syNock = camera.sy;

    // Optional entry hole mark on target
    if (drawEntryHole) {
      final double entryR = (camera.pxPerMeterAt(tipDepth) * 0.007).clamp(1.5, 4.0);
      canvas.drawCircle(Offset(sxTip, syTip), entryR, _entryHolePaint);
    }

    // 4. Construct Orthonormal Frame (forward = f, right = r, up = u)
    // World Up = (0, 1, 0)
    // r = normalize(f × worldUp)
    double rx = -forwardZ;
    double ry = 0.0;
    double rz = forwardX;
    final double rLen = math.sqrt(rx * rx + rz * rz);
    if (rLen > 0.0001) {
      final double invR = 1.0 / rLen;
      rx *= invR;
      rz *= invR;
    } else {
      rx = 1.0;
      ry = 0.0;
      rz = 0.0;
    }

    // u = r × f
    final double ux = -rz * forwardY;
    final double uy = rz * forwardX - rx * forwardZ;
    final double uz = rx * forwardY;

    // 5. Precompute 3 Vanes Geometry
    // Camera view vector to nock
    final double vx = nockX - camera.eyeX;
    final double vy = nockY - camera.eyeY;
    final double vz = nockZ - camera.eyeZ;
    final double vLen = math.sqrt(vx * vx + vy * vy + vz * vz);
    final double invV = vLen > 0.001 ? 1.0 / vLen : 1.0;

    for (int k = 0; k < 3; k++) {
      final _VaneData vane = _vanes[k];
      final double theta = roll + k * (2.0 * math.pi / 3.0);
      final double cosT = math.cos(theta);
      final double sinT = math.sin(theta);

      // Radial vector d_k
      final double dx = cosT * rx + sinT * ux;
      final double dy = cosT * ry + sinT * uy;
      final double dz = cosT * rz + sinT * uz;

      // Facing: v points from the camera to the nock, so a vane whose radial
      // direction runs along v points AWAY from the camera. Negate so that
      // dot > 0 means "facing the camera" (drawn last, brighter).
      vane.dot = -(dx * vx + dy * vy + dz * vz) * invV;

      // 4 corners in 3D:
      final double rOuter = shaftR + vaneHeight;

      final double ax = nockX + forwardX * 0.015 + dx * shaftR;
      final double ay = nockY + forwardY * 0.015 + dy * shaftR;
      final double az = nockZ + forwardZ * 0.015 + dz * shaftR;

      final double bx = nockX + forwardX * 0.110 + dx * shaftR;
      final double by = nockY + forwardY * 0.110 + dy * shaftR;
      final double bz = nockZ + forwardZ * 0.110 + dz * shaftR;

      final double cx = nockX + forwardX * 0.045 + dx * rOuter;
      final double cy = nockY + forwardY * 0.045 + dy * rOuter;
      final double cz = nockZ + forwardZ * 0.045 + dz * rOuter;

      final double dpx = nockX + forwardX * 0.020 + dx * rOuter;
      final double dpy = nockY + forwardY * 0.020 + dy * rOuter;
      final double dpz = nockZ + forwardZ * 0.020 + dz * rOuter;

      bool ok = true;
      if (camera.project(ax, ay, az)) {
        vane.a.sx = camera.sx;
        vane.a.sy = camera.sy;
      } else {
        ok = false;
      }
      if (camera.project(bx, by, bz)) {
        vane.b.sx = camera.sx;
        vane.b.sy = camera.sy;
      } else {
        ok = false;
      }
      if (camera.project(cx, cy, cz)) {
        vane.c.sx = camera.sx;
        vane.c.sy = camera.sy;
      } else {
        ok = false;
      }
      if (camera.project(dpx, dpy, dpz)) {
        vane.d.sx = camera.sx;
        vane.d.sy = camera.sy;
      } else {
        ok = false;
      }
      vane.valid = ok;
    }

    // 6. Draw Order:
    // Step A: Vanes pointing AWAY from camera (dot <= 0)
    for (int k = 0; k < 3; k++) {
      final vane = _vanes[k];
      if (vane.valid && vane.dot <= 0.0) {
        _renderVane(canvas, vane);
      }
    }

    // Step B: Shaft & Steel Field Point
    final double wTip = camera.pxPerMeterAt(tipDepth) * shaftR;
    final double wNock = camera.pxPerMeterAt(nockDepth) * shaftR;

    final double screenDx = sxTip - sxNock;
    final double screenDy = syTip - syNock;
    final double screenLen = math.sqrt(screenDx * screenDx + screenDy * screenDy);

    if (screenLen < wNock * 1.2) {
      // Looking almost straight down the shaft
      canvas.drawCircle(Offset(sxNock, syNock), wNock, _nockCapPaint);
    } else {
      final double invLen = 1.0 / screenLen;
      final double nx = -screenDy * invLen;
      final double ny = screenDx * invLen;

      // Wooden shaft perspective quad
      _shaftPath.reset();
      _shaftPath.moveTo(sxNock - nx * wNock, syNock - ny * wNock);
      _shaftPath.lineTo(sxTip - nx * wTip, syTip - ny * wTip);
      _shaftPath.lineTo(sxTip + nx * wTip, syTip + ny * wTip);
      _shaftPath.lineTo(sxNock + nx * wNock, syNock + ny * wNock);
      _shaftPath.close();
      canvas.drawPath(_shaftPath, _shaftPaint);

      // Varnish highlight along the shaft, scaled with its on-screen width
      _highlightPaint.strokeWidth = math.max(1.0, (wNock + wTip) * 0.3);
      canvas.drawLine(
        Offset(sxNock - nx * (wNock * 0.4), syNock - ny * (wNock * 0.4)),
        Offset(sxTip - nx * (wTip * 0.4), syTip - ny * (wTip * 0.4)),
        _highlightPaint,
      );

      // Steel broadhead (last 6 cm at the tip)
      final double pBaseX = tipX - forwardX * pointLength;
      final double pBaseY = tipY - forwardY * pointLength;
      final double pBaseZ = tipZ - forwardZ * pointLength;

      if (camera.project(pBaseX, pBaseY, pBaseZ)) {
        final double sxPBase = camera.sx;
        final double syPBase = camera.sy;
        final double wPBase = camera.pxPerMeterAt(camera.depth) * (shaftR * 2.6); // broadhead blades

        _pointPath.reset();
        _pointPath.moveTo(sxPBase - nx * wPBase, syPBase - ny * wPBase);
        _pointPath.lineTo(sxTip, syTip);
        _pointPath.lineTo(sxPBase + nx * wPBase, syPBase + ny * wPBase);
        _pointPath.close();
        canvas.drawPath(_pointPath, _pointPaint);
      }
    }

    // Step C: Vanes pointing TOWARDS camera (dot > 0)
    for (int k = 0; k < 3; k++) {
      final vane = _vanes[k];
      if (vane.valid && vane.dot > 0.0) {
        _renderVane(canvas, vane);
      }
    }
  }

  static void _renderVane(Canvas canvas, _VaneData vane) {
    _vanePath.reset();
    _vanePath.moveTo(vane.a.sx, vane.a.sy);
    _vanePath.lineTo(vane.b.sx, vane.b.sy);
    _vanePath.lineTo(vane.c.sx, vane.c.sy);
    _vanePath.lineTo(vane.d.sx, vane.d.sy);
    _vanePath.close();

    // Shaded red: brighter when facing camera, deeper when facing away
    final double t = (vane.dot * 0.5 + 0.5).clamp(0.0, 1.0);
    final Color shade = _vaneShades[(t * 7.0).round()];
    _vanePaint.color = _opacity >= 0.999 ? shade : shade.withValues(alpha: _opacity);
    canvas.drawPath(_vanePath, _vanePaint);
  }
}
