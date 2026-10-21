import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../archery_constants.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import 'archery_match_state.dart';

/// What the Flame game needs from the match: the seed and arrow position for
/// deterministic wind/sway, and somewhere to report events.
abstract interface class ArcheryGameEvents {
  int get matchSeed;
  int get setIndex;

  /// Arrows already shot in the current set.
  int get arrowIndex;

  void phaseChanged(ShotPhase phase);
  void windChanged(double windDisplay);

  /// The opponent's next arrow of this set has landed (set-start replay).
  /// Returns its score, or null once all of its arrows are in.
  ShotScore? botArrowLanded();

  /// Records your arrow and, on the last arrow of the set, awards set points.
  /// Returns true when the set is over.
  bool shotScored(ShotScore score);

  void nextSet();
  void restartMatch();
}

/// Riverpod notifier that owns every scoring rule (pure Dart, testable).
class ArcheryMatchNotifier extends Notifier<ArcheryMatchState>
    implements ArcheryGameEvents {
  /// Bot grouping: standard deviation of its hit offset (m) on each axis.
  /// 0.07 m ≈ an 8-ring average archer. Lower = stronger bot.
  static const double botSigmaM = 0.07;

  @override
  ArcheryMatchState build() => ArcheryMatchState.initial(seed: _newSeed());

  static int _newSeed() => math.Random().nextInt(1 << 30) + 1;

  @override
  int get matchSeed => state.matchSeed;

  @override
  int get setIndex => state.setIndex;

  @override
  int get arrowIndex => state.arrowIndex;

  @override
  void phaseChanged(ShotPhase phase) {
    if (state.phase == phase) return;
    state = state.copyWith(phase: phase);
  }

  @override
  void windChanged(double windDisplay) {
    if (state.windDisplay == windDisplay) return;
    state = state.copyWith(windDisplay: windDisplay);
  }

  @override
  ShotScore? botArrowLanded() {
    final int i = state.botShots.length;
    if (i >= ArcheryMatchState.arrowsPerSet) return null;
    final ShotScore shot = botShot(state.matchSeed, state.setIndex, i);
    state = state.copyWith(botShots: [...state.botShots, shot.points]);
    return shot;
  }

  @override
  bool shotScored(ShotScore score) {
    if (state.setOver) return true;

    final shots = [...state.setShots, score];
    if (shots.length < ArcheryMatchState.arrowsPerSet) {
      state = state.copyWith(setShots: shots);
      return false;
    }

    // Normally the replay already revealed all bot arrows; fill any missing.
    final bot = [...state.botShots];
    while (bot.length < ArcheryMatchState.arrowsPerSet) {
      bot.add(botShot(state.matchSeed, state.setIndex, bot.length).points);
    }

    final int you = shots.fold(0, (sum, s) => sum + s.points);
    final int them = bot.fold(0, (sum, p) => sum + p);
    int userSets = state.userSets;
    int botSets = state.botSets;
    if (you > them) {
      userSets++;
    } else if (you < them) {
      botSets++;
    } else {
      userSets++;
      botSets++;
    }

    state = state.copyWith(
      setShots: shots,
      botShots: bot,
      userSets: userSets,
      botSets: botSets,
      setOver: true,
      matchOver: userSets >= ArcheryMatchState.setsToWin ||
          botSets >= ArcheryMatchState.setsToWin,
    );
    return true;
  }

  @override
  void nextSet() {
    if (state.matchOver) return;
    state = state.copyWith(
      setIndex: state.setIndex + 1,
      setShots: const [],
      botShots: const [],
      setOver: false,
    );
  }

  @override
  void restartMatch() {
    state = ArcheryMatchState.initial(seed: _newSeed())
        .copyWith(windDisplay: state.windDisplay);
  }

  /// Deterministic bot arrow: a 2D normal hit offset on the face, scored by
  /// the same rules as yours. Its grouping opens up a little with distance.
  static ShotScore botShot(int seed, int setIndex, int arrowIndex) {
    int h = seed;
    h = (h * 31 + setIndex) & 0x7FFFFFFF;
    h = (h * 31 + arrowIndex) & 0x7FFFFFFF;
    h = (h * 31 + 0xB07) & 0x7FFFFFFF;
    final rng = math.Random(h);
    final double distance = ArcheryK.distanceForSet(setIndex);
    final double sigma =
        botSigmaM * (0.8 + 0.2 * distance / ArcheryK.setDistancesM.first);
    // Box–Muller: Rayleigh radius from u1, angle from u2.
    final double u1 = math.max(rng.nextDouble(), 1e-9);
    final double u2 = rng.nextDouble();
    final double r = sigma * math.sqrt(-2.0 * math.log(u1));
    final double a = 2.0 * math.pi * u2;
    // Keep it on the board so it always sticks somewhere visible.
    const double edge = ArcheryK.boardWidth * 0.5 - 0.03;
    final double dx = (r * math.cos(a)).clamp(-edge, edge);
    final double dy = (r * math.sin(a)).clamp(-edge, edge);
    return TargetScoring.calculate(
      localX: dx,
      localY: dy,
      hitBoss: true,
      distance: distance,
    );
  }

  /// Points of [botShot] (kept for tests and callers that only need the ring).
  static int botRing(int seed, int setIndex, int arrowIndex) =>
      botShot(seed, setIndex, arrowIndex).points;
}

final archeryMatchProvider =
    NotifierProvider<ArcheryMatchNotifier, ArcheryMatchState>(
  ArcheryMatchNotifier.new,
);
