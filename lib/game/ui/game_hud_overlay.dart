import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'floating_score_toast.dart';
import 'game_over_overlay.dart';
import 'game_rules_dialog.dart';
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
            onHelpTapped: () => showGameRulesDialog(context),
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
}
