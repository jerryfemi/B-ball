import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';

/// Flanking circular scoreboard button for the 1v1 Match Hub.
///
/// Features an animated heartbeat pulse and shake/wobble effect
/// when it's your turn to shoot, inviting immediate action.
class InboxNotificationBadge extends StatefulWidget {
  final VoidCallback onTap;

  const InboxNotificationBadge({
    super.key,
    required this.onTap,
  });

  @override
  State<InboxNotificationBadge> createState() => _InboxNotificationBadgeState();
}

class _InboxNotificationBadgeState extends State<InboxNotificationBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartbeatController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shakeAnimation;
  int _prevWaitingCount = 0;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Realistic "lub-dub... pause" heartbeat sequence
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
    ]).animate(_heartbeatController);

    // Subtle rotational arcade wobble
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.1, end: 0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 50,
      ),
    ]).animate(_heartbeatController);
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  void _updateAnimation(int turnsWaiting) {
    if (turnsWaiting > 0) {
      if (!_heartbeatController.isAnimating) {
        _heartbeatController.repeat();
      }
      if (_prevWaitingCount == 0 && turnsWaiting > 0) {
        HapticFeedback.mediumImpact();
      }
    } else {
      if (_heartbeatController.isAnimating) {
        _heartbeatController.stop();
        _heartbeatController.reset();
      }
    }
    _prevWaitingCount = turnsWaiting;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return _buildButton(turnsWaiting: 0);
        }

        return StreamBuilder<List<CloudMatch>>(
          stream: FirestoreMatchService.instance.streamUserMatches(user.uid),
          builder: (context, snapshot) {
            final matches = snapshot.data ?? [];
            final turnsWaiting = matches
                .where((m) =>
                    m.isMyTurn(user.uid) && m.status != MatchStatus.completed)
                .length;

            _updateAnimation(turnsWaiting);

            return _buildButton(turnsWaiting: turnsWaiting);
          },
        );
      },
    );
  }

  Widget _buildButton({required int turnsWaiting}) {
    final hasTurns = turnsWaiting > 0;

    return AnimatedBuilder(
      animation: _heartbeatController,
      builder: (context, child) {
        final scale = hasTurns ? _scaleAnimation.value : 1.0;
        final rotation = hasTurns ? _shakeAnimation.value : 0.0;

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(17.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: hasTurns
                      ? const Color(0xFF0F172A)
                      : const Color(0xDDFFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasTurns
                        ? const Color(0xFF00FFCC)
                        : const Color(0x66FFFFFF),
                    width: hasTurns ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hasTurns
                          ? const Color(0xFF00FFCC).withValues(alpha: 0.5)
                          : const Color(0x33000000),
                      blurRadius: hasTurns ? 10.0 : 6.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.forum_rounded,
                    size: 18.0,
                    color: hasTurns
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (hasTurns)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      '$turnsWaiting',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
