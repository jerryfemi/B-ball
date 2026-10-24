import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../game/match/match_config.dart';
import '../game/ui/common/clean_ui.dart';
import '../game/ui/match/match_lobby_dialog.dart';
import '../game/ui/match/match_setup_dialog.dart';
import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../models/player_descriptor.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import 'archery_game.dart';
import 'audio/archery_audio.dart';
import 'camera/camera_rig.dart';
import 'online/archery_online_controller.dart';
import 'state/archery_match_notifier.dart';
import 'state/archery_players.dart';
import 'state/archery_rules.dart';
import 'ui/archery_hud.dart';
import 'ui/archery_match_bar.dart';
import 'ui/archery_pause_menu.dart';
import '../game/ui/common/lobby_pill.dart';
import '../notifications/notice_stack.dart';
import '../notifications/profile_drawer.dart';
import 'ui/archery_tour.dart';

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
        // Solo: the bot waits for START (and the how-to-play steps).
        final created = ArcheryGame(events: notifier, online: controller)
          ..awaitingStart = controller == null;
        audioOwner.value = created;
        game.value = created;
      });
      return () {
        online.value?.dispose();
        final owner = audioOwner.value;
        if (owner != null) ArcheryAudio.leave(owner);
      };
    }, const []);

    void leaveScreen() {
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/games');
      }
    }

    // Leaving a live 1v1 is a forfeit: ask first, record it (the match stays
    // in both players' history as completed), and the opponent is told at
    // once instead of waiting out the clock.
    Future<void> goToLobbyAsync() async {
      final ctrl = online.value;
      final CloudMatch? live = ctrl?.match.value;
      if (ctrl != null && live != null && live.status == MatchStatus.active && live.player2 != null) {
        final opp = live.opponentPlayer(ctrl.myUid);
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
                  accent: const Color(0xFFEF4444),
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
          matchId: live.id,
          forfeiterUid: ctrl.myUid,
          winnerUid: opp?.uid ?? '',
        );
        if (!context.mounted) return;
      }
      leaveScreen();
    }

    void goToLobby() {
      goToLobbyAsync();
    }

    final g = game.value;
    final bool isOnline = match != null;

    // How-to-play, once per device, solo only; then START.
    final showTour = useState(false);
    final started = useState(false);
    final tourChecked = useState(false);
    final playFriendKey = useMemoized(GlobalKey.new);
    final matchesKey = useMemoized(GlobalKey.new);
    void startSolo() {
      ArcheryAudio.unlock();
      g?.startMatch();
      started.value = true;
    }

    useEffect(() {
      if (!isOnline) {
        ArcheryTour.shouldShow().then((show) {
          if (!context.mounted) return;
          if (show) showTour.value = true;
          tourChecked.value = true;
        });
      }
      return null;
    }, [isOnline]);

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

    final matchState = ref.watch(archeryMatchProvider);
    final bool isModalActive = paused.value ||
        showTour.value ||
        matchState.matchOver ||
        matchState.setOver ||
        matchState.phase == ShotPhase.setEnd;

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

                  // 3. Corner buttons, icon-only up top so they never collide
                  //    with the scoreboard. Left: your profile drawer
                  //    (invites, friends, matches). Right: pause, 1v1.
                  if (_firebaseReady)
                    Positioned(
                      top: 8.0,
                      left: 12.0,
                      child: ArcheryMatchesButton(
                        key: matchesKey,
                        onTap: () {
                          openPauseSilently();
                          ProfileDrawer.show(
                            context,
                            onOpenMatch: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
                            onOpenMatches: () => ArcheryInbox.open(
                              context,
                              onCreateMatch: () => ArcheryChallenge.start(
                                context,
                                showGamePicker: true,
                              ),
                            ),
                            onPlayFriend: () => ArcheryChallenge.start(context),
                          );
                        },
                      ),
                    ),
                  // "‹ Lobby" under the scoreboard's left edge (hidden during modals).
                  if (!isModalActive)
                    Positioned(
                      top: 108.0,
                      left: 12.0,
                      child: LobbyPill(onTap: goToLobby),
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
                            key: playFriendKey,
                            icon: Icons.people_alt_rounded,
                            tooltip: 'Play a friend',
                            onTap: () => ArcheryChallenge.start(context),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Notifications from any game (invites, friend requests),
                  // at the top under the scoreboard. In a live 1v1 they
                  // shrink to bubbles on the right edge.
                  if (_firebaseReady)
                    Positioned(
                      left: isOnline ? 12.0 : 60.0,
                      right: isOnline ? 12.0 : 60.0,
                      // Solo: below the Lobby pill. Live: bubbles on the right.
                      top: isOnline ? 104.0 : 158.0,
                      child: NoticeStack(
                        live: isOnline,
                        onBeforeOpen: openPauseSilently,
                        onOpenMatch: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
                      ),
                    ),

                  // 3b. How-to-play (first archery open on this device)
                  if (showTour.value && !isOnline)
                    ArcheryTour(
                      playFriendKey: playFriendKey,
                      matchesKey: matchesKey,
                      onDone: () => showTour.value = false,
                    )
                  else if (!isOnline && tourChecked.value && !started.value && !paused.value)
                    ArcheryStartButton(onStart: startSolo),

                  // 4. Pause menu (music / effects / birdsong)
                  if (paused.value)
                    ArcheryPauseMenu(
                      online: isOnline,
                      onResume: resume,
                      onRestart: isOnline
                          ? null
                          : () {
                              resume();
                              startSolo(); // a restart doesn't ask again
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

    // "Join with a code": the match already exists, just open it.
    final joined = chosen.joinedMatch;
    if (joined != null) {
      GoRouter.maybeOf(context)?.go('/match/${joined.id}');
      return;
    }

    await _createAndEnter(context, chosen);
  }

  /// A new archery match against the same opponent, sent to them as a
  /// challenge (they see it on their card, in the inbox and as a pill).
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
    // Both archers may tap REMATCH at once: they share one room, so the
    // second tap joins the first instead of opening a second waiting room.
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

  static Future<void> _createAndEnter(BuildContext context, MatchConfig chosen) async {
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
