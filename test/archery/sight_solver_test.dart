import 'package:b_ball/archery/archery_constants.dart';
import 'package:b_ball/archery/camera/archery_camera.dart';
import 'package:b_ball/archery/physics/arrow_physics.dart';
import 'package:b_ball/archery/physics/sight_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SightSolver & Projection Tests (Build Plan v2 §11)', () {
    test('Test 1: Crosshair -> hit within 1 mm for 25 aim points across the board', () {
      final camera = ArcheryCamera();
      camera.screenW = 1080.0;
      camera.screenH = 1920.0;
      camera.prepare();

      const double d = ArcheryK.distanceM;
      final physics = ArrowPhysics3D();

      // Test 5x5 grid across the 1.0m board
      for (int ix = -2; ix <= 2; ix++) {
        for (int iy = -2; iy <= 2; iy++) {
          final double targetX = ix * 0.18; // -0.36m to +0.36m
          final double targetY = ArcheryK.targetCenterY + iy * 0.18;

          // Project to screen then unproject
          camera.project(targetX, targetY, d);
          final double screenX = camera.sx;
          final double screenY = camera.sy;

          camera.unprojectToPlane(screenX, screenY, d);
          final double px = camera.outX;
          final double py = camera.outY;

          // Solve yaw and pitch
          final double yaw = SightSolver.solveYaw(d, px);
          final double pitch = SightSolver.solvePitch(d, py);

          // Launch arrow with zero wind and zero sway
          physics.launch(
            startX: 0.0,
            startY: ArcheryK.launchY,
            startZ: ArcheryK.launchZ,
            launchYaw: yaw,
            launchPitch: pitch,
            speed: ArcheryK.fullDrawSpeed,
            targetDist: d,
          );

          while (physics.inFlight) {
            physics.update(ArcheryK.fixedDt);
          }

          expect(physics.hitBoss, isTrue);
          final double errorX = (physics.hitPoint.x - px).abs();
          final double errorY = (physics.hitPoint.y - py).abs();

          expect(
            errorX,
            lessThan(0.001),
            reason: 'Aim point ($targetX, $targetY): X error ${errorX * 1000}mm must be < 1mm',
          );
          expect(
            errorY,
            lessThan(0.001),
            reason: 'Aim point ($targetX, $targetY): Y error ${errorY * 1000}mm must be < 1mm',
          );
        }
      }
    });

    test('Test 5: Projection round-trip: project(unprojectToPlane(p)) == p within 0.01 px', () {
      final camera = ArcheryCamera();
      camera.screenW = 1080.0;
      camera.screenH = 1920.0;
      camera.prepare();

      const double d = ArcheryK.distanceM;

      // Test various screen pixels
      final testPoints = [
        [540.0, 960.0],
        [300.0, 500.0],
        [800.0, 1400.0],
        [100.0, 200.0],
        [1000.0, 1800.0],
      ];

      for (final pt in testPoints) {
        final double sx = pt[0];
        final double sy = pt[1];

        // 1. Unproject screen point to plane Z = D
        camera.unprojectToPlane(sx, sy, d);
        final double wx = camera.outX;
        final double wy = camera.outY;

        // 2. Project world point back to screen
        final bool visible = camera.project(wx, wy, d);
        expect(visible, isTrue);

        expect((camera.sx - sx).abs(), lessThan(0.01), reason: 'X round-trip failed');
        expect((camera.sy - sy).abs(), lessThan(0.01), reason: 'Y round-trip failed');
      }
    });
  });
}
