import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import '../../audio/audio_engine.dart';
import '../../basketball_game.dart';
import '../common/app_avatar.dart';

/// Flanking circular player avatar with illuminated badge, "You" label,
/// and live reactive inbox/turns notification pip.
class ScoreboardPlayerAvatar extends StatefulWidget {
  final bool isActive;
  final String label;
  final String avatar;
  final String? activeMatchId;
  final VoidCallback? onTap;

  const ScoreboardPlayerAvatar({
    super.key,
    this.isActive = true,
    this.label = 'You',
    this.avatar = AppAvatar.defaultAvatar,
    this.activeMatchId,
    this.onTap,
  });

  @override
  State<ScoreboardPlayerAvatar> createState() => _ScoreboardPlayerAvatarState();
}

class _ScoreboardPlayerAvatarState extends State<ScoreboardPlayerAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  int _prevWaitingCount = 0;
  String? _currentStreamUid;
  Stream<List<CloudMatch>>? _matchesStream;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onAlertsUpdated(int count) {
    if (count > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (count > _prevWaitingCount) {
        HapticFeedback.lightImpact();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
    _prevWaitingCount = count;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null || user.uid.isEmpty) {
          return _buildAvatar(alertsCount: 0);
        }

        if (_currentStreamUid != user.uid) {
          _currentStreamUid = user.uid;
          _matchesStream = FirestoreMatchService.instance.streamUserMatches(
            user.uid,
          );
        }

        return StreamBuilder<List<FriendInvite>>(
          stream: FriendsService.instance.streamIncomingInvites(user.uid),
          initialData: const <FriendInvite>[],
          builder: (context, invitesSnapshot) {
            final invitesCount = (invitesSnapshot.data ?? []).length;

            return StreamBuilder<List<CloudMatch>>(
              stream: _matchesStream,
              initialData: const <CloudMatch>[],
              builder: (context, snapshot) {
                final matches = snapshot.data ?? [];
                final activeId = widget.activeMatchId;
                final turnsWaiting = matches
                    .where(
                      (m) =>
                          m.isMyTurn(user.uid) &&
                          m.status != MatchStatus.completed &&
                          (activeId == null || m.id != activeId),
                    )
                    .length;

                // Also count unread chat messages from background matches
                final chatAlerts = matches.where((m) {
                  if (activeId != null && m.id == activeId) return false;
                  if (m.chat.isEmpty) return false;
                  final lastMsg = m.chat.last;
                  return lastMsg.senderUid != user.uid;
                }).length;

                final totalAlerts = turnsWaiting + invitesCount + chatAlerts;
                _onAlertsUpdated(totalAlerts);

                return _buildAvatar(alertsCount: totalAlerts);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar({required int alertsCount}) {
    final hasAlerts = alertsCount > 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = hasAlerts ? _scaleAnimation.value : 1.0;
        final glowProgress = hasAlerts ? _pulseController.value : 0.0;

        final Color borderColor = hasAlerts
            ? Color.lerp(
                const Color(0xFFF59E0B),
                const Color(0xFFFBBF24),
                glowProgress,
              )!
            : (widget.isActive
                ? const Color(0xFF86EFAC)
                : Colors.white.withValues(alpha: 0.8));

        final Color glowColor = hasAlerts
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

        final bool showGlow = hasAlerts || widget.isActive;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    avatar: widget.avatar,
                    size: 36.0,
                    borderColor: borderColor,
                    borderWidth:
                        hasAlerts ? 2.4 : (widget.isActive ? 2.2 : 1.5),
                    showGlow: showGlow,
                    glowColor: glowColor,
                    onTap: () {
                      if (widget.onTap != null) {
                        HapticFeedback.lightImpact();
                        widget.onTap!();
                      }
                    },
                  ),
                  if (hasAlerts)
                    Positioned(
                      top: -2.0,
                      right: -2.0,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16.0,
                          minHeight: 16.0,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(9.0),
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.6),
                              blurRadius: 6.0,
                              spreadRadius: 1.0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$alertsCount',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              widget.label,
              style: TextStyle(
                color: hasAlerts
                    ? const Color(0xFFFBBF24)
                    : (widget.isActive
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFF4ADE80)),
                fontSize: 10.0,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4.0)],
              ),
            ),
          ],
        );
      },
    );
  }
}

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

/// Flanking help button pill with "?" icon.
class ScoreboardHelpBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const ScoreboardHelpBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17.0),
        child: Container(
          width: 34.0,
          height: 34.0,
          decoration: BoxDecoration(
            color: const Color(0xDDFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x66FFFFFF), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular mute toggle button showing dynamic sound wave / muted slash icon.
class ScoreboardMuteBadge extends StatelessWidget {
  const ScoreboardMuteBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioEngine.isMutedNotifier,
      builder: (context, isMuted, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: AudioEngine.toggleMute,
            borderRadius: BorderRadius.circular(17.0),
            child: Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: isMuted
                    ? const Color(0xCC331116)
                    : const Color(0xDDFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMuted
                      ? const Color(0x88FF4444)
                      : const Color(0x66FFFFFF),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 18.0,
                  color: isMuted
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular pause / resume button.
class ScoreboardPauseBadge extends StatelessWidget {
  final BasketballGame game;

  const ScoreboardPauseBadge({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.isPausedNotifier,
      builder: (context, isPaused, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isPaused) {
                game.resumeGame();
              } else {
                game.pauseGame(manual: true);
              }
            },
            borderRadius: BorderRadius.circular(17.0),
            child: Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: isPaused
                    ? const Color(0xCC1E293B)
                    : const Color(0xDDFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPaused
                      ? const Color(0x8838BDF8)
                      : const Color(0x66FFFFFF),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 20.0,
                  color: isPaused
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
