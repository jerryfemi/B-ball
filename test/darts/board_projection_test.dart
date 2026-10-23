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

      // Center: (390 * 0.5, 844 * DartsK.boardCenterYFrac)
      expect(projection.boardCenterX, equals(195.0));
      expect(projection.boardCenterY, closeTo(844.0 * DartsK.boardCenterYFrac, 1e-4));
    });

    test('Board center (0, 0) mm projects to (centerX, centerY) px and inverts exactly', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));

      final outPx = Vector2.zero();
      projection.boardMmToScreen(0.0, 0.0, outPx);
      expect(outPx.x, equals(200.0)); // 400 * 0.5
      expect(outPx.y, equals(800.0 * DartsK.boardCenterYFrac));

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
      expect(outPx.y, closeTo(800.0 * DartsK.boardCenterYFrac - projection.boardRadiusPx, 1e-4));

      final outMm = Vector2.zero();
      projection.screenToBoardMm(outPx.x, outPx.y, outMm);
      expect(outMm.x.abs(), lessThan(1e-4));
      expect(outMm.y, closeTo(DartsK.boardR, 1e-4));
    });

    test('The camera draws the board plane exactly like the 2D mapping', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));
      final outPx = Vector2.zero();
      for (final (x, y) in [(0.0, 0.0), (0.0, 103.0), (-150.0, 40.0)]) {
        projection.boardMmToScreen(x, y, outPx);
        projection.project(x / 1000.0, y / 1000.0, 0.0);
        expect(projection.outX, closeTo(outPx.x, 1e-6));
        expect(projection.outY, closeTo(outPx.y, 1e-6));
      }
    });

    test('A dart released at bull height appears at the hand spot', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));
      projection.project(0.0, 0.0, DartsK.throwDistanceM);
      expect(projection.outX, closeTo(projection.handX, 1e-6));
      expect(projection.outY, closeTo(800.0 * DartsK.handTipFrac, 1e-6));
      // and unproject inverts it
      projection.unproject(projection.handX, projection.handY, DartsK.throwDistanceM);
      expect(projection.outX.abs(), lessThan(1e-9));
      expect(projection.outY.abs(), lessThan(1e-9));
    });

    test('Perspective: the same length looks much bigger in hand than on the board', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));
      double pxPerMetre(double z) {
        projection.project(0.0, 0.0, z);
        final double a = projection.outX;
        projection.project(0.1, 0.0, z);
        return (projection.outX - a) / 0.1;
      }

      final double hand = pxPerMetre(DartsK.throwDistanceM);
      final double board = pxPerMetre(0.0);
      expect(board, closeTo(projection.mmToPx * 1000.0, 1e-6));
      expect(hand / board, closeTo(projection.eyeZ / DartsK.releaseDepthM, 1e-6));
      expect(hand, greaterThan(board * 3.0));
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
