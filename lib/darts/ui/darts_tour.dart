import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../darts_constants.dart';

/// Interactive walkthrough tour introducing Darts 301 mechanics.
///
/// Features 4 cards:
/// 1. HOLD TO AIM
/// 2. FLICK TO THROW
/// 3. 301 TO ZERO (Bust & Checkout)
/// 4. PLAY A FRIEND (Multiplayer & Sketchfab 3D model attribution)
///
/// Implemented according to Apple Design standards:
/// - Translucent frosted obsidian glass card.
/// - Interactive dot stepper with spring animation.
/// - Instant pointer-down button scale response.
/// - Persisted with preference key [prefKey] so it shows once per device.
class DartsTour extends StatefulWidget {
  final VoidCallback onDone;

  const DartsTour({super.key, required this.onDone});

  static const String prefKey = 'darts_tour_seen_v1';

  /// Returns true if this device has not yet completed the tour.
  /// Marks it seen immediately to prevent duplicate prompts.
  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(prefKey) ?? false) return false;
      await prefs.setBool(prefKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  State<DartsTour> createState() => _DartsTourState();
}

class _TourStep {
  final IconData icon;
  final String title;
  final String body;
  final String? footer;

  const _TourStep({
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
  });
}

class _DartsTourState extends State<DartsTour> {
  int _currentIndex = 0;

  static const List<_TourStep> _steps = [
    _TourStep(
      icon: Icons.touch_app_rounded,
      title: 'HOLD TO AIM',
      body:
          'Press and hold anywhere in the lower screen to raise your dart. Drag your thumb to guide the aim reticle across the dartboard.',
    ),
    _TourStep(
      icon: Icons.arrow_upward_rounded,
      title: 'FLICK TO THROW',
      body:
          'Flick upward smoothly through the release line. Controlled, straight flicks land true; flicking too fast lands high, while too slow drops low.',
    ),
    _TourStep(
      icon: Icons.track_changes_rounded,
      title: '301 TO ZERO',
      body:
          'Both players start at 301 points. Land darts to count down. Landing below 0 is a BUST — your turn ends and your score resets to what it was!',
    ),
    _TourStep(
      icon: Icons.people_alt_rounded,
      title: 'PLAY A FRIEND',
      body:
          'Challenge friends live with a 6-digit match code, or practice your precision against DartBot in solo play.',
      footer: 'Dart 3D model by oxxycodone (Sketchfab), CC-BY 4.0.',
    ),
  ];

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentIndex >= _steps.length - 1) {
      widget.onDone();
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentIndex];
    final bool isLast = _currentIndex == _steps.length - 1;

    return Stack(
      children: [
        // ── 1. Full-screen Blur Backdrop ─────────────────────────────────────
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: const ColoredBox(
              color: Color(0xB3060913),
            ),
          ),
        ),

        // ── 2. Tour Card Modal ───────────────────────────────────────────────
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 22.0),
              padding: const EdgeInsets.fromLTRB(26.0, 24.0, 26.0, 26.0),
              decoration: BoxDecoration(
                color: const Color(0xF20F172A),
                borderRadius: BorderRadius.circular(26.0),
                border: Border.all(
                  color: const Color(0x33FFFFFF),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xE6000000),
                    blurRadius: 40.0,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Step count & Skip button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HOW TO PLAY · ${_currentIndex + 1}/${_steps.length}',
                          style: const TextStyle(
                            color: Color(DartsK.textMuted),
                            fontSize: 11.0,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Inter',
                            fontVariations: [FontVariation('wght', 800)],
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (!isLast)
                          GestureDetector(
                            onTap: _skip,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                              child: Text(
                                'SKIP',
                                style: TextStyle(
                                  color: Color(DartsK.textMuted),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Inter',
                                  fontVariations: [FontVariation('wght', 800)],
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24.0),

                    // Feature Icon
                    Center(
                      child: Container(
                        width: 72.0,
                        height: 72.0,
                        decoration: BoxDecoration(
                          color: const Color(DartsK.accentP1).withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(DartsK.accentP1).withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(DartsK.accentP1).withValues(alpha: 0.25),
                              blurRadius: 20.0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            step.icon,
                            color: const Color(DartsK.accentP1),
                            size: 34.0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20.0),

                    // Card Title
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        step.title,
                        key: ValueKey('title_$_currentIndex'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Inter',
                          fontVariations: [FontVariation('wght', 900)],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12.0),

                    // Card Body
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        step.body,
                        key: ValueKey('body_$_currentIndex'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 14.0,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),

                    if (step.footer != null) ...[
                      const SizedBox(height: 14.0),
                      Text(
                        step.footer!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],

                    const SizedBox(height: 28.0),

                    // Stepper Dots & Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dot indicators
                        Row(
                          children: List.generate(_steps.length, (i) {
                            final bool active = i == _currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(right: 6.0),
                              width: active ? 22.0 : 7.0,
                              height: 7.0,
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(DartsK.accentP1)
                                    : const Color(0x33FFFFFF),
                                borderRadius: BorderRadius.circular(3.5),
                              ),
                            );
                          }),
                        ),

                        // Action Button (Next / Get Started)
                        _TourActionButton(
                          label: isLast ? 'LET’S PLAY' : 'NEXT',
                          onPressed: _next,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TourActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _TourActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_TourActionButton> createState() => _TourActionButtonState();
}

class _TourActionButtonState extends State<_TourActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(DartsK.accentP1),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: const Color(DartsK.accentP1).withValues(alpha: 0.35),
                blurRadius: 14.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Color(DartsK.surfaceDark),
              fontSize: 13.0,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
              fontVariations: [FontVariation('wght', 900)],
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
