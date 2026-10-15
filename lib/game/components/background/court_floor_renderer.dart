import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'room_geometry.dart';

/// Renders the authentic GamePigeon hardwood court floor:
/// - Supports both photorealistic blonde maple wood texture ([assets/images/court_floor_blonde.jpg])
///   mapped with 1-point perspective geometry, and procedural hardwood fallback
/// - Atmospheric warm baseline bounce lighting bridging to the brick wall
/// - Terracotta/Crimson painted key trapezoid in unified 3D perspective
/// - Regulation restricted area arc centered directly under the hoop
/// - Regulation free-throw circle (solid front arc, dashed rear arc)
/// - 3-Point arc framing the perimeter court
/// - Signature vertical pole floor reflection streak
/// - Polished lacquer high-gloss floor varnish sheen
class CourtFloorRenderer {
  static ui.Image? _cachedFloorImage;
  static Future<ui.Image?>? _imageFuture;

  /// Loads and caches the photorealistic blonde maple gym court texture from assets.
  static Future<ui.Image?> loadFloorImage() {
    if (_cachedFloorImage != null) return Future.value(_cachedFloorImage);
    return _imageFuture ??= () async {
      try {
        final byteData =
            await rootBundle.load('assets/images/court_floor_blonde.jpg');
        final codec = await ui.instantiateImageCodec(
          byteData.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        _cachedFloorImage = frame.image;
        return _cachedFloorImage;
      } catch (e) {
        debugPrint(
          '[CourtFloorRenderer] Failed to load court_floor_blonde.jpg: $e',
        );
        return null;
      }
    }();
  }

  void render(Canvas canvas, RoomGeometry geom) {
    final floorRect = geom.floorRect;

    canvas.save();
    canvas.clipRect(floorRect);

    if (_cachedFloorImage != null) {
      _renderPhotorealisticFloor(canvas, geom, floorRect, _cachedFloorImage!);
    } else {
      // Clean blonde maple base tone while texture decodes
      canvas.drawRect(floorRect, Paint()..color = const Color(0xFFC98E50));
    }

    // 4. Terracotta/Crimson Painted Key Trapezoid
    _renderKeyTrapezoid(canvas, geom);

    // 5. Regulation Court Markings (Restricted Area, Free-Throw, 3-Point)
    _renderCourtMarkings(canvas, geom);

    // 6. Signature Vertical Pole Floor Reflection Streak
    _renderPoleFloorReflection(canvas, geom);

    // 7. Polished Lacquer Floor Sheen Overlay
    _renderFloorSheen(canvas, floorRect);

    canvas.restore();
  }

  /// Photorealistic blonde maple hardwood floor rendered with 1-point perspective
  /// vertex projection, foreshortened planks, and warm baseline bounce lighting.
  void _renderPhotorealisticFloor(
    Canvas canvas,
    RoomGeometry geom,
    Rect floorRect,
    ui.Image image,
  ) {
    const int cols = 16;
    const int rows = 16;
    const double wallZ = RoomGeometry.wallZ; // 5.25m baseline

    // Physical dimension scaling:
    // A 1024px court floor tile represents ~1.4m of court width and ~1.4m of depth
    const double metersPerTileWidth = 1.40;
    const double metersPerTileDepth = 1.40;

    final positions = <Offset>[];
    final textureCoords = <Offset>[];
    final indices = <int>[];

    final screenWidth = geom.screenWidth;
    final halfScreenWidth = screenWidth / 2.0;
    final ppm = geom.camera.pixelsPerMeter;

    // Calculate nearZ at the bottom of the screen (floorRect.bottom)
    final denomBottom = (floorRect.bottom - geom.horizonY) /
        (geom.camera.eyeHeightInMeters * ppm);
    final nearZ = denomBottom > 0
        ? math.max(0.0, (geom.camera.focalDistance / denomBottom) - geom.camera.focalDistance)
        : 0.0;

    for (int r = 0; r <= rows; r++) {
      final tRow = r / rows;
      // Row 0 is at foreground (nearZ), Row 'rows' is at baseline (wallZ)
      final z = nearZ + (wallZ - nearZ) * tRow;

      // Exact pixel boundary locking: row 0 = floorRect.bottom, row 'rows' = floorRect.top
      final double y;
      if (r == 0) {
        y = floorRect.bottom;
      } else if (r == rows) {
        y = floorRect.top;
      } else {
        y = geom.projectFloor(0.0, z).dy;
      }

      final s = geom.camera.scaleAtDepth(z);
      final scaleFactor = ppm * s;

      for (int c = 0; c <= cols; c++) {
        final screenX = (c / cols) * screenWidth;
        positions.add(Offset(screenX, y));

        // Invert perspective projection to compute physical 3D world meters (x, z)
        final worldX =
            scaleFactor > 0 ? (screenX - halfScreenWidth) / scaleFactor : 0.0;

        // Map world meters to image texture coordinates
        final u = (worldX / metersPerTileWidth) * image.width;
        final v = (z / metersPerTileDepth) * image.height;
        textureCoords.add(Offset(u, v));
      }
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final i0 = r * (cols + 1) + c;
        final i1 = i0 + 1;
        final i2 = (r + 1) * (cols + 1) + c;
        final i3 = i2 + 1;

        indices.addAll([i0, i1, i2, i1, i3, i2]);
      }
    }

    final matrix = Float64List.fromList([
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]);

    final shader = ui.ImageShader(
      image,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      matrix,
    );

    final floorMeshPaint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.medium;

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: textureCoords,
      indices: indices,
    );

