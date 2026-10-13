import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/live_reaction_event.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../basketball_game.dart';
import '../../match/match_session.dart';
import '../common/app_avatar.dart';
import '../common/app_colors.dart';

/// Data class representing an active floating item in the courtside track.
class _ActiveFloatingReaction {
  final String id;
  final bool isEmoji;
  final String content;
  final String senderAvatar;
  final String senderName;
  final double horizontalOffset;
  final DateTime createdAt;

  _ActiveFloatingReaction({
    required this.id,
    required this.isEmoji,
    required this.content,
    required this.senderAvatar,
    required this.senderName,
    required this.horizontalOffset,
    required this.createdAt,
  });
}

/// Courtside overlay featuring:
/// 1. Floating reaction animation track drifting upward on the left side of the court.
/// 2. Interactive spectator reaction & banter dock with quick emojis & text taunt pills.
class LiveFloatingReactionsOverlay extends StatefulWidget {
  final BasketballGame game;

  const LiveFloatingReactionsOverlay({
    super.key,
    required this.game,
  });

  @override
  State<LiveFloatingReactionsOverlay> createState() =>
      _LiveFloatingReactionsOverlayState();
}

class _LiveFloatingReactionsOverlayState
    extends State<LiveFloatingReactionsOverlay> {
  final List<_ActiveFloatingReaction> _activeReactions = [];
  final Set<String> _spawnedIds = {};
  StreamSubscription<LiveReactionEvent>? _reactionSubscription;
  String? _activeSubscribedMatchId;
  DateTime _lastSentTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isDockExpanded = false;

  // Reaction options
  static const List<String> _quickEmojis = ['🔥', '🧱', '🗑️', '😱', '👏'];
  static const List<String> _quickTexts = [
    'Nice shot!',
    'On fire!',
    'Lucky!',
    'Brick!',
    'Airball!',
  ];

  @override
  void initState() {
    super.initState();
    widget.game.matchSessionNotifier.addListener(_onMatchSessionChanged);
    _syncReactionListener();
  }

  @override
  void didUpdateWidget(covariant LiveFloatingReactionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.matchSessionNotifier.removeListener(_onMatchSessionChanged);
      widget.game.matchSessionNotifier.addListener(_onMatchSessionChanged);
      _syncReactionListener();
    }
  }

  @override
  void dispose() {
    widget.game.matchSessionNotifier.removeListener(_onMatchSessionChanged);
    _reactionSubscription?.cancel();
    super.dispose();
  }

  void _onMatchSessionChanged() {
    _syncReactionListener();
    if (mounted) setState(() {});
  }

  void _syncReactionListener() {
    final session = widget.game.matchSessionNotifier.value;
    final matchId = session?.cloudMatchId;

    if (matchId == null || matchId.isEmpty) {
      _reactionSubscription?.cancel();
      _reactionSubscription = null;
      _activeSubscribedMatchId = null;
      return;
    }

    if (_activeSubscribedMatchId == matchId && _reactionSubscription != null) {
      return;
    }

    _reactionSubscription?.cancel();
    _activeSubscribedMatchId = matchId;
    _reactionSubscription = FirestoreMatchService.instance
        .streamLiveReactions(matchId)
        .listen((reaction) {
      if (!mounted) return;
      _spawnReaction(reaction);
    });
  }

  void _spawnReaction(LiveReactionEvent reaction) {
    if (_spawnedIds.contains(reaction.id)) return;
    _spawnedIds.add(reaction.id);

    // Limit memory footprint
    if (_spawnedIds.length > 100) {
      _spawnedIds.remove(_spawnedIds.first);
    }

    final randOffset = (math.Random().nextDouble() - 0.5) * 28.0;
    final item = _ActiveFloatingReaction(
      id: reaction.id,
      isEmoji: reaction.isEmoji,
      content: reaction.content,
      senderAvatar: reaction.senderAvatar,
      senderName: reaction.senderName,
      horizontalOffset: randOffset,
      createdAt: DateTime.now(),
    );

    setState(() {
      _activeReactions.add(item);
    });
  }

  void _handleSendReaction({required bool isEmoji, required String content}) {
    final session = widget.game.matchSessionNotifier.value;
    final matchId = session?.cloudMatchId;
    if (matchId == null || matchId.isEmpty) return;

    // Rate limit: 250ms cooldown between sends
    final now = DateTime.now();
    if (now.difference(_lastSentTime).inMilliseconds < 250) {
      return;
    }
    _lastSentTime = now;

    HapticFeedback.lightImpact();

    final user = AuthService.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    final name = user?.displayName ?? 'You';
    final avatar = user?.avatarEmoji ?? '👤';

    final reactionId = '${now.millisecondsSinceEpoch}_${uid}_${_activeReactions.length}';
    final reaction = LiveReactionEvent(
      id: reactionId,
      senderUid: uid,
      senderName: name,
      senderAvatar: avatar,
      isEmoji: isEmoji,
      content: content,
      timestamp: now.millisecondsSinceEpoch,
    );

    // Immediate zero-latency local spawn
    _spawnReaction(reaction);

    // Broadcast over Firestore
    unawaited(FirestoreMatchService.instance.sendLiveReaction(
      matchId: matchId,
      reaction: reaction,
    ));
  }

  void _removeReaction(String id) {
    if (!mounted) return;
    setState(() {
      _activeReactions.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.game.matchSessionNotifier.value;
    final is1v1Cloud = session != null &&
        session.mode == MatchGameMode.onlineCloud1v1 &&
        session.cloudMatchId != null;

    if (!is1v1Cloud) {
      return const SizedBox.shrink();
    }

    final isSpectating = session.phase == MatchTurnPhase.watchingLiveOpponent;

    return Stack(
      children: [
        // 1. Floating Reaction Stream (Left Side of Screen, non-blocking)
        Positioned(
          left: 12.0,
          bottom: 110.0,
          width: 140.0,
          height: MediaQuery.of(context).size.height * 0.58,
          child: IgnorePointer(
            ignoring: true,
            child: Stack(
              clipBehavior: Clip.none,
              children: _activeReactions.map((item) {
                return _FloatingReactionBubble(
                  key: ValueKey(item.id),
                  reaction: item,
                  onComplete: () => _removeReaction(item.id),
                );
              }).toList(),
            ),
          ),
        ),

        // 2. Spectator Reactions Dock (Collapsible Streamer Strip on bottom-left)
        if (isSpectating)
          Positioned(
            left: 14.0,
            bottom: 20.0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInQuad,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    alignment: Alignment.bottomLeft,
                    child: child,
                  ),
                );
              },
              child: _isDockExpanded
                  ? _buildStreamerStrip(context)
                  : _buildMinimizedPill(context),
            ),
          ),
      ],
    );
  }

  /// Sleek dual-action minimized quick pill: [ 🔥 | ⌃ ]
  /// Tap 🔥 sends instant reaction with zero delay; tap ⌃ expands full palette.
  Widget _buildMinimizedPill(BuildContext context) {
    return Container(
      key: const ValueKey('minimized_pill'),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: AppColors.accentNeonCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick-fire Fire Emoji button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleSendReaction(isEmoji: true, content: '🔥'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                '🔥',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
          ),
          // Vertical micro-divider
          Container(
            width: 1.0,
            height: 16.0,
            color: AppColors.borderInput.withValues(alpha: 0.6),
          ),
          // Expand button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isDockExpanded = true);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7.0, vertical: 4.0),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.accentNeonCyan,
                size: 20.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Template 1: Streamer Glass Strip (Ultra-compact 2-tier dock without BackdropFilter)
  Widget _buildStreamerStrip(BuildContext context) {
    final maxW = math.min(290.0, MediaQuery.of(context).size.width - 28.0);
    return Container(
      key: const ValueKey('expanded_dock'),
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.accentNeonCyan.withValues(alpha: 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Raw emojis without circle containers + minimize chevron
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ..._quickEmojis.map((emoji) {
                return _BorderlessEmojiButton(
                  emoji: emoji,
                  onTap: () => _handleSendReaction(isEmoji: true, content: emoji),
                );
              }),
              // Minimize button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isDockExpanded = false);
                },
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                    size: 16.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          // Bottom Row: Clean typographic text taunt strip (no bulky pills)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < _quickTexts.length; i++) ...[
                  _TypographicTauntButton(
                    text: _quickTexts[i],
                    onTap: () => _handleSendReaction(isEmoji: false, content: _quickTexts[i]),
                  ),
                  if (i < _quickTexts.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          fontSize: 10.0,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual animated floating reaction item.
class _FloatingReactionBubble extends StatefulWidget {
  final _ActiveFloatingReaction reaction;
  final VoidCallback onComplete;

  const _FloatingReactionBubble({
    super.key,
    required this.reaction,
    required this.onComplete,
  });

  @override
  State<_FloatingReactionBubble> createState() =>
      _FloatingReactionBubbleState();
}

class _FloatingReactionBubbleState extends State<_FloatingReactionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _translateYAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _translateYAnimation = Tween<double>(begin: 0.0, end: -360.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.9),
        weight: 60.0,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 55.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30.0,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        // Subtle sinusoidal sway on X axis
        final swayX = math.sin(progress * math.pi * 3) * 12.0 +
            widget.reaction.horizontalOffset;

        return Positioned(
          left: 12.0 + swayX,
          bottom: -_translateYAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: widget.reaction.isEmoji
          ? _buildEmojiBubble()
          : _buildTextBubble(),
    );
  }

  Widget _buildEmojiBubble() {
    return Container(
      padding: const EdgeInsets.all(7.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accentElectricSky.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        widget.reaction.content,
        style: const TextStyle(fontSize: 26.0),
      ),
    );
  }

  Widget _buildTextBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.accentNeonCyan.withValues(alpha: 0.40),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(
            avatar: widget.reaction.senderAvatar,
            size: 18.0,
            borderWidth: 1.0,
            borderColor: AppColors.accentNeonCyan,
          ),
          const SizedBox(width: 6.0),
          Text(
            widget.reaction.content,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accentNeonCyan,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Borderless bouncy emoji button in the spectator dock.
class _BorderlessEmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _BorderlessEmojiButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_BorderlessEmojiButton> createState() => _BorderlessEmojiButtonState();
}

class _BorderlessEmojiButtonState extends State<_BorderlessEmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.82,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _scaleController.reverse();
  void _onTapUp(TapUpDetails details) {
    _scaleController.forward();
    widget.onTap();
  }

  void _onTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 21.0),
          ),
        ),
      ),
    );
  }
}

/// Clean typographic text taunt button in the spectator dock (no bulky pills).
class _TypographicTauntButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _TypographicTauntButton({
    required this.text,
    required this.onTap,
  });

  @override
  State<_TypographicTauntButton> createState() => _TypographicTauntButtonState();
}

class _TypographicTauntButtonState extends State<_TypographicTauntButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.forward(),
      child: ScaleTransition(
        scale: _scaleController,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
          child: Text(
            widget.text,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accentNeonCyan,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
