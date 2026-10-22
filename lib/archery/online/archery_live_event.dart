import '../physics/target_scoring.dart';

/// One live archery event in `/matches/{id}/live_shots` (shared with
/// basketball's live shots, told apart by `game: 'archery'`).
///
///  * `draw`  — the archer pressed to aim (spectators raise their camera).
///  * `arrow` — the arrow was released and landed: launch angles to re-fly it
///    on the spectator's phone, plus where it hit (the shooter's result is
///    authoritative). A shot-clock timeout is an arrow with [launched] false.
class ArcheryLiveEvent {
  static const String kindDraw = 'draw';
  static const String kindArrow = 'arrow';

  final String kind;
  final String shooterUid;

  /// 1-based set number (the match's `currentRound`).
  final int round;
  final int arrowIndex;

  // Arrow only
  final bool launched;
  final double yaw;
  final double pitch;
  final double hitX;
  final double hitY;
  final bool hitBoss;
  final int ring;
  final bool isX;

  const ArcheryLiveEvent({
    required this.kind,
    required this.shooterUid,
    required this.round,
    required this.arrowIndex,
    this.launched = false,
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.hitX = 0.0,
    this.hitY = 0.0,
    this.hitBoss = false,
    this.ring = 0,
    this.isX = false,
  });

  bool get isArrow => kind == kindArrow;
  bool get isDraw => kind == kindDraw;

  /// Firestore document id. Arrows have a fixed id per (archer, set, arrow),
  /// so an arrow can be written once and never overwritten.
  String get docId => isArrow
      ? 'a_${shooterUid}_${round}_$arrowIndex'
      : 'd_${shooterUid}_${round}_${arrowIndex}_${DateTime.now().millisecondsSinceEpoch}';

  /// The arrow's score, recomputed from where it hit (never trusted as sent).
  ShotScore score(double distance) => TargetScoring.calculate(
        localX: hitX,
        localY: hitY,
        hitBoss: launched && hitBoss,
        distance: distance,
      );

  Map<String, dynamic> toMap() => {
        'game': 'archery',
        'kind': kind,
        'shooterUid': shooterUid,
        'round': round,
        'arrowIndex': arrowIndex,
        if (isArrow) ...{
          'launched': launched,
          'yaw': yaw,
          'pitch': pitch,
          'hitX': hitX,
          'hitY': hitY,
          'hitBoss': hitBoss,
          'ring': ring,
          'isX': isX,
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

  static ArcheryLiveEvent? fromMap(Map<String, dynamic>? m) {
    if (m == null || m['game'] != 'archery') return null;
    final kind = m['kind'];
    if (kind != kindArrow && kind != kindDraw) return null;
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return ArcheryLiveEvent(
      kind: kind as String,
      shooterUid: m['shooterUid'] as String? ?? '',
      round: (m['round'] as num?)?.toInt() ?? 1,
      arrowIndex: (m['arrowIndex'] as num?)?.toInt() ?? 0,
      launched: m['launched'] as bool? ?? false,
      yaw: d('yaw'),
      pitch: d('pitch'),
      hitX: d('hitX'),
      hitY: d('hitY'),
      hitBoss: m['hitBoss'] as bool? ?? false,
      ring: (m['ring'] as num?)?.toInt() ?? 0,
      isX: m['isX'] as bool? ?? false,
    );
  }
}

/// A batch of live events from one snapshot. [initial] is true for the first
/// snapshot after subscribing: those events already happened (e.g. you
/// rejoined), so they are shown instantly, never replayed.
class ArcheryLiveBatch {
  final List<ArcheryLiveEvent> events;
  final bool initial;
  const ArcheryLiveBatch(this.events, {required this.initial});
}
