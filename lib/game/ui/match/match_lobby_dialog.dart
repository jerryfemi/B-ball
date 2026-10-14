import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../providers/app_providers.dart';
import '../../../services/firestore_match_service.dart';
import '../common/app_avatar.dart';
import '../common/app_colors.dart';
import '../common/app_modal_dialog.dart';
import 'components/match_lobby_vs_card.dart';

/// Pre-match lobby waiting room presented to the host while waiting for an opponent.
///
/// Automatically listens to live Firestore room updates and morphs into
/// the confirmed [MatchLobbyVsCard] with haptic feedback as soon as Player 2 enters.
class MatchLobbyDialog extends HookConsumerWidget {
  final CloudMatch initialMatch;
  final FriendProfile? challengedFriend;
  final VoidCallback? onCancel;
  final VoidCallback? onPlaySoloWhileWaiting;
  final ValueChanged<CloudMatch> onEnterArena;

  const MatchLobbyDialog({
    super.key,
    required this.initialMatch,
    this.challengedFriend,
    this.onCancel,
    this.onPlaySoloWhileWaiting,
    required this.onEnterArena,
  });

  static Future<void> show({
    required BuildContext context,
    required CloudMatch match,
    FriendProfile? challengedFriend,
    VoidCallback? onCancel,
    VoidCallback? onPlaySoloWhileWaiting,
    required ValueChanged<CloudMatch> onEnterArena,
  }) {
    return AppModalDialog.show<void>(
      context: context,
      builder: (ctx) => MatchLobbyDialog(
        initialMatch: match,
        challengedFriend: challengedFriend,
        onCancel: onCancel,
        onPlaySoloWhileWaiting: onPlaySoloWhileWaiting,
        onEnterArena: onEnterArena,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Live reactive match stream
    final streamedMatch = ref.watch(singleMatchProvider(initialMatch.id)).value;
    final currentMatch = streamedMatch ?? initialMatch;
    final isOpponentConnected = currentMatch.player2 != null;

    // 2. Pulse radar animation for waiting state
    final radarController = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    );

    useEffect(() {
      radarController.repeat(reverse: true);
      return null;
    }, const []);

    // 3. Auto-start countdown state when opponent joins
    final autoStartSeconds = useState(3);
    final hasAnnouncedHaptic = useRef(false);

    useEffect(() {
      if (isOpponentConnected) {
        if (!hasAnnouncedHaptic.value) {
          hasAnnouncedHaptic.value = true;
          HapticFeedback.heavyImpact();
        }

        final timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (autoStartSeconds.value > 1) {
            autoStartSeconds.value--;
          } else {
            t.cancel();
            if (context.mounted) {
              Navigator.of(context).pop();
              onEnterArena(currentMatch);
            }
          }
        });
        return timer.cancel;
      }
      return null;
    }, [isOpponentConnected]);

    // Copy join code helper
    final codeCopied = useState(false);
    Future<void> copyCode() async {
      await Clipboard.setData(ClipboardData(text: currentMatch.joinCode));
      HapticFeedback.lightImpact();
      codeCopied.value = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) codeCopied.value = false;
      });
    }

    Future<void> handleCancel() async {
      HapticFeedback.mediumImpact();
      if (challengedFriend != null) {
        await FirestoreMatchService.instance.cancelMatchChallenge(
          friendUid: challengedFriend!.uid,
          matchId: currentMatch.id,
        );
      }
      if (context.mounted) {
        Navigator.of(context).pop();
        onCancel?.call();
      }
    }

    return AppModalDialog(
      maxWidth: 390.0,
      iconWidget: Icon(
        isOpponentConnected
            ? Icons.sports_basketball_rounded
            : Icons.radar_rounded,
        color: isOpponentConnected
            ? AppColors.accentNeonCyan
            : AppColors.accentElectricSky,
        size: 22.0,
      ),
      title: isOpponentConnected
          ? 'MATCHUP CONFIRMED'
          : (challengedFriend != null ? 'CHALLENGE DISPATCHED' : 'MATCH LOBBY'),
      subtitle: isOpponentConnected
          ? 'Opponent entered the room'
          : (challengedFriend != null
                ? 'Waiting for ${challengedFriend!.displayName} to accept'
                : 'Share 6-digit code or wait for challenger'),
      showCloseButton: true,
      onClose: handleCancel,
      child: isOpponentConnected
          ? MatchLobbyVsCard(
              match: currentMatch,
              autoStartSeconds: autoStartSeconds.value,
              onEnterArena: () {
                Navigator.of(context).pop();
                onEnterArena(currentMatch);
              },
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Radar Avatar Visualization
                Center(
                  child: AnimatedBuilder(
                    animation: radarController,
                    builder: (context, child) {
                      final scale = 1.0 + (radarController.value * 0.12);
                      final glow = (0.2 + (radarController.value * 0.4)).clamp(
                        0.0,
                        1.0,
                      );
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 88.0 * scale,
                            height: 88.0 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentElectricSky.withValues(
                                  alpha: glow,
                                ),
                                width: 2.0,
                              ),
                            ),
                          ),
                          AppAvatar(
                            avatar:
                                challengedFriend?.avatarEmoji ??
                                'assets/avatars/dunk_heads (2).webp',
                            size: 64.0,
                            borderColor: AppColors.accentElectricSky,
                            borderWidth: 2.0,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Waiting Status Pill (Scalable on narrow mobile)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTile,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: AppColors.borderInput),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 10.0,
                          height: 10.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: AppColors.accentElectricSky,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Flexible(
                          child: Text(
                            challengedFriend != null
                                ? 'Waiting for ${challengedFriend!.displayName}...'
                                : 'Waiting for challenger...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // Monospace Join Code Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.buttonDarkText,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: AppColors.borderInput),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ROOM JOIN CODE',
                              style: TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                currentMatch.joinCode,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4.0,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton.icon(
                        onPressed: copyCode,
                        icon: Icon(
                          codeCopied.value
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          size: 14.0,
                        ),
                        label: Text(
                          codeCopied.value ? 'COPIED' : 'COPY',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: codeCopied.value
                              ? AppColors.accentEmerald
                              : AppColors.surfaceTile,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            side: BorderSide(
                              color: codeCopied.value
                                  ? AppColors.accentEmerald
                                  : AppColors.accentElectricSky,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),

                // Secondary Play Solo While Waiting (Optional convenience for host)
                if (onPlaySoloWhileWaiting != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPlaySoloWhileWaiting?.call();
                    },
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.accentElectricSky,
                      size: 18.0,
                    ),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'SHOOT ROUND 1 WHILE WAITING ➔',
                        style: TextStyle(
                          color: AppColors.accentElectricSky,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                ],

                // Cancel Button
                OutlinedButton(
                  onPressed: handleCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: Color(0xFF7F1D1D)),
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    'CANCEL CHALLENGE',
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
