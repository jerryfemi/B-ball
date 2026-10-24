import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../archery/ui/claim_button.dart';
import '../../archery/ui/pulse.dart';
import '../darts_constants.dart';
import '../online/darts_online_controller.dart';
import '../state/darts_match_notifier.dart';
import '../state/darts_match_state.dart';
import '../state/darts_players.dart';

/// Online status under the top bar: your shot clock, or what the opponent is
/// doing. Hidden in solo play.
class DartsLivePill extends ConsumerWidget {
  final DartsOnlineController? online;

  const DartsLivePill({super.key, required this.online});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = online;
    if (ctrl == null) return const SizedBox.shrink();
    final status = ref.watch(dartsMatchProvider.select((s) => s.liveStatus));
    final code = ref.watch(dartsMatchProvider.select((s) => s.joinCode));
    final name = ref.watch(dartsPlayersProvider.select((p) => p.opponent.name));
    final String who = name.toUpperCase();

    return ValueListenableBuilder<int>(
      valueListenable: ctrl.shotClock,
      builder: (context, secs, _) {
        final String clock = secs >= 0 ? '  ·  ${secs}s' : '';
        final (IconData icon, Color color, String text, bool pulse) = switch (status) {
          DartsLiveStatus.none => (Icons.circle, const Color(0x00000000), '', false),
          DartsLiveStatus.waitingToJoin => (
              Icons.hourglass_top_rounded,
              const Color(DartsK.accentP2),
              'WAITING FOR AN OPPONENT  ·  CODE $code',
              true,
            ),
          DartsLiveStatus.yourShot => (
              Icons.my_location_rounded,
              const Color(DartsK.accentMint),
              'YOUR THROW$clock',
              secs >= 0 && secs <= 5,
            ),
          DartsLiveStatus.submitting => (
              Icons.cloud_upload_rounded,
              const Color(DartsK.accentP1),
              'SENDING YOUR TURN…',
              true,
            ),
          DartsLiveStatus.waitingForShot => (
              Icons.visibility_rounded,
              const Color(DartsK.textMuted),
              'WAITING FOR $who$clock',
              false,
            ),
          DartsLiveStatus.reconnecting => (
              Icons.wifi_off_rounded,
              const Color(DartsK.accentP2),
              'RECONNECTING TO $who…',
              true,
            ),
          DartsLiveStatus.opponentGone => (
              Icons.flag_rounded,
              const Color(DartsK.accentRed),
              '$who LEFT THE GAME',
              false,
            ),
        };
        if (text.isEmpty) return const SizedBox.shrink();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(status),
            padding: const EdgeInsets.fromLTRB(10.0, 5.0, 6.0, 5.0),
            decoration: BoxDecoration(
              color: const Color(0xE60A0E1A),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pulse(enabled: pulse, child: Icon(icon, size: 12.0, color: color)),
                const SizedBox(width: 6.0),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (status == DartsLiveStatus.opponentGone) ...[
                  const SizedBox(width: 8.0),
                  ClaimButton(onClaim: ctrl.claimWin),
                ] else
                  const SizedBox(width: 6.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
