import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';

/// Collegiate Stadium Scoreboard Header with frosted acrylic glassmorphism,
/// spring pop-in score numerals, and dynamic streak fire badge.
class StadiumScoreboard extends StatefulWidget {
  final BasketballGame game;

  const StadiumScoreboard({
    super.key,
    required this.game,
  });

  @override
  State<StadiumScoreboard> createState() => _StadiumScoreboardState();
}

class _StadiumScoreboardState extends State<StadiumScoreboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _scaleAnimation;
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_popController);

    widget.game.scoreNotifier.addListener(_onScoreChanged);
    _lastScore = widget.game.scoreNotifier.value;
  }

  @override
  void didUpdateWidget(covariant StadiumScoreboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.scoreNotifier.removeListener(_onScoreChanged);
      widget.game.scoreNotifier.addListener(_onScoreChanged);
    }
  }

  @override
  void dispose() {
    widget.game.scoreNotifier.removeListener(_onScoreChanged);
    _popController.dispose();
    super.dispose();
  }

  void _onScoreChanged() {
    final current = widget.game.scoreNotifier.value;
    if (current > _lastScore) {
      _popController.forward(from: 0.0);
    }
    _lastScore = current;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xCC090D16),
                    const Color(0xB31E293B),
                  ],
                ),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: const Color(0x3394A3B8),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16.0,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Score Counter Box
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        alignment: Alignment.centerLeft,
                        child: ValueListenableBuilder<int>(
                          valueListenable: widget.game.scoreNotifier,
                          builder: (context, score, _) {
                            return Text(
                              '$score',
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 32.0,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -0.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  // 2. Streak Fire Badge Box
                  ValueListenableBuilder<int>(
                    valueListenable: widget.game.streakNotifier,
                    builder: (context, streak, _) {
                      final bool isHot = streak >= 3;

                      return AnimatedSlide(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        offset: isHot ? Offset.zero : const Offset(0.3, 0.0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHot ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 7.0,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFEA580C),
                                  Color(0xFFDC2626),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.60),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66EA580C),
                                  blurRadius: 14.0,
                                  spreadRadius: 2.0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 16.0),
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  'STREAK x$streak',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
