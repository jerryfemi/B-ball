import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/ui/common/app_avatar.dart';
import '../physics/target_scoring.dart';
import '../state/archery_players.dart';
import '../state/archery_rules.dart';

/// Set result card (and, on the last set, the match result).
///
/// Set scoring: the higher set total earns 2 set points, a tie 1 each,
/// first to [ArcheryRules.pointsToWin]. Online, it moves on by itself after
/// [autoContinueSeconds] so neither archer is kept waiting.
class SetEndCard extends StatefulWidget {
  final int setIndex; // 0-indexed
  final List<ShotScore> userScores;
  final List<ShotScore> opponentScores;
  final int userSetPoints;
  final int opponentSetPoints;
  final bool isMatchOver;

  /// +1 you won the match, −1 they did, 0 draw (when [isMatchOver]).
  final int? winner;
  final ArcheryPlayer you;
  final ArcheryPlayer opponent;
  final String continueLabel;
  final VoidCallback onContinue;
  final int? autoContinueSeconds;

  const SetEndCard({
    super.key,
    required this.setIndex,
    required this.userScores,
    required this.opponentScores,
    required this.userSetPoints,
    required this.opponentSetPoints,
    required this.isMatchOver,
    required this.winner,
    required this.you,
    required this.opponent,
    required this.continueLabel,
    required this.onContinue,
    this.autoContinueSeconds,
  });

  @override
  State<SetEndCard> createState() => _SetEndCardState();
}

class _SetEndCardState extends State<SetEndCard> {
  Timer? _timer;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    final s = widget.autoContinueSeconds;
    if (s != null && !widget.isMatchOver) {
      _left = s;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          widget.onContinue();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const Color _you = Color(0xFF00FFCC);
  static const Color _them = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final int youTotal = w.userScores.fold(0, (s, a) => s + a.points);
    final int themTotal = w.opponentScores.fold(0, (s, a) => s + a.points);
    final bool setWon = youTotal > themTotal;
    final bool setTie = youTotal == themTotal;

    final String setLine = setTie
        ? 'TIE · +${ArcheryRules.pointsForSetTie} EACH'
        : (setWon
            ? 'YOU +${ArcheryRules.pointsForSetWin} SET POINTS'
            : '${w.opponent.name.toUpperCase()} +${ArcheryRules.pointsForSetWin} SET POINTS');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14.0),
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 18.0),
          decoration: BoxDecoration(
            color: const Color(0xF00F172A),
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(color: const Color(0xFF1E2638), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0xCC000000), blurRadius: 32.0, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (w.isMatchOver) ...[
                _MatchWinner(winner: w.winner ?? 0, opponentName: w.opponent.name),
                const SizedBox(height: 12.0),
              ],
              _Badge(
                text: w.isMatchOver
                    ? 'FINAL · SET ${w.setIndex + 1}'
                    : 'SET ${w.setIndex + 1} COMPLETE',
              ),
              const SizedBox(height: 14.0),
              Row(
                children: [
                  Expanded(child: _Side(player: w.you, ring: _you, scores: w.userScores)),
                  Column(
                    children: [
                      Text(
                        '$youTotal - $themTotal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30.0,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        setLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: setTie
                              ? const Color(0xFFF59E0B)
                              : (setWon ? _you : const Color(0xFFEF4444)),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Expanded(child: _Side(player: w.opponent, ring: _them, scores: w.opponentScores)),
                ],
              ),
              const SizedBox(height: 14.0),
              Text(
                'SET POINTS  ${w.userSetPoints} - ${w.opponentSetPoints}'
                '${w.isMatchOver ? '' : '  ·  FIRST TO ${ArcheryRules.pointsToWin}'}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
                height: 46.0,
                child: ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    w.onContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _you,
                    foregroundColor: const Color(0xFF0A0E1A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                  ),
                  child: Text(
                    _timer != null && _left > 0 ? '${w.continueLabel}  ·  $_left' : w.continueLabel,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Avatar, name and the three arrows of one archer.
class _Side extends StatelessWidget {
  final ArcheryPlayer player;
  final Color ring;
  final List<ShotScore> scores;

  const _Side({required this.player, required this.ring, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppAvatar(avatar: player.avatar, size: 46.0, borderColor: ring, borderWidth: 2.5),
        const SizedBox(height: 4.0),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6.0),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < ArcheryRules.arrowsPerSet; i++)
              _ArrowDot(score: i < scores.length ? scores[i] : null),
          ],
        ),
      ],
    );
  }
}

class _ArrowDot extends StatelessWidget {
  final ShotScore? score;
  const _ArrowDot({required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score;
    final Color c = s != null ? Color(s.colorValue) : const Color(0xFF475569);
    return Container(
      width: 24.0,
      height: 24.0,
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 1.6),
      ),
      child: Text(
        s?.displayLabel ?? '-',
        style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// Big trophy headline on the final card.
class _MatchWinner extends StatelessWidget {
  final int winner; // +1 you, −1 them, 0 draw
  final String opponentName;
  const _MatchWinner({required this.winner, required this.opponentName});

  @override
  Widget build(BuildContext context) {
    final bool draw = winner == 0;
    final bool userWon = winner > 0;
    final Color color = draw
        ? const Color(0xFF94A3B8)
        : (userWon ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final String text = draw
        ? 'DRAW'
        : (userWon ? 'YOU WIN!' : '${opponentName.toUpperCase()} WINS');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            userWon ? Icons.emoji_events_rounded : Icons.sports_score_rounded,
            color: color,
            size: 44.0,
            shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 18.0)],
          ),
          const SizedBox(height: 4.0),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 28.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 14.0)],
            ),
          ),
        ],
      ),
    );
  }
}
