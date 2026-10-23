import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../darts_constants.dart';
import '../state/darts_match_notifier.dart';
import '../state/darts_players.dart';

/// Match end summary card for solo and multiplayer Darts 301.
///
/// Follows DARTS_PLAN.md Step 12:
/// - Displays winner outcome (VICTORY, DEFEAT, DRAW) and decisive score difference.
/// - Shows remaining points and turns statistics for both players.
/// - Provides REMATCH (solo replay) and PLAY A FRIEND buttons.
class DartsResultCard extends ConsumerWidget {
  final VoidCallback onRematch;
  final VoidCallback? onPlayFriend;

  const DartsResultCard({
    super.key,
    required this.onRematch,
    this.onPlayFriend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(dartsMatchProvider);
    final players = ref.watch(dartsPlayersProvider);

    if (!match.matchOver) {
      return const SizedBox.shrink();
    }

    final int winner = match.winner ?? 0;
    final bool youWon = winner == 1;
    final bool draw = winner == 0;

    final Color outcomeColor = draw
        ? const Color(DartsK.accentP2)
        : (youWon
            ? const Color(DartsK.accentMint)
            : const Color(DartsK.accentRed));

    final String outcomeTitle = draw
        ? 'MATCH DRAW! 🤝'
        : (youWon ? 'VICTORY! 🏆' : 'BOT WINS');

    // Contextual explanation for the match conclusion
    final String outcomeDesc;
    if (match.yourRemaining == 0 && match.theirRemaining == 0) {
      if (match.yourLastDarts < match.theirLastDarts) {
        outcomeDesc =
            'Both checked out in round ${match.round}!\nYou won by dart count (${match.yourLastDarts} vs ${match.theirLastDarts}).';
      } else if (match.theirLastDarts < match.yourLastDarts) {
        outcomeDesc =
            'Both checked out in round ${match.round}!\nBot won by dart count (${match.theirLastDarts} vs ${match.yourLastDarts}).';
      } else {
        outcomeDesc =
            'Both checked out in round ${match.round} with ${match.yourLastDarts} darts each.';
      }
    } else if (youWon) {
      outcomeDesc = 'Checked out 301 in round ${match.round}!';
    } else if (winner == -1) {
      outcomeDesc = match.theirRemaining == 0
          ? 'Bot checked out 301 in round ${match.round}.'
          : 'Round 20 cap reached. Lower remaining score wins.';
    } else {
      outcomeDesc = 'Equal remaining points after 20 rounds.';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(DartsK.surfaceMid).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: outcomeColor.withValues(alpha: 0.60),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: outcomeColor.withValues(alpha: 0.18),
                blurRadius: 36.0,
                spreadRadius: 2.0,
              ),
              const BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 24.0,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Outcome Title & Description
              Text(
                outcomeTitle,
                style: TextStyle(
                  color: outcomeColor,
                  fontSize: 28.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                outcomeDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(DartsK.textMuted),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20.0),

              // 2. Score & Stats Comparison Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(DartsK.surfaceDark).withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: const Color(DartsK.surfaceCard),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Player 1
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            players.you.name.toUpperCase(),
                            style: const TextStyle(
                              color: Color(DartsK.accentP1),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            '${match.yourRemaining}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${301 - match.yourRemaining} pts scored',
                            style: const TextStyle(
                              color: Color(DartsK.textSubtle),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1.0,
                      height: 54.0,
                      color: const Color(DartsK.surfaceCard),
                    ),

                    // Player 2 / Bot
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            players.opponent.name.toUpperCase(),
                            style: const TextStyle(
                              color: Color(DartsK.accentP2),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            '${match.theirRemaining}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${301 - match.theirRemaining} pts scored',
                            style: const TextStyle(
                              color: Color(DartsK.textSubtle),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // 3. Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(DartsK.accentP1),
                        foregroundColor: const Color(DartsK.surfaceDark),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        elevation: 4,
                      ),
                      onPressed: onRematch,
                      child: const Text(
                        'REMATCH',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(DartsK.accentMint),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                      ),
                      onPressed: onPlayFriend ?? () {},
                      child: const Text(
                        'PLAY A FRIEND',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
