import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../game/match/match_config.dart';
import '../game/ui/common/clean_ui.dart';
import '../game/ui/common/lobby_pill.dart';
import '../game/ui/match/match_lobby_dialog.dart';
import '../game/ui/match/match_setup_dialog.dart';
import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../models/player_descriptor.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import 'audio/darts_audio.dart';
import 'darts_constants.dart';
import 'darts_game.dart';
import 'state/darts_match_notifier.dart';
import 'state/darts_players.dart';
import 'state/darts_rules.dart';
import 'ui/darts_hud.dart';
import 'ui/darts_pause_menu.dart';
import 'ui/darts_result_card.dart';
import 'ui/darts_tour.dart';
import 'ui/darts_turn_banner.dart';

/// Full-screen Darts 301: solo vs bot (`/darts`), or live online 1v1 (`/match/:id`).
///
/// Implements DARTS_PLAN.md Step 15:
/// - Riverpod state setup and lifecycle cleanup.
/// - Apple Design frosted glass overlays and gesture tracking.
/// - Integrated how-to-play tour, pause menu, and match results.
class DartsGameScreen extends HookConsumerWidget {
  final CloudMatch? match;

  const DartsGameScreen({super.key, this.match});

  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = useState<DartsGame?>(null);
    final paused = useState(false);
    final showTour = useState(false);
    final audioOwner = useRef<Object?>(null);

    final bool isOnline = match != null;

    // Set up game and match state after first frame (prevent state modification during build)
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;

        final m = match;
        UserProfile? me = _firebaseReady ? AuthService.instance.currentUser : null;
        if (m != null && me == null && _firebaseReady) {
          try {
            me = await AuthService.instance.initialize();
          } catch (_) {}
          if (!context.mounted) return;
        }

        final notifier = ref.read(dartsMatchProvider.notifier);
        final players = ref.read(dartsPlayersProvider.notifier);

        if (m != null && me != null && m.isParticipant(me.uid)) {
          // Online match setup
          final mine = m.myPlayer(me.uid);
          final theirs = m.opponentPlayer(me.uid);

          players.set(DartsPlayers(
            you: DartsPlayer(
              name: mine?.displayName ?? me.displayName,
              avatar: mine?.avatarEmoji ?? me.avatarEmoji,
            ),
            opponent: theirs == null
                ? const DartsPlayer(name: 'Opponent', avatar: '⏳')
                : DartsPlayer(
                    name: theirs.displayName,
                    avatar: theirs.avatarEmoji,
                  ),
          ));

          notifier.startOnline(
            seed: DartsRules.seedFromMatchId(m.id),
            joinCode: m.joinCode,
          );
        } else {
          // Solo play setup
          notifier.restartMatch();
          players.set(DartsPlayers(
            you: me == null
                ? DartsPlayers.defaultYou
                : DartsPlayer(name: me.displayName, avatar: me.avatarEmoji),
            opponent: DartsPlayers.bot,
          ));
        }

