import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized, high-performance avatar widget for the entire application.
///
/// Automatically determines whether [avatar] is an image asset path (e.g.
/// `assets/avatars/dunk_heads (1).webp`) or a legacy emoji string, rendering
/// an edge-to-edge clipped circular headshot with transparent background
/// and optional illuminated status ring.
class AppAvatar extends StatelessWidget {
  /// The avatar identifier: either a valid asset path or an emoji character.
  final String avatar;

  /// Diameter of the circular avatar badge in logical pixels.
  final double size;

  /// Optional border color for active turn / player ring highlights.
  final Color? borderColor;

  /// Width of the circular border stroke when [borderColor] is set.
  final double borderWidth;

  /// Whether to render an energetic illuminated glow halo behind the border.
  final bool showGlow;

  /// Glow color for the shadow halo (defaults to [borderColor] or [AppColors.accentNeonCyan]).
  final Color? glowColor;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Fallback avatar asset path when the provided string is missing or fails.
  static const String defaultAvatar = 'assets/avatars/dunk_heads (1).webp';

  const AppAvatar({
    super.key,
    required this.avatar,
    this.size = 36.0,
    this.borderColor,
    this.borderWidth = 1.5,
    this.showGlow = false,
    this.glowColor,
    this.onTap,
  });

  /// Helper to test if a given avatar string points to a local image asset.
  static bool isImageAsset(String path) {
    return path.startsWith('assets/') ||
        path.endsWith('.webp') ||
        path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg');
  }

  Widget _buildContent() {
    if (isImageAsset(avatar)) {
      return ClipOval(
        child: Image.asset(
          avatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Text('🏀', style: TextStyle(fontSize: size * 0.5)),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        avatar.isEmpty ? '🏀' : avatar,
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget;

    if (borderColor != null || showGlow) {
      avatarWidget = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: (glowColor ?? borderColor ?? AppColors.accentNeonCyan)
                        .withValues(alpha: 0.35),
                    blurRadius: 10.0,
                    spreadRadius: 1.0,
                  ),
                ]
              : null,
        ),
        child: _buildContent(),
      );
    } else {
      avatarWidget = SizedBox(
        width: size,
        height: size,
        child: _buildContent(),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