    canvas.drawVertices(vertices, BlendMode.srcOver, floorMeshPaint);

    // Warm Atmospheric Lighting Bridge:
    // Golden-amber ambient bounce light where the floor meets the red clay brick wall
    final warmBouncePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, floorRect.top),
        Offset(0, floorRect.top + floorRect.height * 0.45),
        const [
          Color(0x2EB87333), // Warm copper/amber baseline bounce
          Color(0x0EBD5A2A),
          Color(0x00000000), // Clean blonde in foreground
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(floorRect, warmBouncePaint);
  }

  /// Polished lacquer floor sheen overlay.
  void _renderFloorSheen(Canvas canvas, Rect floorRect) {
    final floorGlossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x24FFFFFF),
          Color(0x0CFFFFFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorGlossPaint);
  }

  void _renderKeyTrapezoid(Canvas canvas, RoomGeometry geom) {
    // 3D coordinates for the painted key:
    // Baseline at wallZ (5.25m), width 3.6m (X in [-1.8, 1.8])
    // Free-throw line at 1.30m, width 4.8m (X in [-2.4, 2.4])
    const baselineZ = RoomGeometry.wallZ;
    const freethrowZ = 1.30;
    const baselineHalfWidth = 1.85;
    const freethrowHalfWidth = 2.40;

    final pTopLeft = geom.projectFloor(-baselineHalfWidth, baselineZ);
    final pTopRight = geom.projectFloor(baselineHalfWidth, baselineZ);
    final pBottomRight = geom.projectFloor(freethrowHalfWidth, freethrowZ);
    final pBottomLeft = geom.projectFloor(-freethrowHalfWidth, freethrowZ);

    // Trapezoid body
    final keyPath = Path()
      ..moveTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy)
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..close();

    // Semicircular front key extension covering the free throw area
    // Center at (0, 0, freethrowZ), radius 1.8m
    final frontArcPoints = <Offset>[];
    const arcRadius = 1.80;
    const steps = 32;
    for (int i = 0; i <= steps; i++) {
      final theta = math.pi * i / steps; // 0 to pi (facing player)
      final x = arcRadius * math.cos(theta);
      final z = freethrowZ - arcRadius * math.sin(theta);
      frontArcPoints.add(geom.projectFloor(x, z));
    }

    final fullKeyPath = Path()
      ..moveTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy);

    for (final pt in frontArcPoints) {
      fullKeyPath.lineTo(pt.dx, pt.dy);
    }

    fullKeyPath
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..close();

    final keyRect = fullKeyPath.getBounds();
    final keyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF8B1A1E), // Deep collegiate red at baseline
          Color(0xFFA8262C), // Rich vibrant terracotta red center
          Color(0xFF961D22), // Warm foreground red
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(keyRect);

    canvas.drawPath(fullKeyPath, keyPaint);

    // Clean regulation collegiate dark court lines along key perimeter
    final keyBorderPaint = Paint()
      ..color = const Color(0xC02B2623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(keyPath, keyBorderPaint);
  }

  void _renderCourtMarkings(Canvas canvas, RoomGeometry geom) {
    final linePaint = Paint()
      ..color = const Color(0xC82B2623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final dashedPaint = Paint()
      ..color = const Color(0x702B2623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    // 1. Restricted Area Arc (Centered under hoop at Z=4.50m, Radius=1.15m)
    const hoopZ = 4.50;
    const baselineZ = RoomGeometry.wallZ;
    const restrictedRadius = 1.15;

    final restrictedPath = Path();
    // Straight left side from baseline to arc tangent
    final restLeftBase = geom.projectFloor(-restrictedRadius, baselineZ);
    final restLeftArc = geom.projectFloor(-restrictedRadius, hoopZ);
    restrictedPath.moveTo(restLeftBase.dx, restLeftBase.dy);
    restrictedPath.lineTo(restLeftArc.dx, restLeftArc.dy);

    // Front arc facing player (z decreases from 4.50 to 3.35m)
    const arcSteps = 24;
    for (int i = 0; i <= arcSteps; i++) {
      final theta = math.pi * i / arcSteps;
      final x = -restrictedRadius * math.cos(theta);
      final z = hoopZ - restrictedRadius * math.sin(theta);
      final pt = geom.projectFloor(x, z);
      restrictedPath.lineTo(pt.dx, pt.dy);
    }

    // Straight right side from arc tangent back to baseline
    final restRightBase = geom.projectFloor(restrictedRadius, baselineZ);
    restrictedPath.lineTo(restRightBase.dx, restRightBase.dy);

    canvas.drawPath(restrictedPath, linePaint);

    // 2. Free-Throw Line across the key at Z=1.30m
    const freethrowZ = 1.30;
    const freethrowHalfWidth = 2.40;
    final ftLeft = geom.projectFloor(-freethrowHalfWidth, freethrowZ);
    final ftRight = geom.projectFloor(freethrowHalfWidth, freethrowZ);
    canvas.drawLine(ftLeft, ftRight, linePaint);

    // 3. Free-Throw Circle (Centered at (0, 0, 1.30m), Radius=1.80m)
    const ftRadius = 1.80;

    // Solid front half (facing player, z < 1.30m)
    final frontCirclePath = Path();
    for (int i = 0; i <= arcSteps; i++) {
      final theta = math.pi * i / arcSteps;
      final x = ftRadius * math.cos(theta);
      final z = freethrowZ - ftRadius * math.sin(theta);
      final pt = geom.projectFloor(x, z);
      if (i == 0) {
        frontCirclePath.moveTo(pt.dx, pt.dy);
      } else {
        frontCirclePath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(frontCirclePath, linePaint);

    // Dashed rear half (receding toward hoop, z > 1.30m)
    for (int i = 0; i < 18; i += 2) {
      final t1 = math.pi * i / 18;
      final t2 = math.pi * (i + 1) / 18;
      final x1 = ftRadius * math.cos(t1);
      final z1 = freethrowZ + ftRadius * math.sin(t1);
      final x2 = ftRadius * math.cos(t2);
      final z2 = freethrowZ + ftRadius * math.sin(t2);

      final p1 = geom.projectFloor(x1, z1);
      final p2 = geom.projectFloor(x2, z2);
      canvas.drawLine(p1, p2, dashedPaint);
    }

    // 4. 3-Point Arc Framing the Court (Center at (0, 0, 4.50m), Radius=4.20m)
    final threePointPath = Path();
    const threePointRadius = 4.20;
    const threeSteps = 36;
    bool first = true;
    for (int i = 0; i <= threeSteps; i++) {
      final theta = 0.12 * math.pi + (0.76 * math.pi) * (i / threeSteps);
      final x = threePointRadius * math.cos(theta);
      final z = hoopZ - threePointRadius * math.sin(theta);
      final pt = geom.projectFloor(x, z);
      if (first) {
        threePointPath.moveTo(pt.dx, pt.dy);
        first = false;
      } else {
        threePointPath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(threePointPath, linePaint);
  }

  void _renderPoleFloorReflection(Canvas canvas, RoomGeometry geom) {
    // GamePigeon signature glossy white reflection streak running straight down
    // from the base of the pole (X = 0, Z = 4.96m) across the court floor.
    final poleFloorPt = geom.projectFloor(0.0, 4.96);
    final startY = poleFloorPt.dy;
    final endY = geom.screenHeight;
    final centerX = geom.screenWidth / 2.0;

    // Soft perspective reflection band that widens toward the camera
    const topWidth = 10.0;
    const botWidth = 44.0;

    final reflectionPath = Path()
      ..moveTo(centerX - topWidth / 2, startY)
      ..lineTo(centerX + topWidth / 2, startY)
      ..lineTo(centerX + botWidth / 2, endY)
      ..lineTo(centerX - botWidth / 2, endY)
      ..close();

    final reflectionRect = Rect.fromLTRB(
      centerX - botWidth / 2,
      startY,
      centerX + botWidth / 2,
      endY,
    );

    final corePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x95FFFFFF), // Crisp specular white reflection core directly under pole
          Color(0x45FFFFFF), // Soft midtone fade along the key
          Color(0x18FFFFFF), // Feathered spread in foreground
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.65, 1.0],
      ).createShader(reflectionRect);

    canvas.drawPath(reflectionPath, corePaint);
  }
}
