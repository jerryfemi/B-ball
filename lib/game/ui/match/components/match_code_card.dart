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

  const MatchCodeCard({
    super.key,
    required this.precreatedMatch,
    required this.isGeneratingCode,
    required this.codeCopied,
    required this.profile,
    required this.onGenerateCode,
    required this.onCopyCode,
  });

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                InkWell(
                  onTap: onCopyCode,
                  borderRadius: BorderRadius.circular(6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        codeCopied
                            ? Icons.check_circle_rounded
                            : Icons.copy_rounded,
                        color: codeCopied
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF94A3B8),
                        size: 14.0,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        codeCopied ? 'COPIED' : 'COPY',
                        style: TextStyle(
                          color: codeCopied
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Text(
              precreatedMatch!.joinCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
              ),
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Code copied! Share with your rival before or after shooting.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
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
                isGeneratingCode ? 'GENERATING CODE...' : 'GET CODE & INVITE',
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
