import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../archery_game.dart';

/// Flutter HUD Overlay for the Archery prototype.
///
/// Styled with the DunkVerse "luxury obsidian" design system:
/// - Dark slate surfaces (#0A0E1A, #0F172A, #1E2638)
/// - Neon cyan (#00FFCC) and electric sky (#38BDF8) accents
/// - Responsive draw meter, distance selector, and cancel warning
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
            // Top App Bar / Distance Selector
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
              top: MediaQuery.of(context).padding.top + 72.0,
              child: _buildDevTelemetry(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
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
          // Mode Badge
          Row(
            children: [
              Container(
                width: 10.0,
                height: 10.0,
                decoration: const BoxDecoration(
                  color: Color(0xFF00FFCC),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x8800FFCC),
                      blurRadius: 6.0,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              const Text(
                'ARCHERY PROTOTYPE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Distance Selector Chips (20m, 40m, 60m)
          Row(
            children: ArcheryK.roundDistances.map((dist) {
              final bool isSelected = (widget.game.targetDistance - dist).abs() < 0.5;
              return Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: InkWell(
                  onTap: () => widget.game.setTargetDistance(dist),
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '${dist.toInt()}m',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF0A0E1A) : const Color(0xFF94A3B8),
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
            'FOV: ${fovDeg.toStringAsFixed(1)}° | DIST: ${widget.game.targetDistance.toInt()}m',
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
