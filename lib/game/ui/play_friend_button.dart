import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round "Play a friend" button. For the first [_labelOpens] app opens a
/// "PLAY A FRIEND" label shows beside it for ~4 s, then fades away.
class PlayFriendButton extends StatefulWidget {
  const PlayFriendButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const String _prefKey = 'hoops_play_friend_label_opens';
  static const int _labelOpens = 3;
  static bool _countedThisRun = false;
  static bool _showThisRun = false;

  @override
  State<PlayFriendButton> createState() => _PlayFriendButtonState();
}

class _PlayFriendButtonState extends State<PlayFriendButton> {
  bool _label = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    if (!PlayFriendButton._countedThisRun) {
      PlayFriendButton._countedThisRun = true;
      try {
        final p = await SharedPreferences.getInstance();
        final n = p.getInt(PlayFriendButton._prefKey) ?? 0;
        if (n < PlayFriendButton._labelOpens) {
          PlayFriendButton._showThisRun = true;
          await p.setInt(PlayFriendButton._prefKey, n + 1);
        }
      } catch (_) {}
    } else {
      return; // label only once per app open
    }
    if (!mounted || !PlayFriendButton._showThisRun) return;
    setState(() => _label = true);
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _label = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play a friend',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: _label ? 1 : 0,
              duration: const Duration(milliseconds: 450),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xE60F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x6638BDF8)),
                ),
                child: const Text(
                  'PLAY A FRIEND',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xE60F172A),
                border: Border.all(color: const Color(0x3394A3B8)),
              ),
              child: const Icon(Icons.people_alt_rounded,
                  color: Color(0xFF38BDF8), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
