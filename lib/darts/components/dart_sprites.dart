import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Pre-rendered 3D dart sprite sheet atlas loader and cached frame registry.
///
/// Follows DARTS_PLAN.md Step 10:
/// - 3D dart asset ("GAME READY RED DART ASSET" by oxxycodone, CC-BY 4.0).
/// - Loads `darts_atlas.png` and `darts_atlas.json` once in `onLoad`.
/// - Builds source Rects once into fixed lists:
///   - `rest[2]`: rest frame for player 1 (0) and player 2 / bot (1).
///   - `spin[2][8]`: 8 rotating spin frames per player.
///   - `stuck[2][3]`: 3 perspective-angled stuck frames per player.
/// - Caches `dstAtOrigin` centered on the dart's tip.
/// - Zero JSON access or Rect allocation during game loop.
class DartSprites {
  final ui.Image atlasImage;
  final double cellWidth;
  final double cellHeight;

  /// Rest frames: `rest[0]` for P1, `rest[1]` for P2/bot.
  final List<ui.Rect> rest;

  /// Spin frames: `spin[playerIndex][frameIndex]` (8 frames per player).
  final List<List<ui.Rect>> spin;

  /// Stuck landing poses: `stuck[playerIndex][angleIndex]` (3 frames per player).
  final List<List<ui.Rect>> stuck;

  /// Cached destination Rect at origin centered on the dart's tip.
  final ui.Rect dstAtOrigin;

  const DartSprites({
    required this.atlasImage,
    required this.cellWidth,
    required this.cellHeight,
    required this.rest,
    required this.spin,
    required this.stuck,
    required this.dstAtOrigin,
  });

  /// Loads and parses the sprite sheet image and layout JSON.
  static Future<DartSprites> load({
    String imagePath = 'assets/darts/sprites/darts_atlas.png',
    String jsonPath = 'assets/darts/sprites/darts_atlas.json',
  }) async {
    // 1. Load sprite sheet atlas image
    final ByteData imgData = await rootBundle.load(imagePath);
    final ui.Codec codec =
        await ui.instantiateImageCodec(imgData.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image atlasImage = frameInfo.image;

    // 2. Parse atlas JSON definition
    final String jsonStr = await rootBundle.loadString(jsonPath);
    final Map<String, dynamic> data =
        jsonDecode(jsonStr) as Map<String, dynamic>;

    final double cellW = (data['cellWidth'] as num).toDouble();
    final double cellH = (data['cellHeight'] as num).toDouble();
    final int spinCount = (data['spinFrames'] as num).toInt();
    final int stuckCount = (data['stuckFrames'] as num).toInt();

    final Map<String, dynamic> frames =
        data['frames'] as Map<String, dynamic>;

    ui.Rect rectFromFrame(String key) {
      final f = frames[key] as Map<String, dynamic>;
      return ui.Rect.fromLTWH(
        (f['x'] as num).toDouble(),
        (f['y'] as num).toDouble(),
        (f['w'] as num).toDouble(),
        (f['h'] as num).toDouble(),
      );
    }

    final List<ui.Rect> restRects = [
      rectFromFrame('p1_rest'),
      rectFromFrame('p2_rest'),
    ];

    final List<List<ui.Rect>> spinRects = [
      List.generate(spinCount, (i) => rectFromFrame('p1_spin_$i')),
      List.generate(spinCount, (i) => rectFromFrame('p2_spin_$i')),
    ];

    final List<List<ui.Rect>> stuckRects = [
      List.generate(stuckCount, (i) => rectFromFrame('p1_stuck_$i')),
      List.generate(stuckCount, (i) => rectFromFrame('p2_stuck_$i')),
    ];

    // Dart tip anchor: centered horizontally at top of sprite cell (Y = 0)
    final ui.Rect dstAtOrigin = ui.Rect.fromLTWH(
      -cellW * 0.5,
      0.0,
      cellW,
      cellH,
    );

    return DartSprites(
      atlasImage: atlasImage,
      cellWidth: cellW,
      cellHeight: cellH,
      rest: restRects,
      spin: spinRects,
      stuck: stuckRects,
      dstAtOrigin: dstAtOrigin,
    );
  }

  void dispose() {
    atlasImage.dispose();
  }
}
