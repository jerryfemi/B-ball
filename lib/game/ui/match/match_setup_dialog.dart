import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:share_plus/share_plus.dart';

import '../../../archery/state/archery_rules.dart';
import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../models/player_descriptor.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/update/update_platform.dart';
import '../../match/match_config.dart';
import '../../physics/shot_difficulty.dart';
import '../common/app_avatar.dart';
import '../common/app_button.dart';
import '../common/app_colors.dart';
import '../common/app_modal_dialog.dart';
import '../common/difficulty_stepped_slider.dart';
import '../common/inline_feedback.dart';
import 'components/friend_selector_ribbon.dart';
import 'components/match_code_card.dart';

/// Streamlined Arcade 1v1 Challenge Creator modal in muted luxury obsidian palette.
class MatchSetupDialog extends HookWidget {
  final MatchConfig initialConfig;

  /// Shows a BASKETBALL / ARCHERY switch at the top (the shared match inbox).
  /// Off when a game opens the dialog for itself.
  final bool showGamePicker;

  const MatchSetupDialog({
    super.key,
    this.initialConfig = const MatchConfig(),
    this.showGamePicker = false,
  });

  static Future<MatchConfig?> show(
    BuildContext context, {
    MatchConfig initialConfig = const MatchConfig(),
    bool showGamePicker = false,
  }) {
    return AppModalDialog.show<MatchConfig>(
      context: context,
      builder: (context) => MatchSetupDialog(
        initialConfig: initialConfig,
        showGamePicker: showGamePicker,
      ),
    );
  }

  static const List<int> _roundOptions = [2, 3, 4];
  static const List<int> _durationOptions = [30, 60];

