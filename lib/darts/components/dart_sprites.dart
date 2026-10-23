import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// The dart's angle-sweep sprite sheet (made with the sprite renderer's
/// "Angle sweep" mode).
///
/// - Row `r` shows the dart seen at [angles][r] degrees between the line of
///   sight and the direction the tip points: 0 = from straight behind (the
///   flights make an X), 90 = side view.
/// - Column `c` is a spin step (the sheet covers [spinDegrees], usually 90°
///   because the four flights repeat).
/// - The tip points up in every frame; [tipX]/[tipY] give the tip's pixel in
///   each row's cell, so a frame can be pinned by its tip and rotated.
/// - [fullLengthPx] is the dart's tip-to-tail length in a 90° frame, which
///   turns a real length in metres into a sprite scale.
///
/// Both players use the same dart. Everything is parsed once in [load]; the
/// game loop only reads these lists.
///
/// Dart model: "Dart" by TimThePanda (Sketchfab), CC BY 4.0.
class DartSprites {
  static const String credit = 'Dart model: "Dart" by TimThePanda (Sketchfab), CC BY 4.0';

  final ui.Image atlasImage;
  final double cellWidth;
  final double cellHeight;

  /// Viewing angle of each row (degrees, increasing).
  final List<double> angles;

  /// `src[row][column]`: the frame's rectangle in the atlas.
  final List<List<ui.Rect>> src;

  /// `dstAtTip[row]`: the cell drawn with the dart's tip at the origin.
  final List<ui.Rect> dstAtTip;

  final double fullLengthPx;
  final int spinColumns;
  final double spinDegrees;

  /// The side-view row (largest angle), used for shadows.
  int get sideRow => angles.length - 1;

  const DartSprites({
    required this.atlasImage,
    required this.cellWidth,
    required this.cellHeight,
    required this.angles,
    required this.src,
    required this.dstAtTip,
    required this.fullLengthPx,
    required this.spinColumns,
    required this.spinDegrees,
  });

  /// The row whose angle is nearest [deg].
  int rowFor(double deg) {
    final List<double> a = angles;
    if (deg <= a[0]) return 0;
    final int last = a.length - 1;
    if (deg >= a[last]) return last;
    for (int i = 1; i <= last; i++) {
      if (deg < a[i]) {
        return (deg - a[i - 1] < a[i] - deg) ? i - 1 : i;
      }
    }
    return last;
  }

  /// Loads the atlas image and its JSON once.
  static Future<DartSprites> load({
    String imagePath = 'assets/darts/sprites/dart_sweep.png',
    String jsonPath = 'assets/darts/sprites/dart_sweep.json',
  }) async {
    final ByteData imgData = await rootBundle.load(imagePath);
    final ui.Codec codec =
        await ui.instantiateImageCodec(imgData.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image atlasImage = frameInfo.image;

    final Map<String, dynamic> data =
        jsonDecode(await rootBundle.loadString(jsonPath)) as Map<String, dynamic>;
    return fromJson(atlasImage, data);
  }

  /// Builds the frame tables from a parsed sweep JSON (also used by tests).
  static DartSprites fromJson(ui.Image atlasImage, Map<String, dynamic> data) {
    double d(Object? v) => (v as num).toDouble();

    final double cellW = d(data['cellWidth']);
    final double cellH = d(data['cellHeight']);
    final int cols = (data['spinFrames'] as num).toInt();
    final List<double> angles =
        (data['angles'] as List).map((e) => d(e)).toList(growable: false);
    final List rowsInfo = data['angleRows'] as List;
    final Map<String, dynamic> frames = data['frames'] as Map<String, dynamic>;

    ui.Rect rectFor(int row, int col) {
      final f = frames['p1_a${row}_s$col'] as Map<String, dynamic>;
      return ui.Rect.fromLTWH(d(f['x']), d(f['y']), d(f['w']), d(f['h']));
    }

    final List<List<ui.Rect>> src = List.generate(
      angles.length,
      (r) => List.generate(cols, (c) => rectFor(r, c), growable: false),
      growable: false,
    );
    final List<ui.Rect> dstAtTip = List.generate(angles.length, (r) {
      final tip = (rowsInfo[r] as Map<String, dynamic>)['tip'] as Map<String, dynamic>;
      return ui.Rect.fromLTWH(-d(tip['x']), -d(tip['y']), cellW, cellH);
    }, growable: false);

    return DartSprites(
      atlasImage: atlasImage,
      cellWidth: cellW,
      cellHeight: cellH,
      angles: angles,
      src: src,
      dstAtTip: dstAtTip,
      fullLengthPx: d(data['fullLengthPx']),
      spinColumns: cols,
      spinDegrees: d(data['spinDegrees'] ?? 90),
    );
  }

  void dispose() {
    atlasImage.dispose();
  }
}
