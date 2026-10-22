import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Tap target that dips to 98% the moment it's pressed (feedback on press,
/// not on release) and fires a light haptic on the tap itself.
class Pressable extends HookWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => pressed.value = true,
          onTapUp: (_) => pressed.value = false,
          onTapCancel: () => pressed.value = false,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: AnimatedScale(
            scale: pressed.value ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pill button: solid accent (primary) or translucent (secondary).
class LobbyPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool showPlayIcon;
  final TextStyle style;

  const LobbyPillButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.style,
    this.accent,
    this.showPlayIcon = false,
  });

  static const Color _ink = Color(0xFF0A0E1A);

  @override
  Widget build(BuildContext context) {
    final bool primary = accent != null;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: primary ? accent : const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: primary ? null : Border.all(color: const Color(0x29FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPlayIcon) ...[
              Icon(Icons.play_arrow_rounded, size: 20, color: primary ? _ink : Colors.white),
              const SizedBox(width: 4),
            ],
            Text(label, style: style.copyWith(color: primary ? _ink : Colors.white)),
          ],
        ),
      ),
    );
  }
}
