import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../services/auth_service.dart';
import '../common/app_button.dart';
import '../common/app_modal_dialog.dart';
import '../common/app_text_field.dart';
import '../common/inline_feedback.dart';

/// Modal dialog allowing the player to customize or randomize their unique Gamer Tag.
class EditGamerTagDialog extends HookWidget {
  const EditGamerTagDialog({super.key});

  static Future<void> show(BuildContext context) {
    return AppModalDialog.show<void>(
      context: context,
      builder: (ctx) => const EditGamerTagDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentName = useMemoized(
      () => AuthService.instance.currentUser?.displayName ?? 'Baller',
    );
    final controller = useTextEditingController(text: currentName);
    final errorText = useState<String?>(null);
    final isSaving = useState<bool>(false);
    final savedTag = useState<String?>(null);

    void randomizeTag() {
      HapticFeedback.lightImpact();
      final newTag = AuthService.generateUniqueGamerTag();
      controller.text = newTag;
      errorText.value = null;
    }

    Future<void> save() async {
      final clean = controller.text.trim();
      if (clean.length < 3) {
        errorText.value = 'Gamer tag must be at least 3 characters';
        return;
      }
      if (clean.length > 20) {
        errorText.value = 'Gamer tag cannot exceed 20 characters';
        return;
      }

      isSaving.value = true;
      errorText.value = null;

      HapticFeedback.mediumImpact();
      await AuthService.instance.updateProfile(displayName: clean);

      if (!context.mounted) return;
      // Confirm inside the dialog itself, then close.
      isSaving.value = false;
      savedTag.value = clean;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (context.mounted) Navigator.of(context).pop();
    }

    return AppModalDialog(
      maxWidth: 360,
      iconWidget: const Icon(
        Icons.badge_rounded,
        color: Color(0xFF38BDF8),
        size: 22,
      ),
      title: 'EDIT GAMER TAG',
      subtitle: 'Your public 1v1 player tag & name',
      child: InlineFeedbackSwitcher(
        child: savedTag.value != null
            ? _SavedTagConfirmation(
                key: const ValueKey('saved'),
                tag: savedTag.value!,
              )
            : Column(
        key: const ValueKey('form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Text Field with Randomize Suffix
          AppTextField(
            controller: controller,
            autofocus: true,
            labelText: 'PLAYER TAG',
            errorText: errorText.value,
            suffixIcon: IconButton(
              icon: const Text('🎲', style: TextStyle(fontSize: 18)),
              tooltip: 'Roll random tag',
              onPressed: randomizeTag,
            ),
            onSubmitted: (_) => save(),
          ),
          const SizedBox(height: 10),

          const Text(
            'Tip: Use the 🎲 button to roll cool monikers like Baller#4829 or Hooper#7182.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'CANCEL',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppPrimaryButton(
                  label: 'SAVE TAG',
                  backgroundColor: const Color(0xFF38BDF8),
                  isLoading: isSaving.value,
                  onPressed: save,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// In-dialog success state shown briefly after saving a new tag.
class _SavedTagConfirmation extends StatelessWidget {
  final String tag;

  const _SavedTagConfirmation({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CopiedBadge(visible: true, label: '✓ TAG UPDATED'),
          const SizedBox(height: 14),
          Text(
            tag,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Friends will see your new tag on their next refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
