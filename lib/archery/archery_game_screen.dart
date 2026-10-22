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
        game.value = ArcheryGame(events: notifier, online: controller);
      });
      return () {
        online.value?.dispose();
        ArcheryAudio.leave();
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

                  // 3. Lobby (top-left) and, solo, a 1v1 challenge (top-right)
                  Positioned(
                    top: 8.0,
                    left: 14.0,
                    child: _CornerButton(
                      icon: Icons.grid_view_rounded,
                      label: 'LOBBY',
                      onTap: goToLobby,
                    ),
                  ),
                  Positioned(
                    top: 8.0,
                    right: 14.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isOnline && _firebaseReady) ...[
                          _CornerButton(
                            icon: Icons.people_alt_rounded,
                            label: '1V1',
                            onTap: () => ArcheryChallenge.start(context),
                          ),
                          const SizedBox(width: 8.0),
                        ],
                        _CornerButton(
                          icon: Icons.pause_rounded,
                          label: 'PAUSE',
                          onTap: openPause,
                        ),
                      ],
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

  static Future<void> start(BuildContext context) async {
    final chosen = await MatchSetupDialog.show(context, initialConfig: config);
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

class _CornerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CornerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC0A0E1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33FFFFFF), width: 1.0),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
