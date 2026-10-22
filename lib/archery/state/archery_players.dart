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
}

@immutable
class ArcheryPlayers {
  final ArcheryPlayer you;
  final ArcheryPlayer opponent;

  const ArcheryPlayers({required this.you, required this.opponent});
}

/// The two players on the scoreboard.
///
/// The standalone dev build (main_archery.dart) has no Firebase, so it shows
/// the default avatar. Inside the app, override this in the ProviderScope
/// with the signed-in profile (and the opponent's profile in online matches):
///
/// ```dart
/// archeryPlayersProvider.overrideWith((ref) {
///   final me = ref.watch(currentUserProfileProvider).value;
///   return ArcheryPlayers(
///     you: ArcheryPlayer(name: me?.gamerTag ?? 'You', avatar: me?.avatar ?? ...),
///     opponent: ...,
///   );
/// })
/// ```
final archeryPlayersProvider = Provider<ArcheryPlayers>(
  (ref) => const ArcheryPlayers(
    you: ArcheryPlayer(name: 'You', avatar: PlayerDescriptor.defaultAvatar),
    opponent: ArcheryPlayer(
      name: 'Bot',
      avatar: 'assets/avatars/dunk_heads (2).webp',
    ),
  ),
);
