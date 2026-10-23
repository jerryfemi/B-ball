import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/audio/audio_engine.dart';
import '../darts_constants.dart';

/// Darts pause menu: audio settings (music, sound effects, ambience),
/// how-to-play tour, resume, solo restart, and lobby exit.
///
/// Built according to Apple Design standards:
/// - Translucent frosted glass material with specular rim lighting.
/// - Optical typography scale with negative tracking on headings.
/// - Instant pointer-down press feedback (scale 0.96, haptic impact).
/// - Non-blocking solo pause / live clock notice for online play.
class DartsPauseMenu extends StatelessWidget {
  final bool online;
  final VoidCallback onResume;
  final VoidCallback onHowToPlay;
  final VoidCallback? onRestart;
  final VoidCallback onLobby;

  const DartsPauseMenu({
    super.key,
    required this.online,
    required this.onResume,
    required this.onHowToPlay,
    required this.onLobby,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 1. Full-screen blur backdrop (tap outside to resume) ─────────────
        Positioned.fill(
          child: GestureDetector(
            onTap: onResume,
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
              child: const ColoredBox(
                color: Color(0x99060913),
              ),
            ),
          ),
        ),

        // ── 2. Centered Frosted Glass Sheet ──────────────────────────────────
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.fromLTRB(22.0, 20.0, 22.0, 22.0),
              decoration: BoxDecoration(
                color: const Color(0xF00F172A),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: const Color(0x33FFFFFF),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xD9000000),
                    blurRadius: 36.0,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Text(
                      'PAUSED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.0,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Inter',
                        fontVariations: [FontVariation('wght', 900)],
                        letterSpacing: 2.0,
                      ),
                    ),
                    if (online) ...[
                      const SizedBox(height: 5.0),
                      const Text(
                        'LIVE MATCH · SHOT CLOCK IS RUNNING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(DartsK.accentP2),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                          fontVariations: [FontVariation('wght', 800)],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18.0),

                    // ── Audio Controls ───────────────────────────────────────
                    _AudioRow(
                      icon: Icons.music_note_rounded,
                      label: 'MUSIC',
                      enabled: AudioEngine.musicEnabledNotifier,
                      volume: AudioEngine.musicVolumeNotifier,
                      onEnabled: AudioEngine.setMusicEnabled,
                      onVolume: (v) => AudioEngine.musicVolume = v,
                    ),
                    const SizedBox(height: 10.0),
                    _AudioRow(
                      icon: Icons.graphic_eq_rounded,
                      label: 'SOUND EFFECTS',
                      enabled: AudioEngine.sfxEnabledNotifier,
                      volume: AudioEngine.sfxVolumeNotifier,
                      onEnabled: AudioEngine.setSfxEnabled,
                      onVolume: (v) => AudioEngine.sfxVolume = v,
                    ),
                    const SizedBox(height: 10.0),
                    _AudioRow(
                      icon: Icons.sports_bar_rounded,
                      label: 'PUB AMBIENCE',
                      enabled: AudioEngine.ambienceEnabledNotifier,
                      volume: AudioEngine.ambienceVolumeNotifier,
                      onEnabled: AudioEngine.setAmbienceEnabled,
                      onVolume: (v) => AudioEngine.ambienceVolume = v,
                    ),

                    const SizedBox(height: 22.0),

                    // ── Action Buttons ───────────────────────────────────────
                    _MenuButton(
                      label: 'RESUME',
                      isPrimary: true,
                      accentColor: const Color(DartsK.accentP1),
                      onPressed: onResume,
                    ),
                    const SizedBox(height: 10.0),
                    _MenuButton(
                      label: 'HOW TO PLAY',
                      onPressed: onHowToPlay,
                    ),
                    if (!online && onRestart != null) ...[
                      const SizedBox(height: 10.0),
                      _MenuButton(
                        label: 'RESTART MATCH',
                        onPressed: onRestart!,
                      ),
                    ],
                    const SizedBox(height: 10.0),
                    _MenuButton(
                      label: 'EXIT TO LOBBY',
                      isDestructive: true,
                      onPressed: onLobby,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Frosted audio control row with toggle switch and smooth volume slider.
class _AudioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final ValueNotifier<bool> enabled;
  final ValueNotifier<double> volume;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<double> onVolume;

  const _AudioRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.volume,
    required this.onEnabled,
    required this.onVolume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0x660A0E1A),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0x1AFFFFFF),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.0, color: const Color(DartsK.accentP1)),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    fontVariations: [FontVariation('wght', 800)],
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (context, isEnabled, _) {
                  return Switch.adaptive(
                    value: isEnabled,
                    activeThumbColor: const Color(DartsK.accentP1),
                    activeTrackColor: const Color(DartsK.accentP1).withValues(alpha: 0.35),
                    inactiveThumbColor: const Color(DartsK.textMuted),
                    inactiveTrackColor: const Color(0x33FFFFFF),
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      onEnabled(val);
                    },
                  );
                },
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, isEnabled, _) {
              if (!isEnabled) return const SizedBox.shrink();
              return ValueListenableBuilder<double>(
                valueListenable: volume,
                builder: (context, vol, _) {
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(DartsK.accentP1),
                      inactiveTrackColor: const Color(0x26FFFFFF),
                      thumbColor: Colors.white,
                      overlayColor: const Color(DartsK.accentP1).withValues(alpha: 0.2),
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                    ),
                    child: Slider(
                      value: vol.clamp(0.0, 1.0),
                      onChanged: (v) => onVolume(v),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Instant interactive menu button with Apple-standard pointer response.
class _MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final Color? accentColor;

  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.accentColor,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isPrimary
        ? (widget.accentColor ?? const Color(DartsK.accentP1))
        : widget.isDestructive
            ? const Color(DartsK.accentRed)
            : const Color(0x33FFFFFF);

    final Color textColor = widget.isPrimary
        ? const Color(DartsK.surfaceDark)
        : widget.isDestructive
            ? const Color(DartsK.accentRed)
            : Colors.white;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 46.0,
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? baseColor
                : widget.isDestructive
                    ? const Color(0x1AEF4444)
                    : const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: widget.isPrimary
                  ? Colors.transparent
                  : widget.isDestructive
                      ? const Color(0x4DEF4444)
                      : const Color(0x26FFFFFF),
              width: 1.0,
            ),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.35),
                      blurRadius: 16.0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'Inter',
                fontVariations: const [FontVariation('wght', 900)],
                letterSpacing: 0.9,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
