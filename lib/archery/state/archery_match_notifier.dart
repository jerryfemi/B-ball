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

  /// Records your arrow, reveals the bot's matching arrow and, on the last
  /// arrow of the set, awards set points. Returns true when the set is over.
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
  bool shotScored(ShotScore score) {
    if (state.setOver) return true;

    final shots = [...state.setShots, score];
    final bot = [
      ...state.botShots,
      botRing(state.matchSeed, state.setIndex, state.botShots.length),
    ];
    final bool setDone = shots.length >= ArcheryMatchState.arrowsPerSet;

    if (!setDone) {
      state = state.copyWith(setShots: shots, botShots: bot);
      return false;
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

  /// Deterministic bot arrow: a 2D normal hit offset scored on the same rings.
  static int botRing(int seed, int setIndex, int arrowIndex) {
    int h = seed;
    h = (h * 31 + setIndex) & 0x7FFFFFFF;
    h = (h * 31 + arrowIndex) & 0x7FFFFFFF;
    h = (h * 31 + 0xB07) & 0x7FFFFFFF;
    final rng = math.Random(h);
    // Box–Muller: radius is Rayleigh-distributed from u1 alone (u2 would be angle).
    final double u1 = math.max(rng.nextDouble(), 1e-9);
    rng.nextDouble(); // advance RNG for angle
    // The radius of a 2D normal offset is Rayleigh-distributed:
    // r = σ·sqrt(-2 ln u1). (u2 would only give the angle, which can't change the ring.)
    final double r = botSigmaM * math.sqrt(-2.0 * math.log(u1));
    if (r > ArcheryK.faceRadius) return 0;
    return (10 - (r / ArcheryK.ringWidth).floor()).clamp(1, 10);
  }
}

final archeryMatchProvider =
    NotifierProvider<ArcheryMatchNotifier, ArcheryMatchState>(
  ArcheryMatchNotifier.new,
);
