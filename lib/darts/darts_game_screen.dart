import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Teaser & upcoming game screen for regulation 501 / Cricket Darts.
class DartsGameScreen extends StatelessWidget {
  const DartsGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boardSize = math.min(size.width * 0.72, 320.0);

    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/games');
                      }
                    },
                    tooltip: 'Back to Lobby',
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GAMEVERSE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: Color(0xFF475569))),
                  const SizedBox(width: 6),
                  const Text(
                    'DARTS',
                    style: TextStyle(
                      color: Color(0xFFA855F7),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33A855F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x88A855F7), width: 1),
                    ),
                    child: const Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Color(0xFFE9D5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Glowing Dartboard Canvas
                        Container(
                          width: boardSize,
                          height: boardSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA855F7).withValues(alpha: 0.25),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            size: Size(boardSize, boardSize),
                            painter: const _DartboardPainter(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        const Text(
                          'Precision Darts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Authentic regulation English darts. Flick-throw physics, double-out checkouts, and strategic Cricket 1v1 battles.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Feature badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            _FeaturePill(label: '🎯 501 & 301 Checkout'),
                            _FeaturePill(label: '🏏 Tactical Cricket'),
                            _FeaturePill(label: '⚡ Real-time 1v1'),
                          ],
                        ),
                        const SizedBox(height: 36),

                        // Action button back to lobby
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/games'),
                            icon: const Icon(Icons.grid_view_rounded, size: 18),
                            label: const Text(
                              'EXPLORE GAMEVERSE LOBBY',
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA855F7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: const Color(0x66A855F7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E283D)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Custom painter for an authentic regulation London dartboard.
class _DartboardPainter extends CustomPainter {
  const _DartboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Dark surround
    final surroundPaint = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(center, r, surroundPaint);

    // Outer rim wire
    final wirePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, r * 0.98, wirePaint);

    final blackPaint = Paint()..color = const Color(0xFF0F172A);
    final creamPaint = Paint()..color = const Color(0xFFF1F5F9);
    final redPaint = Paint()..color = const Color(0xFFDC2626);
    final greenPaint = Paint()..color = const Color(0xFF16A34A);

    // 20 sectors
    final sectorAngle = 2 * math.pi / 20;
    for (int i = 0; i < 20; i++) {
      final startAngle = -math.pi / 2 - sectorAngle / 2 + i * sectorAngle;
      final sweep = sectorAngle;

      final isEven = i % 2 == 0;
      final bedPaint = isEven ? blackPaint : creamPaint;
      final ringPaint1 = isEven ? redPaint : greenPaint;

      // Single bed (outer)
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.78), startAngle, sweep, true, bedPaint);
      // Double ring
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.78), startAngle, sweep, true, ringPaint1);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.72), startAngle, sweep, true, bedPaint);
      // Treble ring
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.48), startAngle, sweep, true, ringPaint1);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.42), startAngle, sweep, true, bedPaint);
    }

    // Outer bull (Green)
    canvas.drawCircle(center, r * 0.12, greenPaint);
    // Inner bull (Red)
    canvas.drawCircle(center, r * 0.05, redPaint);

    // Wires (radial lines)
    for (int i = 0; i < 20; i++) {
      final angle = -math.pi / 2 - sectorAngle / 2 + i * sectorAngle;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + dx * r * 0.12, center.dy + dy * r * 0.12),
        Offset(center.dx + dx * r * 0.78, center.dy + dy * r * 0.78),
        wirePaint..strokeWidth = 1.0,
      );
    }

    // Ring wires
    wirePaint.strokeWidth = 1.2;
    canvas.drawCircle(center, r * 0.78, wirePaint);
    canvas.drawCircle(center, r * 0.72, wirePaint);
    canvas.drawCircle(center, r * 0.48, wirePaint);
    canvas.drawCircle(center, r * 0.42, wirePaint);
    canvas.drawCircle(center, r * 0.12, wirePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
