import 'package:b_ball/darts/physics/dart_physics.dart';
import 'package:b_ball/darts/physics/flick_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlickSolver Tests (Step 5)', () {
    test('Ideal flick lands within 1 mm of aim point', () {
      final targets = [
        (x: 0.0, y: 0.0), // Centre bull
        (x: 0.0, y: 103.0), // T20
        (x: 103.0, y: 0.0), // T6
        (x: 0.0, y: -166.0), // D3
        (x: -85.0, y: 60.0), // General quadrant
      ];

      for (final t in targets) {
        final ideal = FlickSolver.launchFor(t.x, t.y);
        final flicked = FlickSolver.applyFlick(ideal, 1.0, 0.0);

        final physics = DartPhysics()..launch(launchVel: flicked);
        physics.simulateToEnd();

        final double errX = (physics.hitX - t.x).abs();
        final double errY = (physics.hitY - t.y).abs();

        expect(errX, lessThan(1.0),
            reason: 'Horizontal error must be < 1 mm for aim (${t.x}, ${t.y})');
        expect(errY, lessThan(1.0),
            reason: 'Vertical error must be < 1 mm for aim (${t.x}, ${t.y})');
      }
    });

    test('Power 0.8 and 1.3 (sweet band boundaries) land within 1 mm of aim', () {
      final ideal = FlickSolver.launchFor(0.0, 0.0);

      // Low boundary of sweet band: 0.8
      final flick08 = FlickSolver.applyFlick(ideal, 0.8, 0.0);
      final p08 = DartPhysics()..launch(launchVel: flick08);
      p08.simulateToEnd();
      expect(p08.hitY.abs(), lessThan(1.0),
          reason: 'Power 0.8 is inside sweet band and should have zero error');

      // High boundary of sweet band: 1.3
      final flick13 = FlickSolver.applyFlick(ideal, 1.3, 0.0);
      final p13 = DartPhysics()..launch(launchVel: flick13);
      p13.simulateToEnd();
      expect(p13.hitY.abs(), lessThan(1.0),
          reason: 'Power 1.3 is inside sweet band and should have zero error');
    });

    test('Power 0.6 lands lower than aim by 20–45 mm', () {
      final ideal = FlickSolver.launchFor(0.0, 0.0);
      final flick06 = FlickSolver.applyFlick(ideal, 0.6, 0.0);

      final physics = DartPhysics()..launch(launchVel: flick06);
      physics.simulateToEnd();

      final double dropMm = 0.0 - physics.hitY; // positive when landing lower
      expect(dropMm, greaterThanOrEqualTo(20.0),
          reason: 'Power 0.6 must drop at least 20 mm');
      expect(dropMm, lessThanOrEqualTo(45.0),
          reason: 'Power 0.6 must not drop more than 45 mm');
    });

    test('Power 1.6 lands higher than aim', () {
      final ideal = FlickSolver.launchFor(0.0, 0.0);
      final flick16 = FlickSolver.applyFlick(ideal, 1.6, 0.0);

      final physics = DartPhysics()..launch(launchVel: flick16);
      physics.simulateToEnd();

      final double riseMm = physics.hitY - 0.0;
      expect(riseMm, greaterThan(20.0),
          reason: 'Power 1.6 must land significantly higher than aim');
      expect(riseMm, lessThan(55.0));
    });

    test('6° flick angle (boundary of angle sweet band) lands within 1 mm of aim', () {
      final ideal = FlickSolver.launchFor(0.0, 0.0);

      // +6° right
      final flickPos6 = FlickSolver.applyFlick(ideal, 1.0, 6.0);
      final pPos6 = DartPhysics()..launch(launchVel: flickPos6);
      pPos6.simulateToEnd();
      expect(pPos6.hitX.abs(), lessThan(1.0));

      // -6° left
      final flickNeg6 = FlickSolver.applyFlick(ideal, 1.0, -6.0);
      final pNeg6 = DartPhysics()..launch(launchVel: flickNeg6);
      pNeg6.simulateToEnd();
      expect(pNeg6.hitX.abs(), lessThan(1.0));
    });

    test('16° flick angle lands 20–30 mm sideways on that side', () {
      final ideal = FlickSolver.launchFor(0.0, 0.0);

      // +16° flick to right: excess 10° -> should land 20-30 mm right
      final flickRight16 = FlickSolver.applyFlick(ideal, 1.0, 16.0);
      final pRight = DartPhysics()..launch(launchVel: flickRight16);
      pRight.simulateToEnd();
      expect(pRight.hitX, greaterThanOrEqualTo(20.0));
      expect(pRight.hitX, lessThanOrEqualTo(30.0));

      // -16° flick to left: excess -10° -> should land 20-30 mm left
      final flickLeft16 = FlickSolver.applyFlick(ideal, 1.0, -16.0);
      final pLeft = DartPhysics()..launch(launchVel: flickLeft16);
      pLeft.simulateToEnd();
      expect(pLeft.hitX, lessThanOrEqualTo(-20.0));
      expect(pLeft.hitX, greaterThanOrEqualTo(-30.0));
    });
  });
}
