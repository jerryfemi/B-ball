import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'floating_score_toast.dart';
import 'game_over_overlay.dart';
import 'game_rules_dialog.dart';
import 'pause_overlay.dart';
import 'stadium_scoreboard.dart';

/// Top-level Game HUD Overlay mounted via Flame's [GameWidget.overlayBuilderMap].
///
/// Combines:
/// 1. Authentic GamePigeon 3-Bay Electronic LED Scoreboard Header with Pause & Mute controls
/// 2. Interactive rules "?" button with auto-pause synchronization
/// 3. In-flight floating score toast spawner (+3 SWISH!, +3 BANK SHOT!, +2 PTS)
/// 4. Ready-to-shoot tutorial prompt during [GameModeState.ready]
/// 5. Frosted obsidian glass Pause Overlay during active pauses
/// 6. 60-second buzzer-beater Game Over recap modal with shooting statistics
class GameHudOverlay extends StatelessWidget {
  final BasketballGame game;

  const GameHudOverlay({
    super.key,
    required this.game,
  });

  Future<void> _handleHelpTapped(BuildContext context) async {
    final wasPlaying = game.gameStateNotifier.value == GameModeState.playing;
    if (wasPlaying) {
      game.pauseGame(manual: true);
    }
    await showGameRulesDialog(context);
    if (wasPlaying && game.isPaused) {
      game.resumeGame();
    }
  }

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
            onHelpTapped: () => _handleHelpTapped(context),
          ),
        ),

        // 2. Start-on-First-Shot Guidance Prompt (Visible during GameModeState.ready)
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.14,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<GameModeState>(
            valueListenable: game.gameStateNotifier,
            builder: (context, state, _) {
              if (state == GameModeState.ready) {
                return Center(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 7.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0B111E),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: const Color(0x4438BDF8),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 10.0,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 15.0,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 6.0),
                          Text(
                            'SWIPE TO SHOOT • FIRST SHOT STARTS CLOCK',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),

        // 3. Floating Score Toast Spawner (Centered around hoop plane, non-blocking)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.28,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: true,
            child: FloatingScoreToastSystem(game: game),
          ),
        ),

        // 4. Pause Overlay (Displayed when game is paused and not gameOver)
        ValueListenableBuilder<bool>(
          valueListenable: game.isPausedNotifier,
          builder: (context, isPaused, _) {
            if (isPaused &&
                game.gameStateNotifier.value != GameModeState.gameOver) {
              return PauseOverlay(game: game);
            }
            return const SizedBox.shrink();
          },
        ),

        // 5. Game Over Recap Overlay (Only visible when 60s expires)
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
}
