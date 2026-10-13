import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../basketball_game.dart';

/// Interactive spotlight walkthrough overlay that guides new players
/// through key controls (Avatar profile hub, 1v1 chat, and shooting gesture).
class OnboardingTourOverlay extends StatefulWidget {
  final BasketballGame game;

  const OnboardingTourOverlay({super.key, required this.game});

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _ready = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wait for the scoreboard / HUD widgets to finish layout so that
    // GlobalKey.findRenderObject() returns accurate positions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _completeTour() async {
    HapticFeedback.mediumImpact();
    widget.game.isTourActiveNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('b_ball_has_seen_tour', true);
    } catch (_) {}
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _completeTour();
    }
  }

  void _prevStep() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Offset _getTargetCenter(Size size, double topPadding) {
    if (_currentStep == 0) {
      final ctx = widget.game.playerAvatarKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          return pos + Offset(box.size.width / 2.0, box.size.height / 2.0);
        }
      }
      return Offset(size.width * 0.15, topPadding + 42.0);
    } else if (_currentStep == 1) {
      final ctx = widget.game.rightFlankKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          return pos + Offset(box.size.width / 2.0, box.size.height / 2.0);
        }
      }
      return Offset(size.width * 0.85, topPadding + 42.0);
    } else {
      // Step 2: Basketball on court floor
      return Offset(
        size.width / 2.0,
        size.height - (size.height * 0.11).clamp(70.0, 95.0),
      );
    }
  }

  double _getTargetRadius(Size size) {
    if (_currentStep == 0) {
      final ctx = widget.game.playerAvatarKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          return (box.size.width / 2.0) + 4.0;
        }
      }
      return (size.width * 0.065).clamp(22.0, 30.0);
    } else if (_currentStep == 1) {
      final ctx = widget.game.rightFlankKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          return (box.size.width / 2.0) + 4.0;
        }
      }
      return (size.width * 0.065).clamp(22.0, 30.0);
    } else {
      return (size.width * 0.11).clamp(36.0, 48.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    // Don't render the spotlight until the layout pass is complete so
    // GlobalKey positions are accurate.
    if (!_ready) {
      return const ColoredBox(
        color: Color(0xD805070C),
        child: SizedBox.expand(),
      );
    }

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          final currentTarget = _getTargetCenter(size, topPadding);
          final currentRadius = _getTargetRadius(size);
          final pulse = _pulseAnimation.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Semi-transparent backdrop with spotlight cutout
              CustomPaint(
                size: size,
                painter: _SpotlightPainter(
                  target: currentTarget,
                  radius: currentRadius,
                  pulseScale: pulse,
                ),
              ),

              // 2. Animated Pulse Ring directly aligned with cutout
              Positioned(
                left: currentTarget.dx - (currentRadius * pulse),
                top: currentTarget.dy - (currentRadius * pulse),
                child: IgnorePointer(
                  child: Container(
                    width: currentRadius * 2.0 * pulse,
                    height: currentRadius * 2.0 * pulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x9938BDF8),
                        width: 2.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x6638BDF8),
                          blurRadius: 18.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Tooltip Card
              _buildTooltipCard(context, size, topPadding, currentTarget, currentRadius),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltipCard(
    BuildContext context,
    Size size,
    double topPadding,
    Offset currentTarget,
    double currentRadius,
  ) {
    final bool isBottomStep = _currentStep == 2;
    final topCardPos = (currentTarget.dy + currentRadius + 18.0).clamp(
      topPadding + 65.0,
      size.height - 240.0,
    );
    final bottomCardPos =
        ((size.height - currentTarget.dy) + currentRadius + 18.0).clamp(
      120.0,
      size.height - 240.0,
    );

    final stepsData = [
      _TourStepData(
        stepNumber: '1 OF 3',
        icon: '👤',
        title: 'YOUR PROFILE & FRIENDS',
        desc: 'Tap your avatar to open your Profile, Friends Hub, and active invites. It pulses when you have a notification',
      ),
      _TourStepData(
        stepNumber: '2 OF 3',
        icon: '💬',
        title: '1V1 MATCHES & CHAT',
        desc: 'Tap your opponent\'s avatar during 1v1 online showdowns to send live in-game messages!',
      ),
      _TourStepData(
        stepNumber: '3 OF 3',
        icon: '🏀',
        title: 'SWIPE UP TO SHOOT',
        desc: 'Flick from the court floor toward the hoop with finger speed and angle. Clean swishes and bank shots score 3 PTS!',
      ),
    ];

    final currentData = stepsData[_currentStep];

    return Positioned(
      left: 20.0,
      right: 20.0,
      top: isBottomStep ? null : topPadding + 88.0,
      bottom: isBottomStep ? 160.0 : null,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: const Color(0xF2090D16),
          borderRadius: BorderRadius.circular(22.0),
          border: Border.all(color: const Color(0x6638BDF8), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 28.0,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step badge + Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2238BDF8),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: const Color(0x5538BDF8),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    currentData.stepNumber,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Spacer(),
                Text(currentData.icon, style: const TextStyle(fontSize: 20.0)),
              ],
            ),
            const SizedBox(height: 10.0),

            // Title
            Text(
              currentData.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6.0),

            // Description
            Text(
              currentData.desc,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.0,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18.0),

            // Action row: Skip, Back, Next / Finish
            Row(
              children: [
                if (_currentStep < 2)
                  TextButton(
                    onPressed: _completeTour,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                if (_currentStep > 0 && _currentStep < 2)
                  TextButton(
                    onPressed: _prevStep,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == 2
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18.0,
                      vertical: 10.0,
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentStep == 2 ? "LET'S HOOP! 🏀" : 'NEXT',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (_currentStep < 2) ...[
                        const SizedBox(width: 4.0),
                        const Icon(Icons.arrow_forward_rounded, size: 14.0),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TourStepData {
  final String stepNumber;
  final String icon;
  final String title;
  final String desc;

  const _TourStepData({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.desc,
  });
}

class _SpotlightPainter extends CustomPainter {
  final Offset target;
  final double radius;
  final double pulseScale;

  const _SpotlightPainter({
    required this.target,
    required this.radius,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xD805070C);

    // Create a path covering the full screen, with a circle cut out at target
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final spotlightPath = Path()
      ..addOval(Rect.fromCircle(center: target, radius: radius * pulseScale));

    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      spotlightPath,
    );

    canvas.drawPath(combinedPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.target != target ||
        oldDelegate.radius != radius ||
        oldDelegate.pulseScale != pulseScale;
  }
}
