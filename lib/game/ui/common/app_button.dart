import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized primary action button for the B-Ball UI.
///
/// Features bold typography, subtle letter spacing, rounded corners,
/// optional leading icon, and an embedded progress indicator for async actions.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final IconData? iconData;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isCyan;
  final bool isLoading;
  final bool fullWidth;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconData,
    this.backgroundColor,
    this.foregroundColor,
    this.isCyan = false,
    this.isLoading = false,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
    this.borderRadius = 14.0,
    this.fontSize = 13.5,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ??
        (isCyan ? AppColors.accentNeonCyan : const Color(0xFF2563EB));
    final effectiveFg = foregroundColor ??
        (isCyan || effectiveBg == AppColors.accentNeonCyan || effectiveBg == AppColors.accentElectricSky
            ? const Color(0xFF0F172A)
            : Colors.white);

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20.0,
        height: 20.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: effectiveFg,
        ),
      );
    } else {
      final textWidget = Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      );

      final resolvedIcon = icon ??
          (iconData != null ? Icon(iconData, size: 18.0) : null);

      if (resolvedIcon != null) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            resolvedIcon,
            const SizedBox(width: 8.0),
            textWidget,
          ],
        );
      } else {
        content = textWidget;
      }
    }

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveBg,
        foregroundColor: effectiveFg,
        disabledBackgroundColor: effectiveBg.withValues(alpha: 0.5),
        disabledForegroundColor: effectiveFg.withValues(alpha: 0.5),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 0,
      ),
      child: content,
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }
}

/// Centralized secondary action button for the B-Ball UI.
///
/// Features a sleek dark tile background or transparent outline border
/// for dismiss, cancel, or secondary navigation actions.
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final IconData? iconData;
  final bool isOutlined;
  final bool fullWidth;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconData,
    this.isOutlined = false,
    this.fullWidth = false,
    this.padding = const EdgeInsets.symmetric(vertical: 13.0, horizontal: 16.0),
    this.borderRadius = 14.0,
    this.fontSize = 13.0,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );

    final resolvedIcon = icon ??
        (iconData != null ? Icon(iconData, size: 16.0) : null);

    final Widget content;
    if (resolvedIcon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          resolvedIcon,
          const SizedBox(width: 8.0),
          textWidget,
        ],
      );
    } else {
      content = textWidget;
    }

    final Widget button;
    if (isOutlined) {
      button = OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: content,
      );
    } else {
      button = TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: content,
      );
    }

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }
}
