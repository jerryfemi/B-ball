import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/friend_profile.dart';
import '../models/match_invite.dart';
import '../providers/app_providers.dart';

/// Where a notice came from; picks its colour and its bubble during a live 1v1.
enum NoticeSource { basketball, archery, friends }

/// One thing waiting for the player, from any game: a match invite or a
/// friend request. Every screen (lobby, Hoops, Archery) reads the same list,
/// so an invite shows up wherever the player happens to be.
class AppNotice {
  final String id;
  final NoticeSource source;
  final String name;
  final String avatar;
  final int createdAt;
  final MatchInvite? matchInvite;
  final FriendInvite? friendInvite;

  const AppNotice._({
    required this.id,
    required this.source,
    required this.name,
    required this.avatar,
    required this.createdAt,
    this.matchInvite,
    this.friendInvite,
  });

  factory AppNotice.match(MatchInvite i) => AppNotice._(
        id: 'm:${i.matchId}',
        source: i.isArchery ? NoticeSource.archery : NoticeSource.basketball,
        name: i.hostName,
        avatar: i.hostAvatar,
        createdAt: i.createdAt,
        matchInvite: i,
      );

  factory AppNotice.friend(FriendInvite i) => AppNotice._(
        id: 'f:${i.senderUid}',
        source: NoticeSource.friends,
        name: i.senderName,
        avatar: i.senderAvatar,
        createdAt: i.timestamp,
        friendInvite: i,
      );

  String get title => friendInvite != null
      ? '$name wants to be friends'
      : '$name challenged you';

  String get subtitle => switch (source) {
        NoticeSource.archery => 'Archery · 1v1',
        NoticeSource.basketball => 'Hoops · 1v1',
        NoticeSource.friends => 'Friend request',
      };
}

/// Every pending notice, newest first (dismissed ones included; the drawer
/// lists them all).
final appNoticesProvider = Provider.autoDispose<List<AppNotice>>((ref) {
  final matches = ref.watch(incomingMatchChallengesProvider).value ?? const <MatchInvite>[];
  final friends = ref.watch(incomingInvitesProvider).value ?? const <FriendInvite>[];
  final list = <AppNotice>[
    for (final m in matches)
      if (m.isPending) AppNotice.match(m),
    for (final f in friends)
      if (f.status == 'pending') AppNotice.friend(f),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

/// Notices swiped away "for later". Hidden from the chips, still listed in
/// the drawer. Kept on this device so they stay hidden after a reload.
class DismissedNotices extends Notifier<Set<String>> {
  static const String _key = 'dismissed_notices_v1';

  @override
  Set<String> build() {
    _load();
    return const <String>{};
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_key);
      if (saved != null && saved.isNotEmpty) state = {...state, ...saved};
    } catch (_) {}
  }

  void dismiss(String id) {
    state = {...state, id};
    _save();
  }

  void restore(String id) {
    state = {...state}..remove(id);
    _save();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      // Only the last 200, so the list can't grow forever.
      final list = state.toList();
      await p.setStringList(_key, list.length > 200 ? list.sublist(list.length - 200) : list);
    } catch (_) {}
  }
}

final dismissedNoticesProvider =
    NotifierProvider<DismissedNotices, Set<String>>(DismissedNotices.new);

/// Notices that still show as chips (not swiped away).
final visibleNoticesProvider = Provider.autoDispose<List<AppNotice>>((ref) {
  final all = ref.watch(appNoticesProvider);
  final hidden = ref.watch(dismissedNoticesProvider);
  return [for (final n in all) if (!hidden.contains(n.id)) n];
});
