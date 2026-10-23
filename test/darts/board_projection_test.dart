import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/scene/board_projection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('BoardProjection Tests (Step 8)', () {
    test('Resizing calculates board dimensions and centers accurately', () {
      final projection = BoardProjection();
      // Standard mobile viewport: 390 x 844
      projection.resize(Vector2(390.0, 844.0));

      expect(projection.screenWidth, equals(390.0));
      expect(projection.screenHeight, equals(844.0));

      // refW = min(390, 844 * 0.62) = min(390, 523.28) = 390.0
      expect(projection.refW, equals(390.0));

      // boardDiameterPx = 390.0 * 0.92 = 358.8
      expect(projection.boardDiameterPx, closeTo(358.8, 1e-4));
      expect(projection.boardRadiusPx, closeTo(179.4, 1e-4));

      // Center: (390 * 0.5, 844 * 0.40) = (195.0, 337.6)
      expect(projection.boardCenterX, equals(195.0));
      expect(projection.boardCenterY, closeTo(337.6, 1e-4));
    });

    test('Board center (0, 0) mm projects to (centerX, centerY) px and inverts exactly', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));

      final outPx = Vector2.zero();
      projection.boardMmToScreen(0.0, 0.0, outPx);
      expect(outPx.x, equals(200.0)); // 400 * 0.5
      expect(outPx.y, equals(320.0)); // 800 * 0.40

      final outMm = Vector2.zero();
      projection.screenToBoardMm(outPx.x, outPx.y, outMm);
      expect(outMm.x.abs(), lessThan(1e-4));
      expect(outMm.y.abs(), lessThan(1e-4));
    });

    test('Top of board outer radius (0, 225.5) mm projects to top edge of board', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));

      final outPx = Vector2.zero();
      projection.boardMmToScreen(0.0, DartsK.boardR, outPx);
      expect(outPx.x, equals(200.0));
      expect(outPx.y, closeTo(320.0 - projection.boardRadiusPx, 1e-4));

      final outMm = Vector2.zero();
      projection.screenToBoardMm(outPx.x, outPx.y, outMm);
      expect(outMm.x.abs(), lessThan(1e-4));
      expect(outMm.y, closeTo(DartsK.boardR, 1e-4));
    });

    test('Perspective depthScale is ~1.0 at release and ~0.15 at board plane', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));

      final double releaseScale = projection.depthScale(DartsK.throwDistanceM); // 2.37 m
      final double boardScale = projection.depthScale(0.0); // 0.0 m

      expect(releaseScale, closeTo(1.0, 0.01));
      expect(boardScale, closeTo(0.15, 0.02));
      expect(boardScale, lessThan(releaseScale));
    });

    test('Resizing to wide and narrow screens does not crash or produce NaN', () {
      final projection = BoardProjection();

      // Extreme portrait
      projection.resize(Vector2(320.0, 900.0));
      expect(projection.mmToPx.isNaN, isFalse);
      expect(projection.pxToMm.isNaN, isFalse);

      // Tablet / square
      projection.resize(Vector2(800.0, 800.0));
      expect(projection.mmToPx.isNaN, isFalse);

      // Desktop landscape
      projection.resize(Vector2(1920.0, 1080.0));
      expect(projection.refW, closeTo(1080.0 * DartsK.refAspect, 1e-4));
      expect(projection.mmToPx > 0.0, isTrue);
    });
  });
}
