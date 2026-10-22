/// Match rules shared by solo play, online play and the Firestore turn
/// transaction (pure Dart, no Flutter).
///
/// GamePigeon-style set scoring: each set is 3 arrows; the higher set total
/// earns 2 set points, a tie earns 1 point each. First to 6 set points wins.
/// Capped at [maxSets] sets; after that the higher point total wins (or a draw).
abstract final class ArcheryRules {
  static const int arrowsPerSet = 3;
  static const int pointsForSetWin = 2;
  static const int pointsForSetTie = 1;
  static const int pointsToWin = 6;
  static const int maxSets = 5;

  /// Highest possible set total (three 10s).
  static const int maxSetScore = arrowsPerSet * 10;

  /// Seconds each archer gets per arrow in online play.
  static const int shotClockSeconds = 25;

  /// Stored as the match's `roundDurationSeconds`: one set (3 arrows) plus
  /// slack. The "claim win" rule waits this long + 50 s after a turn starts.
  static const int onlineSetSeconds = 120;

  /// Set points from per-set totals. Only sets both archers have shot count.
  static ({int you, int them}) setPoints(List<int> you, List<int> them) {
    final int n = you.length < them.length ? you.length : them.length;
    int a = 0;
    int b = 0;
    for (int i = 0; i < n; i++) {
      if (you[i] > them[i]) {
        a += pointsForSetWin;
      } else if (you[i] < them[i]) {
        b += pointsForSetWin;
      } else {
        a += pointsForSetTie;
        b += pointsForSetTie;
      }
    }
    return (you: a, them: b);
  }

  /// True once someone reached [pointsToWin] or all [maxSets] sets are shot.
  static bool isMatchOver(List<int> you, List<int> them) {
    final p = setPoints(you, them);
    final int completedSets = you.length < them.length ? you.length : them.length;
    return p.you >= pointsToWin || p.them >= pointsToWin || completedSets >= maxSets;
  }

  /// +1 you won, −1 they won, 0 draw (call once [isMatchOver]).
  static int winner(List<int> you, List<int> them) {
    final p = setPoints(you, them);
    return p.you > p.them ? 1 : (p.you < p.them ? -1 : 0);
  }

  /// Deterministic per-match seed (wind and sway) from the match id, so both
  /// archers get identical conditions without storing anything extra.
  static int seedFromMatchId(String matchId) {
    // Small multipliers only: exact on the web too (JS numbers), so every
    // platform computes the same seed.
    int h = 17;
    for (final int c in matchId.trim().toUpperCase().codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h == 0 ? 1 : h;
  }
}
