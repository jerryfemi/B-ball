import 'package:b_ball/darts/state/darts_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartsRules Tests (Step 3)', () {
    test('20 left + T20 (60 pts) -> bust, turn = 0, turn over', () {
      final res = DartsRules.applyDart(20, const [], 60);
      expect(res.bust, isTrue);
      expect(res.checkout, isFalse);
      expect(res.turnOver, isTrue);
      expect(res.newTurnTotal, equals(0));
      expect(res.remainingAfter, equals(20));
      expect(res.dartsUsed, equals(1));
    });

    test('40 left + D20 (40 pts) -> checkout, turnOver: true', () {
      final res = DartsRules.applyDart(40, const [], 40);
      expect(res.bust, isFalse);
      expect(res.checkout, isTrue);
      expect(res.turnOver, isTrue);
      expect(res.newTurnTotal, equals(40));
      expect(res.remainingAfter, equals(0));
      expect(res.dartsUsed, equals(1));
    });

    test('2 left + S1 (1 pt) + S1 (1 pt) -> checkout on dart 2', () {
      // Dart 1: S1
      final d1 = DartsRules.applyDart(2, const [], 1);
      expect(d1.bust, isFalse);
      expect(d1.checkout, isFalse);
      expect(d1.turnOver, isFalse);
      expect(d1.newTurnTotal, equals(1));
      expect(d1.remainingAfter, equals(1));
      expect(d1.dartsUsed, equals(1));

      // Dart 2: S1
      final d2 = DartsRules.applyDart(2, const [1], 1);
      expect(d2.bust, isFalse);
      expect(d2.checkout, isTrue);
      expect(d2.turnOver, isTrue);
      expect(d2.newTurnTotal, equals(2));
      expect(d2.remainingAfter, equals(0));
      expect(d2.dartsUsed, equals(2));
    });

    test('Normal 3-dart turn finishes on 3rd dart', () {
      final d1 = DartsRules.applyDart(301, const [], 60);
      expect(d1.turnOver, isFalse);

      final d2 = DartsRules.applyDart(301, const [60], 60);
      expect(d2.turnOver, isFalse);

      final d3 = DartsRules.applyDart(301, const [60, 60], 60);
      expect(d3.turnOver, isTrue);
      expect(d3.bust, isFalse);
      expect(d3.checkout, isFalse);
      expect(d3.newTurnTotal, equals(180));
      expect(d3.remainingAfter, equals(121));
    });

    test('Equal turns: P1 checks out round 6, P2 does not -> P1 wins only after P2 round-6 turn', () {
      // 5 full rounds previously played
      final p1Turns = [60, 60, 60, 60, 41]; // 281 points total, 20 left
      final p2Turns = [40, 40, 40, 40, 40]; // 200 points total, 101 left

      // Round 6: P1 throws 20 (checkout!)
      final p1Round6 = [...p1Turns, 20]; // 301 total, 0 left

      // Mid-round 6: P1 finished, but P2 hasn't thrown yet
      expect(
        DartsRules.isMatchOver(p1Round6, p2Turns),
        isFalse,
        reason: 'Match is not over until P2 completes their round-6 turn',
      );

      // P2 throws round 6 (scores 40, leaves 61)
      final p2Round6 = [...p2Turns, 40];

      // End of round 6: both have equal turns
      expect(DartsRules.isMatchOver(p1Round6, p2Round6), isTrue);
      expect(DartsRules.winner(p1Round6, p2Round6), equals(1),
          reason: 'P1 checked out and P2 did not');
    });

    test('Equal turns tiebreaker: both checkout round 6, P1 with 2 darts and P2 with 3 -> P1 wins', () {
      final p1Turns = [60, 60, 60, 60, 41, 20]; // 301 total, 0 left
      final p2Turns = [60, 60, 60, 60, 41, 20]; // 301 total, 0 left

      expect(DartsRules.isMatchOver(p1Turns, p2Turns), isTrue);

      // P1 used 2 darts in round 6, P2 used 3 darts
      final winP1 = DartsRules.winner(
        p1Turns,
        p2Turns,
        p1LastDarts: 2,
        p2LastDarts: 3,
      );
      expect(winP1, equals(1), reason: 'P1 used fewer darts in checkout turn');

      // If P2 used 1 dart and P1 used 2 darts -> P2 wins
      final winP2 = DartsRules.winner(
        p1Turns,
        p2Turns,
        p1LastDarts: 2,
        p2LastDarts: 1,
      );
      expect(winP2, equals(-1), reason: 'P2 used fewer darts in checkout turn');

      // If both used same darts -> draw
      final draw = DartsRules.winner(
        p1Turns,
        p2Turns,
        p1LastDarts: 2,
        p2LastDarts: 2,
      );
      expect(draw, equals(0), reason: 'Equal darts used in checkout turn results in draw');
    });

    test('Round 20 cap: lower remaining total wins; equal -> draw', () {
      // 20 rounds without checkout
      final p1Turns = List.filled(20, 13); // 260 total -> 41 left
      final p2Turns = List.filled(20, 12); // 240 total -> 61 left

      expect(DartsRules.isMatchOver(p1Turns, p2Turns), isTrue);
      expect(DartsRules.winner(p1Turns, p2Turns), equals(1),
          reason: 'P1 has 41 left vs P2 61 left -> P1 wins');

      // Swap totals: P2 has lower remaining
      final p1Worse = List.filled(20, 10); // 200 total -> 101 left
      final p2Better = List.filled(20, 14); // 280 total -> 21 left
      expect(DartsRules.winner(p1Worse, p2Better), equals(-1));

      // Equal remaining -> Draw
      final p1Equal = List.filled(20, 12); // 61 left
      final p2Equal = List.filled(20, 12); // 61 left
      expect(DartsRules.winner(p1Equal, p2Equal), equals(0));
    });

    test('seedFromMatchId is deterministic and non-zero', () {
      final s1 = DartsRules.seedFromMatchId('match_abc123');
      final s2 = DartsRules.seedFromMatchId('match_abc123');
      final s3 = DartsRules.seedFromMatchId('MATCH_ABC123');
      final sOther = DartsRules.seedFromMatchId('match_xyz999');

      expect(s1, equals(s2));
      expect(s1, equals(s3), reason: 'Case insensitive match ID hashing');
      expect(s1, isNot(equals(sOther)));
      expect(s1, isPositive);
    });
  });
}
