/// Model representing a real-time courtside reaction (floating emoji or text banter)
/// sent by match participants during live rounds.
class LiveReactionEvent {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderAvatar;
  final bool isEmoji;
  final String content;
  final int timestamp;

  const LiveReactionEvent({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderAvatar,
    required this.isEmoji,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderUid': senderUid,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'isEmoji': isEmoji,
    'content': content,
    'timestamp': timestamp,
  };

  factory LiveReactionEvent.fromMap(
    Map<String, dynamic> map, [
    String? docId,
  ]) => LiveReactionEvent(
    id: docId ?? (map['id'] as String? ?? ''),
    senderUid: map['senderUid'] as String? ?? '',
    senderName: map['senderName'] as String? ?? 'Player',
    senderAvatar: map['senderAvatar'] as String? ?? '👤',
    isEmoji: map['isEmoji'] as bool? ?? true,
    content: map['content'] as String? ?? '🔥',
    timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
  );
}
