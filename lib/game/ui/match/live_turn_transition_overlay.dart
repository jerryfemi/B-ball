import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/audio_engine.dart';

/// Configuration payload for an active live turn transition countdown.
class LiveTransitionData {
  final bool isMyTurnNow;
  final String opponentName;
  final int currentRound;
  final int totalRounds;
  final VoidCallback onFinished;

  const LiveTransitionData({
    required this.isMyTurnNow,
    required this.opponentName,
    required this.currentRound,
    required this.totalRounds,
    required this.onFinished,
  });
}

/// Animated full-screen interstitial banner displaying a dramatic
/// countdown between turns (e.g., "3... 2... 1... YOUR TURN!").
class LiveTurnTransitionOverlay extends StatefulWidget {
  final bool isMyTurnNow;
  final String opponentName;
  final int currentRound;
  final int totalRounds;
  final VoidCallback onFinished;

  const LiveTurnTransitionOverlay({
    super.key,
    required this.isMyTurnNow,
    required this.opponentName,
    required this.currentRound,
    required this.totalRounds,
    required this.onFinished,
  });

  @override
  State<LiveTurnTransitionOverlay> createState() =>
      _LiveTurnTransitionOverlayState();
}

class _LiveTurnTransitionOverlayState extends State<LiveTurnTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _pulseGlowAnimation;
  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _pulseGlowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _animController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    HapticFeedback.mediumImpact();
    AudioEngine.playFloorBounce(6.0);

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        _animController.forward(from: 0.0);
        HapticFeedback.mediumImpact();
        AudioEngine.playFloorBounce(7.0);
      } else if (_countdown == 1) {
        setState(() {
          _countdown = 0; // GO / SHOOT!
        });
        _animController.forward(from: 0.0);
        HapticFeedback.heavyImpact();
        AudioEngine.playSwish();
      } else {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShooter = widget.isMyTurnNow;
    final accentColor = isShooter ? const Color(0xFF00FFCC) : const Color(0xFF38BDF8);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              accentColor.withValues(alpha: 0.22),
              const Color(0xEC090D16),
              const Color(0xF8030712),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Round Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'ROUND ${widget.currentRound} OF ${widget.totalRounds}',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // Main Role Title
                Text(
                  isShooter ? 'YOUR TURN TO SHOOT!' : 'WATCHING ${widget.opponentName.toUpperCase()} LIVE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 26.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 16.0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6.0),

                // Subtitle
                Text(
                  isShooter
                      ? 'Sink buckets to climb the scoreboard!'
                      : 'Take your courtside seat & send reactions!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 36.0),

                // Countdown Pulsing Circle
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _pulseGlowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 100.0,
                        height: 100.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xCC0F172A),
                          border: Border.all(
                            color: accentColor,
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(
                                alpha: 0.40 * _pulseGlowAnimation.value,
                              ),
                              blurRadius: 18.0,
                              spreadRadius: 3.0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: Text(
                      _countdown > 0 ? '$_countdown' : (isShooter ? 'GO!' : 'LIVE'),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: _countdown > 0 ? 44.0 : 26.0,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
