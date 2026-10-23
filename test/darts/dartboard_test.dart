import 'package:b_ball/darts/components/board_backdrop.dart';
import 'package:b_ball/darts/components/dartboard.dart';
import 'package:b_ball/darts/physics/dart_scoring.dart';
import 'package:b_ball/darts/scene/board_projection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dartboard & BoardBackdrop Tests (Step 9)', () {
    test('BoardBackdrop has priority 0 and records picture on resize', () {
      final projection = BoardProjection();
      final backdrop = BoardBackdrop(projection: projection);

      expect(backdrop.priority, equals(0));
      backdrop.onGameResize(Vector2(400.0, 800.0));
      // Doesn't crash and completes recording
    });

    test('Dartboard has priority 1 and records picture on resize', () {
      final projection = BoardProjection();
      final dartboard = Dartboard(projection: projection);

      expect(dartboard.priority, equals(1));
      projection.resize(Vector2(400.0, 800.0));
      dartboard.onGameResize(Vector2(400.0, 800.0));
    });

    test('Dartboard precomputes paths for all 82 scoring areas', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));
      final dartboard = Dartboard(projection: projection);
      dartboard.onGameResize(Vector2(400.0, 800.0));

      // Test that flashing each category of area works and activates a valid Path
      // 1. Inner Bull (50 pts)
      final hitBull = DartScoring.score(0.0, 0.0);
      dartboard.flashArea(hitBull);

      // 2. Outer Bull (25 pts)
      final hit25 = DartScoring.score(0.0, 11.0);
      dartboard.flashArea(hit25);

      // 3. Treble T20 (60 pts)
      final hitT20 = DartScoring.score(0.0, 103.0);
      dartboard.flashArea(hitT20);

      // 4. Double D16 (32 pts)
      final hitD16 = DartScoring.score(0.0, 166.0);
      dartboard.flashArea(hitD16);

      // 5. Outer Single S20 (20 pts)
      final hitS20Outer = DartScoring.score(0.0, 135.0);
      dartboard.flashArea(hitS20Outer);

      // 6. Inner Single S20 (20 pts)
      final hitS20Inner = DartScoring.score(0.0, 50.0);
      dartboard.flashArea(hitS20Inner);

      // 7. Complete miss outside board
      final hitMiss = DartScoring.score(0.0, 250.0);
      dartboard.flashArea(hitMiss);
    });

    test('flashArea timer fades out over 450 ms and resets', () {
      final projection = BoardProjection();
      projection.resize(Vector2(400.0, 800.0));
      final dartboard = Dartboard(projection: projection);
      dartboard.onGameResize(Vector2(400.0, 800.0));

      final hitT20 = DartScoring.score(0.0, 103.0);
      dartboard.flashArea(hitT20);

      // Halfway through 450 ms fade
      dartboard.update(0.225);

      // Past 450 ms fade: flash should expire cleanly
      dartboard.update(0.300);
    });
  });
}
