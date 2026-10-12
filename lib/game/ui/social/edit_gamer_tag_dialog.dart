import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../common/app_modal_dialog.dart';

/// Modal dialog allowing the player to customize or randomize their unique Gamer Tag.
class EditGamerTagDialog extends StatefulWidget {
  const EditGamerTagDialog({super.key});

  static Future<void> show(BuildContext context) {
    return AppModalDialog.show<void>(
      context: context,
      builder: (ctx) => const EditGamerTagDialog(),
    );
  }

  @override
  State<EditGamerTagDialog> createState() => _EditGamerTagDialogState();
}

class _EditGamerTagDialogState extends State<EditGamerTagDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentName =
        AuthService.instance.currentUser?.displayName ?? 'Baller';
    _controller = TextEditingController(text: currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _randomizeTag() {
    HapticFeedback.lightImpact();
    final newTag = AuthService.generateUniqueGamerTag();
    setState(() {
      _controller.text = newTag;
      _errorText = null;
    });
  }

  Future<void> _save() async {
    final clean = _controller.text.trim();
    if (clean.length < 3) {
      setState(() => _errorText = 'Gamer tag must be at least 3 characters');
      return;
    }
    if (clean.length > 20) {
      setState(() => _errorText = 'Gamer tag cannot exceed 20 characters');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    HapticFeedback.mediumImpact();
    await AuthService.instance.updateProfile(displayName: clean);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gamer tag updated to "$clean"! 🎉'),
          backgroundColor: const Color(0xFF1E2638),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      maxWidth: 360,
      iconWidget: const Icon(
        Icons.badge_rounded,
        color: Color(0xFF38BDF8),
        size: 22,
      ),
      title: 'EDIT GAMER TAG',
      subtitle: 'Your public 1v1 player tag & name',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

              // Text Field with Randomize Suffix
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  labelText: 'PLAYER TAG',
                  labelStyle: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                  errorText: _errorText,
                  filled: true,
                  fillColor: const Color(0xFF1E2638),
                  suffixIcon: IconButton(
                    icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                    tooltip: 'Roll random tag',
                    onPressed: _randomizeTag,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF38BDF8),
                      width: 1.8,
                    ),
                  ),
                ),
                onSubmitted: (_) => _save(),
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
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : const Text(
                              'SAVE TAG',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}
