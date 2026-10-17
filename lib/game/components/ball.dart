import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../audio/audio_engine.dart';
import '../basketball_game.dart';
import '../physics/ball_physics_3d.dart';
import '../physics/perspective_camera.dart';
import '../physics/launch_solver.dart';
import 'fiery_trail.dart';
import 'wall_impact_puff.dart';

/// Basketball component featuring true 3D projectile kinematics,
/// exact 3D Torus rim collision, backboard glass bounce, hardwood floor roll,
/// and continuous ground drop shadow within the 1-point perspective gymnasium.
class Basketball extends BodyComponent<BasketballGame> with DragCallbacks {
  final Vector2 initialPosition;
  final double radius;
  final VoidCallback? onLaunched;
  final bool animateEntrance;

  // 3D physics simulator
  late final BallPhysics3D physics;

  // Cached 3D perspective camera for projection
  PerspectiveCamera3D? _cachedCamera;
  Vector2? _lastCameraSize;

  PerspectiveCamera3D get camera3D {
    if (_cachedCamera == null || _lastCameraSize != game.size) {
      _lastCameraSize = game.size.clone();
      _cachedCamera = PerspectiveCamera3D.standard(game.size.x, game.size.y);
      // Device pixel ratio only changes alongside a resize/zoom, so it is read
      // here (rarely) instead of 60x per second inside render().
      final views = WidgetsBinding.instance.platformDispatcher.views;
      _cachedDpr = views.isNotEmpty ? views.first.devicePixelRatio : 1.0;
    }
    return _cachedCamera!;
  }

  double _cachedDpr = 1.0;

  // ── Zero-allocation scratch state (reused every frame) ──
  final Vector2 _projScratch = Vector2.zero();
  final Vector2 _velScratch = Vector2.zero();
  final Paint _shaderPaint = Paint();
  late final Rect _shaderRect = Rect.fromCenter(
    center: Offset.zero,
    width: radius * 2.02,
    height: radius * 2.02,
  );
  static final Paint _fallbackPaint = Paint()..color = const Color(0xFFFF6F00);

  /// Precomputed black-with-alpha colors so shadow alpha changes never allocate.
  static final List<Color> _blackAlpha = List<Color>.generate(
    256,
    (i) => Color.fromARGB(i, 0, 0, 0),
    growable: false,
  );

  // Canvas→logical-pixel mapping, calibrated once per screen size from a single
  // getTransform() call (instead of one Float64List per ball per frame).
  // The Flame camera is a fixed affine map: logical = root + m * world.
  static Vector2? _calibratedForSize;
  static double _calibRootX = 0.0;
  static double _calibRootY = 0.0;
  static double _calibMetersToPx = 1.0;

  /// Retirement age (seconds since launch). Shared by update() and render() so
  /// the fade-out always completes right as the ball is removed.
  double get _maxLifetime =>
      (physics.isSettled || physics.bounceCount >= 2) ? 1.8 : 4.0;
  static const double _fadeOutDuration = 0.6;

  // ── Static GPU Shader Program Cache ──
  static Future<ui.FragmentProgram?>? _programFuture;
  static ui.FragmentProgram? _cachedProgram;

  // ── Static Shadow Sprite Cache (Eliminates per-frame ui.Gradient.radial recompilations) ──
  static ui.Image? _cachedShadowSprite;
  static final Paint _sharedShadowPaint = Paint()
    ..filterQuality = FilterQuality.low;

  static void _ensureShadowSprite() {
    if (_cachedShadowSprite != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(32, 32),
        32,
        const [Color(0xFF000000), Color(0x73000000), Color(0x00000000)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 64, 64), paint);
    final picture = recorder.endRecording();
    _cachedShadowSprite = picture.toImageSync(64, 64);
    picture.dispose();
  }

  /// Loads and statically caches the GPU [FragmentProgram] across all basketball instances.
  /// Pre-warming this during [BasketballGame.onLoad] completely eliminates feeder-spawn compilation hitches.
  static Future<ui.FragmentProgram?> loadProgram() {
    if (_cachedProgram != null) return Future.value(_cachedProgram);
    return _programFuture ??= () async {
      try {
        final program = await ui.FragmentProgram.fromAsset(
          'shaders/basketball.frag',
        );
        _cachedProgram = program;
        return program;
      } catch (e) {
        debugPrint('Failed to load basketball shader: $e');
        return null;
      }
    }();
  }

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  bool isEntering = false;
  double enterProgress = 0.0;

