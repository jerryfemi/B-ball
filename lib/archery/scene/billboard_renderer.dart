import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../util/image_loader.dart';
import 'venue_theme.dart';

/// Internal runtime cache for a loaded billboard instance.
class _LoadedBillboard {
  final BillboardSpec spec;
  final ui.Image image;
  final Paint paint;
  final double widthPx;
  final double heightPx;

  /// Effective world Z (spec.z, shifted back for followTarget objects).
  double z = 0.0;

  _LoadedBillboard({
    required this.spec,
    required this.image,
    required this.paint,
  })  : widthPx = image.width.toDouble(),
        heightPx = image.height.toDouble();
}

/// High-performance zero-allocation billboard and contact-shadow renderer.
class BillboardRenderer {
  final ArcheryCamera camera;
  final VenueTheme theme;

  final Map<String, ui.Image> _loadedImages = {};
  final List<_LoadedBillboard> _billboards = [];
  ui.Image? _shadowBlob;

  // Cached paint for tree ground shadows (35% alpha)
  final Paint _shadowPaint = Paint()
    ..color = const Color(0x59000000)
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.low;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  BillboardRenderer({
    required this.camera,
    required this.theme,
  });

  /// Loads all billboard images and precomputes distance haze color filters.
  Future<void> load() async {
    _loadedImages.clear();
    _billboards.clear();

    // 1. Load unique billboard images
    for (final entry in theme.billboardImages.entries) {
      try {
        _loadedImages[entry.key] = await loadArcheryImage(entry.value);
      } catch (e) {
        debugPrint('Failed to load archery billboard image ${entry.value}: $e');
      }
    }

    // 2. Load or generate shadow blob
    try {
      _shadowBlob = await loadArcheryImage(theme.shadowBlobImage);
    } catch (_) {
      // Fallback: generate 64x64 soft shadow blob procedurally
      _shadowBlob = _generateFallbackShadowBlob();
    }

    // 3. Prepare billboards (haze filters + back-to-front order)
    for (final spec in theme.billboards) {
      final img = _loadedImages[spec.imageKey];
      if (img == null) continue;

      final Paint paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.low;

      _billboards.add(_LoadedBillboard(
        spec: spec,
        image: img,
        paint: paint,
      ));
    }

    _isLoaded = true;
    setTargetDistance(_targetDistance);
  }

  double _targetDistance = ArcheryK.distanceM;

  /// Moves followTarget objects back with the target, then refreshes haze and
  /// draw order. Called on load and when a new set changes the distance
  /// (an event, so allocating the filters here is fine).
  void setTargetDistance(double distance) {
    _targetDistance = distance;
    final double shift = distance - ArcheryK.distanceM;
    for (final b in _billboards) {
      b.z = b.spec.z + (b.spec.followTarget ? shift : 0.0);

      // Distance haze: 1 - exp(-z / hazeDist)
      final double hazeAmount =
          ((1.0 - math.exp(-b.z / theme.hazeDist)) * 0.55).clamp(0.0, 1.0);
      if (hazeAmount > 0.02) {
        final double invF = 1.0 - hazeAmount;
        b.paint.colorFilter = ColorFilter.matrix(<double>[
          invF, 0, 0, 0, hazeAmount * theme.haze.r * 255.0,
          0, invF, 0, 0, hazeAmount * theme.haze.g * 255.0,
          0, 0, invF, 0, hazeAmount * theme.haze.b * 255.0,
          0, 0, 0, 1, 0,
        ]);
      } else {
        b.paint.colorFilter = null;
      }
    }
    _billboards.sort((a, b) => b.z.compareTo(a.z));
  }

  ui.Image _generateFallbackShadowBlob() {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double size = 64.0;
    const Rect rect = Rect.fromLTWH(0, 0, size, size);

    final Paint paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xCC000000), Color(0x00000000)],
        stops: [0.0, 1.0],
      ).createShader(rect);

    canvas.drawOval(rect, paint);
    return recorder.endRecording().toImageSync(64, 64);
  }

  /// Renders soft ground contact shadows for all visible trees.
  /// Called right before drawing billboards so shadows lie under them.
  void renderShadows(Canvas canvas) {
    if (!_isLoaded || _shadowBlob == null) return;

    final double screenW = camera.screenW;
    final double screenH = camera.screenH;
    final double eyeY = camera.eyeY;
    final ui.Image shadow = _shadowBlob!;
    final double shadowImgW = shadow.width.toDouble();
    final double shadowImgH = shadow.height.toDouble();

    for (int i = 0; i < _billboards.length; i++) {
      final b = _billboards[i];
      if (!b.spec.castShadow) continue;

      if (!camera.project(b.spec.x, b.spec.baseY, b.z)) continue;
      final double depth = camera.depth;
      if (depth <= 0.3) continue;

      final double pxPerM = camera.pxPerMeterAt(depth);
      final double widthPx = pxPerM * b.spec.widthMeters * b.spec.shadowScale;
      // Flatten ellipse by camera angle
      final double flatten = (eyeY / math.sqrt(eyeY * eyeY + depth * depth)).clamp(0.25, 0.75);
      final double heightPx = widthPx * flatten * 0.45;

      // Slight sun direction offset (sun top-left -> shadow slightly to bottom-right)
      final double drawX = camera.sx - widthPx * 0.42;
      final double drawY = camera.sy - heightPx * 0.5 + 2.0;

      if (drawX + widthPx < 0 || drawX > screenW || drawY + heightPx < 0 || drawY > screenH) {
        continue;
      }

      final Rect dst = Rect.fromLTWH(drawX, drawY, widthPx, heightPx);
      final Rect src = Rect.fromLTWH(0, 0, shadowImgW, shadowImgH);
      canvas.drawImageRect(shadow, src, dst, _shadowPaint);
    }
  }

  /// Renders all billboards sorted back-to-front with zero runtime allocation.
  void renderBillboards(Canvas canvas) {
    if (!_isLoaded) return;

    final double screenW = camera.screenW;
    final double screenH = camera.screenH;

    for (int i = 0; i < _billboards.length; i++) {
      final b = _billboards[i];
      final BillboardSpec spec = b.spec;

      // Project bottom-center contact point
      if (!camera.project(spec.x, spec.baseY, b.z)) continue;
      final double depth = camera.depth;
      if (depth <= 0.3) continue;

      final double pxPerM = camera.pxPerMeterAt(depth);
      final double drawW = pxPerM * spec.widthMeters;
      final double scaleY = drawW / b.widthPx;
      final double drawH = b.heightPx * scaleY;

      final double drawX = camera.sx - drawW * 0.5;
      final double drawY = camera.sy - drawH;

      // Culling
      if (drawX + drawW < 0 || drawX > screenW || drawY + drawH < 0 || drawY > screenH) {
        continue;
      }

      if (spec.flipX) {
        canvas.save();
        canvas.translate(drawX + drawW, drawY);
        canvas.scale(-scaleY, scaleY);
        canvas.drawImage(b.image, Offset.zero, b.paint);
        canvas.restore();
      } else {
        final Rect src = Rect.fromLTWH(0, 0, b.widthPx, b.heightPx);
        final Rect dst = Rect.fromLTWH(drawX, drawY, drawW, drawH);
        canvas.drawImageRect(b.image, src, dst, b.paint);
      }
    }
  }
}
