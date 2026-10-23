import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:b_ball/darts/physics/dart_scoring.dart';
import 'package:b_ball/darts/state/darts_match_notifier.dart';
import 'package:b_ball/darts/state/darts_match_state.dart';

void main() {
  group('Step 12 — Solo Bot Turn Flow & Equal Turns Rule', () {
    test('3 player darts complete turn and hand turn to opponent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);
      final initial = container.read(dartsMatchProvider);
      expect(initial.isMyTurn, isTrue);
      expect(initial.round, equals(1));

      // Dart 1: T20 (60)
      final hitT20 = DartScoring.score(0.0, 103.0);
      final res1 = notifier.dartLanded(hitT20);
      expect(res1.turnOver, isFalse);
      expect(container.read(dartsMatchProvider).dartIndex, equals(1));

      // Dart 2: T20 (60)
      final res2 = notifier.dartLanded(hitT20);
      expect(res2.turnOver, isFalse);
      expect(container.read(dartsMatchProvider).dartIndex, equals(2));

      // Dart 3: T20 (60) -> completes turn (180 points)
      final res3 = notifier.dartLanded(hitT20);
      expect(res3.turnOver, isTrue);

      final postTurn = container.read(dartsMatchProvider);
      expect(postTurn.yourTurns, equals([180]));
      expect(postTurn.yourRemaining, equals(121));
      expect(postTurn.thrower, equals(DartsThrower.opponent));
      expect(postTurn.isMyTurn, isFalse);
    });

    test('Bot turn executes and finalizes round back to player for round 2', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);

      // Player completes Round 1 turn
      final hitT20 = DartScoring.score(0.0, 103.0);
      notifier.dartLanded(hitT20);
      notifier.dartLanded(hitT20);
      notifier.dartLanded(hitT20);

      expect(container.read(dartsMatchProvider).thrower, equals(DartsThrower.opponent));

      // Bot throws 3 darts in Round 1
      for (int i = 0; i < 3; i++) {
        final botHit = notifier.botNextDart();
        expect(botHit, isNotNull);
      }

      final round2 = container.read(dartsMatchProvider);
      expect(round2.round, equals(2));
      expect(round2.thrower, equals(DartsThrower.you));
      expect(round2.isMyTurn, isTrue);
      expect(round2.theirTurns.length, equals(1));
    });

    test('Equal-turns rule: P1 checkout in Round 6 waits for bot turn before match ends', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);

      // Simulate match state where P1 has 40 left in Round 6
      container.read(dartsMatchProvider.notifier).state =
          container.read(dartsMatchProvider).copyWith(
                round: 6,
                yourTurns: [60, 60, 60, 40, 41], // 301 - 261 = 40 left
                theirTurns: [40, 40, 40, 40, 40], // 301 - 200 = 101 left
                thrower: DartsThrower.you,
                turnOver: false,
              );

      final state = container.read(dartsMatchProvider);
      expect(state.yourRemaining, equals(40));

      // Player throws D20 (40) -> Checkout!
      final hitD20 = DartScoring.score(0.0, 166.0);
      final res = notifier.dartLanded(hitD20);
      expect(res.checkout, isTrue);
      expect(res.turnOver, isTrue);

      final postCheckout = container.read(dartsMatchProvider);
      expect(postCheckout.yourRemaining, equals(0));
      // Equal-turns rule: match is NOT over yet, bot must throw round 6!
      expect(postCheckout.matchOver, isFalse);
      expect(postCheckout.thrower, equals(DartsThrower.opponent));

      // LAST CHANCE condition verified:
      final bool isLastChance =
          !postCheckout.isMyTurn &&
          postCheckout.yourRemaining == 0 &&
          postCheckout.theirRemaining <= 180;
      expect(isLastChance, isTrue);

      // Bot throws round 6 (misses checkout)
      final hitSingle = DartScoring.score(0.0, 135.0); // 20
      notifier.dartLanded(hitSingle);
      notifier.dartLanded(hitSingle);
      notifier.dartLanded(hitSingle);

      // NOW match is over and Player 1 wins!
      final finalState = container.read(dartsMatchProvider);
      expect(finalState.matchOver, isTrue);
      expect(finalState.winner, equals(1));
    });

    test('Restart match resets state to initial Round 1 with 301 points', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);
      final hitT20 = DartScoring.score(0.0, 103.0);
      notifier.dartLanded(hitT20);

      notifier.restartMatch();

      final resetState = container.read(dartsMatchProvider);
      expect(resetState.round, equals(1));
      expect(resetState.yourRemaining, equals(301));
      expect(resetState.theirRemaining, equals(301));
      expect(resetState.turnDarts.isEmpty, isTrue);
      expect(resetState.matchOver, isFalse);
      expect(resetState.isMyTurn, isTrue);
    });
  });
}
