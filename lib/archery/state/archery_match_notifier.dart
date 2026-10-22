import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../archery_constants.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import 'archery_match_state.dart';
import 'archery_rules.dart';

/// What the Flame game needs from the match: the seed and arrow position for
/// deterministic wind/sway, and somewhere to report events.
abstract interface class ArcheryGameEvents {
  int get matchSeed;
  int get setIndex;

  /// Arrows already shot in the current set by whoever is shooting.
  int get arrowIndex;

  /// False while watching the opponent shoot (online).
  bool get isMyTurn;

  void phaseChanged(ShotPhase phase);
  void windChanged(double windDisplay);

  /// Solo: the bot's next arrow of this set has landed (set-start replay).
  /// Returns its score, or null once all of its arrows are in.
  ShotScore? botArrowLanded();

  /// Records your arrow. Solo: on the last arrow of the set, also scores the
  /// set; returns true when the set is over. Online: always false (the set
  /// result comes from the server once both archers have shot).
  bool shotScored(ShotScore score);

  /// Online: the opponent's arrow landed (re-flown on this phone).
  void opponentShotScored(ShotScore score);

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
  bool get isMyTurn => state.isMyTurn;

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

  // ── Solo ────────────────────────────────────────────────────────────────

  @override
  ShotScore? botArrowLanded() {
    if (state.online) return null;
    final int i = state.opponentShots.length;
    if (i >= ArcheryRules.arrowsPerSet) return null;
    final ShotScore shot = botShot(state.matchSeed, state.setIndex, i);
    state = state.copyWith(opponentShots: [...state.opponentShots, shot]);
    return shot;
  }

  @override
  bool shotScored(ShotScore score) {
    if (state.setOver) return true;
    final shots = [...state.setShots, score];

    if (state.online) {
      state = state.copyWith(setShots: shots);
      return false;
    }

    if (shots.length < ArcheryRules.arrowsPerSet) {
      state = state.copyWith(setShots: shots);
      return false;
    }

    // Normally the replay already revealed all bot arrows; fill any missing.
    final bot = [...state.opponentShots];
    while (bot.length < ArcheryRules.arrowsPerSet) {
      bot.add(botShot(state.matchSeed, state.setIndex, bot.length));
    }

    final you = [...state.userSetTotals, shots.fold(0, (s, a) => s + a.points)];
    final them = [...state.opponentSetTotals, bot.fold(0, (s, a) => s + a.points)];
    state = state.copyWith(
      setShots: shots,
      opponentShots: bot,
      userSetTotals: you,
      opponentSetTotals: them,
      setOver: true,
      matchOver: ArcheryRules.isMatchOver(you, them),
    );
    return true;
  }

  @override
  void nextSet() {
    if (state.matchOver || state.online) return;
    state = state.copyWith(
      setIndex: state.setIndex + 1,
      setShots: const [],
      opponentShots: const [],
      setOver: false,
    );
  }

  @override
  void restartMatch() {
    state = ArcheryMatchState.initial(seed: _newSeed())
        .copyWith(windDisplay: state.windDisplay);
  }

  // ── Online ──────────────────────────────────────────────────────────────

  @override
  void opponentShotScored(ShotScore score) {
    if (!state.online || state.opponentShots.length >= ArcheryRules.arrowsPerSet) {
      return;
    }
    state = state.copyWith(opponentShots: [...state.opponentShots, score]);
  }

  /// Switches to an online match: seed from the match id, empty board.
  void startOnline({required int seed, required String joinCode}) {
    state = ArcheryMatchState.initial(seed: seed).copyWith(
      online: true,
      joinCode: joinCode,
      windDisplay: state.windDisplay,
    );
  }

  /// Sets up the board for a turn: which set, who shoots, arrows already in
  /// (yours and theirs for this set) and every finished set's totals.
  void beginOnlineTurn({
    required int setIndex,
    required ArcheryShooter shooter,
    required List<ShotScore> mine,
    required List<ShotScore> theirs,
    required List<int> userSetTotals,
    required List<int> opponentSetTotals,
  }) {
    state = state.copyWith(
      setIndex: setIndex,
      shooter: shooter,
      setShots: mine,
      opponentShots: theirs,
      userSetTotals: userSetTotals,
      opponentSetTotals: opponentSetTotals,
      setOver: false,
      bannerId: state.bannerId + 1,
    );
  }

  /// Both archers finished the set: show its result (and the match result
  /// when [matchOver]).
  void showOnlineSetResult({
    required List<ShotScore> mine,
    required List<ShotScore> theirs,
    required List<int> userSetTotals,
    required List<int> opponentSetTotals,
    required bool matchOver,
  }) {
    state = state.copyWith(
      setShots: mine,
      opponentShots: theirs,
      userSetTotals: userSetTotals,
      opponentSetTotals: opponentSetTotals,
      setOver: true,
      matchOver: matchOver,
      liveStatus: ArcheryLiveStatus.none,
    );
  }

  /// The match ended by forfeit (+1 you won, −1 they won).
  void endOnlineByForfeit(int winner) {
    state = state.copyWith(
      setOver: true,
      matchOver: true,
      forfeitWinner: winner,
      liveStatus: ArcheryLiveStatus.none,
    );
  }

  void setLiveStatus(ArcheryLiveStatus status) {
    if (state.liveStatus == status) return;
    state = state.copyWith(liveStatus: status);
  }

  // ── Bot ─────────────────────────────────────────────────────────────────

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
