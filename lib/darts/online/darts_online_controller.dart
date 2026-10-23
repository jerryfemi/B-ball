import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/cloud_match.dart';
import '../../services/firestore_match_service.dart';
import '../physics/dart_scoring.dart';
import '../state/darts_match_notifier.dart';
import '../state/darts_match_state.dart';
import '../state/darts_rules.dart';
import 'darts_live_event.dart';

/// What the online controller drives in the Flame game.
abstract interface class DartsOnlineGame {
  /// Clears the board for a turn and puts the thrower's already-landed
  /// darts in it (instantly, no replay).
  void beginOnlineTurn({
    required int round,
    required bool mine,
    required List<DartHit> turnDarts,
  });

  /// The opponent's dart: fly it and land it exactly at [hit].
  void playRemoteDart(DartHit hit);

  /// Your shot clock ran out: this dart is a miss.
  void forceMiss();

  /// True while a dart is flying or the board is being cleared.
  bool get isBusy;
}

/// Runs one live online darts match on this phone.
///
/// Firestore is the referee: the match document says whose turn it is
/// (`activeTurnPlayerUid`, `currentRound`). Player 1 opens every round,
/// player 2 answers it. Each landed dart is a small event in `live_shots`
/// (hit position only) that the other phone flies and lands at the same
/// spot; the finished turn goes through [DartsMatchService.submitDartsTurn],
/// which re-scores it from the hit positions.
///
/// No replays: darts that landed while you were away are just shown.
class DartsOnlineController {
  final String matchId;
  final String myUid;
  final DartsMatchNotifier notifier;
  final FirestoreMatchService service;

  DartsOnlineGame? _game;

  DartsOnlineController({
    required this.matchId,
    required this.myUid,
    required this.notifier,
    FirestoreMatchService? service,
  }) : service = service ?? FirestoreMatchService.instance;

  /// Seconds left on the shot clock (yours, or your estimate of theirs);
  /// −1 hides it. Only changes once per second.
  final ValueNotifier<int> shotClock = ValueNotifier<int>(-1);

  /// The latest match document (names, avatars, code, status).
  final ValueNotifier<CloudMatch?> match = ValueNotifier<CloudMatch?>(null);

  StreamSubscription<CloudMatch?>? _matchSub;
  StreamSubscription<DartsLiveBatch>? _liveSub;

  // Current turn
  int _turnRound = 0; // 1-based; 0 = none yet
  String _turnShooter = '';
  bool get _myTurn => _turnShooter == myUid;
  final List<DartsLiveEvent> _myDarts = [];
  int _myRemainingAtStart = DartsRules.startScore;
  int _opponentDartsSeen = 0;
  bool _turnDone = false; // your turn ended on this phone (3 darts, bust, checkout)
  bool _submitting = false;
  Future<bool>? _pendingBroadcast;
  bool _finished = false;

  DartsLiveStatus _status = DartsLiveStatus.none;

  void _setStatus(DartsLiveStatus s) {
    if (_status == s) return;
    _status = s;
    notifier.setLiveStatus(s);
  }

  // Clocks (seconds)
  double _clock = DartsRules.shotClockSeconds.toDouble();

  /// Seconds a timed-out dart ran over, taken off the next dart's clock (so
  /// a long absence costs one dart per clock, not just one).
  double _overrun = 0.0;

  /// Your shot clock when you last left a match (lobby, inbox), per match,
  /// so coming back continues it instead of starting a fresh one.
  static final Map<String, _SavedClock> _savedClocks = {};
  double _idle = 0.0; // since the opponent last did anything

  String get _opponentUid {
    final m = match.value;
    if (m == null) return '';
    return m.player1.uid == myUid ? (m.player2?.uid ?? '') : m.player1.uid;
  }

  /// Seed for wobble: identical on both phones.
  static int seedFor(String matchId) => DartsRules.seedFromMatchId(matchId);

  void attach(DartsOnlineGame game) {
    _game = game;
    _matchSub ??= service.streamMatch(matchId.trim().toUpperCase()).listen(
          _onMatch,
          onError: (Object e) => debugPrint('[DartsOnline] match stream: $e'),
        );
  }

