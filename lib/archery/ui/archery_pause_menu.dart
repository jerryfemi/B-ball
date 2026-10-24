import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/audio/audio_engine.dart';

/// Archery's pause menu: music, sound effects and birdsong (each with an
/// on/off switch and a volume slider), plus resume / restart / lobby.
///
/// Solo play freezes while it is open. Online, the match keeps running (your
/// opponent isn't paused), so the menu says so and offers no restart.
///
/// Shared with darts: the ambience row's name/icon and an optional
/// "HOW TO PLAY" button are configurable; everything else is identical.
class ArcheryPauseMenu extends StatelessWidget {
  final bool online;
  final VoidCallback onResume;
  final VoidCallback? onRestart;
  final VoidCallback onLobby;
  final VoidCallback? onHowToPlay;

  /// Small attribution line under the buttons (e.g. a CC-BY model credit).
  final String? credit;

  const ArcheryPauseMenu({
    super.key,
    required this.online,
    required this.onResume,
    required this.onLobby,
    this.onRestart,
    this.onHowToPlay,
    this.credit,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap outside = resume.
        Positioned.fill(
          child: GestureDetector(
            onTap: onResume,
            child: const ColoredBox(color: Color(0x99000000)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: const Color(0xF20F172A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF1E2638),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xCC000000),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'PAUSED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      if (online) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'LIVE MATCH · YOUR SHOT CLOCK KEEPS RUNNING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _AudioRow(
                        icon: Icons.music_note_rounded,
                        label: 'MUSIC',
                        enabled: AudioEngine.musicEnabledNotifier,
                        volume: AudioEngine.musicVolumeNotifier,
                        onEnabled: AudioEngine.setMusicEnabled,
                        onVolume: (v) => AudioEngine.musicVolume = v,
                      ),
                      _AudioRow(
                        icon: Icons.graphic_eq_rounded,
                        label: 'SOUND EFFECTS',
                        enabled: AudioEngine.sfxEnabledNotifier,
                        volume: AudioEngine.sfxVolumeNotifier,
                        onEnabled: AudioEngine.setSfxEnabled,
                        onVolume: (v) => AudioEngine.sfxVolume = v,
                      ),
                      const SizedBox(height: 14),
                      _MenuButton(
                        label: 'RESUME',
                        icon: Icons.play_arrow_rounded,
                        primary: true,
                        onTap: onResume,
                      ),
                      if (onHowToPlay != null) ...[
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'HOW TO PLAY',
                          icon: Icons.help_outline_rounded,
                          onTap: onHowToPlay!,
                        ),
                      ],
                      if (onRestart != null) ...[
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'RESTART MATCH',
                          icon: Icons.replay_rounded,
                          onTap: onRestart!,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _MenuButton(
                        label: 'LOBBY',
                        icon: Icons.grid_view_rounded,
                        onTap: onLobby,
                      ),
                      if (credit != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          credit!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One audio channel: icon, name, on/off switch and a volume slider.
class _AudioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final ValueNotifier<bool> enabled;
  final ValueNotifier<double> volume;
  final Future<void> Function(bool) onEnabled;
  final ValueChanged<double> onVolume;

  const _AudioRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.volume,
    required this.onEnabled,
    required this.onVolume,
  });

  static const Color _accent = Color(0xFF00FFCC);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (context, on, _) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: on ? _accent : const Color(0xFF475569)),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(
                  color: on ? Colors.white : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: volume,
                builder: (context, v, _) => SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: _accent,
                    inactiveTrackColor: const Color(0xFF1E2638),
                    thumbColor: Colors.white,
                    disabledActiveTrackColor: const Color(0xFF334155),
                    disabledThumbColor: const Color(0xFF475569),
                  ),
                  child: Slider(value: v, onChanged: on ? onVolume : null),
                ),
              ),
            ),
            Switch(
              value: on,
              activeThumbColor: Colors.white,
              activeTrackColor: _accent,
              inactiveThumbColor: const Color(0xFF94A3B8),
              inactiveTrackColor: const Color(0xFF1E2638),
              onChanged: (value) {
                HapticFeedback.selectionClick();
                onEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary
              ? const Color(0xFF00FFCC)
              : const Color(0xFF1E2638),
          foregroundColor: primary ? const Color(0xFF0A0E1A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
