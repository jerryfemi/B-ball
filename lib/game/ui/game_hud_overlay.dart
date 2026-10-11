import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_match_service.dart';
import '../basketball_game.dart';
import '../match/match_session.dart';
import 'floating_score_toast.dart';
import 'game_over_overlay.dart';
import 'game_rules_dialog.dart';
import 'inbox/match_inbox_sheet.dart';
import 'match/match_setup_dialog.dart';
import 'match/match_winner_podium_overlay.dart';
import 'match/round_intermission_overlay.dart';
import 'pause_overlay.dart';
import 'replay_hud_overlay.dart';
import 'stadium_scoreboard.dart';

/// Top-level Game HUD Overlay mounted via Flame's [GameWidget.overlayBuilderMap].
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

  Future<void> _handleInboxTapped(BuildContext context) async {
    final wasPlaying = game.gameStateNotifier.value == GameModeState.playing;
    if (wasPlaying) {
      game.pauseGame(manual: true);
    }
    await MatchInboxSheet.show(
      context,
      onPlayMatch: (match) {
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        game.startCloudMatch(match, myUid);
      },
      onCreateMatch: () async {
        final config = await MatchSetupDialog.show(
          context,
          initialConfig: game.currentMatchConfig,
        );
        if (config != null) {
          final user = await AuthService.instance.ensureAuthenticated();
          final profile = AuthService.instance.currentUser ??
              UserProfile(
                uid: user.uid,
                displayName: user.displayName ?? 'Player',
                avatarEmoji: '🏀',
              );
          final newMatch = await FirestoreMatchService.instance.createMatch(
            config: config,
            player1Profile: profile,
          );
          game.startCloudMatch(newMatch, profile.uid);
        }
      },
      onViewPodium: (match) {
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        final session = MatchSession.fromCloudMatch(match, myUid);
        session.phase = MatchTurnPhase.matchComplete;
        game.matchSessionNotifier.value = session;
        game.gameStateNotifier.value = GameModeState.gameOver;
      },
    );
    if (wasPlaying && game.isPaused) {
      game.resumeGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Top Stadium Scoreboard Header with integrated controls & match hub
        Align(
          alignment: Alignment.topCenter,
          child: StadiumScoreboard(
            game: game,
            onHelpTapped: () => _handleHelpTapped(context),
            onInboxTapped: () => _handleInboxTapped(context),
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

        // 3. Pause Overlay (Displayed when game is paused and not gameOver)
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

        // 4. Game Over / Match Intermission / Match Winner Podium Overlays
        ValueListenableBuilder<GameModeState>(
          valueListenable: game.gameStateNotifier,
          builder: (context, state, _) {
            if (state == GameModeState.gameOver) {
              return ValueListenableBuilder<MatchSession?>(
                valueListenable: game.matchSessionNotifier,
                builder: (context, session, _) {
                  if (session != null) {
                    if (session.phase == MatchTurnPhase.matchComplete) {
                      return MatchWinnerPodiumOverlay(
                        game: game,
                        session: session,
                      );
                    } else if (session.phase == MatchTurnPhase.turnComplete) {
                      return RoundIntermissionOverlay(
                        game: game,
                        session: session,
                      );
                    }
                  }
                  return GameOverOverlay(game: game);
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // 5. Replay HUD Overlay (Displayed when watching replay mode)
        ValueListenableBuilder<GameModeState>(
          valueListenable: game.gameStateNotifier,
          builder: (context, state, _) {
            if (state == GameModeState.replay) {
              return ReplayHudOverlay(game: game);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
