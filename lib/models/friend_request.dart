import 'chat_user.dart';
import 'enums.dart';
import 'family.dart';
import 'friend_request_message.dart';

class FriendRequest {
  FriendRequest({
    required this.id,
    required this.user,
    required this.createdAt,
    required this.roomType,
    required this.messageCount,
    this.messageLifetime,
    this.initialMessage = '',
    this.stage,
    List<FriendRequestMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  final ChatUser user;
  final DateTime createdAt;
  RoomType roomType;
  Duration? messageLifetime;
  String initialMessage;
  int messageCount;

  /// Only ever set on OUTGOING requests, and only when supervision is in
  /// play — it tells the sender whether their own grown-up still has to
  /// release this, or whether it's now with the other person. Incoming
  /// requests never carry it: by the time one is visible it has already
  /// been released, so there is nothing to disclose.
  final RequestStage? stage;
  List<FriendRequestMessage> messages;

  factory FriendRequest.fromJson(Map<String, dynamic> j) {
    final ml = j['messageLifetime'];
    return FriendRequest(
      id: (j['_id'] ?? j['id']).toString(),
      user: ChatUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      roomType: RoomTypeWire.parse(j['roomType'] as String?),
      messageLifetime: ml is num ? Duration(seconds: ml.toInt()) : null,
      initialMessage: (j['initialMessage'] ?? '') as String,
      messageCount: ((j['messageCount'] ?? 0) as num).toInt(),
      stage: RequestStage.parse(j['stage'] as String?),
    );
  }
}
