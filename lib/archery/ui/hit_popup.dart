import 'package:flutter/material.dart';
import '../physics/target_scoring.dart';

/// Floating visual hit score popup at the arrow impact location (Build Plan v2 §8.4).
///
/// Features:
/// - Chunky rounded bold font with amber-gold fill (#F59E0B) and dark 3 px outline.
/// - Scales 0.6 -> 1.15 -> 1.0 (0.25 s, back-out).
/// - Rises ~40 px over 1.0 s and fades over the last 0.3 s.
class HitPopupOverlay extends StatefulWidget {
  final ShotScore score;
  final Offset position;
  final VoidCallback onDismissed;

  const HitPopupOverlay({
    super.key,
    required this.score,
    required this.position,
    required this.onDismissed,
  });

  @override
  State<HitPopupOverlay> createState() => _HitPopupOverlayState();
}

class _HitPopupOverlayState extends State<HitPopupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Punchy pop scale: 0.6 -> 1.15 -> 1.0 over first 250ms (23% of 1.1s)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 23,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
    ]).animate(_controller);

    // Float upward by ~40 px
    _slideAnimation = Tween<double>(begin: 0.0, end: -40.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Fade out over the last 0.3s (27% of 1.1s)
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 73),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String label = widget.score.isX ? '+10 (X)' : '+${widget.score.points}';

    return Positioned(
      left: widget.position.dx - 60.0,
      top: widget.position.dy - 30.0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: SizedBox(
                  width: 120.0,
                  height: 60.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dark 3.0 px outline behind text
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3.5
                            ..color = const Color(0xFF0F172A),
                        ),
                      ),
                      // Amber-gold fill (#F59E0B)
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Color(0xFFF59E0B),
                          shadows: [
                            Shadow(
                              color: Color(0x99F59E0B),
                              blurRadius: 10.0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
