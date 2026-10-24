import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/physics/dart_physics.dart';
import 'package:b_ball/darts/physics/flick_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlickSolver: launch lands on target', () {
    test('a launch for a target lands within 1 mm of it', () {
      final targets = [
        (x: 0.0, y: 0.0), // bull
        (x: 0.0, y: 103.0), // T20
        (x: 103.0, y: 0.0), // T6
        (x: 0.0, y: -166.0), // D3
        (x: -85.0, y: 60.0),
        (x: 0.0, y: 400.0), // way over the top
      ];
      for (final t in targets) {
        final physics = DartPhysics()..launch(launchVel: FlickSolver.launchFor(t.x, t.y));
        physics.simulateToEnd();
        expect((physics.hitX - t.x).abs(), lessThan(1.0), reason: '$t x');
        expect((physics.hitY - t.y).abs(), lessThan(1.0), reason: '$t y');
      }
    });
  });

  group('FlickSolver: pure flick mapping (no aim preview)', () {
    test('a straight reference flick from under the bull hits bull height', () {
      final t = FlickSolver.targetForFlick(
        releaseMmX: 0.0,
        upwardSpeed: DartsK.flickRefSpeed,
        angleDeg: 0.0,
      );
      expect(t.x, closeTo(0.0, 1e-9));
      expect(t.y, closeTo(0.0, 1e-9));
    });

    test('harder flicks go higher, softer go lower', () {
      double y(double speed) => FlickSolver.targetForFlick(
            releaseMmX: 0.0,
            upwardSpeed: speed,
            angleDeg: 0.0,
          ).y;
      expect(y(DartsK.flickRefSpeed * 1.1), greaterThan(0.0));
      expect(y(DartsK.flickRefSpeed * 0.9), lessThan(0.0));
      // 10% faster:
      expect(y(DartsK.flickRefSpeed * 1.1), closeTo(0.1 * DartsK.flickHeightMmPerUnit, 0.5));
    });

    test('treble 20 needs an intentional flick harder than the bull flick', () {
      final double trebleSpeed = DartsK.flickRefSpeed *
          (1.0 + (DartsK.trebleInR + DartsK.trebleOutR) * 0.5 / DartsK.flickHeightMmPerUnit);
      final t = FlickSolver.targetForFlick(
        releaseMmX: 0.0,
        upwardSpeed: trebleSpeed,
        angleDeg: 0.0,
      );
      expect(t.y, inInclusiveRange(DartsK.trebleInR, DartsK.trebleOutR));
    });

    test('release position sets left/right', () {
      final t = FlickSolver.targetForFlick(
        releaseMmX: -60.0,
        upwardSpeed: DartsK.flickRefSpeed,
        angleDeg: 0.0,
      );
      expect(t.x, closeTo(-60.0, 1e-9));
    });

    test('tiny thumb curves are forgiven; bigger angles drift that way', () {
      double x(double deg) => FlickSolver.targetForFlick(
            releaseMmX: 0.0,
            upwardSpeed: DartsK.flickRefSpeed,
            angleDeg: deg,
          ).x;
      expect(x(DartsK.flickDeadZoneDeg * 0.9), 0.0);
      expect(x(DartsK.flickDeadZoneDeg + 5.0), closeTo(26.2, 0.5));
      expect(x(-(DartsK.flickDeadZoneDeg + 5.0)), closeTo(-26.2, 0.5));
    });

    test('aim is clamped far off the board', () {
      final t = FlickSolver.targetForFlick(
        releaseMmX: 5000.0,
        upwardSpeed: 50.0,
        angleDeg: 80.0,
      );
      expect(t.x, DartsK.flickMaxAimMm);
      expect(t.y, DartsK.flickMaxAimMm);
    });
  });
}
