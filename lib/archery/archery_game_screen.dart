import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../game/match/match_config.dart';
import '../game/ui/match/match_lobby_dialog.dart';
import '../game/ui/match/match_setup_dialog.dart';
import '../models/cloud_match.dart';
import '../models/player_descriptor.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import 'archery_game.dart';
import 'audio/archery_audio.dart';
import 'online/archery_online_controller.dart';
import 'state/archery_match_notifier.dart';
import 'state/archery_players.dart';
import 'state/archery_rules.dart';
import 'ui/archery_hud.dart';
import 'ui/archery_match_bar.dart';
import 'ui/archery_pause_menu.dart';

/// Full-screen archery: solo against the bot (`/archery`), or a live online
/// match when [match] is given (`/match/:id`).
class ArcheryGameScreen extends HookConsumerWidget {
  final CloudMatch? match;

  const ArcheryGameScreen({super.key, this.match});

  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = useState<ArcheryGame?>(null);
    final paused = useState(false);
    final online = useRef<ArcheryOnlineController?>(null);
    // The game owns archery's music; kept here so dispose can release it.
    final audioOwner = useRef<Object?>(null);

    // Set the match up after the first frame: Riverpod state must not change
    // while widgets are building.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final m = match;
        // A refreshed /match/:id page may still be restoring the sign-in.
        UserProfile? me = _firebaseReady ? AuthService.instance.currentUser : null;
        if (m != null && me == null && _firebaseReady) {
          try {
            me = await AuthService.instance.initialize();
          } catch (_) {}
          if (!context.mounted) return;
        }
        final notifier = ref.read(archeryMatchProvider.notifier);
        final players = ref.read(archeryPlayersProvider.notifier);

