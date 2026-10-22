import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import 'app_avatar.dart';
import 'inline_feedback.dart';

/// Standalone dialog for viewing and updating player display name and avatar.
/// Used in the GameVerse lobby account chip and in MatchInboxSheet.
class EditProfileDialog extends StatefulWidget {
  final UserProfile currentProfile;

  const EditProfileDialog({
    super.key,
    required this.currentProfile,
  });

  /// Opens the profile editor dialog.
  static Future<void> show(BuildContext context, {UserProfile? profile}) async {
    final current = profile ??
        AuthService.instance.currentUser ??
        UserProfile(
          uid: 'guest',
          displayName: 'Player',
          avatarEmoji: AuthService.avatarImageOptions.first,
        );

    await showDialog<void>(
      context: context,
      builder: (ctx) => EditProfileDialog(currentProfile: current),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedAvatar;
  late final List<String> _avatarOptions;
  bool _isSaving = false;

  /// Inline problems (no SnackBars): a save that failed, or an empty name.
  String? _error;
  bool _nameMissing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentProfile.displayName);
    final current = widget.currentProfile.avatarEmoji;
    // Keep a custom avatar (e.g. a Lagos Life character) selectable and
    // selected, so saving a new name never silently replaces it.
    final builtIn = AuthService.avatarImageOptions;
    _avatarOptions = [
      if (current.isNotEmpty && !builtIn.contains(current)) current,
      ...builtIn,
    ];
    _selectedAvatar = current.isNotEmpty ? current : builtIn.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final cleanName = _nameCtrl.text.trim();
    if (_isSaving) return;
    if (cleanName.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _nameMissing = false;
    });
    try {
      await AuthService.instance.updateProfile(
        displayName: cleanName,
        avatarEmoji: _selectedAvatar,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = InlineErrorPanel.friendlyMessage(
              e,
              fallback: 'Couldn\'t save your profile. Please try again.',
            ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarOptions = _avatarOptions;

    return Dialog(
      backgroundColor: const Color(0xFF131826),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2E3954), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EDIT PROFILE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Selected Avatar Live Preview Circle
              Center(
                child: AppAvatar(
                  avatar: _selectedAvatar,
                  size: 96,
                  borderColor: const Color(0xFF00FFCC),
                  borderWidth: 2.5,
                  showGlow: true,
                ),
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _nameCtrl,
                maxLength: 16,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF1E2638),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'CHOOSE AVATAR',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // 15 Dunk Head Real Image Avatars using AppAvatar
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: avatarOptions.map((assetPath) {
                  final isSel = _selectedAvatar == assetPath;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedAvatar = assetPath);
                    },
                    customBorder: const CircleBorder(),
                    child: AppAvatar(
                      avatar: assetPath,
                      size: 44,
                      borderColor: isSel
                          ? const Color(0xFF00FFCC)
                          : Colors.white24,
                      borderWidth: isSel ? 2.5 : 1.2,
                      showGlow: isSel,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Problems show inside the card, never as a SnackBar.
              InlineFeedbackSwitcher(
                child: _error != null
                    ? Padding(
                        key: const ValueKey('save-error'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InlineErrorPanel(
                          title: 'PROFILE NOT SAVED',
                          message: _error!,
                          onRetry: _handleSave,
                          onDismiss: () => setState(() => _error = null),
                        ),
                      )
                    : _nameMissing
                        ? Padding(
                            key: const ValueKey('name-missing'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InlineErrorPanel(
                              icon: Icons.badge_rounded,
                              accent: const Color(0xFFF59E0B),
                              title: 'ENTER A NAME',
                              message: 'Your display name can\'t be empty.',
                              onDismiss: () => setState(() => _nameMissing = false),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-feedback')),
              ),

              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                      )
                    : const Text(
                        'SAVE PROFILE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
