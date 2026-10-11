import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';

/// Minimalist Floating Stadium Glass Pills (GamePigeon / Modern iOS Style).
///
/// Replaces the bulky full-width header with dual content-hugging frosted capsules:
/// 1. Sleek Score Pill: compact frosted acrylic badge with bouncy score numerals.
/// 2. Dynamic Streak Pill: luminous flame badge that slides in alongside when streak >= 3.
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

    // Punchy spring pop on score increase
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.30)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.30, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
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
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── 1. Compact Frosted Glass Score Pill ──
            ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 7.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xB80F172A), // Deep translucent obsidian slate
                        Color(0x991E293B),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: const Color(0x38FFFFFF),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 16.0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        alignment: Alignment.center,
                        child: ValueListenableBuilder<int>(
                          valueListenable: widget.game.scoreNotifier,
                          builder: (context, score, _) {
                            return Text(
                              '$score',
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 24.0,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -0.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Dynamic Luminous Streak Fire Pill ──
            ValueListenableBuilder<int>(
              valueListenable: widget.game.streakNotifier,
              builder: (context, streak, _) {
                final bool isHot = streak >= 3;

                return AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: isHot
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24.0),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 12.0,
                                sigmaY: 12.0,
                              ),
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
                                      Color(0xFFEA580C), // Radiant flame amber
                                      Color(0xFFDC2626), // Searing crimson
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24.0),
                                  border: Border.all(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.70),
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
                                      style: TextStyle(fontSize: 15.0),
                                    ),
                                    const SizedBox(width: 5.0),
                                    Text(
                                      'x$streak',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                        letterSpacing: 0.5,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
}
