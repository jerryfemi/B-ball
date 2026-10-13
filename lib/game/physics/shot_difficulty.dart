/// Presets controlling shot forgiveness, aim assist, and power clamping.
enum ShotDifficulty {
  easy(
    plateau: 0.38,
    aimDeadzone: 0.06,
    aimSoftening: 0.20,
    minPower: 0.65,
    maxPower: 1.20,
    label: 'Easy',
    emoji: '🟢',
  ),
  medium(
    plateau: 0.28,
    aimDeadzone: 0.045,
    aimSoftening: 0.30,
    minPower: 0.48,
    maxPower: 1.32,
    label: 'Medium',
    emoji: '🟡',
  ),
  hard(
    plateau: 0.16,
    aimDeadzone: 0.02,
    aimSoftening: 0.50,
    minPower: 0.35,
    maxPower: 1.45,
    label: 'Hard',
    emoji: '🔴',
  ),
  pro(
    plateau: 0.06,
    aimDeadzone: 0.00,
    aimSoftening: 1.00,
    minPower: 0.20,
    maxPower: 1.60,
    label: 'Pro',
    emoji: '⚫',
  );

  final double plateau;
  final double aimDeadzone;
  final double aimSoftening;
  final double minPower;
  final double maxPower;
  final String label;
  final String emoji;

  const ShotDifficulty({
    required this.plateau,
    required this.aimDeadzone,
    required this.aimSoftening,
    required this.minPower,
    required this.maxPower,
    required this.label,
    required this.emoji,
  });
}
