import 'package:flutter/material.dart';

/// Lobby colours and type. One family, Archivo (variable: weight 100–900,
/// width 62–125), bundled in assets/fonts. Wide + heavy for game names and
/// the wordmark, normal width for everything else.
abstract final class LobbyStyle {
  static const String font = 'Archivo';

  static const Color ink = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF0F172A);
  static const Color line = Color(0xFF1E2638);
  static const Color muted = Color(0xFF94A3B8);
  static const Color soft = Color(0xFFCBD5E1);

  /// A text style on the variable font. [weight] 100–900, [width] 62–125.
  static TextStyle text({
    double size = 15,
    double weight = 400,
    double width = 100,
    Color color = Colors.white,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: font,
      fontSize: size,
      fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      fontVariations: [
        FontVariation('wght', weight),
        FontVariation('wdth', width),
      ],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Game names: widest, heaviest cut, tight tracking.
  static TextStyle display(double size, {Color color = Colors.white}) => text(
        size: size,
        weight: 900,
        width: 125,
        color: color,
        height: 0.98,
        letterSpacing: -0.02 * size,
      );

  static final TextStyle sectionLabel = text(size: 15, weight: 600, color: muted);
  static final TextStyle body = text(size: 15, color: muted, height: 1.45);
  static final TextStyle button = text(size: 15, weight: 700);
}
