import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery_game.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import '../state/archery_match_notifier.dart';
import 'round_summary.dart';

/// Flutter HUD over the Flame canvas: compact scoreboard, shooting-line hint
/// and the set-end card. Every piece watches only the state slice it shows.
class ArcheryHud extends ConsumerWidget {
  final ArcheryGame game;

  const ArcheryHud({super.key, required this.game});

  static const String userAvatar = 'assets/avatars/dunk_heads (1).webp';
  static const String botAvatar = 'assets/avatars/dunk_heads (2).webp';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShotPhase phase = ref.watch(archeryMatchProvider.select((s) => s.phase));
    final bool showScoreBar = phase == ShotPhase.atLine ||
        phase == ShotPhase.closeup ||
        phase == ShotPhase.returning ||
        phase == ShotPhase.setEnd;

    return Stack(
      children: [
        // Scoreboard: compact, centred, never wider than 360 px.
        Positioned(
          top: MediaQuery.paddingOf(context).top + 10.0,
          left: 12.0,
          right: 12.0,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: showScoreBar ? Offset.zero : const Offset(0, -0.15),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: showScoreBar ? 1.0 : 0.0,
                  child: const _Scoreboard(),
                ),
              ),
            ),
          ),
        ),

        // Hint at the shooting line (touches pass through to the game).
        if (phase == ShotPhase.atLine)
          const Positioned(
            bottom: 24.0,
            left: 20.0,
            right: 20.0,
            child: IgnorePointer(child: _BottomGuide()),
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

/// [avatar]  ┌ SET 1 ┐  [avatar]
///  (coin)   │18 – 26│   (coin)
///           └◉ ◉ ○ ┘
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
    final List<ShotScore> shots = ref.watch(archeryMatchProvider.select((s) => s.setShots));

    // The overlaps below pull the row 12 px left; shift it back so it stays centred.
    return Transform.translate(
      offset: const Offset(6.0, 0.0),
      child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            image: ArcheryHud.userAvatar,
            label: 'YOU',
            sets: youSets,
            ring: const Color(0xFF00FFCC),
          ),
          // Centre box overlaps both avatars slightly (GamePigeon layout).
          Transform.translate(
            offset: const Offset(-6.0, 0.0),
            child: _CenterBox(setIndex: setIndex, you: you, them: them, shots: shots),
          ),
          Transform.translate(
            offset: const Offset(-12.0, 0.0),
            child: _Avatar(
              image: ArcheryHud.botAvatar,
              label: 'BOT',
              sets: themSets,
              ring: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _CenterBox extends StatelessWidget {
  final int setIndex;
  final int you;
  final int them;
  final List<ShotScore> shots;

  const _CenterBox({
    required this.setIndex,
    required this.you,
    required this.them,
    required this.shots,
  });

  static const Color _cyan = Color(0xFF00FFCC);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      padding: const EdgeInsets.fromLTRB(22.0, 6.0, 22.0, 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF1E2638), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 14.0, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SET ${setIndex + 1}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 1.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountUp(value: you, color: you > them ? _cyan : Colors.white),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '–',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 22.0, fontWeight: FontWeight.w700),
                ),
              ),
              _CountUp(value: them, color: them > you ? _cyan : Colors.white),
            ],
          ),
          const SizedBox(height: 4.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: i < shots.length
                      ? _ShotPip(score: shots[i])
                      : (i == shots.length ? const _NextPip() : const _EmptyPip()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Score that counts up instead of jumping; tabular digits so it doesn't wobble.
class _CountUp extends StatelessWidget {
  final int value;
  final Color color;
  const _CountUp({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: value, end: value),
      duration: const Duration(milliseconds: 400),
      builder: (context, v, _) => Text(
        '$v',
        style: TextStyle(
          color: color,
          fontSize: 26.0,
          height: 1.1,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String image;
  final String label;
  final int sets;
  final Color ring;

  const _Avatar({
    required this.image,
    required this.label,
    required this.sets,
    required this.ring,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E2638),
                  border: Border.all(color: ring, width: 2.0),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8.0)],
                ),
                child: ClipOval(
                  child: Image.asset(image, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                ),
              ),
              // Set points: one gold coin with the count (hidden at 0).
              if (sets > 0)
                Positioned(
                  bottom: -6.0,
                  child: Container(
                    width: 20.0,
                    height: 20.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B),
                      border: Border.all(color: const Color(0xFF0A0E1A), width: 1.5),
                    ),
                    child: Text(
                      '$sets',
                      style: const TextStyle(
                        color: Color(0xFF0A0E1A),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: sets > 0 ? 9.0 : 3.0),
          Text(
            label,
            style: TextStyle(
              color: ring,
              fontSize: 9.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShotPip extends StatelessWidget {
  final ShotScore score;
  const _ShotPip({required this.score});

  @override
  Widget build(BuildContext context) {
    final Color c = Color(score.colorValue);
    return Container(
      width: 17.0,
      height: 17.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0A0E1A),
        border: Border.all(color: c, width: 1.5),
      ),
      child: Text(
        score.displayLabel,
        style: TextStyle(color: c, fontSize: 9.0, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// The next arrow to shoot: a softly pulsing cyan pip.
class _NextPip extends HookWidget {
  const _NextPip();

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(duration: const Duration(milliseconds: 900));
    useEffect(() {
      controller.repeat(reverse: true);
      return null;
    }, const []);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(controller),
      child: Container(
        width: 17.0,
        height: 17.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x2200FFCC),
          border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
        ),
      ),
    );
  }
}

class _EmptyPip extends StatelessWidget {
  const _EmptyPip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17.0,
      height: 17.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E2638),
        border: Border.all(color: const Color(0xFF334155), width: 1.0),
      ),
    );
  }
}

class _BottomGuide extends StatelessWidget {
  const _BottomGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1A).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: const Color(0xFF1E2638), width: 1.0),
        ),
        child: const Text(
          'HOLD ANYWHERE TO AIM',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
