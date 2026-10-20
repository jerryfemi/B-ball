import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../camera/archery_camera.dart';

/// Drifting dust motes and wind particles indicating crosswind across the range.
///
/// Features:
/// - Structure-of-Arrays (SoA) typed lists for zero garbage collection.
/// - Atmospheric glow under stadium floodlights.
class WindParticles {
  final ArcheryCamera camera;

  static const int count = 36;

  final Float64List _x = Float64List(count);
  final Float64List _y = Float64List(count);
  final Float64List _z = Float64List(count);
  final Float64List _phase = Float64List(count);
  final Float64List _baseSize = Float64List(count);

  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  double _time = 0.0;

  WindParticles({required this.camera}) {
    final math.Random rng = math.Random(1337);
    for (int i = 0; i < count; i++) {
      _x[i] = (rng.nextDouble() * 12.0) - 6.0;
      _y[i] = 0.4 + rng.nextDouble() * 3.5;
      _z[i] = 2.0 + rng.nextDouble() * 60.0;
      _phase[i] = rng.nextDouble() * 2.0 * math.pi;
      _baseSize[i] = 0.015 + rng.nextDouble() * 0.02; // 1.5 cm to 3.5 cm
    }
  }

  void update(double dt, double windMps) {
    _time += dt;

    for (int i = 0; i < count; i++) {
      // Lateral drift proportional to crosswind + gentle turbulent wave
      final double turbulence = math.sin(_time * 2.5 + _phase[i]) * 0.15;
      _x[i] += (windMps * 0.85 + turbulence) * dt;

      // Gentle vertical bobbing
      _y[i] += math.sin(_time * 1.8 + _phase[i] * 1.5) * 0.08 * dt;

      // Wrap-around bounds across range
      if (_x[i] > 6.5) {
        _x[i] = -6.5;
      } else if (_x[i] < -6.5) {
        _x[i] = 6.5;
      }

      if (_y[i] < 0.2) _y[i] = 0.2;
      if (_y[i] > 4.5) _y[i] = 4.5;
    }
  }

  void render(Canvas canvas) {
    for (int i = 0; i < count; i++) {
      if (!camera.project(_x[i], _y[i], _z[i])) continue;

      final double sx = camera.sx;
      final double sy = camera.sy;
      final double pxPerM = camera.pxPerMeterAt(camera.depth);
      final double radius = (pxPerM * _baseSize[i]).clamp(1.2, 5.5);

      // Depth fade: near particles brighter, far particles subtle
      final double depthAlpha = (1.0 - (camera.depth / 70.0)).clamp(0.15, 0.75);

      // Halo glow
      _glowPaint.color = const Color(0x2238BDF8).withValues(alpha: depthAlpha * 0.4);
      canvas.drawCircle(Offset(sx, sy), radius * 2.2, _glowPaint);

      // Core particle speck
      _particlePaint.color = const Color(0xCC00FFCC).withValues(alpha: depthAlpha);
      canvas.drawCircle(Offset(sx, sy), radius, _particlePaint);
    }
  }
}
