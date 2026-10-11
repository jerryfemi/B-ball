import 'package:flutter/material.dart';

/// Segment flags for standard 7-segment digital displays.
///
///       aaa
///      f   b
///      f   b
///       ggg
///      e   c
///      e   c
///       ddd
enum LedSegment { a, b, c, d, e, f, g }

/// Bitmask definitions for digits 0-9.
const Map<int, Set<LedSegment>> _digitSegments = {
  0: {
    LedSegment.a,
    LedSegment.b,
    LedSegment.c,
    LedSegment.d,
    LedSegment.e,
    LedSegment.f,
  },
  1: {LedSegment.b, LedSegment.c},
  2: {LedSegment.a, LedSegment.b, LedSegment.g, LedSegment.e, LedSegment.d},
  3: {LedSegment.a, LedSegment.b, LedSegment.g, LedSegment.c, LedSegment.d},
  4: {LedSegment.f, LedSegment.g, LedSegment.b, LedSegment.c},
  5: {LedSegment.a, LedSegment.f, LedSegment.g, LedSegment.c, LedSegment.d},
  6: {
    LedSegment.a,
    LedSegment.f,
    LedSegment.e,
    LedSegment.d,
    LedSegment.c,
    LedSegment.g,
  },
  7: {LedSegment.a, LedSegment.b, LedSegment.c},
  8: {
    LedSegment.a,
    LedSegment.b,
    LedSegment.c,
    LedSegment.d,
    LedSegment.e,
    LedSegment.f,
    LedSegment.g,
  },
  9: {
    LedSegment.a,
    LedSegment.b,
    LedSegment.c,
    LedSegment.d,
    LedSegment.f,
    LedSegment.g,
  },
};

/// A custom-painted authentic 7-segment LED digit with unlit ghost segments
/// and glowing illuminated active segments.
class SevenSegmentDigit extends StatelessWidget {
  final int digit; // 0..9 or -1 for unlit/blank
  final Color onColor;
  final Color offColor;
  final double width;
  final double height;
  final double slant;

  const SevenSegmentDigit({
    super.key,
    required this.digit,
    required this.onColor,
    required this.offColor,
    this.width = 22.0,
    this.height = 38.0,
    this.slant = -0.06,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SevenSegmentPainter(
        digit: digit,
        onColor: onColor,
        offColor: offColor,
        slant: slant,
      ),
    );
  }
}

class _SevenSegmentPainter extends CustomPainter {
  final int digit;
  final Color onColor;
  final Color offColor;
  final double slant;

