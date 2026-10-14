import 'package:flutter/material.dart';

import '../../../../models/cloud_match.dart';
import '../../common/app_avatar.dart';
import '../../common/app_button.dart';
import '../../common/app_colors.dart';

/// Luxury obsidian Head-to-Head matchup card revealed when both players are connected.
class MatchLobbyVsCard extends StatelessWidget {
  final CloudMatch match;
  final int autoStartSeconds;
  final VoidCallback onEnterArena;

  const MatchLobbyVsCard({
    super.key,
    required this.match,
    required this.autoStartSeconds,
    required this.onEnterArena,
  });

  @override
  Widget build(BuildContext context) {
    final p1 = match.player1;
    final p2 = match.player2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Head-to-head VS arena capsule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceTile,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: AppColors.accentNeonCyan, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentNeonCyan.withValues(alpha: 0.15),
                blurRadius: 16.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Host / You Flank
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAvatar(
                      avatar: p1.avatarEmoji,
                      size: 52.0,
                      borderColor: AppColors.accentNeonCyan,
                      borderWidth: 2.0,
                    ),
                    const SizedBox(height: 8.0),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        p1.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                    const Text(
                      'HOST',
                      style: TextStyle(
                        color: AppColors.accentNeonCyan,
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Glowing VS Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.buttonDarkText,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: AppColors.accentElectricSky),
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: AppColors.accentElectricSky,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.0,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

              // Opponent Flank
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAvatar(
                      avatar: p2?.avatarEmoji ?? AppAvatar.defaultAvatar,
                      size: 52.0,
                      borderColor: AppColors.accentElectricSky,
                      borderWidth: 2.0,
                    ),
                    const SizedBox(height: 8.0),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        p2?.displayName ?? 'Opponent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                    const Text(
                      'CHALLENGER',
                      style: TextStyle(
                        color: AppColors.accentElectricSky,
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),

        // 2. Match Settings Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.buttonDarkText,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.borderInput),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${match.totalRounds} ROUNDS • ${match.roundDurationSeconds}s • ${match.difficulty.name.toUpperCase()}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20.0),

        // 3. Enter Arena CTA with auto-start countdown indicator
        AppPrimaryButton(
          label: autoStartSeconds > 0
              ? 'ENTER ARENA ($autoStartSeconds) ➔'
              : 'ENTER ARENA ➔',
          backgroundColor: AppColors.accentNeonCyan,
          foregroundColor: AppColors.buttonDarkText,
          iconData: Icons.sports_basketball_rounded,
          onPressed: onEnterArena,
        ),
      ],
    );
  }
}
