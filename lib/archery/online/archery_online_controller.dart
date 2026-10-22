import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/cloud_match.dart';
import '../../services/firestore_match_service.dart';
import '../archery_constants.dart';
import '../physics/target_scoring.dart';
import '../state/archery_match_notifier.dart';
import '../state/archery_match_state.dart';
import '../state/archery_rules.dart';
import 'archery_live_event.dart';

/// What the online controller drives in the Flame game.
abstract interface class ArcheryOnlineGame {
  /// Clears the target, moves it to this set's distance and puts the
  /// shooter's already-landed arrows in it (instantly, no replay).
  void beginOnlineTurn({
    required int setIndex,
    required bool mine,
    required List<ArcheryLiveEvent> shooterArrows,
  });

  /// The opponent pressed to aim: raise the camera like they did.
  void remoteDraw();

  /// The opponent's arrow: fly it with their launch angles.
  void playRemoteArrow(ArcheryLiveEvent event);

  /// Your shot clock ran out: this arrow is a miss.
  void forceMiss();

  /// True while an arrow is flying or the camera is away from the line.
  bool get isBusy;
}

/// Runs one live online archery match on this phone.
///
/// Firestore is the referee: the match document says whose set it is
/// (`activeTurnPlayerUid`, `currentRound`); each arrow is a small event in
/// `live_shots` that the other phone re-flies with the same physics and wind;
/// the finished set goes through [ArcheryMatchService.submitArcherySet].
///
/// Turns switch set by set. No replays: arrows that landed while you were
/// away are just shown.
class ArcheryOnlineController {
  final String matchId;
  final String myUid;
  final ArcheryMatchNotifier notifier;
  final FirestoreMatchService service;

  ArcheryOnlineGame? _game;

  ArcheryOnlineController({
    required this.matchId,
    required this.myUid,
    required this.notifier,
    FirestoreMatchService? service,
  }) : service = service ?? FirestoreMatchService.instance;

  /// Seconds left on the shot clock (yours or your estimate of theirs);
  /// −1 hides it. Only changes once per second.
  final ValueNotifier<int> shotClock = ValueNotifier<int>(-1);

  /// The latest match document (names, avatars, code, status).
  final ValueNotifier<CloudMatch?> match = ValueNotifier<CloudMatch?>(null);

  StreamSubscription<CloudMatch?>? _matchSub;
  StreamSubscription<ArcheryLiveBatch>? _liveSub;

  // Current turn
  int _turnRound = 0; // 1-based; 0 = none yet
  String _turnShooter = '';
  bool get _myTurn => _turnShooter == myUid;
  final List<ArcheryLiveEvent> _myArrows = [];
  int _opponentArrowsSeen = 0;
  bool _submitting = false;
  Future<bool>? _pendingBroadcast;

  // Set results already shown (= sets both archers finished).
  int _resultsShown = 0;
  bool _primed = false;
  bool _showingResult = false;
  bool _finished = false;

  ArcheryLiveStatus _status = ArcheryLiveStatus.none;

  void _setStatus(ArcheryLiveStatus s) {
    if (_status == s) return;
    _status = s;
    notifier.setLiveStatus(s);
  }

  // Clocks (seconds)
  double _clock = ArcheryRules.shotClockSeconds.toDouble();

  /// Seconds a timed-out arrow ran over, taken off the next arrow's clock
  /// (so a long absence costs one arrow per 25 s, not just one).
  double _overrun = 0.0;

  /// Your shot clock when you last left a match (lobby, inbox), per match,
  /// so coming back continues it instead of starting a fresh 25 s.
  static final Map<String, _SavedClock> _savedClocks = {};
  double _idle = 0.0; // since the opponent last did anything
  double _drawingFor = -1.0; // since their draw ping, −1 = not drawing

  String get _opponentUid {
    final m = match.value;
    if (m == null) return '';
    return m.player1.uid == myUid ? (m.player2?.uid ?? '') : m.player1.uid;
  }

  /// Seed for wind and sway: identical on both phones.
  static int seedFor(String matchId) => ArcheryRules.seedFromMatchId(matchId);

  void attach(ArcheryOnlineGame game) {
    _game = game;
    _matchSub ??= service.streamMatch(matchId.trim().toUpperCase()).listen(
          _onMatch,
          onError: (Object e) => debugPrint('[ArcheryOnline] match stream: $e'),
        );
  }

