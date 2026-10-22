import 'package:flutter/material.dart';

/// One game in the lobby. Add a game here and it appears in the lobby.
@immutable
class LobbyGame {
  /// Same id as `CloudMatch.game` ('basketball', 'archery', 'darts').
  final String id;
  final String title;

  /// One line under the tile.
  final String tagline;

  /// Longer copy for the featured banner.
  final String pitch;

  /// Small line above the title on this game's banner slide.
  final String heroLabel;

  final Color accent;

  /// Tile art (gameplay) and how to crop it.
  final String image;
  final Alignment imageAlignment;

  /// Banner art: a wide image for desktop and a tall one for phones, each
  /// with its focus point.
  final String heroImage;
  final Alignment heroAlignment;
  final String heroImageNarrow;
  final Alignment heroAlignmentNarrow;

  /// Where the game opens (a GoRouter path).
  final String route;

  /// False: shown greyed with "Coming soon" (still opens its preview).
  final bool available;

  /// The banner's lead: first slide, shown longest, ringed in the shelf
  /// (first one wins).
  final bool featured;

  const LobbyGame({
    required this.id,
    required this.title,
    required this.tagline,
    required this.pitch,
    required this.accent,
    required this.image,
    required this.route,
    this.heroLabel = '',
    this.imageAlignment = Alignment.center,
    String? heroImage,
    this.heroAlignment = Alignment.center,
    String? heroImageNarrow,
    this.heroAlignmentNarrow = Alignment.center,
    this.available = true,
    this.featured = false,
  })  : heroImage = heroImage ?? image,
        heroImageNarrow = heroImageNarrow ?? heroImage ?? image;
}

/// The games in GameVerse, in lobby order.
const List<LobbyGame> lobbyGames = [
  LobbyGame(
    id: 'basketball',
    title: 'Hoops',
    tagline: "Sixty seconds, one hoop. Beat your rival's score.",
    pitch: 'Sixty seconds on the clock. Swish, bank and catch fire on the way past a friend.',
    heroLabel: 'The original',
    accent: Color(0xFFF59E0B),
    image: 'assets/lobby/hoops.webp',
    heroImage: 'assets/lobby/hoops_hero.webp',
    heroAlignment: Alignment.centerRight,
    heroImageNarrow: 'assets/lobby/hoops_poster.webp',
    route: '/hoops',
  ),
  LobbyGame(
    id: 'archery',
    title: 'Archery',
    tagline: 'Read the wind and hit the gold.',
    pitch: 'Three arrows a set, and the wind changes every shot. First archer to six set points wins.',
    heroLabel: 'New this week',
    accent: Color(0xFF00FFCC),
    image: 'assets/lobby/archery.webp',
    heroImage: 'assets/lobby/archery_hero.webp',
    heroAlignment: Alignment.center,
    // Phones: the wind pill, the target and the apple tree all in frame.
    heroAlignmentNarrow: Alignment(0.16, 0),
    route: '/archery',
    featured: true,
  ),
  LobbyGame(
    id: 'darts',
    title: 'Darts',
    tagline: '501 and Cricket, thrown with a flick.',
    pitch: '501 and Cricket, thrown with a flick. Still in the workshop.',
    heroLabel: 'Coming soon',
    accent: Color(0xFFEF4444),
    image: 'assets/lobby/darts.webp',
    imageAlignment: Alignment(0, -0.3),
    heroImage: 'assets/lobby/darts_hero.webp',
    heroAlignment: Alignment.centerRight,
    heroImageNarrow: 'assets/lobby/darts.webp',
    route: '/darts',
    available: false,
  ),
];

LobbyGame get featuredGame =>
    lobbyGames.firstWhere((g) => g.featured, orElse: () => lobbyGames.first);

/// Banner slides: the featured game first, then the rest in lobby order.
List<LobbyGame> get heroGames => [
      featuredGame,
      for (final g in lobbyGames)
        if (!identical(g, featuredGame)) g,
    ];

/// The lobby entry for a `CloudMatch.game` id (falls back to basketball).
LobbyGame lobbyGameById(String id) =>
    lobbyGames.firstWhere((g) => g.id == id, orElse: () => lobbyGames.first);