  _SevenSegmentPainter({
    required this.digit,
    required this.onColor,
    required this.offColor,
    required this.slant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (slant != 0.0) {
      // Pivot around center for slant
      canvas.translate(size.width / 2, size.height / 2);
      canvas.skew(slant, 0.0);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    final activeSegments = _digitSegments[digit] ?? const <LedSegment>{};
    final paths = _computeSegmentPaths(size);

    final offPaint = Paint()
      ..color = offColor
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = onColor.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..style = PaintingStyle.fill;

    final onPaint = Paint()
      ..color = onColor
      ..style = PaintingStyle.fill;

    // First: draw all 7 segments in their unlit "ghost" state
    for (final seg in LedSegment.values) {
      final path = paths[seg]!;
      canvas.drawPath(path, offPaint);
    }

    // Second: draw glowing active segments over top
    for (final seg in activeSegments) {
      final path = paths[seg]!;
      // Diffuse neon glow aura
      canvas.drawPath(path, glowPaint);
      // Crisp illuminated core
      canvas.drawPath(path, onPaint);
    }

    canvas.restore();
  }

  Map<LedSegment, Path> _computeSegmentPaths(Size size) {
    final w = size.width;
    final h = size.height;
    final hh = h / 2;
    final t = w * 0.20; // Segment thickness
    final g = w * 0.04; // Gap
    final ch = t * 0.45; // Chamfer bevel

    final paths = <LedSegment, Path>{};

    // a: Top horizontal
    paths[LedSegment.a] = Path()
      ..moveTo(g + ch, g)
      ..lineTo(w - g - ch, g)
      ..lineTo(w - g - t, g + t)
      ..lineTo(g + t, g + t)
      ..close();

    // b: Top-right vertical
    paths[LedSegment.b] = Path()
      ..moveTo(w - g, g + ch)
      ..lineTo(w - g, hh - g / 2 - ch)
      ..lineTo(w - g - t, hh - g / 2 - t)
      ..lineTo(w - g - t, g + t)
      ..close();

    // c: Bottom-right vertical
    paths[LedSegment.c] = Path()
      ..moveTo(w - g, hh + g / 2 + ch)
      ..lineTo(w - g, h - g - ch)
      ..lineTo(w - g - t, h - g - t)
      ..lineTo(w - g - t, hh + g / 2 + t)
      ..close();

    // d: Bottom horizontal
    paths[LedSegment.d] = Path()
      ..moveTo(g + ch, h - g)
      ..lineTo(w - g - ch, h - g)
      ..lineTo(w - g - t, h - g - t)
      ..lineTo(g + t, h - g - t)
      ..close();

    // e: Bottom-left vertical
    paths[LedSegment.e] = Path()
      ..moveTo(g, hh + g / 2 + ch)
      ..lineTo(g, h - g - ch)
      ..lineTo(g + t, h - g - t)
      ..lineTo(g + t, hh + g / 2 + t)
      ..close();

    // f: Top-left vertical
    paths[LedSegment.f] = Path()
      ..moveTo(g, g + ch)
      ..lineTo(g, hh - g / 2 - ch)
      ..lineTo(g + t, hh - g / 2 - t)
      ..lineTo(g + t, g + t)
      ..close();

    // g: Middle horizontal
    paths[LedSegment.g] = Path()
      ..moveTo(g + ch, hh)
      ..lineTo(g + t, hh - t / 2)
      ..lineTo(w - g - t, hh - t / 2)
      ..lineTo(w - g - ch, hh)
      ..lineTo(w - g - t, hh + t / 2)
      ..lineTo(g + t, hh + t / 2)
      ..close();

    return paths;
  }

  @override
  bool shouldRepaint(covariant _SevenSegmentPainter oldDelegate) {
    return oldDelegate.digit != digit ||
        oldDelegate.onColor != onColor ||
        oldDelegate.offColor != offColor ||
        oldDelegate.slant != slant;
  }
}

/// Renders a multi-digit number (e.g. "00", "07", "84") formatted as authentic LED digits.
class DigitalLedNumberDisplay extends StatelessWidget {
  final int value;
  final int padDigits;
  final Color onColor;
  final Color offColor;
  final double digitWidth;
  final double digitHeight;
  final double spacing;

  const DigitalLedNumberDisplay({
    super.key,
    required this.value,
    this.padDigits = 2,
    this.onColor = const Color(0xFFFF2222), // Classic red LED
    this.offColor = const Color(0x283A0505), // Faint unlit red ghost
    this.digitWidth = 20.0,
    this.digitHeight = 36.0,
    this.spacing = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final str = value.clamp(0, 9999).toString().padLeft(padDigits, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(str.length, (index) {
        final d = int.tryParse(str[index]) ?? 0;
        return Padding(
          padding: EdgeInsets.only(right: index < str.length - 1 ? spacing : 0),
          child: SevenSegmentDigit(
            digit: d,
            onColor: onColor,
            offColor: offColor,
            width: digitWidth,
            height: digitHeight,
          ),
        );
      }),
    );
  }
}

/// Renders a timer clock (MM:SS, e.g. "00:44", "01:00") with glowing amber LEDs.
class DigitalLedClockDisplay extends StatelessWidget {
  final int totalSeconds;
  final Color onColor;
  final Color offColor;
  final double digitWidth;
  final double digitHeight;
  final double spacing;

  const DigitalLedClockDisplay({
    super.key,
    required this.totalSeconds,
    this.onColor = const Color(0xFFFFE000), // GamePigeon vibrant amber
    this.offColor = const Color(0x22352E04), // Faint unlit amber ghost
    this.digitWidth = 19.0,
    this.digitHeight = 34.0,
    this.spacing = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = totalSeconds.clamp(0, 5999);
    final minutes = clamped ~/ 60;
    final seconds = clamped % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Minutes (00)
        SevenSegmentDigit(
          digit: int.parse(mStr[0]),
          onColor: onColor,
          offColor: offColor,
          width: digitWidth,
          height: digitHeight,
        ),
        SizedBox(width: spacing),
        SevenSegmentDigit(
          digit: int.parse(mStr[1]),
          onColor: onColor,
          offColor: offColor,
          width: digitWidth,
          height: digitHeight,
        ),

        // Colon separator
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing + 1.0),
          child: _LedColon(
            onColor: onColor,
            height: digitHeight,
          ),
        ),

        // Seconds (44)
        SevenSegmentDigit(
          digit: int.parse(sStr[0]),
          onColor: onColor,
          offColor: offColor,
          width: digitWidth,
          height: digitHeight,
        ),
        SizedBox(width: spacing),
        SevenSegmentDigit(
          digit: int.parse(sStr[1]),
          onColor: onColor,
          offColor: offColor,
          width: digitWidth,
          height: digitHeight,
        ),
      ],
    );
  }
}

class _LedColon extends StatelessWidget {
  final Color onColor;
  final double height;

  const _LedColon({
    required this.onColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = height * 0.11;
    return SizedBox(
      height: height,
      width: dotSize * 1.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ColonDot(color: onColor, size: dotSize),
          SizedBox(height: height * 0.28),
          _ColonDot(color: onColor, size: dotSize),
        ],
      ),
    );
  }
}

class _ColonDot extends StatelessWidget {
  final Color color;
  final double size;

  const _ColonDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 4.0,
          ),
        ],
      ),
    );
  }
}
