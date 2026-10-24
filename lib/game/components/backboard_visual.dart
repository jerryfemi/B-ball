
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import '../fx/net_simulation.dart';
import '../physics/ball_physics_3d.dart';
import 'ball.dart';

/// Renders the GamePigeon scooped-shield backboard, 3D cylindrical pole,
/// wall drop shadows, rear rim arc, and back net mesh.
/// Configured with priority = 1 so it renders behind the basketball (priority = 2).
class BackboardVisual extends PositionComponent
    with HasGameReference<BasketballGame> {
  final double hoopWidth;
  final double hoopDepth;

  /// Cloth net shared with [FrontRimVisual] (front half) and
  /// [RearRimVisual] (rear half). Hoop-local units, origin at the rim center.
  late final NetSimulation net = NetSimulation(
    rimHalfWidth: hoopWidth / 2,
    rimHalfDepth: hoopDepth / 2,
  );

  /// Physical rim radius (0.27m) → drawn rim half-width, used to map the
  /// ball's 3D depth into the net's local space.
  static const double _physicalRimRadius = 0.27;

  BackboardVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.15,
  }) : super(
         position: position,
         size: Vector2(6.0, 20.0),
         anchor: Anchor.center,
         priority: 1,
       );

  @override
  void update(double dt) {
    super.update(dt);

    final depthScale = (hoopWidth / 2) / _physicalRimRadius;

    // Feed every ball near the hoop into the cloth net. Plain iteration with a
    // type check: no whereType() iterable allocated per frame.
    final children = parent?.children ?? const <Component>[];
    for (final child in children) {
      if (child is! Basketball) continue;
      final ball = child;
      if (!ball.isLaunched) continue;
      final pz = ball.physics.pos.z;
      if (pz < 4.0 || pz > 5.0) continue;

      final cam = ball.camera3D;
      net.pushBall(
        bx: ball.body.position.x - position.x,
        bh: ball.body.position.y - position.y,
        bz: (BallPhysics3D.rimCenter.z - pz) * depthScale,
        radius: ball.radius * 1.38 * cam.scaleAtDepth(pz),
        fallSpeed: -ball.physics.vel.y * depthScale,
        dt: dt,
      );
    }

    net.update(dt);
  }

  /// The backboard, pole and wall shadows never change, so they are recorded
  /// once into a [ui.Picture] and then rasterised into a [ui.Image] at the
  /// screen's resolution. Replaying the picture every frame re-ran its three
  /// MaskFilter blurs on the GPU every frame; drawing the image is one blit.
  /// Re-rasterised only when the screen size (pixels per metre) changes.
  ui.Picture? _staticPicture;
  ui.Image? _staticImage;
  double _imagePxPerUnit = 0.0;
  double _dpr = 1.0;
  Rect _imageSrc = Rect.zero;
  Rect _imageDst = Rect.zero;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  /// World units of margin around the component box that are rasterised too
  /// (the soft shadows reach slightly outside it).
  static const double _imagePad = 1.0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Read once per resize, never per frame.
    _dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  }

  /// Screen pixels per world metre at the current size (camera zoom is 1).
  double get _pxPerUnit =>
      game.size.y / BasketballGame.worldHeightInMeters * _dpr;

  void _rasterise(double pxPerUnit) {
    final ui.Picture picture = _staticPicture ??= _recordStaticPicture();
    final double w = size.x + _imagePad * 2;
    final double h = size.y + _imagePad * 2;
    final int pw = (w * pxPerUnit).ceil().clamp(1, 4096);
    final int ph = (h * pxPerUnit).ceil().clamp(1, 4096);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pw / w, ph / h);
      canvas.translate(_imagePad, _imagePad);
      canvas.drawPicture(picture);
      final ui.Picture scaled = recorder.endRecording();
      _staticImage?.dispose();
      _staticImage = scaled.toImageSync(pw, ph);
      scaled.dispose();
      _imagePxPerUnit = pxPerUnit;
      _imageSrc = Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble());
      _imageDst = Rect.fromLTWH(-_imagePad, -_imagePad, w, h);
    } catch (_) {
      _staticImage = null; // fall back to replaying the picture
      _imagePxPerUnit = pxPerUnit;
    }
  }

  ui.Picture _recordStaticPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);
    _renderWallDropShadow(canvas);
    _renderPole(canvas);
    _renderScoopedBackboard(canvas);
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final fx = game.hoopFx;
    final shaking = fx.boardOffsetX != 0.0 || fx.boardOffsetY != 0.0;
    if (shaking) {
      canvas.save();
      canvas.translate(fx.boardOffsetX, fx.boardOffsetY);
    }
    final double pxPerUnit = _pxPerUnit;
    if ((pxPerUnit - _imagePxPerUnit).abs() > 0.5) _rasterise(pxPerUnit);
    final ui.Image? image = _staticImage;
    if (image != null) {
      canvas.drawImageRect(image, _imageSrc, _imageDst, _imagePaint);
    } else {
      canvas.drawPicture(_staticPicture ??= _recordStaticPicture());
    }
    if (shaking) canvas.restore();
  }

  @override
  void onRemove() {
    _staticPicture?.dispose();
    _staticPicture = null;
    _staticImage?.dispose();
    _staticImage = null;
    super.onRemove();
  }

  void _renderWallDropShadow(Canvas canvas) {
    // Soft, realistic ambient drop shadow cast onto the back wall directly behind backboard
    final shadowPaint = Paint()
      ..color = const Color(0x3B000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.22);

    final shadowPath = _buildBackboardPath(3.6, 2.4, const Offset(0.08, -0.94));
    canvas.drawPath(shadowPath, shadowPaint);

    // Subtle drop shadow cast by the vertical pole onto the back wall
    final poleShadowPaint = Paint()
      ..color = const Color(0x28000000)
      ..strokeWidth = 0.22
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.16);

    canvas.drawLine(
      const Offset(0.08, -0.15),
      const Offset(0.08, 8.00),
      poleShadowPaint,
    );
  }

  void _renderPole(Canvas canvas) {
    const poleWidth = 0.22;
    const topY = -0.30;
    const bottomY = 8.16; // Hardwood floor entry depth under hoop at Z=4.96m (derived from camera)

    final poleRect = Rect.fromLTRB(
      -poleWidth / 2,
      topY,
      poleWidth / 2,
      bottomY,
    );

    // 1. Pole floor contact shadow on the hardwood
    final floorShadowPaint = Paint()
      ..color = const Color(0x60000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.08);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, bottomY + 0.03),
        width: poleWidth * 2.2,
        height: 0.12,
      ),
      floorShadowPaint,
    );

    // 2. 3D Cylindrical lighting gradient for metallic post
    final polePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0.0, 0.22, 0.50, 0.82, 1.0],
        colors: [
          Color(0xFFCBD5E1), // Left rim shadow
          Color(0xFFFFFFFF), // Left-center specular reflection crest
          Color(0xFFF1F5F9), // Center body
          Color(0xFFE2E8F0), // Right midtone
          Color(0xFF94A3B8), // Right shadow edge
        ],
      ).createShader(poleRect);

    canvas.drawRect(poleRect, polePaint);

    // 3. Subtle longitudinal edge outline for crisp definition
    final poleEdgePaint = Paint()
      ..color = const Color(0x3064748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(
      const Offset(-poleWidth / 2, topY),
      const Offset(-poleWidth / 2, bottomY),
      poleEdgePaint,
    );
    canvas.drawLine(
      const Offset(poleWidth / 2, topY),
      const Offset(poleWidth / 2, bottomY),
      poleEdgePaint,
    );

    // 4. Ground base collar flange where pole anchors into the court floor
    final collarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(0, bottomY),
        width: poleWidth * 1.65,
        height: 0.16,
      ),
      const Radius.circular(0.04),
    );

    final collarPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF94A3B8), Color(0xFFF1F5F9), Color(0xFF64748B)],
      ).createShader(collarRect.outerRect);

    canvas.drawRRect(collarRect, collarPaint);
    canvas.drawRRect(
      collarRect,
      Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025,
    );

    // 5. Backboard mounting collar & gusset directly behind the hoop
    final mountCollar = Rect.fromCenter(
      center: const Offset(0, -0.22),
      width: poleWidth * 1.45,
      height: 0.22,
    );
    canvas.drawRect(mountCollar, Paint()..color = const Color(0xFF64748B));
    canvas.drawRect(
      mountCollar,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025,
    );
  }

  void _renderScoopedBackboard(Canvas canvas) {
    const boardWidth = 3.6;
    const boardHeight = 2.4;
    const boardCenter = Offset(0, -1.02);

    final outerPath = _buildBackboardPath(boardWidth, boardHeight, boardCenter);
    final innerPath = _buildBackboardPath(
      boardWidth * 0.90,
      boardHeight * 0.90,
      boardCenter,
    );

    // 1. 3D Acrylic edge bevel (subtle thickness rim)
    final bevelPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(outerPath, bevelPaint);

    // 2. Glossy white backboard face plate
    final facePaint = Paint()
      ..color = const Color(0xFFFAFAFA)
      ..style = PaintingStyle.fill;
    canvas.drawPath(outerPath, facePaint);

    // 3. Subtle gloss sheen gradient
    final sheenPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0x20FFFFFF),
              Colors.transparent,
              Color(0x0C000000),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: boardCenter,
              width: boardWidth,
              height: boardHeight,
            ),
          );
    canvas.drawPath(outerPath, sheenPaint);

    // 4. Diagonal glass specular streak (GamePigeon signature acrylic reflection)
    canvas.save();
    canvas.clipPath(outerPath);

    final streakPaint = Paint()
      ..shader =
          LinearGradient(
            begin: const Alignment(-0.85, -1.0),
            end: const Alignment(0.85, 1.0),
            stops: const [0.0, 0.30, 0.38, 0.46, 0.54, 1.0],
            colors: const [
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
              Color(0x28FFFFFF),
              Color(0x42FFFFFF),
              Color(0x10FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(
            Rect.fromCenter(
              center: boardCenter,
              width: boardWidth * 1.4,
              height: boardHeight * 1.4,
            ),
          );
    canvas.drawRect(
      Rect.fromCenter(
        center: boardCenter,
        width: boardWidth * 1.5,
        height: boardHeight * 1.5,
      ),
      streakPaint,
    );
    canvas.restore();

    // 5. Outer bold red contour line
    final outerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.08;
    canvas.drawPath(outerPath, outerRedPaint);

    // 6. Inner parallel red accent line (signature GamePigeon double border)
    final innerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.035;
    canvas.drawPath(innerPath, innerRedPaint);

    // 7. Regulation target rectangle directly above the rim
    final targetRect = Rect.fromCenter(
      center: const Offset(0, -0.66),
      width: 0.98,
      height: 0.72,
    );
    final targetPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.065;
    canvas.drawRect(targetRect, targetPaint);
  }

  Path _buildBackboardPath(double w, double h, Offset center) {
    final path = Path();
    final hw = w / 2;
    final hh = h / 2;

    // Symmetric scooped-shield fan contour
    path.moveTo(center.dx, center.dy - hh);
    // Top-right shoulder notch
    path.lineTo(center.dx + hw * 0.40, center.dy - hh);
    path.quadraticBezierTo(
      center.dx + hw * 0.65,
      center.dy - hh * 0.95,
      center.dx + hw * 0.70,
      center.dy - hh * 0.75,
    );
    path.quadraticBezierTo(
      center.dx + hw * 0.75,
      center.dy - hh * 0.60,
      center.dx + hw,
      center.dy - hh * 0.48,
    );
    // Right side curve down to lower corner
    path.quadraticBezierTo(
      center.dx + hw * 1.02,
      center.dy + hh * 0.05,
      center.dx + hw * 0.90,
      center.dy + hh * 0.65,
    );
    path.quadraticBezierTo(
      center.dx + hw * 0.82,
      center.dy + hh,
      center.dx + hw * 0.55,
      center.dy + hh,
    );
    // Bottom edge to bottom-left corner
    path.lineTo(center.dx - hw * 0.55, center.dy + hh);
    path.quadraticBezierTo(
      center.dx - hw * 0.82,
      center.dy + hh,
      center.dx - hw * 0.90,
      center.dy + hh * 0.65,
    );
    // Left side curve up to shoulder
    path.quadraticBezierTo(
      center.dx - hw * 1.02,
      center.dy + hh * 0.05,
      center.dx - hw,
      center.dy - hh * 0.48,
    );
    // Top-left shoulder notch
    path.quadraticBezierTo(
      center.dx - hw * 0.75,
      center.dy - hh * 0.60,
      center.dx - hw * 0.70,
      center.dy - hh * 0.75,
    );
    path.quadraticBezierTo(
      center.dx - hw * 0.65,
      center.dy - hh * 0.95,
      center.dx - hw * 0.40,
      center.dy - hh,
    );
    path.close();

    return path;
  }
}
