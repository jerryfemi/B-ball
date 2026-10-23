import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/online/darts_live_event.dart';
import 'package:b_ball/darts/physics/dart_scoring.dart';
import 'package:b_ball/darts/state/darts_match_notifier.dart';
import 'package:b_ball/darts/state/darts_match_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

DartsLiveEvent dartAt(int i, double x, double y, {bool launched = true}) =>
    DartsLiveEvent(
      kind: DartsLiveEvent.kindDart,
      shooterUid: 'u1',
      round: 3,
      dartIndex: i,
      launched: launched,
      hitX: x,
      hitY: y,
    );

void main() {
  group('DartsLiveEvent (Step 16)', () {
    test('round-trips through a Firestore map', () {
      final e = dartAt(1, 0.0, 103.0);
      final back = DartsLiveEvent.fromMap(e.toMap())!;
      expect(back.kind, DartsLiveEvent.kindDart);
      expect(back.shooterUid, 'u1');
      expect(back.round, 3);
      expect(back.dartIndex, 1);
      expect(back.launched, isTrue);
      expect(back.hitX, 0.0);
      expect(back.hitY, 103.0);
    });

    test('ignores other games and bad dart indexes', () {
      expect(DartsLiveEvent.fromMap({'game': 'archery', 'kind': 'dart'}), isNull);
      expect(DartsLiveEvent.fromMap(null), isNull);
      final bad = dartAt(0, 0, 0).toMap()..['dartIndex'] = 3;
      expect(DartsLiveEvent.fromMap(bad), isNull);
    });

    test('doc ids use the t_ prefix (never archery a_/d_)', () {
      expect(dartAt(2, 0, 0).docId, 't_u1_3_2');
    });

    test('only landed darts are read back (no aim events)', () {
      expect(DartsLiveEvent.fromMap({'game': 'darts', 'kind': 'aim', 'dartIndex': 0}), isNull);
    });

    test('score is recomputed from the hit position', () {
      expect(dartAt(0, 0.0, 103.0).hit.points, 60); // T20
      expect(dartAt(0, 0.0, 0.0).hit.points, 50); // bull
    });

    test('a timed-out dart is a miss wherever it says it hit', () {
      final e = dartAt(0, 0.0, 0.0, launched: false);
      expect(e.hit.isMiss, isTrue);
      expect(e.hit.points, 0);
    });
  });

  group('DartsTurnTally (Step 16)', () {
    test('three treble 20s score 180', () {
      final t = DartsTurnTally.score(301, [
        dartAt(0, 0, 103),
        dartAt(1, 0, 103),
        dartAt(2, 0, 103),
      ]);
      expect(t.total, 180);
      expect(t.dartsUsed, 3);
      expect(t.trebles, 3);
      expect(t.bust, isFalse);
    });

    test('a bust scores 0 and ends the turn on that dart', () {
      final t = DartsTurnTally.score(40, [
        dartAt(0, 0, 103), // T20 = 60 > 40 → bust
        dartAt(1, 0, 103),
      ]);
      expect(t.bust, isTrue);
      expect(t.total, 0);
      expect(t.dartsUsed, 1);
      expect(t.hits.length, 1);
    });

    test('a checkout ends the turn and keeps the darts used', () {
      final t = DartsTurnTally.score(40, [
        dartAt(0, 0, 135), // S20
        dartAt(1, 0, 135), // S20 → 0
        dartAt(2, 0, 103), // ignored
      ]);
      expect(t.checkout, isTrue);
      expect(t.total, 40);
      expect(t.dartsUsed, 2);
    });

    test('missing darts count as misses; order of arrival does not matter', () {
      final t = DartsTurnTally.score(301, [dartAt(2, 0, 103), dartAt(0, 0, 135)]);
      expect(t.total, 80); // S20 + miss + T20
      expect(t.onBoard, 2);
      expect(t.dartsUsed, 3);
    });

    test('a forged duplicate index cannot add a fourth dart', () {
      final t = DartsTurnTally.score(301, [
        dartAt(0, 0, 103),
        dartAt(0, 0, 103),
        dartAt(1, 0, 103),
        dartAt(2, 0, 103),
      ]);
      expect(t.total, 180);
    });
  });

  group('Notifier online turn recording (Step 18)', () {
    test('online, a finished turn does not advance the round or thrower', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(dartsMatchProvider.notifier);
      n.startOnline(seed: 7, joinCode: 'ABCD', youThrowFirst: false);
      n.beginOnlineTurn(
        round: 2,
        thrower: DartsThrower.opponent,
        turnDarts: const [],
        yourTurns: const [60],
        theirTurns: const [60, 60],
      );
      final s20 = DartScoring.score(0.0, 135.0);
      n.dartLanded(s20);
      n.dartLanded(s20);
      final r = n.dartLanded(s20);
      expect(r.turnOver, isTrue);
      final s = container.read(dartsMatchProvider);
      expect(s.round, 2, reason: 'Firestore decides the next round');
      expect(s.thrower, DartsThrower.opponent);
      expect(s.theirTurns, [60, 60, 60]);
      expect(s.matchOver, isFalse);
    });

    test('guest throws second: last chance after the host checks out', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(dartsMatchProvider.notifier);
      n.startOnline(seed: 7, joinCode: 'ABCD', youThrowFirst: false);
      n.beginOnlineTurn(
        round: 5,
        thrower: DartsThrower.you,
        turnDarts: const [],
        yourTurns: const [100, 100, 60, 1],
        theirTurns: const [100, 100, 60, 1, 40], // host checked out (301)
      );
      final s = container.read(dartsMatchProvider);
      expect(s.theirRemaining, 0);
      expect(s.isLastChance, isTrue);
    });

    test('solo: you throw first, so the bot gets the last chance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(dartsMatchProvider.notifier);
      n.beginOnlineTurn(
        round: 5,
        thrower: DartsThrower.opponent,
        turnDarts: const [],
        yourTurns: const [100, 100, 60, 41],
        theirTurns: const [100, 100, 60, 1],
      );
      final s = container.read(dartsMatchProvider);
      expect(s.yourRemaining, 0);
      expect(s.isLastChance, isTrue);
      expect(DartsK.startScore, 301);
    });
  });
}
