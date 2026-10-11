import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';

/// Modal dialog for entering a 6-character arcade code to join a remote match.
class JoinMatchDialog extends StatefulWidget {
  const JoinMatchDialog({super.key});

  /// Displays the dialog and returns the joined [CloudMatch], or null if cancelled.
  static Future<CloudMatch?> show(BuildContext context) {
    return showDialog<CloudMatch>(
      context: context,
      builder: (ctx) => const JoinMatchDialog(),
    );
  }

  @override
  State<JoinMatchDialog> createState() => _JoinMatchDialogState();
}

class _JoinMatchDialogState extends State<JoinMatchDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be exactly 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.instance.ensureAuthenticated();
      final currentProfile = AuthService.instance.currentUser ??
          UserProfile(
            uid: user.uid,
            displayName: user.displayName ?? 'Player',
            avatarEmoji: '⚡',
          );

      final match = await FirestoreMatchService.instance.joinMatchByCode(
        joinCode: code,
        player2Profile: currentProfile,
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.of(context).pop(match);
      }
    } on MatchNotFoundException catch (e) {
      setState(() => _errorMessage = e.message);
    } on SelfJoinException catch (e) {
      setState(() => _errorMessage = e.message);
    } on MatchAlreadyFullException catch (e) {
      setState(() => _errorMessage = e.message);
    } on AuthRequiredException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to join: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131826),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2E3954), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🎯', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOIN MATCH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enter 6-digit game code',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Code input field
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                color: Color(0xFF00FFCC),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABCXYZ',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15),
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: const Color(0xFF1E2638),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF00FFCC), width: 1.8),
                ),
              ),
              onSubmitted: (_) => _handleJoin(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'JOIN ROOM',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
