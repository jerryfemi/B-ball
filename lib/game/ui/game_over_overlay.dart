import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'game_over/game_over_header.dart';
import 'game_over/game_over_stats_grid.dart';
import 'game_over/play_again_button.dart';
import 'game_over/see_replay_button.dart';
import 'match/match_setup_dialog.dart';

/// Celebratory Game Over recap modal shown when the 60-second round clock expires.
///
/// Orchestrates:
/// 1. Frosted obsidian glass modal container with metallic border
/// 2. Smooth entrance scale and fade animations
/// 3. [GameOverHeader]: Accolades and big final score numerals
/// 4. [GameOverStatsGrid]: 2x2 field goal accuracy and bonus counts
/// 5. [PlayAgainButton]: Interactive restart trigger
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
                            Color(0xF00F172A),
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
                          GameOverHeader(stats: stats),
                          const SizedBox(height: 22.0),
                          GameOverStatsGrid(stats: stats),
                          const SizedBox(height: 20.0),
                          if (widget.game.lastRoundTelemetry != null &&
                              widget.game.lastRoundTelemetry!.shots.isNotEmpty) ...[
                            SeeReplayButton(
                              onPressed: () => widget.game.startReplayMode(),
                            ),
                            const SizedBox(height: 10.0),
                          ],
                          PlayAgainButton(
                            onPressed: () => widget.game.exitToSoloMode(),
                          ),
                          const SizedBox(height: 10.0),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                final config = await MatchSetupDialog.show(
                                  context,
                                  initialConfig: widget.game.currentMatchConfig,
                                );
                                if (config != null) {
                                  widget.game.startPassAndPlayMatch(config: config);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0x180284C7),
                                foregroundColor: const Color(0xFF38BDF8),
                                side: const BorderSide(
                                  color: Color(0x6638BDF8),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.sports_basketball_rounded, size: 20.0),
                                  SizedBox(width: 8.0),
                                  Text(
                                    '1V1 PASS & PLAY MATCH',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  SizedBox(width: 6.0),
                                  Icon(Icons.tune_rounded, size: 16.0),
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
