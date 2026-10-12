import 'package:flutter/material.dart';

/// Central design system color tokens for the B-Ball UI.
///
/// Provides a Single Source of Truth (SSOT) for surfaces, borders,
/// accents, typography, and interactive state colors across all sheets and dialogs.
abstract final class AppColors {
  // --- Surfaces & Backgrounds ---
  /// Deep dark surface used for bottom sheet modals (e.g. Match Inbox, Friends Hub).
  static const Color surfaceSheet = Color(0xFF0F1420);

  /// Elevated dark surface used for modal dialogs (e.g. Match Setup, Add Friend, Gamer Tag).
  static const Color surfaceDialog = Color(0xFF131826);

  /// Card tile and list item background surface.
  static const Color surfaceTile = Color(0xFF1E2638);

  /// Alternate card background surface for nested or secondary cards.
  static const Color surfaceCard = Color(0xFF161F2E);

  /// Overlay backdrop color (dimming behind bottom sheets and dialogs).
  static const Color backdrop = Color(0xBF000000);

  // --- Borders & Dividers ---
  /// Standard subtle border for modal cards and dialog frames.
  static const Color borderSubtle = Color(0xFF2E3954);

  /// Input field and container outline border.
  static const Color borderInput = Color(0xFF334155);

  /// Top border accent for bottom sheets.
  static const Color borderSheet = Color(0xFF26324A);

  /// Translucent white divider / outline.
  static const Color borderTranslucent = Color(0x33FFFFFF);

  // --- Brand Accents & State Colors ---
  /// Vibrant energetic neon cyan used for primary player turns, active selections, and winning glows.
  static const Color accentNeonCyan = Color(0xFF00FFCC);

  /// Electric sky blue used for secondary player, opponent turns, and information badges.
  static const Color accentElectricSky = Color(0xFF38BDF8);

  /// Vivid green used for success, scores, and victorious outcomes.
  static const Color accentEmerald = Color(0xFF22C55E);

  /// Amber / gold used for ties, podium trophies, and warning badges.
  static const Color accentAmber = Color(0xFFF59E0B);

  /// Fiery crimson used for mute buttons, errors, and destructive actions.
  static const Color accentRed = Color(0xFFEF4444);

  /// In-match chat bubble color for user's own sent messages.
  static const Color bubbleUser = Color(0xFF2563EB);

  // --- Text & Foreground ---
  /// High-contrast pure white for titles and primary labels.
  static const Color textPrimary = Colors.white;

  /// Secondary muted text for subtitles, timestamps, and secondary info.
  static const Color textMuted = Color(0xFF94A3B8);

  /// Subtle gray for placeholder text, tips, and caption labels.
  static const Color textSubtle = Color(0xFF64748B);

  /// Dark slate foreground color for text on bright neon buttons (e.g. Neon Cyan button).
  static const Color buttonDarkText = Color(0xFF0F172A);
}
