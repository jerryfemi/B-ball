import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'floating_score_toast.dart';
import 'stadium_scoreboard.dart';

/// Top-level Game HUD Overlay mounted via Flame's [GameWidget.overlayBuilderMap].
///
/// Features:
/// - Collegiate frosted-glass stadium scoreboard header
/// - Live streak fire badge on streaks of 3 or more
/// - Celebratory floating score toasts (+3 SWISH!, +3 BANK SHOT!, +2 PTS)
///
/// Wrapped in [IgnorePointer] so all touch events and mouse flicks pass through
/// uninterrupted to the Flame 3D physics canvas.
class GameHudOverlay extends StatelessWidget {
  final BasketballGame game;

  const GameHudOverlay({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Top Stadium Scoreboard Header
          Align(
            alignment: Alignment.topCenter,
            child: StadiumScoreboard(game: game),
          ),

          // 2. Floating Score Toast Spawner (Centered around hoop plane)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            child: FloatingScoreToastSystem(game: game),
          ),
        ],
      ),
    );
  }
}
