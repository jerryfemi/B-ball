import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:b_ball/darts/ui/darts_hud.dart';
import 'package:b_ball/darts/ui/darts_pause_menu.dart';
import 'package:b_ball/darts/ui/darts_tour.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 14 — Darts HUD, Pause Menu & Tour', () {
    test('DartsTour prefKey and shouldShow logic', () async {
      SharedPreferences.setMockInitialValues({});

      expect(DartsTour.prefKey, equals('darts_tour_seen_v1'));

      final firstShow = await DartsTour.shouldShow();
      expect(firstShow, isTrue, reason: 'First check must show tour on new device');

      final secondShow = await DartsTour.shouldShow();
      expect(secondShow, isFalse, reason: 'Subsequent check must not show tour');
    });

    testWidgets('DartsHud renders round and score badge elements', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DartsHud(
                onOpenPause: () {},
              ),
            ),
          ),
        ),
      );

      // Verify Round text
      expect(find.textContaining('ROUND 1/'), findsOneWidget);

      // Verify remaining scores start at 301
      expect(find.text('301'), findsNWidgets(2));

      // Verify pause icon
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('DartsPauseMenu displays audio controls and action buttons', (tester) async {
      bool resumed = false;
      bool restarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DartsPauseMenu(
              online: false,
              onResume: () => resumed = true,
              onHowToPlay: () {},
              onRestart: () => restarted = true,
              onLobby: () {},
            ),
          ),
        ),
      );

      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('MUSIC'), findsOneWidget);
      expect(find.text('SOUND EFFECTS'), findsOneWidget);
      expect(find.text('PUB AMBIENCE'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('HOW TO PLAY'), findsOneWidget);
      expect(find.text('RESTART MATCH'), findsOneWidget);
      expect(find.text('EXIT TO LOBBY'), findsOneWidget);

      await tester.tap(find.text('RESUME'));
      expect(resumed, isTrue);

      await tester.tap(find.text('RESTART MATCH'));
      expect(restarted, isTrue);
    });

    testWidgets('DartsTour cycles through all 4 cards and completes', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DartsTour(
              onDone: () => completed = true,
            ),
          ),
        ),
      );

      // Card 1: HOLD TO AIM
      expect(find.text('HOLD TO AIM'), findsOneWidget);
      expect(find.text('HOW TO PLAY · 1/4'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Card 2: FLICK TO THROW
      expect(find.text('FLICK TO THROW'), findsOneWidget);
      expect(find.text('HOW TO PLAY · 2/4'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Card 3: 301 TO ZERO
      expect(find.text('301 TO ZERO'), findsOneWidget);
      expect(find.text('HOW TO PLAY · 3/4'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Card 4: PLAY A FRIEND & attribution
      expect(find.text('PLAY A FRIEND'), findsOneWidget);
      expect(find.text('HOW TO PLAY · 4/4'), findsOneWidget);
      expect(find.textContaining('oxxycodone'), findsOneWidget);
      expect(find.text('LET’S PLAY'), findsOneWidget);

      await tester.tap(find.text('LET’S PLAY'));
      expect(completed, isTrue);
    });
  });
}
