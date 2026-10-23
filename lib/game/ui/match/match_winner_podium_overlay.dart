import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/friend_profile.dart';
import '../../../models/match_invite.dart';
import '../../../providers/app_providers.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../basketball_game.dart';
import '../../match/match_session.dart';
import '../common/app_avatar.dart';
import '../common/inline_feedback.dart';
import 'match_lobby_dialog.dart';
import 'match_setup_dialog.dart';
import 'podium/podium_score_matrix.dart';
import 'podium/podium_stats_comparison.dart';
import 'podium/podium_trophy_header.dart';

/// Grand celebration podium overlay shown upon match conclusion.
class MatchWinnerPodiumOverlay extends HookConsumerWidget {
  final BasketballGame game;
  final MatchSession session;

  const MatchWinnerPodiumOverlay({
    super.key,
    required this.game,
    required this.session,
  });

  /// Leaves the podium and returns to solo shootaround.
  ///
  /// The match document is intentionally left untouched: finished matches stay
  /// in both players' COMPLETED trophy history. Removal only happens when a
  /// player explicitly taps the trash icon in the inbox.
  Future<void> _handleCloseOrDismiss(BuildContext context) async {
    game.exitToSoloMode();
  }

  Future<void> _handleInstantRematch(
    BuildContext context,
    ValueNotifier<String?> rematchError,
    ValueNotifier<bool> isRematching,
  ) async {
    if (isRematching.value) return;
    HapticFeedback.mediumImpact();
    rematchError.value = null;
    isRematching.value = true;
    final profile = AuthService.instance.currentUser;
    final myUid = profile?.uid ?? '';

    final opponent = session.player2;
    final bool hasValidUid = opponent.id.isNotEmpty && opponent.id != 'them';
    final opponentFriend = hasValidUid
        ? FriendProfile(
            uid: opponent.id,
            displayName: opponent.name,
            avatarEmoji: opponent.avatar,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          )
        : null;

    try {
      final config = MatchConfig(
        totalRounds: session.totalRounds,
        roundDurationSeconds: session.config.roundDurationSeconds,
        difficulty: session.config.difficulty,
        player1Name: session.player1.name,
        player1Avatar: session.player1.avatar,
        player2Name: opponent.name,
        player2Avatar: opponent.avatar,
        player2Uid: opponent.id.isNotEmpty ? opponent.id : null,
        opponentFriend: opponentFriend,
      );

      final userProfile = profile ??
          UserProfile(
            uid: myUid,
            displayName: session.player1.name,
            avatarEmoji: session.player1.avatar,
          );

      // Both players may tap REMATCH at once: they share one room, so the
      // second tap joins the first instead of opening a second waiting room.
      final String? finishedId = session.cloudMatchId;
      final result = finishedId != null
          ? await FirestoreMatchService.instance.createOrJoinRematch(
              finishedMatchId: finishedId,
              config: config,
              me: userProfile,
            )
          : (
              match: await FirestoreMatchService.instance.createMatch(
                config: config,
                player1Profile: userProfile,
              ),
              joined: false,
            );
      final newMatch = result.match;

      if (context.mounted) {
        isRematching.value = false;
        game.exitToSoloMode();
        if (result.joined) {
          game.startCloudMatch(newMatch, userProfile.uid);
          return;
        }

        MatchLobbyDialog.show(
          context: context,
          match: newMatch,
          challengedFriend: opponentFriend,
          onPlaySoloWhileWaiting: () {
            game.startCloudMatch(newMatch, userProfile.uid);
          },
          onEnterArena: (confirmedMatch) {
            game.startCloudMatch(confirmedMatch, userProfile.uid);
          },
        );
      }
    } catch (e) {
      debugPrint('[Podium] Failed to create instant rematch: $e');
      if (context.mounted) {
        isRematching.value = false;
        // The rematch button morphs into an inline error card with RETRY.
        rematchError.value = InlineErrorPanel.friendlyMessage(
          e,
          fallback: 'Couldn\'t create the rematch room. Check your connection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rematchError = useState<String?>(null);
    // A rematch challenge from this opponent while I'm still on the podium.
    final opponentId = session.player2.id;
    final rematchInvite = session.isHistoryView || !session.isOnline
        ? null
        : (ref.watch(incomingMatchChallengesProvider).value ??
                  const <MatchInvite>[])
              .where((i) => i.isPending && i.hostUid == opponentId)
              .firstOrNull;
    final isRematching = useState(false);

    // Online podium: if nobody rematches, both players go back to the court
    // (solo). Shorter when the opponent left. Paused while their rematch
    // invite is up or while a rematch is being set up.
    final bool liveEnd = !session.isHistoryView && session.cloudMatchId != null;
    final bool oppLeft = session.forfeitWinner != null;
    final backIn = useState<int>(oppLeft ? 10 : 45);
    final holdCountdown = useRef(false);
    holdCountdown.value = rematchInvite != null || isRematching.value || rematchError.value != null;
    useEffect(() {
      if (!liveEnd) return null;
      final t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (holdCountdown.value) return;
        backIn.value--;
        if (backIn.value <= 0) {
          t.cancel();
          if (context.mounted) _handleCloseOrDismiss(context);
        }
      });
      return t.cancel;
    }, [liveEnd]);

    final winner = session.overallWinner;
    final isTie = session.isTie;
    final isP1Winner = winner == session.player1;

    final Color bannerColor = isTie
        ? const Color(0xFFF59E0B)
        : (isP1Winner ? const Color(0xFF22C55E) : const Color(0xFF38BDF8));

    // Online: I'm always player1, so I see myself as "YOU".
    final String winnerDeclaration = isTie || winner == null
        ? 'MATCH TIED!'
        : (session.isOnline && isP1Winner
              ? 'YOU WIN!'
              : '${winner.name.toUpperCase()} WINS!');

    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        constraints: BoxConstraints(
          maxWidth: 410.0,
          maxHeight: screenHeight * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 22.0,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF20F172A), Color(0xFA090D16)],
                ),
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(
                  color: bannerColor.withValues(alpha: 0.60),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bannerColor.withValues(alpha: 0.25),
                    blurRadius: 36.0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Trophy Graphic, Declaration & Close Button
                    PodiumTrophyHeader(
                      session: session,
                      bannerColor: bannerColor,
                      winnerDeclaration: winnerDeclaration,
                      isTie: isTie,
                      onClose: () => _handleCloseOrDismiss(context),
                    ),
                    const SizedBox(height: 14.0),

                    // 2. Aggregate Score Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06060A),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: const Color(0x28FFFFFF),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAggregateColumn(
                            name: session.displayNameFor(session.player1),
                            avatar: session.player1.avatar,
                            score: session.player1.totalScore,
                            color: session.player1.accentColor,
                            isWinner: isP1Winner,
                          ),
                          const Text(
                            'VS',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          _buildAggregateColumn(
                            name: session.player2.name,
                            avatar: session.player2.avatar,
                            score: session.player2.totalScore,
                            color: session.player2.accentColor,
                            isWinner: !isTie && !isP1Winner,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // 3. Round-by-Round Breakdown Matrix
                    PodiumScoreMatrix(session: session),
                    const SizedBox(height: 12.0),

                    // 4. Head-to-Head Shooting Analytics
                    PodiumStatsComparison(session: session),
                    const SizedBox(height: 18.0),

                    // 5. Action Buttons
                    if (session.isHistoryView) ...[
                      // Reopened from COMPLETED history: the match is over,
                      // so no rematch / "waiting for host" — just close.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleCloseOrDismiss(context),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text(
                            'CLOSE',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0x181E293B),
                            foregroundColor: const Color(0xFF94A3B8),
                            side: const BorderSide(
                              color: Color(0xFF334155),
                              width: 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                        ),
                      ),
                    ] else if (session.cloudMatchId != null) ...[
                      // Opponent already sent a rematch: offer it right here
                      // (one tap joins the waiting room) instead of only as
                      // a chip behind the podium.
                      if (rematchInvite != null) ...[
                        _RematchInviteBanner(
                          key: ValueKey('rematch-${rematchInvite.matchId}'),
                          invite: rematchInvite,
                          game: game,
                        ),
                        const SizedBox(height: 8.0),
                      ]
                      // Primary Action: REMATCH. Either player can start it;
                      // the other gets the invite banner above.
                      else
                        InlineFeedbackSwitcher(
                          child: rematchError.value != null
                              ? InlineErrorPanel(
                                  key: const ValueKey('rematch-error'),
                                  title: 'REMATCH FAILED',
                                  message: rematchError.value!,
                                  onRetry: () => _handleInstantRematch(
                                    context,
                                    rematchError,
                                    isRematching,
                                  ),
                                  onDismiss: () => rematchError.value = null,
                                )
                              : SizedBox(
                          key: const ValueKey('rematch-button'),
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isRematching.value
                                ? null
                                : () => _handleInstantRematch(
                                      context,
                                      rematchError,
                                      isRematching,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bannerColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              elevation: 8.0,
                              shadowColor: bannerColor.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.replay_rounded, size: 20.0),
                                const SizedBox(width: 8.0),
                                Flexible(
                                  child: Text(
                                    'REMATCH ${session.player2.name.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      const SizedBox(height: 8.0),

                      // Secondary Action: CLOSE & DISMISS
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleCloseOrDismiss(context),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: Text(
                            holdCountdown.value
                                ? 'BACK TO COURT'
                                : 'BACK TO COURT · ${backIn.value}s',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0x181E293B),
                            foregroundColor: const Color(0xFF94A3B8),
                            side: const BorderSide(
                              color: Color(0xFF334155),
                              width: 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Local / Pass & Play Actions
                      // Primary Action: REMATCH
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => game.startPassAndPlayMatch(
                            config: session.config,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bannerColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            elevation: 8.0,
                            shadowColor: bannerColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.replay_rounded, size: 20.0),
                              SizedBox(width: 8.0),
                              Text(
                                'REMATCH',
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      // Secondary Action: MATCH SETTINGS
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final newConfig = await MatchSetupDialog.show(
                              context,
                              initialConfig: session.config,
                              allowJoin: false,
                            );
                            if (newConfig != null) {
                              game.startPassAndPlayMatch(config: newConfig);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(
                              color: Color(0x6638BDF8),
                              width: 1.0,
                            ),
                            backgroundColor: const Color(0x120284C7),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune_rounded, size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'MATCH SETTINGS',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      // Tertiary Action: PRACTICE SOLO
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => game.exitToSoloMode(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                          ),
                          child: const Text(
                            'PRACTICE SOLO',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

  Widget _buildAggregateColumn({
    required String name,
    required String avatar,
    required int score,
    required Color color,
    required bool isWinner,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(avatar: avatar, size: 16.0),
            const SizedBox(width: 4.0),
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            if (isWinner) ...[
              const SizedBox(width: 4.0),
              const Text('👑', style: TextStyle(fontSize: 12.0)),
            ],
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          '$score',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32.0,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
/// "BUCKET#4417 wants a rematch" card shown on the podium. JOIN accepts the
/// challenge and goes straight into the new match; NO THANKS declines it.
class _RematchInviteBanner extends HookWidget {
  final MatchInvite invite;
  final BasketballGame game;

  const _RematchInviteBanner({
    super.key,
    required this.invite,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final isJoining = useState(false);
    final joinError = useState<String?>(null);

    Future<void> join() async {
      final profile = AuthService.instance.currentUser;
      if (isJoining.value || profile == null) return;
      HapticFeedback.mediumImpact();
      joinError.value = null;
      isJoining.value = true;
      try {
        final joined = await FirestoreMatchService.instance
            .acceptMatchChallenge(invite: invite, recipientProfile: profile);
        game.startCloudMatch(joined, profile.uid);
      } catch (e) {
        if (context.mounted) {
          isJoining.value = false;
          joinError.value = InlineErrorPanel.friendlyMessage(
            e,
            fallback: 'Couldn\'t join the rematch. Check your connection.',
          );
        }
      }
    }

    Future<void> decline() async {
      HapticFeedback.lightImpact();
      final myUid = AuthService.instance.currentUser?.uid;
      if (myUid == null) return;
      await FirestoreMatchService.instance.declineMatchChallenge(
        myUid: myUid,
        matchId: invite.matchId,
        hostUid: invite.hostUid,
      );
    }

    return InlineFeedbackSwitcher(
      child: joinError.value != null
          ? InlineErrorPanel(
              key: const ValueKey('rematch-join-error'),
              title: 'COULDN\'T JOIN',
              message: joinError.value!,
              onRetry: join,
              onDismiss: () => joinError.value = null,
            )
          : Container(
              key: const ValueKey('rematch-invite'),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFF00FFCC), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.18),
                    blurRadius: 14.0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AppAvatar(avatar: invite.hostAvatar, size: 30.0),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                          '${invite.hostName.toUpperCase()} WANTS A REMATCH!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isJoining.value ? null : decline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 11.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'NO THANKS',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isJoining.value ? null : join,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 11.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isJoining.value
                              ? const SizedBox(
                                  width: 16.0,
                                  height: 16.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'JOIN REMATCH',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
