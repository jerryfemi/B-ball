import 'package:flutter/material.dart';

import '../game_catalog.dart';
import '../lobby_style.dart';
import 'pressable.dart';

/// A game in the "All games" shelf: gameplay picture on top, the name and
/// one line below it, and a round play button (or "Coming soon").
/// [highlighted] draws an accent ring (the game in the banner).
class GameCard extends StatelessWidget {
  final LobbyGame game;
  final VoidCallback onTap;
  final bool highlighted;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.highlighted = false,
  });

  /// Height of the caption under the picture (title + two lines).
  static const double captionHeight = 96;

  /// Greys out games that aren't playable yet.
  static const ColorFilter _dim = ColorFilter.matrix(<double>[
    0.45, 0.35, 0.05, 0, -14, //
    0.15, 0.65, 0.05, 0, -14,
    0.15, 0.35, 0.35, 0, -14,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final g = game;
    Widget picture = Image.asset(
      g.image,
      fit: BoxFit.cover,
      alignment: g.imageAlignment,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (!g.available) picture = ColorFiltered(colorFilter: _dim, child: picture);

    return Pressable(
      semanticLabel: g.available ? 'Play ${g.title}' : '${g.title}, coming soon',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ring sits 3 px outside the picture; same padding either way so
          // every tile lines up.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: highlighted ? g.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: LobbyStyle.surface, child: picture),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x14FFFFFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: captionHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 12, 5, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LobbyStyle.text(size: 24, weight: 800, width: 115, letterSpacing: -0.24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          g.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LobbyStyle.text(size: 14, color: LobbyStyle.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (g.available)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: g.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, size: 22, color: LobbyStyle.ink),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Coming soon',
                        style: LobbyStyle.text(size: 13, weight: 500, color: LobbyStyle.muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
