import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../models/player_descriptor.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../match/match_config.dart';
import '../common/app_avatar.dart';
import '../common/app_button.dart';
import '../common/app_modal_dialog.dart';
import 'components/friend_selector_ribbon.dart';
import 'components/match_code_card.dart';

/// Streamlined Arcade 1v1 Challenge Creator modal in muted luxury obsidian palette.
class MatchSetupDialog extends HookWidget {
  final MatchConfig initialConfig;

  const MatchSetupDialog({super.key, this.initialConfig = const MatchConfig()});

  static Future<MatchConfig?> show(
    BuildContext context, {
    MatchConfig initialConfig = const MatchConfig(),
  }) {
    return AppModalDialog.show<MatchConfig>(
      context: context,
      builder: (context) => MatchSetupDialog(initialConfig: initialConfig),
    );
  }

  static const List<int> _roundOptions = [2, 3, 4];
  static const List<int> _durationOptions = [30, 60];

  @override
  Widget build(BuildContext context) {
    final selectedRounds = useState(initialConfig.totalRounds);
    final selectedDuration = useState(initialConfig.roundDurationSeconds);
    final opponentMode = useState(
      initialConfig.opponentFriend != null ? 1 : 0,
    ); // 0: Open Code, 1: Friend Challenge
    final selectedFriend = useState<FriendProfile?>(
      initialConfig.opponentFriend,
    );
    final isGeneratingCode = useState(false);
    final precreatedMatch = useState<CloudMatch?>(null);
    final codeCopied = useState(false);

    Future<void> generateUpfrontCode(UserProfile profile) async {
      if (isGeneratingCode.value) return;
      isGeneratingCode.value = true;
      try {
        final config = MatchConfig(
          totalRounds: selectedRounds.value,
          roundDurationSeconds: selectedDuration.value,
          player1Name: profile.displayName,
          player1Avatar: profile.avatarEmoji,
          player2Name: 'Opponent',
          player2Avatar: '⏳',
        );
        final match = await FirestoreMatchService.instance.createMatch(
          config: config,
          player1Profile: profile,
        );
        await Clipboard.setData(ClipboardData(text: match.joinCode));
        HapticFeedback.mediumImpact();
        if (context.mounted) {
          precreatedMatch.value = match;
          codeCopied.value = true;
          isGeneratingCode.value = false;
        }
      } catch (e) {
        if (context.mounted) {
          isGeneratingCode.value = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate code: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }

    Future<void> copyCode() async {
      if (precreatedMatch.value == null) return;
      await Clipboard.setData(
        ClipboardData(text: precreatedMatch.value!.joinCode),
      );
      HapticFeedback.lightImpact();
      codeCopied.value = true;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Match code ${precreatedMatch.value!.joinCode} copied!',
            ),
            backgroundColor: const Color(0xFF1E2638),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    void onStartPressed() {
      HapticFeedback.mediumImpact();
      final profile = AuthService.instance.currentUser;
      final myName = profile?.displayName ?? 'Player';
      final myAvatar =
          profile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;

      final config = MatchConfig(
        totalRounds: selectedRounds.value,
        roundDurationSeconds: selectedDuration.value,
        player1Name: myName,
        player1Avatar: myAvatar,
        player2Name:
            opponentMode.value == 1 && selectedFriend.value != null
                ? selectedFriend.value!.displayName
                : 'Opponent',
        player2Avatar:
            opponentMode.value == 1 && selectedFriend.value != null
                ? selectedFriend.value!.avatarEmoji
                : '⏳',
        player2Uid:
            opponentMode.value == 1 ? selectedFriend.value?.uid : null,
        opponentFriend:
            opponentMode.value == 1 ? selectedFriend.value : null,
        precreatedMatch: precreatedMatch.value,
      );

      Navigator.of(context).pop(config);
    }

    String getStartButtonLabel() {
      if (opponentMode.value == 1 && selectedFriend.value != null) {
        return 'CHALLENGE ${selectedFriend.value!.displayName.toUpperCase()} ➔';
      }
      if (precreatedMatch.value != null) {
        return 'START ROUND 1 ➔';
      }
      return 'START 1V1 MATCH';
    }

    final profile = AuthService.instance.currentUser;
    final myName = profile?.displayName ?? 'Player';
    final myAvatar =
        profile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;

    return AppModalDialog(
      maxWidth: 390.0,
      scrollable: true,
      iconWidget: const Icon(
        Icons.sports_basketball_rounded,
        color: Color(0xFFF59E0B),
        size: 22.0,
      ),
      title: 'NEW 1V1 MATCH',
      subtitle: 'Challenge a friend or share a match code',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player identity capsule
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2638),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                AppAvatar(
                  avatar: myAvatar,
                  size: 34.0,
                  borderColor: const Color(0xFF38BDF8),
                  borderWidth: 1.5,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CREATING AS',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        myName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'HOST',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // Opponent Mode Selector
          const Text(
            'OPPONENT',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              _buildOpponentTab(
                0,
                'OPEN CODE',
                Icons.qr_code_rounded,
                opponentMode,
              ),
              const SizedBox(width: 8.0),
              _buildOpponentTab(
                1,
                'CHALLENGE FRIEND',
                Icons.people_alt_rounded,
                opponentMode,
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Opponent Details / Options
          if (opponentMode.value == 0)
            MatchCodeCard(
              precreatedMatch: precreatedMatch.value,
              isGeneratingCode: isGeneratingCode.value,
              codeCopied: codeCopied.value,
              profile: profile,
              onGenerateCode: () {
                if (profile != null) generateUpfrontCode(profile);
              },
              onCopyCode: copyCode,
            )
          else
            FriendSelectorRibbon(
              profile: profile,
              selectedFriend: selectedFriend.value,
              onFriendSelected: (friend) {
                selectedFriend.value = friend;
              },
              onUseOpenCode: () => opponentMode.value = 0,
            ),
          const SizedBox(height: 18.0),

          // Option 1: Total Rounds
          const Text(
            'MATCH LENGTH',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: _roundOptions.map((rounds) {
              final isSelected = selectedRounds.value == rounds;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      selectedRounds.value = rounds;
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF334155),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$rounds Rounds',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                            fontSize: 12.0,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16.0),

          // Option 2: Shot Clock
          const Text(
            'ROUND SHOT CLOCK',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: _durationOptions.map((dur) {
              final isSelected = selectedDuration.value == dur;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      selectedDuration.value = dur;
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF334155),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dur == 30 ? '30s Blitz ⚡' : '60s Standard ⏱',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFCBD5E1),
                            fontSize: 12.0,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22.0),

          // Primary Start Challenge Button
          AppPrimaryButton(
            label: getStartButtonLabel(),
            backgroundColor: const Color(0xFF38BDF8),
            iconData: Icons.arrow_forward_rounded,
            onPressed: onStartPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentTab(
    int mode,
    String label,
    IconData icon,
    ValueNotifier<int> opponentMode,
  ) {
    final isSelected = opponentMode.value == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          opponentMode.value = mode;
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1E3A5F)
                : const Color(0xFF1E2638),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF334155),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.0,
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
