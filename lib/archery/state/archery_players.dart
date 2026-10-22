import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/player_descriptor.dart';

/// Who is shown on the archery scoreboard.
@immutable
class ArcheryPlayer {
  final String name;

  /// Anything [AppAvatar] can draw: asset path, data URI, URL or emoji.
  final String avatar;

  const ArcheryPlayer({required this.name, required this.avatar});

  @override
  bool operator ==(Object other) =>
      other is ArcheryPlayer && other.name == name && other.avatar == avatar;

  @override
  int get hashCode => Object.hash(name, avatar);
}

@immutable
class ArcheryPlayers {
  final ArcheryPlayer you;
  final ArcheryPlayer opponent;

  const ArcheryPlayers({required this.you, required this.opponent});

  static const ArcheryPlayer defaultYou =
      ArcheryPlayer(name: 'You', avatar: PlayerDescriptor.defaultAvatar);
  static const ArcheryPlayer bot =
      ArcheryPlayer(name: 'Bot', avatar: 'assets/avatars/dunk_heads (2).webp');

  @override
  bool operator ==(Object other) =>
      other is ArcheryPlayers && other.you == you && other.opponent == opponent;

  @override
  int get hashCode => Object.hash(you, opponent);
}

/// The two players on the scoreboard. The archery screen sets them: the
/// signed-in profile vs the bot in solo play, both profiles online.
class ArcheryPlayersNotifier extends Notifier<ArcheryPlayers> {
  @override
  ArcheryPlayers build() => const ArcheryPlayers(
        you: ArcheryPlayers.defaultYou,
        opponent: ArcheryPlayers.bot,
      );

  void set(ArcheryPlayers players) {
    if (state != players) state = players;
  }
}

final archeryPlayersProvider =
    NotifierProvider<ArcheryPlayersNotifier, ArcheryPlayers>(
  ArcheryPlayersNotifier.new,
);
