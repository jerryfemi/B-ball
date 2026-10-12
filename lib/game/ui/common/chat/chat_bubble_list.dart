import 'package:flutter/material.dart';

import '../../../../models/cloud_match.dart';
import '../app_avatar.dart';
import '../app_colors.dart';

/// Centralized, high-performance chat bubble list for in-game banter and direct messaging.
///
/// Features alternating bubble alignments, sender avatar badges,
/// custom theme colors, and auto-scroll compatibility.
class ChatBubbleList extends StatelessWidget {
  /// Ordered list of chat messages to render.
  final List<CloudChatMessage> messages;

  /// Local player's UID used to determine outgoing vs incoming bubble styling.
  final String myUid;

  /// Optional scroll controller for managing list scroll position.
  final ScrollController? controller;

  /// Text displayed when no messages exist yet.
  final String emptyMessage;

  /// Padding surrounding the list.
  final EdgeInsetsGeometry padding;

  const ChatBubbleList({
    super.key,
    required this.messages,
    required this.myUid,
    this.controller,
    this.emptyMessage = 'No banter yet. Send a quick reaction below! 🎯',
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        final isMe = msg.senderUid == myUid;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            constraints: const BoxConstraints(maxWidth: 270.0),
            decoration: BoxDecoration(
              color: isMe ? AppColors.bubbleUser : AppColors.surfaceTile,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14.0),
                topRight: const Radius.circular(14.0),
                bottomLeft: Radius.circular(isMe ? 14.0 : 2.0),
                bottomRight: Radius.circular(isMe ? 2.0 : 14.0),
              ),
              border: Border.all(
                color: isMe
                    ? const Color(0xFF3B82F6)
                    : AppColors.borderInput,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  AppAvatar(avatar: msg.senderAvatar, size: 16.0),
                  const SizedBox(width: 8.0),
                ],
                Flexible(
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8.0),
                  AppAvatar(avatar: msg.senderAvatar, size: 16.0),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
