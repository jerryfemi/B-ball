import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'archery_constants.dart';
import 'audio/archery_audio.dart';
import 'camera/archery_camera.dart';
import 'camera/camera_rig.dart';
import 'components/bow_overlay.dart';
import 'components/distance_tag.dart';
import 'components/flying_arrow.dart';
import 'components/hit_popup_canvas.dart';
import 'components/range_background.dart';
import 'components/stuck_arrow.dart';
import 'components/target_board.dart';
import 'components/wind_pill.dart';
import 'input/draw_aim_controller.dart';
import 'physics/arrow_physics.dart';
import 'physics/sight_solver.dart';
import 'physics/target_scoring.dart';
import 'physics/wind_model.dart';
import 'state/archery_match_notifier.dart';
import 'state/archery_match_state.dart';

/// Flame game for the 50 ft GamePigeon-style archery range.
///
/// Owns the camera, physics and drawing only. Scores, sets and the match seed
/// live in [ArcheryGameEvents] (the Riverpod notifier); the game reads the seed
/// and arrow position from it and reports each shot back.
class ArcheryGame extends FlameGame {
  final ArcheryGameEvents events;

  // --- Core Systems ---
  late final ArcheryCamera archeryCamera;
  late final CameraRig cameraRig;
  late final DrawAimController controller;

  // --- Physics & Wind Models ---
  final ArrowPhysics3D arrowPhysics = ArrowPhysics3D();
  late WindModel windModel;

  // --- Components ---
  late final RangeBackground background;
  late final TargetBoard targetBoard;
  late final WindPill windPill;
  late final BowOverlay bowOverlay;
  late final FlyingArrow flyingArrow;
  late final HitPopupCanvas hitPopup;
  late final DistanceTag distanceTag;
  final List<StuckArrow> stuckArrows = [];

  /// The opponent's arrows shown landing at the start of each set.
  final List<StuckArrow> _botArrows = [];

  // Set-start replay timeline (seconds). _introTime < 0 = not running.
  static const double _introFirst = 0.6;
  static const double _introGap = 0.75;
  static const double _introHold = 1.2;
  static const double _botFadeSeconds = 0.45;
  double _introTime = -1.0;
  int _introLanded = 0;

  /// True between the last arrow of a set landing and "Next set".
  bool _setOver = false;

  double targetDistance = ArcheryK.distanceM;

  ArcheryGame({required this.events}) {
    archeryCamera = ArcheryCamera();
    cameraRig = CameraRig(camera: archeryCamera);
    controller = DrawAimController(camera: archeryCamera, cameraRig: cameraRig);
    background = RangeBackground(camera: archeryCamera);
    targetBoard = TargetBoard(
      camera: archeryCamera,
      initialDistance: targetDistance,
    );
    windPill = WindPill(camera: archeryCamera, cameraRig: cameraRig);
    bowOverlay = BowOverlay(camera: archeryCamera, cameraRig: cameraRig);
    flyingArrow = FlyingArrow(camera: archeryCamera, physics: arrowPhysics);
    hitPopup = HitPopupCanvas();
    distanceTag = DistanceTag(camera: archeryCamera, cameraRig: cameraRig);

    _setupCurrentArrow();
  }

  /// Moves the target to this set's distance: 50 ft, 100 ft, then 150 ft.
  void _applySetDistance() {
    final int set = events.setIndex;
    targetDistance = ArcheryK.distanceForSet(set);
    cameraRig.setTargetDistance(
      targetDistance,
      label: ArcheryK.distanceLabelForSet(set),
    );
    targetBoard.distance = targetDistance;
    background.activeDistance = targetDistance;
  }

  /// Seed for the next arrow, derived from the match seed so both players of a
  /// future online match get identical wind and sway.
  int get _arrowSeed {
    int h = events.matchSeed;
    h = (h * 31 + events.setIndex) & 0x7FFFFFFF;
    h = (h * 31 + events.arrowIndex) & 0x7FFFFFFF;
    return h;
  }

