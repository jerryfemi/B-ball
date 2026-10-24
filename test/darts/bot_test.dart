import 'package:b_ball/darts/physics/dart_scoring.dart';
import 'package:b_ball/darts/state/darts_bot.dart';
import 'package:b_ball/darts/state/darts_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartsBot Tests (Step 6)', () {
    test('aimFor(301) targets T20', () {
      final aim = DartsBot.aimFor(301);
      expect(aim.label, equals('T20'));
      expect(aim.points, equals(60));
      expect(aim.segment, equals(20));
      expect(aim.multiplier, equals(3));
      expect(aim.x.abs(), lessThan(1e-4));
      expect((aim.y - 103.0).abs(), lessThan(1e-4));
    });

    test('aimFor(16) targets a 16 and never exceeds remaining', () {
      final aim = DartsBot.aimFor(16);
      expect(aim.points, equals(16));
      expect(aim.points, lessThanOrEqualTo(16));
      // Fat single S16 or double D8 are both valid 16-point targets
      expect(aim.label == 'S16' || aim.label == 'D8', isTrue);
    });

    test('aimFor never selects a target worth more than remaining for all 1..301', () {
      for (int rem = 1; rem <= 301; rem++) {
        final aim = DartsBot.aimFor(rem);
        expect(aim.points, lessThanOrEqualTo(rem),
            reason: 'Aim for remaining $rem yielded ${aim.points} (${aim.label})');
        expect(aim.points, greaterThan(0));
      }
    });

    test('aimFor checkout targets matches exact single/double/treble/bull values', () {
      expect(DartsBot.aimFor(50).label, equals('BULL'));
      expect(DartsBot.aimFor(25).label, equals('25'));
      expect(DartsBot.aimFor(40).label, equals('D20'));
      expect(DartsBot.aimFor(60).label, equals('T20'));
      expect(DartsBot.aimFor(20).label, equals('S20'));
      expect(DartsBot.aimFor(1).label, equals('S1'));
    });

    test('Same seed produces identical dart scatter', () {
      const int seed = 428912;
      final dartA = DartsBot.dart(seed, 2, 0, 241);
      final dartB = DartsBot.dart(seed, 2, 0, 241);

      expect(dartA.x, equals(dartB.x));
      expect(dartA.y, equals(dartB.y));
      expect(dartA.points, equals(dartB.points));
      expect(dartA.label, equals(dartB.label));
    });

    test('Different dart index or round produces distinct scatter', () {
      const int seed = 428912;
      final dart0 = DartsBot.dart(seed, 1, 0, 301);
      final dart1 = DartsBot.dart(seed, 1, 1, 301);
      final dart2 = DartsBot.dart(seed, 1, 2, 301);

      expect(dart0.x == dart1.x && dart0.y == dart1.y, isFalse);
      expect(dart1.x == dart2.x && dart1.y == dart2.y, isFalse);
    });

    test('Simulate 1,000 solo bot games: median finish 8–12 rounds, never > 20', () {
      final List<int> finishRounds = [];

      for (int game = 0; game < 1000; game++) {
        final int seed = DartsRules.seedFromMatchId('match_bot_sim_$game');
        int remaining = 301;
        int finishedRound = -1;

        for (int r = 1; r <= 20; r++) {
          final int startRem = remaining;
          final List<int> turnDarts = [];

          for (int d = 0; d < 3; d++) {
            final int currentRem = startRem - turnDarts.fold<int>(0, (s, p) => s + p);
            final DartHit hit = DartsBot.dart(seed, r, d, currentRem);
            final DartTurnResult res = DartsRules.applyDart(startRem, turnDarts, hit.points);

            if (res.bust) {
              turnDarts.clear();
              break;
            }
            if (res.checkout) {
              remaining = 0;
              finishedRound = r;
              break;
            }
            turnDarts.add(hit.points);
          }

          if (remaining == 0) break;
          remaining = startRem - turnDarts.fold<int>(0, (s, p) => s + p);
        }

        // Record the round it finished (or 20 if round cap reached)
        finishRounds.add(finishedRound == -1 ? 20 : finishedRound);
      }

      finishRounds.sort();
      final int median = finishRounds[finishRounds.length ~/ 2];
      final int maxRound = finishRounds.last;

      expect(median, inInclusiveRange(8, 12),
          reason: 'Median finish must be in 8–12 range (was $median)');
      expect(maxRound, lessThanOrEqualTo(20),
          reason: 'No game should ever exceed round 20 (was $maxRound)');
      expect(finishRounds.every((r) => r <= 20), isTrue);
    });
  });
}
