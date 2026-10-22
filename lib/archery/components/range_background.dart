import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../scene/billboard_renderer.dart';
import '../scene/venue_theme.dart';
import '../util/image_loader.dart';

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

  double _activeDistance = ArcheryK.distanceM;
  double get activeDistance => _activeDistance;

  /// Target distance for the current set: feeds the ground shader (lane lines,
  /// contact shadow) and moves the trees behind the target.
  set activeDistance(double d) {
    if (d == _activeDistance) return;
    _activeDistance = d;
    billboardRenderer.setTargetDistance(d);
  }

  // --- Sky ---
  ui.Image? _skyImage;
  final Paint _skyPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.medium;

  // Fallback sky gradient if asset still loading
  final Paint _fallbackSkyPaint = Paint()..isAntiAlias = false;

  // Rects that only change with the screen size (not rebuilt every frame).
  double _skyFor = -1.0;
  double _groundFor = -1.0;
  Rect _skySrc = Rect.zero;
  Rect _skyDst = Rect.zero;
  Rect _skyTop = Rect.zero;
  Rect _groundRect = Rect.zero;

  // --- Ground Shader ---
  ui.FragmentShader? _groundShader;
  ui.Image? _grassTexture;
  final Paint _groundShaderPaint = Paint()..isAntiAlias = false;

  // Fallback ground paint
  final Paint _fallbackGroundPaint = Paint()
    ..color = const Color(0xFF438A27)
    ..style = PaintingStyle.fill;

  double _lastW = 0.0;
  double _lastH = 0.0;

  RangeBackground({required this.camera}) {
    theme = VenueTheme.createParkTheme(targetDistance: ArcheryK.distanceM);
    billboardRenderer = BillboardRenderer(camera: camera, theme: theme);
  }

  /// Loads sky, ground shader, grass texture and the trees in parallel, so
  /// the range is ready as soon as the slowest single file is.
  Future<void> load() async {
    Future<void> sky() async {
      try {
        _skyImage = await loadArcheryImage(theme.skyImage);
      } catch (e) {
        debugPrint('Archery: Failed to load sky image: $e');
      }
    }

    Future<void> ground() async {
      try {
        final results = await Future.wait<Object>([
          loadArcheryImage(theme.grassDetailImage),
          ui.FragmentProgram.fromAsset('shaders/archery_ground.frag'),
        ]);
        _grassTexture = results[0] as ui.Image;
        final program = results[1] as ui.FragmentProgram;
        _groundShader = program.fragmentShader()..setImageSampler(0, _grassTexture!);
        _groundShaderPaint.shader = _groundShader;
      } catch (e) {
        debugPrint('Archery: Note - Ground shader unavailable, using Canvas fallback: $e');
      }
    }

    await Future.wait([sky(), ground(), billboardRenderer.load()]);
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
      // Fit to cover sky area, anchored at horizon line (§1.1)
      final double imgW = img.width.toDouble();
      final double imgH = img.height.toDouble();
      final double scale = math.max(screenW / imgW, (horizonY + 40.0) / (imgH * 0.78));
      final double drawW = imgW * scale;
      final double drawH = imgH * scale;
      final double drawX = (screenW - drawW) * 0.5;
      final double drawY = horizonY - drawH * 0.78; // Align mountain base with horizon

      // The sky only changes with the screen size: rects are rebuilt then.
      if (_skyFor != screenW * 100000 + screenH) {
        _skyFor = screenW * 100000 + screenH;
        _skySrc = Rect.fromLTWH(0, 0, imgW, imgH);
        _skyDst = Rect.fromLTWH(drawX, drawY, drawW, drawH);
        _skyTop = Rect.fromLTWH(0, 0, screenW, drawY + 1.0);
      }
      canvas.drawImageRect(img, _skySrc, _skyDst, _skyPaint);

      // Fill any top margin if aspect ratio is tall
      if (drawY > 0) canvas.drawRect(_skyTop, _fallbackSkyPaint);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, screenW, horizonY + 1.0), _fallbackSkyPaint);
    }

    // ==========================================
    // 2. GROUND (SHADER OR CANVAS FALLBACK)
    // ==========================================
    if (_groundFor != screenW * 100000 + screenH) {
      _groundFor = screenW * 100000 + screenH;
      _groundRect = Rect.fromLTWH(0, horizonY, screenW, screenH - horizonY);
    }
    final Rect groundRect = _groundRect;

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

      // Explicitly bind sampler every frame for Web CanvasKit reliability
      shader.setImageSampler(0, _grassTexture!);

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
    canvas.drawRect(Rect.fromLTWH(0, horizonY, screenW, screenH - horizonY), _fallbackGroundPaint);
  }
}
