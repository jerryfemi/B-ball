import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scene/board_projection.dart';

/// The wall behind the board: warm wood planks filling the whole screen.
///
/// - If `assets/darts/wood.jpg` (or `.png`) exists, that texture is used,
///   scaled to cover the screen. Otherwise planks are painted in code.
/// - A warm light falls on the board and the edges darken.
/// - Painted once into an image on resize (and when the texture arrives), so
///   the grain paths aren't redrawn every frame; `render()` is one
///   `drawImage`.
class BoardBackdrop extends Component {
  final BoardProjection projection;

  ui.Image? _image;
  ui.Image? _wood;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;
  double _w = 0.0;
  double _h = 0.0;

  static const List<String> _texturePaths = [
    'assets/darts/wood.jpg',
    'assets/darts/wood.png',
  ];

  BoardBackdrop({required this.projection}) : super(priority: 0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final path in _texturePaths) {
      try {
        final ByteData data = await rootBundle.load(path);
        final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _wood = (await codec.getNextFrame()).image;
        break;
      } catch (_) {
        // Not there: try the next one, else paint the planks.
      }
    }
    if (_w > 0.0) _record(_w, _h);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _w = size.x;
    _h = size.y;
    _record(size.x, size.y);
  }

  void _record(double width, double height) {
    if (width < 1.0 || height < 1.0) return;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final Rect screen = Rect.fromLTWH(0, 0, width, height);

    final ui.Image? wood = _wood;
    if (wood != null) {
      // Cover: fill the screen, keep the texture's proportions.
      final double iw = wood.width.toDouble();
      final double ih = wood.height.toDouble();
      final double s = math.max(width / iw, height / ih);
      final double sw = width / s;
      final double sh = height / s;
      c.drawImageRect(
        wood,
        Rect.fromLTWH((iw - sw) * 0.5, (ih - sh) * 0.5, sw, sh),
        screen,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      _paintPlanks(c, width, height);
    }

    // Warm light on the board.
    final Offset centre = Offset(projection.boardCenterX, projection.boardCenterY);
    final double r = math.max(projection.boardRadiusPx * 3.0, height * 0.6);
    c.drawRect(
      screen,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          r,
          const [Color(0x2EFFD9A0), Color(0x00FFD9A0)],
          const [0.0, 1.0],
        ),
    );

    // Darker edges.
    c.drawRect(
      screen,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(width * 0.5, height * 0.45),
          math.max(width, height) * 0.8,
          const [Color(0x00000000), Color(0x8C140A04)],
          const [0.55, 1.0],
        ),
    );

    final ui.Picture picture = recorder.endRecording();
    _image?.dispose();
    _image = picture.toImageSync(width.ceil(), height.ceil());
    picture.dispose();
  }

  /// Vertical planks in warm browns with grain, painted once.
  void _paintPlanks(Canvas c, double width, double height) {
    const List<Color> tones = [
      Color(0xFF8A5A33),
      Color(0xFF9A6639),
      Color(0xFF7E5230),
      Color(0xFF946038),
      Color(0xFF85572F),
    ];
    final double plankW = math.max(56.0, projection.boardRadiusPx * 0.62);
    final int count = (width / plankW).ceil() + 1;
    final double x0 = projection.boardCenterX - plankW * (count / 2).floor() - plankW * 0.5;
    final math.Random rnd = math.Random(7);
    final Paint fill = Paint();
    final Paint grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Paint seam = Paint()
      ..color = const Color(0xFF3B2414)
      ..strokeWidth = 2.0;
    final Paint seamLight = Paint()
      ..color = const Color(0x33FFE2BF)
      ..strokeWidth = 1.0;

    for (int i = 0; i < count + 1; i++) {
      final double x = x0 + i * plankW;
      final Color base = tones[(i * 3 + 1) % tones.length];
      final Rect r = Rect.fromLTWH(x, 0, plankW, height);
      fill.shader = ui.Gradient.linear(
        Offset(x, 0),
        Offset(x + plankW, 0),
        [
          Color.lerp(base, const Color(0xFF000000), 0.10)!,
          base,
          Color.lerp(base, const Color(0xFFFFFFFF), 0.06)!,
          Color.lerp(base, const Color(0xFF000000), 0.12)!,
        ],
        const [0.0, 0.3, 0.7, 1.0],
      );
      c.drawRect(r, fill);

      // Grain: long wavy lines down the plank.
      final int lines = 7 + rnd.nextInt(4);
      for (int g = 0; g < lines; g++) {
        final double gx = x + plankW * (0.08 + 0.84 * rnd.nextDouble());
        final double amp = 2.0 + rnd.nextDouble() * 5.0;
        final double freq = 0.004 + rnd.nextDouble() * 0.006;
        final double phase = rnd.nextDouble() * math.pi * 2.0;
        final bool dark = rnd.nextBool();
        grain.color = dark ? const Color(0x24000000) : const Color(0x14FFE7C4);
        final Path path = Path()..moveTo(gx, 0);
        for (double y = 0; y <= height; y += 12.0) {
          path.lineTo(gx + math.sin(y * freq + phase) * amp, y);
        }
        c.drawPath(path, grain);
      }
      // A knot now and then.
      if (rnd.nextDouble() < 0.35) {
        final Offset k = Offset(x + plankW * (0.3 + 0.4 * rnd.nextDouble()), height * rnd.nextDouble());
        c.drawOval(
          Rect.fromCenter(center: k, width: plankW * 0.16, height: plankW * 0.30),
          Paint()
            ..shader = ui.Gradient.radial(
              k,
              plankW * 0.15,
              const [Color(0x664A2A12), Color(0x00000000)],
            ),
        );
      }
      c.drawLine(Offset(x, 0), Offset(x, height), seam);
      c.drawLine(Offset(x + 2.0, 0), Offset(x + 2.0, height), seamLight);
    }
  }

  @override
  void render(Canvas canvas) {
    final ui.Image? img = _image;
    if (img != null) canvas.drawImage(img, Offset.zero, _imagePaint);
  }

  @override
  void onRemove() {
    _image?.dispose();
    _image = null;
    _wood?.dispose();
    _wood = null;
    super.onRemove();
  }
}
