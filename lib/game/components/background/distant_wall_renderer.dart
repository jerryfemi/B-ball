import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'room_geometry.dart';

/// Renders the authentic GamePigeon exposed red clay brick gym back wall:
/// - Supports both photorealistic seamless 3D brick texture ([assets/images/brick_wall.jpg])
///   and procedural clay brickwork fallback
/// - Atmospheric distance lighting & depth gradient
/// - Dark hardwood baseboard trim meeting the court floor with highlight bevel
class DistantWallRenderer {
  static ui.Image? _cachedBrickImage;
  static Future<ui.Image?>? _imageFuture;

  /// Loads and caches the seamless clay brick wall texture from assets.
  static Future<ui.Image?> loadBrickImage() {
    if (_cachedBrickImage != null) return Future.value(_cachedBrickImage);
    return _imageFuture ??= () async {
      try {
        final byteData = await rootBundle.load('assets/images/brick_wall.jpg');
        final codec = await ui.instantiateImageCodec(
          byteData.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        _cachedBrickImage = frame.image;
        return _cachedBrickImage;
      } catch (e) {
        debugPrint('[DistantWallRenderer] Failed to load brick_wall.jpg: $e');
        return null;
      }
    }();
  }

  void render(Canvas canvas, RoomGeometry geom) {
    final wallRect = geom.backWallRect;

    canvas.save();
    canvas.clipRect(wallRect);

    if (_cachedBrickImage != null) {
      _renderPhotorealisticBrickWall(canvas, wallRect, _cachedBrickImage!);
    } else {
      // Clean terracotta base tone while texture decodes
      canvas.drawRect(wallRect, Paint()..color = const Color(0xFFA63C27));
    }

    _renderBaseboardAndLighting(canvas, wallRect);

    canvas.restore();
  }

  /// Photorealistic 3D brick wall using seamless texture, scale calibration,
  /// and atmospheric depth gradients.
  void _renderPhotorealisticBrickWall(
    Canvas canvas,
    Rect wallRect,
    ui.Image image,
  ) {
    // 1. Scale calibration:
    // The seamless texture has 24 brick rows.
    // In GamePigeon perspective scale, each brick row is ~16.0px high.
    // Target height for 24 rows = 384.0px.
    final double scale = 384.0 / image.height;

    final matrix = Float64List.fromList([
      scale, 0, 0, 0,
      0, scale, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]);

    final brickShader = ui.ImageShader(
      image,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      matrix,
    );

    // Warm terracotta color grading to harmonize with gymnasium tones
    final wallPaint = Paint()
      ..shader = brickShader
      ..filterQuality = FilterQuality.medium
      ..colorFilter = const ColorFilter.mode(
        Color(0x18A63C27),
        BlendMode.multiply,
      );

    canvas.drawRect(wallRect, wallPaint);

    // 2. 3D Atmospheric Depth & Ambient Occlusion:
    // a. Top ceiling crease shadow where wall meets roof rafters
    final topOcclusionPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(wallRect.left, wallRect.top),
        Offset(wallRect.left, wallRect.bottom),
        const [
          Color(0x50000000), // Deep ceiling crease shadow
          Color(0x1C000000),
          Color(0x00000000), // Clear at hoop level
        ],
        const [0.0, 0.30, 0.65],
      );
    canvas.drawRect(wallRect, topOcclusionPaint);

    // b. Lateral depth vignette (darker towards outer wall corners for concave 3D room feel)
    final lateralDepthPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(wallRect.left, wallRect.top),
        Offset(wallRect.right, wallRect.top),
        const [
          Color(0x32000000), // Left corner depth
          Color(0x00000000),
          Color(0x00000000),
          Color(0x32000000), // Right corner depth
        ],
        const [0.0, 0.18, 0.82, 1.0],
      );
    canvas.drawRect(wallRect, lateralDepthPaint);

    // c. Baseline ground contact ambient occlusion (crease shadow where vertical wall meets floor)
    final contactShadowHeight = math.min(42.0, wallRect.height * 0.25);
    final bottomContactPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(wallRect.left, wallRect.bottom - contactShadowHeight),
        Offset(wallRect.left, wallRect.bottom),
        const [
          Color(0x00000000),
          Color(0x28000000), // Ground plane contact shadow
        ],
      );
    canvas.drawRect(
      Rect.fromLTRB(
        wallRect.left,
        wallRect.bottom - contactShadowHeight,
        wallRect.right,
        wallRect.bottom,
      ),
      bottomContactPaint,
    );

    // d. Soft backboard ambient depth shadow (subtle depth cue placing backboard forward in space)
    final backboardAtmospherePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(wallRect.center.dx, wallRect.top + wallRect.height * 0.40),
        wallRect.width * 0.32,
        const [
          Color(0x20000000),
          Color(0x00000000),
        ],
        const [0.0, 1.0],
      );
    canvas.drawRect(wallRect, backboardAtmospherePaint);
  }

  /// Baseboard trim and atmospheric radial lighting.
  void _renderBaseboardAndLighting(Canvas canvas, Rect wallRect) {
    // 1. Dark Hardwood / Rubber Baseboard Trim at Baseline Joint
    const baseboardHeight = 5.0;
    final baseboardRect = Rect.fromLTWH(
      wallRect.left,
      wallRect.bottom - baseboardHeight,
      wallRect.width,
      baseboardHeight,
    );
    final baseboardPaint = Paint()..color = const Color(0xFF18120C);
    canvas.drawRect(baseboardRect, baseboardPaint);

    // Crisp highlight bevel along top edge of baseboard
    canvas.drawLine(
      Offset(wallRect.left, wallRect.bottom - baseboardHeight),
      Offset(wallRect.right, wallRect.bottom - baseboardHeight),
      Paint()
        ..color = const Color(0x35FFFFFF)
        ..strokeWidth = 1.0,
    );

    // 2. Atmospheric Gym Lighting Vignette on Wall
    // Centers warmth around hoop, subtly shading top and corners
    final wallLightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.2),
        radius: 1.15,
        colors: const [
          Color(0x00000000), // Pure crisp brick in center
          Color(0x12000000), // Gentle shading
          Color(0x38000000), // Rich moody vignette near borders
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, wallLightPaint);
  }
}
