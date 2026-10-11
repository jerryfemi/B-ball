import 'package:flutter/material.dart';

/// Custom painter for the iconic GamePigeon trapezoidal matte black chassis.
/// The top edge is wider, and the sides angle subtly inwards towards the bottom.
class TrapezoidScoreboardPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double slopeInset;

  const TrapezoidScoreboardPainter({
    this.fillColor = const Color(0xFF0C0C0E),
    this.borderColor = Colors.white,
    this.borderWidth = 2.4,
    this.slopeInset = 11.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inx = slopeInset;
    const r = 5.0; // Subtle corner bevel

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w - 1.2, r)
      ..lineTo(w - inx + 1.2, h - r)
      ..quadraticBezierTo(w - inx, h, w - inx - r, h)
      ..lineTo(inx + r, h)
      ..quadraticBezierTo(inx, h, inx - 1.2, h - r)
      ..lineTo(1.2, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    // 1. Matte black drop shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.6), 8.0, true);

    // 2. Matte black fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Crisp white contour stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TrapezoidScoreboardPainter oldDelegate) => false;
}
