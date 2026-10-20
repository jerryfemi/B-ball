import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../scene/billboard_renderer.dart';
import '../scene/venue_theme.dart';

/// Renders the outdoor daytime archery park scene.
///
/// Architecture:
/// - Fixed screen-space sky + mountains at infinity.
/// - Perspective-correct ground shader with mowed stripes, lane lines & haze (with Canvas fallback).
/// - BillboardRenderer for trees, hedge, and distant hills with distance haze & tree contact shadows.
/// - Zero runtime allocation in render loop.
class RangeBackground {
  final ArcheryCamera camera;
  late VenueTheme theme;
  late final BillboardRenderer billboardRenderer;

  double activeDistance = ArcheryK.distanceM;

  // --- Sky ---
  ui.Image? _skyImage;
  final Paint _skyPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.medium;

  // Fallback sky gradient if asset still loading
  final Paint _fallbackSkyPaint = Paint()..isAntiAlias = false;

  // --- Ground Shader ---
  ui.FragmentShader? _groundShader;
  ui.Image? _grassTexture;
  final Paint _groundShaderPaint = Paint()..isAntiAlias = false;

  // Fallback ground paint
  final Paint _fallbackGroundPaint = Paint()
    ..color = const Color(0xFF438A27)
    ..style = PaintingStyle.fill;
  final Paint _fallbackStripePaint = Paint()
    ..color = const Color(0xFF387A1E)
    ..style = PaintingStyle.fill;
  final Paint _fallbackLinePaint = Paint()
    ..color = const Color(0xE6F8FAFC)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  final Path _reusablePath = Path();

  double _lastW = 0.0;
  double _lastH = 0.0;

  RangeBackground({required this.camera}) {
    theme = VenueTheme.createParkTheme(targetDistance: activeDistance);
    billboardRenderer = BillboardRenderer(camera: camera, theme: theme);
  }

  /// Asynchronously loads sky, shader, textures, and billboard sprites.
  Future<void> load() async {
    // 1. Load Sky Image
    try {
      final ByteData skyData = await rootBundle.load(theme.skyImage);
      final ui.Codec codec = await ui.instantiateImageCodec(skyData.buffer.asUint8List());
      final ui.FrameInfo frame = await codec.getNextFrame();
      _skyImage = frame.image;
    } catch (e) {
      debugPrint('Archery: Failed to load sky image: $e');
    }

    // 2. Load Grass Texture for Shader
    try {
      final ByteData grassData = await rootBundle.load(theme.grassDetailImage);
      final ui.Codec codec = await ui.instantiateImageCodec(grassData.buffer.asUint8List());
      final ui.FrameInfo frame = await codec.getNextFrame();
      _grassTexture = frame.image;
    } catch (e) {
      debugPrint('Archery: Failed to load grass texture: $e');
    }

    // 3. Load Ground FragmentProgram
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/archery_ground.frag');
      _groundShader = program.fragmentShader();
      if (_grassTexture != null) {
        _groundShader!.setImageSampler(0, _grassTexture!);
      }
      _groundShaderPaint.shader = _groundShader;
    } catch (e) {
      debugPrint('Archery: Note - Ground shader unavailable, using Canvas fallback: $e');
    }

