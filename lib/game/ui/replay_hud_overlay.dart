import 'package:flutter/material.dart';

import '../basketball_game.dart';
import '../match/match_session.dart';

/// Floating HUD controls displayed while spectator replay mode is active.
///
/// Features:
/// 1. Unobstructed court & hoop view (no top banners blocking the basket)
/// 2. Bottom responsive control dock:
///    - Compact Exit button
///    - Expanded Primary Action button ("SKIP TO MY TURN ❯❯" or "PLAY AGAIN")
///    - Guaranteed 0 RenderFlex overflow across all screen sizes.
class ReplayHudOverlay extends StatelessWidget {
  final BasketballGame game;

  const ReplayHudOverlay({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MatchSession?>(
      valueListenable: game.matchSessionNotifier,
      builder: (context, session, _) {
        final isOpponentReplay = session != null &&
            session.phase == MatchTurnPhase.watchingOpponentReplay;

        return SafeArea(
          child: Align(
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
                                game.exitToSoloMode();
                              } else {
                                game.stopReplayMode();
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
                                  game.skipOpponentReplayAndStartTurn();
                                } else {
                                  game.restartRound();
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
          );
      },
    );
  }
}