  @override
  Widget build(BuildContext context) {
    // Archery has fixed rules (sets to 6 points, per-arrow shot clock), so
    // only the opponent part of this dialog applies.
    final selectedGame = useState(initialConfig.game);
    final bool isArchery = selectedGame.value == 'archery';

    /// Archery has fixed rules; basketball uses the chosen options.
    MatchConfig withGameRules(MatchConfig c) => selectedGame.value == 'archery'
        ? c.copyWith(
            game: 'archery',
            totalRounds: ArcheryRules.maxSets,
            roundDurationSeconds: ArcheryRules.onlineSetSeconds,
          )
        : c.copyWith(game: selectedGame.value);
    final selectedRounds = useState(initialConfig.totalRounds);
    final selectedDuration = useState(initialConfig.roundDurationSeconds);
    final selectedDifficulty = useState(initialConfig.difficulty);
    final opponentMode = useState(
      initialConfig.opponentFriend != null ? 1 : 0,
    ); // 0: Open Code, 1: Friend Challenge
    final selectedFriend = useState<FriendProfile?>(
      initialConfig.opponentFriend,
    );
    final isGeneratingCode = useState(false);
    final precreatedMatch = useState<CloudMatch?>(null);
    final codeCopied = useState(false);
    // Inline states that replace floating SnackBars.
    final codeError = useState<String?>(null);
    final showPickFriendHint = useState(false);

    /// Works even if the player taps before sign-in has finished hydrating:
    /// shows the generating spinner immediately and waits for the profile,
    /// instead of leaving the button silently disabled.
    Future<void> generateUpfrontCode(UserProfile? knownProfile) async {
      if (isGeneratingCode.value) return;
      codeError.value = null;
      if (!isDeviceOnline()) {
        codeError.value =
            'You\'re offline. Reconnect to the internet to create a 1v1 match.';
        return;
      }
      isGeneratingCode.value = true;
      try {
        final profile = knownProfile ??
            AuthService.instance.currentUser ??
            await AuthService.instance.initialize();
        final config = withGameRules(MatchConfig(
          totalRounds: selectedRounds.value,
          roundDurationSeconds: selectedDuration.value,
          difficulty: selectedDifficulty.value,
          player1Name: profile.displayName,
          player1Avatar: profile.avatarEmoji,
          player2Name: 'Opponent',
          player2Avatar: '⏳',
        ));
        final match = await FirestoreMatchService.instance.createMatch(
          config: config,
          player1Profile: profile,
        );
        // The room exists now: show the code no matter what happens next.
        if (context.mounted) {
          precreatedMatch.value = match;
          codeCopied.value = false;
          isGeneratingCode.value = false;
        }
        HapticFeedback.mediumImpact();
        // Best-effort auto-copy. Safari only allows clipboard writes during
        // the tap itself, and creating the room took a network round trip,
        // so this often fails there. That's fine: the card offers COPY and
        // SHARE buttons, which run inside a fresh tap.
        try {
          await Clipboard.setData(ClipboardData(text: match.joinCode));
          if (context.mounted) codeCopied.value = true;
        } catch (_) {}
      } catch (e) {
        if (context.mounted) {
          isGeneratingCode.value = false;
          codeError.value = InlineErrorPanel.friendlyMessage(
            e,
            fallback: 'Couldn\'t generate a match code. Please try again.',
          );
        }
      }
    }

    Future<void> copyCode() async {
      final match = precreatedMatch.value;
      if (match == null) return;
      try {
        await Clipboard.setData(ClipboardData(text: match.joinCode));
        HapticFeedback.lightImpact();
        // MatchCodeCard renders its own copied state — no SnackBar needed.
        codeCopied.value = true;
      } catch (_) {
        // Clipboard blocked (rare, inside a tap): the code is selectable and
        // SHARE still works, so stay quiet rather than show an error.
      }
    }

    Future<void> shareCode() async {
      final match = precreatedMatch.value;
      if (match == null) return;
      HapticFeedback.lightImpact();
      final code = match.joinCode;
      final text = match.isArchery
          ? '🎯 Shoot archery with me on GameVerse! Match code: $code\n'
              'https://dunkverse.web.app/match/$code'
          : '🏀 Play me 1v1 on DunkVerse! Match code: $code\n'
              'https://dunkverse.web.app/match/$code';
      try {
        await SharePlus.instance.share(ShareParams(text: text));
      } catch (_) {
        // No share sheet on this browser: fall back to copying the message.
        try {
          await Clipboard.setData(ClipboardData(text: text));
          codeCopied.value = true;
        } catch (_) {}
      }
    }

    void onStartPressed() {
      HapticFeedback.mediumImpact();
      if (opponentMode.value == 1 && selectedFriend.value == null) {
        showPickFriendHint.value = true;
        return;
      }

      final profile = AuthService.instance.currentUser;
      final myName = profile?.displayName ?? 'Player';
      final myAvatar =
          profile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;

      final isFriendMode =
          opponentMode.value == 1 && selectedFriend.value != null;

      final config = withGameRules(MatchConfig(
        totalRounds: selectedRounds.value,
        roundDurationSeconds: selectedDuration.value,
        difficulty: selectedDifficulty.value,
        player1Name: myName,
        player1Avatar: myAvatar,
        player2Name:
            isFriendMode ? selectedFriend.value!.displayName : 'Opponent',
        player2Avatar:
            isFriendMode ? selectedFriend.value!.avatarEmoji : '⏳',
        player2Uid: isFriendMode ? selectedFriend.value?.uid : null,
        opponentFriend: isFriendMode ? selectedFriend.value : null,
        precreatedMatch: isFriendMode ? null : precreatedMatch.value,
      ));

      Navigator.of(context).pop(config);
    }

    String getStartButtonLabel() {
      if (opponentMode.value == 1) {
        if (selectedFriend.value != null) {
          return 'CHALLENGE ${selectedFriend.value!.displayName.toUpperCase()} ➔';
        }
        return 'SELECT A FRIEND TO CHALLENGE';
      }
      if (precreatedMatch.value != null) {
        return 'ENTER MATCH LOBBY ➔';
      }
      return 'CREATE 1V1 MATCH';
    }

    final profile = AuthService.instance.currentUser;
    final myName = profile?.displayName ?? 'Player';
    final myAvatar =
        profile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;

    return AppModalDialog(
      maxWidth: 390.0,
      scrollable: true,
      iconWidget: Icon(
        isArchery ? Icons.track_changes_rounded : Icons.sports_basketball_rounded,
        color: AppColors.accentAmber,
        size: 22.0,
      ),
      title: isArchery ? 'NEW ARCHERY MATCH' : 'NEW 1V1 MATCH',
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
              color: AppColors.surfaceTile,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: AppColors.borderInput),
            ),
            child: Row(
              children: [
                AppAvatar(
                  avatar: myAvatar,
                  size: 34.0,
                  borderColor: AppColors.accentElectricSky,
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
                          color: AppColors.textSubtle,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          myName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'HOST',
                  style: TextStyle(
                    color: AppColors.accentElectricSky,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // Which game (only in the shared match inbox). Locked once a
          // code exists, since that room was made for one game.
          if (showGamePicker) ...[
            Row(
              children: [
                _buildGameTab(
                  'basketball',
                  'BASKETBALL',
                  Icons.sports_basketball_rounded,
                  selectedGame,
                  locked: precreatedMatch.value != null,
                ),
                const SizedBox(width: 8.0),
                _buildGameTab(
                  'archery',
                  'ARCHERY',
                  Icons.track_changes_rounded,
                  selectedGame,
                  locked: precreatedMatch.value != null,
                ),
              ],
            ),
            const SizedBox(height: 14.0),
          ],

          // Opponent Mode Selector
          const Text(
            'OPPONENT',
            style: TextStyle(
              color: AppColors.textMuted,
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
            // The code card itself morphs into an inline error state with RETRY.
            InlineFeedbackSwitcher(
              child: codeError.value != null
                  ? InlineErrorPanel(
                      key: const ValueKey('code-error'),
                      title: 'MATCH CODE UNAVAILABLE',
                      message: codeError.value!,
                      onRetry: () => generateUpfrontCode(profile),
                      onDismiss: () => codeError.value = null,
                    )
                  : MatchCodeCard(
                      key: const ValueKey('code-card'),
                      precreatedMatch: precreatedMatch.value,
                      isGeneratingCode: isGeneratingCode.value,
                      codeCopied: codeCopied.value,
                      profile: profile,
                      onGenerateCode: () => generateUpfrontCode(profile),
                      onCopyCode: copyCode,
                      onShareCode: shareCode,
                    ),
            )
          else
            FriendSelectorRibbon(
              profile: profile,
              selectedFriend: selectedFriend.value,
              onFriendSelected: (friend) {
                selectedFriend.value = friend;
                showPickFriendHint.value = false;
              },
              onUseOpenCode: () => opponentMode.value = 0,
            ),
          const SizedBox(height: 18.0),

          if (!isArchery) ...[
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
          const SizedBox(height: 16.0),

          // Option 3: Shot Difficulty
          ValueListenableBuilder<ShotDifficulty>(
            valueListenable: selectedDifficulty,
            builder: (context, diff, _) {
              return DifficultySteppedSlider(
                value: diff,
                onChanged: (newDiff) => selectedDifficulty.value = newDiff,
                title: 'DIFFICULTY PRESET',
              );
            },
          ),
          const SizedBox(height: 20.0),
          ] else ...[
            const Text(
              'SETS OF 3 ARROWS · 50FT → 100FT → 150FT · FIRST TO 6 SET POINTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 16.0),
          ],

          // Inline validation hint (replaces the old floating SnackBar)
          InlineFeedbackSwitcher(
            child: (showPickFriendHint.value &&
                    opponentMode.value == 1 &&
                    selectedFriend.value == null)
                ? Padding(
                    key: const ValueKey('pick-friend'),
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: InlineErrorPanel(
                      icon: Icons.people_alt_rounded,
                      accent: AppColors.accentAmber,
                      title: 'PICK A FRIEND',
                      message:
                          'Select a friend to challenge above, or switch to Open Code.',
                      onDismiss: () => showPickFriendHint.value = false,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-hint')),
          ),

          // Primary Start Challenge Button
          AppPrimaryButton(
            label: getStartButtonLabel(),
            backgroundColor: AppColors.accentElectricSky,
            iconData: Icons.arrow_forward_rounded,
            onPressed: onStartPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildGameTab(
    String game,
    String label,
    IconData icon,
    ValueNotifier<String> selected, {
    required bool locked,
  }) {
    final isSelected = selected.value == game;
    final Color accent = game == 'archery'
        ? const Color(0xFF00FFCC)
        : AppColors.accentAmber;
    return Expanded(
      child: Opacity(
        opacity: locked && !isSelected ? 0.4 : 1.0,
        child: InkWell(
          onTap: locked
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  selected.value = game;
                },
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9.0),
            decoration: BoxDecoration(
              color: isSelected ? accent.withValues(alpha: 0.14) : AppColors.surfaceTile,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: isSelected ? accent : AppColors.borderInput,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15.0, color: isSelected ? accent : AppColors.textMuted),
                const SizedBox(width: 6.0),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 11.0,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                : AppColors.surfaceTile,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentElectricSky
                  : AppColors.borderInput,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14.0,
                  color: isSelected
                      ? AppColors.accentElectricSky
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 6.0),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 11.0,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
