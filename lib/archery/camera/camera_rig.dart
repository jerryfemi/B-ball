import 'dart:math' as math;
import '../archery_constants.dart';
import '../physics/arrow_physics.dart';
import 'archery_camera.dart';

/// Shot sequence phases matching GamePigeon archery flow.
enum ShotPhase {
  atLine,   // Wide view behind shooting line (Z = -2.0)
  raising,  // Easing in towards aiming stance (Z: -2.0 -> 1.0, zoom: 1.0 -> aimZoom)
  aiming,   // Static aiming viewpoint with crosshair and steady ring
  chase,    // Dolly chasing closely behind arrow in flight
  closeup,  // Close-up impact inspection at target (Z = D - 2.2)
  returning,// Smooth dolly return back to the shooting line
  setEnd,   // Set completion summary card display (locked at closeup)
}

/// State-machine camera rig managing smooth cinematic dollies, chase cam, and shake.
class CameraRig {
  final ArcheryCamera camera;

  ShotPhase phase = ShotPhase.atLine;
  double phaseTime = 0.0;

  // Camera Dolly Positions (meters)
  double currentEyeX = 0.0;
  double currentEyeY = ArcheryK.eyeY;
  double currentEyeZ = ArcheryK.camLineZ;

  // Starting pose for current phase interpolation (from -> to lerp)
  double _fromX = 0.0;
  double _fromY = ArcheryK.eyeY;
  double _fromZ = ArcheryK.camLineZ;
  double _fromZoom = 1.0;
  double _fromBowSlide = 0.0;

  // Spring velocity for chase camera smoothing (omega = 14)
  double _chaseVelX = 0.0;
  double _chaseVelY = 0.0;
  double _chaseVelZ = 0.0;

  // Camera Shake
  double _shakeAmp = 0.0;
  double _shakeTimer = 1000.0;
  double shakeOffsetX = 0.0;
  double shakeOffsetY = 0.0;

  // Target distance
  double targetDistance = ArcheryK.distanceM;

  // Track if current closeup is for the final arrow of the set
  bool _isLastArrowOfSet = false;

  // Callbacks for phase transitions
  void Function()? onCloseupStarted;
  void Function()? onReturnedToLine;
  void Function()? onSetEndStarted;
  void Function(ShotPhase phase)? onPhaseChanged;

  CameraRig({required this.camera});

  void setTargetDistance(double distance) {
    targetDistance = distance;
  }

  void addShake(double pixels) {
    if (pixels > _shakeAmp) {
      _shakeAmp = pixels;
      _shakeTimer = 0.0;
    }
  }

  /// Target-size-preserving aiming zoom based on screen dimensions and distance.
  double get aimZoom {
    if (camera.screenW <= 0.0 || camera.screenH <= 0.0 || camera.baseFocal <= 0.0) return 1.0;
    final double depth = targetDistance - ArcheryK.camAimZ;
    final double minSide = math.min(camera.screenW, camera.screenH);
    final double calculated = (ArcheryK.aimFaceFrac * minSide * depth) /
        (2.0 * ArcheryK.faceRadius * camera.baseFocal);
    return calculated.clamp(1.0, 5.0);
  }

  /// Internal state transition recorder storing starting coordinates for deterministic easing.
  void _enter(ShotPhase p) {
    phase = p;
    phaseTime = 0.0;
    _fromX = currentEyeX;
    _fromY = currentEyeY;
    _fromZ = currentEyeZ;
    _fromZoom = camera.zoom;
    _fromBowSlide = bowSlideProgress;
    onPhaseChanged?.call(p);
  }

  /// Transition to raising phase upon finger touch down.
  void startRaising() {
    if (phase == ShotPhase.atLine || phase == ShotPhase.returning) {
      _enter(ShotPhase.raising);
    }
  }

  /// Cancel aim smoothly back to shooting line from current camera pose.
  void cancelAim() {
    if (phase == ShotPhase.raising || phase == ShotPhase.aiming) {
      _enter(ShotPhase.returning);
    }
  }

  /// Triggered when arrow is fired.
  void fireShot() {
    _enter(ShotPhase.chase);
    _chaseVelX = 0.0;
    _chaseVelY = 0.0;
    _chaseVelZ = 0.0;
  }

  /// Triggered on arrow impact.
  void onImpact({bool isLastArrowOfSet = false}) {
    _isLastArrowOfSet = isLastArrowOfSet;
    _enter(ShotPhase.closeup);
    onCloseupStarted?.call();
  }

  /// Smoothly dollies back to the shooting line from the current viewpoint.
  void returnToLine({bool isSetComplete = false}) {
    if (isSetComplete) {
      _enter(ShotPhase.setEnd);
      onSetEndStarted?.call();
    } else {
      _enter(ShotPhase.returning);
    }
  }

  /// Hard reset to line pose (e.g. on match restart).
  void reset() {
    _enter(ShotPhase.atLine);
    currentEyeX = 0.0;
    currentEyeY = ArcheryK.eyeY;
    currentEyeZ = ArcheryK.camLineZ;
    camera.zoom = 1.0;
    _shakeAmp = 0.0;
    shakeOffsetX = 0.0;
    shakeOffsetY = 0.0;
  }