    // 4. Load Billboard Renderer
    await billboardRenderer.load();
  }

  void resize(double width, double height) {
    if (width == _lastW && height == _lastH) return;
    _lastW = width;
    _lastH = height;

    final double horizonY = height * ArcheryK.horizonFrac;
    _fallbackSkyPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF6BA4E8),
        Color(0xFF90C2F2),
        Color(0xFFE2EBF5),
      ],
      stops: [0.0, 0.6, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, width, horizonY + 2.0));
  }

  void render(Canvas canvas) {
    if (_lastW <= 0.0 || _lastH <= 0.0) return;

    final double screenW = camera.screenW;
    final double screenH = camera.screenH;
    final double horizonY = screenH * ArcheryK.horizonFrac;

    // ==========================================
    // 1. SKY + MOUNTAINS AT INFINITY
    // ==========================================
    if (_skyImage != null) {
      final img = _skyImage!;
      // Fit to screen width, anchored at horizon line
      final double imgW = img.width.toDouble();
      final double imgH = img.height.toDouble();
      final double scale = screenW / imgW;
      final double drawH = imgH * scale;
      final double drawY = horizonY - drawH * 0.78; // Align mountain base with horizon

      final Rect src = Rect.fromLTWH(0, 0, imgW, imgH);
      final Rect dst = Rect.fromLTWH(0, drawY, screenW, drawH);
      canvas.drawImageRect(img, src, dst, _skyPaint);

      // Fill any top margin if aspect ratio is tall
      if (drawY > 0) {
        canvas.drawRect(Rect.fromLTWH(0, 0, screenW, drawY + 1.0), _fallbackSkyPaint);
      }
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, screenW, horizonY + 1.0), _fallbackSkyPaint);
    }

    // ==========================================
    // 2. GROUND (SHADER OR CANVAS FALLBACK)
    // ==========================================
    final Rect groundRect = Rect.fromLTWH(0, horizonY, screenW, screenH - horizonY);

    if (_groundShader != null && _grassTexture != null) {
      final shader = _groundShader!;
      // Uniforms per shaders/archery_ground.frag:
      // vec2 uSize
      shader.setFloat(0, screenW);
      shader.setFloat(1, screenH);
      // float uHorizonY
      shader.setFloat(2, horizonY);
      // float uFocal
      shader.setFloat(3, camera.focal);
      // float uEyeX, uEyeY, uEyeZ
      shader.setFloat(4, camera.eyeX);
      shader.setFloat(5, camera.eyeY);
      shader.setFloat(6, camera.eyeZ);
      // float uStripeLen
      shader.setFloat(7, theme.stripeLen);
      // vec4 uGrassA
      shader.setFloat(8, theme.grassA.r);
      shader.setFloat(9, theme.grassA.g);
      shader.setFloat(10, theme.grassA.b);
      shader.setFloat(11, 1.0);
      // vec4 uGrassB
      shader.setFloat(12, theme.grassB.r);
      shader.setFloat(13, theme.grassB.g);
      shader.setFloat(14, theme.grassB.b);
      shader.setFloat(15, 1.0);
      // vec4 uHaze
      shader.setFloat(16, theme.haze.r);
      shader.setFloat(17, theme.haze.g);
      shader.setFloat(18, theme.haze.b);
      shader.setFloat(19, 1.0);
      // float uHazeDist, uTargetZ
      shader.setFloat(20, theme.hazeDist);
      shader.setFloat(21, activeDistance);

      canvas.drawRect(groundRect, _groundShaderPaint);
    } else {
      _renderFallbackGround(canvas, screenW, screenH, horizonY);
    }

    // ==========================================
    // 3. TREE CONTACT SHADOWS
    // ==========================================
    billboardRenderer.renderShadows(canvas);

    // ==========================================
    // 4. BILLBOARDS (HILLS, HEDGE, TREES)
    // ==========================================
    billboardRenderer.renderBillboards(canvas);
  }

  void _renderFallbackGround(Canvas canvas, double screenW, double screenH, double horizonY) {
    // Solid base grass
    canvas.drawRect(Rect.fromLTWH(0, horizonY, screenW, screenH - horizonY), _fallbackGroundPaint);

    // Perspective lawn stripes
    final double focal = camera.focal;
    final double eyeY = camera.eyeY;
    final double eyeZ = camera.eyeZ;

    for (double z = 0.0; z < 50.0; z += theme.stripeLen * 2.0) {
      final double z0 = z;
      final double z1 = z + theme.stripeLen;
      final double dz0 = z0 - eyeZ;
      final double dz1 = z1 - eyeZ;
      if (dz1 <= 0.2) continue;

      final double sy0 = dz0 > 0.1 ? (horizonY + focal * eyeY / dz0) : screenH;
      final double sy1 = horizonY + focal * eyeY / dz1;

      final double topY = sy1.clamp(horizonY, screenH);
      final double botY = sy0.clamp(horizonY, screenH);
      if (botY > topY) {
        canvas.drawRect(Rect.fromLTWH(0, topY, screenW, botY - topY), _fallbackStripePaint);
      }
    }

    // Lane lines: V-shape converging to target
    if (camera.project(-0.55, 0.0, activeDistance) && camera.project(0.55, 0.0, activeDistance)) {
      // Re-project left at target
      camera.project(-0.55, 0.0, activeDistance);
      final double targetLX = camera.sx;
      final double targetLY = camera.sy;

      camera.project(0.55, 0.0, activeDistance);
      final double targetRX = camera.sx;

      // Project at shooting line z = 0
      camera.project(-3.2, 0.0, 0.0);
      final double lineLX = camera.sx;
      final double lineLY = camera.sy;

      camera.project(3.2, 0.0, 0.0);
      final double lineRX = camera.sx;

      _reusablePath.reset();
      _reusablePath.moveTo(lineLX, lineLY);
      _reusablePath.lineTo(targetLX, targetLY);
      canvas.drawPath(_reusablePath, _fallbackLinePaint);

      _reusablePath.reset();
      _reusablePath.moveTo(lineRX, lineLY);
      _reusablePath.lineTo(targetRX, targetLY);
      canvas.drawPath(_reusablePath, _fallbackLinePaint);

      // Center line
      camera.project(0.0, 0.0, 0.0);
      final double centerLineX = camera.sx;
      final double centerLineY = camera.sy;
      camera.project(0.0, 0.0, activeDistance);
      final double centerTargetX = camera.sx;
      final double centerTargetY = camera.sy;

      _reusablePath.reset();
      _reusablePath.moveTo(centerLineX, centerLineY);
      _reusablePath.lineTo(centerTargetX, centerTargetY);
      canvas.drawPath(_reusablePath, _fallbackLinePaint);
    }

    // Atmospheric haze gradient over ground near horizon
    final Paint hazeGrad = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x8CBFD7E6),
          Color(0x00BFD7E6),
        ],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, horizonY, screenW, 80.0));
    canvas.drawRect(Rect.fromLTWH(0, horizonY, screenW, 80.0), hazeGrad);
  }
}
