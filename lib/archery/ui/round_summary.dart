import 'package:flutter/material.dart';
import '../physics/target_scoring.dart';

/// Modal card displayed at the conclusion of each 3-arrow round.
class RoundSummaryCard extends StatelessWidget {
  final int roundIndex; // 0, 1, 2
  final double distance;
  final List<ShotScore> roundScores;
  final int totalScore;
  final int totalXCount;
  final bool isMatchOver;
  final VoidCallback onContinue;

  const RoundSummaryCard({
    super.key,
    required this.roundIndex,
    required this.distance,
    required this.roundScores,
    required this.totalScore,
    required this.totalXCount,
    required this.isMatchOver,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final int roundSubtotal = roundScores.fold(0, (sum, s) => sum + s.points);
    final int roundXCount = roundScores.where((s) => s.isX).length;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFF1E2638), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 32.0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                isMatchOver ? 'FINAL RESULTS' : 'ROUND ${roundIndex + 1} OF 3',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Main Title
            Text(
              isMatchOver ? 'MATCH COMPLETE' : '${distance.toInt()}m ROUND END',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 20.0),

            // 3 Arrow Badges for this round
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final ShotScore? score =
                    index < roundScores.length ? roundScores[index] : null;
                final String label = score?.displayLabel ?? '-';
                final Color ringColor = score != null
                    ? Color(score.colorValue)
                    : const Color(0xFF475569);

                return Container(
                  width: 54.0,
                  height: 54.0,
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withValues(alpha: 0.3),
                        blurRadius: 10.0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ringColor,
                      fontSize: 22.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16.0),

            // Round Points Breakdown
            Text(
              'Round: $roundSubtotal / 30 pts  •  $roundXCount X',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20.0),

            // Total Score Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFF1E2638)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL SCORE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$totalScore',
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
                          fontSize: 26.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ' / ${(roundIndex + 1) * 30}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: const Color(0x33F7D000),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          '$totalXCount X',
                          style: const TextStyle(
                            color: Color(0xFFF7D000),
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Next / Play Again Button
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
                  isMatchOver
                      ? 'PLAY AGAIN'
                      : 'ADVANCE TO ROUND ${roundIndex + 2}',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
