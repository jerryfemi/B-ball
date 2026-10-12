import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../audio/audio_engine.dart';
import '../basketball_game.dart';
import 'match/match_setup_dialog.dart';

/// Frosted obsidian glass Pause Overlay displayed when mid-round action is paused.
class PauseOverlay extends HookWidget {
  final BasketballGame game;

  const PauseOverlay({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 260),
    );

    final scaleAnimation = useMemoized(
      () => Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(
          parent: animController,
          curve: Curves.easeOutBack,
        ),
      ),
      [animController],
    );

    final fadeAnimation = useMemoized(
      () => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animController,
          curve: Curves.easeOut,
        ),
      ),
      [animController],
    );

    useEffect(() {
      animController.forward();
      return null;
    }, const []);

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            constraints: const BoxConstraints(maxWidth: 360.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 26.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xF00F172A),
                        Color(0xFA090D16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28.0),
                    border: Border.all(
                      color: const Color(0x5538BDF8),
                      width: 1.4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 32.0,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Icon & Header Title
                      Container(
                        width: 52.0,
                        height: 52.0,
                        decoration: BoxDecoration(
                          color: const Color(0x2238BDF8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x6638BDF8),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.pause_rounded,
                          size: 30.0,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      const Text(
                        'GAME PAUSED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Color(0x8838BDF8),
                              blurRadius: 10.0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18.0),

                      // 2. Snapshot Metrics Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricChip(
                              label: 'SCORE',
                              value: '${game.scoreNotifier.value}',
                              color: const Color(0xFFFF4444),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: _buildMetricChip(
                              label: 'CLOCK',
                              value: '${game.timeRemainingNotifier.value}s',
                              color: const Color(0xFFFFE000),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: _buildMetricChip(
                              label: 'STREAK',
                              value: '${game.streakNotifier.value}',
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22.0),

                      // 3. Primary CTA: Resume Game
                      SizedBox(
                        width: double.infinity,
                        height: 48.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF22C55E),
                                Color(0xFF16A34A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4422C55E),
                                blurRadius: 12.0,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => game.resumeGame(),
                              borderRadius: BorderRadius.circular(16.0),
                              child: const Center(
                                child: Text(
                                  'RESUME GAME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0),

                      // 4. Secondary Action: Restart Round / Exit Match / 1v1 Setup
                      ValueListenableBuilder(
                        valueListenable: game.matchSessionNotifier,
                        builder: (context, session, _) {
                          final isMatch = session != null;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 42.0,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final config = await MatchSetupDialog.show(
                                      context,
                                      initialConfig: game.currentMatchConfig,
                                    );
                                    if (config != null) {
                                      game.startPassAndPlayMatch(config: config);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0x6638BDF8),
                                      width: 1.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                    backgroundColor: const Color(0x180284C7),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.tune_rounded,
                                        size: 16.0,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(
                                        isMatch ? 'MATCH SETTINGS' : 'START 1V1 MATCH',
                                        style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              SizedBox(
                                width: double.infinity,
                                height: 42.0,
                                child: OutlinedButton(
                                  onPressed: () {
                                    if (isMatch) {
                                      game.exitToSoloMode();
                                    } else {
                                      game.restartRound();
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0x4494A3B8),
                                      width: 1.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                    backgroundColor: const Color(0x1E334155),
                                  ),
                                  child: Text(
                                    isMatch ? 'EXIT MATCH TO SOLO' : 'RESTART ROUND',
                                    style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12.0),

                      // 5. Sound Quick-Toggle Pill
                      ValueListenableBuilder<bool>(
                        valueListenable: AudioEngine.isMutedNotifier,
                        builder: (context, isMuted, _) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: AudioEngine.toggleMute,
                              borderRadius: BorderRadius.circular(12.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      size: 16.0,
                                      color: isMuted
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6.0),
                                    Text(
                                      isMuted
                                          ? 'Sound: Muted (Tap to unmute)'
                                          : 'Sound: Enabled',
                                      style: TextStyle(
                                        color: isMuted
                                            ? const Color(0xFFFF6B6B)
                                            : const Color(0xFF94A3B8),
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      decoration: BoxDecoration(
        color: const Color(0x66060608),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0x28FFFFFF),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17.0,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
