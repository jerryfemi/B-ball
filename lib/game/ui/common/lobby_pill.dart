
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui_font.dart';

/// "‹ Lobby": a labelled way back to the GameVerse lobby, top-left in every
/// game. Words beat an icon here; players didn't recognise the old grid icon.
class LobbyPill extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const LobbyPill({
    super.key,
    required this.onTap,
    this.compact = true,
  });

  @override
  State<LobbyPill> createState() => _LobbyPillState();
}

class _LobbyPillState extends State<LobbyPill> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back to the lobby',
      child: GestureDetector(
        // Feedback on press, action on release.
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              // No backdrop blur here: over the live game it re-blurs every frame.
              child: Container(
                height: widget.compact ? 32 : 40,
                padding: widget.compact
                    ? const EdgeInsets.fromLTRB(6, 0, 10, 0)
                    : const EdgeInsets.fromLTRB(8, 0, 14, 0),
                decoration: BoxDecoration(
                  color: const Color(0xE80F172A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x2EFFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      size: widget.compact ? 18 : 22,
                      color: Colors.white,
                    ),
                    Text(
                      'Lobby',
                      style: UiFont.style(
                        size: widget.compact ? 12.5 : 14.5,
                        weight: 700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
