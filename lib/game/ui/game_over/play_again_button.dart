import 'package:flutter/material.dart';

/// Tactile, glowing action button to restart the 60-second challenge.
class PlayAgainButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PlayAgainButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: Colors.white,
          elevation: 8.0,
          shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.replay_rounded,
              size: 22.0,
              color: Colors.white,
            ),
            SizedBox(width: 8.0),
            Text(
              'PLAY AGAIN',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
