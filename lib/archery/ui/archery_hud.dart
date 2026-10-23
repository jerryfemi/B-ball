import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../../game/ui/match/incoming_challenge_dialog.dart';
import '../../models/cloud_match.dart';
import '../../models/match_invite.dart';
import '../../providers/app_providers.dart';
import '../archery_game_screen.dart' show ArcheryChallenge;
import '../archery_constants.dart';
import '../archery_game.dart';
import '../camera/camera_rig.dart';
import '../state/archery_match_notifier.dart';
import '../state/archery_match_state.dart';
import '../state/archery_players.dart';
import 'live_pill.dart';
import 'round_summary.dart';
import 'turn_banner.dart';

/// Flutter HUD over the Flame canvas: GamePigeon-style scoreboard, the live
/// status pill and turn banner (online), and the set-end card. Each piece
/// watches only the state slice it shows.
class ArcheryHud extends ConsumerWidget {
  final ArcheryGame game;

  /// Online: where "BACK TO LOBBY" goes after the match.
  final VoidCallback? onExitToLobby;

  const ArcheryHud({super.key, required this.game, this.onExitToLobby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (phase, online, setOver) = ref.watch(
      archeryMatchProvider.select((s) => (s.phase, s.online, s.setOver)),
    );
    final bool showScoreBar = online ||
        phase == ShotPhase.atLine ||
        phase == ShotPhase.intro ||
        phase == ShotPhase.closeup ||
        phase == ShotPhase.returning ||
        phase == ShotPhase.setEnd;
    final bool showSetEnd = online ? setOver : phase == ShotPhase.setEnd;
    final double top = MediaQuery.paddingOf(context).top + 8.0;

    return Stack(
      children: [
        Positioned(
          top: top,
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
        if (online) ...[
          Positioned(
            top: top + 104.0,
            left: 0.0,
            right: 0.0,
            child: Center(child: LivePill(game: game)),
          ),
          const Positioned.fill(child: IgnorePointer(child: TurnBanner())),
        ],
        if (showSetEnd) _SetEnd(game: game, onExitToLobby: onExitToLobby),
      ],
    );
  }
}

class _SetEnd extends HookConsumerWidget {
  final ArcheryGame game;
  final VoidCallback? onExitToLobby;
  const _SetEnd({required this.game, this.onExitToLobby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(archeryMatchProvider);
    final players = ref.watch(archeryPlayersProvider);
    final online = game.online;

    // Online match over: nobody rematched -> back to solo against the bot.
    // Shorter when the opponent left. Paused while their rematch invite is
    // waiting, stopped once you tap REMATCH or JOIN.
    final bool onlineOver = online != null && s.matchOver;
    final CloudMatch? endDoc = online?.match.value;
    final bool oppLeft = endDoc != null &&
        (endDoc.status == MatchStatus.forfeited || endDoc.status == MatchStatus.abandoned);
    final left = useState<int>(oppLeft ? 10 : 45);
    final acted = useRef(false);
    final inviteWaiting = useRef(false);
    useEffect(() {
      if (!onlineOver) return null;
      left.value = oppLeft ? 10 : 45;
      final t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (acted.value || inviteWaiting.value) return;
        left.value--;
        if (left.value <= 0) {
          t.cancel();
          if (context.mounted) GoRouter.maybeOf(context)?.go('/archery');
        }
      });
      return t.cancel;
    }, [onlineOver, oppLeft]);

    String label;
    VoidCallback onContinue;
    String? secondaryLabel;
    VoidCallback? onSecondary;
    if (online == null) {
      label = s.matchOver ? 'PLAY AGAIN' : 'NEXT SET';
      onContinue = s.matchOver ? game.restartMatch : game.advanceNextSet;
    } else if (!s.matchOver) {
      label = 'NEXT SET';
      onContinue = online.continueAfterSet;
    } else {
      // Match over: rematch the same opponent (or join theirs if they were
      // quicker), or exit to keep shooting on your own.
      final finished = online.match.value;
      final String oppUid = finished?.opponentPlayer(online.myUid)?.uid ?? '';
      final MatchInvite? theirRematch = oppUid.isEmpty
          ? null
          : (ref.watch(incomingMatchChallengesProvider).value ?? const <MatchInvite>[])
              .where((i) => i.isPending && i.hostUid == oppUid)
              .firstOrNull;
      inviteWaiting.value = theirRematch != null;
      if (theirRematch != null) {
        label = 'JOIN ${theirRematch.hostName.toUpperCase()}\'S REMATCH';
        onContinue = () {
          acted.value = true;
          IncomingChallengeDialog.show(
            context: context,
            invite: theirRematch,
            onAccepted: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
          );
        };
      } else {
        label = 'REMATCH';
        onContinue = () async {
          if (finished == null) return;
          acted.value = true;
          try {
            await ArcheryChallenge.rematch(context, finished: finished, myUid: online.myUid);
          } catch (_) {
            acted.value = false; // couldn't start it: let the countdown resume
          }
        };
      }
      secondaryLabel = acted.value || inviteWaiting.value
          ? 'BACK TO SOLO'
          : 'BACK TO SOLO · ${left.value}s';
      onSecondary = () => GoRouter.maybeOf(context)?.go('/archery');
    }

    return SetEndCard(
      // A new card (and countdown) per set.
      key: ValueKey('set-${s.setIndex}-${s.matchOver}'),
      setIndex: s.setIndex,
      userScores: s.setShots,
      opponentScores: s.opponentShots,
      userSetPoints: s.userPoints,
      opponentSetPoints: s.opponentPoints,
      isMatchOver: s.matchOver,
      winner: s.winner,
      you: players.you,
      opponent: players.opponent,
      continueLabel: label,
      onContinue: onContinue,
      autoContinueSeconds: online != null ? 5 : null,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    );
  }
}

/// Compact GamePigeon-style scoreboard:
///
///   (you)  [ SET 2 · 100ft ]  (them)
///    You   [    18 - 26    ]   Bot
///   ▢▢▢                       ▢▢▢     ← one chip per arrow, ring-coloured
///
/// The coin on each avatar is that archer's set points (first to 6).
/// Online, the archer whose set it is gets a glowing ring.
class _Scoreboard extends ConsumerWidget {
  const _Scoreboard();

