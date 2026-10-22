import 'package:flutter/material.dart';

/// One game on the lobby grid. Add a game here and it appears in the lobby.
@immutable
class LobbyGame {
  final String title;
  final String category;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final String description;
  final String features;
  final String buttonLabel;

  /// Where the card goes (a GoRouter path).
  final String route;

  const LobbyGame({
    required this.title,
    required this.category,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.description,
    required this.features,
    required this.buttonLabel,
    required this.route,
  });
}

/// The games in GameVerse, in lobby order.
const List<LobbyGame> lobbyGames = [
  LobbyGame(
    title: 'DunkVerse',
    category: 'BASKETBALL',
    badge: 'POPULAR',
    badgeColor: Color(0xFFFF8A00),
    icon: Icons.sports_basketball_rounded,
    accentColor: Color(0xFFFF6B00),
    gradientColors: [Color(0xFF26130A), Color(0xFF131826)],
    description:
        'Arcade 1v1 hoop shootout. Beat the clock, rack up clean swishes, and challenge friends.',
    features: '2–4 Rounds • 30–60s Clock • Physics',
    buttonLabel: 'PLAY HOOPS',
    route: '/',
  ),
  LobbyGame(
    title: 'Archery',
    category: 'PRECISION',
    badge: 'NEW',
    badgeColor: Color(0xFF10B981),
    icon: Icons.track_changes_rounded,
    accentColor: Color(0xFF00FFCC),
    gradientColors: [Color(0xFF06281E), Color(0xFF131826)],
    description:
        'GamePigeon-style set archery. Read the wind, hold steady, and hit the X-ring. Play the bot or go live 1v1.',
    features: 'Sets of 3 • First to 6 • 50/100/150 ft',
    buttonLabel: 'PLAY ARCHERY',
    route: '/archery',
  ),
  LobbyGame(
    title: 'Darts',
    category: 'TARGET',
    badge: 'COMING SOON',
    badgeColor: Color(0xFFA855F7),
    icon: Icons.adjust_rounded,
    accentColor: Color(0xFFA855F7),
    gradientColors: [Color(0xFF1F1033), Color(0xFF131826)],
    description:
        'Regulation 501 countdown & tactical Cricket. Flick throw mechanics with double-out finishes.',
    features: '501 Rules • Cricket • Flick Mechanics',
    buttonLabel: 'PREVIEW',
    route: '/darts',
  ),
];
