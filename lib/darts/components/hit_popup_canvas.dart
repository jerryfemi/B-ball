import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import '../scene/board_projection.dart';

/// Renders score callout pops and BUST / CHECKOUT banners upon dart impact.
///
/// - Priority 8 (topmost visual layer).
/// - Score pop, GamePigeon style: the points as a big white number with a
///   dark outline ("60", "25", "MISS"), popping up over the dart then
///   floating up and fading.
/// - Prominent red BUST or mint CHECKOUT banner triggered on turn-ending events.
/// - Paragraph layouts generated on hit event; zero heap allocations per frame in `render()`.
class HitPopupCanvas extends Component {
  final BoardProjection projection;

  // ─── Score Pop State ───────────────────────────────────────────────────────
  bool _popActive = false;
  double _popTimer = 0.0;
  static const double _popDuration = 1.0;

  double _popBasePxX = 0.0;
  double _popBasePxY = 0.0;
  ui.Paragraph? _popParagraph;
  ui.Paragraph? _popOutline;
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
  final ui.Paint _fadePaint = ui.Paint();

  HitPopupCanvas({required this.projection}) : super(priority: 8);

  /// Shows the floating score over the landed dart.
  void showHit(DartHit hit, {bool isBust = false, bool isCheckout = false}) {
    if (hit.isMiss) {
      // Off the board: show it just inside the edge, nearest the dart.
      final double r = DartsK.boardR * 0.9;
      final double d = hit.r > 1e-6 ? hit.r : 1.0;
      projection.boardMmToScreen(hit.x / d * r, hit.y / d * r, _screenPos);
    } else {
      projection.boardMmToScreen(hit.x, hit.y, _screenPos);
    }
    _popBasePxX = _screenPos.x;
    _popBasePxY = _screenPos.y - projection.boardRadiusPx * 0.16;
    _popTimer = 0.0;
    _popActive = true;

    final String label = hit.isMiss ? 'MISS' : '${hit.points}';
    final double size = (projection.boardRadiusPx * (hit.isMiss ? 0.17 : 0.24))
        .clamp(20.0, 72.0)
        .toDouble();
    final ui.Color fill = hit.isMiss
        ? const ui.Color(0xFFFFB4B4)
        : const ui.Color(0xFFFFFFFF);

    _popParagraph?.dispose();
    _popOutline?.dispose();
    _popOutline = _buildText(
      text: label,
      fontSize: size,
      fontWeight: ui.FontWeight.w900,
      letterSpacing: 0.0,
      foreground: ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = size * 0.16
        ..strokeJoin = ui.StrokeJoin.round
        ..color = const ui.Color(0xFF0A0E1A),
    );
    _popParagraph = _buildText(
      text: label,
      color: fill,
      fontSize: size,
      fontWeight: ui.FontWeight.w900,
      letterSpacing: 0.0,
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
    ui.Color color = const ui.Color(0xFFFFFFFF),
    required double fontSize,
    required ui.FontWeight fontWeight,
    double letterSpacing = 0.5,
    ui.Paint? foreground,
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
              color: foreground == null ? color : null,
              foreground: foreground,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
            ),
          )
          ..addText(text);

    final paragraph = builder.build();
    // Lay out once to measure, then again at the text's own width: centred
    // text in a wider box was drawn off to the side of where it was placed
    // (the old score pill sat to the left of its text).
    paragraph.layout(const ui.ParagraphConstraints(width: 1000.0));
    paragraph.layout(
      ui.ParagraphConstraints(width: paragraph.maxIntrinsicWidth.ceilToDouble() + 1.0),
    );
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
        _popOutline?.dispose();
        _popOutline = null;
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

    // 1. Score pop: overshoot in, float up, fade out.
    if (_popActive && _popParagraph != null && _popOutline != null) {
      final double t = _popTimer;
      final double progress = (t / _popDuration).clamp(0.0, 1.0).toDouble();
      final double scale = t < 0.09
          ? 0.35 + 0.90 * (t / 0.09)
          : (t < 0.20 ? 1.25 - 0.25 * ((t - 0.09) / 0.11) : 1.0);
      final double ease = 1.0 - (1.0 - progress) * (1.0 - progress);
      final double y = _popBasePxY - projection.boardRadiusPx * 0.22 * ease;
      final double alpha =
          progress < 0.7 ? 1.0 : ((1.0 - progress) / 0.3).clamp(0.0, 1.0).toDouble();

      if (alpha > 0.0) {
        canvas.save();
        canvas.translate(_popBasePxX, y);
        canvas.scale(scale);
        final ui.Offset at = ui.Offset(-_popWidth * 0.5, -_popHeight * 0.5);
        if (alpha < 1.0) {
          canvas.saveLayer(null, _fadePaint..color = ui.Color.fromARGB((alpha * 255).round(), 0, 0, 0));
        }
        canvas.drawParagraph(_popOutline!, at);
        canvas.drawParagraph(_popParagraph!, at);
        if (alpha < 1.0) canvas.restore();
        canvas.restore();
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
    _popOutline?.dispose();
    _bannerParagraph?.dispose();
    super.onRemove();
  }
}
