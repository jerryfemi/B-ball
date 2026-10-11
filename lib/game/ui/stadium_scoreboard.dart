import 'package:flutter/material.dart';

import '../basketball_game.dart';
import '../match/match_session.dart';
import 'scoreboard/hot_streak_pill.dart';
import 'scoreboard/round_indicator_badge.dart';
import 'scoreboard/scoreboard_bay.dart';
import 'scoreboard/scoreboard_flank_badges.dart';
import 'scoreboard/trapezoid_scoreboard_painter.dart';
import 'inbox/inbox_notification_badge.dart';

export 'scoreboard/trapezoid_scoreboard_painter.dart';

/// GamePigeon Authentic 3-Bay Electronic LED Stadium Scoreboard.
///
/// Orchestrates:
/// 1. Flanking player avatar badge ("You")
/// 2. Matte black trapezoidal chassis with white contour
/// 3. Score bays ("YOU" and "BEST") with glowing red LEDs
/// 4. Center amber countdown clock with flashing urgency
/// 5. Flanking rules "?" button
/// 6. Animated hot streak fire pill
class StadiumScoreboard extends StatefulWidget {
  final BasketballGame game;
  final VoidCallback? onHelpTapped;
  final VoidCallback? onInboxTapped;

  const StadiumScoreboard({
    super.key,
    required this.game,
    this.onHelpTapped,
    this.onInboxTapped,
  });

  @override
  State<StadiumScoreboard> createState() => _StadiumScoreboardState();
}

class _StadiumScoreboardState extends State<StadiumScoreboard>
    with TickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _scoreScaleAnimation;

  late final AnimationController _urgentClockController;
  late final Animation<double> _urgentGlowAnimation;

  int _lastScore = 0;

  @override
  void initState() {
    super.initState();

    // 1. Spring pop on score change
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scoreScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_popController);

    // 2. Urgent clock pulse when time <= 10s
    _urgentClockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _urgentClockController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          if (widget.game.timeRemainingNotifier.value <= 10 &&
              widget.game.timeRemainingNotifier.value > 0) {
            _urgentClockController.forward();
          }
        }
      });

    _urgentGlowAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _urgentClockController,
        curve: Curves.easeInOut,
      ),
    );

    widget.game.scoreNotifier.addListener(_onScoreChanged);
    widget.game.timeRemainingNotifier.addListener(_onTimeChanged);
    _lastScore = widget.game.scoreNotifier.value;
  }

  @override
  void didUpdateWidget(covariant StadiumScoreboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.scoreNotifier.removeListener(_onScoreChanged);
      oldWidget.game.timeRemainingNotifier.removeListener(_onTimeChanged);
      widget.game.scoreNotifier.addListener(_onScoreChanged);
      widget.game.timeRemainingNotifier.addListener(_onTimeChanged);
    }
  }

  @override
  void dispose() {
    widget.game.scoreNotifier.removeListener(_onScoreChanged);
    widget.game.timeRemainingNotifier.removeListener(_onTimeChanged);
    _popController.dispose();
    _urgentClockController.dispose();
    super.dispose();
  }

  void _onScoreChanged() {
    final current = widget.game.scoreNotifier.value;
    if (current > _lastScore) {
      _popController.forward(from: 0.0);
    }
    _lastScore = current;
  }

  void _onTimeChanged() {
    final remaining = widget.game.timeRemainingNotifier.value;
    if (remaining <= 10 && remaining > 0) {
      if (!_urgentClockController.isAnimating) {
        _urgentClockController.forward();
      }
    } else {
      if (_urgentClockController.isAnimating) {
        _urgentClockController.stop();
        _urgentClockController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MatchSession?>(
      valueListenable: widget.game.matchSessionNotifier,
      builder: (context, matchSession, _) {
        return _buildLayout(context, matchSession);
      },
    );
  }

  Widget _buildLayout(BuildContext context, MatchSession? matchSession) {
    final is1v1 = matchSession != null;
    final isWatchingReplay =
        is1v1 && matchSession.phase == MatchTurnPhase.watchingOpponentReplay;

    // When watching opponent replay, highlight the opponent whose shots are actively flying into the net.
    // When shooting live, highlight the active shooter.
    final int shootingPlayerIndex = is1v1
        ? (isWatchingReplay
            ? (matchSession.activePlayerIndex == 0 ? 1 : 0)
            : matchSession.activePlayerIndex)
        : 0;

    final p1Active = shootingPlayerIndex == 0;
    final p2Active = shootingPlayerIndex == 1;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ScoreboardPlayerAvatar(
                    isActive: p1Active,
                    label: is1v1 ? matchSession.player1.name : 'You',
                    avatar: is1v1 ? matchSession.player1.avatar : '🏀',
                  ),
                  const SizedBox(width: 5.0),
                  ScoreboardPauseBadge(game: widget.game),
                  const SizedBox(width: 5.0),
                  ScoreboardHelpBadge(onTap: widget.onHelpTapped),
                  const SizedBox(width: 8.0),
                  _buildTrapezoidalConsole(matchSession, shootingPlayerIndex),
                  const SizedBox(width: 8.0),
                  const ScoreboardMuteBadge(),
                  if (widget.onInboxTapped != null) ...[
                    const SizedBox(width: 5.0),
                    InboxNotificationBadge(
                      onTap: widget.onInboxTapped!,
                      activeMatchId: matchSession?.cloudMatchId,
                    ),
                  ],
                  if (is1v1) ...[
                    const SizedBox(width: 5.0),
                    ScoreboardOpponentAvatar(
                      isActive: p2Active,
                      label: matchSession.player2.name,
                      avatar: matchSession.player2.avatar,
                    ),
                  ],
                ],
              ),
            ),
            HotStreakPill(streakNotifier: widget.game.streakNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildTrapezoidalConsole(MatchSession? matchSession, int shootingPlayerIndex) {
    final is1v1 = matchSession != null;

    return CustomPaint(
      painter: const TrapezoidScoreboardPainter(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 6.0,
        ),
        constraints: const BoxConstraints(
          minWidth: 260.0,
          maxWidth: 330.0,
          minHeight: 56.0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ScoreboardBay(
              label: 'YOU',
              valueListenable: is1v1
                  ? widget.game.player1MatchScoreNotifier
                  : widget.game.scoreNotifier,
              scaleAnimation: (is1v1 && shootingPlayerIndex == 0) || !is1v1
                  ? _scoreScaleAnimation
                  : null,
            ),
            const SizedBox(width: 10.0),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoreboardClockBay(
                  timeRemainingNotifier: widget.game.timeRemainingNotifier,
                  urgentGlowAnimation: _urgentGlowAnimation,
                ),
                if (is1v1)
                  RoundIndicatorBadge(
                    currentRound: matchSession.currentRoundNumber,
                    totalRounds: matchSession.totalRounds,
                  ),
              ],
            ),
            const SizedBox(width: 10.0),
            ScoreboardBay(
              label: is1v1 ? 'THEM' : 'BEST',
              valueListenable: is1v1
                  ? widget.game.player2MatchScoreNotifier
                  : widget.game.bestScoreNotifier,
              scaleAnimation: (is1v1 && shootingPlayerIndex == 1)
                  ? _scoreScaleAnimation
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
