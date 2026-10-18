import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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
class FloatingScoreToastSystem extends HookWidget {
  final BasketballGame game;

  const FloatingScoreToastSystem({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final activeToasts = useState<List<_ToastItem>>([]);
    final toastCounterRef = useRef<int>(0);

    useEffect(() {
      void onScoreEvent() {
        final event = game.scoreEventNotifier.value;
        if (event == null) return;
        toastCounterRef.value++;
        activeToasts.value = [
          ...activeToasts.value,
          _ToastItem(
            key: ValueKey('toast_${toastCounterRef.value}'),
            event: event,
            createdAt: DateTime.now(),
          ),
        ];
      }

      game.scoreEventNotifier.addListener(onScoreEvent);
      return () => game.scoreEventNotifier.removeListener(onScoreEvent);
    }, [game]);

    void removeToast(Key key) {
      activeToasts.value =
          activeToasts.value.where((item) => item.key != key).toList();
    }

    return IgnorePointer(
      child: Stack(
        children: activeToasts.value.map((toast) {
          return Positioned.fill(
            child: _FloatingToastWidget(
              key: toast.key,
              event: toast.event,
              onComplete: () => removeToast(toast.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FloatingToastWidget extends HookWidget {
  final ScoreEvent event;
  final VoidCallback onComplete;

  const _FloatingToastWidget({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    // Initial punchy spring pop-in
    final scaleAnimation = useMemoized(
      () => TweenSequence<double>([
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
      ]).animate(controller),
      [controller],
    );

    // Upward float drift
    final slideAnimation = useMemoized(
      () => Tween<Offset>(
        begin: const Offset(0.0, 0.0),
        end: const Offset(0.0, -1.3),
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(controller),
      [controller],
    );

    // Smooth fade out in the final 40% of duration
    final fadeAnimation = useMemoized(
      () => TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40,
        ),
      ]).animate(controller),
      [controller],
    );

    useEffect(() {
      controller.forward().then((_) {
        onComplete();
      });
      return null;
    }, const []);

    // Shot-type styling: SWISH and BANK get the big arcade word; a plain
    // make stays a small, quiet "+2" so the special shots feel special.
    final String? word = event.isSwish
        ? 'SWISH!'
        : (event.isBankShot ? 'BANK!' : null);
    final Color accent = event.isSwish
        ? const Color(0xFFFFC31E) // radiant gold
        : (event.isBankShot
              ? const Color(0xFFFB923C) // hot orange
              : const Color(0xFFF8FAFC)); // pearl
    final points = '+${event.points}';

    final hasStreakBonus = event.streak >= 3;

    Widget animated(Widget child, {Alignment scaleFrom = Alignment.center}) {
      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            alignment: scaleFrom,
            child: child,
          ),
        ),
      );
    }

    // Layout: the shot callout pops BESIDE the hoop (right of the backboard)
    // so it never covers the rim; the streak-bonus chip keeps its old spot
    // centered under the scoreboard. The hoop sits at 25% of the game height
    // (Forge2D y=5 of 20), centered horizontally.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const calloutMaxWidth = 175.0;
        final calloutLeft = (w / 2 + h * 0.10).clamp(
          0.0,
          (w - calloutMaxWidth - 8.0).clamp(0.0, double.infinity),
        );
        return Stack(
          children: [
            Positioned(
              left: calloutLeft,
              top: h * 0.25 - (word != null ? 40.0 : 18.0),
              child: animated(
                word != null
                    ? _ArcadeCallout(word: word, points: points, accent: accent)
                    : _ArcadeCallout.small(points: points, accent: accent),
                scaleFrom: Alignment.centerLeft,
              ),
            ),
            if (hasStreakBonus)
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.28,
                child: Center(child: animated(_buildStreakChip())),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStreakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88EF4444),
            blurRadius: 8.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '🔥 ${event.streak} STREAK (+1 BONUS)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Arcade "sticker" lettering for shot callouts: Poppins Bold Italic with a
/// thick dark outline, a 3-layer block extrude (reads as chunky 3D letters),
/// a soft glow in the shot's color, and a slight energetic tilt.
///
/// Built from stacked Text layers in the HUD overlay (never in the game's
/// render loop); it only exists for ~1s after a make.
class _ArcadeCallout extends StatelessWidget {
  final String? word;
  final String points;
  final Color accent;
  final bool _small;

  const _ArcadeCallout({
    required String this.word,
    required this.points,
    required this.accent,
  }) : _small = false;

  /// Plain make: just a modest outlined "+2", no glow, no extrude.
  const _ArcadeCallout.small({required this.points, required this.accent})
    : word = null,
      _small = true;

  static const String _font = 'PoppinsCallout';
  static const Color _ink = Color(0xFF140C06);

  static final Paint _outline32 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;
  static final Paint _outline18 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.5
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  /// One outlined word: [extrude] stacks offset copies underneath for depth.
  Widget _outlined(
    String text, {
    required double size,
    required Color fill,
    required Paint outline,
    Color? glow,
    bool extrude = false,
  }) {
    final base = TextStyle(
      fontFamily: _font,
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      letterSpacing: 0.5,
      height: 1.0,
    );
    final depth = Color.lerp(accent, _ink, 0.62)!;
    return Stack(
      children: [
        // Depth block + glow (drawn as shadows of a dark copy).
        if (extrude || glow != null)
          Text(
            text,
            style: base.copyWith(
              color: extrude ? depth : Colors.transparent,
              shadows: [
                if (glow != null)
                  Shadow(color: glow, blurRadius: 18.0),
                if (extrude) ...[
                  Shadow(color: depth, offset: const Offset(1.2, 1.6)),
                  Shadow(color: depth, offset: const Offset(2.4, 3.2)),
                  Shadow(color: _ink, offset: const Offset(3.4, 4.6)),
                ],
              ],
            ),
          ),
        // Thick dark outline.
        Text(text, style: base.copyWith(foreground: outline)),
        // Bright face.
        Text(text, style: base.copyWith(color: fill)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_small) {
      return _outlined(
        points,
        size: 20.0,
        fill: accent,
        outline: _outline18,
      );
    }
    return Transform.rotate(
      angle: -0.10, // ~6° tilt
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _outlined(
            word!,
            size: 32.0,
            fill: const Color(0xFFFFFAEB),
            outline: _outline32,
            glow: accent.withValues(alpha: 0.75),
            extrude: true,
          ),
          const SizedBox(height: 4.0),
          _outlined(
            points,
            size: 18.0,
            fill: accent,
            outline: _outline18,
          ),
        ],
      ),
    );
  }
}
