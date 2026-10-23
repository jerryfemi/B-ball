import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'darts/darts_constants.dart';
import 'darts/darts_game.dart';
import 'darts/state/darts_match_notifier.dart';
import 'darts/ui/darts_hud.dart';
import 'darts/ui/darts_pause_menu.dart';
import 'darts/ui/darts_result_card.dart';
import 'darts/ui/darts_tour.dart';
import 'darts/ui/darts_turn_banner.dart';
import 'game/audio/audio_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(AudioEngine.init());

  // Portrait orientation for smartphone darts
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: DartsDevApp(),
    ),
  );
}

/// Standalone Darts 301 application harness (DARTS_PLAN.md Step 8 & Step 10).
///
/// Completely decoupled from Firebase, basketball match models, and main.dart.
class DartsDevApp extends StatelessWidget {
  const DartsDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AudioEngine.unlockAudio(),
      onPointerUp: (_) => AudioEngine.unlockAudio(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        title: 'Darts 301 Prototype',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(DartsK.surfaceDark),
          fontFamily: 'Roboto',
        ),
        home: const DartsHarnessScreen(),
      ),
    );
  }
}

/// Standalone harness screen hosting [DartsGame] with keyboard and debug trigger buttons.
class DartsHarnessScreen extends ConsumerStatefulWidget {
  const DartsHarnessScreen({super.key});

  @override
  ConsumerState<DartsHarnessScreen> createState() => _DartsHarnessScreenState();
}

class _DartsHarnessScreenState extends ConsumerState<DartsHarnessScreen> {
  DartsGame? _game;
  final FocusNode _focusNode = FocusNode();
  bool _isPaused = false;
  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    DartsTour.shouldShow().then((show) {
      if (mounted && show) {
        setState(() => _showTour = true);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _throwP1Bull() {
    _game?.throwDebugDart(player: 0, targetMmX: 0.0, targetMmY: 0.0);
  }

  void _throwP2T20() {
    _game?.throwDebugDart(player: 1, targetMmX: 0.0, targetMmY: 103.0);
  }

  void _throwP1D16() {
    // D16 is on the left at 9 o'clock (162 mm)
    _game?.throwDebugDart(player: 0, targetMmX: -166.0, targetMmY: 0.0);
  }

  void _pullDarts() {
    _game?.pullDarts();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.read(dartsMatchProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(DartsK.surfaceDark),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.digit1) {
              _throwP1Bull();
            } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
              _throwP2T20();
            } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
              _throwP1D16();
            } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
              _pullDarts();
            }
          }
        },
        child: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => _game?.onPointerDown(
                event.pointer,
                event.position.dx,
                event.position.dy,
              ),
              onPointerMove: (event) => _game?.onPointerMove(
                event.pointer,
                event.position.dx,
                event.position.dy,
              ),
              onPointerUp: (event) => _game?.onPointerUp(event.pointer),
              onPointerCancel: (_) => _game?.onPointerCancel(),
              child: GameWidget<DartsGame>.controlled(
                gameFactory: () {
                  final game = DartsGame(events: events);
                  _game = game;
                  return game;
                },
              ),
            ),
            // Full Darts HUD (Remaining scores, Round, Darts Left, Pause Button)
            Positioned.fill(
              child: DartsHud(
                onOpenPause: () {
                  _game?.flickController.onPointerCancel();
                  setState(() => _isPaused = true);
                },
              ),
            ),
            // Turn transition banner (Round N / Bot's Turn / Last Chance)
            const Positioned.fill(
              child: DartsTurnBanner(),
            ),
            // Match result card (Victory / Defeat / Draw with Rematch)
            Positioned.fill(
              child: DartsResultCard(
                onRematch: () => _game?.restartGame(),
              ),
            ),
            // Pause Menu Modal Sheet
            if (_isPaused)
              Positioned.fill(
                child: DartsPauseMenu(
                  online: false,
                  onResume: () => setState(() => _isPaused = false),
                  onHowToPlay: () => setState(() {
                    _isPaused = false;
                    _showTour = true;
                  }),
                  onRestart: () {
                    setState(() => _isPaused = false);
                    _game?.restartGame();
                  },
                  onLobby: () => setState(() => _isPaused = false),
                ),
              ),
            // How To Play Walkthrough Tour
            if (_showTour)
              Positioned.fill(
                child: DartsTour(
                  onDone: () => setState(() => _showTour = false),
                ),
              ),
            // Debug controls overlay at bottom of screen
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DebugChip(
                      label: 'P1 Bull [Space]',
                      color: const Color(DartsK.accentP1),
                      onPressed: _throwP1Bull,
                    ),
                    const SizedBox(width: 8),
                    _DebugChip(
                      label: 'P2 T20 [2]',
                      color: const Color(DartsK.accentP2),
                      onPressed: _throwP2T20,
                    ),
                    const SizedBox(width: 8),
                    _DebugChip(
                      label: 'P1 D16 [3]',
                      color: const Color(DartsK.accentMint),
                      onPressed: _throwP1D16,
                    ),
                    const SizedBox(width: 8),
                    _DebugChip(
                      label: 'Pull [C]',
                      color: const Color(DartsK.textMuted),
                      onPressed: _pullDarts,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _DebugChip({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(DartsK.surfaceCard).withValues(alpha: 0.85),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
