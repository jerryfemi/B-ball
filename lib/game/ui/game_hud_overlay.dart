import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../basketball_game.dart';
import '../match/match_session.dart';
import '../../services/update/update_service.dart';
import 'common/update_available_banner.dart';
import 'floating_score_toast.dart';
import 'game_over_overlay.dart';
import 'game_rules_dialog.dart';
import 'match/match_winner_podium_overlay.dart';
import 'match/round_intermission_overlay.dart';
import 'pause_overlay.dart';
import 'replay_hud_overlay.dart';
import 'inbox/match_inbox_sheet.dart';
import 'stadium_scoreboard.dart';
import 'tour/onboarding_tour_overlay.dart';
import '../../notifications/notice_stack.dart';
import '../../notifications/profile_drawer.dart';
import 'common/lobby_pill.dart';
import 'play_friend_button.dart';
import 'match/live_spectator_status_pill.dart';
import 'match/live_turn_transition_overlay.dart';
import 'reactions/live_floating_reactions_overlay.dart';

/// Top-level Game HUD Overlay mounted via Flame's [GameWidget.overlayBuilderMap].
class GameHudOverlay extends StatelessWidget {
  final BasketballGame game;

  const GameHudOverlay({super.key, required this.game});

  Future<void> _handleHelpTapped(BuildContext context) async {
    final wasPlaying = game.gameStateNotifier.value == GameModeState.playing;
    if (wasPlaying) {
      game.pauseGame(manual: true);
    }
    await showGameRulesDialog(context, game: game);
    if (wasPlaying && game.isPaused) {
      game.resumeGame();
    }
  }

  Future<void> _handleInboxTapped(BuildContext context) =>
      MatchInboxSheet.openWithGame(context, game: game);

