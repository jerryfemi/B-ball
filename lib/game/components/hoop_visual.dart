import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class HoopVisual extends PositionComponent {
  HoopVisual({required super.position, required super.size});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw the pole (white)
    final polePaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 4, size.y / 2, 8, size.y),
      polePaint,
    );

    // Draw backboard (white with red square)
    final backboardPaint = Paint()..color = Colors.white;
    final backboardBorder = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    final backboardRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2 - 20),
      width: size.x * 0.8,
      height: size.y * 0.4,
    );
    
    // Fill backboard
    canvas.drawRect(backboardRect, backboardPaint);
    // Draw outer red border
    canvas.drawRect(backboardRect, backboardBorder);

    // Draw inner red square
    final innerSquareRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2 - 10),
      width: size.x * 0.3,
      height: size.y * 0.2,
    );
    canvas.drawRect(innerSquareRect, backboardBorder);

    // Draw rim (orange)
    final rimPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: size.x * 0.4,
        height: size.y * 0.1,
      ),
      0,
      3.14159, // PI (bottom half of circle for front rim)
      false,
      rimPaint,
    );
  }
}
