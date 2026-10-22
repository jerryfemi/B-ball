import 'dart:math' as math;
import 'package:b_ball/archery/archery_constants.dart';
import 'package:b_ball/archery/physics/arrow_physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('ArrowPhysics3D Tests', () {
    test('Test 2: Determinism across 100 runs with varying frame dt jitter', () {
      const double dist = 60.0;
      const double launchPitch = 0.045; // ~2.5° elevation
      const double launchYaw = 0.012;   // slight right aim
      const double speed = ArcheryK.fullDrawSpeed;

      double? canonicalHitX;
      double? canonicalHitY;

      // Seeded random for deterministic dt jitter across the 100 runs
      final math.Random rng = math.Random(42);

      for (int run = 0; run < 100; run++) {
        final ArrowPhysics3D physics = ArrowPhysics3D();
        physics.launch(
          startPos: Vector3(0.0, ArcheryK.launchY, ArcheryK.launchZ),
          launchYaw: launchYaw,
          launchPitch: launchPitch,
          speed: speed,
          targetDist: dist,
        );

        while (physics.inFlight) {
          // Vary frame dt between 1/120s and 1/30s
          final double frameDt = 0.008 + rng.nextDouble() * 0.025;
          physics.update(frameDt);
        }

        expect(physics.hitBoss, isTrue);

        if (run == 0) {
          canonicalHitX = physics.hitLocalX;
          canonicalHitY = physics.hitLocalY;
        } else {
          // Must match to within floating point rounding (< 1e-12)
          expect(
            (physics.hitLocalX - canonicalHitX!).abs(),
            lessThan(1e-10),
            reason: 'Hit X must be bit-identical across run $run',
          );
          expect(
            (physics.hitLocalY - canonicalHitY!).abs(),
            lessThan(1e-10),
            reason: 'Hit Y must be bit-identical across run $run',
          );
        }
      }
    });

    test('Test 3: No tunneling at extreme 90 m/s arrow velocity', () {
      const double dist = 40.0;
      final ArrowPhysics3D physics = ArrowPhysics3D();

      physics.launch(
        startPos: Vector3(0.0, ArcheryK.launchY, ArcheryK.launchZ),
        launchYaw: 0.0,
        launchPitch: 0.015,
        speed: 90.0, // High speed: moves ~37 cm per 240Hz step
        targetDist: dist,
      );

      // Simulate with low framerate (15 FPS = ~66.7 ms per frame, arrow jumps ~6 meters)
      while (physics.inFlight) {
        physics.update(1.0 / 15.0);
      }

      expect(physics.hitBoss, isTrue, reason: 'Plane crossing must prevent tunneling');
      expect(physics.hitPoint.z, equals(dist), reason: 'Plane crossing hit z must be exact D');
    });

    test('Ground collision detection when aiming down', () {
      final ArrowPhysics3D physics = ArrowPhysics3D();

      physics.launch(
        startPos: Vector3(0.0, ArcheryK.launchY, ArcheryK.launchZ),
        launchYaw: 0.0,
        launchPitch: -0.35, // Aimed sharply downward
        speed: ArcheryK.fullDrawSpeed,
        targetDist: 50.0,
      );

      while (physics.inFlight) {
        physics.update(1.0 / 60.0);
      }

      expect(physics.hitGround, isTrue);
      expect(physics.hitPoint.y, equals(0.0));
      expect(physics.hitPoint.z, lessThan(50.0));
    });
  });
}
