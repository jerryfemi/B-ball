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
import '../common/app_colors.dart';
import '../common/clean_ui.dart';
import '../common/difficulty_stepped_slider.dart';
import '../common/inline_feedback.dart';
import '../inbox/join_match_dialog.dart';
import 'components/friend_selector_ribbon.dart';

/// "Play a friend": create a 1v1 match (share a code or challenge a friend)
/// or join one with a code. Same clean look as the archery pause menu, for
/// both games.
///
/// Returns the chosen [MatchConfig]; if the player joined a match instead,
/// [MatchConfig.joinedMatch] is set and the caller just opens it.
class MatchSetupDialog extends HookWidget {
  final MatchConfig initialConfig;

  /// Shows a HOOPS / ARCHERY switch at the top (the shared match inbox).
  /// Off when a game opens the dialog for itself.
  final bool showGamePicker;

  /// Offers "Join with a code" (off where joining makes no sense, e.g. the
  /// pass-and-play settings).
  final bool allowJoin;

  const MatchSetupDialog({
    super.key,
    this.initialConfig = const MatchConfig(),
    this.showGamePicker = false,
    this.allowJoin = true,
  });

  static Future<MatchConfig?> show(
    BuildContext context, {
    MatchConfig initialConfig = const MatchConfig(),
    bool showGamePicker = false,
    bool allowJoin = true,
  }) {
    return CleanUi.show<MatchConfig>(
      context,
      (context) => MatchSetupDialog(
        initialConfig: initialConfig,
        showGamePicker: showGamePicker,
        allowJoin: allowJoin,
      ),
    );
  }

  static const Color _hoops = Color(0xFFF59E0B);

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

    Future<void> joinWithCode() async {
      final joined = await JoinMatchDialog.show(context);
      if (joined != null && context.mounted) {
        Navigator.of(context).pop(MatchConfig(game: joined.game, joinedMatch: joined));
      }
    }

    // Share-a-code mode: the primary button first gets the code, then opens
    // the waiting room. Friend mode: it sends the challenge.
    final bool codeMode = opponentMode.value == 0;
    final bool hasCode = precreatedMatch.value != null;
    String primaryLabel() {
      if (!codeMode) {
        final f = selectedFriend.value;
        return f == null ? 'PICK A FRIEND' : 'CHALLENGE ${f.displayName.toUpperCase()}';
      }
      return hasCode ? 'ENTER MATCH LOBBY' : 'GET MATCH CODE';
    }

    void onPrimary() {
      if (codeMode && !hasCode) {
        generateUpfrontCode(AuthService.instance.currentUser);
        return;
      }
      onStartPressed();
    }

    final profile = AuthService.instance.currentUser;
    final Color gameAccent = isArchery ? CleanUi.accent : _hoops;

