import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/input/flick_controller.dart';
import 'package:b_ball/darts/physics/dart_physics.dart';
import 'package:b_ball/darts/scene/board_projection.dart';

void main() {
  group('FlickController: pure flick', () {
    late BoardProjection projection;
    late FlickController controller;
    late double now;

    setUp(() {
      projection = BoardProjection()..resize(Vector2(400, 800));
      now = 0.0;
      controller = FlickController(projection: projection, now: () => now);
    });

    /// Swipes from (x, y0) straight up to (x + dx, y1) in [ms] milliseconds,
    /// in 10 steps, then lets go.
    void swipe({
      required double x,
      required double y0,
      required double y1,
      double dx = 0.0,
      required double ms,
    }) {
      controller.onPointerDown(1, x, y0);
      for (int i = 1; i <= 10; i++) {
        now += ms / 10000.0;
        controller.onPointerMove(1, x + dx * i / 10, y0 + (y1 - y0) * i / 10);
      }
      controller.onPointerUp(1);
    }

    test('touches in the top part of the screen do not pick the dart up', () {
      controller.onPointerDown(1, 200, 800 * DartsK.flickTouchTopFrac - 10);
      expect(controller.isHolding, isFalse);
    });

    test('touching the lower screen picks the dart up and it follows the finger', () {
      bool picked = false;
      controller.onPickUp = () => picked = true;
      controller.onPointerDown(1, 200, 700);
      expect(controller.isHolding, isTrue);
      expect(picked, isTrue);
      controller.onPointerMove(1, 150, 680);
      expect(controller.fingerX, 150);
      expect(controller.fingerY, 680);
    });

    test('letting go without an upward flick drops the dart (no throw)', () {
      bool dropped = false;
      bool thrown = false;
      controller.onDrop = () => dropped = true;
      controller.onThrow = (_) => thrown = true;
      swipe(x: 200, y0: 700, y1: 690, ms: 400); // slow drift
      expect(dropped, isTrue);
      expect(thrown, isFalse);
    });

    test('stopping before lifting the finger is not a flick', () {
      bool thrown = false;
      controller.onThrow = (_) => thrown = true;
      controller.onPointerDown(1, 200, 700);
      now += 0.05;
      controller.onPointerMove(1, 200, 500);
      now += 0.30; // hold still, then lift
      controller.onPointerUp(1);
      expect(thrown, isFalse);
    });

    test('a straight reference-speed flick under the bull lands near the bull', () {
      vm64.Vector3? launch;
      controller.onThrow = (v) => launch = v;
      // Reference speed: 2.4 screen heights/s = 1920 px/s on an 800 px screen.
      const double ms = 100.0;
      const double dist = DartsK.flickRefSpeed * 800 * ms / 1000;
      swipe(x: projection.boardCenterX, y0: 700, y1: 700 - dist, ms: ms);
      expect(launch, isNotNull);
      final physics = DartPhysics()..launch(launchVel: launch!);
      physics.simulateToEnd();
      expect(physics.hitX.abs(), lessThan(2.0));
      expect(physics.hitY.abs(), lessThan(2.0));
    });

    test('a harder flick lands higher than a softer one', () {
      controller.onThrow = (_) {};
      swipe(x: 200, y0: 700, y1: 400, ms: 120);
      final double hard = controller.lastTargetMmY;
      swipe(x: 200, y0: 700, y1: 550, ms: 120);
      final double soft = controller.lastTargetMmY;
      expect(hard, greaterThan(soft));
    });

    test('a flick angled right drifts right', () {
      controller.onThrow = (_) {};
      swipe(x: 200, y0: 700, y1: 450, dx: 60, ms: 120);
      expect(controller.lastTargetMmX, greaterThan(20.0));
    });

    test('pointer cancel drops a held dart', () {
      bool dropped = false;
      controller.onDrop = () => dropped = true;
      controller.onPointerDown(1, 200, 700);
      controller.onPointerCancel();
      expect(controller.isHolding, isFalse);
      expect(dropped, isTrue);
    });

    test('no input while disabled', () {
      controller.inputEnabled = false;
      controller.onPointerDown(1, 200, 700);
      expect(controller.isHolding, isFalse);
    });
  });
}
