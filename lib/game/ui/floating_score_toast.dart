import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';

/// Floating score toast item model
class _ToastItem {
  final Key key;
  final ScoreEvent event;
  final DateTime createdAt;

  _ToastItem({
    required this.key,
    required this.event,
    required this.createdAt,
  });
}

/// Floating Score Toast System that listens to [BasketballGame.scoreEventNotifier]
/// and spawns celebratory floating badges (+3 SWISH!, +3 BANK SHOT!, +2 PTS)
/// that gently drift upward and fade out.
class FloatingScoreToastSystem extends StatefulWidget {
  final BasketballGame game;

  const FloatingScoreToastSystem({
    super.key,
    required this.game,
  });

  @override
  State<FloatingScoreToastSystem> createState() =>
      _FloatingScoreToastSystemState();
}

class _FloatingScoreToastSystemState extends State<FloatingScoreToastSystem> {
  final List<_ToastItem> _activeToasts = [];
  int _toastCounter = 0;

  @override
  void initState() {
    super.initState();
    widget.game.scoreEventNotifier.addListener(_onScoreEvent);
  }

  @override
  void didUpdateWidget(covariant FloatingScoreToastSystem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.scoreEventNotifier.removeListener(_onScoreEvent);
      widget.game.scoreEventNotifier.addListener(_onScoreEvent);
    }
  }

  @override
  void dispose() {
    widget.game.scoreEventNotifier.removeListener(_onScoreEvent);
    super.dispose();
  }

  void _onScoreEvent() {
    final event = widget.game.scoreEventNotifier.value;
    if (event == null || !mounted) return;

    setState(() {
      _toastCounter++;
      _activeToasts.add(
        _ToastItem(
          key: ValueKey('toast_$_toastCounter'),
          event: event,
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  void _removeToast(Key key) {
    if (!mounted) return;
    setState(() {
      _activeToasts.removeWhere((item) => item.key == key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: _activeToasts.map((toast) {
          return _FloatingToastWidget(
            key: toast.key,
            event: toast.event,
            onComplete: () => _removeToast(toast.key),
          );
        }).toList(),
      ),
    );
  }
}

class _FloatingToastWidget extends StatefulWidget {
  final ScoreEvent event;
  final VoidCallback onComplete;

  const _FloatingToastWidget({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<_FloatingToastWidget> createState() => _FloatingToastWidgetState();
}

class _FloatingToastWidgetState extends State<_FloatingToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Initial punchy spring pop-in
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.95),
        weight: 45,
      ),
    ]).animate(_controller);

    // Upward float drift
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(0.0, -1.3),
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller);

    // Smooth fade out in the final 40% of duration
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    // Palette & Label resolution
    final Color primaryColor;
    final Color glowColor;
    final String label;
    final IconData icon;

    if (event.isSwish) {
      primaryColor = const Color(0xFFFBBF24); // Warm radiant gold
      glowColor = const Color(0x66F59E0B);
      label = '+${event.points} SWISH!';
      icon = Icons.auto_awesome_rounded;
    } else if (event.isBankShot) {
      primaryColor = const Color(0xFF38BDF8); // Electric cyan
      glowColor = const Color(0x660EA5E9);
      label = '+${event.points} BANK SHOT!';
      icon = Icons.crop_square_rounded;
    } else {
      primaryColor = const Color(0xFFF8FAFC); // Clean collegiate pearl
      glowColor = const Color(0x33FFFFFF);
      label = '+${event.points} PTS';
      icon = Icons.sports_basketball_rounded;
    }

    final hasStreakBonus = event.streak >= 3;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xE60F172A),
                      const Color(0xCC1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 18.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: primaryColor,
                      size: 20.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      label,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 18.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasStreakBonus) ...[
                const SizedBox(height: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE6EA580C),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66EA580C),
                        blurRadius: 10.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🔥',
                        style: TextStyle(fontSize: 12.0),
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'STREAK x${event.streak} (+${event.streak - 2} BONUS)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
