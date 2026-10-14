import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/cloud_match.dart';
import '../../../models/player_descriptor.dart';
import '../../../providers/app_providers.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../basketball_game.dart';
import '../../match/match_session.dart';
import '../match/match_lobby_dialog.dart';
import '../match/match_setup_dialog.dart';
import 'join_match_dialog.dart';
import 'match_inbox_card.dart';
import 'match_thread_dialog.dart';
import '../common/app_avatar.dart';
import '../common/app_colors.dart';
import '../common/app_modal_sheet.dart';
import '../social/friends_hub_sheet.dart';

/// The central 1v1 Match Hub bottom sheet modal.
class MatchInboxSheet extends HookConsumerWidget {
  final ValueChanged<CloudMatch> onPlayMatch;
  final VoidCallback onCreateMatch;
  final ValueChanged<CloudMatch>? onViewPodium;

  const MatchInboxSheet({
    super.key,
    required this.onPlayMatch,
    required this.onCreateMatch,
    this.onViewPodium,
  });

  /// Summon the Match Inbox sheet.
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CloudMatch> onPlayMatch,
    required VoidCallback onCreateMatch,
    ValueChanged<CloudMatch>? onViewPodium,
  }) {
    return AppModalSheet.show<void>(
      context: context,
      builder: (ctx) => MatchInboxSheet(
        onPlayMatch: onPlayMatch,
        onCreateMatch: onCreateMatch,
        onViewPodium: onViewPodium,
      ),
    );
  }

  /// Convenience coordinator to open the Match Inbox and wire all cloud match actions
  /// (joining, creating lobby, playing, viewing podium) directly to the [BasketballGame].
  static Future<void> openWithGame(
    BuildContext context, {
    required BasketballGame game,
  }) async {
    final wasPlaying = game.gameStateNotifier.value == GameModeState.playing;
    if (wasPlaying) {
      game.pauseGame(manual: true);
    }
    await show(
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = useState(0); // 0: Live Matches, 1: Trophy History

    void showEditProfileDialog(BuildContext ctx, UserProfile current) {
      final nameCtrl = TextEditingController(text: current.displayName);
      final avatarOptions = AuthService.avatarImageOptions;
      String selectedAvatar = current.avatarEmoji.startsWith('assets/')
          ? current.avatarEmoji
          : avatarOptions.first;

      showDialog(
        context: ctx,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => Dialog(
            backgroundColor: const Color(0xFF131826),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF2E3954), width: 1.5),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EDIT YOUR PROFILE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white60,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Selected Avatar Live Preview Circle
                  Center(
                    child: AppAvatar(
                      avatar: selectedAvatar,
                      size: 96,
                      borderColor: const Color(0xFF00FFCC),
                      borderWidth: 2.5,
                      showGlow: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    maxLength: 16,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF1E2638),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'CHOOSE AVATAR',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 15 Dunk Head Real Image Avatars using AppAvatar
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: avatarOptions.map((assetPath) {
                      final isSel = selectedAvatar == assetPath;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setDialogState(() => selectedAvatar = assetPath);
                        },
                        customBorder: const CircleBorder(),
                        child: AppAvatar(
                          avatar: assetPath,
                          size: 44,
                          borderColor: isSel
                              ? const Color(0xFF00FFCC)
                              : Colors.white24,
                          borderWidth: isSel ? 2.5 : 1.2,
                          showGlow: isSel,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: () async {
                      final cleanName = nameCtrl.text.trim();
                      if (cleanName.isNotEmpty) {
                        await AuthService.instance.updateProfile(
                          displayName: cleanName,
                          avatarEmoji: selectedAvatar,
                        );
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'SAVE PROFILE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final myProfile = ref.watch(currentUserProfileProvider).value;
    final myUid = myProfile?.uid ?? '';
    final matchesAsync = ref.watch(userMatchesProvider);
    final allMatches = matchesAsync.value ?? const <CloudMatch>[];

    return AppModalSheet(
          heightFactor: 0.85,
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                InkWell(
                  onTap: myProfile != null
                      ? () => showEditProfileDialog(context, myProfile)
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      AppAvatar(
                        avatar: myProfile?.avatarEmoji ??
                            AppAvatar.defaultAvatar,
                        size: 38,
                        borderColor: const Color(0xFF38BDF8),
                        borderWidth: 1.8,
                        showGlow: true,
                        glowColor: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                myProfile?.displayName ?? 'Baller',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit_rounded,
                                size: 13,
                                color: Color(0xFF38BDF8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'MY PROFILE',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 14),

                // Quick Actions: "+ CREATE MATCH", "JOIN MATCH", and "FRIENDS"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onCreateMatch();
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'CREATE MATCH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 10,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final match = await JoinMatchDialog.show(context);
                            if (match != null && context.mounted) {
                              Navigator.of(context).pop();
                              onPlayMatch(match);
                            }
                          },
                          icon: const Icon(Icons.dialpad_rounded, size: 14),
                          label: const Text(
                            'JOIN MATCH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00FFCC),
                            side: const BorderSide(
                              color: Color(0xFF00FFCC),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final friendsBadgeCount =
                              ref.watch(friendsBadgeCountProvider);
                          return Expanded(
                            flex: 8,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await FriendsHubSheet.show(
                                        context,
                                        onPlayMatch: (m) {
                                          Navigator.of(context).pop();
                                          onPlayMatch(m);
                                        },
                                        onCreateMatch: () {
                                          Navigator.of(context).pop();
                                          onCreateMatch();
                                        },
                                        onViewPodium: (m) {
                                          Navigator.of(context).pop();
                                          onViewPodium?.call(m);
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.people_alt_rounded, size: 14),
                                    label: const Text(
                                      'FRIENDS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF818CF8),
                                      side: const BorderSide(
                                        color: Color(0xFF6366F1),
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                if (friendsBadgeCount > 0)
                                  Positioned(
                                    top: -4.0,
                                    right: -4.0,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18.0,
                                        minHeight: 18.0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5.0,
                                        vertical: 1.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentRed,
                                        borderRadius: BorderRadius.circular(10.0),
                                        border: Border.all(
                                          color: const Color(0xFF0F1420),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accentRed
                                                .withValues(alpha: 0.6),
                                            blurRadius: 6.0,
                                            spreadRadius: 1.0,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$friendsBadgeCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Tab Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildTabPill(0, 'ACTIVE MATCHES', selectedTab),
                      const SizedBox(width: 8),
                      _buildTabPill(1, 'COMPLETED', selectedTab),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Matches Stream Feed
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (matchesAsync.isLoading && !matchesAsync.hasValue) {
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00FFCC),
                          ),
                        );
                      }
                      final liveMatches = allMatches
                          .where((m) => m.status != MatchStatus.completed)
                          .toList();
                      final completedMatches = allMatches
                          .where((m) => m.status == MatchStatus.completed)
                          .toList();

                      // Sort live matches so your turns appear at the top
                      liveMatches.sort((a, b) {
                        final aTurn = a.isMyTurn(myUid) ? 0 : 1;
                        final bTurn = b.isMyTurn(myUid) ? 0 : 1;
                        return aTurn.compareTo(bTurn);
                      });

                      final displayList = selectedTab.value == 0
                          ? liveMatches
                          : completedMatches;

                      if (displayList.isEmpty) {
                        return _buildEmptyState(selectedTab.value == 0);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        itemCount: displayList.length,
                        itemBuilder: (ctx, i) {
                          final match = displayList[i];
                          return MatchInboxCard(
                            match: match,
                            myUid: myUid,
                            onTap: () {
                              if (match.status == MatchStatus.completed) {
                                Navigator.of(context).pop();
                                onViewPodium?.call(match);
                              } else {
                                MatchThreadDialog.show(
                                  context,
                                  match: match,
                                  myUid: myUid,
                                  onPlayTurn: () {
                                    Navigator.of(context).pop();
                                    onPlayMatch(match);
                                  },
                                  onViewPodium: () {
                                    Navigator.of(context).pop();
                                    onViewPodium?.call(match);
                                  },
                                );
                              }
                            },
                            onPlayTurn: () {
                              Navigator.of(context).pop();
                              onPlayMatch(match);
                            },
                            onViewPodium: () {
                              Navigator.of(context).pop();
                              onViewPodium?.call(match);
                            },
                            onLeave: () {
                              final isDone =
                                  match.status == MatchStatus.completed;
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF131826),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                      color: Color(0xFF2E3954),
                                      width: 1.5,
                                    ),
                                  ),
                                  title: Text(
                                    isDone ? 'REMOVE MATCH' : 'LEAVE MATCH',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  content: Text(
                                    isDone
                                        ? 'Remove this finished match from your history?'
                                        : 'Are you sure you want to forfeit and leave this match? It will be removed from your active matches.',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogCtx).pop(),
                                      child: const Text(
                                        'CANCEL',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.of(dialogCtx).pop();
                                        await FirestoreMatchService.instance
                                            .leaveOrDismissMatch(
                                          matchId: match.id,
                                          myUid: myUid,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        isDone ? 'REMOVE' : 'LEAVE',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
        );
  }

  Widget _buildTabPill(
    int index,
    String label,
    ValueNotifier<int> selectedTab,
  ) {
    final isSelected = selectedTab.value == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        selectedTab.value = index;
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2638) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FFCC)
                : const Color(0xFF26324A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF00FFCC)
                : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLiveTab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiveTab
                  ? Icons.sports_basketball_outlined
                  : Icons.emoji_events_outlined,
              size: 40,
              color: const Color(0xFF475569),
            ),
            const SizedBox(height: 10),
            Text(
              isLiveTab
                  ? 'No live challenges right now'
                  : 'No completed matches yet',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLiveTab
                  ? 'Tap "+ NEW MATCH" or join a friend\'s code to play!'
                  : 'Finished games and winner podiums will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
