import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery_constants.dart';
import '../archery_game.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import '../state/archery_match_notifier.dart';
import 'round_summary.dart';

/// Flutter HUD Overlay for the GamePigeon-style Archery prototype (Build Plan v2 §5, Review §1.2).
///
/// Features:
/// - Riverpod [ConsumerWidget] with slice-based updates (`ref.watch(select(...))`).
/// - Top score bar with avatars, set points, count-up scores, and quiver dots.
/// - Capped at `maxWidth: 520` with fluid horizontal margins for desktop/phone responsiveness.
/// - Dynamic distance label using [ArcheryK.distanceLabel].
/// - Fades out during raising, aiming, and chase phases.
/// - Explicit phase-driven [SetEndCard] modal when `phase == ShotPhase.setEnd`.
/// - Wrapped with [IgnorePointer] on non-interactive areas for touch input isolation (Bug #7).
class ArcheryHud extends ConsumerWidget {
  final ArcheryGame game;

  const ArcheryHud({super.key, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShotPhase phase = ref.watch(
      archeryMatchProvider.select((s) => s.phase),
    );
    final int setIdx = ref.watch(
      archeryMatchProvider.select((s) => s.setIndex),
    );
    final List<ShotScore> currentScores = ref.watch(
      archeryMatchProvider.select((s) => s.setShots),
    );
    final int currentScore = ref.watch(
      archeryMatchProvider.select((s) => s.currentSetScore),
    );
    final int userSets = ref.watch(
      archeryMatchProvider.select((s) => s.userSets),
    );
    final int botSets = ref.watch(
      archeryMatchProvider.select((s) => s.botSets),
    );
    final bool isMatchOver = ref.watch(
      archeryMatchProvider.select((s) => s.matchOver),
    );

    // Hide score bar during raising, aiming, and chase
    final bool showScoreBar = phase == ShotPhase.atLine ||
        phase == ShotPhase.closeup ||
        phase == ShotPhase.returning ||
        phase == ShotPhase.setEnd;

    return Stack(
      children: [
        // Top App Bar / Scoreboard (capped at maxWidth 520, fluid on smaller screens)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 10.0,
          left: 0.0,
          right: 0.0,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: showScoreBar ? 1.0 : 0.0,
                    child: _buildTopScoreBar(
                      context,
                      setIdx: setIdx,
                      currentScores: currentScores,
                      currentScore: currentScore,
                      userSets: userSets,
                      botSets: botSets,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Guide at Shooting Line (non-interactive, passes touches through)
        if (phase == ShotPhase.atLine)
          const Positioned(
            bottom: 24.0,
            left: 20.0,
            right: 20.0,
            child: IgnorePointer(
              child: _BottomGuide(),
            ),
          ),

        // Set End Summary Modal Card
        if (phase == ShotPhase.setEnd)
          SetEndCard(
            setIndex: setIdx,
            userScores: currentScores,
            userSetPoints: userSets,
            opponentSetPoints: botSets,
            isMatchOver: isMatchOver,
            onContinue: isMatchOver ? game.restartMatch : game.advanceNextSet,
          ),
      ],
    );
  }

  Widget _buildTopScoreBar(
    BuildContext context, {
    required int setIdx,
    required List<ShotScore> currentScores,
    required int currentScore,
    required int userSets,
    required int botSets,
  }) {
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.0,
                height: 36.0,
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
              _buildCoinIndicators(userSets),
            ],
          ),

          // Center: Set Label & Count-Up Score
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SET ${setIdx + 1} • ${ArcheryK.distanceLabel}',
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
            ),
          ),

          // 3 Arrows Quiver Bubbles
          Row(
            mainAxisSize: MainAxisSize.min,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCoinIndicators(botSets),
              const SizedBox(width: 6.0),
              Container(
                width: 36.0,
                height: 36.0,
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
}

class _BottomGuide extends StatelessWidget {
  const _BottomGuide();

  @override
  Widget build(BuildContext context) {
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
