import 'package:flutter/foundation.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';

/// Immutable archery match state (Build Plan v2 §5).
@immutable
class ArcheryMatchState {
  final ShotPhase phase;
  final int setIndex;
  final List<ShotScore> setShots;
  final int currentSetScore;
  final int userSets;
  final int botSets;
  final double windDisplay;
  final bool isSetComplete;
  final bool matchOver;
  final int matchSeed;

  const ArcheryMatchState({
    required this.phase,
    required this.setIndex,
    required this.setShots,
    required this.currentSetScore,
    required this.userSets,
    required this.botSets,
    required this.windDisplay,
    required this.isSetComplete,
    required this.matchOver,
    required this.matchSeed,
  });

  factory ArcheryMatchState.initial({int seed = 101}) => ArcheryMatchState(
        phase: ShotPhase.atLine,
        setIndex: 0,
        setShots: const [],
        currentSetScore: 0,
        userSets: 0,
        botSets: 0,
        windDisplay: 0.0,
        isSetComplete: false,
        matchOver: false,
        matchSeed: seed,
      );

  ArcheryMatchState copyWith({
    ShotPhase? phase,
    int? setIndex,
    List<ShotScore>? setShots,
    int? currentSetScore,
    int? userSets,
    int? botSets,
    double? windDisplay,
    bool? isSetComplete,
    bool? matchOver,
    int? matchSeed,
  }) {
    return ArcheryMatchState(
      phase: phase ?? this.phase,
      setIndex: setIndex ?? this.setIndex,
      setShots: setShots ?? this.setShots,
      currentSetScore: currentSetScore ?? this.currentSetScore,
      userSets: userSets ?? this.userSets,
      botSets: botSets ?? this.botSets,
      windDisplay: windDisplay ?? this.windDisplay,
      isSetComplete: isSetComplete ?? this.isSetComplete,
      matchOver: matchOver ?? this.matchOver,
      matchSeed: matchSeed ?? this.matchSeed,
    );
  }
}
