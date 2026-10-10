import 'package:flame/components.dart';

/// Hoop reference component.
///
/// In the 3D projectile architecture, all hoop interactions
/// (continuous 3D torus rim collision, backboard glass bounce, regulation box guidance,
/// net cylinder drag, and scoring callbacks) are handled at 240Hz inside `BallPhysics3D`.
///
/// This component retains the 2D layout anchor reference without creating
/// redundant Box2D collision shapes that would otherwise consume physics ticks.
class HoopPhysics extends Component {
  final Vector2 hoopCenterInMeters;
  final double hoopWidthInMeters;

  HoopPhysics({
    required this.hoopCenterInMeters,
    this.hoopWidthInMeters = 1.8,
  });
}

