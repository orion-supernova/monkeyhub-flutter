class MessageReaction {
  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
    this.album = false,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  /// A reaction to the whole album [messageId] heads, not to that one photo.
  /// See `reactions.album` in the backend schema.
  final bool album;

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
        id: (j['_id'] ?? j['id']).toString(),
        messageId: (j['messageId']).toString(),
        userId: (j['userId']).toString(),
        emoji: (j['emoji'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
        album: j['album'] == true,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'messageId': messageId,
        'userId': userId,
        'emoji': emoji,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (album) 'album': true,
      };
}