  // Monotonic stopwatch for zero-allocation touch timestamping
  static final Stopwatch _touchClock = Stopwatch()..start();

  // Rolling touch history for release velocity estimation
  final List<_TouchSample> _touchSamples = [];
  bool _streakEvaluated = false;

  /// Base opacity of the basketball: 1.0 for standard live play, ~0.55 for ghost replay.
  double get baseOpacity => 1.0;

  /// Whether this ball is controlled by the live player.
  bool get isLiveBall => true;

  /// Active streak score for this ball. For live ball, returns the game's reactive streak.
  /// Subclasses (e.g. GhostBasketball) override this to return their recorded shot streak.
  int get activeStreak => isLiveBall ? game.streakNotifier.value : 0;

  /// High-performance zero-allocation fiery trail and ember spark system.
  final FieryBallTrail fieryTrail = FieryBallTrail();

  /// Whether this ball is currently blazing with fire/lightning in active flight.
  /// Strictly restricted to the upward swiping trajectory towards the net.
  /// Only ignites once the player achieves a streak of 3 in a row (matches HUD flame badge)!
  /// Extinguishes immediately when the ball enters the net, touches the floor, or bounces.
  bool get isFlightOnFire {
    if (!isLaunched) return false;
    // Local player preference: if local player disabled streak FX, don't show on live ball.
    // Opponent ghost balls bypass this so spectator can see opponent's flaming/lightning streak!
    if (isLiveBall && !game.streakFxEnabledNotifier.value) return false;
    if (activeStreak < 3) return false; // 3 in a row trigger (lightning at 3-5, fire at 6+)

    // Extinguish once the ball has entered the net, bounced, or is near the floor
    if (physics.passedThroughRim) return false;
    if (physics.bounceCount > 0) return false;
    if (physics.isDeadBall || physics.isSettled) return false;
    if (physics.pos.y <= physics.radius + 0.08) return false;

    return true;
  }

  @protected
  void onScoredBasket({required bool isSwish, required bool isBankShot}) {
    _streakEvaluated = true;
    if (isSwish) {
      AudioEngine.playSwish();
    }
    game.registerScore(isSwish: isSwish, isBankShot: isBankShot);
  }

  Basketball({
    required this.initialPosition,
    this.radius = 0.58,
    this.onLaunched,
    this.animateEntrance = false,
    Vector3? initialPos3D,
  }) : super(priority: 6) {
    physics = BallPhysics3D(
      initialPos:
          initialPos3D ??
          Vector3(
            initialPosition.x / PerspectiveCamera3D.forge2dUnitsPerMeterAtZ0,
            0.25,
            0.0,
          ),
      radius: 0.125,
      onWallImpact: (impactPt) {
        if (!isMounted) return;
        // Minimum impact velocity threshold: only trigger puff on solid hits
        if (physics.vel.length < 1.2) return;
        final wallF2D = camera3D.projectToForge2D(
          impactPt.x,
          impactPt.y,
          impactPt.z,
        );
        final wallScale = camera3D.scaleAtDepth(BallPhysics3D.wallZ);
        final visualRadius = radius * wallScale * 1.38;
        game.world.add(
          WallImpactPuff(
            position: Vector2(wallF2D.dx, wallF2D.dy),
            baseRadius: visualRadius,
          ),
        );
      },
      onRimImpact: (speed) {
        if (!isMounted) return;
        AudioEngine.playRimClank(speed);
      },
      onBackboardImpact: (speed) {
        if (!isMounted) return;
        AudioEngine.playBackboardThud(speed);
      },
      onFloorImpact: (speed) {
        if (!isMounted) return;
        AudioEngine.playFloorBounce(speed);
      },
      onScored: ({required bool isSwish, required bool isBankShot}) {
        if (!isMounted) return;
        onScoredBasket(isSwish: isSwish, isBankShot: isBankShot);
      },
    );
    if (animateEntrance) {
      isEntering = true;
      physics.pos.y =
          -0.4; // Start slightly below floor level for smooth slide-in
    }
  }