    return CleanDialog(
      title: 'PLAY A FRIEND',
      subtitle: isArchery
          ? 'Archery 1v1: sets of 3 arrows, first to 6 set points'
          : 'Hoops 1v1: take turns, highest total wins',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Which game (shared inbox only). Locked once a code exists,
          // since that room was made for one game.
          if (showGamePicker) ...[
            CleanSegmented<String>(
              segments: const [
                CleanSegment('basketball', 'HOOPS', icon: Icons.sports_basketball_rounded),
                CleanSegment('archery', 'ARCHERY', icon: Icons.track_changes_rounded),
              ],
              selected: selectedGame.value,
              accent: gameAccent,
              onChanged: hasCode ? null : (g) => selectedGame.value = g,
            ),
            const SizedBox(height: 10.0),
          ],

          CleanSegmented<int>(
            segments: const [
              CleanSegment(0, 'SHARE A CODE', icon: Icons.tag_rounded),
              CleanSegment(1, 'A FRIEND', icon: Icons.people_alt_rounded),
            ],
            selected: opponentMode.value,
            onChanged: (m) => opponentMode.value = m,
          ),
          const SizedBox(height: 14.0),

          if (codeMode)
            InlineFeedbackSwitcher(
              child: codeError.value != null
                  ? InlineErrorPanel(
                      key: const ValueKey('code-error'),
                      title: 'MATCH CODE UNAVAILABLE',
                      message: codeError.value!,
                      onRetry: () => generateUpfrontCode(profile),
                      onDismiss: () => codeError.value = null,
                    )
                  : hasCode
                      ? _CodeReveal(
                          key: const ValueKey('code'),
                          code: precreatedMatch.value!.joinCode,
                          copied: codeCopied.value,
                          onCopy: copyCode,
                          onShare: shareCode,
                        )
                      : const Padding(
                          key: ValueKey('code-help'),
                          padding: EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            'Get a 6-character code and send it to anyone. '
                            'They enter it with "Join with a code".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: CleanUi.muted, fontSize: 12.5, height: 1.4),
                          ),
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
          const SizedBox(height: 16.0),

          if (!isArchery) ...[
            CleanRow(
              icon: Icons.repeat_rounded,
              label: 'ROUNDS',
              iconColor: _hoops,
              trailing: CleanSegmented<int>(
                segments: [for (final r in _roundOptions) CleanSegment(r, '$r')],
                selected: selectedRounds.value,
                accent: _hoops,
                onChanged: (r) => selectedRounds.value = r,
              ),
            ),
            CleanRow(
              icon: Icons.timer_outlined,
              label: 'CLOCK',
              iconColor: _hoops,
              trailing: CleanSegmented<int>(
                segments: [for (final d in _durationOptions) CleanSegment(d, '${d}s')],
                selected: selectedDuration.value,
                accent: _hoops,
                onChanged: (d) => selectedDuration.value = d,
              ),
            ),
            ValueListenableBuilder<ShotDifficulty>(
              valueListenable: selectedDifficulty,
              builder: (context, diff, _) => DifficultySteppedSlider(
                value: diff,
                onChanged: (newDiff) => selectedDifficulty.value = newDiff,
                title: 'DIFFICULTY',
              ),
            ),
            const SizedBox(height: 14.0),
          ],

          // Inline validation hint (replaces the old floating SnackBar)
          InlineFeedbackSwitcher(
            child: (showPickFriendHint.value && !codeMode && selectedFriend.value == null)
                ? Padding(
                    key: const ValueKey('pick-friend'),
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: InlineErrorPanel(
                      icon: Icons.people_alt_rounded,
                      accent: AppColors.accentAmber,
                      title: 'PICK A FRIEND',
                      message: 'Select a friend above, or share a code instead.',
                      onDismiss: () => showPickFriendHint.value = false,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-hint')),
          ),

          CleanButton(
            label: primaryLabel(),
            icon: codeMode
                ? (hasCode ? Icons.arrow_forward_rounded : Icons.tag_rounded)
                : Icons.send_rounded,
            primary: true,
            accent: gameAccent,
            loading: isGeneratingCode.value,
            onTap: onPrimary,
          ),
          if (allowJoin) ...[
            const SizedBox(height: 8.0),
            CleanButton(
              label: 'JOIN WITH A CODE',
              icon: Icons.login_rounded,
              onTap: joinWithCode,
            ),
          ],
        ],
      ),
    );
  }
}

/// The match code, big, with COPY and SHARE (copy confirms in place with
/// "✓ CODE COPIED").
class _CodeReveal extends StatelessWidget {
  final String code;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _CodeReveal({
    super.key,
    required this.code,
    required this.copied,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SelectableText(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CleanUi.accent,
            fontSize: 34.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 8.0,
          ),
        ),
        const SizedBox(height: 4.0),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            copied ? '✓ CODE COPIED' : 'Send this code to your opponent',
            key: ValueKey(copied),
            style: TextStyle(
              color: copied ? CleanUi.accent : CleanUi.muted,
              fontSize: 11.5,
              fontWeight: copied ? FontWeight.w900 : FontWeight.w500,
              letterSpacing: copied ? 0.8 : 0.0,
              shadows: copied
                  ? const [Shadow(color: Color(0x8800FFCC), blurRadius: 10.0)]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10.0),
        Row(
          children: [
            Expanded(
              child: CleanButton(label: 'COPY', icon: Icons.copy_rounded, onTap: onCopy),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: CleanButton(label: 'SHARE', icon: Icons.ios_share_rounded, onTap: onShare),
            ),
          ],
        ),
      ],
    );
  }
}
