import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import '../performance/adaptive_quality.dart';
import 'glow_sprite.dart';

/// Streak tiers, matching the ball's existing effects:
/// lightning 3–5, fire 6–9, inferno 10+.
enum StreakTier { none, lightning, fire, inferno }

StreakTier streakTierFor(int streak) {
  if (streak >= 10) return StreakTier.inferno;
  if (streak >= 6) return StreakTier.fire;
  if (streak >= 3) return StreakTier.lightning;
  return StreakTier.none;
}

/// Visual reward layer for streaks, drawn at the hoop:
///  • every streak make: shockwave ring across the rim + spark spray through the net
///  • tier-ups (3, 6, 10): double shockwave, bigger spray, stronger zoom punch,
///    and a quick tinted flash over the court ([flashAlpha], drawn by the game)
///  • while the player is on a streak: the rim glows and pulses in tier colors
///
/// Performance: every particle lives in preallocated typed arrays; colors with
/// alpha come from precomputed lookup tables; the glow is a cached sprite.
/// Zero allocations per frame. Spark count follows [AdaptiveQuality].
class StreakCelebration extends PositionComponent
    with HasGameReference<BasketballGame> {
  StreakCelebration({required Vector2 hoopCenter, required this.hoopWidth})
    : super(position: hoopCenter, priority: 5);

  final double hoopWidth;

  // ── Palettes (3 colors per tier) ─────────────────────────────────────────
  static const List<List<Color>> _palettes = [
    [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)], // none (unused)
    [Color(0xFFFFFFFF), Color(0xFF38BDF8), Color(0xFF818CF8)], // lightning
    [Color(0xFFFFFBEB), Color(0xFFFFB020), Color(0xFFFF5500)], // fire
    [Color(0xFFFFE27A), Color(0xFFFF2E2E), Color(0xFFFFC31E)], // inferno
  ];

  /// Main accent per tier (ring, glow, flash).
  static const List<Color> _accent = [
    Color(0xFFFFFFFF),
    Color(0xFF38BDF8),
    Color(0xFFFF7A18),
    Color(0xFFFF3B1F),
  ];

  static const int _alphaSteps = 32;

  /// [tier][colorIndex][alphaStep] — built once, so alpha changes never allocate.
  static final List<List<List<Color>>> _particleColors = List.generate(
    _palettes.length,
    (t) => List.generate(
      3,
      (c) => List.generate(
        _alphaSteps,
        (a) => _palettes[t][c].withValues(alpha: a / (_alphaSteps - 1)),
        growable: false,
      ),
      growable: false,
    ),
    growable: false,
  );

  static final List<List<Color>> _accentColors = List.generate(
    _accent.length,
    (t) => List.generate(
      _alphaSteps,
      (a) => _accent[t].withValues(alpha: a / (_alphaSteps - 1)),
      growable: false,
    ),
    growable: false,
  );

  static Color _alpha(List<Color> table, double a) =>
      table[(a.clamp(0.0, 1.0) * (_alphaSteps - 1)).round()];

  // ── Sparks ────────────────────────────────────────────────────────────────
  static const int _maxSparks = 48;
  final Float64List _sx = Float64List(_maxSparks);
  final Float64List _sy = Float64List(_maxSparks);
  final Float64List _svx = Float64List(_maxSparks);
  final Float64List _svy = Float64List(_maxSparks);
  final Float64List _sLife = Float64List(_maxSparks); // 0 → 1
  final Float64List _sInvLife = Float64List(_maxSparks);
  final Float64List _sSize = Float64List(_maxSparks);
  final Int8List _sTier = Int8List(_maxSparks);
  final Int8List _sColor = Int8List(_maxSparks);
  final Uint8List _sActive = Uint8List(_maxSparks);
  int _activeSparks = 0;
  final math.Random _rng = math.Random();

  // ── Shockwave rings (two slots: tier-ups fire a delayed second ring) ──────
  final Float64List _ringT = Float64List(2)..fillRange(0, 2, 1e9);
  final Float64List _ringDelay = Float64List(2);
  final Int8List _ringTier = Int8List(2);
  final Float64List _ringStrength = Float64List(2);
  static const double _ringDuration = 0.42;

  // ── Court flash (read by BasketballGame.render) ───────────────────────────
  double _flashT = 1e9;
  int _flashTier = 0;
  static const double _flashDuration = 0.16;

  /// Current flash color (already alpha-blended), or null when inactive.
  Color? get flashColor {
    if (_flashT >= _flashDuration) return null;
    final a = 0.16 * (1.0 - _flashT / _flashDuration);
    return _alpha(_accentColors[_flashTier], a);
  }

  // ── Rim glow ──────────────────────────────────────────────────────────────
  double _time = 0.0;
  double _glowLevel = 0.0; // eased toward the target for smooth on/off

  static ui.Image? _glowSprite;
  static final Paint _glowPaint = Paint()
    ..filterQuality = FilterQuality.low
    ..blendMode = BlendMode.plus;
  static final Paint _sparkPaint = Paint()..blendMode = BlendMode.plus;
  static final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;

  /// One cached ColorFilter per tier × alpha step for tinting the glow sprite.
  static final List<List<ColorFilter>> _glowFilters = List.generate(
    _accent.length,
    (t) => List.generate(
      _alphaSteps,
      (a) => ColorFilter.mode(_accentColors[t][a], BlendMode.srcIn),
      growable: false,
    ),
    growable: false,
  );

  static void _ensureGlowSprite() {
    if (_glowSprite != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(32, 32),
        32,
        const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 64, 64), paint);
    final picture = recorder.endRecording();
    _glowSprite = picture.toImageSync(64, 64);
    picture.dispose();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Celebrates a make at [streak] (the streak count INCLUDING this make).
  /// [isLocalPlayer] adds the flash/punch reserved for the player's own shots.
  void onMake({required int streak, required bool isLocalPlayer}) {
    final tier = streakTierFor(streak);
    if (tier == StreakTier.none) return;
    final tierUp = streak == 3 || streak == 6 || streak == 10;

    _startRing(0, tier, tierUp ? 1.35 : 1.0, delay: 0.0);
    if (tierUp) _startRing(1, tier, 1.0, delay: 0.09);

    final quality = game.quality.tier;
    final baseCount = switch (quality) {
      QualityTier.high => 22,
      QualityTier.medium => 12,
      QualityTier.low => 8, // still a visible burst on hot/older phones
    };
    final count = tierUp ? (baseCount * 1.6).round() : baseCount;
    _spray(count, tier);

    if (isLocalPlayer && tierUp) {
      _flashT = 0.0;
      _flashTier = tier.index;
      game.screenFx.punch(0.04);
    }
  }

  void _startRing(int slot, StreakTier tier, double strength,
      {required double delay}) {
    _ringT[slot] = 0.0;
    _ringDelay[slot] = delay;
    _ringTier[slot] = tier.index;
    _ringStrength[slot] = strength;
  }

  void _spray(int count, StreakTier tier) {
    final halfW = hoopWidth / 2;
    for (int n = 0; n < count; n++) {
      int slot = -1;
      for (int i = 0; i < _maxSparks; i++) {
        if (_sActive[i] == 0) {
          slot = i;
          break;
        }
      }
      if (slot < 0) return;

      final a = _rng.nextDouble() * math.pi * 2.0;
      final ca = math.cos(a);
      // Start around the rim, burst outward; most fall down through the net,
      // a few kick upward for a "fountain" silhouette.
      _sx[slot] = ca * halfW * (0.4 + _rng.nextDouble() * 0.6);
      _sy[slot] = 0.05 + _rng.nextDouble() * 0.25;
      final speed = 1.6 + _rng.nextDouble() * 2.6;
      _svx[slot] = ca * speed;
      _svy[slot] = _rng.nextDouble() < 0.3
          ? -(1.2 + _rng.nextDouble() * 2.2) // upward kick
          : (0.4 + _rng.nextDouble() * 2.4); // down through the net
      final life = 0.38 + _rng.nextDouble() * 0.34;
      _sLife[slot] = 0.0;
      _sInvLife[slot] = 1.0 / life;
      _sSize[slot] = 0.035 + _rng.nextDouble() * 0.05;
      _sTier[slot] = tier.index;
      _sColor[slot] = _rng.nextInt(3);
      _sActive[slot] = 1;
      _activeSparks++;
    }
  }

  // ── Loop ──────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _flashT += dt;
    for (int r = 0; r < 2; r++) {
      _ringT[r] += dt;
    }

    // Rim glow follows the player's live streak (if streak FX are enabled).
    final streak = game.streakNotifier.value;
    final fxOn = game.streakFxEnabledNotifier.value;
    final tier = streakTierFor(streak);
    final target = (!fxOn || tier == StreakTier.none)
        ? 0.0
        : switch (tier) {
            StreakTier.lightning => 0.40,
            StreakTier.fire => 0.58,
            StreakTier.inferno => 0.78,
            StreakTier.none => 0.0,
          };
    _glowLevel += (target - _glowLevel) * (1.0 - math.exp(-dt * 6.0));
    if (tier != StreakTier.none) _glowTier = tier.index;

    if (_activeSparks == 0) return;
    const gravity = 6.5;
    final drag = math.exp(-2.2 * dt);
    for (int i = 0; i < _maxSparks; i++) {
      if (_sActive[i] == 0) continue;
      _sLife[i] += dt * _sInvLife[i];
      if (_sLife[i] >= 1.0) {
        _sActive[i] = 0;
        _activeSparks--;
        continue;
      }
      _svx[i] *= drag;
      _svy[i] = _svy[i] * drag + gravity * dt;
      _sx[i] += _svx[i] * dt;
      _sy[i] += _svy[i] * dt;
    }
  }

  int _glowTier = 1;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderRimGlow(canvas);
    _renderRings(canvas);
    _renderSparks(canvas);
  }

  void _renderRimGlow(Canvas canvas) {
    if (_glowLevel < 0.02) return;
    _ensureGlowSprite();
    final sprite = _glowSprite;
    if (sprite == null) return;
    final pulse = 0.82 + 0.18 * math.sin(_time * (5.0 + _glowTier * 1.5));
    final a = _glowLevel * pulse;
    _glowPaint.colorFilter =
        _glowFilters[_glowTier][(a.clamp(0.0, 1.0) * (_alphaSteps - 1)).round()];
    // Wide, flat halo hugging the rim ellipse.
    final w = hoopWidth * 1.7;
    final h = hoopWidth * 0.55;
    canvas.save();
    canvas.translate(0, 0.02);
    canvas.scale(w / 64.0, h / 64.0);
    canvas.drawImage(sprite, const Offset(-32, -32), _glowPaint);
    canvas.restore();
  }

  void _renderRings(Canvas canvas) {
    for (int r = 0; r < 2; r++) {
      final t = _ringT[r] - _ringDelay[r];
      if (t < 0.0 || t >= _ringDuration) continue;
      final p = t / _ringDuration;
      final ease = 1.0 - (1.0 - p) * (1.0 - p) * (1.0 - p); // easeOutCubic
      final rx = hoopWidth * 0.5 * (1.0 + 1.1 * ease) * _ringStrength[r];
      final ry = rx * 0.16; // flattened like the rim ellipse
      final alpha = (1.0 - p) * 0.9;
      _ringPaint
        ..color = _alpha(_accentColors[_ringTier[r]], alpha)
        // Stroke is set in unit space; non-uniform scale thins it vertically,
        // which reads as perspective on the floor-parallel rim plane.
        ..strokeWidth = (0.09 * (1.0 - p) + 0.015) / rx;
      canvas.save();
      canvas.scale(rx, ry);
      canvas.drawCircle(Offset.zero, 1.0, _ringPaint);
      canvas.restore();
    }
  }

  void _renderSparks(Canvas canvas) {
    if (_activeSparks == 0) return;
    // Fake bloom: a soft additive halo under each spark makes the spray read
    // as light, not confetti. Dropped first on LOW (one sprite per spark).
    if (game.quality.drawSparkBloom) {
      for (int i = 0; i < _maxSparks; i++) {
        if (_sActive[i] == 0) continue;
        final life = _sLife[i];
        final glow = _sSize[i] * (1.0 - life * 0.5) * 7.0;
        GlowSprite.draw(
          canvas,
          _sx[i],
          _sy[i],
          glow,
          glow,
          _sTier[i],
          (1.0 - life) * 0.42,
        );
      }
    }
    for (int i = 0; i < _maxSparks; i++) {
      if (_sActive[i] == 0) continue;
      final life = _sLife[i];
      final alpha = 1.0 - life * life;
      final radius = _sSize[i] * (1.0 - life * 0.5);
      _sparkPaint.color =
          _alpha(_particleColors[_sTier[i]][_sColor[i]], alpha);
      canvas.save();
      canvas.translate(_sx[i], _sy[i]);
      canvas.drawCircle(Offset.zero, radius, _sparkPaint);
      canvas.restore();
    }
  }
}
