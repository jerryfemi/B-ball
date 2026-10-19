import 'package:b_ball/archery/physics/target_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetScoring Tests', () {
    test('Test 4: World Archery 10-ring scoring and line-cutter rule', () {
      // 1. Center hit: r = 0 -> 10 + X
      final ShotScore centerScore = TargetScoring.calculate(
        localX: 0.0,
        localY: 0.0,
        hitBoss: true,
        distance: 20.0,
        applyLineCutter: true,
      );
      expect(centerScore.ring, equals(10));
      expect(centerScore.isX, isTrue);
      expect(centerScore.displayLabel, equals('X'));

      // 2. Just inside Ring 10: r = 0.0609m -> 10
      final ShotScore inside10 = TargetScoring.calculate(
        localX: 0.0609,
        localY: 0.0,
        hitBoss: true,
        distance: 20.0,
        applyLineCutter: false,
      );
      expect(inside10.ring, equals(10));
      expect(inside10.isX, isFalse);

      // 3. Just outside Ring 10 without line cutter: r = 0.0611m -> 9
      final ShotScore outside10NoCutter = TargetScoring.calculate(
        localX: 0.0611,
        localY: 0.0,
        hitBoss: true,
        distance: 20.0,
        applyLineCutter: false,
      );
      expect(outside10NoCutter.ring, equals(9));

      // 4. Just outside Ring 10 WITH line cutter: r = 0.0611m -> 10 (shaft touches higher line)
      final ShotScore outside10WithCutter = TargetScoring.calculate(
        localX: 0.0611,
        localY: 0.0,
        hitBoss: true,
        distance: 20.0,
        applyLineCutter: true,
      );
      expect(
        outside10WithCutter.ring,
        equals(10),
        reason: 'Line cutter should award the higher 10 ring',
      );

      // 5. Outside face on boss: r = 0.62m -> 0 points
      final ShotScore bossOutsideFace = TargetScoring.calculate(
        localX: 0.62,
        localY: 0.0,
        hitBoss: true,
        distance: 20.0,
        applyLineCutter: true,
      );
      expect(bossOutsideFace.ring, equals(0));
      expect(bossOutsideFace.hitBoss, isTrue);

      // 6. Complete miss
      final ShotScore completeMiss = TargetScoring.calculate(
        localX: 2.0,
        localY: 2.0,
        hitBoss: false,
        distance: 20.0,
        applyLineCutter: true,
      );
      expect(completeMiss.ring, equals(0));
      expect(completeMiss.hitBoss, isFalse);
    });
  });
}