        ArcheryOnlineController? controller;
        if (m != null && me != null && m.isParticipant(me.uid)) {
          notifier.startOnline(
            seed: ArcheryOnlineController.seedFor(m.id),
            joinCode: m.joinCode,
          );
          controller = ArcheryOnlineController(
            matchId: m.id,
            myUid: me.uid,
            notifier: notifier,
          );
          final UserProfile self = me;
          void syncPlayers() {
            final cm = controller!.match.value ?? m;
            final mine = cm.myPlayer(self.uid);
            final theirs = cm.opponentPlayer(self.uid);
            players.set(ArcheryPlayers(
              you: ArcheryPlayer(
                name: mine?.displayName ?? self.displayName,
                avatar: mine?.avatarEmoji ?? self.avatarEmoji,
              ),
              opponent: theirs == null
                  ? const ArcheryPlayer(name: 'Opponent', avatar: '⏳')
                  : ArcheryPlayer(name: theirs.displayName, avatar: theirs.avatarEmoji),
            ));
          }

          syncPlayers();
          controller.match.addListener(syncPlayers);
        } else {
          notifier.restartMatch();
          players.set(ArcheryPlayers(
            you: me == null
                ? ArcheryPlayers.defaultYou
                : ArcheryPlayer(name: me.displayName, avatar: me.avatarEmoji),
            opponent: ArcheryPlayers.bot,
          ));
        }
        online.value = controller;
        final created = ArcheryGame(events: notifier, online: controller);
        audioOwner.value = created;
        game.value = created;
      });
      return () {
        online.value?.dispose();
        final owner = audioOwner.value;
        if (owner != null) ArcheryAudio.leave(owner);
      };
    }, const []);

    void goToLobby() {
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/games');
      }
    }

    final g = game.value;
    final bool isOnline = match != null;

    void openPause() {
      if (g == null || paused.value) return;
      g.controller.onPointerCancel();
      // Solo freezes; a live match can't (the opponent is still playing).
      if (!isOnline) g.pauseEngine();
      paused.value = true;
    }

    /// Opening a dialog over the range: drop any aim being held so the
    /// arrow isn't released by the dialog's own taps.
    void openPauseSilently() {
      if (g == null) return;
      g.controller.onPointerCancel();
    }

    void resume() {
      if (g == null) return;
      if (!isOnline) g.resumeEngine();
      paused.value = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: SafeArea(
        child: g == null
            ? const SizedBox.expand()
            : Stack(
                fit: StackFit.expand,
                children: [
                  // 1. The Flame canvas with its own touch listener
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      ArcheryAudio.unlock();
                      g.controller.onPointerDown(
                        event.pointer,
                        event.localPosition.dx,
                        event.localPosition.dy,
                      );
                    },
                    onPointerMove: (event) {
                      g.controller.onPointerMove(
                        event.pointer,
                        event.localPosition.dx,
                        event.localPosition.dy,
                      );
                    },
                    onPointerUp: (event) {
                      ArcheryAudio.unlock();
                      g.controller.onPointerUp(event.pointer);
                    },
                    onPointerCancel: (_) => g.controller.onPointerCancel(),
                    child: GameWidget(game: g),
                  ),

                  // 2. HUD
                  ArcheryHud(game: g, onExitToLobby: goToLobby),

                  // 3. Corner buttons, icon-only so they never collide with
                  //    the scoreboard. Left: lobby, matches. Right: pause, 1v1.
                  Positioned(
                    top: 8.0,
                    left: 12.0,
                    child: Column(
                      children: [
                        ArcheryRoundButton(
                          icon: Icons.grid_view_rounded,
                          tooltip: 'Lobby',
                          onTap: goToLobby,
                        ),
                        if (_firebaseReady) ...[
                          const SizedBox(height: 8.0),
                          ArcheryMatchesButton(
                            onTap: () {
                              openPauseSilently();
                              ArcheryInbox.open(
                                context,
                                onCreateMatch: () => ArcheryChallenge.start(
                                  context,
                                  showGamePicker: true,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8.0,
                    right: 12.0,
                    child: Column(
                      children: [
                        ArcheryRoundButton(
                          icon: Icons.pause_rounded,
                          tooltip: 'Pause',
                          onTap: openPause,
                        ),
                        if (!isOnline && _firebaseReady) ...[
                          const SizedBox(height: 8.0),
                          ArcheryRoundButton(
                            icon: Icons.people_alt_rounded,
                            tooltip: 'Challenge 1v1',
                            onTap: () => ArcheryChallenge.start(context),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Incoming challenges (any game), under the scoreboard.
                  if (_firebaseReady)
                    Positioned(
                      left: 60.0,
                      right: 60.0,
                      bottom: 18.0,
                      child: Center(
                        child: ArcheryChallengePill(onOpen: openPauseSilently),
                      ),
                    ),

                  // 4. Pause menu (music / effects / birdsong)
                  if (paused.value)
                    ArcheryPauseMenu(
                      online: isOnline,
                      onResume: resume,
                      onRestart: isOnline
                          ? null
                          : () {
                              resume();
                              g.restartMatch();
                            },
                      onLobby: () {
                        paused.value = false;
                        goToLobby();
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

/// Creates an online archery match (code or friend challenge) and takes the
/// player into it. The host may shoot set 1 while waiting for the opponent.
abstract final class ArcheryChallenge {
  static const MatchConfig config = MatchConfig(
    game: 'archery',
    totalRounds: ArcheryRules.maxSets,
    roundDurationSeconds: ArcheryRules.onlineSetSeconds,
  );

  static Future<void> start(BuildContext context, {bool showGamePicker = false}) async {
    final chosen = await MatchSetupDialog.show(
      context,
      initialConfig: config,
      showGamePicker: showGamePicker,
    );
    if (chosen == null || !context.mounted) return;

    final user = await AuthService.instance.ensureAuthenticated();
    final profile = AuthService.instance.currentUser ??
        UserProfile(
          uid: user.uid,
          displayName: user.displayName ?? 'Player',
          avatarEmoji: PlayerDescriptor.defaultAvatar,
        );
    final CloudMatch match = chosen.precreatedMatch ??
        await FirestoreMatchService.instance.createMatch(
          config: chosen,
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