  void dispose() {
    if (_myTurn && _turnRound > 0 && !_turnDone && !_submitting && !_finished) {
      _savedClocks[matchId] = _SavedClock(
        round: _turnRound,
        dartIndex: _myDarts.length,
        secondsLeft: _clock - _overrun,
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
    _matchSub?.cancel();
    _liveSub?.cancel();
    _matchSub = null;
    _liveSub = null;
    _game = null;
    shotClock.dispose();
    match.dispose();
  }

  // ── Match document ──────────────────────────────────────────────────────

  void _onMatch(CloudMatch? m) {
    if (m == null || _game == null) return;
    match.value = m;
    if (_finished) return;

    if (m.status == MatchStatus.forfeited || m.status == MatchStatus.abandoned) {
      _finished = true;
      _stopTurn();
      final winnerUid = m.winnerUid;
      _status = DartsLiveStatus.none;
      notifier.endOnlineByForfeit(
        winnerUid == myUid ? 1 : (winnerUid == null || winnerUid.isEmpty ? 0 : -1),
      );
      return;
    }

    if (m.status == MatchStatus.completed) {
      _finished = true;
      _stopTurn();
      _status = DartsLiveStatus.none;
      final me = m.myPlayer(myUid);
      final opp = m.opponentPlayer(myUid);
      notifier.showOnlineRoundResult(
        yourTurns: me?.roundScores ?? const [],
        theirTurns: opp?.roundScores ?? const [],
        yourLastDarts: _lastDarts(me),
        theirLastDarts: _lastDarts(opp),
        matchOver: true,
      );
      return;
    }

    _syncTurn(m);
  }

  /// Darts used in a player's last turn (the checkout tiebreak).
  static int _lastDarts(CloudPlayer? p) {
    if (p == null || p.roundSummaries.isEmpty) return DartsRules.dartsPerTurn;
    final n = p.roundSummaries.last.totalShots;
    return (n >= 1 && n <= DartsRules.dartsPerTurn) ? n : DartsRules.dartsPerTurn;
  }

  void _syncTurn(CloudMatch m) {
    final String shooter = m.activeTurnPlayerUid;
    final int round = m.currentRound;
    if (shooter.isEmpty) {
      // You threw round 1 and nobody has joined yet.
      if (m.status == MatchStatus.waitingForOpponent) {
        _stopTurn();
        _setStatus(DartsLiveStatus.waitingToJoin);
      }
      return;
    }
    if (shooter == _turnShooter && round == _turnRound) {
      // Same turn; the opponent may just have joined while you throw round 1.
      if (_myTurn && !_turnDone && !_submitting) {
        _setStatus(m.status == MatchStatus.waitingForOpponent
            ? DartsLiveStatus.waitingToJoin
            : DartsLiveStatus.yourShot);
      }
      return;
    }
    _beginTurn(m, shooter, round);
  }

  Future<void> _beginTurn(CloudMatch m, String shooter, int round) async {
    _stopTurn();
    _turnShooter = shooter;
    _turnRound = round;
    _turnDone = false;

    final bool myTurn = shooter == myUid;
    final shooterDarts =
        await service.getDartsThrows(matchId, shooterUid: shooter, round: round);
    if (_game == null) return; // left the screen meanwhile
    if (_turnShooter != shooter || _turnRound != round) return; // superseded

    final me = m.myPlayer(myUid);
    final opp = m.opponentPlayer(myUid);
    final List<int> myScores = me?.roundScores ?? const [];
    final List<int> theirScores = opp?.roundScores ?? const [];
    final int shooterRemaining =
        DartsRules.remaining(myTurn ? myScores : theirScores);

    // The darts of this turn that still count (a bust/checkout ends it).
    final tally = DartsTurnTally.score(shooterRemaining, shooterDarts);
    final bool alreadyOver = shooterDarts.length >= DartsRules.dartsPerTurn ||
        ((tally.bust || tally.checkout) && shooterDarts.length >= tally.dartsUsed);
    final List<DartHit> landed = alreadyOver
        ? tally.hits
        : [for (final d in shooterDarts) d.hit];

    notifier.beginOnlineTurn(
      round: round,
      thrower: myTurn ? DartsThrower.you : DartsThrower.opponent,
      turnDarts: alreadyOver ? const [] : landed,
      yourTurns: myScores,
      theirTurns: theirScores,
      yourLastDarts: _lastDarts(me),
      theirLastDarts: _lastDarts(opp),
    );
    _game?.beginOnlineTurn(round: round, mine: myTurn, turnDarts: landed);

    _clock = DartsRules.shotClockSeconds.toDouble();
    _overrun = 0.0;
    _idle = 0.0;

    if (myTurn) {
      _myRemainingAtStart = shooterRemaining;
      _myDarts
        ..clear()
        ..addAll(shooterDarts);
      if (alreadyOver) {
        _turnDone = true;
        unawaited(_submit()); // threw it all before, the submit didn't land
        return;
      }
      // Coming back mid-turn: the clock kept running while you were away.
      _restoreClock(m, round);
      _setStatus(m.status == MatchStatus.waitingForOpponent
          ? DartsLiveStatus.waitingToJoin
          : DartsLiveStatus.yourShot);
      // Lets the opponent claim the win if this turn is abandoned.
      if (m.liveShooterUid != myUid) {
        unawaited(service.markTurnStarted(matchId: matchId, shooterUid: myUid));
      }
    } else {
      _opponentDartsSeen = shooterDarts.length;
      _setStatus(DartsLiveStatus.waitingForShot);
      _liveSub = service
          .streamDartsEvents(matchId, shooterUid: shooter, round: round)
          .listen(_onLiveBatch);
    }
  }

  void _stopTurn() {
    _liveSub?.cancel();
    _liveSub = null;
    shotClock.value = -1;
  }

  /// Your shot clock for the dart you're on, if you left and came back:
  /// what was left when you went, minus the time away. Without that (page
  /// refresh, other device): a full clock from when your last dart landed,
  /// or from when the turn began. Anything past zero is carried as [_overrun].
  void _restoreClock(CloudMatch m, int round) {
    final double full = DartsRules.shotClockSeconds.toDouble();
    final int now = DateTime.now().millisecondsSinceEpoch;
    final saved = _savedClocks.remove(matchId);
    double left;
    if (saved != null && saved.round == round && saved.dartIndex == _myDarts.length) {
      left = saved.secondsLeft - (now - saved.savedAtMs) / 1000.0;
    } else {
      int? from;
      if (_myDarts.isNotEmpty && _myDarts.last.createdAtMs > 0) {
        from = _myDarts.last.createdAtMs + 1500; // allow for the flight
      } else if (m.liveShooterUid == myUid && m.turnStartedAtMs != null) {
        from = m.turnStartedAtMs; // turn already started before you left
      }
      if (from == null) return; // a fresh turn: full clock
      left = full - (now - from) / 1000.0;
    }
    if (left >= full) return;
    if (left > 0) {
      _clock = left;
    } else {
      _clock = 0.0001; // runs out on the next frame
      _overrun = -left;
    }
  }

  // ── Opponent's live events ──────────────────────────────────────────────

  void _onLiveBatch(DartsLiveBatch batch) {
    final events = [...batch.events]
      ..sort((a, b) => a.dartIndex.compareTo(b.dartIndex));
    for (final e in events) {
      if (e.shooterUid != _turnShooter || e.round != _turnRound) continue;
      if (!e.isDart) continue;
      // Dart: in order, once each.
      if (e.dartIndex != _opponentDartsSeen) continue;
      _opponentDartsSeen++;
      _idle = 0.0;
      _clock = DartsRules.shotClockSeconds.toDouble();
      _setStatus(DartsLiveStatus.waitingForShot);
      _game?.playRemoteDart(e.hit);
    }
  }

  // ── Your darts ──────────────────────────────────────────────────────────

  /// Your dart landed (or the shot clock made it a miss with [launched]
  /// false). Returns true when this dart ended your turn.
  bool onMyDart(DartHit hit, {bool launched = true}) {
    if (!_myTurn || _turnDone || _myDarts.length >= DartsRules.dartsPerTurn) {
      return false;
    }
    final event = DartsLiveEvent.fromHit(
      shooterUid: myUid,
      round: _turnRound,
      dartIndex: _myDarts.length,
      hit: hit,
      launched: launched,
    );
    _myDarts.add(event);
    _clock = DartsRules.shotClockSeconds - _overrun;
    if (_clock <= 0) {
      _overrun = -_clock; // still over: the next dart times out too
      _clock = 0.0001;
    } else {
      _overrun = 0.0;
    }
    _pendingBroadcast = service.broadcastDartsEvent(matchId: matchId, event: event);

    final tally = DartsTurnTally.score(_myRemainingAtStart, _myDarts);
    final bool over = _myDarts.length >= DartsRules.dartsPerTurn ||
        tally.bust ||
        tally.checkout;
    if (over) {
      _turnDone = true;
      // Give the opponent's phone time to fly your last dart before the
      // turn changes hands.
      shotClock.value = -1;
      _setStatus(DartsLiveStatus.submitting);
      Future<void>.delayed(const Duration(milliseconds: 2000), _submit);
    }
    return over;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _submitting = true;
    _setStatus(DartsLiveStatus.submitting);
    shotClock.value = -1;
    final int round = _turnRound;
    // The last dart must be written while it is still our turn.
    await _pendingBroadcast;
    // Retry until it lands or the turn moved on (e.g. it did land before).
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        await service.submitDartsTurn(
          matchId: matchId,
          shooterUid: myUid,
          round: round,
          darts: List.of(_myDarts),
        );
        break;
      } on NotYourTurnException {
        break;
      } on RoundMismatchException {
        break;
      } on MatchNotActiveException {
        break;
      } catch (e) {
        debugPrint('[DartsOnline] submit failed (try ${attempt + 1}): $e');
        await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
      }
    }
    _submitting = false;
  }

