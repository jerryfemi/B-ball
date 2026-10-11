import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'digital_led_display.dart';

/// GamePigeon Authentic 3-Bay Electronic LED Stadium Scoreboard.
///
/// Features:
/// 1. Matte black trapezoidal chassis with crisp white perimeter contour.
/// 2. Left Bay: "YOU" header with glowing red 7-segment digital score digits.
/// 3. Center Bay: Inset rounded white-bordered pill with amber 7-segment countdown clock.
/// 4. Right Bay: "BEST" header with glowing red 7-segment personal record digits.
/// 5. Left/Right Flanking: "You" avatar badge on left, "?" rules button on right.
/// 6. Luminous hot streak fire pill that slides out underneath when streak >= 3.
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
            // ── Primary GamePigeon Console Row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Left Flanking Avatar Badge
                _buildPlayerAvatar(),

                const SizedBox(width: 8.0),

                // 2. Center GamePigeon Trapezoidal Electronic Console
                _buildTrapezoidalConsole(),

                const SizedBox(width: 8.0),

                // 3. Right Flanking Rules Button
                _buildHelpBadge(),
              ],
            ),

            // ── Dynamic Hot Streak Fire Pill ──
            ValueListenableBuilder<int>(
              valueListenable: widget.game.streakNotifier,
              builder: (context, streak, _) {
                final bool isHot = streak >= 3;
                return AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: isHot
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFEA580C),
                                  Color(0xFFDC2626),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: 0.8),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66EA580C),
                                  blurRadius: 10.0,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 13.0),
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  'x$streak ON FIRE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the iconic GamePigeon trapezoidal matte black scoreboard enclosure.
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
            // ── Left Bay: "YOU" Score ──
            _buildScoreBay(
              label: 'YOU',
              isPlayer: true,
            ),

            const SizedBox(width: 10.0),

            // ── Center Bay: Amber Countdown Timer ──
            _buildClockBay(),

            const SizedBox(width: 10.0),

            // ── Right Bay: "BEST" Record ──
            _buildScoreBay(
              label: 'BEST',
              isPlayer: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Score bay with condensed label and red 7-segment digital display.
  Widget _buildScoreBay({
    required String label,
    required bool isPlayer,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 3.5),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6.0,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF060608),
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: const Color(0x38FFFFFF),
              width: 1.0,
            ),
          ),
          child: isPlayer
              ? ScaleTransition(
                  scale: _scoreScaleAnimation,
                  child: ValueListenableBuilder<int>(
                    valueListenable: widget.game.scoreNotifier,
                    builder: (context, score, _) {
                      return DigitalLedNumberDisplay(
                        value: score,
                        digitWidth: 13.0,
                        digitHeight: 23.0,
                        spacing: 2.5,
                        onColor: const Color(0xFFFF2020),
                        offColor: const Color(0x283A0505),
                      );
                    },
                  ),
                )
              : ValueListenableBuilder<int>(
                  valueListenable: widget.game.bestScoreNotifier,
                  builder: (context, bestScore, _) {
                    return DigitalLedNumberDisplay(
                      value: bestScore,
                      digitWidth: 13.0,
                      digitHeight: 23.0,
                      spacing: 2.5,
                      onColor: const Color(0xFFFF2020),
                      offColor: const Color(0x283A0505),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Center clock bay: rounded pill with white outline and amber LED digits.
  Widget _buildClockBay() {
    return AnimatedBuilder(
      animation: _urgentGlowAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.game.timeRemainingNotifier.value <= 10
              ? _urgentGlowAnimation.value
              : 1.0,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9.0,
          vertical: 4.0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF040406),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Colors.white,
            width: 2.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4.0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: widget.game.timeRemainingNotifier,
          builder: (context, secondsRemaining, _) {
            final isUrgent = secondsRemaining <= 10;
            return DigitalLedClockDisplay(
              totalSeconds: secondsRemaining,
              digitWidth: 12.0,
              digitHeight: 22.0,
              spacing: 2.0,
              onColor: isUrgent
                  ? const Color(0xFFFF3333) // Flashing red urgency under 10s
                  : const Color(0xFFFFE000), // Iconic GamePigeon amber
              offColor: isUrgent
                  ? const Color(0x283A0505)
                  : const Color(0x22352E04),
            );
          },
        ),
      ),
    );
  }

  /// Flanking circular avatar with green background and "You" label.
  Widget _buildPlayerAvatar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🏀',
              style: TextStyle(fontSize: 18.0),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        const Text(
          'You',
          style: TextStyle(
            color: Color(0xFF4ADE80),
            fontSize: 10.0,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4.0),
            ],
          ),
        ),
      ],
    );
  }

  /// Flanking help pill on the right side.
  Widget _buildHelpBadge() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onHelpTapped,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          width: 34.0,
          height: 34.0,
          decoration: BoxDecoration(
            color: const Color(0xDDFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0x66FFFFFF),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the iconic GamePigeon trapezoidal matte black chassis.
/// The top edge is wider, and the sides angle subtly inwards towards the bottom.
class TrapezoidScoreboardPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double slopeInset;

  const TrapezoidScoreboardPainter({
    this.fillColor = const Color(0xFF0C0C0E),
    this.borderColor = Colors.white,
    this.borderWidth = 2.4,
    this.slopeInset = 11.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inx = slopeInset;
    const r = 5.0; // Subtle corner bevel

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w - 1.2, r)
      ..lineTo(w - inx + 1.2, h - r)
      ..quadraticBezierTo(w - inx, h, w - inx - r, h)
      ..lineTo(inx + r, h)
      ..quadraticBezierTo(inx, h, inx - 1.2, h - r)
      ..lineTo(1.2, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    // 1. Matte black drop shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.6), 8.0, true);

    // 2. Matte black fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Crisp white contour stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TrapezoidScoreboardPainter oldDelegate) => false;
}
