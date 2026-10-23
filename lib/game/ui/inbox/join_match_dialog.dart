import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../common/clean_ui.dart';

/// Modal dialog for entering a 6-character arcade code to join a remote match.
class JoinMatchDialog extends HookWidget {
  const JoinMatchDialog({super.key});

  static Future<CloudMatch?> show(BuildContext context) {
    return CleanUi.show<CloudMatch>(context, (ctx) => const JoinMatchDialog());
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
      } on MatchClosedException catch (e) {
        errorMessage.value = e.message;
      } on SelfJoinException catch (e) {
        errorMessage.value = e.message;
      } on MatchAlreadyFullException catch (e) {
        errorMessage.value = e.message;
      } on AuthRequiredException catch (e) {
        errorMessage.value = e.message;
      } catch (e) {
        final raw = e.toString();
        final cleanMsg = raw
            .replaceAll(
              RegExp(r'^(Exception:|Error:(\s*Dart Exception:)?)\s*', caseSensitive: false),
              '',
            )
            .trim();
        errorMessage.value = cleanMsg.isNotEmpty
            ? cleanMsg
            : 'Unable to join room. Please check the code and try again.';
      } finally {
        if (context.mounted) isLoading.value = false;
      }
    }

    return CleanDialog(
      title: 'JOIN A MATCH',
      subtitle: 'Enter the 6-character code your friend sent you',
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
              fontFamily: 'Inter',
              fontVariations: const [FontVariation('wght', 900)],
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
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
                fontFamily: 'Inter',
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ],

          const SizedBox(height: 18),

          CleanButton(
            label: 'JOIN MATCH',
            icon: Icons.login_rounded,
            primary: true,
            loading: isLoading.value,
            onTap: handleJoin,
          ),
        ],
      ),
    );
  }
}
