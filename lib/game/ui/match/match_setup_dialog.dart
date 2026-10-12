import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../models/player_descriptor.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import '../../match/match_config.dart';
import '../common/app_avatar.dart';
import '../common/app_button.dart';
import '../common/app_modal_dialog.dart';

/// Streamlined Arcade 1v1 Challenge Creator modal in muted luxury obsidian palette.
class MatchSetupDialog extends StatefulWidget {
  final MatchConfig initialConfig;

  const MatchSetupDialog({super.key, this.initialConfig = const MatchConfig()});

  static Future<MatchConfig?> show(
    BuildContext context, {
    MatchConfig initialConfig = const MatchConfig(),
  }) {
    return AppModalDialog.show<MatchConfig>(
      context: context,
      builder: (context) => MatchSetupDialog(initialConfig: initialConfig),
    );
  }

  @override
  State<MatchSetupDialog> createState() => _MatchSetupDialogState();
}

class _MatchSetupDialogState extends State<MatchSetupDialog> {
  late int _selectedRounds;
  late int _selectedDuration;
  int _opponentMode = 0; // 0: Open Code, 1: Friend Challenge
  FriendProfile? _selectedFriend;
  bool _isGeneratingCode = false;
  CloudMatch? _precreatedMatch;
  bool _codeCopied = false;

  static const List<int> _roundOptions = [2, 3, 4];
  static const List<int> _durationOptions = [30, 60];

  @override
  void initState() {
    super.initState();
    _selectedRounds = widget.initialConfig.totalRounds;
    _selectedDuration = widget.initialConfig.roundDurationSeconds;
    if (widget.initialConfig.opponentFriend != null) {
      _selectedFriend = widget.initialConfig.opponentFriend;
      _opponentMode = 1;
    }
  }

