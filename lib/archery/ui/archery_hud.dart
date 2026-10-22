import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../archery_constants.dart';
import '../archery_game.dart';
import '../camera/camera_rig.dart';
import '../state/archery_match_notifier.dart';
import '../state/archery_match_state.dart';
import '../state/archery_players.dart';
import 'round_summary.dart';

/// Flutter HUD over the Flame canvas: GamePigeon-style scoreboard and the
/// set-end card. Each piece watches only the state slice it shows.
class ArcheryHud extends ConsumerWidget {
  final ArcheryGame game;

  const ArcheryHud({super.key, required this.game});

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

/// Compact GamePigeon-style scoreboard:
///
///   (you)  [ SET 2 · 100ft ]  (them)
///    You   [    18 - 26    ]   Bot
///   ▢▢▢                       ▢▢▢     ← one chip per arrow, ring-coloured
class _Scoreboard extends ConsumerWidget {
  const _Scoreboard();

  static const Color _youRing = Color(0xFF00FFCC);
  static const Color _themRing = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(archeryPlayersProvider);
    // Records compare by value; the lists are replaced on every change.
    final (setIndex, you, them, youSets, themSets) = ref.watch(
      archeryMatchProvider.select(
        (s) => (s.setIndex, s.setShots, s.botShots, s.userSets, s.botSets),
      ),
    );
    final int youTotal = you.fold(0, (sum, s) => sum + s.points);
    final int themTotal = them.fold(0, (sum, p) => sum + p);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayerBadge(
          player: players.you,
          ring: _youRing,
          sets: youSets,
          chips: [for (final s in you) _ChipData(s.ring, isX: s.isX)],
        ),
        const SizedBox(width: 8.0),
        _ScoreBox(setIndex: setIndex, you: youTotal, them: themTotal),
        const SizedBox(width: 8.0),
        _PlayerBadge(
          player: players.opponent,
          ring: _themRing,
          sets: themSets,
          chips: [for (final p in them) _ChipData(p)],
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
    fontSize: 22.0,
    height: 1.1,
    fontWeight: FontWeight.w900,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      padding: const EdgeInsets.fromLTRB(12.0, 5.0, 12.0, 6.0),
      decoration: BoxDecoration(
        color: const Color(0xE00F172A),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 10.0, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SET ${setIndex + 1} · ${ArcheryK.distanceLabelForSet(setIndex)}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
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

/// Avatar (with the set coin), name, and the three arrow chips.
/// Tapping does nothing: profile editing lives in the lobby.
class _PlayerBadge extends StatelessWidget {
  final ArcheryPlayer player;
  final Color ring;
  final int sets;
  final List<_ChipData> chips;

  const _PlayerBadge({
    required this.player,
    required this.ring,
    required this.sets,
    required this.chips,
  });

  static const double avatarSize = 42.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x59000000), blurRadius: 8.0, offset: Offset(0, 2)),
                  ],
                ),
                child: AppAvatar(
                  avatar: player.avatar,
                  size: avatarSize,
                  borderColor: ring,
                  borderWidth: 2.5,
                ),
              ),
              if (sets > 0)
                Positioned(
                  right: -5.0,
                  bottom: -3.0,
                  child: _SetCoin(count: sets),
                ),
            ],
          ),
          const SizedBox(height: 3.0),
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Color(0xCC000000), blurRadius: 3.0),
                Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
              ],
            ),
          ),
          const SizedBox(height: 3.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < ArcheryMatchState.arrowsPerSet; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0.0 : 3.0),
                  child: _ArrowChip(data: i < chips.length ? chips[i] : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipData {
  final int ring;
  final bool isX;
  const _ChipData(this.ring, {this.isX = false});
}

/// One arrow: empty outline until it lands, then filled in its ring colour.
class _ArrowChip extends StatelessWidget {
  final _ChipData? data;
  const _ArrowChip({required this.data});

  static const double _w = 17.0;
  static const double _h = 15.0;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) {
      return Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: const Color(0x59FFFFFF)),
        ),
      );
    }
    final (Color fill, Color text) = _colors(d.ring);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        width: _w,
        height: _h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: const Color(0x66000000), width: 0.8),
        ),
        child: Text(
          d.isX ? 'X' : (d.ring > 0 ? '${d.ring}' : 'M'),
          style: TextStyle(
            color: text,
            fontSize: 9.5,
            height: 1.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  /// Same colours as the target face rings.
  static (Color, Color) _colors(int ring) {
    if (ring >= 9) return (const Color(0xFFF7D000), const Color(0xFF1F1500));
    if (ring >= 7) return (const Color(0xFFE0322B), Colors.white);
    if (ring >= 5) return (const Color(0xFF2E7DD7), Colors.white);
    if (ring >= 3) return (const Color(0xFF1F2937), Colors.white);
    if (ring >= 1) return (const Color(0xFFF8FAFC), const Color(0xFF0F172A));
    return (const Color(0xFF475569), Colors.white);
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
        width: 18.0,
        height: 18.0,
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
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
