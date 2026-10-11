import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import '../match/match_session.dart';

/// Floating HUD controls displayed while spectator replay mode is active.
///
/// Layout:
/// 1. Top floating status capsule: clear context indicator (Opponent Replay vs Solo Replay)
/// 2. Bottom responsive control dock:
///    - Compact Exit button
///    - Expanded Primary Action button (e.g. "SKIP TO MY TURN ❯❯" or "PLAY AGAIN")
///    - Guaranteed 0 RenderFlex overflow across all screen sizes.
class ReplayHudOverlay extends StatefulWidget {
  final BasketballGame game;

  const ReplayHudOverlay({
    super.key,
    required this.game,
  });

  @override
  State<ReplayHudOverlay> createState() => _ReplayHudOverlayState();
}

class _ReplayHudOverlayState extends State<ReplayHudOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MatchSession?>(
      valueListenable: widget.game.matchSessionNotifier,
      builder: (context, session, _) {
        final isOpponentReplay = session != null &&
            session.phase == MatchTurnPhase.watchingOpponentReplay;

        final Color themeColor = isOpponentReplay
            ? const Color(0xFF38BDF8)
            : const Color(0xFFFBBF24);

        return SafeArea(
          child: Stack(
            children: [
              // 1. Top Floating Status Capsule (Below Top Scoreboard)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 88.0, left: 16.0, right: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0B1120),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.22),
                              blurRadius: 16.0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) => Container(
                                width: 8.0,
                                height: 8.0,
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(
                                    alpha: _pulseAnimation.value,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeColor,
                                      blurRadius: 6.0 * _pulseAnimation.value,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              isOpponentReplay
                                  ? "OPPONENT'S ROUND ${session.currentRoundNumber} REPLAY"
                                  : 'YOUR ROUND REPLAY',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Bottom Control Dock (Skip Replay / Exit)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 24.0,
                    left: 20.0,
                    right: 20.0,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xF00F172A),
                                Color(0xFA090D16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(
                              color: const Color(0x38FFFFFF),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 24.0,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Compact Exit Button
                              OutlinedButton(
                                onPressed: () {
                                  if (isOpponentReplay) {
                                    widget.game.exitToSoloMode();
                                  } else {
                                    widget.game.stopReplayMode();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF94A3B8),
                                  side: const BorderSide(
                                    color: Color(0x38FFFFFF),
                                    width: 1.0,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                    vertical: 12.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded, size: 16.0),
                                    SizedBox(width: 4.0),
                                    Text(
                                      'EXIT',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10.0),

                              // Expanded Skip / Play Button
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (isOpponentReplay) {
                                      widget.game.skipOpponentReplayAndStartTurn();
                                    } else {
                                      widget.game.restartRound();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    elevation: 6.0,
                                    shadowColor: const Color(0xFF22C55E)
                                        .withValues(alpha: 0.45),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                      horizontal: 12.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isOpponentReplay
                                            ? Icons.skip_next_rounded
                                            : Icons.replay_rounded,
                                        size: 20.0,
                                      ),
                                      const SizedBox(width: 6.0),
                                      Flexible(
                                        child: Text(
                                          isOpponentReplay
                                              ? 'SKIP TO MY TURN ❯❯'
                                              : 'PLAY AGAIN',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