        final created = DartsGame(events: notifier);
        audioOwner.value = created;
        game.value = created;
      });

      return () {
        final owner = audioOwner.value;
        if (owner != null) DartsAudio.leave(owner);
      };
    }, const []);

    // Tour display check on solo open
    useEffect(() {
      if (!isOnline) {
        DartsTour.shouldShow().then((show) {
          if (!context.mounted) return;
          if (show) showTour.value = true;
        });
      }
      return null;
    }, [isOnline]);

    void leaveScreen() {
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/');
      }
    }

    Future<void> goToLobbyAsync() async {
      final g = game.value;
      if (g != null && isOnline && match != null) {
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        final opp = match!.opponentPlayer(myUid);
        final bool? leave = await CleanUi.show<bool>(
          context,
          (c) => CleanDialog(
            title: 'LEAVE MATCH?',
            subtitle: "You'll forfeit and ${opp?.displayName ?? 'your opponent'} wins.",
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CleanButton(
                  label: 'LEAVE AND FORFEIT',
                  primary: true,
                  accent: const Color(DartsK.accentRed),
                  onTap: () => Navigator.of(c).pop(true),
                ),
                const SizedBox(height: 10.0),
                CleanButton(
                  label: 'KEEP PLAYING',
                  onTap: () => Navigator.of(c).pop(false),
                ),
              ],
            ),
          ),
        );
        if (leave != true || !context.mounted) return;
        await FirestoreMatchService.instance.forfeitMatch(
          matchId: match!.id,
          forfeiterUid: myUid,
          winnerUid: opp?.uid ?? '',
        );
        if (!context.mounted) return;
      }
      leaveScreen();
    }

    void openPause() {
      final g = game.value;
      if (g == null || paused.value) return;
      g.flickController.onPointerCancel();
      if (!isOnline) g.pauseEngine();
      paused.value = true;
    }

    void resume() {
      final g = game.value;
      if (g == null) return;
      if (!isOnline) g.resumeEngine();
      paused.value = false;
    }

    final g = game.value;

    return Scaffold(
      backgroundColor: const Color(DartsK.surfaceDark),
      body: SafeArea(
        child: g == null
            ? const Center(
                child: SizedBox(
                  width: 36.0,
                  height: 36.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(DartsK.accentP1),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Flame Game Canvas with Direct Touch Tracking
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      DartsAudio.unlock();
                      g.onPointerDown(
                        event.pointer,
                        event.localPosition.dx,
                        event.localPosition.dy,
                      );
                    },
                    onPointerMove: (event) {
                      g.onPointerMove(
                        event.pointer,
                        event.localPosition.dx,
                        event.localPosition.dy,
                      );
                    },
                    onPointerUp: (event) {
                      DartsAudio.unlock();
                      g.onPointerUp(event.pointer);
                    },
                    onPointerCancel: (_) => g.onPointerCancel(),
                    child: GameWidget(game: g),
                  ),

                  // 2. Translucent Glass HUD (Remaining scores, Round, Darts Left, Pause Button)
                  DartsHud(onOpenPause: openPause),

                  // 3. Quick Lobby Navigation Pill under Top Bar
                  Positioned(
                    top: 56.0,
                    left: 16.0,
                    child: LobbyPill(onTap: goToLobbyAsync),
                  ),

                  // 4. Turn Banner Overlay (YOUR TURN / BOT'S TURN / LAST CHANCE)
                  const Positioned.fill(
                    child: DartsTurnBanner(),
                  ),

                  // 5. Match Result Card (Victory / Defeat / Draw with Rematch)
                  Positioned.fill(
                    child: DartsResultCard(
                      onRematch: () => g.restartGame(),
                      onPlayFriend: () => DartsChallenge.start(context),
                    ),
                  ),

                  // 6. How-to-play Guided Walkthrough Tour
                  if (showTour.value && !isOnline)
                    Positioned.fill(
                      child: DartsTour(
                        onDone: () => showTour.value = false,
                      ),
                    ),

                  // 7. Frosted Glass Pause Menu Sheet
                  if (paused.value)
                    Positioned.fill(
                      child: DartsPauseMenu(
                        online: isOnline,
                        onResume: resume,
                        onHowToPlay: () {
                          paused.value = false;
                          showTour.value = true;
                        },
                        onRestart: isOnline
                            ? null
                            : () {
                                resume();
                                g.restartGame();
                              },
                        onLobby: () {
                          paused.value = false;
                          goToLobbyAsync();
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Orchestrates online Darts match creation, friend challenges, and rematches.
abstract final class DartsChallenge {
  static const MatchConfig config = MatchConfig(
    game: 'darts',
    totalRounds: DartsRules.maxRounds,
    roundDurationSeconds: DartsRules.onlineTurnSeconds,
  );

  static Future<void> start(
    BuildContext context, {
    bool showGamePicker = false,
  }) async {
    final chosen = await MatchSetupDialog.show(
      context,
      initialConfig: config,
      showGamePicker: showGamePicker,
    );
    if (chosen == null || !context.mounted) return;

    final joined = chosen.joinedMatch;
    if (joined != null) {
      GoRouter.maybeOf(context)?.go('/match/${joined.id}');
      return;
    }

    await _createAndEnter(context, chosen);
  }

  static Future<void> rematch(
    BuildContext context, {
    required CloudMatch finished,
    required String myUid,
  }) async {
    final opp = finished.opponentPlayer(myUid);
    if (opp == null || opp.uid.isEmpty) {
      await start(context);
      return;
    }
    final friend = FriendProfile(
      uid: opp.uid,
      displayName: opp.displayName,
      avatarEmoji: opp.avatarEmoji,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final profile = await _me();
    final cfg = config.copyWith(
      player1Name: profile.displayName,
      player1Avatar: profile.avatarEmoji,
      player2Name: opp.displayName,
      player2Avatar: opp.avatarEmoji,
      player2Uid: opp.uid,
      opponentFriend: friend,
    );

    final result = await FirestoreMatchService.instance.createOrJoinRematch(
      finishedMatchId: finished.id,
      config: cfg,
      me: profile,
    );
    if (!context.mounted) return;
    if (result.joined) {
      GoRouter.maybeOf(context)?.go('/match/${result.match.id}');
      return;
    }
    await _createAndEnter(context, cfg.copyWith(precreatedMatch: result.match));
  }

  static Future<UserProfile> _me() async {
    final user = await AuthService.instance.ensureAuthenticated();
    return AuthService.instance.currentUser ??
        UserProfile(
          uid: user.uid,
          displayName: user.displayName ?? 'Player',
          avatarEmoji: PlayerDescriptor.defaultAvatar,
        );
  }

  static Future<void> _createAndEnter(
    BuildContext context,
    MatchConfig chosen,
  ) async {
    final profile = await _me();
    final CloudMatch match = chosen.precreatedMatch ??
        await FirestoreMatchService.instance.createMatch(
          config: chosen.copyWith(
            player1Name: profile.displayName,
            player1Avatar: profile.avatarEmoji,
          ),
          player1Profile: profile,
        );
    if (!context.mounted) return;

    void enter(CloudMatch m) {
      if (context.mounted) GoRouter.maybeOf(context)?.go('/match/${m.id}');
    }

    await MatchLobbyDialog.show(
      context: context,
      match: match,
      challengedFriend: chosen.opponentFriend,
      onPlaySoloWhileWaiting: () => enter(match),
      onEnterArena: enter,
    );
  }
}
