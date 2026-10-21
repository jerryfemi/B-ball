import 'package:flutter/foundation.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';

/// Immutable archery match state. The single source of truth for scores,
/// sets and the match seed (the Flame game only reports shots).
@immutable
class ArcheryMatchState {
  /// Arrows per set and set points needed to win the match.
  static const int arrowsPerSet = 3;
  static const int setsToWin = 3;

  final ShotPhase phase;
  final int setIndex;

  /// Your arrows in the current set.
  final List<ShotScore> setShots;

  /// The bot's arrows in the current set revealed so far (one per your arrow).
  final List<int> botShots;

  final int userSets;
  final int botSets;
  final double windDisplay;

  /// True once all arrows of the current set are in and set points are awarded.
  final bool setOver;
  final bool matchOver;
  final int matchSeed;

  const ArcheryMatchState({
    required this.phase,
    required this.setIndex,
    required this.setShots,
    required this.botShots,
    required this.userSets,
    required this.botSets,
    required this.windDisplay,
    required this.setOver,
    required this.matchOver,
    required this.matchSeed,
  });

  factory ArcheryMatchState.initial({required int seed}) => ArcheryMatchState(
        phase: ShotPhase.atLine,
        setIndex: 0,
        setShots: const [],
        botShots: const [],
        userSets: 0,
        botSets: 0,
        windDisplay: 0.0,
        setOver: false,
        matchOver: false,
        matchSeed: seed,
      );

  int get userSetScore => setShots.fold(0, (sum, s) => sum + s.points);
  int get botSetScore => botShots.fold(0, (sum, p) => sum + p);

  /// Arrows already shot in the current set (also the index of the next one).
  int get arrowIndex => setShots.length;

  ArcheryMatchState copyWith({
    ShotPhase? phase,
    int? setIndex,
    List<ShotScore>? setShots,
    List<int>? botShots,
    int? userSets,
    int? botSets,
    double? windDisplay,
    bool? setOver,
    bool? matchOver,
    int? matchSeed,
  }) {
    return ArcheryMatchState(
      phase: phase ?? this.phase,
      setIndex: setIndex ?? this.setIndex,
      setShots: setShots ?? this.setShots,
      botShots: botShots ?? this.botShots,
      userSets: userSets ?? this.userSets,
      botSets: botSets ?? this.botSets,
      windDisplay: windDisplay ?? this.windDisplay,
      setOver: setOver ?? this.setOver,
      matchOver: matchOver ?? this.matchOver,
      matchSeed: matchSeed ?? this.matchSeed,
    );
  }
}
