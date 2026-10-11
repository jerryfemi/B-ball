import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'scoreboard/hot_streak_pill.dart';
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

  const StadiumScoreboard({
    super.key,
    required this.game,
    this.onHelpTapped,
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
                  const ScoreboardPlayerAvatar(),
                  const SizedBox(width: 6.0),
                  ScoreboardPauseBadge(game: widget.game),
                  const SizedBox(width: 8.0),
                  _buildTrapezoidalConsole(),
                  const SizedBox(width: 8.0),
                  const ScoreboardMuteBadge(),
                  const SizedBox(width: 6.0),
                  ScoreboardHelpBadge(onTap: widget.onHelpTapped),
                ],
              ),
            ),
            HotStreakPill(streakNotifier: widget.game.streakNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildTrapezoidalConsole() {
    return CustomPaint(
      painter: const TrapezoidScoreboardPainter(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 6.0,
        ),
        constraints: const BoxConstraints(
          minWidth: 260.0,
          maxWidth: 320.0,
          minHeight: 56.0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ScoreboardBay(
              label: 'YOU',
              valueListenable: widget.game.scoreNotifier,
              scaleAnimation: _scoreScaleAnimation,
            ),
            const SizedBox(width: 10.0),
            ScoreboardClockBay(
              timeRemainingNotifier: widget.game.timeRemainingNotifier,
              urgentGlowAnimation: _urgentGlowAnimation,
            ),
            const SizedBox(width: 10.0),
            ValueListenableBuilder<bool>(
              valueListenable: widget.game.isGhostModeNotifier,
              builder: (context, isGhost, _) {
                if (isGhost) {
                  return ScoreboardBay(
                    label: 'GHOST',
                    valueListenable: widget.game.ghostScoreNotifier,
                  );
                }
                return ScoreboardBay(
                  label: 'BEST',
                  valueListenable: widget.game.bestScoreNotifier,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
