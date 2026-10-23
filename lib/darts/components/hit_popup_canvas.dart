import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import '../scene/board_projection.dart';

/// Renders score callout pops and BUST / CHECKOUT banners upon dart impact.
///
/// Follows DARTS_PLAN.md §1.5 & Step 11:
/// - Priority 8 (topmost visual layer).
/// - Score pop rises from the hit point (`T20`, `D16`, `BULL`, `MISS`, etc.) over 0.8s.
/// - Prominent red BUST or mint CHECKOUT banner triggered on turn-ending events.
/// - Paragraph layouts generated on hit event; zero heap allocations per frame in `render()`.
class HitPopupCanvas extends Component {
  final BoardProjection projection;

  // ─── Score Pop State ───────────────────────────────────────────────────────
  bool _popActive = false;
  double _popTimer = 0.0;
  static const double _popDuration = 0.85;

  double _popBasePxX = 0.0;
  double _popBasePxY = 0.0;
  ui.Paragraph? _popParagraph;
  double _popWidth = 0.0;
  double _popHeight = 0.0;

  // ─── Banner State (BUST / CHECKOUT) ────────────────────────────────────────
  bool _bannerActive = false;
  double _bannerTimer = 0.0;
  static const double _bannerDuration = 1.30;
  String _bannerText = '';
  ui.Color _bannerColor = const ui.Color(DartsK.accentRed);
  ui.Paragraph? _bannerParagraph;
  double _bannerWidth = 0.0;
  double _bannerHeight = 0.0;

  final Vector2 _screenPos = Vector2.zero();

  final ui.Paint _bannerBgPaint = ui.Paint()..style = ui.PaintingStyle.fill;
  final ui.Paint _popBgPaint = ui.Paint()
    ..style = ui.PaintingStyle.fill
    ..color = const ui.Color(0xD90A0E1A);

  HitPopupCanvas({required this.projection}) : super(priority: 8);

  /// Shows floating score popup at landed dart coordinates.
  void showHit(DartHit hit, {bool isBust = false, bool isCheckout = false}) {
    projection.boardMmToScreen(hit.x, hit.y, _screenPos);
    _popBasePxX = _screenPos.x;
    _popBasePxY = _screenPos.y - 14.0; // slightly above tip

    _popTimer = 0.0;
    _popActive = true;

    // Pick callout color by hit significance
    final ui.Color textColor;
    if (hit.isInnerBull || hit.isBull) {
      textColor = const ui.Color(DartsK.accentMint);
    } else if (hit.isTreble) {
      textColor = const ui.Color(DartsK.accentP1);
    } else if (hit.isDouble) {
      textColor = const ui.Color(DartsK.accentP2);
    } else if (hit.isMiss) {
      textColor = const ui.Color(DartsK.accentRed);
    } else {
      textColor = const ui.Color(DartsK.textPrimary);
    }

    final String label = hit.isMiss ? 'MISS' : '${hit.label} (+${hit.points})';
    _popParagraph = _buildText(
      text: label,
      color: textColor,
      fontSize: 14.0,
      fontWeight: ui.FontWeight.w900,
    );
    _popWidth = _popParagraph!.maxIntrinsicWidth;
    _popHeight = _popParagraph!.height;

    // Handle BUST or CHECKOUT banner
    if (isBust) {
      _showBanner('BUST!', const ui.Color(DartsK.accentRed));
    } else if (isCheckout) {
      _showBanner('CHECKOUT! 🎯', const ui.Color(DartsK.accentMint));
    }
  }

  void _showBanner(String text, ui.Color color) {
    _bannerText = text;
    _bannerColor = color;
    _bannerTimer = 0.0;
    _bannerActive = true;

    _bannerParagraph = _buildText(
      text: _bannerText,
      color: const ui.Color(0xFFFFFFFF),
      fontSize: 22.0,
      fontWeight: ui.FontWeight.w900,
      letterSpacing: 2.0,
    );
    _bannerWidth = _bannerParagraph!.maxIntrinsicWidth;
    _bannerHeight = _bannerParagraph!.height;
  }

  ui.Paragraph _buildText({
    required String text,
    required ui.Color color,
    required double fontSize,
    required ui.FontWeight fontWeight,
    double letterSpacing = 0.5,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              fontSize: fontSize,
              fontWeight: fontWeight,
              fontFamily: 'Inter',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
            ),
          )
          ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 320.0));
    return paragraph;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_popActive) {
      _popTimer += dt;
      if (_popTimer >= _popDuration) {
        _popActive = false;
        _popParagraph?.dispose();
        _popParagraph = null;
      }
    }

    if (_bannerActive) {
      _bannerTimer += dt;
      if (_bannerTimer >= _bannerDuration) {
        _bannerActive = false;
        _bannerParagraph?.dispose();
        _bannerParagraph = null;
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final double screenW = projection.screenWidth;
    final double screenH = projection.screenHeight;
    if (screenW <= 0.0 || screenH <= 0.0) return;

    // 1. Render rising score popup
    if (_popActive && _popParagraph != null) {
      final double progress = (_popTimer / _popDuration).clamp(0.0, 1.0);
      final double riseY = 26.0 * progress;
      final double currentY = _popBasePxY - riseY;

      final double alpha = progress < 0.65
          ? 1.0
          : ((1.0 - progress) / 0.35).clamp(0.0, 1.0);

      if (alpha > 0.0) {
        final double px = _popBasePxX - (_popWidth * 0.5);
        final double py = currentY - (_popHeight * 0.5);

        // Pill background
        const double padX = 8.0;
        const double padY = 3.0;
        final rect = ui.RRect.fromLTRBR(
          px - padX,
          py - padY,
          px + _popWidth + padX,
          py + _popHeight + padY,
          const ui.Radius.circular(6.0),
        );
        _popBgPaint.color = ui.Color.fromARGB(
          (alpha * 215.0).round(),
          10,
          14,
          26,
        );
        canvas.drawRRect(rect, _popBgPaint);

        canvas.drawParagraph(_popParagraph!, ui.Offset(px, py));
      }
    }

    // 2. Render prominent BUST / CHECKOUT banner across center
    if (_bannerActive && _bannerParagraph != null) {
      final double progress = (_bannerTimer / _bannerDuration).clamp(0.0, 1.0);
      final double alpha = progress < 0.75
          ? 1.0
          : ((1.0 - progress) / 0.25).clamp(0.0, 1.0);

      final double cx = screenW * 0.5;
      final double cy = screenH * 0.38; // just over board center

      const double padX = 24.0;
      const double padY = 8.0;
      final rrect = ui.RRect.fromLTRBR(
        cx - (_bannerWidth * 0.5) - padX,
        cy - (_bannerHeight * 0.5) - padY,
        cx + (_bannerWidth * 0.5) + padX,
        cy + (_bannerHeight * 0.5) + padY,
        const ui.Radius.circular(12.0),
      );

      _bannerBgPaint.color = _bannerColor.withValues(alpha: alpha * 0.92);
      canvas.drawRRect(rrect, _bannerBgPaint);

      canvas.drawParagraph(
        _bannerParagraph!,
        ui.Offset(cx - (_bannerWidth * 0.5), cy - (_bannerHeight * 0.5)),
      );
    }
  }

  @override
  void onRemove() {
    _popParagraph?.dispose();
    _bannerParagraph?.dispose();
    super.onRemove();
  }
}
