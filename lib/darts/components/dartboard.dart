import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import '../scene/board_projection.dart';

/// Renders the regulation dartboard and hit-area flash.
///
/// Follows DARTS_PLAN.md Step 9:
/// - Recorded into a single [ui.Picture] on resize.
/// - Standard colors: black/cream singles, alternating red/green doubles and trebles,
///   green outer bull, red inner bull, thin silver wires, white numbers on black surround.
/// - Precomputes paths for all 82 scoring areas at record time.
/// - `flashArea(DartHit)` triggers a 450 ms fade flash with `#38BDF8` at 35% alpha.
/// - Zero allocations per frame in `render()`.
class Dartboard extends Component {
  final BoardProjection projection;

  ui.Picture? _boardPicture;

  // ─── 82 Precomputed Scoring Area Paths ─────────────────────────────────────
  final Map<String, Path> _flashPaths = <String, Path>{};
  Path? _activeFlashPath;
  double _flashTime = 0.0;
  static const double _flashDuration = 0.45; // 450 ms

  final Paint _flashPaint = Paint()..style = PaintingStyle.fill;

  Dartboard({required this.projection}) : super(priority: 1);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recordBoard();
  }

  /// Triggers a visual flash on the specific scored board segment/bed.
  void flashArea(DartHit hit) {
    if (hit.isMiss) {
      _activeFlashPath = null;
      _flashTime = 0.0;
      return;
    }

    final String key = _flashKeyFor(hit);
    _activeFlashPath = _flashPaths[key];
    _flashTime = _flashDuration;
  }

  String _flashKeyFor(DartHit hit) {
    if (hit.isInnerBull) return 'bull_inner';
    if (hit.isBull) return 'bull_outer';
    if (hit.isDouble) return 'D${hit.segment}';
    if (hit.isTreble) return 'T${hit.segment}';
    if (hit.r > (DartsK.trebleInR + DartsK.trebleOutR) * 0.5) {
      return 'S${hit.segment}_outer';
    } else {
      return 'S${hit.segment}_inner';
    }
  }

  void _recordBoard() {
    _boardPicture?.dispose();
    _flashPaths.clear();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, projection.screenWidth, projection.screenHeight),
    );

    final double cx = projection.boardCenterX;
    final double cy = projection.boardCenterY;
    final Offset center = Offset(cx, cy);
    final double mmToPx = projection.mmToPx;

    // Radii in screen pixels
    final double rInnerBull = DartsK.innerBullR * mmToPx;
    final double rOuterBull = DartsK.outerBullR * mmToPx;
    final double rTrebleIn = DartsK.trebleInR * mmToPx;
    final double rTrebleOut = DartsK.trebleOutR * mmToPx;
    final double rDoubleIn = DartsK.doubleInR * mmToPx;
    final double rDoubleOut = DartsK.doubleOutR * mmToPx;
    final double rBoard = DartsK.boardR * mmToPx;

    // Colors
    const Color colorBlackSingle = Color(0xFF1E232F);
    const Color colorCreamSingle = Color(0xFFF6F0DC);
    const Color colorRed = Color(0xFFDC2626);
    const Color colorGreen = Color(0xFF16A34A);
    const Color colorSurround = Color(0xFF0F141C);
    const Color colorWire = Color(0xFFE2E8F0);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    // 1. Black board surround / number ring
    fillPaint.color = colorSurround;
    c.drawCircle(center, rBoard, fillPaint);

    // 2. 20 Radial segments & beds
    const double degToRad = math.pi / 180.0;
    const double sweepAngleRad = DartsK.segmentAngleDeg * degToRad; // 18 degrees

    for (int i = 0; i < DartsK.segmentOrder.length; i++) {
      final int segment = DartsK.segmentOrder[i];
      // Segment 20 (i=0) is centered at 12 o'clock (-90°): spans -99° to -81°
      final double startAngleRad = (-99.0 + (i * DartsK.segmentAngleDeg)) * degToRad;

      final bool isEven = i % 2 == 0;
      final Color singleColor = isEven ? colorBlackSingle : colorCreamSingle;
      final Color ringColor = isEven ? colorRed : colorGreen;

      // Bed 1: Outer double bed
      final Path doublePath = _buildAnnularSector(
        center,
        rDoubleIn,
        rDoubleOut,
        startAngleRad,
        sweepAngleRad,
      );
      fillPaint.color = ringColor;
      c.drawPath(doublePath, fillPaint);
      _flashPaths['D$segment'] = doublePath;

      // Bed 2: Outer single bed (fat single)
      final Path outerSinglePath = _buildAnnularSector(
        center,
        rTrebleOut,
        rDoubleIn,
        startAngleRad,
        sweepAngleRad,
      );
      fillPaint.color = singleColor;
      c.drawPath(outerSinglePath, fillPaint);
      _flashPaths['S${segment}_outer'] = outerSinglePath;

      // Bed 3: Treble bed
      final Path treblePath = _buildAnnularSector(
        center,
        rTrebleIn,
        rTrebleOut,
        startAngleRad,
        sweepAngleRad,
      );
      fillPaint.color = ringColor;
      c.drawPath(treblePath, fillPaint);
      _flashPaths['T$segment'] = treblePath;

      // Bed 4: Inner single bed
      final Path innerSinglePath = _buildAnnularSector(
        center,
        rOuterBull,
        rTrebleIn,
        startAngleRad,
        sweepAngleRad,
      );
      fillPaint.color = singleColor;
      c.drawPath(innerSinglePath, fillPaint);
      _flashPaths['S${segment}_inner'] = innerSinglePath;
    }

    // 3. Bulls
    // Outer bull: 25 pts (Green)
    final Path outerBullPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: rOuterBull))
      ..addOval(Rect.fromCircle(center: center, radius: rInnerBull))
      ..fillType = PathFillType.evenOdd;

    fillPaint.color = colorGreen;
    c.drawCircle(center, rOuterBull, fillPaint);
    _flashPaths['bull_outer'] = outerBullPath;

    // Inner bull: 50 pts (Red)
    final Path innerBullPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: rInnerBull));
    fillPaint.color = colorRed;
    c.drawCircle(center, rInnerBull, fillPaint);
    _flashPaths['bull_inner'] = innerBullPath;

    // 4. Thin silver spider wires
    final Paint wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = colorWire
      ..strokeWidth = math.max(1.2, rBoard * 0.006);

    // Concentric wire rings
    c.drawCircle(center, rInnerBull, wirePaint);
    c.drawCircle(center, rOuterBull, wirePaint);
    c.drawCircle(center, rTrebleIn, wirePaint);
    c.drawCircle(center, rTrebleOut, wirePaint);
    c.drawCircle(center, rDoubleIn, wirePaint);
    c.drawCircle(center, rDoubleOut, wirePaint);

    // 20 Radial wires
    for (int i = 0; i < DartsK.segmentOrder.length; i++) {
      final double wireAngleRad = (-99.0 + (i * DartsK.segmentAngleDeg)) * degToRad;
      final double cosA = math.cos(wireAngleRad);
      final double sinA = math.sin(wireAngleRad);

      c.drawLine(
        Offset(cx + rOuterBull * cosA, cy + rOuterBull * sinA),
        Offset(cx + rDoubleOut * cosA, cy + rDoubleOut * sinA),
        wirePaint,
      );
    }

    // Outer board boundary wire
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF475569)
      ..strokeWidth = math.max(1.5, rBoard * 0.008);
    c.drawCircle(center, rBoard, rimPaint);

    // 5. White regulation numbers around the surround
    _drawNumbers(c, center, (rDoubleOut + rBoard) * 0.5, mmToPx);

    _boardPicture = recorder.endRecording();
  }

  Path _buildAnnularSector(
    Offset center,
    double rIn,
    double rOut,
    double startAngleRad,
    double sweepAngleRad,
  ) {
    final Path path = Path();
    final Rect rectOut = Rect.fromCircle(center: center, radius: rOut);
    final Rect rectIn = Rect.fromCircle(center: center, radius: rIn);

    path.arcTo(rectOut, startAngleRad, sweepAngleRad, false);
    path.arcTo(rectIn, startAngleRad + sweepAngleRad, -sweepAngleRad, false);
    path.close();
    return path;
  }

  void _drawNumbers(Canvas c, Offset center, double numberRadiusPx, double mmToPx) {
    final double fontSize = (24.0 * mmToPx).clamp(12.0, 36.0);
    const double degToRad = math.pi / 180.0;

    for (int i = 0; i < DartsK.segmentOrder.length; i++) {
      final int segment = DartsK.segmentOrder[i];
      final double angleRad = (-90.0 + (i * DartsK.segmentAngleDeg)) * degToRad;

      final double nx = center.dx + (numberRadiusPx * math.cos(angleRad));
      final double ny = center.dy + (numberRadiusPx * math.sin(angleRad));

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '$segment',
          style: TextStyle(
            color: const Color(0xFFF8FAFC),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontFamily: 'Roboto',
            shadows: const [
              Shadow(
                color: Color(0x99000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(c, Offset(nx - (tp.width * 0.5), ny - (tp.height * 0.5)));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTime > 0.0) {
      _flashTime = math.max(0.0, _flashTime - dt);
      if (_flashTime == 0.0) {
        _activeFlashPath = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // 1. Draw static recorded board picture
    if (_boardPicture != null) {
      canvas.drawPicture(_boardPicture!);
    }

    // 2. Draw hit-area flash overlay
    if (_flashTime > 0.0 && _activeFlashPath != null) {
      final double alpha = (_flashTime / _flashDuration).clamp(0.0, 1.0) * 0.35;
      _flashPaint.color = const Color(DartsK.accentP1).withValues(alpha: alpha);
      canvas.drawPath(_activeFlashPath!, _flashPaint);
    }
  }

  @override
  void onRemove() {
    _boardPicture?.dispose();
    _boardPicture = null;
    _flashPaths.clear();
    super.onRemove();
  }
}
