import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

  // ── Wind sway (trees only) ──
  final bool sways;

  /// Per-tree timing so the trees don't move in lockstep.
  final double phase;

  /// Same look as [paint], but sampling the image through a shader so the
  /// tree can be drawn as a bending mesh.
  Paint? meshPaint;

  /// Reused vertex positions / fixed texture coordinates of the mesh.
  Float32List? positions;
  Float32List? texCoords;

  _LoadedBillboard({
    required this.spec,
    required this.image,
    required this.paint,
    required this.sways,
    required this.phase,
  }) : widthPx = image.width.toDouble(),
       heightPx = image.height.toDouble();
}

/// Billboards (trees, hills) and their ground shadows.
///
/// Trees near the camera sway in the match's wind: each is drawn as a small
/// mesh whose points move with their height, so the trunk stays planted and
/// the crown bends (a slow lean + sway, plus a faster leaf flutter, each tree
/// on its own timing). Stronger wind = more movement, leaning the way it
/// blows. Their ground shadows shift with the crowns.
///
/// Far trees and the hills stay still (real distant trees barely move, and it
/// saves work). If the device can't hold the frame rate, swaying switches
/// itself off for the session.
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

  BillboardRenderer({required this.camera, required this.theme});

  // ── Sway tuning ─────────────────────────────────────────────────────────
  /// Mesh resolution (columns × rows of quads).
  static const int _cols = 4;
  static const int _rows = 6;

  /// Trees sway by how big they are ON SCREEN (so a far tree seen through the
  /// aiming zoom sways too, while tiny distant ones stay still): full sway
  /// above [_swayFullPx] tall, fading to none at [_swayMinPx].
  static const double _swayMinPx = 40.0;
  static const double _swayFullPx = 110.0;

  static final Uint16List _indices = _buildIndices();
  static final Float64List _identity = Float64List.fromList(const <double>[
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  double _time = 0.0;

  // Wind the trees are currently showing; eases toward the arrow's wind so a
  // new arrow never makes the trees snap.
  double _windStrength = 0.0; // 0..1
  double _windSide = 0.0; // −1..1: −1 blowing left, +1 right
  double _targetStrength = 0.0;
  double _targetSide = 0.0;

  /// Seconds for the trees to settle into a new wind (about 63% of the way).
  static const double _windEaseSeconds = 1.2;

  /// Off for the rest of the session once the frame rate struggles.
  /// Automatic quality: sway fades out while the device is struggling and
  /// fades back in once it keeps up again. Only judged in release builds:
  /// debug web builds are always slow and would switch it off for no reason.
  bool swayEnabled = true;
  double _swayLevel = 1.0; // eased 0..1 version of [swayEnabled]
  double _avgDt = 1.0 / 60.0;
  double _slowFor = 0.0;
  double _fastFor = 0.0;

  /// Wind for the current arrow (the same model that moves the arrow).
  void setWind({
    required double display,
    required double angle,
    double phase = 0.0,
  }) {
    _targetStrength = (display / ArcheryK.windMaxDisplay).clamp(0.0, 1.0);
    _targetSide = math.sin(angle);
    if (!_windSet) {
      // First wind of the session: start there instead of easing in from 0.
      _windSet = true;
      _windStrength = _targetStrength;
      _windSide = _targetSide;
    }
  }

  bool _windSet = false;

  /// [dt] should be the game's clamped frame time.
  void update(double dt) {
    // Never wrapped: sin() of a large time is fine, and wrapping would make
    // every tree jump (the sway frequencies don't share a common period).
    _time += dt;

    final double k = 1.0 - math.exp(-dt / _windEaseSeconds);
    _windStrength += (_targetStrength - _windStrength) * k;
    _windSide += (_targetSide - _windSide) * k;

    if (kReleaseMode) {
      _avgDt += (dt - _avgDt) * 0.05;
      if (swayEnabled) {
        // Below ~40 fps for 3 s: ease the sway off.
        _slowFor = _avgDt > 1.0 / 40.0 ? _slowFor + dt : 0.0;
        if (_slowFor > 3.0) {
          swayEnabled = false;
          _fastFor = 0.0;
        }
      } else {
        // Back above ~50 fps for 5 s: bring it back.
        _fastFor = _avgDt < 1.0 / 50.0 ? _fastFor + dt : 0.0;
        if (_fastFor > 5.0) {
          swayEnabled = true;
          _slowFor = 0.0;
        }
      }
    }
    final double target = swayEnabled ? 1.0 : 0.0;
    _swayLevel += (target - _swayLevel) * (1.0 - math.exp(-dt / 0.6));
    if ((_swayLevel - target).abs() < 0.001) _swayLevel = target;
  }

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
    final Map<String, ui.ImageShader> shaders = {};
    for (int i = 0; i < theme.billboards.length; i++) {
      final spec = theme.billboards[i];
      final img = _loadedImages[spec.imageKey];
      if (img == null) continue;

      final Paint paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.low;

      final bool sways = spec.imageKey.startsWith('tree');
      final b = _LoadedBillboard(
        spec: spec,
        image: img,
        paint: paint,
        sways: sways,
        phase: (i * 2.399963) % (2.0 * math.pi), // golden-angle spread
      );

      if (sways) {
        final shader = shaders[spec.imageKey] ??= ui.ImageShader(
          img,
          TileMode.clamp,
          TileMode.clamp,
          _identity,
          filterQuality: FilterQuality.low,
        );
        b.meshPaint = Paint()
          ..isAntiAlias = true
          ..shader = shader;
        b.positions = Float32List((_cols + 1) * (_rows + 1) * 2);
        b.texCoords = _buildTexCoords(b.widthPx, b.heightPx, flip: spec.flipX);
      }
      _billboards.add(b);
    }

    _isLoaded = true;
    setTargetDistance(_targetDistance);
  }

  static Float32List _buildTexCoords(double w, double h, {required bool flip}) {
    final t = Float32List((_cols + 1) * (_rows + 1) * 2);
    int k = 0;
    for (int r = 0; r <= _rows; r++) {
      for (int c = 0; c <= _cols; c++) {
        final double u = c / _cols;
        t[k++] = (flip ? 1.0 - u : u) * w;
        t[k++] = (r / _rows) * h;
      }
    }
    return t;
  }

  static Uint16List _buildIndices() {
    final idx = Uint16List(_cols * _rows * 6);
    int k = 0;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final int a = r * (_cols + 1) + c;
        final int b = a + 1;
        final int d = a + (_cols + 1);
        final int e = d + 1;
        idx[k++] = a;
        idx[k++] = b;
        idx[k++] = d;
        idx[k++] = b;
        idx[k++] = e;
        idx[k++] = d;
      }
    }
    return idx;
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
      final double hazeAmount = ((1.0 - math.exp(-b.z / theme.hazeDist)) * 0.55)
          .clamp(0.0, 1.0);
      if (hazeAmount > 0.02) {
        final double invF = 1.0 - hazeAmount;
        b.paint.colorFilter = ColorFilter.matrix(<double>[
          invF,
          0,
          0,
          0,
          hazeAmount * theme.haze.r * 255.0,
          0,
          invF,
          0,
          0,
          hazeAmount * theme.haze.g * 255.0,
          0,
          0,
          invF,
          0,
          hazeAmount * theme.haze.b * 255.0,
          0,
          0,
          0,
          1,
          0,
        ]);
      } else {
        b.paint.colorFilter = null;
      }
      b.meshPaint?.colorFilter = b.paint.colorFilter;
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

  // ── Sway model ──────────────────────────────────────────────────────────

  /// How much this tree sways (0 = still) given its height on screen.
  double _swayWeight(_LoadedBillboard b, double heightPx) {
    if (!b.sways || _swayLevel <= 0.0) return 0.0;
    return ((heightPx - _swayMinPx) / (_swayFullPx - _swayMinPx)).clamp(
          0.0,
          1.0,
        ) *
        _swayLevel;
  }

  /// Crown offset as a fraction of tree height: steady lean with the wind
  /// plus a gusting sway. Leaves move even in calm air.
  double _crownOffset(_LoadedBillboard b) {
    final double s = _windStrength;
    final double t = _time;
    final double lean = 0.022 * s * _windSide;
    final double gust =
        1.0 +
        0.35 * math.sin(t * 0.7 + b.phase * 0.5) * math.sin(t * 0.31 + b.phase);
    final double sway =
        (0.012 + 0.018 * s) *
        gust *
        (math.sin(t * 1.25 + b.phase) * 0.75 +
            math.sin(t * 2.1 + b.phase * 1.7) * 0.25);
    return lean + sway;
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
      final double flatten = (eyeY / math.sqrt(eyeY * eyeY + depth * depth))
          .clamp(0.25, 0.75);
      final double heightPx = widthPx * flatten * 0.45;

      // The crown's shadow follows the crown a little as it sways.
      final double treeH = pxPerM * b.spec.widthMeters * b.heightPx / b.widthPx;
      final double w = _swayWeight(b, treeH);
      final double shift = w > 0.0 ? _crownOffset(b) * treeH * 0.22 * w : 0.0;

      // Slight sun direction offset (sun top-left -> shadow slightly to bottom-right)
      final double drawX = camera.sx - widthPx * 0.42 + shift;
      final double drawY = camera.sy - heightPx * 0.5 + 2.0;

      if (drawX + widthPx < 0 ||
          drawX > screenW ||
          drawY + heightPx < 0 ||
          drawY > screenH) {
        continue;
      }

      // Transform instead of building Rects every frame.
      canvas.save();
      canvas.translate(drawX, drawY);
      canvas.scale(widthPx / shadowImgW, heightPx / shadowImgH);
      canvas.drawImage(shadow, Offset.zero, _shadowPaint);
      canvas.restore();
    }
  }

  /// Renders all billboards sorted back-to-front.
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
      final double scale = drawW / b.widthPx;
      final double drawH = b.heightPx * scale;

      final double drawX = camera.sx - drawW * 0.5;
      final double drawY = camera.sy - drawH;

      // Culling (with room for the swaying crown)
      final double margin = drawW * 0.1;
      if (drawX + drawW + margin < 0 ||
          drawX - margin > screenW ||
          drawY + drawH < 0 ||
          drawY > screenH) {
        continue;
      }

      // Swaying trees are always drawn as a mesh (never switching to a plain
      // image mid-sway, which made them hop when the sway crossed zero).
      final double w = _swayWeight(b, drawH);
      if (w > 0.0) {
        final double crown = _crownOffset(b) * drawH * w;
        _drawSwaying(canvas, b, drawX, drawY, drawW, drawH, crown, w);
        continue;
      }

      // Still: a plain image draw (transform, no per-frame Rects).
      canvas.save();
      if (spec.flipX) {
        canvas.translate(drawX + drawW, drawY);
        canvas.scale(-scale, scale);
      } else {
        canvas.translate(drawX, drawY);
        canvas.scale(scale, scale);
      }
      canvas.drawImage(b.image, Offset.zero, b.paint);
      canvas.restore();
    }
  }

  /// Draws a tree as a bending mesh: points move by their height (trunk base
  /// fixed, crown most), with a faster leaf flutter across the crown.
  void _drawSwaying(
    Canvas canvas,
    _LoadedBillboard b,
    double x0,
    double y0,
    double w,
    double h,
    double crownPx,
    double weight,
  ) {
    final pos = b.positions!;
    final double t = _time;
    final double flutterPx =
        (0.006 + 0.008 * _windStrength) * w * weight; // leaf rustle
    int k = 0;
    for (int r = 0; r <= _rows; r++) {
      final double v = r / _rows; // 0 top .. 1 base
      final double height = 1.0 - v; // 0 base .. 1 top
      // Trunk (lower ~20%) stays put; above it the bend grows smoothly.
      final double hb = height <= 0.2 ? 0.0 : (height - 0.2) / 0.8;
      final double bend = hb * math.sqrt(hb); // hb^1.5
      final double dx = crownPx * bend;
      final double dy = dx.abs() * 0.08 * bend; // bending shortens a little
      for (int c = 0; c <= _cols; c++) {
        final double u = c / _cols;
        final double flutter =
            bend *
            flutterPx *
            math.sin(t * 3.1 + b.phase * 2.3 + u * 4.0 + height * 5.0);
        pos[k++] = x0 + u * w + dx + flutter;
        pos[k++] = y0 + v * h + dy + flutter * 0.4;
      }
    }

    // One small native object per swaying tree per frame (the points change).
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      pos,
      textureCoordinates: b.texCoords,
      indices: _indices,
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, b.meshPaint!);
  }
}
