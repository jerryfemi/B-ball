import 'dart:math' as math;
import '../archery_constants.dart';
import 'archery_camera.dart';

/// Manages camera orientation, spring-damped zoom, sway, and shake.
class CameraRig {
  final ArcheryCamera camera;

  CameraRig({required this.camera});

  // --- Aim Angles (radians) ---
  double targetYaw = 0.0;
  double targetPitch = 0.0;
  double currentYaw = 0.0;
  double currentPitch = 0.0;
  double _yawVel = 0.0;
  double _pitchVel = 0.0;

  // --- FOV & Zoom State ---
  double currentFov = ArcheryK.idleFovRad;
  double _fovVel = 0.0;
  double _targetDistance = ArcheryK.distNear;

  // --- Post-Release Zoom Hold ---
  double zoomHoldTimer = 0.0;

  // --- External Sway / Offsets (e.g. from fatigue) ---
  double swayYaw = 0.0;
  double swayPitch = 0.0;

  // --- Camera Shake ---
  double _shakeAmp = 0.0;
  double _shakeTimer = 1000.0;
  double shakeOffsetX = 0.0;
  double shakeOffsetY = 0.0;

  /// Sets the active distance of the target downrange in meters.
  void setTargetDistance(double distance) {
    _targetDistance = distance;
  }

  /// Adds an impulse shake to the camera in pixels.
  void addShake(double pixels) {
    if (pixels > _shakeAmp) {
      _shakeAmp = pixels;
      _shakeTimer = 0.0;
    }
  }

  /// Calculates the zoomed FOV required so that the target face
  /// fills [ArcheryK.faceScreenFraction] of the screen height.
  double getZoomedFovForDistance(double distance) {
    final double targetAngularHeight =
        (2.0 * ArcheryK.faceRadius / ArcheryK.faceScreenFraction) / (2.0 * distance);
    return 2.0 * math.atan(targetAngularHeight);
  }

  /// Adds touch drag delta to the target aim angles.
  void addAimDelta(double deltaYaw, double deltaPitch) {
    targetYaw = (targetYaw + deltaYaw).clamp(-ArcheryK.maxYawRad, ArcheryK.maxYawRad);
    targetPitch = (targetPitch + deltaPitch).clamp(ArcheryK.minPitchRad, ArcheryK.maxPitchRad);
  }

  /// Resets aim to dead-center.
  void resetAim() {
    targetYaw = 0.0;
    targetPitch = 0.0;
    currentYaw = 0.0;
    currentPitch = 0.0;
    _yawVel = 0.0;
    _pitchVel = 0.0;
    swayYaw = 0.0;
    swayPitch = 0.0;
  }

  /// Updates FOV, spring smoothing, shake, and prepares [camera].
  void update(double dt, double drawRatio, bool isHolding) {
    // 1. Calculate Target FOV based on draw progress
    double desiredFov = ArcheryK.idleFovRad;

    if (isHolding) {
      final double zoomedFov = getZoomedFovForDistance(_targetDistance);
      // Ease out cubic: 1 - (1 - d)^3
      final double clampedDraw = drawRatio.clamp(0.0, 1.0);
      final double inv = 1.0 - clampedDraw;
      final double ease = 1.0 - (inv * inv * inv);
      desiredFov = ArcheryK.idleFovRad + (zoomedFov - ArcheryK.idleFovRad) * ease;
      zoomHoldTimer = 0.15;
    } else if (zoomHoldTimer > 0.0) {
      zoomHoldTimer -= dt;
      final double zoomedFov = getZoomedFovForDistance(_targetDistance);
      desiredFov = zoomedFov;
    }

    // 2. Critically Damped Spring for FOV
    // a = omega² * (target - fov) - 2 * omega * vel
    final double omega = ArcheryK.fovSpringOmega;
    final double fovError = desiredFov - currentFov;
    final double fovAccel = (omega * omega * fovError) - (2.0 * omega * _fovVel);
    _fovVel += fovAccel * dt;
    currentFov += _fovVel * dt;

    // 3. Smooth Yaw & Pitch with fast responsive spring (omega = 24)
    const double aimOmega = 24.0;
    final double yawError = targetYaw - currentYaw;
    final double yawAccel = (aimOmega * aimOmega * yawError) - (2.0 * aimOmega * _yawVel);
    _yawVel += yawAccel * dt;
    currentYaw += _yawVel * dt;

    final double pitchError = targetPitch - currentPitch;
    final double pitchAccel = (aimOmega * aimOmega * pitchError) - (2.0 * aimOmega * _pitchVel);
    _pitchVel += pitchAccel * dt;
    currentPitch += _pitchVel * dt;

    // 4. Update Shake
    _shakeTimer += dt;
    if (_shakeTimer < 0.35) {
      final double decay = math.exp(-_shakeTimer * 14.0);
      final double amp = _shakeAmp * decay;
      // High-frequency deterministic shake oscillation
      shakeOffsetX = amp * math.sin(_shakeTimer * 55.0);
      shakeOffsetY = amp * math.cos(_shakeTimer * 43.0);
    } else {
      shakeOffsetX = 0.0;
      shakeOffsetY = 0.0;
      _shakeAmp = 0.0;
    }

    // 5. Transfer to Camera fields and prepare projection
    camera.fovY = currentFov;
    camera.yaw = currentYaw + swayYaw;
    camera.pitch = currentPitch + swayPitch;
    camera.prepare();
  }
}
