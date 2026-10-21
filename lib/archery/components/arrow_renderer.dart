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
  static const double shaftR = 0.0055; // Arcade-thick shaft radius (meters)
  static const double vaneHeight = 0.024; // Vane radial extension (meters)
  static const double pointLength = 0.075; // Steel broadhead length (meters)

  // ---- Look (GamePigeon-style wooden arrow, steel broadhead, red vanes) ----
  // Every solid paint is listed in [_solid] with its base colour so the bow's
  // fade-out can scale alpha on all of them without allocating per frame.
  static Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static const Color _cShaftEdge = Color(0xFF4A2B14); // shaded rim of the shaft
  static const Color _cShaft = Color(0xFF8E5C31); // wood
  static const Color _cShaftLit = Color(0xFFDDAE74); // varnish highlight
  static const Color _cNock = Color(0xFFF1F5F9); // white plastic nock
  static const Color _cFerrule = Color(0xFF8B95A3); // steel collar
  static const Color _cFerruleLit = Color(0xFFE5E9EF);
  static const Color _cBladeLit = Color(0xFFF4F6F9); // lit blade half
  static const Color _cBladeDark = Color(0xFF9AA4B2); // shaded blade half
  static const Color _cRidge = Color(0xFF5B6573); // centre ridge / edge line

  static final Paint _shaftEdgePaint = _fill(_cShaftEdge);
  static final Paint _shaftPaint = _fill(_cShaft);
  static final Paint _shaftLitPaint = _fill(_cShaftLit);
  static final Paint _nockPaint = _fill(_cNock);
  static final Paint _ferrulePaint = _fill(_cFerrule);
  static final Paint _ferruleLitPaint = _fill(_cFerruleLit);
  static final Paint _bladeLitPaint = _fill(_cBladeLit);
  static final Paint _bladeDarkPaint = _fill(_cBladeDark);
  static final Paint _ridgePaint = Paint()
    ..color = _cRidge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..isAntiAlias = true;
  static final Paint _vanePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _entryHolePaint = _fill(const Color(0xFF0F172A));

  static final List<Paint> _solid = [
    _shaftEdgePaint, _shaftPaint, _shaftLitPaint, _nockPaint, _ferrulePaint,
    _ferruleLitPaint, _bladeLitPaint, _bladeDarkPaint, _ridgePaint,
  ];
  static const List<Color> _solidColors = [
    _cShaftEdge, _cShaft, _cShaftLit, _cNock, _cFerrule,
    _cFerruleLit, _cBladeLit, _cBladeDark, _cRidge,
  ];

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
    for (int i = 0; i < _solid.length; i++) {
      _solid[i].color = opaque ? _solidColors[i] : _solidColors[i].withValues(alpha: opacity);
    }
  }

  // Reusable Paths
  static final Path _stripPath = Path();
  static final Path _vanePath = Path();

  // Screen-space registers for points along the shaft (zero allocation).
  static double _ax = 0, _ay = 0, _aw = 0; // segment start (toward nock)
  static double _bx = 0, _by = 0, _bw = 0; // segment end (toward tip)

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

    // Step B: shaft, nock, steel collar and broadhead.
    final double wNock = camera.pxPerMeterAt(nockDepth) * shaftR;
    final double screenDx = sxTip - sxNock;
    final double screenDy = syTip - syNock;
    final double screenLen = math.sqrt(screenDx * screenDx + screenDy * screenDy);

    if (screenLen < wNock * 1.2) {
      // Looking straight down the shaft: just the white nock.
      canvas.drawCircle(Offset(sxNock, syNock), wNock, _nockPaint);
    } else {
      // Perpendicular on screen, flipped so +n faces the light (upper left).
      double nx = -screenDy / screenLen;
      double ny = screenDx / screenLen;
      if (nx * -0.55 + ny * -0.83 < 0) {
        nx = -nx;
        ny = -ny;
      }

      final double len = length;
      // A stuck arrow's head is buried in the board: shaft runs to the entry
      // point and no collar/broadhead is drawn.
      final bool showHead = !drawEntryHole;
      final double shaftFront = showHead ? pointLength + 0.02 : 0.0;
      // Wooden shaft from the nock to the steel collar, as three tapered strips
      // (shaded rim, wood, varnish highlight) so it reads as a round dowel.
      if (_segment(camera, tipX, tipY, tipZ, forwardX, forwardY, forwardZ,
          len, shaftFront, quiverOffsetX)) {
        _strip(canvas, _shaftEdgePaint, nx, ny, 1.0, 0.0);
        _strip(canvas, _shaftPaint, nx, ny, 0.74, 0.16);
        _strip(canvas, _shaftLitPaint, nx, ny, 0.22, 0.48);
      }
      // White nock (last 1.8 cm at the back).
      if (_segment(camera, tipX, tipY, tipZ, forwardX, forwardY, forwardZ,
          len, len - 0.018, quiverOffsetX)) {
        _strip(canvas, _nockPaint, nx, ny, 1.08, 0.0);
      }
      // Steel collar (ferrule).
      if (showHead && _segment(camera, tipX, tipY, tipZ, forwardX, forwardY, forwardZ,
          pointLength + 0.02, pointLength - 0.004, 0.0)) {
        _strip(canvas, _ferrulePaint, nx, ny, 1.18, 0.0);
        _strip(canvas, _ferruleLitPaint, nx, ny, 0.35, 0.45);
      }
      // Broadhead: two-tone blade with a centre ridge and a notched back.
      if (showHead && _segment(camera, tipX, tipY, tipZ, forwardX, forwardY, forwardZ,
          pointLength, 0.0, 0.0)) {
        final double bw = _aw * 3.4; // blade half-width at its back
        final double notchX = _ax + (_bx - _ax) * 0.12;
        final double notchY = _ay + (_by - _ay) * 0.12;
        // lit half
        _stripPath
          ..reset()
          ..moveTo(notchX, notchY)
          ..lineTo(_ax + nx * bw, _ay + ny * bw)
          ..lineTo(_bx, _by)
          ..close();
        canvas.drawPath(_stripPath, _bladeLitPaint);
        // shaded half
        _stripPath
          ..reset()
          ..moveTo(notchX, notchY)
          ..lineTo(_ax - nx * bw, _ay - ny * bw)
          ..lineTo(_bx, _by)
          ..close();
        canvas.drawPath(_stripPath, _bladeDarkPaint);
        // ridge
        _ridgePaint.strokeWidth = math.max(1.0, _aw * 0.35);
        canvas.drawLine(Offset(notchX, notchY), Offset(_bx, _by), _ridgePaint);
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

  /// Projects the shaft section between [fromBack] and [toBack] metres
  /// behind the tip into the screen registers (_a = back end, _b = front end).
  /// [backOffsetX] bends the back end sideways (quiver / paradox wobble).
  static bool _segment(
    ArcheryCamera camera,
    double tipX,
    double tipY,
    double tipZ,
    double fx,
    double fy,
    double fz,
    double fromBack,
    double toBack,
    double backOffsetX,
  ) {
    final double total = math.max(fromBack, 1e-6);
    final double offA = backOffsetX * (fromBack / total);
    if (!camera.project(tipX - fx * fromBack + offA, tipY - fy * fromBack, tipZ - fz * fromBack)) {
      return false;
    }
    _ax = camera.sx;
    _ay = camera.sy;
    _aw = camera.pxPerMeterAt(camera.depth) * shaftR;
    final double offB = backOffsetX * (toBack / total);
    if (!camera.project(tipX - fx * toBack + offB, tipY - fy * toBack, tipZ - fz * toBack)) {
      return false;
    }
    _bx = camera.sx;
    _by = camera.sy;
    _bw = camera.pxPerMeterAt(camera.depth) * shaftR;
    return true;
  }

  /// Fills a tapered strip along the current segment: [widthK] of the shaft
  /// width, shifted toward the lit side by [shift] (fraction of the radius).
  static void _strip(Canvas canvas, Paint paint, double nx, double ny,
      double widthK, double shift) {
    final double wa = _aw * widthK, wb = _bw * widthK;
    final double sa = _aw * shift, sb = _bw * shift;
    _stripPath
      ..reset()
      ..moveTo(_ax + nx * (sa + wa), _ay + ny * (sa + wa))
      ..lineTo(_bx + nx * (sb + wb), _by + ny * (sb + wb))
      ..lineTo(_bx + nx * (sb - wb), _by + ny * (sb - wb))
      ..lineTo(_ax + nx * (sa - wa), _ay + ny * (sa - wa))
      ..close();
    canvas.drawPath(_stripPath, paint);
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
