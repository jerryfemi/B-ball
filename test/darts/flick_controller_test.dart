import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

import 'package:b_ball/darts/input/flick_controller.dart';
import 'package:b_ball/darts/scene/board_projection.dart';

void main() {
  group('Step 11 — FlickController Tests', () {
    late BoardProjection projection;
    late FlickController controller;

    setUp(() {
      projection = BoardProjection();
      projection.resize(Vector2(400, 800));
      controller = FlickController(projection: projection);
      controller.initWobbleSeed(matchSeed: 12345, round: 1, dartIndex: 0);
    });

    test('Touch in upper 40% of screen is ignored', () {
      // Screen height is 800. 40% threshold = 320 px.
      controller.onPointerDown(1, 200, 300); // y = 300 < 320
      expect(controller.isAiming, isFalse);

      controller.onPointerDown(1, 200, 150);
      expect(controller.isAiming, isFalse);
    });

    test('Touch in lower 60% of screen initiates aim', () {
      // y = 500 >= 320
      bool aimStarted = false;
      controller.onAimStart = () => aimStarted = true;

      controller.onPointerDown(1, 200, 500);
      expect(controller.isAiming, isTrue);
      expect(aimStarted, isTrue);
    });

    test('Drag updates aim coordinates with thumb-roll sensitivity', () {
      controller.onPointerDown(1, 200, 500);

      // Drag right by 20 px and up by 30 px
      controller.onPointerMove(1, 220, 470);

      // Delta: +20px right -> +x, -30px up (lower Y) -> +y in board mm
      expect(controller.rawAimMmX, greaterThan(0.0));
      expect(controller.rawAimMmY, greaterThan(0.0));
    });

    test('Slow release without flick cancels aim without throwing', () {
      bool throwCalled = false;
      bool cancelCalled = false;
      controller.onThrow = (_) => throwCalled = true;
      controller.onAimCancel = () => cancelCalled = true;

      controller.onPointerDown(1, 200, 500);

      // Hold still for 0.1s
      controller.update(0.10);
      controller.onPointerMove(1, 200, 500);

      // Release without upward flick
      controller.onPointerUp(1);

      expect(controller.isAiming, isFalse);
      expect(throwCalled, isFalse);
      expect(cancelCalled, isTrue);
    });

    test('Upward flick throws with ballistic launch velocity', () {
      vm64.Vector3? launchedVelocity;
      controller.onThrow = (vel) => launchedVelocity = vel;

      controller.onPointerDown(1, 200, 600);
      controller.update(0.05);

      // Rapid upward swipe: moves from y = 600 to y = 450 over 0.06s
      // Upward speed: 150 px / (800 px * 0.06s) = 3.125 screen-heights/s >= minFlick (0.50)
      controller.onPointerMove(1, 200, 450);
      controller.update(0.06);

      controller.onPointerUp(1);

      expect(controller.isAiming, isFalse);
      expect(launchedVelocity, isNotNull);
      // Dart flies towards board (-z)
      expect(launchedVelocity!.z, lessThan(0.0));
      expect(launchedVelocity!.y, greaterThan(0.0));
    });

    test('Wobble model updates shown coordinates during hold', () {
      controller.onPointerDown(1, 200, 500);

      // Advance hold time through steady and fatigue phases
      controller.update(0.2);
      final double wobble1 =
          (controller.shownMmX - controller.rawAimMmX).abs() +
          (controller.shownMmY - controller.rawAimMmY).abs();
      expect(wobble1, greaterThan(0.0));

      controller.update(3.5); // hold time = 3.7s (fatigue phase)
      expect(controller.holdTime, closeTo(3.7, 0.05));
    });
  });
}
