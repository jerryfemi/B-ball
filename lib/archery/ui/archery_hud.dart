import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../archery_game.dart';
import '../physics/target_scoring.dart';
import 'hit_popup.dart';
import 'round_summary.dart';

/// Flutter HUD Overlay for the Archery prototype.
///
/// Styled with the DunkVerse "luxury obsidian" design system:
/// - Dark slate surfaces (#0A0E1A, #0F172A, #1E2638)
/// - Neon cyan (#00FFCC) and electric sky (#38BDF8) accents
/// - Responsive draw meter, round arrow quiver, live score, and summary card
class ArcheryHud extends StatefulWidget {
  final ArcheryGame game;

  const ArcheryHud({super.key, required this.game});

  @override
  State<ArcheryHud> createState() => _ArcheryHudState();
}

class _ArcheryHudState extends State<ArcheryHud> with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  bool _lastFullDraw = false;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.game.hudNotifier, _flashController]),
      builder: (context, child) {
        final double draw = widget.game.controller.draw;
        final bool isHolding = widget.game.controller.isHolding;
        final bool isCancelZone = widget.game.controller.isCancelZone;
        final bool isFullDraw = draw >= ArcheryK.fullDrawPlateau;

        if (isFullDraw && !_lastFullDraw) {
          _flashController.forward(from: 0.0);
        }
        _lastFullDraw = isFullDraw;

        return Stack(
          children: [
            // Top App Bar / Scoreboard
            Positioned(
              top: MediaQuery.of(context).padding.top + 12.0,
              left: 16.0,
              right: 16.0,
              child: _buildTopBar(context),
            ),

            // Right-side Vertical Draw Meter (appears when holding)
            Positioned(
              right: 20.0,
              top: MediaQuery.of(context).size.height * 0.32,
              bottom: MediaQuery.of(context).size.height * 0.32,
              child: _buildDrawMeter(draw, isHolding, isFullDraw),
            ),

            // Bottom Guide or Cancel Zone Alert
            Positioned(
              bottom: 24.0,
              left: 20.0,
              right: 20.0,
              child: _buildBottomIndicator(isHolding, isCancelZone, isFullDraw),
            ),

            // Dev telemetry badge (top-left below header)
            Positioned(
              left: 16.0,
              top: MediaQuery.of(context).padding.top + 76.0,
              child: _buildDevTelemetry(),
            ),

            // Hit score floating popup at impact point
            if (widget.game.lastShotScore != null &&
                widget.game.lastHitScreenPos != null)
              HitPopupOverlay(
                key: ValueKey(widget.game.lastShotScore.hashCode),
                score: widget.game.lastShotScore!,
                position: widget.game.lastHitScreenPos!,
                onDismissed: widget.game.clearLastHitPopup,
              ),

            // End-of-Round or Match Summary Modal
            if (widget.game.isRoundComplete)
              RoundSummaryCard(
                roundIndex: widget.game.currentRoundIndex,
                distance: widget.game.targetDistance,
                roundScores:
                    widget.game.roundScores[widget.game.currentRoundIndex],
                totalScore: widget.game.totalScore,
                totalXCount: widget.game.totalXCount,
                isMatchOver: widget.game.isMatchComplete,
                onContinue: widget.game.advanceNextRound,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final int roundIndex = widget.game.currentRoundIndex;
    final List<ShotScore> currentRoundScores =
        widget.game.roundScores[roundIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF1E2638), width: 1.2),
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
          // Round & Distance Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  'R${roundIndex + 1}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '${widget.game.targetDistance.toInt()}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          // 3 Arrow Quiver Status
          Row(
            children: List.generate(3, (arrowIndex) {
              if (arrowIndex < currentRoundScores.length) {
                // Shot taken: shows ring result
                final ShotScore s = currentRoundScores[arrowIndex];
                final Color ringColor = Color(s.colorValue);
                return Container(
                  width: 24.0,
                  height: 24.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s.displayLabel,
                    style: TextStyle(
                      color: ringColor,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              } else if (arrowIndex == currentRoundScores.length) {
                // Active arrow ready to fire (pulsing neon cyan outline)
                return Container(
                  width: 24.0,
                  height: 24.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0x2200FFCC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FFCC), width: 1.8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6600FFCC),
                        blurRadius: 6.0,
                      ),
                    ],
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
                // Future arrow (muted dot)
                return Container(
                  width: 24.0,
                  height: 24.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2638),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF334155), width: 1.0),
                  ),
                );
              }
            }),
          ),

          // Running Total Score
          Row(
            children: [
              Text(
                '${widget.game.totalScore}',
                style: const TextStyle(
                  color: Color(0xFF00FFCC),
                  fontSize: 16.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                ' PTS',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.game.totalXCount > 0) ...[
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: const Color(0x33F7D000),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    '${widget.game.totalXCount}X',
                    style: const TextStyle(
                      color: Color(0xFFF7D000),
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawMeter(double draw, bool isHolding, bool isFullDraw) {
    final double opacity = isHolding ? 1.0 : (draw > 0.05 ? draw : 0.0);
    if (opacity <= 0.0) return const SizedBox.shrink();

    final Color barColor = isFullDraw ? const Color(0xFF00FFCC) : const Color(0xFF38BDF8);

    return Opacity(
      opacity: opacity,
      child: Container(
        width: 32.0,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isFullDraw ? const Color(0xFF00FFCC) : const Color(0xFF1E2638),
            width: isFullDraw ? 1.8 : 1.0,
          ),
          boxShadow: isFullDraw
              ? const [
                  BoxShadow(
                    color: Color(0x6600FFCC),
                    blurRadius: 12.0,
                    spreadRadius: 1.0,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              '${(draw * 100).toInt()}%',
              style: TextStyle(
                color: isFullDraw ? const Color(0xFF00FFCC) : Colors.white,
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6.0),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: draw.clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF1E2638),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6.0),
            Icon(
              Icons.bolt_rounded,
              size: 14.0,
              color: isFullDraw ? const Color(0xFF00FFCC) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIndicator(bool isHolding, bool isCancelZone, bool isFullDraw) {
    if (widget.game.isRoundComplete) {
      return const SizedBox.shrink();
    }

    if (isCancelZone) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88EF4444),
              blurRadius: 16.0,
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, color: Colors.white, size: 18.0),
            SizedBox(width: 8.0),
            Text(
              'RELEASE TO CANCEL SHOT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1A).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: const Color(0xFF1E2638), width: 1.0),
        ),
        child: Text(
          isHolding
              ? (isFullDraw ? 'READY • RELEASE TO FIRE' : 'DRAWING...')
              : 'HOLD ANYWHERE TO DRAW & AIM',
          style: TextStyle(
            color: isFullDraw
                ? const Color(0xFF00FFCC)
                : (isHolding ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildDevTelemetry() {
    final camera = widget.game.archeryCamera;
    final double yawDeg = camera.yaw * 180.0 / math.pi;
    final double pitchDeg = camera.pitch * 180.0 / math.pi;
    final double fovDeg = camera.fovY * 180.0 / math.pi;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFF1E2638), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YAW: ${yawDeg.toStringAsFixed(1)}° | PITCH: ${pitchDeg.toStringAsFixed(1)}°',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 10.0,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            'FOV: ${fovDeg.toStringAsFixed(1)}° | ARROW: ${widget.game.currentArrowIndex + 1}/3',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.0,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
