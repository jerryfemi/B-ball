import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';

/// Celebratory Game Over recap modal shown when the 60-second round clock expires.
///
/// Displays:
/// - Final score with "NEW RECORD 🏆" accolade if personal best is broken
/// - Shot accuracy percentage and field goals (makes / attempts)
/// - Swishes and Bank Shots count
/// - Longest streak reached
/// - Tactile "PLAY AGAIN" button to restart the round immediately
class GameOverOverlay extends StatefulWidget {
  final BasketballGame game;

  const GameOverOverlay({
    super.key,
    required this.game,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameRoundStats?>(
      valueListenable: widget.game.statsNotifier,
      builder: (context, stats, _) {
        if (stats == null) return const SizedBox.shrink();

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                constraints: const BoxConstraints(maxWidth: 380.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 28.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF00F172A), // Deep translucent obsidian navy
                            Color(0xFA090D16),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28.0),
                        border: Border.all(
                          color: stats.isNewRecord
                              ? const Color(0xFFFFD700).withValues(alpha: 0.70)
                              : const Color(0x38FFFFFF),
                          width: stats.isNewRecord ? 2.0 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: stats.isNewRecord
                                ? const Color(0x55EAB308)
                                : const Color(0x66000000),
                            blurRadius: 32.0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Header & Accolade
                          if (stats.isNewRecord) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 5.0,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFD97706),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20.0),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66F59E0B),
                                    blurRadius: 10.0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🏆', style: TextStyle(fontSize: 14.0)),
                                  SizedBox(width: 6.0),
                                  Text(
                                    'NEW HIGH SCORE!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12.0),
                          ] else ...[
                            const Text(
                              "TIME'S UP!",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                          ],

                          // 2. Giant Final Score
                          Text(
                            '${stats.score}',
                            style: TextStyle(
                              color: stats.isNewRecord
                                  ? const Color(0xFFFFD700)
                                  : Colors.white,
                              fontSize: 64.0,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          const Text(
                            'POINTS',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),

                          const SizedBox(height: 22.0),

                          // 3. Stat Grid
                          Container(
                            padding: const EdgeInsets.all(14.0),
                            decoration: BoxDecoration(
                              color: const Color(0x40020617),
                              borderRadius: BorderRadius.circular(18.0),
                              border: Border.all(
                                color: const Color(0x20FFFFFF),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatTile(
                                        label: 'FIELD GOALS',
                                        value:
                                            '${stats.madeShots}/${stats.totalShots}',
                                        subtitle:
                                            '${stats.accuracy.toStringAsFixed(0)}% ACC',
                                      ),
                                    ),
                                    Container(
                                      width: 1.0,
                                      height: 38.0,
                                      color: const Color(0x20FFFFFF),
                                    ),
                                    Expanded(
                                      child: _StatTile(
                                        label: 'BEST STREAK',
                                        value: '⚡ x${stats.bestStreak}',
                                        subtitle: stats.bestStreak >= 3
                                            ? 'ON FIRE'
                                            : 'IN A ROW',
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Color(0x20FFFFFF),
                                  height: 20.0,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatTile(
                                        label: 'SWISHES (+3)',
                                        value: '🔥 ${stats.swishCount}',
                                        subtitle: 'CLEAN NET',
                                      ),
                                    ),
                                    Container(
                                      width: 1.0,
                                      height: 38.0,
                                      color: const Color(0x20FFFFFF),
                                    ),
                                    Expanded(
                                      child: _StatTile(
                                        label: 'BANK SHOTS (+3)',
                                        value: '🎯 ${stats.bankCount}',
                                        subtitle: 'OFF GLASS',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24.0),

                          // 4. Play Again Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                widget.game.restartRound();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                foregroundColor: Colors.white,
                                elevation: 8.0,
                                shadowColor:
                                    const Color(0xFF22C55E).withValues(alpha: 0.5),
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.replay_rounded,
                                    size: 22.0,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8.0),
                                  Text(
                                    'PLAY AGAIN',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _StatTile({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1.0),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
