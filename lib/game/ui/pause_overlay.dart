import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../audio/audio_engine.dart';
import '../basketball_game.dart';
import '../physics/shot_difficulty.dart';

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

    final screenHeight = MediaQuery.sizeOf(context).height;

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            constraints: BoxConstraints(
              maxWidth: 360.0,
              maxHeight: screenHeight * 0.90,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.0),
              child: Container(
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 26.0,
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
                      const SizedBox(height: 14.0),

                      // 4. Solo Difficulty Selector (Active only during Solo Play)
                      ValueListenableBuilder(
                        valueListenable: game.matchSessionNotifier,
                        builder: (context, session, _) {
                          final isMatch = session != null;
                          if (isMatch) {
                            // In 1v1 match: Strict lock-in to prevent cheating/dodging.
                            // Players cannot restart round or exit mid-turn.
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 10.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x180284C7),
                                borderRadius: BorderRadius.circular(14.0),
                                border: Border.all(
                                  color: const Color(0x4438BDF8),
                                  width: 1.0,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 15.0,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  SizedBox(width: 8.0),
                                  Text(
                                    '1V1 TURN IN PROGRESS • FINISH ROUND',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Difficulty Preset selector
                              ValueListenableBuilder<ShotDifficulty>(
                                valueListenable: game.soloDifficultyNotifier,
                                builder: (context, currentDiff, _) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SOLO DIFFICULTY',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6.0),
                                      Row(
                                        children: ShotDifficulty.values.map((diff) {
                                          final isSel = currentDiff == diff;
                                          return Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 2.5,
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  game.soloDifficultyNotifier.value =
                                                      diff;
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 7.0,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSel
                                                        ? const Color(0xFF1E293B)
                                                        : const Color(0x661E2638),
                                                    borderRadius:
                                                        BorderRadius.circular(10.0),
                                                    border: Border.all(
                                                      color: isSel
                                                          ? const Color(0xFF38BDF8)
                                                          : const Color(0xFF334155),
                                                      width: isSel ? 1.4 : 1.0,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        diff.emoji,
                                                        style: const TextStyle(
                                                          fontSize: 13.0,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 1.0),
                                                      Text(
                                                        diff.label,
                                                        style: TextStyle(
                                                          color: isSel
                                                              ? const Color(0xFF38BDF8)
                                                              : const Color(0xFFCBD5E1),
                                                          fontSize: 10.0,
                                                          fontWeight: isSel
                                                              ? FontWeight.w900
                                                              : FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12.0),

                              // Solo Action: Restart Round
                              SizedBox(
                                width: double.infinity,
                                height: 42.0,
                                child: OutlinedButton(
                                  onPressed: () => game.restartRound(),
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
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.replay_rounded,
                                        size: 16.0,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      SizedBox(width: 8.0),
                                      Text(
                                        'RESTART ROUND',
                                        style: TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14.0),

                      // 5. Audio Settings Card: SFX & Music Sliders + Mute Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: const Color(0x3338BDF8),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            _VolumeSliderRow(
                              icon: Icons.sports_basketball_rounded,
                              label: 'SFX',
                              notifier: AudioEngine.sfxVolumeNotifier,
                              onChanged: (val) => AudioEngine.sfxVolume = val,
                            ),
                            const SizedBox(height: 6.0),
                            _VolumeSliderRow(
                              icon: Icons.music_note_rounded,
                              label: 'MUSIC',
                              notifier: AudioEngine.musicVolumeNotifier,
                              onChanged: (val) => AudioEngine.musicVolume = val,
                            ),
                            const SizedBox(height: 8.0),
                            const Divider(color: Color(0x2238BDF8), height: 1.0),
                            const SizedBox(height: 6.0),
                            ValueListenableBuilder<bool>(
                              valueListenable: AudioEngine.isMutedNotifier,
                              builder: (context, isMuted, _) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: AudioEngine.toggleMute,
                                    borderRadius: BorderRadius.circular(10.0),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isMuted
                                                ? Icons.volume_off_rounded
                                                : Icons.volume_up_rounded,
                                            size: 15.0,
                                            color: isMuted
                                                ? const Color(0xFFFF6B6B)
                                                : const Color(0xFF38BDF8),
                                          ),
                                          const SizedBox(width: 6.0),
                                          Text(
                                            isMuted ? 'Muted (Tap to Unmute)' : 'Sound On',
                                            style: TextStyle(
                                              color: isMuted
                                                  ? const Color(0xFFFF6B6B)
                                                  : const Color(0xFF94A3B8),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
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

class _VolumeSliderRow extends StatelessWidget {
  const _VolumeSliderRow({
    required this.icon,
    required this.label,
    required this.notifier,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final ValueNotifier<double> notifier;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, volume, _) {
        return Row(
          children: [
            Icon(
              icon,
              size: 15.0,
              color: const Color(0xFF38BDF8),
            ),
            const SizedBox(width: 8.0),
            SizedBox(
              width: 50.0,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  activeTrackColor: const Color(0xFF38BDF8),
                  inactiveTrackColor: const Color(0x3338BDF8),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6.0,
                    pressedElevation: 4.0,
                  ),
                  overlayColor: const Color(0x3338BDF8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12.0),
                ),
                child: Slider(
                  value: volume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 32.0,
              child: Text(
                '${(volume * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
