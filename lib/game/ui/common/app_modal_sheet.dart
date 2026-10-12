import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_decorations.dart';

/// Centralized modal bottom sheet scaffold for B-Ball.
///
/// Provides a consistent glass/obsidian surface, top grab bar, optional header
/// with title/subtitle/actions, keyboard avoidance, and safe area containment.
class AppModalSheet extends StatelessWidget {
  /// Proportional height factor of screen height (e.g. 0.85).
  /// If null and [height] is null, the sheet sizes dynamically to its children.
  final double? heightFactor;

  /// Explicit height in logical pixels.
  final double? height;

  /// Custom background color (defaults to [AppColors.surfaceSheet]).
  final Color? backgroundColor;

  /// Whether to render the standardized rounded grab handle bar.
  final bool showDragHandle;

  /// Custom full header widget replacing default title layout.
  final Widget? header;

  /// Standard title string.
  final String? title;

  /// Optional subtitle below title.
  final String? subtitle;

  /// Optional widget on the left side of the header (e.g. back button).
  final Widget? leading;

  /// Optional widget on the right side of the header (e.g. close button or badge).
  final Widget? trailing;

  /// Callback when default close icon is tapped. If null and neither [trailing] nor [header]
  /// is provided while [title] is set, closes current route.
  final VoidCallback? onClose;

  /// Outer padding for sheet content (defaults to horizontal 20).
  final EdgeInsetsGeometry? padding;

  /// Whether to offset the sheet when on-screen software keyboard appears.
  final bool avoidKeyboard;

  /// Main body content of the sheet.
  final Widget child;

  const AppModalSheet({
    super.key,
    this.heightFactor = 0.85,
    this.height,
    this.backgroundColor,
    this.showDragHandle = true,
    this.header,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onClose,
    this.padding,
    this.avoidKeyboard = true,
    required this.child,
  });

  /// Displays an [AppModalSheet] using standard modal bottom sheet options.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  Widget _buildDefaultHeader(BuildContext context) {
    if (header != null) return header!;
    if (title == null && leading == null && trailing == null) {
      return const SizedBox.shrink();
    }

    final closeAction = onClose ?? () => Navigator.of(context).pop();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12.0),
          ],
          if (title != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.0,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            const Spacer(),
          if (trailing != null)
            trailing!
          else if (title != null)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 22.0,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: closeAction,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = avoidKeyboard ? mediaQuery.viewInsets.bottom : 0.0;

    final resolvedHeight = height ??
        (heightFactor != null ? mediaQuery.size.height * heightFactor! : null);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: resolvedHeight,
        decoration: backgroundColor != null
            ? AppDecorations.sheetDecoration.copyWith(color: backgroundColor)
            : AppDecorations.sheetDecoration,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: resolvedHeight != null
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              if (showDragHandle) ...[
                const SizedBox(height: 10.0),
                AppDecorations.dragHandle(),
                const SizedBox(height: 8.0),
              ],
              _buildDefaultHeader(context),
              if (resolvedHeight != null)
                Expanded(
                  child: padding != null
                      ? Padding(padding: padding!, child: child)
                      : child,
                )
              else
                (padding != null
                    ? Padding(padding: padding!, child: child)
                    : child),
            ],
          ),
        ),
      ),
    );
  }
}
