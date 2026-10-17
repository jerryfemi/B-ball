import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'common/app_button.dart';
import 'common/app_colors.dart';
import 'common/app_modal_dialog.dart';

/// Displays the collegiate "HOW TO PLAY" rules dialog.
Future<void> showGameRulesDialog(BuildContext context, {BasketballGame? game}) {
  return AppModalDialog.show<void>(
    context: context,
    builder: (context) => GameRulesDialog(game: game),
  );
}

/// Collegiate rules modal explaining HUD controls, flicks, clock, and scoring bonuses.
class GameRulesDialog extends StatelessWidget {
  final BasketballGame? game;

  const GameRulesDialog({super.key, this.game});

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      title: 'HOW TO PLAY',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.46,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'HUD & GAME CONTROLS',
                    trailing: game != null
                        ? TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              game!.isTourActiveNotifier.value = true;
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 14.0,
                                  color: Color(0xFF38BDF8),
                                ),
                                SizedBox(width: 4.0),
                                Text(
                                  'Replay',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8.0),
                  const _RuleRow(
                    icon: '👤',
                    title: 'Your Avatar (Top-Left)',
                    desc:
                        'Tap your avatar anytime to view friend invites, check H2H stats, and host 1v1 matches.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '⚡',
                    title: 'Bouncing Avatar (Turn Alert)',
                    desc:
                        'Your avatar pulses rhythmically when it is your turn to shoot, or when you receive a match invite.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '💬',
                    title: 'Opponent Avatar & Chat',
                    desc:
                        'Tap the opponent avatar during 1v1 online matches to send trash-talk reactions and live banter.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '⏸️',
                    title: 'Pause & Sound Controls',
                    desc:
                        'Tap pause to adjust SFX/music volume, mute, or restart your solo round.',
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 18.0)),
                      const SizedBox(width: 12.0),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visual Court Tour',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2.0),
                            Text(
                              'Tap "Replay" to see in-game spotlight walkthrough on court.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (game != null)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            game!.isTourActiveNotifier.value = true;
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Replay',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  const _SectionHeader(title: 'SHOOTING & SCORING'),
                  const SizedBox(height: 8.0),
                  const _RuleRow(
                    icon: '🏀',
                    title: 'Flick to Shoot',
                    desc: 'Swipe up with finger speed and angle towards the hoop.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '🔥',
                    title: 'Swish (+3 PTS)',
                    desc: 'Clean shot through the net without hitting rim or backboard.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '🎯',
                    title: 'Bank Shot (+3 PTS)',
                    desc: 'Rebound the ball off the regulation tempered glass target box.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '⚡',
                    title: 'Streak Bonus (+1)',
                    desc: 'Sink 3+ in a row to earn +1 extra bonus point per consecutive basket!',
                  ),
                  const SizedBox(height: 16.0),
                  const _SectionHeader(title: '1V1 ONLINE SHOOTOUT'),
                  const SizedBox(height: 8.0),
                  const _RuleRow(
                    icon: '⚔️',
                    title: 'Asynchronous Rounds',
                    desc: 'Challenge friends via 6-digit room codes or direct invites across 2, 3, or 4 rounds.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '👻',
                    title: 'Ghost Replay',
                    desc: "Spectate your opponent's exact shots and arc trajectory flying in real-time before you shoot.",
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '🏆',
                    title: 'Cumulative Score',
                    desc: 'Highest total score across all rounds takes the crown and ascends the winner podium.',
                  ),
                  const SizedBox(height: 16.0),
                  const _SectionHeader(title: '1V1 PASS & PLAY'),
                  const SizedBox(height: 8.0),
                  const _RuleRow(
                    icon: '📱',
                    title: 'Single Device Local Match',
                    desc: 'Play head-to-head with a friend in person on the exact same screen.',
                  ),
                  const SizedBox(height: 10.0),
                  const _RuleRow(
                    icon: '🤝',
                    title: 'Handoff Between Rounds',
                    desc: 'Player 1 shoots their round, then pass the phone to Player 2 to answer back!',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          AppPrimaryButton(
            label: 'GOT IT',
            backgroundColor: AppColors.accentEmerald,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: const Color(0x2238BDF8),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: const Color(0x4438BDF8), width: 1.0),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;

  const _RuleRow({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18.0)),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
