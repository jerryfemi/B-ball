import 'dart:math' as math;
import 'package:b_ball/archery/archery_constants.dart';
import 'package:b_ball/archery/physics/arrow_physics.dart';
import 'package:b_ball/archery/physics/sight_solver.dart';
import 'package:b_ball/archery/physics/sway_model.dart';
import 'package:b_ball/archery/physics/wind_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wind & Sway Tests (Build Plan v2 §11)', () {
    test('Test 2: Wind drift at 50ft (15.24m)', () {
      const double d = ArcheryK.distanceM;
      final double pitch = SightSolver.solvePitch(d, ArcheryK.targetCenterY);

      // Baseline: Zero wind
      final physics0 = ArrowPhysics3D();
      physics0.launch(
        startX: 0.0,
        startY: ArcheryK.launchY,
        startZ: ArcheryK.launchZ,
        launchYaw: 0.0,
        launchPitch: pitch,
        speed: ArcheryK.fullDrawSpeed,
        targetDist: d,
        windModel: WindModel(display: 0.0, angle: 0.0),
      );
      while (physics0.inFlight) {
        physics0.update(ArcheryK.fixedDt);
      }
      expect(physics0.hitLocalX.abs(), lessThan(0.001));
      final double baselineY = physics0.hitLocalY;

      // 1. Crosswind (display 1.0, angle π/2 = blowing right +X)
      // Drift ≈ 1/2 * a * t^2 ≈ 1/2 * 1.9 * (15.24/62)^2 ≈ 0.057 m = 5.7 cm (within 5-7 cm)
      final physicsCross = ArrowPhysics3D();
      physicsCross.launch(
        startX: 0.0,
        startY: ArcheryK.launchY,
        startZ: ArcheryK.launchZ,
        launchYaw: 0.0,
        launchPitch: pitch,
        speed: ArcheryK.fullDrawSpeed,
        targetDist: d,
        windModel: WindModel(display: 1.0, angle: math.pi * 0.5),
      );
      while (physicsCross.inFlight) {
        physicsCross.update(ArcheryK.fixedDt);
      }
      expect(physicsCross.hitLocalX, inInclusiveRange(0.05, 0.07),
          reason: 'Crosswind 1.0 at π/2 should drift +X by 5 to 7 cm');

      // 2. Tailwind (display 1.0, angle 0.0 = blowing downrange +Z)
      // Accelerates along track -> arrow reaches target sooner -> less gravity drop -> lands slightly higher
      final physicsTail = ArrowPhysics3D();
      physicsTail.launch(
        startX: 0.0,
        startY: ArcheryK.launchY,
        startZ: ArcheryK.launchZ,
        launchYaw: 0.0,
        launchPitch: pitch,
        speed: ArcheryK.fullDrawSpeed,
        targetDist: d,
        windModel: WindModel(display: 1.0, angle: 0.0),
      );
      while (physicsTail.inFlight) {
        physicsTail.update(ArcheryK.fixedDt);
      }
      expect(physicsTail.hitLocalY, greaterThan(baselineY),
          reason: 'Tailwind must raise hit point slightly compared to zero-wind baseline');
    });

    test('Test 3: Seeds determinism for (matchSeed, set, arrow)', () {
      int hashSeed(int matchSeed, int setIndex, int arrowIndex) {
        int h = matchSeed;
        h = (h * 31 + setIndex) & 0x7FFFFFFF;
        h = (h * 31 + arrowIndex) & 0x7FFFFFFF;
        return h;
      }

      final int seedA1 = hashSeed(101, 0, 0);
      final int seedA2 = hashSeed(101, 0, 0);
      final int seedB = hashSeed(101, 0, 1);

      final wind1 = WindModel.fromSeed(seedA1);
      final wind2 = WindModel.fromSeed(seedA2);
      final windOther = WindModel.fromSeed(seedB);

      // Same seed must produce identical wind
      expect(wind1.display, equals(wind2.display));
      expect(wind1.angle, equals(wind2.angle));
      expect(wind1.getLateralAccel(0.1), equals(wind2.getLateralAccel(0.1)));

      // Different arrow must produce different wind
      expect(
        wind1.display != windOther.display || wind1.angle != windOther.angle,
        isTrue,
        reason: 'Different arrows in a set must generate different wind parameters',
      );
    });

    test('Test 4: Sway curve A(0) > A(2.5) and A(4.9) > A(2.5) (shaky -> steady -> shaky)', () {
      final sway = SwayModel(seed: 42);

      final double aStart = sway.getAmplitude(0.0);
      final double aSteady = sway.getAmplitude(2.5);
      final double aFatigue = sway.getAmplitude(4.9);

      expect(aStart, greaterThan(aSteady),
          reason: 'Initial touch settle sway A(0) must be larger than steady window A(2.5)');
      expect(aFatigue, greaterThan(aSteady),
          reason: 'Arm fatigue sway near timer end A(4.9) must be larger than steady window A(2.5)');
    });
  });
}
