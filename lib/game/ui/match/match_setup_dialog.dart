import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../match/match_config.dart';

/// Streamlined 2-second Arcade 1v1 Challenge Creator modal.
///
/// Lets the player select match rounds and shot clock duration,
/// pulling their personal player identity from [AuthService].
class MatchSetupDialog extends StatefulWidget {
  final MatchConfig initialConfig;

  const MatchSetupDialog({
    super.key,
    this.initialConfig = const MatchConfig(),
  });

  /// Displays the modal sheet / dialog and returns the configured [MatchConfig],
  /// or null if dismissed.
  static Future<MatchConfig?> show(
    BuildContext context, {
    MatchConfig initialConfig = const MatchConfig(),
  }) {
    return showDialog<MatchConfig>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => MatchSetupDialog(initialConfig: initialConfig),
    );
  }

  @override
  State<MatchSetupDialog> createState() => _MatchSetupDialogState();
}

class _MatchSetupDialogState extends State<MatchSetupDialog> {
  late int _selectedRounds;
  late int _selectedDuration;

  static const List<int> _roundOptions = [2, 3, 4];
  static const List<int> _durationOptions = [30, 60];

  @override
  void initState() {
    super.initState();
    _selectedRounds = widget.initialConfig.totalRounds;
    _selectedDuration = widget.initialConfig.roundDurationSeconds;
  }

  void _onStartPressed() {
    HapticFeedback.mediumImpact();
    final profile = AuthService.instance.currentUser;
    final myName = profile?.displayName ?? 'Player';
    final myAvatar = profile?.avatarEmoji ?? '🏀';

    final config = MatchConfig(
      totalRounds: _selectedRounds,
      roundDurationSeconds: _selectedDuration,
      player1Name: myName,
      player1Avatar: myAvatar,
      player2Name: 'Opponent',
      player2Avatar: '⏳',
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthService.instance.currentUser;
    final myName = profile?.displayName ?? 'Player';
    final myAvatar = profile?.avatarEmoji ?? '🏀';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF131826).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: const Color(0xFF2E3954),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                      blurRadius: 28.0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row with close button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: const Icon(
                            Icons.sports_basketball_rounded,
                            color: Color(0xFF00FFCC),
                            size: 22.0,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEW 1V1 MATCH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'Challenge a friend with join code',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18.0),

                    // Player identity capsule
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Text(myAvatar, style: const TextStyle(fontSize: 20.0)),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CREATING AS',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  myName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'YOU',
                            style: TextStyle(
                              color: Color(0xFF00FFCC),
                              fontSize: 11.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // Option 1: Total Rounds
                    const Text(
                      'MATCH LENGTH',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: _roundOptions.map((rounds) {
                        final isSelected = _selectedRounds == rounds;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedRounds = rounds);
                              },
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF1E2638),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF334155),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$rounds Rounds',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                      fontSize: 12.0,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),

                    // Option 2: Shot Clock
                    const Text(
                      'ROUND SHOT CLOCK',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: _durationOptions.map((dur) {
                        final isSelected = _selectedDuration == dur;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedDuration = dur);
                              },
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00FFCC).withValues(alpha: 0.15)
                                      : const Color(0xFF1E2638),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00FFCC)
                                        : const Color(0xFF334155),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    dur == 30 ? '30s Blitz ⚡' : '60s Standard ⏱',
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFFCBD5E1),
                                      fontSize: 12.0,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22.0),

                    // Primary Start Challenge Button
                    SizedBox(
                      height: 50.0,
                      child: ElevatedButton(
                        onPressed: _onStartPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF00FFCC).withValues(alpha: 0.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'START 1V1 MATCH',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(width: 8.0),
                            Icon(Icons.arrow_forward_rounded, size: 18.0),
                          ],
                        ),
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
