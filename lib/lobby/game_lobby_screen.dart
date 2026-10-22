import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../game/ui/common/app_avatar.dart';
import '../game/ui/common/edit_profile_dialog.dart';
import '../game/ui/inbox/match_inbox_sheet.dart';
import '../models/cloud_match.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';

/// The central GameVerse arcade lobby (`/games`).
///
/// Features:
/// - Top header with player account chip for profile / avatar customization.
/// - Active matches strip with 1-tap jump to MatchInboxSheet.
/// - Responsive card grid for DunkVerse (Basketball), Archery, and Darts.
class GameLobbyScreen extends HookConsumerWidget {
  const GameLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final myUid = profile?.uid ?? '';
    final matches = ref.watch(userMatchesProvider).value ?? const <CloudMatch>[];

    final activeMatches = matches.where((m) => m.status == MatchStatus.active).toList();
    final yourTurnMatches = activeMatches.where((m) => m.isMyTurn(myUid)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Top App Bar with Branding & Account Chip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00FFCC), Color(0xFF38BDF8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FFCC).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sports_esports_rounded,
                            size: 20,
                            color: Color(0xFF060913),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'GAMEVERSE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '1v1 MULTIPLAYER ARCADE',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Account Chip (taps to EditProfileDialog)
                    _AccountChip(
                      profile: profile,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        EditProfileDialog.show(context, profile: profile);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 2. Active Matches Banner / Inbox Strip
            if (activeMatches.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      MatchInboxSheet.show(
                        context,
                        onPlayMatch: (m) => context.go('/match/${m.id}'),
                        onCreateMatch: () => context.go('/'),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            yourTurnMatches.isNotEmpty
                                ? const Color(0xFF064E3B)
                                : const Color(0xFF1E293B),
                            const Color(0xFF0F172A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: yourTurnMatches.isNotEmpty
                              ? const Color(0xFF10B981)
                              : const Color(0xFF334155),
                          width: 1.2,
                        ),
                        boxShadow: [
                          if (yourTurnMatches.isNotEmpty)
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.18),
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
                              color: yourTurnMatches.isNotEmpty
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : const Color(0x3364748B),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 18,
                              color: yourTurnMatches.isNotEmpty
                                  ? const Color(0xFF34D399)
                                  : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  yourTurnMatches.isNotEmpty
                                      ? 'YOUR TURN IN ${yourTurnMatches.length} MATCH${yourTurnMatches.length > 1 ? "ES" : ""}!'
                                      : '${activeMatches.length} ACTIVE MATCH${activeMatches.length > 1 ? "ES" : ""}',
                                  style: TextStyle(
                                    color: yourTurnMatches.isNotEmpty
                                        ? const Color(0xFF34D399)
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to view your 1v1 match inbox',
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
                  ),
                ),
              ),

            // 3. Section Title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'SELECT A GAME',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            // 4. Responsive Game Cards Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.crossAxisExtent > 720 ? 3 : (constraints.crossAxisExtent > 500 ? 2 : 1);

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 220,
                    ),
                    delegate: SliverChildListDelegate([
                      // 1. Basketball (DunkVerse)
                      _GameCard(
                        title: 'DunkVerse',
                        category: 'BASKETBALL',
                        badge: 'POPULAR',
                        badgeColor: const Color(0xFFFF8A00),
                        icon: Icons.sports_basketball_rounded,
                        accentColor: const Color(0xFFFF6B00),
                        gradientColors: const [Color(0xFF26130A), Color(0xFF131826)],
                        description: 'Arcade 1v1 hoop shootout. Beat the clock, rack up clean swishes, and challenge friends.',
                        features: '2–4 Rounds • 30–60s Clock • Physics',
                        buttonLabel: 'PLAY HOOPS',
                        onTap: () => context.go('/'),
                      ),

                      // 2. Archery (GamePigeon Style)
                      _GameCard(
                        title: 'Archery',
                        category: 'PRECISION',
                        badge: 'NEW',
                        badgeColor: const Color(0xFF10B981),
                        icon: Icons.track_changes_rounded,
                        accentColor: const Color(0xFF00FFCC),
                        gradientColors: const [Color(0xFF06281E), Color(0xFF131826)],
                        description: 'GamePigeon-style set archery. Compensate for real-time wind, hold steady, and hit the X-ring.',
                        features: '3 Sets • 50/100/150 ft • 3D Physics',
                        buttonLabel: 'PLAY ARCHERY',
                        onTap: () => context.go('/archery'),
                      ),

                      // 3. Darts (501 / Cricket)
                      _GameCard(
                        title: 'Darts',
                        category: 'TARGET',
                        badge: 'COMING SOON',
                        badgeColor: const Color(0xFFA855F7),
                        icon: Icons.adjust_rounded,
                        accentColor: const Color(0xFFA855F7),
                        gradientColors: const [Color(0xFF1F1033), Color(0xFF131826)],
                        description: 'Regulation 501 countdown & tactical Cricket. Flick throw mechanics with double-out finishes.',
                        features: '501 Rules • Cricket • Flick Mechanics',
                        buttonLabel: 'PREVIEW',
                        onTap: () => context.go('/darts'),
                      ),
                    ]),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }
}

/// Header account chip showing user avatar, name, and edit trigger.
class _AccountChip extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback onTap;

  const _AccountChip({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF131826),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E3954), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              avatar: profile?.avatarEmoji ?? AppAvatar.defaultAvatar,
              size: 28,
              borderColor: const Color(0xFF00FFCC),
              borderWidth: 1.5,
              showGlow: false,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                profile?.displayName ?? 'Player',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF00FFCC)),
          ],
        ),
      ),
    );
  }
}

/// Polished Game selection card with gradient background, badges, and action button.
class _GameCard extends StatelessWidget {
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
  final VoidCallback onTap;

  const _GameCard({
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
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category, Badge, Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Expanded(
                  child: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),

                // Specs / Features line
                Text(
                  features,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onTap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: const Color(0xFF060913),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
