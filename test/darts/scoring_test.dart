import 'dart:math' as math;
import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/physics/dart_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartScoring Tests (Step 2)', () {
    test('Centre (0, 0) scores BULL 50', () {
      final hit = DartScoring.score(0.0, 0.0);
      expect(hit.segment, equals(25));
      expect(hit.multiplier, equals(2));
      expect(hit.points, equals(50));
      expect(hit.label, equals('BULL'));
      expect(hit.isBull, isTrue);
      expect(hit.isInnerBull, isTrue);
      expect(hit.isDouble, isTrue);
      expect(hit.isTreble, isFalse);
      expect(hit.isMiss, isFalse);
    });

    test('Outer bull (e.g. r = 11 mm) scores 25', () {
      final hit = DartScoring.score(0.0, 11.0);
      expect(hit.segment, equals(25));
      expect(hit.multiplier, equals(1));
      expect(hit.points, equals(25));
      expect(hit.label, equals('25'));
      expect(hit.isBull, isTrue);
      expect(hit.isInnerBull, isFalse);
      expect(hit.isTreble, isFalse);
      expect(hit.isMiss, isFalse);
    });

    test('(0, 103) straight up scores T20 (60 points)', () {
      final hit = DartScoring.score(0.0, 103.0);
      expect(hit.segment, equals(20));
      expect(hit.multiplier, equals(3));
      expect(hit.points, equals(60));
      expect(hit.label, equals('T20'));
      expect(hit.isTreble, isTrue);
      expect(hit.isBull, isFalse);
      expect(hit.isMiss, isFalse);
    });

    test('(0, -166) straight down scores D3 (6 points)', () {
      final hit = DartScoring.score(0.0, -166.0);
      expect(hit.segment, equals(3));
      expect(hit.multiplier, equals(2));
      expect(hit.points, equals(6));
      expect(hit.label, equals('D3'));
      expect(hit.isDouble, isTrue);
      expect(hit.isTreble, isFalse);
      expect(hit.isBull, isFalse);
    });

    test('(103, 0) straight right scores T6 (18 points)', () {
      final hit = DartScoring.score(103.0, 0.0);
      expect(hit.segment, equals(6));
      expect(hit.multiplier, equals(3));
      expect(hit.points, equals(18));
      expect(hit.label, equals('T6'));
      expect(hit.isTreble, isTrue);
      expect(hit.isBull, isFalse);
    });

    test('Segment boundaries: 8.9° right of top is S20, 9.1° right of top is S1', () {
      // At r = 135 mm (fat single)
      const double r = 135.0;

      // 8.9° clockwise from top (still in segment 20, which covers -9° to +9°)
      final double rad20 = 8.9 * math.pi / 180.0;
      final hit20 = DartScoring.score(r * math.sin(rad20), r * math.cos(rad20));
      expect(hit20.segment, equals(20));
      expect(hit20.points, equals(20));
      expect(hit20.label, equals('S20'));

      // 9.1° clockwise from top (crossed wire into segment 1)
      final double rad1 = 9.1 * math.pi / 180.0;
      final hit1 = DartScoring.score(r * math.sin(rad1), r * math.cos(rad1));
      expect(hit1.segment, equals(1));
      expect(hit1.points, equals(1));
      expect(hit1.label, equals('S1'));
    });

    test('r = 171 mm is MISS (0 points)', () {
      final hit = DartScoring.score(0.0, 171.0);
      expect(hit.segment, equals(0));
      expect(hit.multiplier, equals(0));
      expect(hit.points, equals(0));
      expect(hit.label, equals('MISS'));
      expect(hit.isMiss, isTrue);
      expect(hit.isBull, isFalse);
      expect(hit.isTreble, isFalse);
    });

    test('Every segment centre at r = 135 mm scores its single', () {
      for (int i = 0; i < DartsK.segmentOrder.length; i++) {
        final int expectedSeg = DartsK.segmentOrder[i];
        final coords = DartScoring.targetCoordinates(
          segment: expectedSeg,
          multiplier: 1,
          customR: 135.0,
        );

        final hit = DartScoring.score(coords.x, coords.y);
        expect(hit.segment, equals(expectedSeg),
            reason: 'Segment $expectedSeg failed at (${coords.x}, ${coords.y})');
        expect(hit.multiplier, equals(1));
        expect(hit.points, equals(expectedSeg));
        expect(hit.label, equals('S$expectedSeg'));
        expect(hit.isMiss, isFalse);
      }
    });

    test('DartHit serialization round-trip', () {
      final original = DartScoring.score(0.0, 103.0);
      final map = original.toMap();
      final restored = DartHit.fromMap(map);
      expect(restored, equals(original));
      expect(restored.label, equals('T20'));
      expect(restored.points, equals(60));
    });
  });
}
