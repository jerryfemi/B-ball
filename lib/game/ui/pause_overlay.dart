import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../audio/audio_engine.dart';
import '../basketball_game.dart';
import '../match/match_session.dart';
import '../performance/adaptive_quality.dart';
import '../physics/shot_difficulty.dart';
import 'common/difficulty_stepped_slider.dart';

/// Frosted obsidian glass Pause Overlay displayed when mid-round action is paused.
class PauseOverlay extends HookWidget {
  final BasketballGame game;

  const PauseOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 260),
    );

    final scaleAnimation = useMemoized(
      () => Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(parent: animController, curve: Curves.easeOutBack),
      ),
      [animController],
    );

    final fadeAnimation = useMemoized(
      () => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animController, curve: Curves.easeOut)),
      [animController],
    );

    final isSettingsExpanded = useState<bool>(false);

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
            margin: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
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
                    colors: [Color(0xF00F172A), Color(0xFA090D16)],
                  ),
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: const Color(0x5538BDF8),
                    width: 1.4,
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22.0,
                    vertical: 22.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Icon & Header Title
                      Container(
                        width: 44.0,
                        height: 44.0,
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
                          size: 24.0,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'GAME PAUSED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 14.0),

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
                      const SizedBox(height: 16.0),

                      // 3. Primary CTA: Resume Game
                      SizedBox(
                        width: double.infinity,
                        height: 46.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            ),
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => game.resumeGame(),
                              borderRadius: BorderRadius.circular(14.0),
                              child: const Center(
                                child: Text(
                                  'RESUME GAME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // 4. Mode-Dependent Section (1v1 Match vs Solo Play)
                      ValueListenableBuilder<MatchSession?>(
                        valueListenable: game.matchSessionNotifier,
                        builder: (context, session, _) {
                          final isMatch = session != null;
                          if (isMatch) {
                            return _buildMatchForfeitSection(context, session);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Solo Action: Restart Round
                              SizedBox(
                                width: double.infinity,
                                height: 40.0,
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
                                        size: 15.0,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      SizedBox(width: 8.0),
                                      Text(
                                        'RESTART ROUND',
                                        style: TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14.0),

                              // Difficulty Stepped Slider
                              ValueListenableBuilder<ShotDifficulty>(
                                valueListenable: game.soloDifficultyNotifier,
                                builder: (context, currentDiff, _) {
                                  return DifficultySteppedSlider(
                                    value: currentDiff,
                                    onChanged: (newDiff) {
                                      game.soloDifficultyNotifier.value =
                                          newDiff;
                                    },
                                    title: 'SOLO DIFFICULTY',
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14.0),

                      // 5. Option A: Collapsible Audio & Visual Settings Tray
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: const Color(0x3338BDF8),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Collapsible Tray Header
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  isSettingsExpanded.value =
                                      !isSettingsExpanded.value;
                                },
                                borderRadius: BorderRadius.circular(16.0),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                    vertical: 10.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.tune_rounded,
                                        size: 16.0,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 8.0),
                                      const Text(
                                        'AUDIO & EFFECTS SETTINGS',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      AnimatedRotation(
                                        turns: isSettingsExpanded.value
                                            ? 0.5
                                            : 0.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        child: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18.0,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Expandable Settings Content
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(
                                  left: 14.0,
                                  right: 14.0,
                                  bottom: 12.0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Divider(
                                      color: Color(0x2238BDF8),
                                      height: 1.0,
                                    ),
                                    const SizedBox(height: 8.0),
                                    // The speaker button switches each sound
                                    // off entirely: OFF never downloads
                                    // (music) or decodes (effects) at all.
                                    _VolumeSliderRow(
                                      label: 'SFX',
                                      notifier: AudioEngine.sfxVolumeNotifier,
                                      enabledNotifier:
                                          AudioEngine.sfxEnabledNotifier,
                                      onToggle: AudioEngine.setSfxEnabled,
                                      onChanged: (val) =>
                                          AudioEngine.sfxVolume = val,
                                    ),
                                    const SizedBox(height: 4.0),
                                    _VolumeSliderRow(
                                      label: 'MUSIC',
                                      notifier: AudioEngine.musicVolumeNotifier,
                                      enabledNotifier:
                                          AudioEngine.musicEnabledNotifier,
                                      onToggle: AudioEngine.setMusicEnabled,
                                      onChanged: (val) =>
                                          AudioEngine.musicVolume = val,
                                    ),
                                    const SizedBox(height: 6.0),
                                    _DisabledWhenOff(
                                      notifier:
                                          AudioEngine.musicEnabledNotifier,
                                      child: _buildTrackSelector(),
                                    ),
                                    const Divider(
                                      color: Color(0x2238BDF8),
                                      height: 14.0,
                                    ),
                                    _buildStreakFxRow(),
                                    const Divider(
                                      color: Color(0x2238BDF8),
                                      height: 14.0,
                                    ),
                                    _buildGraphicsQualityRow(),
                                  ],
                                ),
                              ),
                              crossFadeState: isSettingsExpanded.value
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 240),
                              sizeCurve: Curves.easeInOutCubic,
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

  Widget _buildTrackSelector() {
    return ValueListenableBuilder<int>(
      valueListenable: AudioEngine.currentTrackIndexNotifier,
      builder: (context, selectedIdx, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1538BDF8),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: const Color(0x3338BDF8),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 2.0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.queue_music_rounded,
                  size: 15.0,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'TRACK',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: const Color(0xFF0F172A),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedIdx.clamp(
                          0,
                          AudioEngine.availableTracks.length - 1,
                        ),
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12.0),
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Color(0xFF38BDF8),
                          size: 20.0,
                        ),
                        items: List.generate(
                          AudioEngine.availableTracks.length,
                          (index) {
                            final track = AudioEngine.availableTracks[index];
                            final isSelected = index == selectedIdx;
                            return DropdownMenuItem<int>(
                              value: index,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6.0),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 13.0,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      'Track ${index + 1}: ${track.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFFE2E8F0),
                                        fontSize: 10.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        onChanged: (newIndex) {
                          if (newIndex != null) {
                            AudioEngine.selectTrack(newIndex);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakFxRow() {
    return ValueListenableBuilder<bool>(
      valueListenable: game.streakFxEnabledNotifier,
      builder: (context, enabled, _) {
        return Row(
          children: [
            Container(
              width: 28.0,
              height: 28.0,
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0x22F97316)
                    : const Color(0x1E334155),
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled
                      ? const Color(0x66F97316)
                      : const Color(0x3394A3B8),
                  width: 1.0,
                ),
              ),
              child: Icon(
                enabled
                    ? Icons.local_fire_department_rounded
                    : Icons.flash_off_rounded,
                size: 15.0,
                color: enabled
                    ? const Color(0xFFF97316)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BALL STREAK FX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 1.0),
                  Text(
                    enabled
                        ? '⚡ Lightning (3+) & 🔥 Fire (6+)'
                        : 'Disabled (Saves battery)',
                    style: TextStyle(
                      color: enabled
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF64748B),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (_) {
                HapticFeedback.selectionClick();
                unawaited(game.toggleStreakFx());
              },
              activeThumbColor: const Color(0xFF38BDF8),
              activeTrackColor: const Color(0x6638BDF8),
              inactiveThumbColor: const Color(0xFF64748B),
              inactiveTrackColor: const Color(0x33334155),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        );
      },
    );
  }

  /// GRAPHICS: HIGH / LOW (default LOW). LOW only switches the ball to smooth
  /// leather; every other effect is identical on both.
  Widget _buildGraphicsQualityRow() {
    return ValueListenableBuilder<QualityMode>(
      valueListenable: game.quality.modeNotifier,
      builder: (context, mode, _) {
        return Builder(
          builder: (context) {
            final subtitle = switch (mode) {
              QualityMode.high => 'Detailed pebbled ball texture',
              QualityMode.low => 'Smooth ball • lighter on your phone',
            };
            final accent = mode == QualityMode.low
                ? const Color(0xFF94A3B8)
                : const Color(0xFF00FFCC);
            return Row(
              children: [
                Container(
                  width: 28.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    mode == QualityMode.high
                        ? Icons.high_quality_rounded
                        : Icons.battery_saver_rounded,
                    size: 15.0,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GRAPHICS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 1.0),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999.0),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    unawaited(game.quality.cycleMode());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(color: accent, width: 1.0),
                    ),
                    child: Text(
                      mode.label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
        border: Border.all(color: const Color(0x28FFFFFF), width: 1.0),
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

  Widget _buildMatchForfeitSection(BuildContext context, MatchSession session) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: const Color(0x180284C7),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: const Color(0x4438BDF8), width: 1.0),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_basketball_rounded,
                size: 15.0,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8.0),
              Text(
                '1V1 MATCH IN PROGRESS',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10.0),
        SizedBox(
          width: double.infinity,
          height: 44.0,
          child: OutlinedButton.icon(
            onPressed: () => _showForfeitConfirmationDialog(context, session),
            icon: const Icon(
              Icons.flag_outlined,
              size: 16.0,
              color: Color(0xFFEF4444),
            ),
            label: const Text(
              'FORFEIT MATCH',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                width: 1.2,
              ),
              backgroundColor: const Color(0x15EF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showForfeitConfirmationDialog(
    BuildContext context,
    MatchSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161822),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 24.0,
            ),
            SizedBox(width: 10.0),
            Text(
              'Forfeit Match?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: const Text(
          'Leaving mid-game will forfeit this match and award the victory to your opponent. Are you sure you want to forfeit?',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'CONFIRM FORFEIT',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      final myUid = AuthService.instance.currentUser?.uid ?? '';
      final cloudMatchId = session.cloudMatchId;
      final opponent = session.player2;

      if (cloudMatchId != null && myUid.isNotEmpty) {
        unawaited(
          FirestoreMatchService.instance.forfeitMatch(
            matchId: cloudMatchId,
            forfeiterUid: myUid,
            winnerUid: opponent.id.isNotEmpty && opponent.id != 'them'
                ? opponent.id
                : '',
          ),
        );
      }

      // The explicit CONFIRM FORFEIT dialog is the confirmation; returning to
      // the court is the outcome — no floating SnackBar.
      game.exitToSoloMode();
    }
  }
}

class _VolumeSliderRow extends StatelessWidget {
  const _VolumeSliderRow({
    required this.label,
    required this.notifier,
    required this.enabledNotifier,
    required this.onToggle,
    required this.onChanged,
  });

  final String label;
  final ValueNotifier<double> notifier;
  final ValueNotifier<bool> enabledNotifier;
  final Future<void> Function(bool enabled) onToggle;
  final ValueChanged<double> onChanged;

  static const Color _onColor = Color(0xFF38BDF8);
  static const Color _offColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabledNotifier,
      builder: (context, isOn, _) {
        return ValueListenableBuilder<double>(
          valueListenable: notifier,
          builder: (context, volume, _) {
            return Row(
              children: [
                // Speaker button: tap to switch this sound fully on/off.
                InkResponse(
                  radius: 18.0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    unawaited(onToggle(!isOn));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28.0,
                    height: 28.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isOn ? _onColor : _offColor).withValues(
                        alpha: 0.12,
                      ),
                      border: Border.all(
                        color: (isOn ? _onColor : _offColor).withValues(
                          alpha: 0.55,
                        ),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      isOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      size: 15.0,
                      color: isOn ? _onColor : _offColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                SizedBox(
                  width: 46.0,
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
                  child: IgnorePointer(
                    ignoring: !isOn,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: isOn ? 1.0 : 0.35,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          activeTrackColor: _onColor,
                          inactiveTrackColor: const Color(0x3338BDF8),
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0,
                            pressedElevation: 4.0,
                          ),
                          overlayColor: const Color(0x3338BDF8),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12.0,
                          ),
                        ),
                        child: Slider(
                          value: volume.clamp(0.0, 1.0),
                          min: 0.0,
                          max: 1.0,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32.0,
                  child: Text(
                    isOn ? '${(volume * 100).round()}%' : 'OFF',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isOn ? const Color(0xFFE2E8F0) : _offColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
/// Dims and locks a settings row while its sound category is switched off.
class _DisabledWhenOff extends StatelessWidget {
  final ValueNotifier<bool> notifier;
  final Widget child;

  const _DisabledWhenOff({required this.notifier, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, isOn, child) => IgnorePointer(
        ignoring: !isOn,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isOn ? 1.0 : 0.35,
          child: child,
        ),
      ),
      child: child,
    );
  }
}
