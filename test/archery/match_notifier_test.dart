import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:b_ball/archery/archery_constants.dart';
import 'package:b_ball/archery/online/archery_live_event.dart';
import 'package:b_ball/archery/physics/target_scoring.dart';
import 'package:b_ball/archery/state/archery_match_notifier.dart';
import 'package:b_ball/archery/state/archery_match_state.dart';
import 'package:b_ball/archery/state/archery_rules.dart';

ShotScore _shot(double localX) => TargetScoring.calculate(
      localX: localX,
      localY: 0.0,
      hitBoss: true,
      distance: ArcheryK.distanceM,
    );

void main() {
  late ProviderContainer container;
  late ArcheryMatchNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(archeryMatchProvider.notifier);
  });
  tearDown(() => container.dispose());

  ArcheryMatchState state() => container.read(archeryMatchProvider);

  group('rules', () {
    test('set points: win 2, tie 1 each', () {
      expect(ArcheryRules.setPoints([28, 20, 25], [20, 20, 26]), (you: 3, them: 3));
      expect(ArcheryRules.setPoints([30], [10]), (you: 2, them: 0));
    });

    test('first to 6 set points, capped at 5 sets', () {
      expect(ArcheryRules.isMatchOver([30, 30], [0, 0]), isFalse);
      expect(ArcheryRules.isMatchOver([30, 30, 30], [0, 0, 0]), isTrue);
      expect(ArcheryRules.isMatchOver([1, 1, 1, 1, 1], [1, 1, 1, 1, 1]), isTrue);
      expect(ArcheryRules.winner([1, 1, 1, 1, 1], [1, 1, 1, 1, 1]), 0);
    });

    test('only sets both archers shot count', () {
      expect(ArcheryRules.setPoints([30, 30], [0]), (you: 2, them: 0));
    });

    test('match seed is stable and case-insensitive', () {
      expect(ArcheryRules.seedFromMatchId('ab12cd'), ArcheryRules.seedFromMatchId('AB12CD'));
      expect(ArcheryRules.seedFromMatchId('AB12CD'), isNot(ArcheryRules.seedFromMatchId('AB12CE')));
      expect(ArcheryRules.seedFromMatchId('ZZZZZZ'), greaterThan(0));
    });
  });

  group('solo', () {
    test('bot arrows land in the set-start replay, not with yours', () {
      expect(notifier.botArrowLanded(), isNotNull);
      expect(notifier.botArrowLanded(), isNotNull);
      expect(notifier.botArrowLanded(), isNotNull);
      expect(notifier.botArrowLanded(), isNull); // only three per set
      expect(notifier.shotScored(_shot(0.0)), isFalse);
      expect(state().opponentShots.length, 3);
    });

    test('set result is scored once, on the third arrow', () {
      notifier.shotScored(_shot(0.0));
      notifier.shotScored(_shot(0.0));
      expect(notifier.shotScored(_shot(0.0)), isTrue);
      final s = state();
      expect(s.setOver, isTrue);
      expect(s.userSetTotals.length, 1);
      expect(s.userPoints + s.opponentPoints, 2); // win 2+0 or tie 1+1

      expect(notifier.shotScored(_shot(0.0)), isTrue); // ignored
      expect(state().userSetTotals.length, 1);
      expect(state().setShots.length, 3);
    });

    test('nextSet clears the set and advances the index', () {
      for (int i = 0; i < 3; i++) {
        notifier.shotScored(_shot(0.0));
      }
      notifier.nextSet();
      final s = state();
      expect(s.setIndex, 1);
      expect(s.setShots, isEmpty);
      expect(s.opponentShots, isEmpty);
      expect(s.setOver, isFalse);
      expect(notifier.arrowIndex, 0);
    });

    test('bot arrows are deterministic and 0..10', () {
      expect(ArcheryMatchNotifier.botRing(1234, 2, 1), ArcheryMatchNotifier.botRing(1234, 2, 1));
      for (int i = 0; i < 300; i++) {
        expect(ArcheryMatchNotifier.botRing(i, i % 5, i % 3), inInclusiveRange(0, 10));
      }
    });

    test('restart starts a fresh, solo match', () {
      final oldSeed = notifier.matchSeed;
      notifier.startOnline(seed: 99, joinCode: 'ABC123');
      notifier.restartMatch();
      final s = state();
      expect(s.online, isFalse);
      expect(s.setIndex, 0);
      expect(s.userSetTotals, isEmpty);
      expect(notifier.matchSeed, isNot(oldSeed));
    });
  });

  group('online', () {
    test('your arrows never end the set locally', () {
      notifier.startOnline(seed: 42, joinCode: 'ABC123');
      notifier.beginOnlineTurn(
        setIndex: 0,
        shooter: ArcheryShooter.you,
        mine: const [],
        theirs: const [],
        userSetTotals: const [],
        opponentSetTotals: const [],
      );
      for (int i = 0; i < 3; i++) {
        expect(notifier.shotScored(_shot(0.0)), isFalse);
      }
      expect(state().setOver, isFalse);
      expect(state().setShots.length, 3);
    });

    test('arrow index follows whoever is shooting', () {
      notifier.startOnline(seed: 42, joinCode: 'ABC123');
      notifier.beginOnlineTurn(
        setIndex: 1,
        shooter: ArcheryShooter.opponent,
        mine: [_shot(0.0)],
        theirs: const [],
        userSetTotals: const [20],
        opponentSetTotals: const [25],
      );
      expect(notifier.isMyTurn, isFalse);
      expect(notifier.arrowIndex, 0);
      notifier.opponentShotScored(_shot(0.1));
      expect(notifier.arrowIndex, 1);
      expect(state().opponentPoints, 2);
    });

    test('forfeit ends the match with that winner', () {
      notifier.startOnline(seed: 42, joinCode: 'ABC123');
      notifier.endOnlineByForfeit(1);
      expect(state().matchOver, isTrue);
      expect(state().winner, 1);
    });
  });

  group('live events', () {
    test('arrow event round-trips and is re-scored from its hit', () {
      const e = ArcheryLiveEvent(
        kind: ArcheryLiveEvent.kindArrow,
        shooterUid: 'u1',
        round: 2,
        arrowIndex: 1,
        launched: true,
        yaw: 0.01,
        pitch: 0.02,
        hitX: 0.0,
        hitY: 0.0,
        hitBoss: true,
        ring: 3, // wrong on purpose: never trusted
      );
      final back = ArcheryLiveEvent.fromMap(e.toMap())!;
      expect(back.docId, 'a_u1_2_1');
      expect(back.yaw, closeTo(0.01, 1e-12));
      expect(back.score(ArcheryK.distanceM).points, 10);
    });

    test('a timed-out arrow scores zero', () {
      const e = ArcheryLiveEvent(
        kind: ArcheryLiveEvent.kindArrow,
        shooterUid: 'u1',
        round: 1,
        arrowIndex: 0,
        launched: false,
        hitBoss: true,
      );
      expect(e.score(ArcheryK.distanceM).points, 0);
    });

    test('other games are ignored', () {
      expect(ArcheryLiveEvent.fromMap({'game': 'basketball'}), isNull);
      expect(ArcheryLiveEvent.fromMap(null), isNull);
    });
  });
}
