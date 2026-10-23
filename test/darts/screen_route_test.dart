import 'package:flutter_test/flutter_test.dart';

import 'package:b_ball/darts/darts_constants.dart';
import 'package:b_ball/darts/darts_game_screen.dart';
import 'package:b_ball/darts/state/darts_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 15 — Darts Screen & Route Integration', () {
    test('DartsGameScreen instantiates cleanly with const constructor', () {
      const screen = DartsGameScreen();
      expect(screen.match, isNull);
    });

    test('DartsChallenge config matches official 301 match specifications', () {
      final config = DartsChallenge.config;
      expect(config.game, equals('darts'));
      expect(config.totalRounds, equals(DartsRules.maxRounds));
      expect(config.totalRounds, equals(DartsK.maxRounds));
      expect(config.roundDurationSeconds, equals(DartsRules.onlineTurnSeconds));
      expect(config.roundDurationSeconds, equals(90));
    });
  });
}
