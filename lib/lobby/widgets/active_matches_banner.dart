import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/inbox/match_inbox_sheet.dart';
import '../../models/cloud_match.dart';
import '../../providers/app_providers.dart';

/// "YOUR TURN IN 2 MATCHES!" strip that opens the match inbox. Hidden when
/// there are no active matches. Watches the match list itself, so match
/// updates rebuild only this strip, not the whole lobby.
class ActiveMatchesBanner extends ConsumerWidget {
  const ActiveMatchesBanner({super.key});

  static const Color _turnGreen = Color(0xFF10B981);
  static const Color _turnGreenText = Color(0xFF34D399);

  static void openInbox(BuildContext context) {
    MatchInboxSheet.show(
      context,
      // Every game opens through /match/:id, which picks the right screen.
      onPlayMatch: (m) => context.go('/match/${m.id}'),
      onCreateMatch: () => context.go('/'),
      onViewPodium: (m) => context.go('/match/${m.id}'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProfileProvider.select((p) => p.value?.uid ?? ''));
    final matches = ref.watch(userMatchesProvider).value ?? const <CloudMatch>[];
    final active = matches.where((m) => m.status == MatchStatus.active).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final int yourTurn = active.where((m) => m.isMyTurn(myUid)).length;
    final bool hot = yourTurn > 0;
    final String title = hot
        ? 'YOUR TURN IN $yourTurn MATCH${yourTurn > 1 ? 'ES' : ''}!'
        : '${active.length} ACTIVE MATCH${active.length > 1 ? 'ES' : ''}';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        openInbox(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hot ? const Color(0xFF064E3B) : const Color(0xFF1E293B),
              const Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hot ? _turnGreen : const Color(0xFF334155),
            width: 1.2,
          ),
          boxShadow: [
            if (hot)
              BoxShadow(
                color: _turnGreen.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hot ? _turnGreen.withValues(alpha: 0.2) : const Color(0x3364748B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 18,
                color: hot ? _turnGreenText : Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: hot ? _turnGreenText : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to open your match inbox',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}
