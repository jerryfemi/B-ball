import 'package:b_ball/darts/physics/dart_scoring.dart';
import 'package:b_ball/darts/state/darts_match_notifier.dart';
import 'package:b_ball/darts/state/darts_match_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('DartsMatchNotifier Tests (Step 7)', () {
    test('Three darts T20/T20/T20 leaves 121 remaining, turn over, thrower = opponent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);
      final t20 = DartScoring.score(0.0, 103.0); // T20 = 60 pts

      // Dart 1
      final res1 = notifier.dartLanded(t20);
      expect(res1.turnOver, isFalse);
      expect(notifier.dartIndex, equals(1));
      expect(container.read(dartsMatchProvider).isMyTurn, isTrue);

      // Dart 2
      final res2 = notifier.dartLanded(t20);
      expect(res2.turnOver, isFalse);
      expect(notifier.dartIndex, equals(2));
      expect(container.read(dartsMatchProvider).isMyTurn, isTrue);

      // Dart 3
      final res3 = notifier.dartLanded(t20);
      expect(res3.turnOver, isTrue);

      final state = container.read(dartsMatchProvider);
      expect(state.yourRemaining, equals(121),
          reason: '301 - 180 should equal 121');
      expect(state.turnOver, isTrue);
      expect(state.thrower, equals(DartsThrower.opponent));
    });

    test('Bust restores turn-start total and ends turn', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);

      // Set up a state where Player 1 has 20 remaining at start of turn
      notifier.beginOnlineTurn(
        round: 3,
        thrower: DartsThrower.you,
        turnDarts: const [],
        yourTurns: [180, 101], // 301 - 281 = 20 remaining
        theirTurns: [100, 100],
      );

      final stateBefore = container.read(dartsMatchProvider);
      expect(stateBefore.yourRemaining, equals(20));
      final int initialBustFlash = stateBefore.bustFlash;

      // Hit T20 (60 pts) when 20 left -> 20 - 60 < 0 -> BUST!
      final t20 = DartScoring.score(0.0, 103.0);
      final res = notifier.dartLanded(t20);

      expect(res.bust, isTrue);
      expect(res.turnOver, isTrue);

      final stateAfter = container.read(dartsMatchProvider);
      expect(stateAfter.yourRemaining, equals(20),
          reason: 'Bust must restore the turn-start remaining total');
      expect(stateAfter.bustFlash, equals(initialBustFlash + 1));
      expect(stateAfter.thrower, equals(DartsThrower.opponent));
    });

    test('Checkout in round N waits for bot round-N turn before matchOver', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);

      // Set up state at Round 6 where you have 40 remaining and bot has 100
      notifier.beginOnlineTurn(
        round: 6,
        thrower: DartsThrower.you,
        turnDarts: const [],
        yourTurns: [60, 60, 60, 40, 41], // sum = 261, 40 remaining
        theirTurns: [40, 40, 40, 40, 41], // 100 remaining
      );

      expect(container.read(dartsMatchProvider).yourRemaining, equals(40));

      // Player 1 hits D20 (40 pts) -> 40 - 40 = 0 -> Checkout!
      final d20 = DartScoring.score(0.0, 166.0);
      final res = notifier.dartLanded(d20);

      expect(res.checkout, isTrue);
      expect(res.turnOver, isTrue);

      final stateAfterCheckout = container.read(dartsMatchProvider);
      expect(stateAfterCheckout.yourRemaining, equals(0));
      expect(stateAfterCheckout.thrower, equals(DartsThrower.opponent));

      // CRITICAL CHECK: Under equal-turns rule, match is NOT over until bot throws round 6
      expect(stateAfterCheckout.matchOver, isFalse,
          reason: 'Checkout in round 6 must wait for bot round 6 before matchOver');

      // Bot throws their round 6 turn (hits 3 singles, doesn't checkout)
      final s20 = DartScoring.score(0.0, 135.0); // 20 pts each
      notifier.dartLanded(s20);
      notifier.dartLanded(s20);
      notifier.dartLanded(s20);

      // Now both players have completed round 6
      final finalState = container.read(dartsMatchProvider);
      expect(finalState.matchOver, isTrue);
      expect(finalState.winner, equals(1), reason: 'Player 1 checked out, bot did not');
    });

    test('Both checkout in round N: tiebreaker awards winner to fewer darts used', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);

      // Both have 40 remaining at round 4
      notifier.beginOnlineTurn(
        round: 4,
        thrower: DartsThrower.you,
        turnDarts: const [],
        yourTurns: [100, 100, 61], // 40 remaining
        theirTurns: [100, 100, 61], // 40 remaining
      );

      // You checkout with 1 dart (D20 = 40)
      final d20 = DartScoring.score(0.0, 166.0);
      notifier.dartLanded(d20);

      // Bot checks out with 2 darts (S20 = 20, then S20 = 20)
      final s20 = DartScoring.score(0.0, 135.0);
      notifier.dartLanded(s20);
      notifier.dartLanded(s20);

      final state = container.read(dartsMatchProvider);
      expect(state.matchOver, isTrue);
      expect(state.yourRemaining, equals(0));
      expect(state.theirRemaining, equals(0));
      expect(state.winner, equals(1),
          reason: 'Player 1 checked out in 1 dart vs bot in 2 darts');
    });

    test('Solo bot turn via botNextDart advances game', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dartsMatchProvider.notifier);

      // Player 1 throws 3 darts (T20, T20, T20)
      final t20 = DartScoring.score(0.0, 103.0);
      notifier.dartLanded(t20);
      notifier.dartLanded(t20);
      notifier.dartLanded(t20);

      expect(container.read(dartsMatchProvider).thrower, equals(DartsThrower.opponent));

      // Bot throws 3 darts via botNextDart
      final d1 = notifier.botNextDart();
      final d2 = notifier.botNextDart();
      final d3 = notifier.botNextDart();

      expect(d1, isNotNull);
      expect(d2, isNotNull);
      expect(d3, isNotNull);

      final state = container.read(dartsMatchProvider);
      expect(state.theirTurns.length, equals(1));
      expect(state.round, equals(2), reason: 'After round 1 completes, round becomes 2');
      expect(state.thrower, equals(DartsThrower.you), reason: 'Turn returns to Player 1');
    });
  });
}
