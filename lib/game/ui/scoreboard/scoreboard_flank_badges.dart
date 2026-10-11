import 'package:flutter/material.dart';

import '../../audio/audio_engine.dart';
import '../../basketball_game.dart';

/// Flanking circular player avatar with vibrant green badge and "You" label.
class ScoreboardPlayerAvatar extends StatelessWidget {
  const ScoreboardPlayerAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🏀',
              style: TextStyle(fontSize: 18.0),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        const Text(
          'You',
          style: TextStyle(
            color: Color(0xFF4ADE80),
            fontSize: 10.0,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4.0),
            ],
          ),
        ),
      ],
    );
  }
}

/// Flanking help button pill with "?" icon.
class ScoreboardHelpBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const ScoreboardHelpBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17.0),
        child: Container(
          width: 34.0,
          height: 34.0,
          decoration: BoxDecoration(
            color: const Color(0xDDFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0x66FFFFFF),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular mute toggle button showing dynamic sound wave / muted slash icon.
class ScoreboardMuteBadge extends StatelessWidget {
  const ScoreboardMuteBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioEngine.isMutedNotifier,
      builder: (context, isMuted, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: AudioEngine.toggleMute,
            borderRadius: BorderRadius.circular(17.0),
            child: Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: isMuted
                    ? const Color(0xCC331116)
                    : const Color(0xDDFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMuted
                      ? const Color(0x88FF4444)
                      : const Color(0x66FFFFFF),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 18.0,
                  color: isMuted
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular pause / resume button.
class ScoreboardPauseBadge extends StatelessWidget {
  final BasketballGame game;

  const ScoreboardPauseBadge({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.isPausedNotifier,
      builder: (context, isPaused, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isPaused) {
                game.resumeGame();
              } else {
                game.pauseGame(manual: true);
              }
            },
            borderRadius: BorderRadius.circular(17.0),
            child: Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: isPaused
                    ? const Color(0xCC1E293B)
                    : const Color(0xDDFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPaused
                      ? const Color(0x8838BDF8)
                      : const Color(0x66FFFFFF),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 20.0,
                  color: isPaused
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