  static const Color _youRing = Color(0xFF00FFCC);
  static const Color _themRing = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(archeryPlayersProvider);
    // Records compare by value; the lists are replaced on every change.
    final (setIndex, you, them, youPts, themPts, online, shooter) = ref.watch(
      archeryMatchProvider.select(
        (s) => (
          s.setIndex,
          s.setShots,
          s.opponentShots,
          s.userPoints,
          s.opponentPoints,
          s.online,
          s.shooter,
        ),
      ),
    );
    final int youTotal = you.fold(0, (sum, s) => sum + s.points);
    final int themTotal = them.fold(0, (sum, s) => sum + s.points);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayerBadge(
          player: players.you,
          ring: _youRing,
          sets: youPts,
          active: online && shooter == ArcheryShooter.you,
          chips: [for (final s in you) _ChipData(s.ring, isX: s.isX)],
        ),
        const SizedBox(width: 8.0),
        _ScoreBox(setIndex: setIndex, you: youTotal, them: themTotal),
        const SizedBox(width: 8.0),
        _PlayerBadge(
          player: players.opponent,
          ring: _themRing,
          sets: themPts,
          active: online && shooter == ArcheryShooter.opponent,
          chips: [for (final s in them) _ChipData(s.ring, isX: s.isX)],
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

  /// Online: this archer is shooting now (glowing ring).
  final bool active;

  const _PlayerBadge({
    required this.player,
    required this.ring,
    required this.sets,
    required this.chips,
    this.active = false,
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
                  showGlow: active,
                  glowColor: ring,
                ),
              ),
              if (sets > 0)
                Positioned(
                  right: -5.0,
                  bottom: -3.0,
                  child: _SetCoinTracker(count: sets),
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

/// Gold set-points coin. When it goes up it pops in and "+N" floats off it.
/// Remembers the previous set points so the coin can say "+2" or "+1".
class _SetCoinTracker extends StatefulWidget {
  final int count;
  const _SetCoinTracker({required this.count});

  @override
  State<_SetCoinTracker> createState() => _SetCoinTrackerState();
}

class _SetCoinTrackerState extends State<_SetCoinTracker> {
  late int _gain = widget.count;

  @override
  void didUpdateWidget(_SetCoinTracker old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count) _gain = widget.count - old.count;
  }

  @override
  Widget build(BuildContext context) => _SetCoin(count: widget.count, gain: _gain);
}

class _SetCoin extends StatelessWidget {
  final int count;
  final int gain;
  const _SetCoin({required this.count, required this.gain});

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
                  child: Text(
                    '+$gain',
                    style: const TextStyle(
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
