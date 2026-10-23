import 'package:b_ball/darts/physics/dart_physics.dart';
import 'package:b_ball/darts/physics/flick_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartPhysics & Frame Rate Independence Tests (Step 5)', () {
    test('Continuous plane-crossing resolves hit accurately without tunneling', () {
      final physics = DartPhysics();
      final launch = FlickSolver.launchFor(0.0, 0.0);
      physics.launch(launchVel: launch);

      physics.simulateToEnd();

      expect(physics.hasHit, isTrue);
      expect(physics.pos.z, equals(0.0));
      expect(physics.hitX.abs(), lessThan(0.5));
      expect(physics.hitY.abs(), lessThan(0.5));
    });

    test('Result is identical across 30, 60, and 120 fps frame splits', () {
      final launch = FlickSolver.launchFor(35.0, -85.0);

      // Simulation 1: 30 FPS (dt = 1/30 s)
      final p30 = DartPhysics();
      p30.launch(launchVel: launch);
      while (p30.inFlight) {
        p30.update(1.0 / 30.0);
      }

      // Simulation 2: 60 FPS (dt = 1/60 s)
      final p60 = DartPhysics();
      p60.launch(launchVel: launch);
      while (p60.inFlight) {
        p60.update(1.0 / 60.0);
      }

      // Simulation 3: 120 FPS (dt = 1/120 s)
      final p120 = DartPhysics();
      p120.launch(launchVel: launch);
      while (p120.inFlight) {
        p120.update(1.0 / 120.0);
      }

      // Exact matches across frame rates
      expect((p30.hitX - p60.hitX).abs(), lessThan(1e-4),
          reason: 'hitX at 30 fps must match 60 fps');
      expect((p30.hitY - p60.hitY).abs(), lessThan(1e-4),
          reason: 'hitY at 30 fps must match 60 fps');

      expect((p60.hitX - p120.hitX).abs(), lessThan(1e-4),
          reason: 'hitX at 60 fps must match 120 fps');
      expect((p60.hitY - p120.hitY).abs(), lessThan(1e-4),
          reason: 'hitY at 60 fps must match 120 fps');
    });
  });
}
