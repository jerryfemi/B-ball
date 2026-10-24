import 'package:flutter/material.dart';

import '../../archery/ui/archery_pause_menu.dart';

/// Darts pause menu: the same compact menu as archery (music, sound effects
/// and pub ambience with switches and sliders; resume / how to play /
/// restart / lobby).
///
/// Solo play freezes while it is open; online, the shot clock keeps running,
/// so there is no restart.
class DartsPauseMenu extends StatelessWidget {
  final bool online;
  final VoidCallback onResume;
  final VoidCallback onHowToPlay;
  final VoidCallback? onRestart;
  final VoidCallback onLobby;

  const DartsPauseMenu({
    super.key,
    required this.online,
    required this.onResume,
    required this.onHowToPlay,
    required this.onLobby,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return ArcheryPauseMenu(
      online: online,
      onResume: onResume,
      onLobby: onLobby,
      onRestart: online ? null : onRestart,
      onHowToPlay: onHowToPlay,
    );
  }
}
