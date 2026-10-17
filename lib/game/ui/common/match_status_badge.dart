import 'package:flutter/material.dart';

import '../../../models/cloud_match.dart';
import 'app_colors.dart';

/// Standard status badge for 1v1 multiplayer matches.
///
/// Communicates whether it is the local player's turn, the opponent's turn,
/// waiting for a challenger to join, or the final outcome (Won, Lost, Tied).
class MatchStatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;
  final double fontSize;

  const MatchStatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    this.fontSize = 9.5,
  });

  /// Factory constructor resolving state directly from a [CloudMatch] and local user ID.
  factory MatchStatusBadge.fromMatch({
    Key? key,
    required CloudMatch match,
    required String myUid,
    double fontSize = 9.5,
  }) {
    if (match.isFinished) {
      final isTie = match.outcome == MatchOutcome.tie;
      final isWinner = match.winnerUid == myUid;

      if (isTie) {
        return MatchStatusBadge(
          key: key,
          label: 'TIED 🤝',
          textColor: AppColors.accentAmber,
          backgroundColor: AppColors.accentAmber.withValues(alpha: 0.15),
          fontSize: fontSize,
        );
      } else if (isWinner) {
        return MatchStatusBadge(
          key: key,
          label: 'WON 👑',
          textColor: AppColors.accentEmerald,
          backgroundColor: AppColors.accentEmerald.withValues(alpha: 0.15),
          fontSize: fontSize,
        );
      } else {
        return MatchStatusBadge(
          key: key,
          label: 'LOST 💥',
          textColor: AppColors.accentRed,
          backgroundColor: AppColors.accentRed.withValues(alpha: 0.15),
          fontSize: fontSize,
        );
      }
    }

    final isWaitingOpponent = match.status == MatchStatus.waitingForOpponent;
    if (isWaitingOpponent) {
      return MatchStatusBadge(
        key: key,
        label: 'WAITING FOR OPPONENT',
        textColor: AppColors.accentAmber,
        backgroundColor: AppColors.accentAmber.withValues(alpha: 0.15),
        fontSize: fontSize,
      );
    }

    final isMyTurn = match.isMyTurn(myUid);
    if (isMyTurn) {
      return MatchStatusBadge(
        key: key,
        label: 'YOUR TURN ⚡',
        textColor: AppColors.accentNeonCyan,
        backgroundColor: AppColors.accentNeonCyan.withValues(alpha: 0.15),
        borderColor: AppColors.accentNeonCyan,
        fontSize: fontSize,
      );
    }

    return MatchStatusBadge(
      key: key,
      label: 'THEIR TURN ⏳',
      textColor: AppColors.textMuted,
      backgroundColor: AppColors.surfaceTile,
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.0) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
