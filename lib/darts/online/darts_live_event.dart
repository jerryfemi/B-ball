import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import '../state/darts_rules.dart';

/// One live darts event in `/matches/{id}/live_shots` (shared with
/// basketball and archery, told apart by `game: 'darts'`).
///
///  * `dart` — a dart landed: where it hit, in board millimetres. The score
///    is ALWAYS recomputed from [hitX]/[hitY] on the receiving phone and in
///    the Firestore transaction; nothing else is trusted. A shot-clock
///    timeout is a dart with [launched] false (a miss).
///
/// Document ids start with `t_` (throw), so they never collide with
/// archery's `a_`/`d_` ids. Darts is a pure flick game: nothing is sent
/// before a dart lands (there is no aiming to watch).
class DartsLiveEvent {
  static const String kindDart = 'dart';

  final String kind;
  final String shooterUid;

  /// 1-based round (the match's `currentRound`).
  final int round;

  /// 0, 1 or 2 within the turn.
  final int dartIndex;

  final bool launched;
  final double hitX;
  final double hitY;

  /// The sender's device time (ms) when it was written; 0 if unknown.
  /// Read back only (a new event stamps the current time in [toMap]).
  final int createdAtMs;

  const DartsLiveEvent({
    required this.kind,
    required this.shooterUid,
    required this.round,
    required this.dartIndex,
    this.launched = false,
    this.hitX = 0.0,
    this.hitY = 0.0,
    this.createdAtMs = 0,
  });

  /// A landed dart from a local [DartHit].
  factory DartsLiveEvent.fromHit({
    required String shooterUid,
    required int round,
    required int dartIndex,
    required DartHit hit,
    bool launched = true,
  }) {
    return DartsLiveEvent(
      kind: kindDart,
      shooterUid: shooterUid,
      round: round,
      dartIndex: dartIndex,
      launched: launched,
      hitX: hit.x.isFinite ? hit.x : 0.0,
      hitY: hit.y.isFinite ? hit.y : 0.0,
    );
  }

  bool get isDart => kind == kindDart;

  /// Firestore document id: fixed per (thrower, round, dart), so a dart can
  /// be written once and never overwritten.
  String get docId => 't_${shooterUid}_${round}_$dartIndex';

  /// Where a timed-out (never thrown) dart counts: off the board.
  static const double missX = DartsK.boardR + 10.0;

  /// The dart's result, recomputed from where it hit (never trusted as sent).
  DartHit get hit => launched && hitX.isFinite && hitY.isFinite
      ? DartScoring.score(hitX, hitY)
      : DartScoring.score(missX, 0.0);

  Map<String, dynamic> toMap() => {
        'game': 'darts',
        'kind': kind,
        'shooterUid': shooterUid,
        'round': round,
        'dartIndex': dartIndex,
        'launched': launched,
        'hitX': hitX,
        'hitY': hitY,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

  static DartsLiveEvent? fromMap(Map<String, dynamic>? m) {
    if (m == null || m['game'] != 'darts') return null;
    final kind = m['kind'];
    if (kind != kindDart) return null;
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    final int dartIndex = (m['dartIndex'] as num?)?.toInt() ?? -1;
    if (dartIndex < 0 || dartIndex >= DartsK.dartsPerTurn) return null;
    return DartsLiveEvent(
      kind: kind as String,
      shooterUid: m['shooterUid'] as String? ?? '',
      round: (m['round'] as num?)?.toInt() ?? 1,
      dartIndex: dartIndex,
      launched: m['launched'] as bool? ?? false,
      hitX: d('hitX'),
      hitY: d('hitY'),
      createdAtMs: (m['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One finished turn, scored from the darts' hit positions with the 301
/// rules. Used by the Firestore transaction and by both phones, so all three
/// always agree.
class DartsTurnTally {
  /// Points the turn scored (0 on a bust).
  final int total;

  /// Darts actually used (a bust or checkout ends the turn early).
  final int dartsUsed;
  final bool bust;
  final bool checkout;
  final int onBoard;
  final int trebles;
  final int bulls;

  /// The darts that counted, in order (darts after a bust/checkout are dropped).
  final List<DartHit> hits;

  const DartsTurnTally({
    required this.total,
    required this.dartsUsed,
    required this.bust,
    required this.checkout,
    required this.onBoard,
    required this.trebles,
    required this.bulls,
    required this.hits,
  });

  /// Scores [darts] (any order; only `dart` events, one per index) for a
  /// thrower who had [remainingAtStart] points left when the turn began.
  /// A missing dart counts as a miss.
  static DartsTurnTally score(int remainingAtStart, List<DartsLiveEvent> darts) {
    final byIndex = <int, DartsLiveEvent>{
      for (final d in darts)
        if (d.isDart && d.dartIndex >= 0 && d.dartIndex < DartsK.dartsPerTurn)
          d.dartIndex: d,
    };
    final points = <int>[];
    final hits = <DartHit>[];
    int onBoard = 0, trebles = 0, bulls = 0;
    DartTurnResult? last;
    for (int i = 0; i < DartsK.dartsPerTurn; i++) {
      final DartHit h = byIndex[i]?.hit ?? DartScoring.score(DartsLiveEvent.missX, 0.0);
      last = DartsRules.applyDart(remainingAtStart, points, h.points);
      points.add(h.points);
      hits.add(h);
      if (!h.isMiss) onBoard++;
      if (h.isTreble) trebles++;
      if (h.isBull) bulls++;
      if (last.turnOver) break;
    }
    final r = last!;
    return DartsTurnTally(
      total: r.newTurnTotal,
      dartsUsed: r.dartsUsed,
      bust: r.bust,
      checkout: r.checkout,
      onBoard: onBoard,
      trebles: trebles,
      bulls: bulls,
      hits: hits,
    );
  }
}

/// A batch of live events from one snapshot. [initial] is true for the first
/// snapshot after subscribing: those darts already landed (e.g. you
/// rejoined), so they are shown instantly, never replayed.
class DartsLiveBatch {
  final List<DartsLiveEvent> events;
  final bool initial;
  const DartsLiveBatch(this.events, {required this.initial});
}
