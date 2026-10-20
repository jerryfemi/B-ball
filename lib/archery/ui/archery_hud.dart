import 'package:flutter/material.dart';
import '../archery_game.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import 'hit_popup.dart';
import 'round_summary.dart';

/// Flutter HUD Overlay for the GamePigeon-style Archery prototype (Build Plan v2).
///
/// Features:
/// - Top score bar with avatars, set points, count-up scores, and quiver dots.
/// - Automatically fades out during raising, aiming, and chase phases.
/// - Automatically fades in during atLine, closeup, and returning phases.
/// - Hit score popup at target impact point (#F59E0B with dark outline).
/// - Set End Card modal over the target.
/// - Only rebuilds on real game state changes (no 60 fps notify bug).
class ArcheryHud extends StatelessWidget {
  final ArcheryGame game;

  const ArcheryHud({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.hudNotifier,
      builder: (context, _, child) {
        final ShotPhase phase = game.cameraRig.phase;

        // Hide score bar during raising, aiming, and chase
        final bool showScoreBar = phase == ShotPhase.atLine ||
            phase == ShotPhase.closeup ||
            phase == ShotPhase.returning ||
            phase == ShotPhase.setEnd;

        return Stack(
          children: [
            // Top App Bar / Scoreboard
            Positioned(
              top: MediaQuery.of(context).padding.top + 10.0,
              left: 16.0,
              right: 16.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: showScoreBar ? 1.0 : 0.0,
                child: _buildTopScoreBar(context),
              ),
            ),

            // Bottom Guide at Shooting Line
            if (phase == ShotPhase.atLine)
              Positioned(
                bottom: 24.0,
                left: 20.0,
                right: 20.0,
                child: _buildBottomGuide(),
              ),

            // Hit score floating popup at impact point
            if (game.lastShotScore != null && game.lastHitScreenPos != null)
              HitPopupOverlay(
                key: ValueKey(game.lastShotScore.hashCode),
                score: game.lastShotScore!,
                position: game.lastHitScreenPos!,
                onDismissed: game.clearLastHitPopup,
              ),

            // Set End Summary Modal Card
            if (phase == ShotPhase.setEnd || (game.isSetComplete && phase == ShotPhase.closeup && game.cameraRig.phaseTime > 1.0))
              SetEndCard(
                setIndex: game.currentSetIndex,
                userScores: game.setScores[game.currentSetIndex],
                userSetPoints: game.userSetPoints,
                opponentSetPoints: game.opponentSetPoints,
                isMatchOver: game.isMatchComplete,
                onContinue: game.advanceNextSet,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopScoreBar(BuildContext context) {
    final int setIdx = game.currentSetIndex;
    final List<ShotScore> currentScores =
        setIdx < game.setScores.length ? game.setScores[setIdx] : [];
    final int currentScore = game.currentSetScore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: const Color(0xFF1E283D), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: User Avatar & Set Points Won
          Row(
            children: [
              Container(
                width: 38.0,
                height: 38.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 1.8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              _buildCoinIndicators(game.userSetPoints),
            ],
          ),

          // Center: Set Label & Count-Up Score
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SET ${setIdx + 1} • 50ft',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2.0),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: currentScore.toDouble()),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22.0,
                      fontWeight: FontWeight.w900,
                    ),
                  );
                },
              ),
            ],
          ),

          // 3 Arrows Quiver Bubbles
          Row(
            children: List.generate(3, (i) {
              if (i < currentScores.length) {
                final ShotScore s = currentScores[i];
                final Color ringColor = Color(s.colorValue);
                return Container(
                  width: 22.0,
                  height: 22.0,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 1.6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s.displayLabel,
                    style: TextStyle(
                      color: ringColor,
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              } else if (i == currentScores.length) {
                return Container(
                  width: 22.0,
                  height: 22.0,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0x2200FFCC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FFCC), width: 1.8),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FFCC),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              } else {
                return Container(
                  width: 22.0,
                  height: 22.0,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E283D),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF334155), width: 1.0),
                  ),
                );
              }
            }),
          ),

          // Right: Opponent / Bot Avatar & Set Points Won
          Row(
            children: [
              _buildCoinIndicators(game.opponentSetPoints),
              const SizedBox(width: 6.0),
              Container(
                width: 38.0,
                height: 38.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 1.8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'BOT',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinIndicators(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final bool earned = i < count;
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: earned ? const Color(0xFFF59E0B) : const Color(0xFF1E283D),
            shape: BoxShape.circle,
            border: Border.all(
              color: earned ? const Color(0xFFFBBF24) : const Color(0xFF334155),
              width: 0.8,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomGuide() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1A).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: const Color(0xFF1E2638), width: 1.0),
        ),
        child: const Text(
          'HOLD ANYWHERE TO AIM',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
