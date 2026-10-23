import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../darts_constants.dart';
import '../state/darts_match_notifier.dart';
import '../state/darts_match_state.dart';
import '../state/darts_players.dart';

/// Animated turn transition banner.
///
/// Follows DARTS_PLAN.md Step 12:
/// - Displays "ROUND N · YOUR TURN" or "BOT'S TURN".
/// - Displays "LAST CHANCE" when Player 1 has checked out and the bot can still tie
///   under the equal-turns rule.
/// - Sleek dark glassmorphism card with glowing accent border.
/// - Auto-hides smoothly after 2.0 seconds.
class DartsTurnBanner extends ConsumerStatefulWidget {
  const DartsTurnBanner({super.key});

  @override
  ConsumerState<DartsTurnBanner> createState() => _DartsTurnBannerState();
}

class _DartsTurnBannerState extends ConsumerState<DartsTurnBanner> {
  int _lastBannerId = -1;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(dartsMatchProvider);
    final opponentName = ref.watch(
      dartsPlayersProvider.select((p) => p.opponent.name),
    );

    if (match.bannerId != _lastBannerId && match.bannerId > 0) {
      _lastBannerId = match.bannerId;
      _visible = true;
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _visible = false);
      });
    }

    if (match.matchOver) {
      return const SizedBox.shrink();
    }

    final bool isYou = match.thrower == DartsThrower.you;
    final bool isLastChance =
        !isYou && match.yourRemaining == 0 && match.theirRemaining <= 180;

    final Color accentColor = isLastChance
        ? const Color(DartsK.accentP2) // Gold / Amber for Last Chance
        : (isYou
            ? const Color(DartsK.accentP1) // Sky blue for You
            : const Color(DartsK.accentP2)); // Amber for Bot

    final String headline = isLastChance
        ? 'LAST CHANCE'
        : (isYou ? 'YOUR TURN' : 'BOT\'S TURN');

    final String subline = isLastChance
        ? 'EQUAL TURNS · BOT CAN STILL TIE'
        : (isYou
            ? 'ROUND ${match.round}  ·  3 DARTS'
            : 'ROUND ${match.round}  ·  WATCHING ${opponentName.toUpperCase()}');

    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: _visible ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: const Color(DartsK.surfaceDark).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.70),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 28.0,
                  spreadRadius: 1.0,
                ),
                const BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 18.0,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subline,
                  style: TextStyle(
                    color: isLastChance
                        ? const Color(DartsK.accentP2)
                        : const Color(DartsK.textMuted),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  headline,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 26.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
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