  /// Returns 0.0 (bow visible at line) to 1.0 (bow fully slid out of frame).
  double get bowSlideProgress {
    switch (phase) {
      case ShotPhase.atLine:
        return 0.0;
      case ShotPhase.raising:
        final double t = (phaseTime / 0.5).clamp(0.0, 1.0);
        return _lerp(_fromBowSlide, 1.0, _easeInOutCubic(t));
      case ShotPhase.aiming:
      case ShotPhase.chase:
      case ShotPhase.closeup:
      case ShotPhase.setEnd:
        return 1.0;
      case ShotPhase.returning:
        final double t = (phaseTime / 0.8).clamp(0.0, 1.0);
        return _lerp(_fromBowSlide, 0.0, _easeInOutCubic(t));
    }
  }

  void update(double dt, bool isHolding, {ArrowPhysics3D? arrow}) {
    phaseTime += dt;

    switch (phase) {
      case ShotPhase.atLine:
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.eyeY;
        currentEyeZ = ArcheryK.camLineZ;
        camera.zoom = 1.0;
        break;

      case ShotPhase.raising:
        final double t = (phaseTime / 0.6).clamp(0.0, 1.0);
        final double ease = _easeInOutCubic(t);
        currentEyeX = _lerp(_fromX, 0.0, ease);
        currentEyeY = _lerp(_fromY, ArcheryK.eyeY, ease);
        currentEyeZ = _lerp(_fromZ, ArcheryK.camAimZ, ease);
        camera.zoom = _lerp(_fromZoom, aimZoom, ease);
        if (t >= 1.0 && isHolding) {
          _enter(ShotPhase.aiming);
        }
        break;

      case ShotPhase.aiming:
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.eyeY;
        currentEyeZ = ArcheryK.camAimZ;
        camera.zoom = aimZoom;
        break;

      case ShotPhase.chase:
        // Ease zoom back to 1.0 during first 0.25s of flight
        if (phaseTime < 0.25) {
          final double t = (phaseTime / 0.25).clamp(0.0, 1.0);
          camera.zoom = _lerp(_fromZoom, 1.0, _easeInOutCubic(t));
        } else {
          camera.zoom = 1.0;
        }

        if (arrow != null && arrow.inFlight) {
          final double maxZ = targetDistance - ArcheryK.camCloseupDist;
          final double desiredZ = (arrow.pos.z - ArcheryK.chaseBehind).clamp(ArcheryK.camAimZ, maxZ);
          final double desiredX = arrow.pos.x * 0.8;
          final double desiredY = arrow.pos.y + ArcheryK.chaseAbove;

          const double omega = 14.0;
          final double ax = omega * omega * (desiredX - currentEyeX) - 2.0 * omega * _chaseVelX;
          final double ay = omega * omega * (desiredY - currentEyeY) - 2.0 * omega * _chaseVelY;
          final double az = omega * omega * (desiredZ - currentEyeZ) - 2.0 * omega * _chaseVelZ;

          _chaseVelX += ax * dt;
          _chaseVelY += ay * dt;
          _chaseVelZ += az * dt;

          currentEyeX += _chaseVelX * dt;
          currentEyeY += _chaseVelY * dt;
          currentEyeZ += _chaseVelZ * dt;
        }
        break;

      case ShotPhase.closeup:
        final double targetZ = targetDistance - ArcheryK.camCloseupDist;
        final double t = (phaseTime / 0.35).clamp(0.0, 1.0);
        final double ease = _easeInOutCubic(t);

        currentEyeX = _lerp(_fromX, 0.0, ease);
        currentEyeY = _lerp(_fromY, ArcheryK.targetCenterY, ease);
        currentEyeZ = _lerp(_fromZ, targetZ, ease);
        camera.zoom = _lerp(_fromZoom, 1.0, ease);

        if (phaseTime >= 1.4) {
          if (_isLastArrowOfSet) {
            _enter(ShotPhase.setEnd);
            onSetEndStarted?.call();
          } else {
            _enter(ShotPhase.returning);
          }
        }
        break;

      case ShotPhase.returning:
        final double t = (phaseTime / 0.8).clamp(0.0, 1.0);
        final double ease = _easeInOutCubic(t);

        currentEyeX = _lerp(_fromX, 0.0, ease);
        currentEyeY = _lerp(_fromY, ArcheryK.eyeY, ease);
        currentEyeZ = _lerp(_fromZ, ArcheryK.camLineZ, ease);
        camera.zoom = _lerp(_fromZoom, 1.0, ease);

        if (t >= 1.0) {
          _enter(ShotPhase.atLine);
          onReturnedToLine?.call();
        }
        break;

      case ShotPhase.setEnd:
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.targetCenterY;
        currentEyeZ = targetDistance - ArcheryK.camCloseupDist;
        camera.zoom = 1.0;
        break;
    }

    // Camera Shake
    _shakeTimer += dt;
    if (_shakeTimer < 0.35) {
      final double decay = math.exp(-_shakeTimer * 14.0);
      final double amp = _shakeAmp * decay;
      shakeOffsetX = amp * math.sin(_shakeTimer * 55.0);
      shakeOffsetY = amp * math.cos(_shakeTimer * 43.0);
    } else {
      shakeOffsetX = 0.0;
      shakeOffsetY = 0.0;
      _shakeAmp = 0.0;
    }

    // Apply to camera
    camera.eyeX = currentEyeX;
    camera.eyeY = currentEyeY;
    camera.eyeZ = currentEyeZ;
    camera.prepare();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - math.pow(-2.0 * t + 2.0, 3.0) / 2.0;
  }
}
