import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery_game.dart';
import '../state/archery_match_notifier.dart';
import '../state/archery_match_state.dart';
import '../state/archery_players.dart';
import 'claim_button.dart';
import 'pulse.dart';

/// Online status under the scoreboard: your shot clock, or what the
/// opponent is doing. Archery's own pill (not basketball's).
class LivePill extends ConsumerWidget {
  final ArcheryGame game;

  const LivePill({super.key, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = game.online;
    if (online == null) return const SizedBox.shrink();
    final status = ref.watch(archeryMatchProvider.select((s) => s.liveStatus));
    final code = ref.watch(archeryMatchProvider.select((s) => s.joinCode));
    final name = ref.watch(archeryPlayersProvider.select((p) => p.opponent.name));

    return ValueListenableBuilder<int>(
      valueListenable: online.shotClock,
      builder: (context, secs, _) {
        final String clock = secs >= 0 ? '  ·  ${secs}s' : '';
        final (IconData icon, Color color, String text, bool pulse) = switch (status) {
          ArcheryLiveStatus.none => (Icons.circle, const Color(0x00000000), '', false),
          ArcheryLiveStatus.waitingToJoin =>
            (Icons.hourglass_top_rounded, const Color(0xFFF59E0B), 'WAITING FOR AN OPPONENT  ·  CODE $code', true),
          ArcheryLiveStatus.yourShot =>
            (Icons.my_location_rounded, const Color(0xFF00FFCC), 'YOUR SHOT$clock', secs >= 0 && secs <= 5),
          ArcheryLiveStatus.submitting =>
            (Icons.cloud_upload_rounded, const Color(0xFF38BDF8), 'SENDING YOUR SET…', true),
          ArcheryLiveStatus.waitingForShot =>
            (Icons.visibility_rounded, const Color(0xFFA78BFA), 'WAITING FOR ${name.toUpperCase()}\'S SHOT$clock', false),
          ArcheryLiveStatus.opponentDrawing =>
            (Icons.gps_fixed_rounded, const Color(0xFFA78BFA), '${name.toUpperCase()} IS DRAWING…', true),
          ArcheryLiveStatus.reconnecting =>
            (Icons.wifi_off_rounded, const Color(0xFFF59E0B), 'RECONNECTING TO ${name.toUpperCase()}…', true),
          ArcheryLiveStatus.opponentGone =>
            (Icons.flag_rounded, const Color(0xFFEF4444), '${name.toUpperCase()} LEFT THE RANGE', false),
        };
        if (text.isEmpty) return const SizedBox.shrink();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(status),
            padding: const EdgeInsets.fromLTRB(12.0, 6.0, 6.0, 6.0),
            decoration: BoxDecoration(
              color: const Color(0xD90A0E1A),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pulse(enabled: pulse, child: Icon(icon, size: 13.0, color: color)),
                const SizedBox(width: 7.0),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (status == ArcheryLiveStatus.opponentGone) ...[
                  const SizedBox(width: 8.0),
                  ClaimButton(onClaim: online.claimWin),
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
