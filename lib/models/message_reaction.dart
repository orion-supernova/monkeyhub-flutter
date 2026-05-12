class MessageReaction {
  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
        id: (j['_id'] ?? j['id']).toString(),
        messageId: (j['messageId']).toString(),
        userId: (j['userId']).toString(),
        emoji: (j['emoji'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      );
}
