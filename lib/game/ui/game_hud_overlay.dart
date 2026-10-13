import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/player_descriptor.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_match_service.dart';
import '../basketball_game.dart';
import '../match/match_session.dart';
import '../../services/update/update_service.dart';
import 'common/app_avatar.dart';
import 'common/app_colors.dart';
import 'common/update_available_banner.dart';
import 'floating_score_toast.dart';
import 'game_over_overlay.dart';
import 'game_rules_dialog.dart';
import 'match/incoming_challenge_dialog.dart';
import 'match/match_lobby_dialog.dart';
import 'match/match_setup_dialog.dart';
import 'match/match_winner_podium_overlay.dart';
import 'match/round_intermission_overlay.dart';
import 'pause_overlay.dart';
import 'replay_hud_overlay.dart';
import 'inbox/match_inbox_sheet.dart';
import 'stadium_scoreboard.dart';
import 'tour/onboarding_tour_overlay.dart';
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
        if (config != null && context.mounted) {
          final user = await AuthService.instance.ensureAuthenticated();
          final profile =
              AuthService.instance.currentUser ??
              UserProfile(
                uid: user.uid,
                displayName: user.displayName ?? 'Player',
                avatarEmoji: PlayerDescriptor.defaultAvatar,
              );
          final newMatch = config.precreatedMatch ??
              await FirestoreMatchService.instance.createMatch(
                config: config,
                player1Profile: profile,
              );

          if (context.mounted) {
            MatchLobbyDialog.show(
              context: context,
              match: newMatch,
              challengedFriend: config.opponentFriend,
              onPlaySoloWhileWaiting: () {
                game.startCloudMatch(newMatch, profile.uid);
              },
              onEnterArena: (confirmedMatch) {
                game.startCloudMatch(confirmedMatch, profile.uid);
              },
            );
          }
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

        // 1c. Incoming 1v1 Challenge Notification Pill
        Consumer(
          builder: (context, ref, _) {
            final challenges =
                ref.watch(incomingMatchChallengesProvider).value ?? const [];
            if (challenges.isEmpty) return const SizedBox.shrink();
            final topChallenge = challenges.first;

            return Positioned(
              top: MediaQuery.of(context).padding.top + 74.0,
              left: 16.0,
              right: 16.0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final wasPlaying =
                          game.gameStateNotifier.value == GameModeState.playing;
                      if (wasPlaying) game.pauseGame(manual: true);

                      IncomingChallengeDialog.show(
                        context: context,
                        invite: topChallenge,
                        onAccepted: (joinedMatch) {
                          final myUid =
                              AuthService.instance.currentUser?.uid ?? '';
                          game.startCloudMatch(joinedMatch, myUid);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(20.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTile,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: AppColors.accentNeonCyan,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentNeonCyan.withValues(alpha: 0.2),
                            blurRadius: 12.0,
                            spreadRadius: 1.0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppAvatar(
                            avatar: topChallenge.hostAvatar,
                            size: 26.0,
                            borderColor: AppColors.accentNeonCyan,
                            borderWidth: 1.0,
                          ),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '⚔️ ${topChallenge.hostName} challenged you to 1v1!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 3.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentNeonCyan,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: const Text(
                              'ACCEPT ➔',
                              style: TextStyle(
                                color: AppColors.buttonDarkText,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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

        // 6. First-Launch / Replay Onboarding Tour Overlay
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
