import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'archery_game.dart';
import 'audio/archery_audio.dart';
import 'state/archery_match_notifier.dart';
import 'ui/archery_hud.dart';

/// Full-screen Archery game view mounted via GoRouter or standalone runner.
class ArcheryGameScreen extends HookConsumerWidget {
  const ArcheryGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArcheryGame game = useMemoized(
      () => ArcheryGame(events: ref.read(archeryMatchProvider.notifier)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Flame 3D Archery Game Canvas with its isolated touch Listener
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                ArcheryAudio.unlock();
                game.controller.onPointerDown(
                  event.pointer,
                  event.localPosition.dx,
                  event.localPosition.dy,
                );
              },
              onPointerMove: (event) {
                game.controller.onPointerMove(
                  event.pointer,
                  event.localPosition.dx,
                  event.localPosition.dy,
                );
              },
              onPointerUp: (event) {
                ArcheryAudio.unlock();
                game.controller.onPointerUp(event.pointer);
              },
              onPointerCancel: (_) {
                game.controller.onPointerCancel();
              },
              child: GameWidget(game: game),
            ),

            // 2. The Flutter Luxury Obsidian HUD Overlay (on top of canvas)
            ArcheryHud(game: game),

            // 3. Lobby Return Button in top-left
            Positioned(
              top: 8.0,
              left: 14.0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/games');
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0A0E1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x33FFFFFF), width: 1.0),
                      boxShadow: const [
                        BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view_rounded, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 5),
                        Text(
                          'LOBBY',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
