import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tiny 3-bar connection gauge pinned to a 1v1 avatar.
///
/// [level]: 0 = unknown (hidden), 1 = poor (red), 2 = fair (amber),
/// 3 = good (green). Rebuilds only when the level changes.
class NetSignalBadge extends StatelessWidget {
  final ValueListenable<int> level;

  const NetSignalBadge({super.key, required this.level});

  static const Color _good = Color(0xFF22C55E);
  static const Color _fair = Color(0xFFF59E0B);
  static const Color _poor = Color(0xFFEF4444);
  static const Color _off = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: level,
      builder: (context, value, _) {
        if (value <= 0) return const SizedBox.shrink();
        final color = switch (value) {
          >= 3 => _good,
          2 => _fair,
          _ => _poor,
        };
        return Tooltip(
          message: switch (value) {
            >= 3 => 'Good connection',
            2 => 'Slow connection',
            _ => 'Poor connection',
          },
          child: Container(
            width: 17.0,
            height: 17.0,
            decoration: BoxDecoration(
              color: const Color(0xF00A0E1A),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 1.2),
                  Container(
                    width: 2.2,
                    height: 3.0 + i * 2.2,
                    decoration: BoxDecoration(
                      color: i < value ? color : _off,
                      borderRadius: BorderRadius.circular(1.0),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