  // Getters for game visual listeners (FrontRimVisual, BackboardVisual, etc.)
  bool get isLaunched => physics.isLaunched;
  bool get passedThroughRim => physics.passedThroughRim;
  bool get hasClankedFrontRim => physics.hasClankedRim;
  bool get hasBankedBackboard => physics.hasBankedBackboard;
  double get timeSinceLaunch => physics.timeSinceLaunch;

  @override
  void onRemove() {
    if (isLiveBall &&
        isLaunched &&
        !_streakEvaluated &&
        !physics.passedThroughRim) {
      _streakEvaluated = true;
      game.resetStreak();
    }
    fieryTrail.reset();
    _shader?.dispose();
    _shader = null;
    super.onRemove();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _program = _cachedProgram ?? await loadProgram();
    _shader = _program?.fragmentShader();
    if (_shader != null) _shaderPaint.shader = _shader;
  }

  @override
  Body createBody() {
    final Vector2 bodyPos;
    if (physics.pos.z != 0.0) {
      final f2d = camera3D.projectToForge2D(
        physics.pos.x,
        physics.pos.y,
        physics.pos.z,
      );
      bodyPos = Vector2(f2d.dx, f2d.dy);
    } else {
      bodyPos = initialPosition;
    }

    final bodyDef = BodyDef(type: BodyType.kinematic, position: bodyPos);

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      density: 1.0,
      material: SurfaceMaterial(friction: 0.8, restitution: 0.82),
      filter: forge2d.Filter(
        categoryBits: isLiveBall
            ? 0x0008
            : 0x0010, // Basketball vs Ghost category
        maskBits: 0, // True 3D physics handles all collisions!
      ),
    );

    body.createShape(forge2d.Circle(radius: radius), shapeDef);
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth Feeder Entrance: glide up from below into ready position
    if (isEntering && !isLaunched) {
      enterProgress += dt / 0.35;
      if (enterProgress >= 1.0) {
        enterProgress = 1.0;
        isEntering = false;
      }
      final t = Curves.easeOutCubic.transform(enterProgress);
      physics.pos.y = ui.lerpDouble(-0.4, 0.25, t)!;
      camera3D.projectToForge2DFast(physics.pos.x, physics.pos.y, physics.pos.z);
      _projScratch.setValues(camera3D.projX, camera3D.projY);
      body.setTransform(_projScratch, const forge2d.Rot.identity());
      return;
    }

