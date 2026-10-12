import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_decorations.dart';

/// Centralized modal dialog scaffold for B-Ball.
///
/// Standardizes dialog backdrop blur, container shape/border, elevation shadows,
/// header badge icons, typography, and dismiss behavior across the app.
class AppModalDialog extends StatelessWidget {
  /// Maximum width constraint of the dialog container (defaults to 380.0).
  final double maxWidth;

  /// Inner padding of the dialog frame.
  final EdgeInsetsGeometry padding;

  /// Optional icon character/emoji (e.g. '🏀' or '🎯') for the header badge.
  final String? icon;

  /// Optional custom icon widget (e.g. Icon(Icons.badge)) for the header badge.
  final Widget? iconWidget;

  /// Main dialog title.
  final String? title;

  /// Secondary description / subtitle below title.
  final String? subtitle;

  /// Custom trailing header widget.
  final Widget? trailing;

  /// Whether to render a close button in the top right.
  final bool showCloseButton;

  /// Callback when close button is tapped (defaults to `Navigator.of(context).pop()`).
  final VoidCallback? onClose;

  /// Whether to wrap [child] in a [SingleChildScrollView].
  final bool scrollable;

  /// Dialog body content.
  final Widget child;

  const AppModalDialog({
    super.key,
    this.maxWidth = 380.0,
    this.padding = const EdgeInsets.all(22.0),
    this.icon,
    this.iconWidget,
    this.title,
    this.subtitle,
    this.trailing,
    this.showCloseButton = false,
    this.onClose,
    this.scrollable = false,
    required this.child,
  });

  /// Displays the modal dialog with standard barrier properties.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    RouteSettings? routeSettings,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? AppColors.backdrop,
      routeSettings: routeSettings,
      builder: builder,
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (title == null && icon == null && iconWidget == null) {
      return const SizedBox.shrink();
    }

    Widget? leadingBadge;
    if (iconWidget != null) {
      leadingBadge = Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceTile,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: AppColors.borderInput),
        ),
        child: iconWidget,
      );
    } else if (icon != null) {
      leadingBadge = Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceTile,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.borderInput),
        ),
        child: Text(icon!, style: const TextStyle(fontSize: 20.0)),
      );
    }

    final closeAction = onClose ?? () => Navigator.of(context).pop();

    return Row(
      children: [
        if (leadingBadge != null) ...[
          leadingBadge,
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
                    letterSpacing: 1.0,
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
        else if (showCloseButton)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || icon != null || iconWidget != null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHeader) ...[
          _buildHeader(context),
          const SizedBox(height: 18.0),
        ],
        child,
      ],
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: padding,
            decoration: AppDecorations.dialogDecoration,
            child: scrollable
                ? SingleChildScrollView(child: content)
                : content,
          ),
        ),
      ),
    );
  }
}
