import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/cloud_match.dart';
import '../../../models/match_invite.dart';
import '../../../models/player_descriptor.dart';
import '../../../providers/app_providers.dart';
import '../../../services/firestore_match_service.dart';
import '../common/app_avatar.dart';
import '../common/app_button.dart';
import '../common/app_colors.dart';
import '../common/app_modal_dialog.dart';

/// Modal dialog presented to a player when receiving an incoming 1v1 match challenge.
class IncomingChallengeDialog extends HookConsumerWidget {
  final MatchInvite invite;
  final ValueChanged<CloudMatch> onAccepted;
  final VoidCallback? onDeclined;

  const IncomingChallengeDialog({
    super.key,
    required this.invite,
    required this.onAccepted,
    this.onDeclined,
  });

  static Future<void> show({
    required BuildContext context,
    required MatchInvite invite,
    required ValueChanged<CloudMatch> onAccepted,
    VoidCallback? onDeclined,
  }) {
    return AppModalDialog.show<void>(
      context: context,
      builder: (ctx) => IncomingChallengeDialog(
        invite: invite,
        onAccepted: onAccepted,
        onDeclined: onDeclined,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    final isAccepting = useState(false);

    Future<void> handleAccept() async {
      if (isAccepting.value || user == null) return;
      isAccepting.value = true;
      HapticFeedback.mediumImpact();

      try {
        final joinedMatch = await FirestoreMatchService.instance
            .acceptMatchChallenge(
          invite: invite,
          recipientProfile: user,
        );

        if (context.mounted) {
          Navigator.of(context).pop();
          onAccepted(joinedMatch);
        }
      } catch (e) {
        if (context.mounted) {
          isAccepting.value = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to join match: $e'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
      }
    }

    Future<void> handleDecline() async {
      HapticFeedback.lightImpact();
      if (user != null) {
        await FirestoreMatchService.instance.declineMatchChallenge(
          myUid: user.uid,
          matchId: invite.matchId,
          hostUid: invite.hostUid,
        );
      }
      if (context.mounted) {
        Navigator.of(context).pop();
        onDeclined?.call();
      }
    }

    return AppModalDialog(
      maxWidth: 380.0,
      iconWidget: const Icon(
        Icons.sports_basketball_rounded,
        color: AppColors.accentAmber,
        size: 22.0,
      ),
      title: 'CHALLENGE RECEIVED!',
      subtitle: '${invite.hostName} challenged you to a 1v1 shootout',
      showCloseButton: true,
      onClose: handleDecline,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Head-to-Head Preview Capsule
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceTile,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: AppColors.borderInput),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Host Flank
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAvatar(
                        avatar: invite.hostAvatar,
                        size: 48.0,
                        borderColor: AppColors.accentElectricSky,
                        borderWidth: 2.0,
                      ),
                      const SizedBox(height: 6.0),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          invite.hostName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const Text(
                        'HOST',
                        style: TextStyle(
                          color: AppColors.accentElectricSky,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // VS Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.buttonDarkText,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.borderInput),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: AppColors.accentAmber,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ),

                // You Flank
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAvatar(
                        avatar: user?.avatarEmoji ??
                            PlayerDescriptor.defaultAvatar,
                        size: 48.0,
                        borderColor: AppColors.accentNeonCyan,
                        borderWidth: 2.0,
                      ),
                      const SizedBox(height: 6.0),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          user?.displayName ?? 'You',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const Text(
                        'YOU',
                        style: TextStyle(
                          color: AppColors.accentNeonCyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Match Format Specs Pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.buttonDarkText,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.borderInput),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${invite.totalRounds} ROUNDS • ${invite.roundDurationSeconds}s • ${invite.difficulty.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20.0),

          // Accept Action CTA
          AppPrimaryButton(
            label: isAccepting.value ? 'JOINING ROOM...' : 'ACCEPT CHALLENGE ➔',
            backgroundColor: AppColors.accentNeonCyan,
            foregroundColor: AppColors.buttonDarkText,
            iconData: Icons.sports_basketball_rounded,
            onPressed: isAccepting.value ? null : handleAccept,
          ),
          const SizedBox(height: 8.0),

          // Decline Action
          OutlinedButton(
            onPressed: isAccepting.value ? null : handleDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.borderInput),
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text(
              'DECLINE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.0,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
