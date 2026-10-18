import 'package:flutter/material.dart';

import '../../../../models/cloud_match.dart';
import '../../../../services/auth_service.dart';

/// Card component displaying either a generated match code or the button to generate one.
class MatchCodeCard extends StatelessWidget {
  final CloudMatch? precreatedMatch;
  final bool isGeneratingCode;
  final bool codeCopied;
  final UserProfile? profile;
  final VoidCallback onGenerateCode;
  final VoidCallback onCopyCode;
  final VoidCallback onShareCode;

  const MatchCodeCard({
    super.key,
    required this.precreatedMatch,
    required this.isGeneratingCode,
    required this.codeCopied,
    required this.profile,
    required this.onGenerateCode,
    required this.onCopyCode,
    required this.onShareCode,
  });

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return SizedBox(
      height: 38.0,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: filled ? const Color(0xFF0A0E1A) : color,
          backgroundColor: filled ? color : Colors.transparent,
          side: BorderSide(color: color, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (precreatedMatch != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ROOM CODE READY',
              style: TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 10.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6.0),
            // Selectable as a last resort: long-press copies on any browser.
            SelectableText(
              precreatedMatch!.joinCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              codeCopied
                  ? 'Code copied! Share it with your rival.'
                  : 'Send this code to your rival to start the 1v1.',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: codeCopied
                        ? Icons.check_circle_rounded
                        : Icons.copy_rounded,
                    label: codeCopied ? '✓ CODE COPIED' : 'COPY',
                    color: codeCopied
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF38BDF8),
                    onTap: onCopyCode,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: _actionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'SHARE',
                    color: const Color(0xFF38BDF8),
                    onTap: onShareCode,
                    filled: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tag_rounded, color: Color(0xFF38BDF8), size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shareable 6-digit match code for randoms or rivals.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          SizedBox(
            height: 36.0,
            child: OutlinedButton.icon(
              // Never a silent dead click: the parent waits for sign-in to
              // hydrate if the profile isn't ready yet.
              onPressed: isGeneratingCode ? null : onGenerateCode,
              icon: isGeneratingCode
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  : const Icon(Icons.copy_rounded, size: 14),
              label: Text(
                isGeneratingCode ? 'GENERATING CODE...' : 'GET MATCH CODE',
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