  void _setupCurrentArrow() {
    final int seed = _arrowSeed;
    windModel = WindModel.fromSeed(seed);
    controller.initSwaySeed(seed);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    ArcheryAudio.init();
    _applySetDistance();
    await background.load();
    await bowOverlay.load();

    // Broadcast initial wind outside widget build cycle
    events.windChanged(windModel.display);

    // Connect aim controller firing hook
    controller.onFireAt = (double crossX, double crossY) {
      if (_setOver || arrowPhysics.inFlight) return;

      ArcheryAudio.playReleaseTwang();
      HapticFeedback.lightImpact();

      // 1. Unproject visible crosshair point to target plane Z = D
      archeryCamera.unprojectToPlane(crossX, crossY, targetDistance);
      final double px = archeryCamera.outX;
      final double py = archeryCamera.outY;

      // 2. Solve launch yaw and pitch
      final double launchYaw = SightSolver.solveYaw(targetDistance, px);
      final double launchPitch = SightSolver.solvePitch(targetDistance, py);

      // 3. Launch arrow at full draw speed with per-arrow wind model
      arrowPhysics.launch(
        startX: 0.0,
        startY: ArcheryK.launchY,
        startZ: ArcheryK.launchZ,
        launchYaw: launchYaw,
        launchPitch: launchPitch,
        speed: ArcheryK.fullDrawSpeed,
        targetDist: targetDistance,
        windModel: windModel,
        windScale: ArcheryK.windScaleFor(targetDistance),
      );

      cameraRig.fireShot();
      cameraRig.addShake(3.5);
    };

    controller.onHoldStarted = ArcheryAudio.playDrawCreak;

    // Camera Rig phase transitions
    cameraRig.onPhaseChanged = (ShotPhase phase) {
      if (phase == ShotPhase.aiming) ArcheryAudio.playFullDrawClick();
      events.phaseChanged(phase);
    };

    cameraRig.onReturnedToLine = () {
      _botArrows.clear();
      _setupCurrentArrow();
      events.windChanged(windModel.display);
    };

    _startIntro();
  }

  /// Set start: the camera waits at the target while the opponent's three
  /// arrows land one by one, then dollies back to the line for your turn.
  void _startIntro() {
    _botArrows.clear();
    _introTime = 0.0;
    _introLanded = 0;
    cameraRig.startIntro();
  }

  void _updateIntro(double dt) {
    if (_introTime < 0.0) return;
    _introTime += dt;
    const int n = ArcheryMatchState.arrowsPerSet;
    if (_introLanded < n && _introTime >= _introFirst + _introLanded * _introGap) {
      _introLanded++;
      final ShotScore? shot = events.botArrowLanded();
      if (shot != null) _landBotArrow(shot);
    }
    if (_introLanded >= n && _introTime >= _introFirst + (n - 1) * _introGap + _introHold) {
      _introTime = -1.0;
      cameraRig.endIntro();
    }
  }

  void _landBotArrow(ShotScore shot) {
    // Came in from the shooting line, dropping slightly.
    final double yaw = math.atan2(shot.localX, targetDistance);
    final double pitch = -0.015 - 0.0008 * targetDistance;
    _botArrows.add(
      StuckArrow(
        hitLocalX: shot.localX,
        hitLocalY: shot.localY,
        hitZ: targetDistance,
        pitch: pitch,
        yaw: yaw,
        penetrationDepth: 0.10,
      ),
    );
    hitPopup.trigger(
      worldX: shot.localX,
      worldY: ArcheryK.targetCenterY + shot.localY,
      worldZ: targetDistance,
      score: shot,
    );
    ArcheryAudio.playImpact(
      distance: 0.0, // heard from the camera at the target: no delay
      isX: shot.ring >= 10,
      hitBoss: true,
      hitGround: false,
    );
    cameraRig.addShake(shot.isX ? 4.0 : 2.5);
  }

  /// "Next set" from the set-end card: clear the target and walk back to the line.
  void advanceNextSet() {
    events.nextSet();
    _setOver = false;
    stuckArrows.clear();
    hitPopup.reset();
    _applySetDistance();
    _setupCurrentArrow();
    events.windChanged(windModel.display);
    // Cut to the new target (the set card covers the cut) and replay the
    // opponent's arrows for this set.
    _startIntro();
  }

