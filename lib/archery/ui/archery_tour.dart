import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Archery how-to-play: four short cards, shown once per device (new and
/// existing players alike), only in solo play.
class ArcheryTour extends StatefulWidget {
  const ArcheryTour({super.key, required this.onDone});

  final VoidCallback onDone;

  static const String prefKey = 'archery_tour_seen_v1';

  /// True if this device hasn't seen the tour. Marks it seen right away so
  /// it never shows twice, even if the app closes mid-tour.
  static Future<bool> shouldShow() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(prefKey) ?? false) return false;
      await p.setBool(prefKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  State<ArcheryTour> createState() => _ArcheryTourState();
}

class _ArcheryTourState extends State<ArcheryTour> {
  int _i = 0;

  static const _steps = <(IconData, String, String)>[
    (Icons.touch_app_rounded, 'HOLD TO AIM',
        'Press and drag to draw the bow. Hold still and the sight ring settles. Let go to shoot.'),
    (Icons.air_rounded, 'READ THE WIND',
        'The pill shows wind speed in mph and its direction. Aim against it; the farther the target, the more it pushes.'),
    (Icons.emoji_events_rounded, 'WIN THE SETS',
        'Three arrows a set. Win a set for 2 points, tie for 1. First to 6 wins the match.'),
    (Icons.people_alt_rounded, 'PLAY A FRIEND',
        'Tap the people button at the top right to challenge a friend or join with a code.'),
  ];

  void _next() {
    HapticFeedback.lightImpact();
    if (_i == _steps.length - 1) {
      widget.onDone();
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = _steps[_i];
    final last = _i == _steps.length - 1;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99060913),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xF2090D16),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x6638BDF8), width: 1.4),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(_i),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(icon, color: const Color(0xFF38BDF8), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                        ),
                        Text('${_i + 1}/${_steps.length}',
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12)),
                      ]),
                      const SizedBox(height: 12),
                      Text(body,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14, height: 1.4)),
                      const SizedBox(height: 18),
                      Row(children: [
                        if (!last)
                          TextButton(
                            onPressed: widget.onDone,
                            child: const Text('SKIP',
                                style: TextStyle(color: Color(0xFF94A3B8))),
                          ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0A0E1A),
                          ),
                          onPressed: _next,
                          child: Text(last ? "LET'S SHOOT" : 'NEXT',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
