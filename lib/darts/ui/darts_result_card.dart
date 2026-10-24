import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../darts_constants.dart';
import '../state/darts_match_notifier.dart';
import '../state/darts_match_state.dart';
import '../state/darts_players.dart';

/// End-of-match card for Darts 301 (solo vs the bot, or a live 1v1).
///
/// - A medallion and the result ("YOU WIN", "DARTBOT WINS", "DRAW") with
///   one line on how it was decided.
/// - Both players side by side: avatar (winner crowned), points left, and a
///   bar showing how much of the 301 they knocked off.
/// - Three quick stats each: 3-dart average, best turn, tons (100+ turns).
/// - REMATCH, then CHALLENGE A FRIEND (solo) or BACK TO SOLO (online).
/// - Pops in with a short scale and fade.
class DartsResultCard extends ConsumerWidget {
  final VoidCallback onRematch;
  final VoidCallback? onPlayFriend;

  /// Live 1v1: name the opponent instead of the bot, and relabel the buttons.
  final bool online;

  const DartsResultCard({
    super.key,
    required this.onRematch,
    this.onPlayFriend,
    this.online = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(dartsMatchProvider);
    final players = ref.watch(dartsPlayersProvider);
    if (!match.matchOver) return const SizedBox.shrink();

    final int winner = match.winner ?? 0; // 1 you, -1 opponent, 0 draw
    final bool youWon = winner == 1;
    final bool draw = winner == 0;
    final String opp = players.opponent.name;

    final Color accent = draw
        ? const Color(DartsK.accentP2)
        : (youWon ? const Color(DartsK.accentMint) : const Color(DartsK.accentRed));
    final String title =
        draw ? 'DRAW' : (youWon ? 'YOU WIN' : '${opp.toUpperCase()} WINS');
    final IconData medal = draw
        ? Icons.handshake_rounded
        : (youWon ? Icons.emoji_events_rounded : Icons.gps_fixed_rounded);

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xB3000000))),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 18.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFA111A2E), Color(0xFA0A0E1A)],
                    ),
                    borderRadius: BorderRadius.circular(26.0),
                    border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 40.0),
                      const BoxShadow(
                        color: Color(0xCC000000),
                        blurRadius: 28.0,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Medallion + result ─────────────────────────────
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: Center(child: _Medallion(icon: medal, color: accent)),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: Column(
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 30.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                shadows: [
                                  Shadow(color: accent.withValues(alpha: 0.45), blurRadius: 18.0),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              _howItEnded(match, winner, opp),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(DartsK.textMuted),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Players ───────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _PlayerColumn(
                              player: players.you,
                              color: const Color(DartsK.accentP1),
                              remaining: match.yourRemaining,
                              turns: match.yourTurns,
                              crowned: youWon,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 22.0),
                            child: Text(
                              'VS',
                              style: TextStyle(
                                color: Color(DartsK.textSubtle),
                                fontSize: 12.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _PlayerColumn(
                              player: players.opponent,
                              color: const Color(DartsK.accentP2),
                              remaining: match.theirRemaining,
                              turns: match.theirTurns,
                              crowned: winner == -1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22.0),

                      // ── Buttons ───────────────────────────────────────
                      _CardButton(
                        label: 'REMATCH',
                        icon: Icons.replay_rounded,
                        primary: true,
                        onTap: onRematch,
                      ),
                      if (onPlayFriend != null) ...[
                        const SizedBox(height: 10.0),
                        _CardButton(
                          label: online ? 'BACK TO SOLO' : 'CHALLENGE A FRIEND',
                          icon: online ? Icons.person_rounded : Icons.people_alt_rounded,
                          onTap: onPlayFriend!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _howItEnded(DartsMatchState m, int winner, String opp) {
    if (m.forfeitWinner != null) {
      return winner == 1 ? '$opp left the match. The win is yours.' : 'You left the match.';
    }
    if (m.yourRemaining == 0 && m.theirRemaining == 0) {
      if (m.yourLastDarts == m.theirLastDarts) {
        return 'Both checked out in round ${m.round} with ${m.yourLastDarts} darts each.';
      }
      final bool you = m.yourLastDarts < m.theirLastDarts;
      return 'Both checked out in round ${m.round}. ${you ? 'You' : opp} needed fewer darts '
          '(${math.min(m.yourLastDarts, m.theirLastDarts)} vs ${math.max(m.yourLastDarts, m.theirLastDarts)}).';
    }
    if (winner == 1) return 'You checked out 301 in round ${m.round}.';
    if (winner == -1) {
      return m.theirRemaining == 0
          ? '$opp checked out 301 in round ${m.round}.'
          : 'Round ${DartsK.maxRounds} reached: fewer points left wins.';
    }
    return 'Same points left after ${DartsK.maxRounds} rounds.';
  }
}

/// Round glowing badge that sits half above the card.
class _Medallion extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Medallion({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64.0,
      height: 64.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), const Color(DartsK.surfaceMid)],
        ),
        border: Border.all(color: color, width: 2.0),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 22.0)],
      ),
      child: Icon(icon, color: color, size: 30.0),
    );
  }
}

/// One player's side: avatar, name, points left, progress, quick stats.
class _PlayerColumn extends StatelessWidget {
  final DartsPlayer player;
  final Color color;
  final int remaining;
  final List<int> turns;
  final bool crowned;

  const _PlayerColumn({
    required this.player,
    required this.color,
    required this.remaining,
    required this.turns,
    required this.crowned,
  });

  @override
  Widget build(BuildContext context) {
    final int scored = DartsK.startScore - remaining;
    final double progress = (scored / DartsK.startScore).clamp(0.0, 1.0).toDouble();
    final int best = turns.isEmpty ? 0 : turns.reduce(math.max);
    final double avg = turns.isEmpty ? 0.0 : scored / turns.length;
    final int tons = turns.where((t) => t >= 100).length;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AppAvatar(
              avatar: player.avatar,
              size: 52.0,
              borderColor: crowned ? const Color(0xFFF59E0B) : color.withValues(alpha: 0.6),
              borderWidth: crowned ? 2.5 : 1.5,
            ),
            if (crowned)
              const Positioned(
                top: -16.0,
                child: Text('👑', style: TextStyle(fontSize: 18.0)),
              ),
          ],
        ),
        const SizedBox(height: 8.0),
        Text(
          player.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          '$remaining',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36.0,
            fontWeight: FontWeight.w900,
            height: 1.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const Text(
          'LEFT',
          style: TextStyle(
            color: Color(DartsK.textSubtle),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.0),
            child: SizedBox(
              height: 5.0,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(DartsK.surfaceCard),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10.0),
        _Stat(label: 'AVG', value: avg.toStringAsFixed(1)),
        _Stat(label: 'BEST TURN', value: '$best'),
        _Stat(label: 'TONS', value: '$tons'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(DartsK.textSubtle),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12.0,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _CardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.0,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        icon: Icon(icon, size: 18.0),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary ? const Color(DartsK.accentP1) : const Color(DartsK.surfaceCard),
          foregroundColor: primary ? const Color(DartsK.surfaceDark) : Colors.white,
          side: primary ? null : const BorderSide(color: Color(0x2EFFFFFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
        ),
      ),
    );
  }
}
