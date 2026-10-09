import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class Basketball extends BodyComponent with DragCallbacks {
  final Vector2 initialPosition;
  final double radius;
  final VoidCallback? onLaunched;

  ui.FragmentProgram? _program;

  // Track 3D rotation driven by 2D physics (initialized with organic resting tilt)
  double _pitch = 0.36; // tilted forward toward camera
  double _yaw = -0.42; // tilted sideways

  bool isLaunched = false;
  double timeSinceLaunch = 0.0;

  final bool animateEntrance;
  bool isEntering = false;
  double enterProgress = 0.0;

  // 2.5D Coordinates (in world meters):
  // x3d: lateral offset from court center (- = left, + = right, 0 = center)
  // y3d: altitude above hardwood floor (0.0 = grounded on floor)
  // z3d: depth into gym (0.0 = player hands in foreground, 4.5 = hoop center, 4.85 = backboard)
  double x3d = 0.0;
  double y3d = 0.0;
  double z3d = 0.0;

  double vx3d = 0.0;
  double vy3d = 0.0;
  double vz3d = 0.0;

  bool hasScored = false;

  Vector2? _dragStartPos;
  Vector2? _lastDragPos;
  int? _dragStartTimeMs;

  Basketball({
    required this.initialPosition,
    this.radius = 0.78,
    this.onLaunched,
    this.animateEntrance = false,
  }) : super(priority: 2) {
    if (animateEntrance) {
      isEntering = true;
    }
  }

  // Perspective depth scale factor: shrinks organically as depth z increases
  double getDepthScale(double z) {
    return 3.2 / (3.2 + z * 0.95);
  }

  // Hardwood floor Y position in world meters based on depth z
  // z = 0.0 (player foreground): 19.2m
  // z = 4.5 (hoop base): 10.0m (50% screen height)
  double getFloorY(double z) {
    final t = (z / 4.5).clamp(0.0, 1.3);
    return 19.2 - t * 9.2;
  }

  // Project 3D (x, y, z) into 2D world coordinates (projX, projY)
  Vector2 project3D(double x, double y, double z) {
    final s = getDepthScale(z);
    final floorY = getFloorY(z);
    final projX = x * s;
    final sRim = getDepthScale(4.5);
    // At rim (y=3.05, z=4.5), height above floor on screen is 10.0 - 5.0 = 5.0m
    final heightOnScreen = y * (5.0 / 3.05) * (s / sRim);
    final projY = floorY - radius * s - heightOnScreen;
    return Vector2(projX, projY);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/basketball.frag');
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
  }

  @override
  Body createBody() {
    x3d = 0.0;
    y3d = 0.0;
    z3d = 0.0;

    final projPos = project3D(x3d, y3d, z3d);
    final startY = animateEntrance ? projPos.y + 2.5 : projPos.y;

    final bodyDef = BodyDef(
      type: BodyType.kinematic,
      position: Vector2(projPos.x, startY),
      linearDamping: 0.0,
      angularDamping: 0.0,
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      density: 1.0,
      material: SurfaceMaterial(
        friction: 0.8,
        restitution: 0.82,
      ),
      filter: forge2d.Filter(
        categoryBits: 2,
        maskBits: 0, // Ballistic engine handles 3D depth collisions internally
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
      final projPos = project3D(0.0, 0.0, 0.0);
      final curY = ui.lerpDouble(projPos.y + 2.5, projPos.y, t)!;
      body.setTransform(
        Vector2(projPos.x, curY),
        const forge2d.Rot.identity(),
      );
      return;
    }

    if (isLaunched) {
      timeSinceLaunch += dt;
      // Garbage collection: remove ball 5.0 seconds after shot
      if (timeSinceLaunch > 5.0) {
        removeFromParent();
        return;
      }

      // 1. Gravity acting in 3D downward toward the floor
      const double gravity = 36.0;
      vy3d -= gravity * dt;

      // 2. Integrate 3D positions
      x3d += vx3d * dt;
      y3d += vy3d * dt;
      z3d += vz3d * dt;

      // Subtle aerodynamic drag
      final dragFactor = math.pow(0.98, dt * 60).toDouble();
      vx3d *= dragFactor;
      vz3d *= dragFactor;

      // 3. Backboard interaction (backboard at depth z = 4.85m)
      if (z3d >= 4.85) {
        if (x3d.abs() <= 1.8 && y3d >= 2.3 && y3d <= 4.6) {
          z3d = 4.85;
          vz3d = -vz3d.abs() * 0.62; // Rebound forward into court!
          vx3d += (x3d * 0.4); // Bank angle deflection
          vy3d *= 0.85;
        }
      }

      // 4. Rim interaction (rim centered at x = 0, y = 3.05m, z = 4.5m)
      // Only interact when passing through the rim depth zone [4.1m, 4.8m]
      if (z3d >= 4.1 && z3d <= 4.8) {
        final distToRimCenter =
            math.sqrt(x3d * x3d + (z3d - 4.5) * (z3d - 4.5));
        final altDiff = y3d - 3.05;

        // Ball is descending and in rim plane
        if (vy3d < 0 && altDiff.abs() < 0.40) {
          if (distToRimCenter <= 0.45) {
            // SWISH! Pass cleanly through cylinder
            if (!hasScored) {
              hasScored = true;
            }
            vx3d *= 0.70;
            vz3d *= 0.70;
            vy3d *= 0.85;
          } else if (distToRimCenter > 0.45 && distToRimCenter <= 0.95) {
            // RIM HIT: elastic deflection off the ring
            final angle = math.atan2(z3d - 4.5, x3d);
            final speed = math.sqrt(vx3d * vx3d + vy3d * vy3d + vz3d * vz3d);
            vx3d = math.cos(angle) * (speed * 0.45);
            vz3d = math.sin(angle) * (speed * 0.45);
            vy3d = vy3d.abs() * 0.55; // Bounce up off rim
          }
        }
      }

      // 5. Hardwood court floor bounce (occurs at depth z3d!)
      if (y3d <= 0.0) {
        y3d = 0.0;
        if (vy3d < 0) {
          vy3d = -vy3d * 0.68; // Floor restitution
          vx3d *= 0.72;
          vz3d *= 0.72;
          if (vy3d < 1.2) {
            vy3d = 0.0; // Settle on court
          }
        }
      }

      // 6. Natural 3D spin tumbling
      _pitch -= vy3d * dt * 0.15;
      _pitch -= vz3d * dt * 0.25;
      _yaw -= vx3d * dt * 0.20;

      // 7. Update projected 2D position in world
      final projPos = project3D(x3d, y3d, z3d);
      body.setTransform(projPos, const forge2d.Rot.identity());
    }
  }

  @override
  void render(Canvas canvas) {
    final currentScale = getDepthScale(z3d);
    final currentFloorY = getFloorY(z3d);
    final distToFloor = currentFloorY - body.position.y;

    // 1. Dynamic Floor Drop Shadow (at the landing depth on the court!)
    if (y3d < 3.2) {
      final shadowFade = (1.0 - (y3d / 3.2)).clamp(0.0, 1.0);
      final shadowAlpha = (0.55 * shadowFade).clamp(0.0, 0.55);
      final shadowScale = (currentScale * (1.0 + (y3d / 3.2) * 0.4))
          .clamp(currentScale, currentScale * 1.5);
      final blurRadius = (0.05 + y3d * 0.06).clamp(0.05, 0.30);

      final shadowPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

      canvas.save();
      // Counter-rotate so shadow remains horizontally flat on the court
      canvas.rotate(-body.angle);

      final shadowRect = Rect.fromCenter(
        center: Offset(0, distToFloor),
        width: radius * 2.2 * shadowScale,
        height: radius * 0.55 * shadowScale,
      );
      canvas.drawOval(shadowRect, shadowPaint);
      canvas.restore();
    }

    // 2. Perspective Ball Scaling
    canvas.save();
    canvas.scale(currentScale);

    if (_program != null) {
      final shader = _program!.fragmentShader();

      final transform = canvas.getTransform();
      final logicalCenterX = transform[12];
      final logicalCenterY = transform[13];
      final logicalScale =
          math.sqrt(transform[0] * transform[0] + transform[1] * transform[1]);

      final dpr =
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

      final physicalCenterX = logicalCenterX * dpr;
      final physicalCenterY = logicalCenterY * dpr;
      final physicalRadius = radius * logicalScale * dpr;

      shader.setFloat(0, physicalCenterX);
      shader.setFloat(1, physicalCenterY);
      shader.setFloat(2, physicalRadius);
      shader.setFloat(3, _yaw);
      shader.setFloat(4, _pitch);
      shader.setFloat(5, radius);

      final paint = Paint()..shader = shader;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.2,
        height: radius * 2.2,
      );
      canvas.drawRect(rect, paint);
    } else {
      final paint = Paint()..color = const Color(0xFFFF6F00);
      canvas.drawCircle(Offset.zero, radius, paint);
    }

    canvas.restore();
  }

  @override
  bool containsPoint(Vector2 point) {
    if (isLaunched || isEntering) return false;
    final currentScale = getDepthScale(z3d);
    final dist = (point - body.position).length;
    return dist <= radius * currentScale * 2.5;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isLaunched && !isEntering) {
      _dragStartPos = event.canvasPosition;
      _lastDragPos = event.canvasPosition;
      _dragStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!isLaunched && !isEntering) {
      _lastDragPos = event.canvasEndPosition;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (isLaunched || isEntering) return;

    double vx = event.velocity.x;
    double vy = event.velocity.y;
    Vector2? delta;

    if (_dragStartPos != null &&
        _lastDragPos != null &&
        _dragStartTimeMs != null) {
      delta = _lastDragPos! - _dragStartPos!;
      final dtMs =
          (DateTime.now().millisecondsSinceEpoch - _dragStartTimeMs!)
              .clamp(40, 600);
      final dispVy = delta.y / (dtMs / 1000.0);
      final dispVx = delta.x / (dtMs / 1000.0);

      if (dispVy < vy) {
        vy = dispVy;
        vx = dispVx;
      }
    }

    // Only launch when swiped upwards toward the hoop
    final isUpward = vy <= -40.0 || (delta != null && delta.y <= -25.0);
    if (!isUpward) return;

    final speedY = vy.abs(); // In pixels per second (typically 300 to 1800 px/s)

    // 2.5D Ballistic Velocity Mapping:
    // Forward depth speed into the gym (4.8 m/s to 7.2 m/s)
    vz3d = (4.8 + (speedY / 900.0) * 1.8).clamp(4.8, 7.2);
    // Altitude launch arc speed (15.5 m/s to 19.2 m/s)
    vy3d = (15.5 + (speedY / 750.0) * 2.6).clamp(15.2, 19.5);
    // Lateral aim speed (-3.5 m/s to +3.5 m/s)
    vx3d = (vx / 160.0).clamp(-3.5, 3.5);

    isLaunched = true;
    onLaunched?.call();
  }
}

/// https://one.google.com/ai?utm_source=gemini&utm_medium=web&utm_campaign=workflow_assist_card_fix_payment&g1_landing_page=75
/// DO NOT TOUCH I KEPT THE LINK HERE FOR A REASON
