import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery/archery_game_screen.dart';
import '../darts/darts_game_screen.dart';
import '../game/audio/audio_engine.dart';
import '../game/basketball_game.dart';
import '../game/ui/common/inline_feedback.dart';
import '../game/ui/game_hud_overlay.dart';
import '../models/cloud_match.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import 'package:flame/game.dart';

/// Route screen for `/match/:id`.
///
/// Fetches the match document from Firestore, detects which game it belongs to
/// (`match.game`), and dispatches to the correct game screen (Basketball, Archery, Darts).
class MatchRouteScreen extends ConsumerStatefulWidget {
  final String matchId;

  const MatchRouteScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchRouteScreen> createState() => _MatchRouteScreenState();
}

class _MatchRouteScreenState extends ConsumerState<MatchRouteScreen> {
  CloudMatch? _match;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  @override
  void didUpdateWidget(covariant MatchRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId) {
      _loadMatch();
    }
  }

  Future<void> _loadMatch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // A shared link may be the first thing a player opens: sign in first
      // (silent guest sign-in), since matches are only readable signed in.
      final me = AuthService.instance.currentUser ??
          await AuthService.instance.initialize();
      CloudMatch? match = await FirestoreMatchService.instance.getMatch(widget.matchId);
      if (!mounted) return;
      if (match == null) {
        _fail('Match not found or has expired.');
        return;
      }

      // /match/CODE doubles as the invite link: take the empty seat.
      if (!match.isParticipant(me.uid)) {
        if (match.status == MatchStatus.waitingForOpponent && match.player2 == null) {
          match = await FirestoreMatchService.instance.joinMatchByCode(
            joinCode: match.joinCode,
            player2Profile: me,
          );
          if (!mounted) return;
        } else if (match.isFinished) {
          _fail('This match has already finished.');
          return;
        } else {
          _fail('This match already has two players.');
          return;
        }
      }

      setState(() {
        _match = match;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _fail(InlineErrorPanel.friendlyMessage(
        e,
        fallback: 'Couldn\'t load this match. Check your connection and try again.',
      ));
    }
  }

  void _fail(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF00FFCC),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'LOADING MATCH...',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _match == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Unable to find match',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _loadMatch,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('RETRY'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFCC),
                      side: const BorderSide(color: Color(0xFF00FFCC)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/games'),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('GO TO LOBBY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final match = _match!;

    // 1. Archery match
    if (match.isArchery) {
      return ArcheryGameScreen(
        key: ValueKey(match.id),
        match: match,
      );
    }

    // 2. Darts match
    if (match.isDarts) {
      return DartsGameScreen(
        key: ValueKey(match.id),
        match: match,
      );
    }

    // 3. Basketball (DunkVerse) match
    return _BasketballMatchHarness(
      key: ValueKey(match.id),
      match: match,
    );
  }
}

class _BasketballMatchHarness extends StatefulWidget {
  final CloudMatch match;

  const _BasketballMatchHarness({super.key, required this.match});

  @override
  State<_BasketballMatchHarness> createState() => _BasketballMatchHarnessState();
}

class _BasketballMatchHarnessState extends State<_BasketballMatchHarness> {
  late final BasketballGame _game;

  @override
  void initState() {
    super.initState();
    _game = BasketballGame();
    // Basketball's playlist plays only while a basketball screen is open.
    AudioEngine.claimSoundtrack(_game);
    _game.onOtherGameMatch = (m) {
      if (mounted) context.go('/match/${m.id}');
    };
    // Launch cloud match once game is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final myUid = AuthService.instance.currentUser?.uid ?? '';
      _game.startCloudMatch(widget.match, myUid);
    });
  }

  @override
  void dispose() {
    AudioEngine.releaseSoundtrack(_game);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: GameWidget<BasketballGame>(
        game: _game,
        overlayBuilderMap: {
          'HUD': (context, game) => GameHudOverlay(game: game),
        },
        initialActiveOverlays: const ['HUD'],
      ),
    );
  }
}
