import 'package:flutter/material.dart';

/// Compact LED round pill positioned beneath the center clock in 1v1 match mode.
class RoundIndicatorBadge extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const RoundIndicatorBadge({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: const Color(0xFF040406),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: const Color(0x55F59E0B),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        'ROUND $currentRound OF $totalRounds',
        style: const TextStyle(
          color: Color(0xFFFBBF24),
          fontSize: 8.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          height: 1.0,
        ),
      ),
    );
  }
}
