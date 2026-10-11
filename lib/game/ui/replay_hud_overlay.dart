import 'dart:ui';
import 'package:flutter/material.dart';

import '../basketball_game.dart';

/// Floating HUD controls displayed while spectator replay mode is active.
///
/// Features:
/// 1. Frosted obsidian glass banner with metallic boundary
/// 2. Clear "REPLAYING ROUND" indicator
/// 3. Immediate Exit and Play Again triggers so the user never feels trapped
class ReplayHudOverlay extends StatelessWidget {
  final BasketballGame game;

  const ReplayHudOverlay({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xE60F172A),
                      Color(0xF0090D16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: const Color(0x38FFFFFF),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20.0,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x2238BDF8),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: const Color(0x6638BDF8),
                          width: 1.0,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 16.0,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 6.0),
                          Text(
                            'REPLAY',
                            style: TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    // Exit replay button
                    OutlinedButton(
                      onPressed: () => game.stopReplayMode(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(
                          color: Color(0x38FFFFFF),
                          width: 1.0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 16.0),
                          SizedBox(width: 4.0),
                          Text(
                            'EXIT',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    // Play Again button
                    ElevatedButton(
                      onPressed: () => game.restartRound(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 16.0),
                          SizedBox(width: 4.0),
                          Text(
                            'PLAY',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
