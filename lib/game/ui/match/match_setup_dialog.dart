import 'dart:ui';
import 'package:flutter/material.dart';

import '../../match/match_config.dart';

/// GamePigeon Authentic 1v1 Match Setup Modal.
///
/// Enables players to configure:
/// - Match Length: 2, 3, or 4 rounds.
/// - Round Clock: 30s (Blitz) or 60s (Standard).
/// - Player 1 & Player 2 Custom Names and Avatars.
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
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => MatchSetupDialog(initialConfig: initialConfig),
    );
  }

  @override
  State<MatchSetupDialog> createState() => _MatchSetupDialogState();
}

class _MatchSetupDialogState extends State<MatchSetupDialog> {
  late int _selectedRounds;
  late int _selectedDuration;
  late TextEditingController _p1NameController;
  late TextEditingController _p2NameController;
  late String _p1Avatar;
  late String _p2Avatar;

  static const List<int> _roundOptions = [2, 3, 4];
  static const List<int> _durationOptions = [30, 60];
  static const List<String> _avatarOptionsP1 = ['🏀', '🔥', '⚡', '👑', '🐺'];
  static const List<String> _avatarOptionsP2 = ['🎯', '🚀', '💣', '💎', '🦁'];

  @override
  void initState() {
    super.initState();
    _selectedRounds = widget.initialConfig.totalRounds;
    _selectedDuration = widget.initialConfig.roundDurationSeconds;
    _p1NameController =
        TextEditingController(text: widget.initialConfig.player1Name);
    _p2NameController =
        TextEditingController(text: widget.initialConfig.player2Name);
    _p1Avatar = widget.initialConfig.player1Avatar;
    _p2Avatar = widget.initialConfig.player2Avatar;
  }

  @override
  void dispose() {
    _p1NameController.dispose();
    _p2NameController.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    final p1Name = _p1NameController.text.trim().isEmpty
        ? 'You'
        : _p1NameController.text.trim();
    final p2Name = _p2NameController.text.trim().isEmpty
        ? 'Them'
        : _p2NameController.text.trim();

    final config = MatchConfig(
      totalRounds: _selectedRounds,
      roundDurationSeconds: _selectedDuration,
      player1Name: p1Name,
      player2Name: p2Name,
      player1Avatar: _p1Avatar,
      player2Avatar: _p2Avatar,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22.0,
                  vertical: 24.0,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF20F172A),
                      Color(0xFA090D16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: const Color(0x3838BDF8),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 36.0,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with Title & Close Icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: const Color(0x2238BDF8),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: const Color(0x5538BDF8),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              '⚙️',
                              style: TextStyle(fontSize: 18.0),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1V1 MATCH SETUP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 2.0),
                                Text(
                                  'Customize rounds, shot clock & players',
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
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                              size: 22.0,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),

                      // Section 1: Number of Rounds
                      _buildSectionTitle(
                        icon: Icons.repeat_rounded,
                        title: 'MATCH LENGTH',
                        subtitle: 'Rounds played per participant',
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: _roundOptions.map((rounds) {
                          final isSelected = _selectedRounds == rounds;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _buildSelectorPill(
                                label: '$rounds ROUNDS',
                                isSelected: isSelected,
                                activeColor: const Color(0xFF22C55E),
                                activeGlowColor: const Color(0x4422C55E),
                                onTap: () => setState(() => _selectedRounds = rounds),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18.0),

                      // Section 2: Shot Clock
                      _buildSectionTitle(
                        icon: Icons.timer_outlined,
                        title: 'SHOT CLOCK DURATION',
                        subtitle: 'Time per shooting turn',
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: _durationOptions.map((duration) {
                          final isSelected = _selectedDuration == duration;
                          final label = duration == 30 ? '30s BLITZ' : '60s STANDARD';
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _buildSelectorPill(
                                label: label,
                                isSelected: isSelected,
                                activeColor: const Color(0xFFF59E0B),
                                activeGlowColor: const Color(0x44F59E0B),
                                onTap: () => setState(() => _selectedDuration = duration),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20.0),

                      // Section 3: Player Customization
                      _buildSectionTitle(
                        icon: Icons.people_outline_rounded,
                        title: 'PARTICIPANTS',
                        subtitle: 'Names and player avatars',
                      ),
                      const SizedBox(height: 10.0),

                      // Player 1 Card
                      _buildPlayerCard(
                        playerNumber: 1,
                        label: 'Player 1 (Green)',
                        themeColor: const Color(0xFF22C55E),
                        nameController: _p1NameController,
                        hintText: 'You',
                        selectedAvatar: _p1Avatar,
                        avatarOptions: _avatarOptionsP1,
                        onAvatarSelected: (av) => setState(() => _p1Avatar = av),
                      ),
                      const SizedBox(height: 10.0),

                      // Player 2 Card
                      _buildPlayerCard(
                        playerNumber: 2,
                        label: 'Player 2 (Cyan)',
                        themeColor: const Color(0xFF38BDF8),
                        nameController: _p2NameController,
                        hintText: 'Them',
                        selectedAvatar: _p2Avatar,
                        avatarOptions: _avatarOptionsP2,
                        onAvatarSelected: (av) => setState(() => _p2Avatar = av),
                      ),
                      const SizedBox(height: 22.0),

                      // Action Button: Start Match
                      ElevatedButton(
                        onPressed: _onStartPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          elevation: 6.0,
                          shadowColor: const Color(0x6622C55E),
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.sports_basketball_rounded,
                              size: 20.0,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'START $_selectedRounds-ROUND MATCH',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
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
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16.0, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 6.0),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorPill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color activeGlowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : const Color(0x18334155),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0x28FFFFFF),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeGlowColor,
                    blurRadius: 10.0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required int playerNumber,
    required String label,
    required Color themeColor,
    required TextEditingController nameController,
    required String hintText,
    required String selectedAvatar,
    required List<String> avatarOptions,
    required ValueChanged<String> onAvatarSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0x181E293B),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: themeColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              // Avatar selector row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: avatarOptions.map((av) {
                  final isChosen = av == selectedAvatar;
                  return InkWell(
                    onTap: () => onAvatarSelected(av),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: isChosen
                            ? themeColor.withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isChosen ? themeColor : Colors.transparent,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        av,
                        style: const TextStyle(fontSize: 14.0),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Container(
            height: 38.0,
            decoration: BoxDecoration(
              color: const Color(0x2A0F172A),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: const Color(0x3394A3B8),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                Text(
                  selectedAvatar,
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: themeColor,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
