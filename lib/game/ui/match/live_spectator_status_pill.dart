import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../basketball_game.dart';
import '../../match/match_session.dart';

/// Floating obsidian glassmorphism status pill mounted during live spectator mode.
///
/// Communicates opponent aiming state, reconnecting status, zero-clock grace countdown,
/// and presents the "Match Abandoned • You've won!" claim card if opponent disconnects.
class LiveSpectatorStatusPill extends HookWidget {
  final BasketballGame game;

  const LiveSpectatorStatusPill({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final breatheController = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    );

    useEffect(() {
      breatheController.repeat(reverse: true);
      return null;
    }, const []);

    final breathe = useAnimation(
      CurvedAnimation(
        parent: breatheController,
        curve: Curves.easeInOutSine,
      ),
    );

    return ValueListenableBuilder<MatchSession?>(
      valueListenable: game.matchSessionNotifier,
      builder: (context, session, _) {
        if (session == null ||
            session.phase != MatchTurnPhase.watchingLiveOpponent) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<SpectatorConnectionStatus>(
          valueListenable: game.spectatorStatusNotifier,
          builder: (context, status, _) {
            if (status == SpectatorConnectionStatus.connected) {
              return const SizedBox.shrink();
            }

            return ValueListenableBuilder<int>(
              valueListenable: game.spectatorGraceSecondsNotifier,
              builder: (context, graceSeconds, _) {
                return _buildAnimatedContent(
                  context,
                  status,
                  graceSeconds,
                  session,
                  breathe,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedContent(
    BuildContext context,
    SpectatorConnectionStatus status,
    int graceSeconds,
    MatchSession session,
    double breathe,
  ) {
    if (status == SpectatorConnectionStatus.opponentAbandoned) {
      return _buildAbandonedCard(context, session, breathe);
    }

    final Color borderColor;
    final Color backgroundColor;
    final Widget iconWidget;
    final String label;

    switch (status) {
      case SpectatorConnectionStatus.aimingOrIdle:
        borderColor = Color.lerp(
          const Color(0x3338BDF8),
          const Color(0x9938BDF8),
          breathe,
        )!;
        backgroundColor = const Color(0xE60F172A);
        iconWidget = Transform.scale(
          scale: 0.85 + (breathe * 0.35),
          child: Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(
                    alpha: 0.40 + (breathe * 0.50),
                  ),
                  blurRadius: 4.0 + (breathe * 8.0),
                  spreadRadius: 1.0 + (breathe * 1.5),
                ),
              ],
            ),
          ),
        );
        label = 'Waiting for ${session.opponentPlayer.name}\'s shot...';
      case SpectatorConnectionStatus.reconnecting:
        borderColor = Color.lerp(
          const Color(0x44F59E0B),
          const Color(0xAAF59E0B),
          breathe,
        )!;
        backgroundColor = const Color(0xF018150A);
        iconWidget = const SizedBox(
          width: 12.0,
          height: 12.0,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
          ),
        );
        label = 'Reconnecting to live court...';
      case SpectatorConnectionStatus.finalizingTurn:
        borderColor = Color.lerp(
          const Color(0x4438BDF8),
          const Color(0xAA38BDF8),
          breathe,
        )!;
        backgroundColor = const Color(0xF00A1324);
        iconWidget = Transform.rotate(
          angle: breathe * 0.4,
          child: const Icon(
            Icons.sync_rounded,
            size: 14.0,
            color: Color(0xFF38BDF8),
          ),
        );
        label = 'Finalizing round score (${graceSeconds}s)...';
      case SpectatorConnectionStatus.connected:
      case SpectatorConnectionStatus.opponentAbandoned:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14.0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: borderColor.withValues(alpha: 0.12 + (breathe * 0.15)),
              blurRadius: 10.0 + (breathe * 8.0),
              spreadRadius: breathe * 1.0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(width: 8.0),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbandonedCard(
    BuildContext context,
    MatchSession session,
    double breathe,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        constraints: const BoxConstraints(maxWidth: 360.0),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF50F172A), Color(0xFA090D16)],
          ),
          borderRadius: BorderRadius.circular(22.0),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(
              alpha: 0.50 + (breathe * 0.40),
            ),
            width: 1.5 + (breathe * 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(
                alpha: 0.18 + (breathe * 0.22),
              ),
              blurRadius: 20.0 + (breathe * 16.0),
              spreadRadius: breathe * 2.0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 14.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFF59E0B),
                  size: 18.0,
                ),
                const SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    'MATCH ABANDONED BY ${session.opponentPlayer.name.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            const Text(
              "You've won! Opponent lost connection or left the court.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => game.exitAbandonedMatch(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'EXIT TO SOLO',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  flex: 2,
                  child: Transform.scale(
                    scale: 1.0 + (breathe * 0.035),
                    child: ElevatedButton(
                      onPressed: () => game.claimAbandonedVictory(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 11.0),
                        elevation: 6.0,
                        shadowColor: const Color(0x6622C55E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text(
                        'CLAIM VICTORY 👑',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
