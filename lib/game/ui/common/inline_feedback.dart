import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'app_colors.dart';

/// In-container feedback primitives that replace floating SnackBars.
///
/// Project rule: network errors and validation issues animate the card itself
/// into an in-place state (icon + explanation + inline RETRY), and copy actions
/// show a glowing "✓ CODE COPIED" badge — never a generic floating SnackBar.

/// Smoothly cross-fades and resizes between a card's normal content and an
/// inline feedback state. Give each child a distinct [Key] so the switch animates.
class InlineFeedbackSwitcher extends StatelessWidget {
  final Widget child;

  const InlineFeedbackSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Frosted obsidian error state rendered inside a card or dialog.
///
/// Shows an icon, a short title, an explanation and (optionally) an inline
/// RETRY action and a dismiss control.
class InlineErrorPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onDismiss;
  final Color accent;

  const InlineErrorPanel({
    super.key,
    this.icon = Icons.wifi_off_rounded,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'RETRY',
    this.onDismiss,
    this.accent = AppColors.accentRed,
  });

  /// Turns raw exception text ("Exception: ...", "[cloud_firestore/...] ...")
  /// into a short human-readable sentence.
  static String friendlyMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
    final raw = error.toString();
    final cleaned = raw
        .replaceAll(
          RegExp(
            r'^(Exception:|Error:(\s*Dart Exception:)?)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'^\[[^\]]+\]\s*'), '')
        .trim();
    if (cleaned.isEmpty) return fallback;
    if (cleaned.toLowerCase().contains('permission-denied') ||
        cleaned.toLowerCase().contains('permission denied')) {
      return 'That action isn\'t allowed right now.';
    }
    if (cleaned.toLowerCase().contains('unavailable') ||
        cleaned.toLowerCase().contains('network')) {
      return 'Connection lost. Check your internet and try again.';
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14.0, 12.0, 10.0, 12.0),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34.0,
            height: 34.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: accent, size: 18.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8.0),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry!();
              },
              style: TextButton.styleFrom(
                foregroundColor: accent,
                backgroundColor: accent.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: Text(
                retryLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 16.0),
              color: AppColors.textMuted,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// High-contrast glowing confirmation badge, e.g. "✓ CODE COPIED".
///
/// Fades/scales in when [visible] is true; takes no space when hidden.
class CopiedBadge extends StatelessWidget {
  final bool visible;
  final String label;
  final Color color;

  const CopiedBadge({
    super.key,
    required this.visible,
    this.label = '✓ CODE COPIED',
    this.color = AppColors.accentNeonCyan,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: visible
          ? TweenAnimationBuilder<double>(
              key: ValueKey(label),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.0),
                  border: Border.all(color: color, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 12.0,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Hook: a boolean that turns on via `flash()` and switches itself off after
/// [duration]. Ideal for transient confirmations like [CopiedBadge].
({bool isOn, void Function() flash}) useFlashFlag([
  Duration duration = const Duration(milliseconds: 1800),
]) {
  final on = useState(false);
  final timer = useRef<Timer?>(null);
  useEffect(() => () => timer.value?.cancel(), const []);

  void flash() {
    timer.value?.cancel();
    on.value = true;
    timer.value = Timer(duration, () => on.value = false);
  }

  return (isOn: on.value, flash: flash);
}
