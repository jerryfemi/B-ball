import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery_constants.dart';
import '../state/archery_match_notifier.dart';
import '../state/archery_match_state.dart';
import '../state/archery_players.dart';

/// "SET 2 · 100ft — YOUR TURN" / "WATCHING NAME", shown for a moment
/// whenever a new turn starts online.
class TurnBanner extends ConsumerStatefulWidget {
  const TurnBanner({super.key});

  @override
  ConsumerState<TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends ConsumerState<TurnBanner> {
  int _shownId = 0;
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final (id, setIndex, shooter, setOver) = ref.watch(
      archeryMatchProvider.select((s) => (s.bannerId, s.setIndex, s.shooter, s.setOver)),
    );
    final name = ref.watch(archeryPlayersProvider.select((p) => p.opponent.name));

    if (id != _shownId && id > 0) {
      _shownId = id;
      _visible = true;
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted && _shownId == id) setState(() => _visible = false);
      });
    }
    final bool mine = shooter == ArcheryShooter.you;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      opacity: _visible && !setOver ? 1.0 : 0.0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: const Color(0xE60A0E1A),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: (mine ? const Color(0xFF00FFCC) : const Color(0xFFA78BFA))
                  .withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SET ${setIndex + 1}  ·  ${ArcheryK.distanceLabelForSet(setIndex)}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                mine ? 'YOUR TURN' : 'WATCHING ${name.toUpperCase()}',
                style: TextStyle(
                  color: mine ? const Color(0xFF00FFCC) : const Color(0xFFA78BFA),
                  fontSize: 24.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