  void dispose() {
    if (_myTurn && _turnRound > 0 && !_submitting && !_finished &&
        _myArrows.length < ArcheryRules.arrowsPerSet) {
      _savedClocks[matchId] = _SavedClock(
        round: _turnRound,
        arrowIndex: _myArrows.length,
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

    if (m.status == MatchStatus.forfeited || m.status == MatchStatus.abandoned) {
      if (_finished) return;
      _finished = true;
      _stopTurn();
      final winnerUid = m.winnerUid;
      _status = ArcheryLiveStatus.none;
      notifier.endOnlineByForfeit(
        winnerUid == myUid ? 1 : (winnerUid == null || winnerUid.isEmpty ? 0 : -1),
      );
      return;
    }

    final (mine, theirs) = _totals(m);
    final int settled = mine.length < theirs.length ? mine.length : theirs.length;

    // Opening a running match: don't recap sets finished before you came.
    if (!_primed) {
      _primed = true;
      if (m.status != MatchStatus.completed) _resultsShown = settled;
    }

    // A set both archers finished that we haven't shown yet.
    if (settled > _resultsShown && !_showingResult) {
      _showSetResult(m, settled);
      return;
    }
    if (_showingResult || _finished) return;
    _syncTurn(m);
  }

  (List<int>, List<int>) _totals(CloudMatch m) {
    final me = m.myPlayer(myUid);
    final opp = m.opponentPlayer(myUid);
    return (me?.roundScores ?? const [], opp?.roundScores ?? const []);
  }

  Future<void> _showSetResult(CloudMatch m, int settled) async {
    _showingResult = true;
    _stopTurn();
    final (mine, theirs) = _totals(m);
    final int round = settled;
    final double d = ArcheryK.distanceForSet(round - 1);
    final myArrows = await service.getArcheryArrows(matchId, shooterUid: myUid, round: round);
    final theirArrows =
        await service.getArcheryArrows(matchId, shooterUid: _opponentUid, round: round);
    if (_game == null) return; // left the screen meanwhile
    final bool over = m.status == MatchStatus.completed;
    _resultsShown = settled;
    if (over) _finished = true;
    _status = ArcheryLiveStatus.none;
    notifier.showOnlineSetResult(
      mine: [for (final a in myArrows) a.score(d)],
      theirs: [for (final a in theirArrows) a.score(d)],
      userSetTotals: mine.sublist(0, settled),
      opponentSetTotals: theirs.sublist(0, settled),
      matchOver: over,
    );
  }

  /// "Next set" on the result card.
  void continueAfterSet() {
    if (!_showingResult || _finished) return;
    _showingResult = false;
    final m = match.value;
    if (m != null) _onMatch(m);
  }

  void _syncTurn(CloudMatch m) {
    final String shooter = m.activeTurnPlayerUid;
    final int round = m.currentRound;
    if (shooter.isEmpty) {
      // Waiting for someone to join after you shot set 1.
      if (m.status == MatchStatus.waitingForOpponent) {
        _setStatus(ArcheryLiveStatus.waitingToJoin);
        shotClock.value = -1;
      }
      return;
    }
    if (shooter == _turnShooter && round == _turnRound) {
      // Same turn; the opponent may just have joined while you shoot set 1.
      if (_myTurn && !_submitting) {
        _setStatus(m.status == MatchStatus.waitingForOpponent
            ? ArcheryLiveStatus.waitingToJoin
            : ArcheryLiveStatus.yourShot);
      }
      return;
    }
    _beginTurn(m, shooter, round);
  }

  Future<void> _beginTurn(CloudMatch m, String shooter, int round) async {
    _stopTurn();
    _turnShooter = shooter;
    _turnRound = round;
    final int setIndex = round - 1;
    final double d = ArcheryK.distanceForSet(setIndex);

    final myArrows = await service.getArcheryArrows(matchId, shooterUid: myUid, round: round);
    final oppUid = _opponentUid;
    final theirArrows = oppUid.isEmpty
        ? const <ArcheryLiveEvent>[]
        : await service.getArcheryArrows(matchId, shooterUid: oppUid, round: round);
    if (_game == null) return; // left the screen meanwhile
    if (_turnShooter != shooter || _turnRound != round) return; // superseded

    final (mine, theirs) = _totals(m);
    final int settled = mine.length < theirs.length ? mine.length : theirs.length;
    final bool myTurn = shooter == myUid;
    notifier.beginOnlineTurn(
      setIndex: setIndex,
      shooter: myTurn ? ArcheryShooter.you : ArcheryShooter.opponent,
      mine: [for (final a in myArrows) a.score(d)],
      theirs: [for (final a in theirArrows) a.score(d)],
      userSetTotals: mine.sublist(0, settled),
      opponentSetTotals: theirs.sublist(0, settled),
    );
    _game?.beginOnlineTurn(
      setIndex: setIndex,
      mine: myTurn,
      shooterArrows: myTurn ? myArrows : theirArrows,
    );

    _clock = ArcheryRules.shotClockSeconds.toDouble();
    _overrun = 0.0;
    _idle = 0.0;
    _drawingFor = -1.0;

    if (myTurn) {
      _myArrows
        ..clear()
        ..addAll(myArrows);
      if (_myArrows.length >= ArcheryRules.arrowsPerSet) {
        unawaited(_submit()); // shot it all before, the submit didn't land
        return;
      }
      // Coming back mid-set: the clock kept running while you were away.
      _restoreClock(m, round);
      _setStatus(m.status == MatchStatus.waitingForOpponent
          ? ArcheryLiveStatus.waitingToJoin
          : ArcheryLiveStatus.yourShot);
      // Lets the spectator claim the win if this turn is abandoned.
      if (m.liveShooterUid != myUid) {
        unawaited(service.markTurnStarted(matchId: matchId, shooterUid: myUid));
      }
    } else {
      _opponentArrowsSeen = theirArrows.length;
      _setStatus(ArcheryLiveStatus.waitingForShot);
      _liveSub = service
          .streamArcheryEvents(matchId, shooterUid: shooter, round: round)
          .listen(_onLiveBatch);
    }
  }

  void _stopTurn() {
    _liveSub?.cancel();
    _liveSub = null;
    shotClock.value = -1;
  }

  /// Your shot clock for the arrow you're on, if you left and came back:
  /// what was left when you went, minus the time away. Without that (page
  /// refresh, other device): 25 s from when your last arrow landed, or from
  /// when the set began. Anything past zero is carried as [_overrun].
  void _restoreClock(CloudMatch m, int round) {
    final double full = ArcheryRules.shotClockSeconds.toDouble();
    final int now = DateTime.now().millisecondsSinceEpoch;
    final saved = _savedClocks.remove(matchId);
    double left;
    if (saved != null && saved.round == round && saved.arrowIndex == _myArrows.length) {
      left = saved.secondsLeft - (now - saved.savedAtMs) / 1000.0;
    } else {
      int? from;
      if (_myArrows.isNotEmpty && _myArrows.last.createdAtMs > 0) {
        from = _myArrows.last.createdAtMs + 3000; // allow for the flight
      } else if (m.liveShooterUid == myUid && m.turnStartedAtMs != null) {
        from = m.turnStartedAtMs; // set already started before you left
      }
      if (from == null) return; // a fresh set: full clock
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

  void _onLiveBatch(ArcheryLiveBatch batch) {
    final events = [...batch.events]
      ..sort((a, b) => a.arrowIndex.compareTo(b.arrowIndex));
    for (final e in events) {
      if (e.shooterUid != _turnShooter || e.round != _turnRound) continue;
      if (e.isDraw) {
        if (batch.initial || e.arrowIndex < _opponentArrowsSeen) continue;
        _idle = 0.0;
        _drawingFor = 0.0;
        _setStatus(ArcheryLiveStatus.opponentDrawing);
        _game?.remoteDraw();
        continue;
      }
      // Arrow: in order, once each.
      if (e.arrowIndex != _opponentArrowsSeen) continue;
      _opponentArrowsSeen++;
      _idle = 0.0;
      _drawingFor = -1.0;
      _clock = ArcheryRules.shotClockSeconds.toDouble();
      _setStatus(ArcheryLiveStatus.waitingForShot);
      _game?.playRemoteArrow(e);
    }
  }

  // ── Your arrows ─────────────────────────────────────────────────────────

  /// You pressed to aim.
  void onMyDraw() {
    if (!_myTurn || _submitting) return;
    _pendingBroadcast = service.broadcastArcheryEvent(
      matchId: matchId,
      event: ArcheryLiveEvent(
        kind: ArcheryLiveEvent.kindDraw,
        shooterUid: myUid,
        round: _turnRound,
        arrowIndex: _myArrows.length,
      ),
    );
  }

  /// Your arrow landed (or the shot clock made it a miss).
  void onMyArrow({
    required bool launched,
    required double yaw,
    required double pitch,
    required ShotScore score,
  }) {
    if (!_myTurn || _myArrows.length >= ArcheryRules.arrowsPerSet) return;
    final event = ArcheryLiveEvent(
      kind: ArcheryLiveEvent.kindArrow,
      shooterUid: myUid,
      round: _turnRound,
      arrowIndex: _myArrows.length,
      launched: launched,
      yaw: yaw,
      pitch: pitch,
      hitX: score.localX.isFinite ? score.localX : 0.0,
      hitY: score.localY.isFinite ? score.localY : 0.0,
      hitBoss: score.hitBoss,
      ring: score.points,
      isX: score.isX,
    );
    _myArrows.add(event);
    _clock = ArcheryRules.shotClockSeconds - _overrun;
    if (_clock <= 0) {
      _overrun = -_clock; // still over: the next arrow times out too
      _clock = 0.0001;
    } else {
      _overrun = 0.0;
    }
    _pendingBroadcast = service.broadcastArcheryEvent(matchId: matchId, event: event);
    if (_myArrows.length >= ArcheryRules.arrowsPerSet) {
      // Give the opponent's phone time to fly your last arrow before the
      // turn changes hands.
      shotClock.value = -1;
      _setStatus(ArcheryLiveStatus.submitting);
      Future<void>.delayed(const Duration(milliseconds: 2500), _submit);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _submitting = true;
    _setStatus(ArcheryLiveStatus.submitting);
    shotClock.value = -1;
    final int round = _turnRound;
    final double d = ArcheryK.distanceForSet(round - 1);
    // The last arrow must be written while it is still our turn.
    await _pendingBroadcast;
    // Retry until it lands or the turn moved on (e.g. it did land before).
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        await service.submitArcherySet(
          matchId: matchId,
          shooterUid: myUid,
          round: round,
          arrows: List.of(_myArrows),
          distance: d,
        );
        break;
      } on NotYourTurnException {
        break;
      } on RoundMismatchException {
        break;
      } catch (e) {
        debugPrint('[ArcheryOnline] submit failed (try ${attempt + 1}): $e');
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
    if (_turnRound == 0 || _showingResult || _finished) return;
    final game = _game;
    if (game == null) return;

    if (_myTurn) {
      if (_submitting || _myArrows.length >= ArcheryRules.arrowsPerSet) return;
      // The clock runs only while you stand at the line deciding.
      if (!game.isBusy) {
        _clock -= dt;
        if (_clock <= 0.0) {
          _clock = ArcheryRules.shotClockSeconds.toDouble();
          game.forceMiss();
        }
      }
      _publishClock(_clock);
      return;
    }

    // Opponent's turn: estimate their clock and watch for silence.
    _idle += dt;
    if (_drawingFor >= 0.0) {
      _drawingFor += dt;
      if (_drawingFor > 12.0) _drawingFor = -1.0; // they let go without shooting
    } else if (!game.isBusy) {
      _clock = (_clock - dt).clamp(0.0, ArcheryRules.shotClockSeconds.toDouble());
    }
    _publishClock(_clock);

    final status = _status;
    if (_idle > ArcheryRules.shotClockSeconds + 8.0) {
      final m = match.value;
      final startedAt = m?.turnStartedAtMs;
      final bool claimable = m != null &&
          m.liveShooterUid == _turnShooter &&
          startedAt != null &&
          DateTime.now().millisecondsSinceEpoch >
              startedAt + (m.roundDurationSeconds + 55) * 1000;
      final next =
          claimable ? ArcheryLiveStatus.opponentGone : ArcheryLiveStatus.reconnecting;
      if (status != next) _setStatus(next);
    } else if (_drawingFor < 0.0 &&
        (status == ArcheryLiveStatus.reconnecting ||
            status == ArcheryLiveStatus.opponentGone)) {
      _setStatus(ArcheryLiveStatus.waitingForShot);
    }
  }

  void _publishClock(double seconds) {
    final int s = seconds.ceil().clamp(0, ArcheryRules.shotClockSeconds);
    if (shotClock.value != s) shotClock.value = s;
  }
}

/// Shot clock left when you stepped away from a live set.
class _SavedClock {
  final int round;
  final int arrowIndex;
  final double secondsLeft;
  final int savedAtMs;

  const _SavedClock({
    required this.round,
    required this.arrowIndex,
    required this.secondsLeft,
    required this.savedAtMs,
  });
}