  /// "Play again" after the match: new seed (in the notifier), fresh target.
  void restartMatch() {
    events.restartMatch();
    _setOver = false;
    stuckArrows.clear();
    hitPopup.reset();
    _applySetDistance();
    _setupCurrentArrow();
    events.windChanged(windModel.display);
    _startIntro();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final double w = size.x;
    final double h = size.y;

    archeryCamera.screenW = w;
    archeryCamera.screenH = h;
    archeryCamera.uiScale = (math.min(w, h) / 400.0).clamp(0.85, 1.6);
    controller.screenW = w;
    controller.screenH = h;
    background.resize(w, h);
    bowOverlay.resize(w, h);

    archeryCamera.prepare();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final double clampedDt = dt.clamp(0.0, 0.05);

    // 1. Update Input & Crosshair
    controller.update(clampedDt);

    // 1b. Set-start replay of the opponent's arrows
    _updateIntro(clampedDt);

    // 2. Update Camera Rig with arrow follow and phase transitions
    cameraRig.update(
      clampedDt,
      controller.isHolding,
      arrow: arrowPhysics,
    );

    // 3. Update Bow Overlay slide progress
    bowOverlay.update(clampedDt, slide: cameraRig.bowSlideProgress);

    // 4. Update Arrow Physics
    final bool wasInFlight = arrowPhysics.inFlight;
    arrowPhysics.update(clampedDt);

    // Impact detection
    if (wasInFlight && !arrowPhysics.inFlight) {
      final ShotScore score = TargetScoring.calculate(
        localX: arrowPhysics.hitLocalX,
        localY: arrowPhysics.hitLocalY,
        hitBoss: arrowPhysics.hitBoss,
        distance: targetDistance,
      );

      // Distance-delayed impact audio
      ArcheryAudio.playImpact(
        distance: targetDistance,
        isX: score.ring >= 10,
        hitBoss: arrowPhysics.hitBoss,
        hitGround: arrowPhysics.hitGround,
      );

      // Hit Popup canvas 3D coordinates & event emission (Bug #6)
      hitPopup.trigger(
        worldX: arrowPhysics.hitPoint.x,
        worldY: arrowPhysics.hitPoint.y,
        worldZ: arrowPhysics.hitPoint.z,
        score: score,
      );
      if (arrowPhysics.hitBoss) HapticFeedback.mediumImpact();

      // Report the shot; the notifier scores it (and the set on the last arrow).
      final bool isLastArrow = events.shotScored(score);
      _setOver = isLastArrow;

      if (arrowPhysics.hitBoss) {
        cameraRig.addShake(score.isX ? 7.0 : 4.5);
        stuckArrows.add(
          StuckArrow(
            hitLocalX: arrowPhysics.hitLocalX,
            hitLocalY: arrowPhysics.hitLocalY,
            hitZ: arrowPhysics.targetDistance,
            pitch: arrowPhysics.pitch,
            yaw: arrowPhysics.yaw,
            penetrationDepth: arrowPhysics.penetrationDepth,
          ),
        );
      } else if (arrowPhysics.hitGround) {
        cameraRig.addShake(1.5);
      }

      // Trigger closeup inspection
      cameraRig.onImpact(isLastArrowOfSet: isLastArrow);
    }

    // 6. Update Stuck Arrows
    for (final arrow in stuckArrows) {
      arrow.update(clampedDt);
    }

    // Opponent's replay arrows fade out as the camera heads back to the line.
    if (_botArrows.isNotEmpty) {
      final double o = cameraRig.phase == ShotPhase.returning
          ? (1.0 - cameraRig.phaseTime / _botFadeSeconds).clamp(0.0, 1.0)
          : (cameraRig.phase == ShotPhase.intro ? 1.0 : 0.0);
      for (final arrow in _botArrows) {
        arrow.opacity = o;
        arrow.update(clampedDt);
      }
    }

    // 7. Update Canvas Hit Popup
    hitPopup.update(clampedDt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Camera shake moves the 3D world only; the bow, popup and crosshair stay steady.
    canvas.save();
    canvas.translate(cameraRig.shakeOffsetX, cameraRig.shakeOffsetY);

    // Layer 0: Park Background
    background.render(canvas);

    // "50ft" tag lying on the shooting line
    distanceTag.render(canvas);

    // Layer 1: White Target Board, Wooden Frame & WA Face
    targetBoard.render(canvas);

    // Layer 2: Stuck Arrows embedded in board
    for (final arrow in _botArrows) {
      arrow.render(canvas, archeryCamera);
    }
    for (final arrow in stuckArrows) {
      arrow.render(canvas, archeryCamera);
    }

    // Layer 3: Flying Arrow + Motion Trail
    flyingArrow.render(canvas);

    // Layer 4: World-Anchored Wind Pill
    windPill.render(canvas, windModel);

    canvas.restore();

    // Layer 5: Foreground Recurve Bow Overlay
    bowOverlay.render(canvas);

    // Layer 6: Hit score popup in 3D world space (Bug #6)
    hitPopup.render(canvas, archeryCamera);

    // Layer 7: Crosshair, Steady Ring & Shot Timer Arc
    controller.render(canvas);
  }

  @override
  Color backgroundColor() => const Color(0xFF6BA4E8);
}
