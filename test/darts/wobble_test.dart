import 'package:b_ball/darts/physics/wobble_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WobbleModel Tests (Step 4)', () {
    test('Amplitude envelope: 0.1 s (settle) > 1.5 s (steady); 4.8 s (fatigue) > 1.5 s', () {
      final wobble = WobbleModel(seed: 12345);

      final double ampSettle = wobble.getAmplitude(0.1);
      final double ampSteady = wobble.getAmplitude(1.5);
      final double ampFatigue = wobble.getAmplitude(4.8);

      expect(ampSettle, greaterThan(ampSteady),
          reason: 'Initial settling amplitude at 0.1s must be larger than steady window at 1.5s');
      expect(ampFatigue, greaterThan(ampSteady),
          reason: 'Fatigue shake amplitude at 4.8s must be larger than steady window at 1.5s');
      expect(ampFatigue, greaterThan(ampSettle),
          reason: 'Full fatigue ramps up beyond settling wobble');
    });

    test('Same seed produces identical outputs dx, dy', () {
      final w1 = WobbleModel(seed: 987654);
      final w2 = WobbleModel(seed: 987654);

      // Check outputs across multiple simulated timestamps
      for (double t = 0.0; t <= 5.5; t += 0.25) {
        w1.update(t, true);
        w2.update(t, true);

        expect(w1.dx, equals(w2.dx), reason: 'dx must match exactly at t=$t');
        expect(w1.dy, equals(w2.dy), reason: 'dy must match exactly at t=$t');
      }
    });

    test('Different seeds produce different wobble patterns', () {
      final w1 = WobbleModel(seed: 1111);
      final w2 = WobbleModel(seed: 2222);

      w1.update(1.0, true);
      w2.update(1.0, true);

      expect(w1.dx, isNot(equals(w2.dx)));
      expect(w1.dy, isNot(equals(w2.dy)));
    });

    test('seedFor produces consistent deterministic integer seeds', () {
      final s1 = WobbleModel.seedFor(42, 3, 1);
      final s2 = WobbleModel.seedFor(42, 3, 1);
      final s3 = WobbleModel.seedFor(42, 3, 2);

      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
      expect(s1, isPositive);
    });

    test('Inactive holding returns dx = 0, dy = 0', () {
      final w = WobbleModel(seed: 777);
      w.update(1.5, false);

      expect(w.dx, equals(0.0));
      expect(w.dy, equals(0.0));
    });

    test('Fatigue plateau: amplitude beyond 5.0s stays at maximum without runaway', () {
      final wobble = WobbleModel(seed: 12345);
      final double at5 = wobble.getAmplitude(5.0);
      final double at6 = wobble.getAmplitude(6.0);
      final double at10 = wobble.getAmplitude(10.0);

      expect((at6 - at5).abs(), lessThan(0.05),
          reason: 'Amplitude stays capped at fatigue plateau');
      expect((at10 - at5).abs(), lessThan(0.05),
          reason: 'Amplitude does not run away when held for long');
    });
  });
}
