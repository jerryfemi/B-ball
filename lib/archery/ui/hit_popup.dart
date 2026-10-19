import 'package:flutter/material.dart';
import '../physics/target_scoring.dart';

/// Floating visual hit score popup at the arrow impact location.
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

    // Punchy pop scale
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
    ]).animate(_controller);

    // Float upward
    _slideAnimation = Tween<double>(begin: 0.0, end: -36.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Fade out towards the end
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 65),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
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
    final Color scoreColor = Color(widget.score.colorValue);
    final bool isGold = widget.score.isX || widget.score.ring >= 9;

    return Positioned(
      left: widget.position.dx - 40.0,
      top: widget.position.dy - 40.0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  width: 80.0,
                  height: 80.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isGold
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF7D000).withValues(alpha: 0.6),
                              blurRadius: 20.0,
                              spreadRadius: 2.0,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    widget.score.displayLabel,
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: widget.score.isX ? 36.0 : 32.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      shadows: [
                        const Shadow(
                          color: Color(0xDD000000),
                          blurRadius: 8.0,
                          offset: Offset(0, 2),
                        ),
                        if (isGold)
                          const Shadow(
                            color: Color(0xAAFFD700),
                            blurRadius: 16.0,
                          ),
                      ],
                    ),
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
