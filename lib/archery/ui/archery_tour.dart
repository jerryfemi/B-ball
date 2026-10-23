import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/ui/common/ui_font.dart';

/// Archery how-to-play, shown once per device (new and existing players
/// alike), only in solo play. The last two steps spotlight the people and
/// matches buttons. The match doesn't start until it's done (see
/// [ArcheryStartButton]).
class ArcheryTour extends StatefulWidget {
  const ArcheryTour({
    super.key,
    required this.onDone,
    required this.playFriendKey,
    required this.matchesKey,
  });

  final VoidCallback onDone;
  final GlobalKey playFriendKey;
  final GlobalKey matchesKey;

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

class _Step {
  const _Step(this.icon, this.title, this.body, [this.target]);
  final IconData icon;
  final String title;
  final String body;
  final GlobalKey? target;
}

class _ArcheryTourState extends State<ArcheryTour> {
  int _i = 0;
  late final List<_Step> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      const _Step(Icons.touch_app_rounded, 'Hold to aim',
          'Press and drag to draw the bow. Hold still and the sight ring settles. Let go to shoot.'),
      const _Step(Icons.air_rounded, 'Read the wind',
          'The pill above the target shows wind speed in mph and its direction. Aim against it. The farther the target, the more it pushes.'),
      const _Step(Icons.emoji_events_rounded, 'Win the sets',
          'Three arrows a set, and the bot shoots first. Win a set for 2 points, tie for 1. First to 6 wins.'),
      _Step(Icons.people_alt_rounded, 'Play a friend',
          'Share a match code, challenge a friend, or join with a code.',
          widget.playFriendKey),
      _Step(Icons.person_rounded, 'You',
          'Invites, friends and your matches live here. A red count means something is waiting.',
          widget.matchesKey),
    ];
    // The two buttons only exist when online play is available.
    _steps.removeWhere((s) => s.target != null && s.target!.currentContext == null);
    // Keys attach during layout; re-check after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_i >= _steps.length - 1) {
      widget.onDone();
    } else {
      setState(() => _i++);
    }
  }

  /// Target circle in this overlay's coordinates, or null for no spotlight.
  (Offset, double)? _spot() {
    final key = _steps[_i].target;
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || me == null) return null;
    final c = me.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
    return (c, box.size.shortestSide / 2 + 8);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_i];
    final last = _i == _steps.length - 1;
    final spot = _spot();

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xF2090D16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x6638BDF8), width: 1.4),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Column(
            key: ValueKey(_i),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(step.icon, color: const Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step.title,
                      style: UiFont.style(size: 18, weight: 700, letterSpacing: -0.2)),
                ),
                Text('${_i + 1} of ${_steps.length}',
                    style: UiFont.style(size: 12, color: const Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 10),
              Text(step.body,
                  style: UiFont.style(
                      size: 15, weight: 450, color: const Color(0xFF94A3B8), height: 1.4)),
              const SizedBox(height: 18),
              Row(children: [
                if (!last)
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text('Skip',
                        style: UiFont.style(size: 14, weight: 600, color: const Color(0xFF94A3B8))),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0A0E1A),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: _next,
                  child: Text(last ? 'Got it' : 'Next',
                      style: UiFont.style(size: 15, weight: 700, color: const Color(0xFF0A0E1A))),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: LayoutBuilder(builder: (context, box) {
        return Stack(
          children: [
            // Taps on the dimmed area do nothing (the game waits).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(painter: _Dim(spot)),
              ),
            ),
            if (spot == null)
              Center(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: card),
              )
            else
              Positioned(
                left: 20,
                right: 20,
                top: spot.$1.dy + spot.$2 + 16,
                child: Align(
                  alignment: spot.$1.dx < box.maxWidth / 2
                      ? Alignment.topLeft
                      : Alignment.topRight,
                  child: card,
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Dim layer with an optional circular hole around the spotlit button.
class _Dim extends CustomPainter {
  _Dim(this.spot);
  final (Offset, double)? spot;

  static final Paint _dim = Paint()..color = const Color(0xB3060913);
  static final Paint _ring = Paint()
    ..color = const Color(0xFF38BDF8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = spot;
    if (s == null) {
      canvas.drawRect(Offset.zero & size, _dim);
      return;
    }
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: s.$1, radius: s.$2));
    canvas.drawPath(path, _dim);
    canvas.drawCircle(s.$1, s.$2, _ring);
  }

  @override
  bool shouldRepaint(_Dim old) => old.spot != spot;
}

/// Big START button for solo play: the bot's first set waits for it.
class ArcheryStartButton extends StatelessWidget {
  const ArcheryStartButton({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66060913),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onStart();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x6638BDF8), blurRadius: 24, spreadRadius: 1),
                    ],
                  ),
                  child: Text('Start',
                      style: UiFont.style(
                          size: 22, weight: 800, color: const Color(0xFF0A0E1A), letterSpacing: 0.2)),
                ),
              ),
              const SizedBox(height: 12),
              Text('The bot shoots first',
                  style: UiFont.style(size: 14, weight: 500, color: const Color(0xFFCBD5E1))),
            ],
          ),
        ),
      ),
    );
  }
}
