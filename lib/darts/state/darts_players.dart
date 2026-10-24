import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/player_descriptor.dart';

/// Representation of a single player on the darts scoreboard.
@immutable
class DartsPlayer {
  final String name;

  /// Anything AppAvatar can draw: asset path, data URI, URL, or emoji.
  final String avatar;

  const DartsPlayer({required this.name, required this.avatar});

  @override
  bool operator ==(Object other) =>
      other is DartsPlayer && other.name == name && other.avatar == avatar;

  @override
  int get hashCode => Object.hash(name, avatar);
}

/// The pair of players currently participating in the darts match.
@immutable
class DartsPlayers {
  final DartsPlayer you;
  final DartsPlayer opponent;

  const DartsPlayers({required this.you, required this.opponent});

  static const DartsPlayer defaultYou =
      DartsPlayer(name: 'You', avatar: PlayerDescriptor.defaultAvatar);

  static const DartsPlayer bot =
      DartsPlayer(name: 'Bot', avatar: 'assets/avatars/dunk_heads (2).webp');

  @override
  bool operator ==(Object other) =>
      other is DartsPlayers && other.you == you && other.opponent == opponent;

  @override
  int get hashCode => Object.hash(you, opponent);
}

/// The two players shown on the scoreboard.
/// Updated when profile loads in solo play (you vs the bot) or on room join in online play.
class DartsPlayersNotifier extends Notifier<DartsPlayers> {
  @override
  DartsPlayers build() => const DartsPlayers(
        you: DartsPlayers.defaultYou,
        opponent: DartsPlayers.bot,
      );

  void set(DartsPlayers players) {
    if (state != players) state = players;
  }
}

final dartsPlayersProvider =
    NotifierProvider<DartsPlayersNotifier, DartsPlayers>(
  DartsPlayersNotifier.new,
);
