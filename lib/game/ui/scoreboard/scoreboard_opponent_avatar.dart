import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../common/app_avatar.dart';

/// Flanking circular opponent avatar with illuminated badge and "Them" label.
class ScoreboardOpponentAvatar extends StatefulWidget {
  final bool isActive;
  final String label;
  final String avatar;
  final bool isWaiting;
  final String? joinCode;
  final String? activeMatchId;
  final VoidCallback? onTap;

  const ScoreboardOpponentAvatar({
    super.key,
    this.isActive = false,
    this.label = 'Them',
    this.avatar = 'assets/avatars/dunk_heads (2).webp',
    this.isWaiting = false,
    this.joinCode,
    this.activeMatchId,
    this.onTap,
  });

  @override
  State<ScoreboardOpponentAvatar> createState() => _ScoreboardOpponentAvatarState();
}

class _ScoreboardOpponentAvatarState extends State<ScoreboardOpponentAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bubbleController;
  late final Animation<double> _bubbleScaleAnimation;
  Timer? _bubbleTimer;
  String? _currentBanterText;
  int _lastSeenBanterTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _bubbleScaleAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _bubbleController.dispose();
    super.dispose();
  }

  void _triggerBanterBubble(String text) {
    _bubbleTimer?.cancel();
    setState(() {
      _currentBanterText = text;
    });
    _bubbleController.forward();
    HapticFeedback.lightImpact();
    _bubbleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _bubbleController.reverse();
      }
    });
  }

  void _onAvatarTap() {
    if (widget.isWaiting && widget.joinCode != null && widget.joinCode!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: widget.joinCode!));
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match code ${widget.joinCode} copied! Share it with a friend.'),
          backgroundColor: const Color(0xFF1E2638),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.0),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeMatchId == null || widget.activeMatchId!.isEmpty) {
      return _buildContent();
    }

    return StreamBuilder<CloudMatch?>(
      stream: FirestoreMatchService.instance.streamMatch(widget.activeMatchId!),
      builder: (context, snapshot) {
        final match = snapshot.data;
        if (match != null && match.chat.isNotEmpty) {
          final lastMsg = match.chat.last;
          final myUid = AuthService.instance.currentUser?.uid ?? '';
          if (lastMsg.senderUid != myUid && lastMsg.timestamp > _lastSeenBanterTimestamp) {
            _lastSeenBanterTimestamp = lastMsg.timestamp;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _triggerBanterBubble(lastMsg.text);
            });
          }
        }
        return _buildContent();
      },
    );
  }

  Widget _buildContent() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _onAvatarTap,
              borderRadius: BorderRadius.circular(18.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    avatar: widget.isWaiting ? '⏳' : widget.avatar,
                    size: 36.0,
                    borderColor: widget.isWaiting
                        ? const Color(0xFFF59E0B)
                        : (widget.isActive
                            ? const Color(0xFF38BDF8)
                            : Colors.white.withValues(alpha: 0.8)),
                    borderWidth: widget.isWaiting || widget.isActive ? 2.2 : 1.5,
                    showGlow: widget.isActive || widget.isWaiting,
                    glowColor: widget.isWaiting
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF38BDF8),
                  ),
                  if (widget.isWaiting)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 9.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2.0),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 62.0),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isWaiting
                      ? const Color(0xFFFBBF24)
                      : (widget.isActive
                          ? const Color(0xFF7DD3FC)
                          : const Color(0xFF38BDF8)),
                  fontSize: 10.0,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4.0)],
                ),
              ),
            ),
          ],
        ),

        // Floating speech bubble for live banter
        if (_currentBanterText != null)
          Positioned(
            bottom: 48.0,
            child: FadeTransition(
              opacity: _bubbleController,
              child: ScaleTransition(
                scale: _bubbleScaleAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 6.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 88.0),
                    child: Text(
                      _currentBanterText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
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
