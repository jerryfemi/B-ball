import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery_game.dart';
import '../camera/camera_rig.dart';
import '../state/archery_match_notifier.dart';
import 'round_summary.dart';

/// Flutter HUD over the Flame canvas: GamePigeon-style scoreboard and the
/// set-end card. Each piece watches only the state slice it shows.
class ArcheryHud extends ConsumerWidget {
  final ArcheryGame game;

  const ArcheryHud({super.key, required this.game});

  static const String userAvatar = 'assets/avatars/dunk_heads (1).webp';
  static const String botAvatar = 'assets/avatars/dunk_heads (2).webp';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShotPhase phase = ref.watch(archeryMatchProvider.select((s) => s.phase));
    final bool showScoreBar = phase == ShotPhase.atLine ||
        phase == ShotPhase.intro ||
        phase == ShotPhase.closeup ||
        phase == ShotPhase.returning ||
        phase == ShotPhase.setEnd;

    return Stack(
      children: [
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8.0,
          left: 0.0,
          right: 0.0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: showScoreBar ? Offset.zero : const Offset(0, -0.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: showScoreBar ? 1.0 : 0.0,
                  child: const _Scoreboard(),
                ),
              ),
            ),
          ),
        ),
        if (phase == ShotPhase.setEnd) _SetEnd(game: game),
      ],
    );
  }
}

class _SetEnd extends ConsumerWidget {
  final ArcheryGame game;
  const _SetEnd({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(archeryMatchProvider);
    return SetEndCard(
      setIndex: s.setIndex,
      userScores: s.setShots,
      opponentTotal: s.botSetScore,
      userSetPoints: s.userSets,
      opponentSetPoints: s.botSets,
      isMatchOver: s.matchOver,
      onContinue: s.matchOver ? game.restartMatch : game.advanceNextSet,
    );
  }
}

/// GamePigeon layout:   (avatar)  [ SET 1 / 18 - 26 ]  (avatar)
///                       You  ●2                         ●1
class _Scoreboard extends ConsumerWidget {
  const _Scoreboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Records compare by value, so this only rebuilds when one field changes.
    final (setIndex, you, them, youSets, themSets) = ref.watch(
      archeryMatchProvider.select(
        (s) => (s.setIndex, s.userSetScore, s.botSetScore, s.userSets, s.botSets),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(
          image: ArcheryHud.userAvatar,
          label: 'You',
          labelColor: const Color(0xFF00FFCC),
          ring: const Color(0xFF00FFCC),
          sets: youSets,
        ),
        const SizedBox(width: 10.0),
        _ScoreBox(setIndex: setIndex, you: you, them: them),
        const SizedBox(width: 10.0),
        _Avatar(
          image: ArcheryHud.botAvatar,
          label: 'Bot',
          labelColor: const Color(0xFFC4B5FD),
          ring: const Color(0xFF8B5CF6),
          sets: themSets,
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final int setIndex;
  final int you;
  final int them;

  const _ScoreBox({required this.setIndex, required this.you, required this.them});

  static const TextStyle _scoreStyle = TextStyle(
    color: Colors.white,
    fontSize: 28.0,
    height: 1.05,
    fontWeight: FontWeight.w900,
    fontFeatures: [FontFeature.tabularFigures()],
    shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1.5), blurRadius: 2)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6.0),
      padding: const EdgeInsets.fromLTRB(18.0, 6.0, 18.0, 8.0),
      decoration: BoxDecoration(
        color: const Color(0xE60F172A),
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 12.0, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SET ${setIndex + 1}',
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 11.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountUp(value: you, style: _scoreStyle),
              const Text(' - ', style: _scoreStyle),
              _CountUp(value: them, style: _scoreStyle),
            ],
          ),
        ],
      ),
    );
  }
}

/// Score that counts up instead of jumping.
class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _CountUp({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: value, end: value),
      duration: const Duration(milliseconds: 450),
      builder: (context, v, _) => Text('$v', style: style),
    );
  }
}

/// Round avatar zoomed onto the character's head, coloured ring, small name
/// label, and a gold coin with the set count once they've won a set.
class _Avatar extends StatelessWidget {
  final String image;
  final String label;
  final Color labelColor;
  final Color ring;
  final int sets;

  const _Avatar({
    required this.image,
    required this.label,
    required this.labelColor,
    required this.ring,
    required this.sets,
  });

  static const double size = 56.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: 3.0),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 10.0, offset: Offset(0, 3)),
                ],
              ),
              child: ClipOval(
                // The avatar art is a full character; zoom onto the head.
                child: Transform.scale(
                  scale: 1.9,
                  alignment: const Alignment(0.0, -0.36),
                  child: Image.asset(
                    image,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            if (sets > 0)
              Positioned(
                right: -4.0,
                bottom: -4.0,
                child: _SetCoin(count: sets),
              ),
          ],
        ),
        const SizedBox(height: 3.0),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12.0,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3.0)],
          ),
        ),
      ],
    );
  }
}

/// Gold set coin. When the count goes up it pops in and a "+1" floats off it.
class _SetCoin extends StatelessWidget {
  final int count;
  const _SetCoin({required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // New key per count = the animation replays every time a set is won.
      key: ValueKey<int>(count),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, coin) {
        final double pop = Curves.elasticOut.transform((t / 0.6).clamp(0.0, 1.0));
        final double rise = Curves.easeOutCubic.transform(t);
        final double fade = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(scale: 0.3 + 0.7 * pop, child: coin),
            if (t < 1.0)
              Positioned(
                top: -14.0 - 22.0 * rise,
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: const Text(
                    '+1',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 16.0,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Color(0xCCF59E0B), blurRadius: 8.0)],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: Container(
        width: 22.0,
        height: 22.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
            stops: [0.0, 0.6, 1.0],
          ),
          border: Border.all(color: const Color(0xFF0A0E1A), width: 1.5),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Color(0xFF3B1F04),
            fontSize: 12.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