  /// Claim the win after the opponent abandoned their live turn.
  Future<void> claimWin() async {
    final opp = _opponentUid;
    if (opp.isEmpty) return;
    await service.claimForfeitVictory(
      matchId: matchId,
      winnerUid: myUid,
      forfeiterUid: opp,
    );
  }

  // ── Clocks (called every frame by the game) ─────────────────────────────

  void update(double dt) {
    if (_turnRound == 0 || _finished) return;
    final game = _game;
    if (game == null) return;

    if (_myTurn) {
      if (_turnDone || _submitting) return;
      // The clock runs only while you're at the oche deciding.
      if (!game.isBusy) {
        _clock -= dt;
        if (_clock <= 0.0) {
          _clock = DartsRules.shotClockSeconds.toDouble();
          game.forceMiss();
        }
      }
      _publishClock(_clock);
      return;
    }

    // Opponent's turn: estimate their clock and watch for silence.
    _idle += dt;
    if (!game.isBusy) {
      _clock = (_clock - dt).clamp(0.0, DartsRules.shotClockSeconds.toDouble());
    }
    _publishClock(_clock);

    final status = _status;
    if (_idle > DartsRules.shotClockSeconds + 8.0) {
      final m = match.value;
      final startedAt = m?.turnStartedAtMs;
      final bool claimable = m != null &&
          m.liveShooterUid == _turnShooter &&
          startedAt != null &&
          DateTime.now().millisecondsSinceEpoch >
              startedAt + (m.roundDurationSeconds + 55) * 1000;
      final next =
          claimable ? DartsLiveStatus.opponentGone : DartsLiveStatus.reconnecting;
      if (status != next) _setStatus(next);
    } else if (status == DartsLiveStatus.reconnecting ||
        status == DartsLiveStatus.opponentGone) {
      _setStatus(DartsLiveStatus.waitingForShot);
    }
  }

  void _publishClock(double seconds) {
    final int s = seconds.ceil().clamp(0, DartsRules.shotClockSeconds);
    if (shotClock.value != s) shotClock.value = s;
  }
}

/// Shot clock left when you stepped away from a live turn.
class _SavedClock {
  final int round;
  final int dartIndex;
  final double secondsLeft;
  final int savedAtMs;

  const _SavedClock({
    required this.round,
    required this.dartIndex,
    required this.secondsLeft,
    required this.savedAtMs,
  });
}
