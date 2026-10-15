/// Models representing the Lagos Life / Vatar Games SDK payloads.
class VatarPlayer {
  final String id;
  final String name;
  final String? avatar;

  const VatarPlayer({
    required this.id,
    required this.name,
    this.avatar,
  });

  @override
  String toString() => 'VatarPlayer(id: $id, name: $name, hasAvatar: ${avatar != null})';
}

class VatarLeaderboardEntry {
  final int rank;
  final String label;
  final int score;

  const VatarLeaderboardEntry({
    required this.rank,
    required this.label,
    required this.score,
  });

  @override
  String toString() => 'VatarLeaderboardEntry(rank: $rank, label: $label, score: $score)';
}

class VatarLeaderboardResult {
  final List<VatarLeaderboardEntry> entries;
  final VatarLeaderboardEntry? me;

  const VatarLeaderboardResult({
    required this.entries,
    this.me,
  });
}

class VatarSession {
  final VatarPlayer? player;
  final String? sessionToken;
  final String mode; // 'live' | 'test' | 'preview'

  const VatarSession({
    this.player,
    this.sessionToken,
    required this.mode,
  });
}
