import 'package:flutter/material.dart';

import '../../../../models/cloud_match.dart';
import '../../common/app_avatar.dart';
import '../../common/app_button.dart';

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
            color: const Color(0xFF1E2638),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
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
                      borderColor: const Color(0xFF00FFCC),
                      borderWidth: 2.0,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      p1.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.0,
                      ),
                    ),
                    const Text(
                      'HOST',
                      style: TextStyle(
                        color: Color(0xFF00FFCC),
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Glowing VS Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.w900,
                    fontSize: 14.0,
                    fontStyle: FontStyle.italic,
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
                      borderColor: const Color(0xFF38BDF8),
                      borderWidth: 2.0,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      p2?.displayName ?? 'Opponent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.0,
                      ),
                    ),
                    const Text(
                      'CHALLENGER',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
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
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              '${match.totalRounds} ROUNDS • ${match.roundDurationSeconds}s • ${match.difficulty.name.toUpperCase()}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
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
          backgroundColor: const Color(0xFF00FFCC),
          foregroundColor: const Color(0xFF0F172A),
          iconData: Icons.sports_basketball_rounded,
          onPressed: onEnterArena,
        ),
      ],
    );
  }
}
