import 'package:flutter/material.dart';

import '../../models/player_descriptor.dart';
import '../../services/auth_service.dart';
import '../basketball_game.dart';
import '../match/match_session.dart';
import 'scoreboard/hot_streak_pill.dart';
import 'scoreboard/round_indicator_badge.dart';
import 'scoreboard/scoreboard_bay.dart';
import 'scoreboard/scoreboard_flank_badges.dart';
import 'scoreboard/trapezoid_scoreboard_painter.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _urgentClockController;
  late final Animation<double> _urgentGlowAnimation;

  @override
  void initState() {
    super.initState();

    // Urgent clock pulse when time <= 10s
    _urgentClockController =
        AnimationController(
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
      CurvedAnimation(parent: _urgentClockController, curve: Curves.easeInOut),
    );

    widget.game.timeRemainingNotifier.addListener(_onTimeChanged);
  }

  @override
  void didUpdateWidget(covariant StadiumScoreboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.timeRemainingNotifier.removeListener(_onTimeChanged);
      widget.game.timeRemainingNotifier.addListener(_onTimeChanged);
    }
  }

  @override
  void dispose() {
    widget.game.timeRemainingNotifier.removeListener(_onTimeChanged);
    _urgentClockController.dispose();
    super.dispose();
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
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, userProfile, _) {
        return ValueListenableBuilder<MatchSession?>(
          valueListenable: widget.game.matchSessionNotifier,
          builder: (context, matchSession, _) {
            return _buildLayout(context, matchSession, userProfile);
          },
        );
      },
    );
  }

  Widget _buildLayout(
    BuildContext context,
    MatchSession? matchSession,
    UserProfile? userProfile,
  ) {
    final is1v1 = matchSession != null;
    final isSpectatingOpponent = is1v1 &&
        (matchSession.phase == MatchTurnPhase.watchingOpponentReplay ||
         matchSession.phase == MatchTurnPhase.watchingLiveOpponent);

    // When spectating opponent (live or replay), highlight the opponent (bay 1).
    // When shooting live, highlight the active shooter.
    final int shootingPlayerIndex = is1v1
        ? (isSpectatingOpponent ? 1 : matchSession.activePlayerIndex)
        : 0;

    final p1Active = is1v1 && shootingPlayerIndex == 0;
    final p2Active = is1v1 && shootingPlayerIndex == 1;

    final String myAvatar =
        userProfile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;
    final String myLabel = userProfile?.displayName ?? 'You';

    final String p1Avatar = is1v1
        ? (matchSession.player1.id == 'you' ||
                  matchSession.player1.id == userProfile?.uid
              ? myAvatar
              : matchSession.player1.avatar)
        : myAvatar;

    final String p1Label = is1v1 ? matchSession.player1.name : myLabel;

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
                  // Left Flank: Player Avatar + Pause Badge
                  ScoreboardPlayerAvatar(
                    key: widget.game.playerAvatarKey,
                    isActive: p1Active,
                    label: p1Label,
                    avatar: p1Avatar,
                    activeMatchId: matchSession?.cloudMatchId,
                    onTap: widget.onInboxTapped,
                  ),
                  const SizedBox(width: 6.0),
                  ScoreboardPauseBadge(game: widget.game),

                  const SizedBox(width: 8.0),
                  _buildTrapezoidalConsole(matchSession, shootingPlayerIndex),
                  const SizedBox(width: 8.0),

                  // Right Flank: Help Badge + Mute Badge (+ Opponent Avatar in 1v1)
                  if (is1v1) ...[
                    ScoreboardHelpBadge(onTap: widget.onHelpTapped),
                    const SizedBox(width: 6.0),
                    const ScoreboardMuteBadge(),
                    const SizedBox(width: 6.0),
                    ScoreboardOpponentAvatar(
                      key: widget.game.rightFlankKey,
                      isActive: p2Active,
                      label: matchSession.isWaitingForOpponent
                          ? (matchSession.joinCode != null
                              ? 'CODE: ${matchSession.joinCode}'
                              : 'WAITING')
                          : matchSession.player2.name,
                      avatar: matchSession.player2.avatar,
                      isWaiting: matchSession.isWaitingForOpponent,
                      joinCode: matchSession.joinCode,
                      activeMatchId: matchSession.cloudMatchId,
                    ),
                  ] else ...[
                    ScoreboardHelpBadge(
                      key: widget.game.rightFlankKey,
                      onTap: widget.onHelpTapped,
                    ),
                    const SizedBox(width: 6.0),
                    const ScoreboardMuteBadge(),
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

  Widget _buildTrapezoidalConsole(
    MatchSession? matchSession,
    int shootingPlayerIndex,
  ) {
    final is1v1 = matchSession != null;

    return CustomPaint(
      painter: const TrapezoidScoreboardPainter(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
              label: is1v1
                  ? (matchSession.isWaitingForOpponent
                      ? 'RIVAL'
                      : matchSession.player2.name.toUpperCase())
                  : 'BEST',
              valueListenable: is1v1
                  ? widget.game.player2MatchScoreNotifier
                  : widget.game.bestScoreNotifier,
            ),
          ],
        ),
      ),
    );
  }
}
