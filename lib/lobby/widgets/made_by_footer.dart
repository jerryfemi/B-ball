import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../lobby_style.dart';
import 'pressable.dart';

/// Bottom of the lobby: who made GameVerse and where to find him.
class MadeByFooter extends StatelessWidget {
  const MadeByFooter({super.key});

  static const List<_Social> _links = [
    _Social(_Glyph.x, '@Pope_mk14', 'https://x.com/Pope_mk14', 'Wooback on X'),
    _Social(_Glyph.instagram, '@_flutter_guy', 'https://www.instagram.com/_flutter_guy/', 'Wooback on Instagram'),
    _Social(_Glyph.github, 'jerryfemi', 'https://github.com/jerryfemi', 'Wooback on GitHub'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Made by Wooback',
          style: LobbyStyle.text(size: 14, weight: 600, color: LobbyStyle.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final l in _links) _SocialPill(link: l)],
        ),
      ],
    );
  }
}

class _Social {
  final _Glyph glyph;
  final String handle;
  final String url;
  final String label;
  const _Social(this.glyph, this.handle, this.url, this.label);
}

class _SocialPill extends StatelessWidget {
  final _Social link;
  const _SocialPill({required this.link});

  Future<void> _open() async {
    try {
      await launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing to show: the link simply doesn't open on this device.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: link.label,
      child: Pressable(
        semanticLabel: link.label,
        onTap: _open,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CustomPaint(painter: _GlyphPainter(link.glyph)),
              ),
              const SizedBox(width: 8),
              Text(link.handle, style: LobbyStyle.text(size: 13, weight: 600, color: LobbyStyle.soft)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Glyph { x, instagram, github }

/// The X, Instagram and GitHub marks, drawn from 24×24 paths (no icon
/// package needed).
class _GlyphPainter extends CustomPainter {
  final _Glyph glyph;
  const _GlyphPainter(this.glyph);

  static final Paint _fill = Paint()..color = const Color(0xFFE2E8F0);
  static final Paint _stroke = Paint()
    ..color = const Color(0xFFE2E8F0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;

  static final Path _x = Path()
    ..moveTo(18.901, 1.153)
    ..lineTo(22.581, 1.153)
    ..lineTo(14.541, 10.343)
    ..lineTo(24.000, 22.846)
    ..lineTo(16.594, 22.846)
    ..lineTo(10.794, 15.262)
    ..lineTo(4.156, 22.846)
    ..lineTo(0.474, 22.846)
    ..lineTo(9.074, 13.016)
    ..lineTo(0.000, 1.154)
    ..lineTo(7.594, 1.154)
    ..lineTo(12.837, 8.086)
    ..lineTo(18.901, 1.153)
    ..close()
    ..moveTo(17.610, 20.644)
    ..lineTo(19.649, 20.644)
    ..lineTo(6.486, 3.240)
    ..lineTo(4.298, 3.240)
    ..lineTo(17.610, 20.644)
    ..close();

  static final Path _github = Path()
    ..moveTo(12.000, 0.297)
    ..cubicTo(5.370, 0.297, 0.000, 5.670, 0.000, 12.297)
    ..cubicTo(0.000, 17.600, 3.438, 22.097, 8.205, 23.682)
    ..cubicTo(8.805, 23.795, 9.025, 23.424, 9.025, 23.105)
    ..cubicTo(9.025, 22.820, 9.015, 22.065, 9.010, 21.065)
    ..cubicTo(5.672, 21.789, 4.968, 19.455, 4.968, 19.455)
    ..cubicTo(4.422, 18.070, 3.633, 17.700, 3.633, 17.700)
    ..cubicTo(2.546, 16.956, 3.717, 16.971, 3.717, 16.971)
    ..cubicTo(4.922, 17.055, 5.555, 18.207, 5.555, 18.207)
    ..cubicTo(6.625, 20.042, 8.364, 19.512, 9.050, 19.205)
    ..cubicTo(9.158, 18.429, 9.467, 17.900, 9.810, 17.600)
    ..cubicTo(7.145, 17.300, 4.344, 16.268, 4.344, 11.670)
    ..cubicTo(4.344, 10.360, 4.809, 9.290, 5.579, 8.450)
    ..cubicTo(5.444, 8.147, 5.039, 6.927, 5.684, 5.274)
    ..cubicTo(5.684, 5.274, 6.689, 4.952, 8.984, 6.504)
    ..cubicTo(9.944, 6.237, 10.964, 6.105, 11.984, 6.099)
    ..cubicTo(13.004, 6.105, 14.024, 6.237, 14.984, 6.504)
    ..cubicTo(17.264, 4.952, 18.269, 5.274, 18.269, 5.274)
    ..cubicTo(18.914, 6.927, 18.509, 8.147, 18.389, 8.450)
    ..cubicTo(19.154, 9.290, 19.619, 10.360, 19.619, 11.670)
    ..cubicTo(19.619, 16.280, 16.814, 17.295, 14.144, 17.590)
    ..cubicTo(14.564, 17.950, 14.954, 18.686, 14.954, 19.810)
    ..cubicTo(14.954, 21.416, 14.939, 22.706, 14.939, 23.096)
    ..cubicTo(14.939, 23.411, 15.149, 23.786, 15.764, 23.666)
    ..cubicTo(20.565, 22.092, 24.000, 17.592, 24.000, 12.297)
    ..cubicTo(24.000, 5.670, 18.627, 0.297, 12.000, 0.297)
    ..close();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    switch (glyph) {
      case _Glyph.x:
        canvas.drawPath(_x, _fill);
      case _Glyph.github:
        canvas.drawPath(_github, _fill);
      case _Glyph.instagram:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(2.2, 2.2, 19.6, 19.6), const Radius.circular(5.6)),
          _stroke,
        );
        canvas.drawCircle(const Offset(12, 12), 4.6, _stroke);
        canvas.drawCircle(const Offset(17.6, 6.4), 1.35, _fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph;
}
