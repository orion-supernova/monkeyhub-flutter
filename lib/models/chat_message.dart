import 'enums.dart';
import 'message_reaction.dart';

/// Denormalized snapshot of the parent message a reply was made against.
/// Stored alongside the child message at send time so the inline tether
/// keeps rendering even when the parent is later deleted or expires (the
/// server replaces [contentPreview] with the literal `__DELETED__`).
class ReplyPreview {
  const ReplyPreview({
    required this.senderId,
    required this.senderName,
    required this.contentPreview,
    required this.type,
    this.mediaStorageId,
  });

  final String senderId;
  final String senderName;
  final String contentPreview;
  final MessageType type;
  final String? mediaStorageId;

  bool get isDeleted => contentPreview == '__DELETED__';

  factory ReplyPreview.fromJson(Map<String, dynamic> j) => ReplyPreview(
        senderId: (j['senderId']).toString(),
        senderName: (j['senderName'] ?? '') as String,
        contentPreview: (j['contentPreview'] ?? '') as String,
        type: MessageTypeWire.parse(j['type'] as String?),
        mediaStorageId: j['mediaStorageId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'contentPreview': contentPreview,
        'type': type.wire,
        if (mediaStorageId != null) 'mediaStorageId': mediaStorageId,
      };
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.type = MessageType.text,
    this.mediaStorageId,
    this.expiresAt,
    this.status = MessageStatus.sent,
    this.edited = false,
    List<MessageReaction>? reactions,
    this.replyToId,
    this.replyToPreview,
    this.rootId,
  }) : reactions = reactions ?? [];

  final String id;
  final String roomId;
  final String senderId;
  String senderName;
  String content;
  final DateTime createdAt;
  MessageType type;
  String? mediaStorageId;
  DateTime? expiresAt;
  MessageStatus status;
  bool edited;
  List<MessageReaction> reactions;
  final String? replyToId;
  final ReplyPreview? replyToPreview;

  /// Id of the message at the top of this reply chain. Set by the server on
  /// replies only — a root message has no [rootId], which is why thread
  /// membership is tested with [threadKey] rather than this field directly.
  final String? rootId;

  /// The thread this message belongs to. A root is the head of its own
  /// thread, so it keys on its own id; replies key on the shared [rootId].
  /// Two messages are in the same thread iff their [threadKey]s match.
  String get threadKey => rootId ?? id;

  bool get isEphemeral => expiresAt != null;
  bool get isMedia =>
      type == MessageType.image || type == MessageType.video || type == MessageType.audio;
  bool get isReply => replyToId != null && replyToPreview != null;

  Duration timeLeft(DateTime now) {
    if (expiresAt == null) return Duration.zero;
    return expiresAt!.difference(now);
  }

  double lifeProgress(DateTime now) {
    if (expiresAt == null) return 0;
    final total = expiresAt!.difference(createdAt).inMilliseconds;
    if (total <= 0) return 1;
    final elapsed = now.difference(createdAt).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final ex = j['expiresAt'];
    final rp = j['replyToPreview'];
    return ChatMessage(
      id: (j['_id'] ?? j['id']).toString(),
      roomId: (j['roomId']).toString(),
      senderId: (j['userId'] ?? j['senderId']).toString(),
      senderName: (j['senderName'] ?? j['name'] ?? '') as String,
      content: (j['content'] ?? '') as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      type: MessageTypeWire.parse(j['type'] as String?),
      mediaStorageId: j['mediaStorageId'] as String?,
      expiresAt: ex is num ? DateTime.fromMillisecondsSinceEpoch(ex.toInt()) : null,
      edited: (j['edited'] ?? false) as bool,
      reactions: (j['reactions'] as List?)
              ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      replyToId: j['replyToId']?.toString(),
      replyToPreview: rp is Map
          ? ReplyPreview.fromJson(rp.cast<String, dynamic>())
          : null,
      rootId: j['rootId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'roomId': roomId,
        'userId': senderId,
        'senderName': senderName,
        'content': content,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'type': type.wire,
        if (mediaStorageId != null) 'mediaStorageId': mediaStorageId,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
        'edited': edited,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToPreview != null) 'replyToPreview': replyToPreview!.toJson(),
        // Round-trips through CacheStore — without it, cached messages lose
        // their thread membership on cold boot.
        if (rootId != null) 'rootId': rootId,
      };

  ChatMessage copyWith({
    String? id,
    MessageStatus? status,
    String? content,
    List<MessageReaction>? reactions,
    String? replyToId,
    ReplyPreview? replyToPreview,
    String? rootId,
  }) => ChatMessage(
        id: id ?? this.id,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        content: content ?? this.content,
        createdAt: createdAt,
        type: type,
        mediaStorageId: mediaStorageId,
        expiresAt: expiresAt,
        status: status ?? this.status,
        edited: edited,
        reactions: reactions ?? this.reactions,
        replyToId: replyToId ?? this.replyToId,
        replyToPreview: replyToPreview ?? this.replyToPreview,
        rootId: rootId ?? this.rootId,
      );
}
