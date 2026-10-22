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

  /// Small line above the title in the featured banner.
  final String featuredLabel;

  final Color accent;

  /// Tile art (gameplay) and how to crop it.
  final String image;
  final Alignment imageAlignment;

  /// Banner art: wide crop, plus a focus point for tall phone banners.
  final String heroImage;
  final Alignment heroAlignment;
  final Alignment heroAlignmentNarrow;

  /// Where the game opens (a GoRouter path).
  final String route;

  /// False: shown greyed with "Coming soon" (still opens its preview).
  final bool available;

  /// Shown as the big banner at the top of the lobby (first one wins).
  final bool featured;

  const LobbyGame({
    required this.id,
    required this.title,
    required this.tagline,
    required this.pitch,
    required this.accent,
    required this.image,
    required this.route,
    this.featuredLabel = '',
    this.imageAlignment = Alignment.center,
    String? heroImage,
    this.heroAlignment = Alignment.center,
    this.heroAlignmentNarrow = Alignment.center,
    this.available = true,
    this.featured = false,
  }) : heroImage = heroImage ?? image;
}

/// The games in GameVerse, in lobby order.
const List<LobbyGame> lobbyGames = [
  LobbyGame(
    id: 'basketball',
    title: 'Hoops',
    tagline: "Sixty seconds, one hoop. Beat your rival's score.",
    pitch: 'Sixty seconds on the clock. Swish, bank and streak your way past a friend.',
    accent: Color(0xFFF59E0B),
    image: 'assets/lobby/hoops.webp',
    imageAlignment: Alignment(0, -0.2),
    route: '/',
  ),
  LobbyGame(
    id: 'archery',
    title: 'Archery',
    tagline: 'Read the wind and hit the gold.',
    pitch: 'Three arrows a set, and the wind changes every shot. First archer to six set points wins.',
    featuredLabel: 'New this week',
    accent: Color(0xFF00FFCC),
    image: 'assets/lobby/archery.webp',
    heroImage: 'assets/lobby/archery_hero.webp',
    heroAlignment: Alignment.center,
    heroAlignmentNarrow: Alignment(0.3, 0),
    route: '/archery',
    featured: true,
  ),
  LobbyGame(
    id: 'darts',
    title: 'Darts',
    tagline: '501 and Cricket, thrown with a flick.',
    pitch: '501 and Cricket, thrown with a flick.',
    accent: Color(0xFFEF4444),
    image: 'assets/lobby/darts.webp',
    imageAlignment: Alignment(0, -0.3),
    route: '/darts',
    available: false,
  ),
];

LobbyGame get featuredGame =>
    lobbyGames.firstWhere((g) => g.featured, orElse: () => lobbyGames.first);

/// The lobby entry for a `CloudMatch.game` id (falls back to basketball).
LobbyGame lobbyGameById(String id) =>
    lobbyGames.firstWhere((g) => g.id == id, orElse: () => lobbyGames.first);
