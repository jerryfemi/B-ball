import 'dart:math' as math;
import '../archery_constants.dart';
import '../physics/arrow_physics.dart';
import 'archery_camera.dart';

/// Shot sequence phases matching GamePigeon archery flow.
enum ShotPhase {
  atLine,   // Wide view behind shooting line (Z = -2.0)
  raising,  // Easing in towards aiming stance (Z: -2.0 -> 1.0)
  aiming,   // Static aiming viewpoint with crosshair and steady ring
  chase,    // Dolly chasing closely behind arrow in flight
  closeup,  // Close-up impact inspection at target (Z = D - 2.2)
  returning,// Smooth dolly return back to the shooting line
  setEnd,   // Set completion summary card display
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

  // Spring velocity for chase camera smoothing (omega = 14)
  double _chaseVelX = 0.0;
  double _chaseVelY = 0.0;
  double _chaseVelZ = 0.0;

  // Camera Shake
  double _shakeAmp = 0.0;
  double _shakeTimer = 1000.0;
  double shakeOffsetX = 0.0;
  double shakeOffsetY = 0.0;

  // Crosshair sway offsets (passed into camera rendering)
  double swayYaw = 0.0;
  double swayPitch = 0.0;

  // Aim dummy fields for backwards compatibility
  double currentYaw = 0.0;
  double currentPitch = 0.0;

  // Target distance
  double targetDistance = ArcheryK.distanceM;

  // Callbacks for phase transitions
  void Function()? onCloseupStarted;
  void Function()? onReturnedToLine;
  void Function()? onSetEndStarted;

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

  /// Transition to raising phase upon finger touch down.
  void startRaising() {
    if (phase == ShotPhase.atLine || phase == ShotPhase.returning) {
      phase = ShotPhase.raising;
      phaseTime = 0.0;
    }
  }

  /// Cancel aim back to shooting line.
  void cancelAim() {
    if (phase == ShotPhase.raising || phase == ShotPhase.aiming) {
      phase = ShotPhase.returning;
      phaseTime = 0.0;
    }
  }

  /// Triggered when arrow is fired.
  void fireShot() {
    phase = ShotPhase.chase;
    phaseTime = 0.0;
    _chaseVelX = 0.0;
    _chaseVelY = 0.0;
    _chaseVelZ = 0.0;
  }

  /// Triggered on arrow impact.
  void onImpact({bool isLastArrowOfSet = false}) {
    phase = ShotPhase.closeup;
    phaseTime = 0.0;
    onCloseupStarted?.call();
  }

  /// Triggered after closeup concludes.
  void returnToLine({bool isSetComplete = false}) {
    if (isSetComplete) {
      phase = ShotPhase.setEnd;
      phaseTime = 0.0;
      onSetEndStarted?.call();
    } else {
      phase = ShotPhase.returning;
      phaseTime = 0.0;
    }
  }

  /// Returns 0.0 (bow visible at line) to 1.0 (bow fully slid out of frame).
  double get bowSlideProgress {
    switch (phase) {
      case ShotPhase.atLine:
        return 0.0;
      case ShotPhase.raising:
        final double t = (phaseTime / 0.5).clamp(0.0, 1.0);
        return _easeInOutCubic(t);
      case ShotPhase.aiming:
      case ShotPhase.chase:
      case ShotPhase.closeup:
      case ShotPhase.setEnd:
        return 1.0;
      case ShotPhase.returning:
        final double t = (phaseTime / 0.8).clamp(0.0, 1.0);
        return 1.0 - _easeInOutCubic(t);
    }
  }

  void update(double dt, double drawRatio, bool isHolding, {ArrowPhysics3D? arrow}) {
    phaseTime += dt;

    switch (phase) {
      case ShotPhase.atLine:
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.eyeY;
        currentEyeZ = ArcheryK.camLineZ;
        break;

      case ShotPhase.raising:
        final double t = (phaseTime / 0.6).clamp(0.0, 1.0);
        final double ease = _easeInOutCubic(t);
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.eyeY;
        currentEyeZ = ArcheryK.camLineZ + (ArcheryK.camAimZ - ArcheryK.camLineZ) * ease;
        if (t >= 1.0 && isHolding) {
          phase = ShotPhase.aiming;
          phaseTime = 0.0;
        }
        break;

      case ShotPhase.aiming:
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.eyeY;
        currentEyeZ = ArcheryK.camAimZ;
        break;

      case ShotPhase.chase:
        if (arrow != null && arrow.inFlight) {
          // Chase camera position behind and above arrow
          final double maxZ = targetDistance - ArcheryK.camCloseupDist;
          final double desiredZ = (arrow.pos.z - ArcheryK.chaseBehind).clamp(ArcheryK.camAimZ, maxZ);
          final double desiredX = arrow.pos.x * 0.8;
          final double desiredY = arrow.pos.y + ArcheryK.chaseAbove;

          // Critically damped spring (omega = 14) for silky-smooth follow
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
        // Settle at target face closeup (Z = D - 2.2m)
        final double targetZ = targetDistance - ArcheryK.camCloseupDist;
        final double t = (phaseTime / 0.35).clamp(0.0, 1.0);
        final double ease = _easeInOutCubic(t);

        currentEyeX = currentEyeX + (0.0 - currentEyeX) * ease;
        currentEyeY = currentEyeY + (ArcheryK.targetCenterY - currentEyeY) * ease;
        currentEyeZ = currentEyeZ + (targetZ - currentEyeZ) * ease;

        if (phaseTime >= 1.4) {
          returnToLine();
        }
        break;

      case ShotPhase.returning:
        final double t = (phaseTime / 0.8).clamp(0.0, 1.0);
        final double ease = _easeInOutCubic(t);
        final double startZ = targetDistance - ArcheryK.camCloseupDist;

        currentEyeX = 0.0;
        currentEyeY = ArcheryK.targetCenterY + (ArcheryK.eyeY - ArcheryK.targetCenterY) * ease;
        currentEyeZ = startZ + (ArcheryK.camLineZ - startZ) * ease;

        if (t >= 1.0) {
          phase = ShotPhase.atLine;
          phaseTime = 0.0;
          onReturnedToLine?.call();
        }
        break;

      case ShotPhase.setEnd:
        // Stay locked at closeup view until player dismisses card
        currentEyeX = 0.0;
        currentEyeY = ArcheryK.targetCenterY;
        currentEyeZ = targetDistance - ArcheryK.camCloseupDist;
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

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - math.pow(-2.0 * t + 2.0, 3.0) / 2.0;
  }
}