    if (isLaunched) {
      // 1. Advance the 3D physics engine (substeps, torus rim, backboard, floor)
      physics.update(dt);

      // Update fiery flame trail and incandescent embers strictly during upward flight
      if (!isFlightOnFire) {
        fieryTrail.reset();
      } else {
        fieryTrail.update(
          dt: dt,
          ballPos: physics.pos,
          ballRadius: radius,
          isOnFire: isFlightOnFire,
          isLaunched: isLaunched && !physics.isSettled,
          streak: activeStreak,
        );
      }

      // Evaluate missed shot for streak reset once the ball settles on the floor or times out
      if (isLiveBall &&
          !_streakEvaluated &&
          physics.timeSinceLaunch > 0.40 &&
          (physics.pos.y <= physics.radius + 0.02 ||
              physics.timeSinceLaunch > 3.0)) {
        _streakEvaluated = true;
        game.resetStreak();
      }

      // 2. Lifecycle cleanup:
      // Active in-flight balls get up to 4.0s full flight time.
      // Once settled on the floor or after 2+ bounces, retire within 1.8s to allow natural bounces and roll.
      if (physics.timeSinceLaunch > _maxLifetime) {
        removeFromParent();
        return;
      }

      // 3. Project 3D coordinate to Forge2D world meters (into reused scratch)
      camera3D.projectToForge2DFast(physics.pos.x, physics.pos.y, physics.pos.z);
      _projScratch.setValues(camera3D.projX, camera3D.projY);
      body.setTransform(_projScratch, const forge2d.Rot.identity());

      // Downward velocity in Forge2D space (+Y is down)
      final f2dVelY = physics.vel.y < 0
          ? physics.vel.y.abs() * 1.5
          : -physics.vel.y * 1.5;
      _velScratch.setValues(physics.vel.x, f2dVelY);
      body.linearVelocity = _velScratch;

      // 4. Dynamic 3D depth layering
      _updateRenderPriority();
    }
  }

  void _updateRenderPriority() {
    if (physics.pos.z > BallPhysics3D.backboardZ) {
      // 1. Completely behind backboard glass (bouncing off back gym wall)
      // Priority 0: Behind BackboardVisual (priority 1)
      priority = 0;
    } else if (physics.pos.z >= 4.70) {
      // 2. Bank shot / bouncing off backboard / resting on rear mounting neck:
      // In front of Backboard glass (1), but BEHIND Rear Rim & mounting bracket (3) and Front Rim (5)
      // Priority 2: BackboardVisual (1) < Ball (2) < RearRimVisual (3) < FrontRimVisual (5)
      priority = 2;
    } else if (physics.pos.z >=
            (BallPhysics3D.rimCenter.z - BallPhysics3D.rimRadius) ||
        (physics.passedThroughRim &&
            physics.pos.y <= BallPhysics3D.rimCenter.y &&
            physics.pos.y >= BallPhysics3D.netBottomY)) {
      // 3. Inside hoop cylinder / dropping through net (4.23 <= Z < 4.70):
      // In front of RearRimVisual (3) and Backboard (1), but BEHIND FrontRimVisual (5)
      // Priority 4: RearRimVisual (3) < Ball (4) < FrontRimVisual (5)
      priority = 4;
    } else {
      // 4. In foreground (Z < 4.23): in front of all hoop visuals
      // Priority 6: Ball (6) > FrontRimVisual (5)
      priority = 6;
    }
  }

  /// Draws the cached radial shadow sprite centered at ([cx], [cy]) with size
  /// [w] x [h], using canvas transforms instead of allocating a Rect.
  static void _drawShadowSprite(
    Canvas canvas,
    ui.Image sprite,
    double cx,
    double cy,
    double w,
    double h,
    double alpha,
  ) {
    _sharedShadowPaint.color = _blackAlpha[(alpha * 255).round().clamp(0, 255).toInt()];
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(w / 64.0, h / 64.0);
    canvas.drawImage(sprite, const Offset(-32, -32), _sharedShadowPaint);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    // Fade out over the final [_fadeOutDuration] of the ball's lifetime,
    // finishing exactly when update() retires it.
    final double fadeOutStart = _maxLifetime - _fadeOutDuration;
    final double fadeOut = physics.timeSinceLaunch > fadeOutStart
        ? (1.0 - (physics.timeSinceLaunch - fadeOutStart) / _fadeOutDuration)
              .clamp(0.0, 1.0)
        : 1.0;

    final double effectiveOpacity = (baseOpacity * fadeOut).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.01) return;

    _ensureShadowSprite();
    final shadowImage = _cachedShadowSprite;
    final cam = camera3D;
    final bodyX = body.position.x;
    final bodyY = body.position.y;

    // 1. Continuous Hardwood Floor Drop Shadow
    // Shadow is calculated at (physics.pos.x, 0.0, physics.pos.z) on the court floor
    final bool onCourtFloor =
        physics.pos.z <= BallPhysics3D.wallZ &&
        physics.pos.x.abs() <= BallPhysics3D.halfWidth;

    if (onCourtFloor && shadowImage != null) {
      final heightAboveFloor = (physics.pos.y - physics.radius).clamp(0.0, 8.0);
      final shadowAlpha = ((0.52 / (1.0 + heightAboveFloor * 0.40)) * opacity)
          .clamp(0.0, 0.52);

      if (shadowAlpha > 0.01) {
        cam.projectToForge2DFast(physics.pos.x, 0.0, physics.pos.z);
        _projScratch.setValues(cam.projX, cam.projY);
        final zScale = cam.scaleAtDepth(physics.pos.z);
        final visualRadius = radius * zScale * 1.38;
        final shadowScale = 1.0 + heightAboveFloor * 0.16;
        _drawShadowSprite(
          canvas,
          shadowImage,
          _projScratch.x - bodyX,
          _projScratch.y - bodyY,
          visualRadius * 2.2 * shadowScale,
          visualRadius * 0.42 * shadowScale, // Perspective flattening
          shadowAlpha,
        );
      }
    }

    // ── High Performance Guard ──
    // Only an actively in-flight ball heading toward the hoop (before floor bounce or netting)
    // evaluates or renders vertical plane shadows (backboard and back wall).
    // Bounced, rolling, or scored balls strictly skip this to eliminate GPU fill-rate waste.
    final quality = game.quality;
    final bool canCastVerticalShadows =
        quality.drawProximityShadows &&
        isLaunched &&
        !physics.isSettled &&
        physics.bounceCount == 0 &&
        !physics.passedThroughRim &&
        physics.pos.z >= 3.40;

    if (canCastVerticalShadows && shadowImage != null) {
      // 2. Dynamic Backboard Acrylic Contact Shadow (Convergence Depth Cue)
      // Cast on the white acrylic backboard as the ball approaches within ~1.20m (Z >= 3.76m).
      final double distToBoard =
          (BallPhysics3D.backboardZ - (physics.pos.z + physics.radius)).clamp(
            0.0,
            1.20,
          );
      final double boardProximity = (1.0 - (distToBoard / 1.20)).clamp(
        0.0,
        1.0,
      );

      if (distToBoard < 1.20 &&
          physics.pos.z <= BallPhysics3D.backboardZ + 0.05) {
        final double offsetX = (1.0 - boardProximity) * 0.14;
        final double offsetY = -(1.0 - boardProximity) * 0.24;
        final double shadowWorldX = physics.pos.x + offsetX;
        final double shadowWorldY = physics.pos.y + offsetY;

        final bool inBoardBounds =
            shadowWorldX.abs() <= BallPhysics3D.backboardMaxX + 0.12 &&
            shadowWorldY >= BallPhysics3D.backboardMinY - 0.15 &&
            shadowWorldY <= BallPhysics3D.backboardMaxY + 0.15;

        if (inBoardBounds) {
          final double boardShadowAlpha =
              (math.pow(boardProximity, 0.6) * 0.65 * opacity).clamp(0.0, 0.65);

          if (boardShadowAlpha > 0.02) {
            cam.projectToForge2DFast(shadowWorldX, shadowWorldY, BallPhysics3D.backboardZ);
            _projScratch.setValues(cam.projX, cam.projY);
            final boardZScale = cam.scaleAtDepth(BallPhysics3D.backboardZ);
            final boardVisualRadius = radius * boardZScale * 1.38;
            final shadowSpread = 1.0 + (1.0 - boardProximity) * 0.55;
            final d = boardVisualRadius * 2.0 * shadowSpread;
            _drawShadowSprite(
              canvas,
              shadowImage,
              _projScratch.x - bodyX,
              _projScratch.y - bodyY,
              d,
              d,
              boardShadowAlpha,
            );
          }
        }
      }

      // 3. Dynamic Brick Back Wall Proximity Contact Shadow
      final double distToWall =
          (BallPhysics3D.wallZ - (physics.pos.z + physics.radius)).clamp(
            0.0,
            0.70,
          );
      if (distToWall < 0.70 && physics.pos.x.abs() <= BallPhysics3D.halfWidth) {
        final double wallProximity = 1.0 - (distToWall / 0.70);
        final double wallShadowAlpha = (wallProximity * 0.60 * opacity).clamp(
          0.0,
          0.60,
        );

        final bool inBackboardFrame =
            physics.pos.x.abs() <= BallPhysics3D.backboardMaxX &&
            physics.pos.y >= BallPhysics3D.backboardMinY &&
            physics.pos.y <= BallPhysics3D.backboardMaxY;
        final bool occludedByBoard =
            inBackboardFrame && physics.pos.z < BallPhysics3D.backboardZ;

        if (!occludedByBoard && wallShadowAlpha > 0.01) {
          final double shadowY = physics.pos.y - (0.04 + distToWall * 0.08);
          cam.projectToForge2DFast(physics.pos.x, shadowY, BallPhysics3D.wallZ);
          _projScratch.setValues(cam.projX, cam.projY);
          final wallZScale = cam.scaleAtDepth(BallPhysics3D.wallZ);
          final wallVisualRadius = radius * wallZScale * 1.38;
          final shadowSpread = 1.0 + (1.0 - wallProximity) * 0.35;
          final d = wallVisualRadius * 2.0 * shadowSpread;
          _drawShadowSprite(
            canvas,
            shadowImage,
            _projScratch.x - bodyX,
            _projScratch.y - bodyY,
            d,
            d,
            wallShadowAlpha,
          );
        }
      }
    }

    // Render fiery ribbon and incandescent embers right behind the ball during upward flight
    if (isFlightOnFire && quality.drawFlameRibbon) {
      fieryTrail.render(
        canvas,
        ballBodyPos: Offset(bodyX, bodyY),
        camera3D: cam,
        streak: activeStreak,
        drawEmbers: quality.drawEmbers,
      );
    }

    // 3. Monotonic Perspective Foreshortening based on exact 3D Z-depth
    final scaleFactor = 1.38 * cam.scaleAtDepth(physics.pos.z);

    canvas.save();
    canvas.scale(scaleFactor);

    final shader = _shader;
    if (shader != null) {
      // Calibrate the world→logical-pixel affine map once per screen size.
      final calibSize = _calibratedForSize;
      if (calibSize == null || calibSize != game.size) {
        final t = canvas.getTransform();
        final m =
            math.sqrt(t[0] * t[0] + t[1] * t[1]) / scaleFactor;
        _calibMetersToPx = m;
        _calibRootX = t[12] - m * bodyX;
        _calibRootY = t[13] - m * bodyY;
        _calibratedForSize = game.size.clone();
      }

      final dpr = _cachedDpr;
      final physicalCenterX = (_calibRootX + _calibMetersToPx * bodyX) * dpr;
      final physicalCenterY = (_calibRootY + _calibMetersToPx * bodyY) * dpr;
      final physicalRadius = radius * _calibMetersToPx * scaleFactor * dpr;

      shader.setFloat(0, physicalCenterX);
      shader.setFloat(1, physicalCenterY);
      shader.setFloat(2, physicalRadius);
      shader.setFloat(3, physics.yaw);
      shader.setFloat(4, physics.pitch);
      shader.setFloat(5, radius);
      final double fireUniform = isFlightOnFire
          ? (activeStreak >= 10 ? 2.0 : 1.0)
          : 0.0;
      shader.setFloat(6, fireUniform);
      // Pebble/bump detail level from AdaptiveQuality (0 = smooth leather).
      shader.setFloat(7, quality.shaderDetail);

      canvas.drawRect(_shaderRect, _shaderPaint);
    } else {
      canvas.drawCircle(Offset.zero, radius, _fallbackPaint);
    }

    canvas.restore();
  }

  @override
  bool containsPoint(Vector2 point) {
    if (!isLiveBall) return false;
    if (game.gameStateNotifier.value == GameModeState.gameOver ||
        game.isPaused) {
      return false;
    }
    // Allow immediate touch even while entering so rapid swipes are never ignored
    if (isLaunched) return false;
    // Lower ~55% of the screen (Y >= 9.5m in Forge2D world)
    // or within generous 3.0x radius of the ready ball to avoid Android bottom gesture conflicts
    return point.y >= 9.5 || (point - body.position).length <= radius * 3.0;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isLaunched) {
      // If player swipes while ball is still gliding up, immediately snap to ready position
      if (isEntering) {
        isEntering = false;
        enterProgress = 1.0;
        physics.pos.y = 0.25;
        final f2d = camera3D.projectToForge2D(
          physics.pos.x,
          physics.pos.y,
          physics.pos.z,
        );
        body.setTransform(
          Vector2(f2d.dx, f2d.dy),
          const forge2d.Rot.identity(),
        );
      }
      _touchSamples.clear();
      _touchSamples.add(
        _TouchSample(event.canvasPosition, _touchClock.elapsedMilliseconds),
      );
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!isLaunched) {
      if (isEntering) {
        isEntering = false;
        enterProgress = 1.0;
      }
      final now = _touchClock.elapsedMilliseconds;
      _touchSamples.add(_TouchSample(event.canvasEndPosition, now));

      // Retain sample buffer up to 350ms to preserve full intentional stroke trajectory
      while (_touchSamples.length > 2 &&
          now - _touchSamples.first.timestampMs > 350) {
        _touchSamples.removeAt(0);
      }
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _touchSamples.clear();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (isLaunched || _touchSamples.isEmpty) return;
    if (isEntering) {
      isEntering = false;
      enterProgress = 1.0;
    }

    final now = _touchClock.elapsedMilliseconds;
    final lastSample = _touchSamples.last;
    final firstSample = _touchSamples.first;

    // 1. Resting finger cancel:
    // Web browsers & iOS Safari PWA inject slight gesture recognition delays (100-140ms).
    // Provide a generous window (240ms on web, 180ms on native) so valid rapid flicks are never dropped,
    // while still cancelling an intentionally held stationary finger.
    final restingThresholdMs = kIsWeb ? 240 : 180;
    if (now - lastSample.timestampMs > restingThresholdMs) {
      _touchSamples.clear();
      return;
    }

    // 2. Trailing ~90ms release window for launch speed & momentum:
    final windowStartMs = lastSample.timestampMs - 90;
    final windowSamples = _touchSamples
        .where((s) => s.timestampMs >= windowStartMs)
        .toList();

    double vx = event.velocity.x;
    double vy = event.velocity.y;

    if (windowSamples.length >= 2) {
      final firstInWindow = windowSamples.first;
      final dtSec =
          (lastSample.timestampMs - firstInWindow.timestampMs) / 1000.0;
      if (dtSec > 0.012) {
        vx = (lastSample.position.x - firstInWindow.position.x) / dtSec;
        vy = (lastSample.position.y - firstInWindow.position.y) / dtSec;
      }
    }

    // Full gesture displacement vector (start of touch to liftoff)
    final totalDx = lastSample.position.x - firstSample.position.x;
    final totalDy = lastSample.position.y - firstSample.position.y;
    final totalDtSec =
        (lastSample.timestampMs - firstSample.timestampMs) / 1000.0;

    // If release window decelerated near liftoff but the stroke was a rapid upward flick,
    // use the overall stroke upward velocity as a floor to prevent dropped shots.
    if (totalDtSec > 0.02 && totalDy < -40.0) {
      final strokeVy = totalDy / totalDtSec;
      if (strokeVy < vy) {
        vy = strokeVy;
      }
    }

    _touchSamples.clear();

    // 3. Minimum upward flick threshold:
    // Only launch when swiped upwards toward the hoop
    if (vy >= -90.0 && totalDy >= -35.0) return;

    // Platform-aware velocity normalization:
    // On touch devices (iOS / Android), human finger flicks generate velocities
    // ~2.0x-2.3x higher (~1400-2500 px/s) than mouse cursor drags (~600-900 px/s).
    // Damping touch velocity normalizes the input so the calibrated 720 px/s sweet spot
    // feels natural, responsive, and consistent across both touch and pointer devices.
    final bool isTouchDevice =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    final double touchScale = isTouchDevice ? 0.46 : 1.0;

    // Upward swipe velocity in pixels/second (normalized for touch vs pointer)
    final swipeSpeedY = vy.abs() * touchScale;

    // 4. Robust Aim Direction Synthesis (Kills Sideways Thumb-Roll Glitch):
    // Calculate aim from release window AND full gesture displacement.
    final trailingAimRatio = (vx / vy.abs()).clamp(-0.80, 0.80);
    double swipeRatioX;

    if (totalDy.abs() >= 35.0) {
      final overallAimRatio = (totalDx / totalDy.abs()).clamp(-0.80, 0.80);

      // Blend overall intentional gesture path (70%) with release momentum (30%)
      swipeRatioX = (overallAimRatio * 0.70) + (trailingAimRatio * 0.30);

      // Liftoff noise rejection:
      // If the player swiped straight (|overallAimRatio| <= 0.08), clamp any rogue thumb-roll hook
      if (overallAimRatio.abs() <= 0.08) {
        swipeRatioX = swipeRatioX.clamp(-0.09, 0.09);
      }
    } else {
      swipeRatioX = trailingAimRatio;
    }
    swipeRatioX = swipeRatioX.clamp(-0.80, 0.80);

    // 5. GamePigeon Power Plateau calculation via LaunchSolver with room difficulty
    final difficulty = game.currentDifficulty;
    final powerRatio = LaunchSolver.flickToPower(
      swipeSpeedY,
      difficulty: difficulty,
    );

    final launchVel = LaunchSolver.calculateLaunchVelocity(
      powerRatio: powerRatio,
      aimRatio: swipeRatioX,
      from: physics.pos,
      difficulty: difficulty,
    );

    game.recordShotAttempt();
    game.recordShotTelemetry(
      startX: physics.pos.x,
      startY: physics.pos.y,
      startZ: physics.pos.z,
      vx: launchVel.x,
      vy: launchVel.y,
      vz: launchVel.z,
      backspin: 14.0,
    );
    physics.launch(launchVel, backspin: 14.0);
    onLaunched?.call();
  }
}

/// Lightweight timestamped touch sample for rolling velocity estimation
class _TouchSample {
  final Vector2 position;
  final int timestampMs;
  const _TouchSample(this.position, this.timestampMs);
}
