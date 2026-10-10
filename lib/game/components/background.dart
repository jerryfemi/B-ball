import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'background/court_floor_renderer.dart';
import 'background/distant_wall_renderer.dart';
import 'background/lighting_renderer.dart';
import 'background/room_geometry.dart';

/// Authentic GamePigeon Gymnasium Court Environment:
/// Orchestrates unified 3D perspective background with:
/// - Exposed red clay brick back wall with sandy charcoal mortar
/// - Maple hardwood court floor with true 3D perspective markings
/// - Collegiate terracotta key, restricted area arc, and free-throw circle
/// - Signature vertical pole floor reflection streak
/// - Volumetric arena floodlight focus
///
/// Fully cached using [ui.Picture] for zero per-frame CPU/GPU rasterization overhead.
class GameBackground extends Component with HasGameReference {
  final DistantWallRenderer _distantWallRenderer = DistantWallRenderer();
  final CourtFloorRenderer _courtFloorRenderer = CourtFloorRenderer();
  final LightingRenderer _lightingRenderer = LightingRenderer();

  ui.Picture? _cachedPicture;
  Vector2? _cachedSize;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _invalidateCache();
  }

  void _invalidateCache() {
    _cachedPicture?.dispose();
    _cachedPicture = null;
    _cachedSize = null;
  }

  void _rebuildCache(double width, double height) {
    _cachedPicture?.dispose();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final geom = RoomGeometry.fromScreenSize(width, height);

    // 1. Authentic GamePigeon exposed red clay brick gym back wall
    _distantWallRenderer.render(canvas, geom);

    // 2. Hardwood court floor with unified 3D perspective markings & pole reflection
    _courtFloorRenderer.render(canvas, geom);

    // 3. Subtle arena floodlight focus & corner vignette
    _lightingRenderer.render(canvas, geom);

    _cachedPicture = recorder.endRecording();
    _cachedSize = Vector2(width, height);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final width = game.size.x;
    final height = game.size.y;

    if (width <= 0 || height <= 0) return;

    if (_cachedPicture == null ||
        _cachedSize == null ||
        _cachedSize!.x != width ||
        _cachedSize!.y != height) {
      _rebuildCache(width, height);
    }

    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }

  @override
  void onRemove() {
    _invalidateCache();
    super.onRemove();
  }
}
