import 'package:flutter/painting.dart';

/// Inter, the app's UI text font. It's a variable font, so the weight is set
/// through the 'wght' axis as well as [FontWeight].
abstract final class UiFont {
  static const String family = 'Inter';

  static TextStyle style({
    required double size,
    double weight = 500,
    Color color = const Color(0xFFFFFFFF),
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: _nearest(weight),
      fontVariations: [FontVariation('wght', weight)],
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static FontWeight _nearest(double w) {
    final int i = ((w / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[i];
  }
}
