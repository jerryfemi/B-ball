import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../game/ui/common/app_avatar.dart';
import '../game/ui/common/inline_feedback.dart';
import '../game/ui/common/ui_font.dart';
import '../game/ui/match/incoming_challenge_dialog.dart';
import '../models/cloud_match.dart';
import '../providers/app_providers.dart';
import '../services/firestore_match_service.dart';
import 'app_notices.dart';

/// Colour and icon per source, shared by chips and bubbles.
abstract final class NoticeStyle {
  static Color accent(NoticeSource s) => switch (s) {
        NoticeSource.archery => const Color(0xFF00FFCC),
        NoticeSource.basketball => const Color(0xFFF59E0B),
        NoticeSource.friends => const Color(0xFF38BDF8),
      };

  static String emoji(NoticeSource s) => switch (s) {
        NoticeSource.archery => '🏹',
        NoticeSource.basketball => '🏀',
        NoticeSource.friends => '👥',
      };
}

/// The notification chips, shown at the top of every screen.
///
/// - **Normal:** the newest notice as a card; more stack behind it ("1 of 3").
///   Swipe it sideways to dismiss it for later (it stays in the drawer), or
///   Accept right on the card.
/// - **[live] (in a 1v1):** chips shrink to small bubbles on the right edge,
///   one per source, so nothing covers the game. Tap a bubble to open its
///   card; tap again or swipe to close it.
///
/// [onOpenMatch] takes the player into a match they accepted (each screen
/// knows how). [onBeforeOpen] runs before a dialog opens (e.g. pause solo).
class NoticeStack extends HookConsumerWidget {
  final bool live;
  final ValueChanged<CloudMatch> onOpenMatch;
  final VoidCallback? onBeforeOpen;

  /// Room kept free on the right of the chip (for corner buttons).
  final double rightInset;

  const NoticeStack({
    super.key,
    required this.onOpenMatch,
    this.live = false,
    this.onBeforeOpen,
    this.rightInset = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(visibleNoticesProvider);
    final expanded = useState<NoticeSource?>(null);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (notices.isEmpty) return const SizedBox.shrink();

    if (!live) {
      final top = notices.first;
      return Padding(
        padding: EdgeInsets.only(right: rightInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _Entering(
              reduceMotion: reduceMotion,
              child: _StackedCard(
                key: ValueKey(top.id),
                notice: top,
                count: notices.length,
                onOpenMatch: onOpenMatch,
                onBeforeOpen: onBeforeOpen,
              ),
            ),
          ),
        ),
      );
    }

    // Live 1v1: one bubble per source, newest notice of each.
    final bySource = <NoticeSource, AppNotice>{};
    for (final n in notices) {
      bySource.putIfAbsent(n.source, () => n);
    }
    final open = expanded.value != null ? bySource[expanded.value] : null;
    if (expanded.value != null && open == null) {
      // That notice was answered or dismissed elsewhere.
      WidgetsBinding.instance.addPostFrameCallback((_) => expanded.value = null);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion ? 120 : 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // Grows out of the bubbles on the right and goes back there.
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: reduceMotion
                  ? child
                  : ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(a),
                      alignment: Alignment.centerRight,
                      child: child,
                    ),
            ),
            child: open == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.topRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: NoticeCard(
                        key: ValueKey('live-${open.id}'),
                        notice: open,
                        compact: true,
                        // × dismisses it for later (it stays in the drawer).
                        onClose: () {
                          HapticFeedback.lightImpact();
                          ref.read(dismissedNoticesProvider.notifier).dismiss(open.id);
                          expanded.value = null;
                        },
                        onOpenMatch: onOpenMatch,
                        onBeforeOpen: onBeforeOpen,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in NoticeSource.values)
              if (bySource[s] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Bubble(
                    source: s,
                    selected: expanded.value == s,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      expanded.value = expanded.value == s ? null : s;
                    },
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

/// Slides a new chip down from the top edge (where it seems to come from);
/// with reduced motion, a short fade.
class _Entering extends StatelessWidget {
  final bool reduceMotion;
  final Widget child;
  const _Entering({required this.reduceMotion, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 150 : 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: reduceMotion
            ? c
            : SlideTransition(
                position: Tween(begin: const Offset(0, -0.35), end: Offset.zero).animate(a),
                child: c,
              ),
      ),
      child: child,
    );
  }
}

/// The top card plus a sliver of the next one behind it when there are more.
class _StackedCard extends ConsumerWidget {
  final AppNotice notice;
  final int count;
  final ValueChanged<CloudMatch> onOpenMatch;
  final VoidCallback? onBeforeOpen;

