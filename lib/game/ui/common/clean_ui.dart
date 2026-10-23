import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The clean, soft look of the archery pause menu, shared by the match
/// dialogs: one dark surface, a centred title, labelled rows and big pill
/// buttons. No boxes inside boxes.
abstract final class CleanUi {
  static const Color surface = Color(0xF20F172A);
  static const Color line = Color(0xFF1E2638);
  static const Color track = Color(0xFF1E2638);
  static const Color ink = Color(0xFF0A0E1A);
  static const Color muted = Color(0xFF94A3B8);
  static const Color subtle = Color(0xFF64748B);
  static const Color accent = Color(0xFF00FFCC);

  /// Opens [child] (usually a [CleanDialog]) over a dim backdrop.
  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) {
    return showDialog<T>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: builder,
    );
  }

  static const TextStyle label = TextStyle(
    color: Colors.white,
    fontSize: 11.0,
    fontWeight: FontWeight.w900,
    fontFamily: 'Inter',
    fontVariations: [FontVariation('wght', 900)],
    letterSpacing: 0.6,
  );
}

/// Dialog shell: centred title, optional subtitle, close button.
class CleanDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showClose;
  final double maxWidth;

  const CleanDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showClose = true,
    this.maxWidth = 380.0,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: CleanUi.surface,
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(color: CleanUi.line, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0xCC000000), blurRadius: 30.0, offset: Offset(0, 10)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            // Inter for every dialog's text (weights set per style).
            textStyle: const TextStyle(fontFamily: 'Inter'),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20.0, 18.0, 20.0, 18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36.0),
                        child: Column(
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Inter',
                                fontVariations: [FontVariation('wght', 900)],
                                letterSpacing: 1.6,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4.0),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: CleanUi.muted,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  fontVariations: [FontVariation('wght', 500)],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showClose)
                        Positioned(
                          right: -8.0,
                          top: -6.0,
                          child: IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, color: CleanUi.muted, size: 20.0),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18.0),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice in a [CleanSegmented] control.
class CleanSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const CleanSegment(this.value, this.label, {this.icon});
}

/// Pill segmented control: one track, the chosen segment filled with [accent].
class CleanSegmented<T> extends StatelessWidget {
  final List<CleanSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final Color accent;

  const CleanSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.accent = CleanUi.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.0,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: CleanUi.track,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: s.value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null || s.value == selected
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onChanged!(s.value);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: s.value == selected ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(9.0),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (s.icon != null) ...[
                              Icon(
                                s.icon,
                                size: 15.0,
                                color: s.value == selected
                                    ? CleanUi.ink
                                    : (onChanged == null ? CleanUi.subtle : CleanUi.muted),
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            Text(
                              s.label,
                              style: TextStyle(
                                color: s.value == selected
                                    ? CleanUi.ink
                                    : (onChanged == null ? CleanUi.subtle : Colors.white),
                                fontSize: 12.0,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Inter',
                                fontVariations: const [FontVariation('wght', 900)],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Labelled row (icon + caps label on the left, a control on the right),
/// like the audio rows of the pause menu.
class CleanRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final Color iconColor;

  const CleanRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.iconColor = CleanUi.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 18.0, color: iconColor),
          const SizedBox(width: 8.0),
          SizedBox(width: 74.0, child: Text(label, style: CleanUi.label)),
          Expanded(child: trailing),
        ],
      ),
    );
  }
}

/// Big pill button: solid accent (primary) or dark (secondary).
class CleanButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;
  final Color accent;

  const CleanButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.loading = false,
    this.accent = CleanUi.accent,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = primary ? CleanUi.ink : Colors.white;
    return SizedBox(
      height: 46.0,
      child: ElevatedButton(
        onPressed: loading || onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary ? accent : CleanUi.track,
          foregroundColor: fg,
          disabledBackgroundColor: primary ? accent.withValues(alpha: 0.55) : CleanUi.track,
          disabledForegroundColor: fg.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
        ),
        child: loading
            ? SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18.0),
                    const SizedBox(width: 8.0),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Inter',
                        fontVariations: [FontVariation('wght', 900)],
                        letterSpacing: 0.9,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
