import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Central design tokens for corner radii, borders, shadows, and recurring UI decorations.
abstract final class AppDecorations {
  // --- Corner Radii ---
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusSheet = 28.0;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(radiusSheet));

  // --- Modal Scaffolding Decorations ---
  /// Standard container decoration for bottom sheet modals.
  static const BoxDecoration sheetDecoration = BoxDecoration(
    color: AppColors.surfaceSheet,
    borderRadius: sheetRadius,
    border: Border(
      top: BorderSide(color: AppColors.borderSheet, width: 1.5),
    ),
  );

  /// Standard container decoration for modal dialogs.
  static BoxDecoration dialogDecoration = BoxDecoration(
    color: AppColors.surfaceDialog,
    borderRadius: borderRadiusXl,
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.65),
        blurRadius: 28.0,
        offset: const Offset(0, 10),
      ),
    ],
  );

  /// Standard shape border for Flutter [Dialog] widgets.
  static final ShapeBorder dialogShape = RoundedRectangleBorder(
    borderRadius: borderRadiusXl,
    side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
  );

  /// Top centered grab handle for draggable bottom sheets.
  static Widget dragHandle() => Center(
        child: Container(
          width: 40.0,
          height: 4.0,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
      );

  // --- Glow & Shadow Effects ---
  /// Neon cyan active player glow shadow.
  static List<BoxShadow> cyanGlow({double blur = 10.0, double spread = 1.0}) => [
        BoxShadow(
          color: AppColors.accentNeonCyan.withValues(alpha: 0.35),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  /// Electric sky active opponent glow shadow.
  static List<BoxShadow> skyGlow({double blur = 10.0, double spread = 1.0}) => [
        BoxShadow(
          color: AppColors.accentElectricSky.withValues(alpha: 0.35),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];
}