  Future<void> _generateUpfrontCode(UserProfile profile) async {
    if (_isGeneratingCode) return;
    setState(() => _isGeneratingCode = true);
    try {
      final config = MatchConfig(
        totalRounds: _selectedRounds,
        roundDurationSeconds: _selectedDuration,
        player1Name: profile.displayName,
        player1Avatar: profile.avatarEmoji,
        player2Name: 'Opponent',
        player2Avatar: '⏳',
      );
      final match = await FirestoreMatchService.instance.createMatch(
        config: config,
        player1Profile: profile,
      );
      await Clipboard.setData(ClipboardData(text: match.joinCode));
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _precreatedMatch = match;
          _codeCopied = true;
          _isGeneratingCode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingCode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate code: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _copyCode() async {
    if (_precreatedMatch == null) return;
    await Clipboard.setData(ClipboardData(text: _precreatedMatch!.joinCode));
    HapticFeedback.lightImpact();
    setState(() => _codeCopied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match code ${_precreatedMatch!.joinCode} copied!'),
          backgroundColor: const Color(0xFF1E2638),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onStartPressed() {
    HapticFeedback.mediumImpact();
    final profile = AuthService.instance.currentUser;
    final myName = profile?.displayName ?? 'Player';
    final myAvatar =
        profile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;

    final config = MatchConfig(
      totalRounds: _selectedRounds,
      roundDurationSeconds: _selectedDuration,
      player1Name: myName,
      player1Avatar: myAvatar,
      player2Name: _opponentMode == 1 && _selectedFriend != null
          ? _selectedFriend!.displayName
          : 'Opponent',
      player2Avatar: _opponentMode == 1 && _selectedFriend != null
          ? _selectedFriend!.avatarEmoji
          : '⏳',
      player2Uid: _opponentMode == 1 ? _selectedFriend?.uid : null,
      opponentFriend: _opponentMode == 1 ? _selectedFriend : null,
      precreatedMatch: _precreatedMatch,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthService.instance.currentUser;
    final myName = profile?.displayName ?? 'Player';
    final myAvatar =
        profile?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;

    return AppModalDialog(
      maxWidth: 390.0,
      scrollable: true,
      iconWidget: const Icon(
        Icons.sports_basketball_rounded,
        color: Color(0xFFF59E0B),
        size: 22.0,
      ),
      title: 'NEW 1V1 MATCH',
      subtitle: 'Challenge a friend or share a match code',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player identity capsule
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2638),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                AppAvatar(
                  avatar: myAvatar,
                  size: 34.0,
                  borderColor: const Color(0xFF38BDF8),
                  borderWidth: 1.5,
                ),
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
                  'HOST',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // Opponent Mode Selector
          const Text(
            'OPPONENT',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              _buildOpponentTab(0, 'OPEN CODE', Icons.qr_code_rounded),
              const SizedBox(width: 8.0),
              _buildOpponentTab(1, 'CHALLENGE FRIEND', Icons.people_alt_rounded),
            ],
          ),
          const SizedBox(height: 10.0),

          // Opponent Details / Options
          if (_opponentMode == 0) _buildOpenCodeSection(profile) else _buildFriendsRibbon(profile),
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
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                            fontSize: 12.0,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
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
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF334155),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dur == 30 ? '30s Blitz ⚡' : '60s Standard ⏱',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFCBD5E1),
                            fontSize: 12.0,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
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
          AppPrimaryButton(
            label: _getStartButtonLabel(),
            backgroundColor: const Color(0xFF38BDF8),
            iconData: Icons.arrow_forward_rounded,
            onPressed: _onStartPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentTab(int mode, String label, IconData icon) {
    final isSelected = _opponentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _opponentMode = mode);
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF1E2638),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.0,
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenCodeSection(UserProfile? profile) {
    if (_precreatedMatch != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ROOM CODE READY',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _codeCopied
                            ? Icons.check_circle_rounded
                            : Icons.copy_rounded,
                        color: _codeCopied
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF94A3B8),
                        size: 14.0,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _codeCopied ? 'COPIED' : 'COPY',
                        style: TextStyle(
                          color: _codeCopied
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Text(
              _precreatedMatch!.joinCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
              ),
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Code copied! Share with your rival before or after shooting.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tag_rounded, color: Color(0xFF38BDF8), size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shareable 6-digit match code for randoms or rivals.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          SizedBox(
            height: 36.0,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingCode || profile == null
                  ? null
                  : () => _generateUpfrontCode(profile),
              icon: _isGeneratingCode
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  : const Icon(Icons.copy_rounded, size: 14),
              label: Text(
                _isGeneratingCode ? 'GENERATING CODE...' : 'GET CODE & INVITE',
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsRibbon(UserProfile? profile) {
    final uid = profile?.uid ?? '';
    return StreamBuilder<List<FriendProfile>>(
      stream: FriendsService.instance.streamFriends(uid),
      initialData: FriendsService.instance.friendsNotifier.value,
      builder: (context, snapshot) {
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2638),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                const Text(
                  'No friends added yet. Add friends via the Friends Hub, or generate an open code!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.0,
                  ),
                ),
                const SizedBox(height: 6.0),
                TextButton(
                  onPressed: () => setState(() => _opponentMode = 0),
                  child: const Text(
                    'USE OPEN MATCH CODE',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 84.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8.0),
            itemBuilder: (context, index) {
              final friend = friends[index];
              final isSelected = _selectedFriend?.uid == friend.uid;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedFriend = isSelected ? null : friend;
                  });
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  width: 72.0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6.0,
                    horizontal: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1E3A5F)
                        : const Color(0xFF1E2638),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF334155),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AppAvatar(
                            avatar: friend.avatarEmoji,
                            size: 32.0,
                            borderColor: isSelected
                                ? const Color(0xFF38BDF8)
                                : Colors.transparent,
                          ),
                          if (isSelected)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2.0),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF38BDF8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        friend.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          fontSize: 10.0,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getStartButtonLabel() {
    if (_opponentMode == 1 && _selectedFriend != null) {
      return 'CHALLENGE ${_selectedFriend!.displayName.toUpperCase()} ➔';
    }
    if (_precreatedMatch != null) {
      return 'START ROUND 1 ➔';
    }
    return 'START 1V1 MATCH';
  }
}