  /// Your avatar opens the profile drawer: what's waiting, friends, matches.
  Future<void> _openDrawer(BuildContext context) => ProfileDrawer.show(
        context,
        onOpenMatch: (m) =>
            game.startCloudMatch(m, AuthService.instance.currentUser?.uid ?? ''),
        onOpenMatches: () => _handleInboxTapped(context),
        onPlayFriend: () => MatchInboxSheet.playAFriend(context, game: game),
        onHowToPlay: () => _handleHelpTapped(context),
      );

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
            onInboxTapped: () => _openDrawer(context),
          ),
        ),

        // 1b. Update Available Notification Pill (Positioned right below scoreboard header)
        Positioned(
          top: MediaQuery.of(context).padding.top + 72.0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: UpdateService.isUpdateAvailable,
            builder: (context, hasUpdate, _) {
              if (!hasUpdate) return const SizedBox.shrink();
              return const Center(child: UpdateAvailableBanner());
            },
          ),
        ),

        // 1c. Notifications from any game (invites, friend requests) at the
        //     top. In a live 1v1 they shrink to bubbles on the right edge.
        ValueListenableBuilder<MatchSession?>(
          valueListenable: game.matchSessionNotifier,
          builder: (context, session, _) {
            final bool live = session != null && session.isOnline;
            return Positioned(
              // Solo: below the Lobby pill and the people button.
              top: MediaQuery.of(context).padding.top + (live ? 62.0 : 112.0),
              left: 16.0,
              right: live ? 12.0 : 16.0,
              child: NoticeStack(
                live: live,
                onBeforeOpen: () {
                  if (game.gameStateNotifier.value == GameModeState.playing) {
                    game.pauseGame(manual: true);
                  }
                },
                onOpenMatch: (m) {
                  final myUid = AuthService.instance.currentUser?.uid ?? '';
                  game.startCloudMatch(m, myUid);
                },
              ),
            );
          },
        ),

        // 1d. Live Spectator Connection & Grace Guard Pill (mounted strictly during active 1v1 spectator phase)
        Positioned(
          top: MediaQuery.of(context).padding.top + 76.0,
          left: 16.0,
          right: 16.0,
          child: ValueListenableBuilder<MatchSession?>(
            valueListenable: game.matchSessionNotifier,
            builder: (context, session, _) {
              if (session == null ||
                  session.phase != MatchTurnPhase.watchingLiveOpponent) {
                return const SizedBox.shrink();
              }
              return LiveSpectatorStatusPill(game: game);
            },
          ),
        ),

        // 2. Floating Score Toasts: callouts pop beside the hoop (never over
        //    the rim); the streak-bonus chip stays under the scoreboard.
        //    Full-screen so the system can place each part itself.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: FloatingScoreToastSystem(game: game),
          ),
        ),

        // 3a. "‹ Lobby" top-left (solo only; hidden when paused, game over, replay, or tour is active)
        Positioned(
          top: MediaQuery.of(context).padding.top + 62.0,
          left: 12.0,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              game.matchSessionNotifier,
              game.isPausedNotifier,
              game.gameStateNotifier,
              game.isTourActiveNotifier,
            ]),
            builder: (context, _) {
              final isModalOrInactive = game.matchSessionNotifier.value != null ||
                  game.isPausedNotifier.value ||
                  game.gameStateNotifier.value == GameModeState.gameOver ||
                  game.gameStateNotifier.value == GameModeState.replay ||
                  game.isTourActiveNotifier.value;

              if (isModalOrInactive) return const SizedBox.shrink();

              return LobbyPill(
                onTap: () => GoRouter.maybeOf(context)?.go('/'),
              );
            },
          ),
        ),

        // 3b. "Play a friend" button under the sound button (solo only; hidden during modals)
        Positioned(
          top: MediaQuery.of(context).padding.top + 62.0,
          right: 12.0,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              game.matchSessionNotifier,
              game.isPausedNotifier,
              game.gameStateNotifier,
              game.isTourActiveNotifier,
            ]),
            builder: (context, _) {
              final isModalOrInactive = game.matchSessionNotifier.value != null ||
                  game.isPausedNotifier.value ||
                  game.gameStateNotifier.value == GameModeState.gameOver ||
                  game.gameStateNotifier.value == GameModeState.replay ||
                  game.isTourActiveNotifier.value;

              if (isModalOrInactive) return const SizedBox.shrink();

              return PlayFriendButton(
                key: game.playFriendKey,
                onTap: () => MatchInboxSheet.playAFriend(context, game: game),
              );
            },
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

        // 5. Game Over / Match Intermission / Match Winner Podium Overlays
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

        // 6. Replay HUD Overlay (Displayed when watching replay mode)
        ValueListenableBuilder<GameModeState>(
          valueListenable: game.gameStateNotifier,
          builder: (context, state, _) {
            if (state == GameModeState.replay) {
              return ReplayHudOverlay(game: game);
            }
            return const SizedBox.shrink();
          },
        ),

        // 7. First-Launch / Replay Onboarding Tour Overlay
        ValueListenableBuilder<bool>(
          valueListenable: game.isTourActiveNotifier,
          builder: (context, isTourActive, _) {
            if (isTourActive) {
              return OnboardingTourOverlay(game: game);
            }
            return const SizedBox.shrink();
          },
        ),

        // 7. Live Floating Reactions Overlay (Left-court track + spectator banter dock)
        LiveFloatingReactionsOverlay(game: game),

        // 8. Live Turn Transition Interstitial Overlay (3-2-1 countdown)
        ValueListenableBuilder<LiveTransitionData?>(
          valueListenable: game.liveTransitionNotifier,
          builder: (context, data, _) {
            if (data == null) return const SizedBox.shrink();
            return LiveTurnTransitionOverlay(
              isMyTurnNow: data.isMyTurnNow,
              opponentName: data.opponentName,
              currentRound: data.currentRound,
              totalRounds: data.totalRounds,
              onFinished: data.onFinished,
            );
          },
        ),
      ],
    );
  }
}
