import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../darts_constants.dart';
import '../state/darts_match_notifier.dart';
import '../state/darts_match_state.dart';
import '../state/darts_players.dart';

/// Flutter HUD overlay over the Darts Flame canvas.
///
/// Implements §1.5 GamePigeon layout with Apple-standard translucent materials,
/// optical typography tracking, and direct interaction feedback:
/// - Top-left: Round indicator pill and 3 remaining dart icons.
/// - Top-right: Translucent frosted glass pause menu button.
/// - Bottom-left: Player 1 avatar, name, glowing badge, remaining score, and active turn points.
/// - Bottom-right: Opponent avatar, name, glowing badge, remaining score, and active turn points.
class DartsHud extends ConsumerWidget {
  final VoidCallback onOpenPause;

  const DartsHud({
    super.key,
    required this.onOpenPause,
  });

  /// HUD scale for this screen: 1.0 on a ~420×860 phone, smaller on small
  /// screens so the badges never crowd the board or the dart. Never larger.
  static double scaleFor(Size size) =>
      math.min(size.width / 420.0, size.height / 860.0).clamp(0.68, 1.0).toDouble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dartsMatchProvider);
    final players = ref.watch(dartsPlayersProvider);
    final double s = scaleFor(MediaQuery.sizeOf(context));
    final double pad = 16.0 * s;

    // Only the pills and badges ignore touches (so throws pass through);
    // the pause button stays tappable. Wrapping the whole HUD in one
    // IgnorePointer made the pause button dead.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8.0 * s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Top Bar: Round & Darts Left | Pause Button ──────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IgnorePointer(
                  child: Transform.scale(
                    scale: s,
                    alignment: Alignment.centerLeft,
                    child: _RoundAndDartsPill(
                      round: state.round,
                      dartsThrown: state.turnDarts.length,
                      activeColor: state.thrower == DartsThrower.you
                          ? const Color(DartsK.accentP1)
                          : const Color(DartsK.accentP2),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: s,
                  alignment: Alignment.centerRight,
                  child: _PauseButton(onTap: onOpenPause),
                ),
              ],
            ),

            // ── Bottom Bar: P1 and Opponent Remaining Score Badges ───────────
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Player 1 (You) Badge. Sizes are scaled for real (so the
                  // layout shrinks too); FittedBox is a last guard for long
                  // names on tiny screens.
                  Flexible(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: _ScoreBadge(
                    scale: s,
                    player: players.you,
                    remaining: state.yourRemaining,
                    turnScore: state.thrower == DartsThrower.you
                        ? state.turnScore
                        : 0,
                    isActive: state.thrower == DartsThrower.you,
                    glowColor: const Color(DartsK.accentP1),
                    isLeft: true,
                  ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.0 * s),

                  // Opponent Badge
                  Flexible(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomRight,
                        child: _ScoreBadge(
                    scale: s,
                    player: players.opponent,
                    remaining: state.theirRemaining,
                    turnScore: state.thrower == DartsThrower.opponent
                        ? state.turnScore
                        : 0,
                    isActive: state.thrower == DartsThrower.opponent,
                    glowColor: const Color(DartsK.accentP2),
                    isLeft: false,
                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Translucent top pill indicating round number and the 3 dart icons.
class _RoundAndDartsPill extends StatelessWidget {
  final int round;
  final int dartsThrown;
  final Color activeColor;

  const _RoundAndDartsPill({
    required this.round,
    required this.dartsThrown,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final int dartsRemaining = (DartsK.dartsPerTurn - dartsThrown).clamp(0, DartsK.dartsPerTurn);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: const Color(0xB30F172A),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: const Color(0x26FFFFFF),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 16.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ROUND $round/${DartsK.maxRounds}',
                style: const TextStyle(
                  color: Color(DartsK.textMuted),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  fontVariations: [FontVariation('wght', 800)],
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 10.0),
              Container(
                width: 1.0,
                height: 14.0,
                color: const Color(0x33FFFFFF),
              ),
              const SizedBox(width: 10.0),
              // 3 Darts Indicators
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(DartsK.dartsPerTurn, (i) {
                  final bool isAvailable = i < dartsRemaining;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(left: 4.0),
                    width: 7.0,
                    height: 16.0,
                    decoration: BoxDecoration(
                      color: isAvailable ? activeColor : const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(3.5),
                      boxShadow: isAvailable
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.5),
                                blurRadius: 6.0,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent frosted glass pause menu button with Apple-standard touch response.
class _PauseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PauseButton({required this.onTap});

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
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
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                width: 38.0,
                height: 38.0,
                decoration: BoxDecoration(
                  color: _pressed
                      ? const Color(0xE61E293B)
                      : const Color(0xB30F172A),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: _pressed
                        ? const Color(0x66FFFFFF)
                        : const Color(0x26FFFFFF),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16.0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

/// GamePigeon-style Player Remaining Score Badge in the lower corners.
class _ScoreBadge extends StatelessWidget {
  /// Size factor for this screen (see [DartsHud.scaleFor]).
  final double scale;
  final DartsPlayer player;
  final int remaining;
  final int turnScore;
  final bool isActive;
  final Color glowColor;
  final bool isLeft;

  const _ScoreBadge({
    required this.scale,
    required this.player,
    required this.remaining,
    required this.turnScore,
    required this.isActive,
    required this.glowColor,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        // Main Glass Badge Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0 * scale),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.35),
                      blurRadius: 20.0 * scale,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 14.0,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0 * scale),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: 12.0 * scale,
                  vertical: 8.0 * scale,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xD90F172A)
                      : const Color(0x990F172A),
                  borderRadius: BorderRadius.circular(20.0 * scale),
                  border: Border.all(
                    color: isActive
                        ? glowColor.withValues(alpha: 0.8)
                        : const Color(0x22FFFFFF),
                    width: isActive ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: isLeft
                      ? [
                          _buildAvatar(),
                          SizedBox(width: 9.0 * scale),
                          _buildNameAndScore(),
                        ]
                      : [
                          _buildNameAndScore(),
                          SizedBox(width: 9.0 * scale),
                          _buildAvatar(),
                        ],
                ),
              ),
            ),
          ),
        ),

        // Running Turn Score Indicator under active thrower badge
        AnimatedOpacity(
          opacity: isActive && turnScore > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: EdgeInsets.only(top: 6.0 * scale, left: 8.0 * scale, right: 8.0 * scale),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.0 * scale, vertical: 3.0 * scale),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: glowColor.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Text(
                '+$turnScore',
                style: TextStyle(
                  color: glowColor,
                  fontSize: 13.0 * scale,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Inter',
                  fontVariations: const [FontVariation('wght', 900)],
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return AppAvatar(
      avatar: player.avatar,
      size: 36.0 * scale,
    );
  }

  Widget _buildNameAndScore() {
    return Column(
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          // Long names end in "…" instead of widening the badge.
          constraints: BoxConstraints(maxWidth: 104.0 * scale),
          child: Text(
          player.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(DartsK.textMuted),
            fontSize: 10.5 * scale,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            fontVariations: const [FontVariation('wght', 800)],
            letterSpacing: 0.8,
          ),
        ),
        ),
        SizedBox(height: 2.0 * scale),
        Text(
          '$remaining',
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 22.0 * scale,
            fontWeight: FontWeight.w900,
            fontFamily: 'Inter',
            fontVariations: const [FontVariation('wght', 900)],
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
