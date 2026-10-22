import 'package:flutter/material.dart';

import '../game_catalog.dart';
import '../lobby_style.dart';
import 'pressable.dart';

/// The big banner at the top of the lobby: one game's gameplay art, its
/// name, a short pitch, Play and Challenge a friend. Only the buttons are
/// tap targets, so a tap on the art can't start a game by accident.
///
/// Wide screens: text on the left over a dark side fade. Phones: a tall
/// poster with the text at the bottom over a dark bottom fade.
class FeaturedHero extends StatelessWidget {
  final LobbyGame game;
  final VoidCallback onPlay;
  final VoidCallback? onChallenge;

  const FeaturedHero({
    super.key,
    required this.game,
    required this.onPlay,
    this.onChallenge,
  });

  static const Color _ink = LobbyStyle.ink;

  static const LinearGradient _sideFade = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xF00A0E1A), Color(0xB30A0E1A), Color(0x000A0E1A)],
    stops: [0.0, 0.34, 0.62],
  );
  static const LinearGradient _bottomShade = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0x990A0E1A), Color(0x000A0E1A)],
    stops: [0.0, 0.4],
  );
  static const LinearGradient _posterFade = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xF70A0E1A), Color(0xBF0A0E1A), Color(0x000A0E1A)],
    stops: [0.0, 0.42, 0.72],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 600;
        final double radius = narrow ? 24 : 28;
        final double height = narrow ? 520 : 440;

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: _ink,
                  child: Image.asset(
                    game.heroImage,
                    fit: BoxFit.cover,
                    alignment: narrow ? game.heroAlignmentNarrow : game.heroAlignment,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
                if (narrow)
                  const DecoratedBox(decoration: BoxDecoration(gradient: _posterFade))
                else ...const [
                  DecoratedBox(decoration: BoxDecoration(gradient: _sideFade)),
                  DecoratedBox(decoration: BoxDecoration(gradient: _bottomShade)),
                ],
                // Hairline edge so the banner reads as a surface, not a hole.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: const Color(0x17FFFFFF)),
                  ),
                ),
                Positioned(
                  left: narrow ? 22 : 48,
                  right: narrow ? 22 : null,
                  bottom: narrow ? 24 : 48,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _Copy(game: game, narrow: narrow, onPlay: onPlay, onChallenge: onChallenge),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Copy extends StatelessWidget {
  final LobbyGame game;
  final bool narrow;
  final VoidCallback onPlay;
  final VoidCallback? onChallenge;

  const _Copy({
    required this.game,
    required this.narrow,
    required this.onPlay,
    required this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (game.featuredLabel.isNotEmpty) ...[
          Text(
            game.featuredLabel,
            style: LobbyStyle.text(size: 14, weight: 600, color: game.accent),
          ),
          const SizedBox(height: 12),
        ],
        Text(game.title, style: LobbyStyle.display(narrow ? 54 : 76)),
        const SizedBox(height: 14),
        Text(
          game.pitch,
          style: LobbyStyle.text(
            size: narrow ? 16 : 17,
            color: LobbyStyle.soft,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            LobbyPillButton(
              label: 'Play',
              accent: game.accent,
              showPlayIcon: true,
              style: LobbyStyle.button,
              onTap: onPlay,
            ),
            if (onChallenge != null)
              LobbyPillButton(
                label: 'Challenge a friend',
                style: LobbyStyle.text(size: 15, weight: 600),
                onTap: onChallenge!,
              ),
          ],
        ),
      ],
    );
  }
}
