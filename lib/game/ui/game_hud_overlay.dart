import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'floating_score_toast.dart';
import 'game_over_overlay.dart';
import 'stadium_scoreboard.dart';

/// Top-level Game HUD Overlay mounted via Flame's [GameWidget.overlayBuilderMap].
///
/// Combines:
/// 1. Authentic GamePigeon 3-Bay Electronic LED Scoreboard Header
/// 2. Interactive rules "?" button with collegiate dialog
/// 3. In-flight floating score toast spawner (+3 SWISH!, +3 BANK SHOT!, +2 PTS)
/// 4. 60-second buzzer-beater Game Over recap modal with shooting statistics
class GameHudOverlay extends StatelessWidget {
  final BasketballGame game;

  const GameHudOverlay({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Top Stadium Scoreboard Header
        Align(
          alignment: Alignment.topCenter,
          child: StadiumScoreboard(
            game: game,
            onHelpTapped: () => _showRulesDialog(context),
          ),
        ),

        // 2. Floating Score Toast Spawner (Centered around hoop plane, non-blocking)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.28,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: true,
            child: FloatingScoreToastSystem(game: game),
          ),
        ),

        // 3. Game Over Recap Overlay (Only visible when 60s expires)
        ValueListenableBuilder<GameModeState>(
          valueListenable: game.gameStateNotifier,
          builder: (context, state, _) {
            if (state == GameModeState.gameOver) {
              return GameOverOverlay(game: game);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF20F172A),
                      Color(0xFA090D16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: const Color(0x38FFFFFF),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 28.0,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'HOW TO PLAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    const _RuleRow(
                      icon: '🏀',
                      title: 'Flick to Shoot',
                      desc:
                          'Swipe up with finger speed and angle towards the hoop.',
                    ),
                    const SizedBox(height: 12.0),
                    const _RuleRow(
                      icon: '⏱️',
                      title: '60s Buzzer Beater',
                      desc:
                          'Score as many points as you can before time expires.',
                    ),
                    const SizedBox(height: 12.0),
                    const _RuleRow(
                      icon: '🔥',
                      title: 'Swish (+3 PTS)',
                      desc:
                          'Clean shot through the net without hitting rim or backboard.',
                    ),
                    const SizedBox(height: 12.0),
                    const _RuleRow(
                      icon: '🎯',
                      title: 'Bank Shot (+3 PTS)',
                      desc:
                          'Rebound the ball off the regulation tempered glass target box.',
                    ),
                    const SizedBox(height: 12.0),
                    const _RuleRow(
                      icon: '⚡',
                      title: 'Streak Multiplier',
                      desc:
                          'Sink 3+ in a row to earn +1 extra bonus point per consecutive basket!',
                    ),
                    const SizedBox(height: 22.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                        ),
                        child: const Text(
                          'GOT IT',
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
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
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;

  const _RuleRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18.0)),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
