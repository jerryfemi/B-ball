import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Unified chat input bar with quick banter chips, stylized text field,
/// and responsive action dispatch.
class ChatInputBar extends StatelessWidget {
  /// Default set of quick banter phrases shared across all in-game chat surfaces.
  static const List<String> defaultBanter = [
    'Good shot! 🏀',
    'Lucky roll... 🎲',
    'Too easy! 🥱',
    'Watch this! 🔥',
    'Brick! 🧱',
    'Rematch? ⚔️',
  ];

  /// Text editing controller for the input field.
  final TextEditingController controller;

  /// Callback invoked when a message (either typed or banter chip) is submitted.
  final ValueChanged<String> onSend;

  /// Quick banter phrases displayed horizontally above the input.
  final List<String> quickBanter;

  /// Placeholder text for the input field.
  final String hintText;

  /// Accent color for the send button and focused input outline.
  final Color accentColor;

  /// Whether to show the banter chip ribbon above the text field.
  final bool showBanterChips;

  /// Padding surrounding the text field and send button row.
  final EdgeInsetsGeometry padding;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.quickBanter = defaultBanter,
    this.hintText = 'Type message...',
    this.accentColor = AppColors.accentNeonCyan,
    this.showBanterChips = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  void _handleSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    onSend(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBanterChips && quickBanter.isNotEmpty) ...[
          SizedBox(
            height: 36.0,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: quickBanter.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8.0),
              itemBuilder: (ctx, i) {
                final text = quickBanter[i];
                return ActionChip(
                  label: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 11.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  backgroundColor: AppColors.surfaceTile,
                  side: const BorderSide(color: AppColors.borderInput),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  onPressed: () => _handleSend(text),
                );
              },
            ),
          ),
          const SizedBox(height: 8.0),
        ],
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.0,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 13.0,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceTile,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(
                        color: AppColors.borderInput,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(
                        color: AppColors.borderInput,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(
                        color: accentColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: _handleSend,
                ),
              ),
              const SizedBox(width: 8.0),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: accentColor,
                  size: 20.0,
                ),
                onPressed: () => _handleSend(controller.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
