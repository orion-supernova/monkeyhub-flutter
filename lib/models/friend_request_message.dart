class FriendRequestMessage {
  FriendRequestMessage({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String userId;
  final String content;
  final DateTime createdAt;

  factory FriendRequestMessage.fromJson(Map<String, dynamic> j) => FriendRequestMessage(
        id: (j['_id'] ?? j['id']).toString(),
        requestId: (j['requestId'] ?? '').toString(),
        userId: (j['userId']).toString(),
        content: (j['content'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      );
}
