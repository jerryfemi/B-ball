import 'package:flutter/material.dart';

import '../lobby_style.dart';
import 'account_chip.dart';

/// Lobby top bar: the GAMEVERSE jersey wordmark and the account chip.
class LobbyHeader extends StatelessWidget {
  const LobbyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 480;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: GameVerseWordmark(size: narrow ? 22 : 27),
          ),
        ),
        const SizedBox(width: 12),
        AccountChip(compact: narrow),
      ],
    );
  }
}

/// The GameVerse logo: a slanted, extra-wide jersey wordmark. No icon.
class GameVerseWordmark extends StatelessWidget {
  final double size;
  const GameVerseWordmark({super.key, this.size = 27});

  /// About 9° of slant, like a jersey number.
  static final Matrix4 _slant = Matrix4.skewX(-0.16);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'GameVerse',
      child: ExcludeSemantics(
        child: Transform(
          transform: _slant,
          alignment: Alignment.center,
          child: Text(
            'GAMEVERSE',
            maxLines: 1,
            style: LobbyStyle.text(
              size: size,
              weight: 900,
              width: 125,
              letterSpacing: -0.03 * size,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
