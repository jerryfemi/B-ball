import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../camera/archery_camera.dart';

/// Small Verlet cloth wind flag attached to a flagpole beside the target.
///
/// Features:
/// - 8 × 5 grid of Verlet cloth particles with pinned flagpole anchor.
/// - Dynamic flutter responsive to wind direction and velocity.
/// - 100% preallocated Float64List buffers (zero runtime allocations).
class WindFlag {
  final ArcheryCamera camera;

  static const int cols = 8;
  static const int rows = 5;
  static const int particleCount = cols * rows;

  // Preallocated particle buffers: posX, posY, posZ, oldX, oldY, oldZ
  final Float64List _posX = Float64List(particleCount);
  final Float64List _posY = Float64List(particleCount);
  final Float64List _posZ = Float64List(particleCount);
  final Float64List _oldX = Float64List(particleCount);
  final Float64List _oldY = Float64List(particleCount);
  final Float64List _oldZ = Float64List(particleCount);

  // Cached screen projection buffers
  final Float64List _screenX = Float64List(particleCount);
  final Float64List _screenY = Float64List(particleCount);
  final Uint8List _projected = Uint8List(particleCount);

  // --- Cached Paints ---
  final Paint _polePaint = Paint()
    ..color = const Color(0xFF475569)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  final Paint _flagFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _flagBorderPaint = Paint()
    ..color = const Color(0x66000000)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  final Path _reusablePath = Path();

  double _targetDistance = 20.0;
  double _time = 0.0;

  WindFlag({required this.camera}) {
    reset(20.0);
  }

  void reset(double distance) {
    _targetDistance = distance;
    const double poleX = 0.85;
    const double poleTopY = 1.70;
    const double flagW = 0.40;
    const double flagH = 0.25;

    final double dx = flagW / (cols - 1);
    final double dy = flagH / (rows - 1);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int i = r * cols + c;
        final double x = poleX + c * dx;
        final double y = poleTopY - r * dy;
        final double z = distance;

        _posX[i] = x;
        _posY[i] = y;
        _posZ[i] = z;
        _oldX[i] = x;
        _oldY[i] = y;
        _oldZ[i] = z;
      }
    }
  }

  void update(double dt, double windMps) {
    _time += dt;
    final double clampedDt = dt.clamp(0.0, 0.05);

    // 1. Verlet Integration
    const double poleX = 0.85;
    const double poleTopY = 1.70;
    const double flagH = 0.25;
    final double dy = flagH / (rows - 1);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int i = r * cols + c;

        // Pin the left edge (column 0) to the flagpole
        if (c == 0) {
          _posX[i] = poleX;
          _posY[i] = poleTopY - r * dy;
          _posZ[i] = _targetDistance;
          _oldX[i] = _posX[i];
          _oldY[i] = _posY[i];
          _oldZ[i] = _posZ[i];
          continue;
        }

        // Wind flutter force
        final double flutter = math.sin(_time * 16.0 + c * 0.8 + r) * 0.25 * windMps.abs();
        final double windAccX = windMps * 4.0;
        final double windAccZ = flutter * 1.5;
        const double gravityAccY = -2.5;

        final double vx = (_posX[i] - _oldX[i]) * 0.94;
        final double vy = (_posY[i] - _oldY[i]) * 0.94;
        final double vz = (_posZ[i] - _oldZ[i]) * 0.94;

        _oldX[i] = _posX[i];
        _oldY[i] = _posY[i];
        _oldZ[i] = _posZ[i];

        _posX[i] += vx + windAccX * clampedDt * clampedDt;
        _posY[i] += vy + gravityAccY * clampedDt * clampedDt;
        _posZ[i] += vz + windAccZ * clampedDt * clampedDt;
      }
    }

    // 2. Structural distance constraints (2 relaxation passes)
    const double restDistX = 0.40 / (cols - 1);
    const double restDistY = 0.25 / (rows - 1);

    for (int pass = 0; pass < 2; pass++) {
      // Horizontal constraints
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols - 1; c++) {
          final int i1 = r * cols + c;
          final int i2 = r * cols + (c + 1);
          _relaxConstraint(i1, i2, restDistX, c == 0);
        }
      }

      // Vertical constraints
      for (int r = 0; r < rows - 1; r++) {
        for (int c = 0; c < cols; c++) {
          final int i1 = r * cols + c;
          final int i2 = (r + 1) * cols + c;
          _relaxConstraint(i1, i2, restDistY, c == 0);
        }
      }
    }
  }

  void _relaxConstraint(int i1, int i2, double targetDist, bool isI1Pinned) {
    final double dx = _posX[i2] - _posX[i1];
    final double dy = _posY[i2] - _posY[i1];
    final double dz = _posZ[i2] - _posZ[i1];

    final double dist = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (dist <= 1e-6) return;

    final double diff = (dist - targetDist) / dist;

    if (isI1Pinned) {
      _posX[i2] -= dx * diff;
      _posY[i2] -= dy * diff;
      _posZ[i2] -= dz * diff;
    } else {
      final double halfDiff = diff * 0.5;
      _posX[i1] += dx * halfDiff;
      _posY[i1] += dy * halfDiff;
      _posZ[i1] += dz * halfDiff;
      _posX[i2] -= dx * halfDiff;
      _posY[i2] -= dy * halfDiff;
      _posZ[i2] -= dz * halfDiff;
    }
  }

  void render(Canvas canvas) {
    // 1. Draw Flagpole
    const double poleX = 0.85;
    if (!camera.project(poleX, 0.0, _targetDistance)) return;
    final double sxBottom = camera.sx;
    final double syBottom = camera.sy;

    if (!camera.project(poleX, 1.75, _targetDistance)) return;
    final double sxTop = camera.sx;
    final double syTop = camera.sy;

    canvas.drawLine(Offset(sxBottom, syBottom), Offset(sxTop, syTop), _polePaint);

    // 2. Project cloth grid nodes
    for (int i = 0; i < particleCount; i++) {
      if (camera.project(_posX[i], _posY[i], _posZ[i])) {
        _screenX[i] = camera.sx;
        _screenY[i] = camera.sy;
        _projected[i] = 1;
      } else {
        _projected[i] = 0;
      }
    }

    // 3. Render Cloth Mesh Quads
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cols - 1; c++) {
        final int i0 = r * cols + c;
        final int i1 = r * cols + (c + 1);
        final int i2 = (r + 1) * cols + (c + 1);
        final int i3 = (r + 1) * cols + c;

        if (_projected[i0] == 0 ||
            _projected[i1] == 0 ||
            _projected[i2] == 0 ||
            _projected[i3] == 0) {
          continue;
        }

        _reusablePath.reset();
        _reusablePath.moveTo(_screenX[i0], _screenY[i0]);
        _reusablePath.lineTo(_screenX[i1], _screenY[i1]);
        _reusablePath.lineTo(_screenX[i2], _screenY[i2]);
        _reusablePath.lineTo(_screenX[i3], _screenY[i3]);
        _reusablePath.close();

        // Alternating neon cyan & dark obsidian flag fabric
        final bool isStripe = (c ~/ 2) % 2 == 0;
        _flagFillPaint.color = isStripe
            ? const Color(0xFF00FFCC)
            : const Color(0xFF38BDF8);

        canvas.drawPath(_reusablePath, _flagFillPaint);
        canvas.drawPath(_reusablePath, _flagBorderPaint);
      }
    }
  }
}
