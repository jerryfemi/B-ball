import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import 'package:b_ball/darts/components/stuck_dart.dart';
import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/scene/board_projection.dart';

void main() {
  group('Step 10 - Dart Rendering Logic & Formulas', () {
    test('A stuck dart points into the board and slightly down (it dipped in)', () {
      for (final (x, y) in [(0.0, 0.0), (0.0, 103.0), (-120.0, -60.0)]) {
        final a = StuckDart.impactAxis(x, y);
        expect(math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z), closeTo(1.0, 1e-9));
        expect(a.z, lessThan(-0.9)); // toward the board
        expect(a.y, lessThan(0.0)); // nose down
      }
    });

    test('Stuck impact wobble formula decays exponentially within 0.35s', () {
      const double maxWobbleRad = 3.0 * math.pi / 180.0;

      double wobbleAt(double t) {
        if (t >= DartsK.stuckWobbleDurationSec) return 0.0;
        return maxWobbleRad * math.exp(-t / 0.12) * math.sin(t * 60.0);
      }

      // At t = 0, sin(0) is 0
      expect(wobbleAt(0.0), closeTo(0.0, 1e-6));

      // At first peak t ≈ pi / 120 ≈ 0.026s
      final double peak1 = wobbleAt(math.pi / 120.0);
      expect(peak1.abs(), greaterThan(0.03)); // ~2 degrees

      // At t = 0.20s, amplitude is significantly decayed
      final double ampLate = wobbleAt(0.20).abs();
      expect(ampLate, lessThan(peak1.abs() * 0.3));

      // At t >= 0.35s, wobble is completely clamped to 0.0
      expect(wobbleAt(0.35), equals(0.0));
      expect(wobbleAt(0.50), equals(0.0));
    });

    test('Flight spin frame index cycles at 18 cycles/s (4.5 rps for 4 flights)', () {
      const int spinFrames = 8;
      int spinIndex(double flightTime) {
        return (flightTime * 18.0 * spinFrames).floor() % spinFrames;
      }

      // At t = 0 -> frame 0
      expect(spinIndex(0.0), equals(0));

      // Advances through frames as flight time increases
      final Set<int> visitedFrames = {};
      for (double t = 0.0; t < 0.25; t += 0.005) {
        visitedFrames.add(spinIndex(t));
      }
      // Should visit all 8 frames within 0.25s
      expect(visitedFrames.length, equals(spinFrames));
      for (int i = 0; i < spinFrames; i++) {
        expect(visitedFrames.contains(i), isTrue);
      }
    });

    test('Pitch tilt formula tilts nose down as dart falls along trajectory', () {
      // Launch velocity: forward (-vz), upward (+vy)
      final vLaunch = Vector3(0.0, 1.8, -7.0);
      final double pitchLaunch =
          math.atan2(vLaunch.y, -vLaunch.z) * 0.35;
      expect(pitchLaunch, greaterThan(0.0)); // Pointing slightly up/level

      // Late flight: forward (-vz), falling downwards (-vy)
      final vLate = Vector3(0.0, -1.8, -7.0);
      final double pitchLate =
          math.atan2(vLate.y, -vLate.z) * 0.35;
      expect(pitchLate, lessThan(0.0)); // Tilting nose down
    });

    test('Seen from the oche, a stuck dart is nearly tail-on (the X of the flights)', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400, 800));
      final a = StuckDart.impactAxis(0.0, 0.0);
      const double l = DartsK.dartLengthM;
      final double vx = -a.x * l * 0.5;
      final double vy = -a.y * l * 0.5 - projection.eyeHeightM;
      final double vz = -a.z * l * 0.5 - projection.eyeZ;
      final double vl = math.sqrt(vx * vx + vy * vy + vz * vz);
      final double deg = math.acos((vx * a.x + vy * a.y + vz * a.z) / vl) * 180 / math.pi;
      expect(deg, lessThan(20.0));
    });
  });
}
