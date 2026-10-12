import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/app_colors.dart';
import '../common/app_modal_sheet.dart';

/// Bottom modal sheet displayed immediately after completing a round in an online match.
/// Provides one-tap link copying, native share sheet, and optional WhatsApp nudge.
class ShareTurnSheet extends StatefulWidget {
  final String joinCode;
  final int roundIndex;
  final int roundScore;
  final String? opponentName;

  const ShareTurnSheet({
    super.key,
    required this.joinCode,
    required this.roundIndex,
    required this.roundScore,
    this.opponentName,
  });

  static Future<void> show(
    BuildContext context, {
    required String joinCode,
    required int roundIndex,
    required int roundScore,
    String? opponentName,
  }) {
    return AppModalSheet.show<void>(
      context: context,
      builder: (ctx) => ShareTurnSheet(
        joinCode: joinCode,
        roundIndex: roundIndex,
        roundScore: roundScore,
        opponentName: opponentName,
      ),
    );
  }

  @override
  State<ShareTurnSheet> createState() => _ShareTurnSheetState();
}

class _ShareTurnSheetState extends State<ShareTurnSheet> {
  bool _copied = false;

  String get _matchUrl => 'https://bball-arcade.web.app/#/join?code=${widget.joinCode}';

  String get _shareText =>
      '🏀 I just scored ${widget.roundScore} in B-Ball Round ${widget.roundIndex}! Can you beat it? Tap to shoot: $_matchUrl';

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _matchUrl));
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareNative() async {
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(
      ShareParams(
        text: _shareText,
        subject: '🏀 B-Ball 1v1 Challenge',
      ),
    );
  }

  Future<void> _shareWhatsApp() async {
    final encoded = Uri.encodeComponent(_shareText);
    final waUri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      _shareNative();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalSheet(
      heightFactor: null,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trophy icon & title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Text(
                'ROUND ${widget.roundIndex} COMPLETE',
                style: const TextStyle(
                  color: AppColors.accentNeonCyan,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
            ],
          ),
            const SizedBox(height: 8),

            Text(
              '${widget.roundScore} POINTS SCORED',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.opponentName != null
                  ? 'Sent to ${widget.opponentName}! Share link to notify them.'
                  : 'Room created! Share your code with a friend to play.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 22),

            // Join code banner
            InkWell(
              onTap: _copyToClipboard,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _copied ? const Color(0xFF00FFCC) : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ARCADE MATCH CODE',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.joinCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          _copied ? Icons.check_circle : Icons.copy_rounded,
                          color: _copied ? const Color(0xFF00FFCC) : const Color(0xFF38BDF8),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _copied ? 'COPIED!' : 'COPY',
                          style: TextStyle(
                            color: _copied ? const Color(0xFF00FFCC) : const Color(0xFF38BDF8),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action buttons: Universal Share & WhatsApp
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareNative,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('SHARE LINK'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _shareWhatsApp,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('WHATSAPP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Close / Done button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'BACK TO COURT',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
  }
}
