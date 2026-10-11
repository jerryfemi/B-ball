import 'package:flutter/material.dart';

/// Flanking circular player avatar with vibrant green badge and "You" label.
class ScoreboardPlayerAvatar extends StatelessWidget {
  const ScoreboardPlayerAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🏀',
              style: TextStyle(fontSize: 18.0),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        const Text(
          'You',
          style: TextStyle(
            color: Color(0xFF4ADE80),
            fontSize: 10.0,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4.0),
            ],
          ),
        ),
      ],
    );
  }
}

/// Flanking help button pill with "?" icon.
class ScoreboardHelpBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const ScoreboardHelpBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          width: 34.0,
          height: 34.0,
          decoration: BoxDecoration(
            color: const Color(0xDDFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0x66FFFFFF),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
