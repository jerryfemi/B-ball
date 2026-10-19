import 'dart:math' as math;
import 'package:b_ball/archery/archery_constants.dart';
import 'package:b_ball/archery/physics/arrow_physics.dart';
import 'package:b_ball/archery/physics/sight_solver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('SightSolver Tests', () {
    test('Test 1: Sight solver accuracy at 20m, 40m, 60m is within ±1 mm', () {
      const List<double> testDistances = [20.0, 40.0, 60.0];

      for (final double dist in testDistances) {
        // Camera aimed directly at target face center (Y = 1.30m) from eye (Y = 1.60m)
        final double cameraPitchToCenter = math.atan2(
          ArcheryK.targetCenterY - ArcheryK.eyeY,
          dist,
        );

        final double offset = SightSolver.getSightPitchOffset(dist);
        final double launchPitch = cameraPitchToCenter + offset;

        // Run full ArrowPhysics3D simulation
        final ArrowPhysics3D physics = ArrowPhysics3D();
        physics.launch(
          startPos: Vector3(0.0, ArcheryK.launchY, ArcheryK.launchZ),
          launchYaw: 0.0,
          launchPitch: launchPitch,
          speed: ArcheryK.fullDrawSpeed,
          targetDist: dist,
        );

        // Step simulation forward until hit
        while (physics.inFlight) {
          physics.update(1.0 / 60.0);
        }

        expect(physics.hitBoss, isTrue, reason: 'Arrow should hit boss at ${dist}m');
        expect(
          physics.hitLocalX.abs(),
          lessThan(0.001),
          reason: 'Horizontal deviation at ${dist}m must be < 1 mm',
        );
        expect(
          physics.hitLocalY.abs(),
          lessThan(0.001),
          reason: 'Vertical deviation at ${dist}m must be < 1 mm',
        );
      }
    });

    test('Test 6: Under-drawn arrow drops below target center', () {
      const double dist = 40.0;
      final double cameraPitchToCenter = math.atan2(
        ArcheryK.targetCenterY - ArcheryK.eyeY,
        dist,
      );
      final double offset = SightSolver.getSightPitchOffset(dist);
      final double launchPitch = cameraPitchToCenter + offset;

      // 50% draw
      const double draw = 0.50;
      final double dRatio = draw / ArcheryK.fullDrawPlateau;
      final double speed = ArcheryK.fullDrawSpeed *
          (ArcheryK.minDrawSpeedRatio + (1.0 - ArcheryK.minDrawSpeedRatio) * dRatio);

      final ArrowPhysics3D physics = ArrowPhysics3D();
      physics.launch(
        startPos: Vector3(0.0, ArcheryK.launchY, ArcheryK.launchZ),
        launchYaw: 0.0,
        launchPitch: launchPitch,
        speed: speed,
        targetDist: dist,
      );

      while (physics.inFlight) {
        physics.update(1.0 / 60.0);
      }

      // Arrow should drop lower than center (negative hitLocalY)
      expect(
        physics.hitLocalY,
        lessThan(-0.15),
        reason: '50% under-draw arrow should drop significantly below center',
      );
    });
  });
}
