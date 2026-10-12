import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../common/app_button.dart';
import '../common/app_modal_dialog.dart';

/// Modal dialog for entering a 6-character arcade code to join a remote match.
class JoinMatchDialog extends HookWidget {
  const JoinMatchDialog({super.key});

  static Future<CloudMatch?> show(BuildContext context) {
    return AppModalDialog.show<CloudMatch>(
      context: context,
      builder: (ctx) => const JoinMatchDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    final isLoading = useState<bool>(false);
    final errorMessage = useState<String?>(null);

    Future<void> handleJoin() async {
      final code = controller.text.trim().toUpperCase();
      if (code.length != 6) {
        errorMessage.value = 'Code must be exactly 6 characters';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

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
        if (context.mounted) {
          Navigator.of(context).pop(match);
        }
      } on MatchNotFoundException catch (e) {
        errorMessage.value = e.message;
      } on SelfJoinException catch (e) {
        errorMessage.value = e.message;
      } on MatchAlreadyFullException catch (e) {
        errorMessage.value = e.message;
      } on AuthRequiredException catch (e) {
        errorMessage.value = e.message;
      } catch (e) {
        errorMessage.value = 'Failed to join: $e';
      } finally {
        if (context.mounted) isLoading.value = false;
      }
    }

    return AppModalDialog(
      icon: '🎯',
      title: 'JOIN MATCH',
      subtitle: 'Enter 6-digit game code',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Code input field
          TextField(
            controller: controller,
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
            onSubmitted: (_) => handleJoin(),
          ),

          if (errorMessage.value != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage.value!,
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
          AppPrimaryButton(
            label: 'JOIN ROOM',
            isLoading: isLoading.value,
            onPressed: handleJoin,
          ),
        ],
      ),
    );
  }
}
