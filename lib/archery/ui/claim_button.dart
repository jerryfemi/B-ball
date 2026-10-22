import 'package:flutter/material.dart';

/// Button that triggers win claiming when the opponent abandons the match.
class ClaimButton extends StatefulWidget {
  final Future<void> Function() onClaim;

  const ClaimButton({super.key, required this.onClaim});

  @override
  State<ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends State<ClaimButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              await widget.onClaim();
              if (mounted) setState(() => _busy = false);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          _busy ? '…' : 'CLAIM WIN',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
