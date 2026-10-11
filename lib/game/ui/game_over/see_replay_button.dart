import 'package:flutter/material.dart';

/// Premium action button allowing the player to watch a full replay of the round's shots.
class SeeReplayButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SeeReplayButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0x2238BDF8),
          foregroundColor: const Color(0xFF38BDF8),
          side: const BorderSide(
            color: Color(0x6638BDF8),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 20.0,
              color: Color(0xFF38BDF8),
            ),
            SizedBox(width: 8.0),
            Text(
              'SEE REPLAY',
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