  const _StackedCard({
    super.key,
    required this.notice,
    required this.count,
    required this.onOpenMatch,
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = Dismissible(
      key: ValueKey('dismiss-${notice.id}'),
      direction: DismissDirection.horizontal,
      // A short drag snaps back; a fling or past ~35% dismisses.
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        ref.read(dismissedNoticesProvider.notifier).dismiss(notice.id);
      },
      child: NoticeCard(
        notice: notice,
        countLabel: count > 1 ? '1 of $count' : null,
        onOpenMatch: onOpenMatch,
        onBeforeOpen: onBeforeOpen,
      ),
    );
    if (count < 2) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The next notice peeking out underneath.
        Positioned(
          left: 12,
          right: 12,
          bottom: -7,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xCC141C2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
          ),
        ),
        card,
      ],
    );
  }
}

/// One notice: avatar with the game's badge, who and what, and Accept.
/// Accepting shows progress on the button; a failure turns the card into an
/// inline error with RETRY.
class NoticeCard extends HookConsumerWidget {
  final AppNotice notice;
  final String? countLabel;
  final bool compact;
  final VoidCallback? onClose;
  final ValueChanged<CloudMatch> onOpenMatch;
  final VoidCallback? onBeforeOpen;

  const NoticeCard({
    super.key,
    required this.notice,
    required this.onOpenMatch,
    this.countLabel,
    this.compact = false,
    this.onClose,
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final error = useState<String?>(null);
    final pressed = useState(false);
    final accent = NoticeStyle.accent(notice.source);

    Future<void> accept() async {
      if (busy.value) return;
      final me = ref.read(currentUserProfileProvider).value;
      if (me == null) return;
      HapticFeedback.mediumImpact();
      busy.value = true;
      error.value = null;
      try {
        final mi = notice.matchInvite;
        final fi = notice.friendInvite;
        if (mi != null) {
          onBeforeOpen?.call();
          final joined = await FirestoreMatchService.instance
              .acceptMatchChallenge(invite: mi, recipientProfile: me);
          if (context.mounted) onOpenMatch(joined);
        } else if (fi != null) {
          await ref.read(friendsServiceProvider).acceptFriendInvite(me.uid, fi, myProfile: me);
        }
      } catch (e) {
        if (context.mounted) {
          error.value = InlineErrorPanel.friendlyMessage(e, fallback: 'Couldn\'t accept that.');
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    void openDetails() {
      final mi = notice.matchInvite;
      if (mi == null) return;
      HapticFeedback.selectionClick();
      onBeforeOpen?.call();
      IncomingChallengeDialog.show(context: context, invite: mi, onAccepted: onOpenMatch);
    }

    final Widget body = error.value != null
        ? Row(
            key: const ValueKey('error'),
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: UiFont.style(size: 13, weight: 500, color: const Color(0xFFE2E8F0), height: 1.3),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(label: 'RETRY', color: const Color(0xFFEF4444), onTap: accept),
            ],
          )
        : Row(
            key: const ValueKey('normal'),
            children: [
              _Avatar(notice: notice, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UiFont.style(size: compact ? 14 : 15, weight: 700, letterSpacing: -0.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      countLabel == null ? notice.subtitle : '${notice.subtitle}  ·  $countLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UiFont.style(size: 12.5, weight: 500, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Pill(label: 'Accept', color: accent, busy: busy.value, onTap: accept),
              if (onClose != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                ),
            ],
          );

    // Frosted, slightly dark material so it reads over any game scene.
    return GestureDetector(
      onTapDown: (_) => pressed.value = true,
      onTapCancel: () => pressed.value = false,
      onTapUp: (_) => pressed.value = false,
      onTap: openDetails,
      child: AnimatedScale(
        scale: pressed.value ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.fromLTRB(10, compact ? 8 : 10, compact ? 4 : 10, compact ? 8 : 10),
              decoration: BoxDecoration(
                color: const Color(0xD90F172A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppNotice notice;
  final Color accent;
  const _Avatar({required this.notice, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppAvatar(avatar: notice.avatar, size: 40, borderColor: accent, borderWidth: 1.2),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F172A), width: 2),
              ),
              child: Text(NoticeStyle.emoji(notice.source), style: const TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.color, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0E1A)),
                )
              : Text(label, style: UiFont.style(size: 13.5, weight: 800, color: const Color(0xFF0A0E1A))),
        ),
      ),
    );
  }
}

/// A round bubble on the right edge during a live 1v1: the source's icon and
/// a red dot.
class _Bubble extends StatelessWidget {
  final NoticeSource source;
  final bool selected;
  final VoidCallback onTap;
  const _Bubble({required this.source, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = NoticeStyle.accent(source);
    return Semantics(
      button: true,
      label: switch (source) {
        NoticeSource.archery => 'Archery invite',
        NoticeSource.basketball => 'Hoops invite',
        NoticeSource.friends => 'Friend request',
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? accent.withValues(alpha: 0.22) : const Color(0xEB0F172A),
            border: Border.all(color: accent.withValues(alpha: selected ? 1 : 0.7), width: 1.5),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(NoticeStyle.emoji(source), style: const TextStyle(fontSize: 19)),
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0A0E1A), width: 2),
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
