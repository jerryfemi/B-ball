import 'package:flutter/material.dart';
import '../physics/target_scoring.dart';

/// Large dark translucent Set End Card displayed over the target (Build Plan v2 §8.4 & §9).
///
/// Features:
/// - Displays "SET n  29 - 25" with avatars.
/// - Set points won indicators (gold coins under avatars).
/// - Clean continue / next set action button.
class SetEndCard extends StatelessWidget {
  final int setIndex; // 0-indexed
  final List<ShotScore> userScores;
  final int opponentTotal;
  final int userSetPoints;
  final int opponentSetPoints;
  final bool isMatchOver;
  final VoidCallback onContinue;

  const SetEndCard({
    super.key,
    required this.setIndex,
    required this.userScores,
    required this.opponentTotal,
    required this.userSetPoints,
    required this.opponentSetPoints,
    required this.isMatchOver,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final int userTotal = userScores.fold(0, (sum, s) => sum + s.points);

    final bool userWon = userTotal > opponentTotal;
    final bool isTie = userTotal == opponentTotal;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
          decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFF1E283D), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 36.0,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMatchOver) ...[
              _MatchWinner(
                userWon: userSetPoints > opponentSetPoints,
                draw: userSetPoints == opponentSetPoints,
              ),
              const SizedBox(height: 14.0),
            ],
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E283D),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                isMatchOver ? 'MATCH FINISHED' : 'SET ${setIndex + 1} COMPLETE',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Avatars & Score Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // User Column
                Column(
                  children: [
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981), width: 2.0),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Gold Coin Set Points
                    _buildCoinRow(userSetPoints, const Color(0xFF10B981)),
                  ],
                ),

                // Center Score Display
                Column(
                  children: [
                    Text(
                      '$userTotal - $opponentTotal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      userWon
                          ? '+1 SET POINT'
                          : (isTie ? 'TIE (+1 EACH)' : 'OPPONENT SET POINT'),
                      style: TextStyle(
                        color: userWon
                            ? const Color(0xFF10B981)
                            : (isTie ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),

                // Opponent Column
                Column(
                  children: [
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF8B5CF6), width: 2.0),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'BOT',
                        style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    _buildCoinRow(opponentSetPoints, const Color(0xFF8B5CF6)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // 3 Arrows Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (idx) {
                final score = idx < userScores.length ? userScores[idx] : null;
                final String label = score?.displayLabel ?? '-';
                final Color ringColor = score != null
                    ? Color(score.colorValue)
                    : const Color(0xFF475569);

                return Container(
                  width: 44.0,
                  height: 44.0,
                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 2.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ringColor,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24.0),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  foregroundColor: const Color(0xFF0A0E1A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  isMatchOver ? 'PLAY AGAIN' : 'NEXT SET',
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

  Widget _buildCoinRow(int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final bool earned = i < count;
        return Container(
          width: 10.0,
          height: 10.0,
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            color: earned ? const Color(0xFFF59E0B) : const Color(0xFF1E283D),
            shape: BoxShape.circle,
            border: Border.all(
              color: earned ? const Color(0xFFFBBF24) : const Color(0xFF334155),
              width: 1.0,
            ),
          ),
        );
      }),
    );
  }
}


/// Big trophy headline on the final card.
class _MatchWinner extends StatelessWidget {
  final bool userWon;
  final bool draw;
  const _MatchWinner({required this.userWon, required this.draw});

  @override
  Widget build(BuildContext context) {
    final Color color = draw
        ? const Color(0xFF94A3B8)
        : (userWon ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final String text = draw ? 'DRAW' : (userWon ? 'YOU WIN!' : 'BOT WINS');
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
            size: 46.0,
            shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 18.0)],
          ),
          const SizedBox(height: 4.0),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 30.0,
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
