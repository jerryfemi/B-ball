import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:b_ball/archery/archery_constants.dart';
import 'package:b_ball/archery/physics/target_scoring.dart';
import 'package:b_ball/archery/state/archery_match_notifier.dart';

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

  test('bot arrows land in the set-start replay, not with yours', () {
    expect(notifier.botArrowLanded(), isNotNull);
    expect(notifier.botArrowLanded(), isNotNull);
    expect(notifier.botArrowLanded(), isNotNull);
    expect(notifier.botArrowLanded(), isNull); // only three per set
    expect(container.read(archeryMatchProvider).botShots.length, 3);

    expect(notifier.shotScored(_shot(0.0)), isFalse);
    expect(container.read(archeryMatchProvider).botShots.length, 3);
  });

  test('set still completes if the replay was skipped', () {
    notifier.shotScored(_shot(0.0));
    notifier.shotScored(_shot(0.0));
    expect(notifier.shotScored(_shot(0.0)), isTrue);
    expect(container.read(archeryMatchProvider).botShots.length, 3);
  });

  test('replayed bot score matches its deterministic shot', () {
    final shot = notifier.botArrowLanded()!;
    final again = ArcheryMatchNotifier.botShot(notifier.matchSeed, 0, 0);
    expect(shot.points, again.points);
    expect(shot.localX, again.localX);
    expect(shot.localY, again.localY);
  });

  test('set points are awarded exactly once, on the third arrow', () {
    notifier.shotScored(_shot(0.0));
    notifier.shotScored(_shot(0.0));
    expect(notifier.shotScored(_shot(0.0)), isTrue);

    final s = container.read(archeryMatchProvider);
    expect(s.setOver, isTrue);
    expect(s.userSets + s.botSets, inInclusiveRange(1, 2)); // 2 only on a tie

    // Extra reports after the set is over change nothing.
    expect(notifier.shotScored(_shot(0.0)), isTrue);
    final after = container.read(archeryMatchProvider);
    expect(after.userSets, s.userSets);
    expect(after.botSets, s.botSets);
    expect(after.setShots.length, 3);
  });

  test('nextSet clears the set and advances the index', () {
    for (int i = 0; i < 3; i++) {
      notifier.shotScored(_shot(0.0));
    }
    notifier.nextSet();
    final s = container.read(archeryMatchProvider);
    expect(s.setIndex, 1);
    expect(s.setShots, isEmpty);
    expect(s.botShots, isEmpty);
    expect(s.setOver, isFalse);
    expect(notifier.arrowIndex, 0);
  });

  test('bot arrows are deterministic per seed and always 0..10', () {
    for (int a = 0; a < 3; a++) {
      final r1 = ArcheryMatchNotifier.botRing(1234, 2, a);
      final r2 = ArcheryMatchNotifier.botRing(1234, 2, a);
      expect(r1, r2);
    }
    for (int i = 0; i < 500; i++) {
      final r = ArcheryMatchNotifier.botRing(i, i % 5, i % 3);
      expect(r, inInclusiveRange(0, 10));
    }
  });

  test('restart starts a fresh match with a new seed', () {
    final oldSeed = notifier.matchSeed;
    notifier.shotScored(_shot(0.0));
    notifier.restartMatch();
    final s = container.read(archeryMatchProvider);
    expect(s.setIndex, 0);
    expect(s.setShots, isEmpty);
    expect(s.userSets, 0);
    expect(s.botSets, 0);
    expect(notifier.matchSeed, isNot(oldSeed));
  });
}
