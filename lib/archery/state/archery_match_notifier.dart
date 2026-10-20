import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import 'archery_match_state.dart';

/// Abstract event receiver interface for ArcheryGame.
/// Decouples the Flame engine loop from Riverpod state.
abstract interface class ArcheryGameEvents {
  void phaseChanged(ShotPhase phase);
  void shotScored(ShotScore score);
  void windChanged(double windDisplay);
  void setCompleted({required int userTotal, required int opponentTotal});
  void nextSetStarted(int setIndex);
  void matchRestarted(int newSeed);
}

/// Riverpod Notifier driving the archery match state machine (Build Plan v2 §5).
class ArcheryMatchNotifier extends Notifier<ArcheryMatchState>
    implements ArcheryGameEvents {
  @override
  ArcheryMatchState build() {
    final int seed = math.Random().nextInt(1000000) + 1;
    return ArcheryMatchState.initial(seed: seed);
  }

  @override
  void phaseChanged(ShotPhase phase) {
    if (state.phase == phase) return;
    state = state.copyWith(phase: phase);
  }

  @override
  void shotScored(ShotScore score) {
    final nextShots = [...state.setShots, score];
    final nextScore = nextShots.fold(0, (sum, s) => sum + s.points);
    state = state.copyWith(
      setShots: nextShots,
      currentSetScore: nextScore,
      isSetComplete: nextShots.length >= 3,
    );
  }

  @override
  void windChanged(double windDisplay) {
    if (state.windDisplay == windDisplay) return;
    state = state.copyWith(windDisplay: windDisplay);
  }

  @override
  void setCompleted({required int userTotal, required int opponentTotal}) {
    int nextUserSets = state.userSets;
    int nextBotSets = state.botSets;
    if (userTotal > opponentTotal) {
      nextUserSets++;
    } else if (userTotal < opponentTotal) {
      nextBotSets++;
    } else {
      nextUserSets++;
      nextBotSets++;
    }
    final bool matchOver = nextUserSets >= 3 || nextBotSets >= 3;
    state = state.copyWith(
      userSets: nextUserSets,
      botSets: nextBotSets,
      isSetComplete: true,
      matchOver: matchOver,
    );
  }

  @override
  void nextSetStarted(int setIndex) {
    state = state.copyWith(
      phase: ShotPhase.returning,
      setIndex: setIndex,
      setShots: const [],
      currentSetScore: 0,
      isSetComplete: false,
    );
  }

  @override
  void matchRestarted(int newSeed) {
    state = ArcheryMatchState.initial(seed: newSeed);
  }
}

final archeryMatchProvider =
    NotifierProvider<ArcheryMatchNotifier, ArcheryMatchState>(
  ArcheryMatchNotifier.new,
);
