import 'enums.dart';
import 'message_reaction.dart';
import 'pending_upload.dart';

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

  /// The parent was a view-once photo. `messages:send` writes this sentinel in
  /// place of the parent's text and withholds its `mediaStorageId`, because a
  /// reply preview is a permanent copy — quoting a burn-after-reading photo
  /// must not be a way to keep it, or to learn the storage id the read path
  /// takes such care to strip.
  bool get isViewOnce => contentPreview == '__VIEW_ONCE__';

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
    this.mediaWidth,
    this.mediaHeight,
    this.expiresAt,
    this.status = MessageStatus.sent,
    this.edited = false,
    List<MessageReaction>? reactions,
    this.replyToId,
    this.replyToPreview,
    this.rootId,
    this.viewOnce = false,
    this.viewOnceOpened = false,
    this.viewOnceBurnedAt,
    this.upload,
  }) : reactions = reactions ?? [];

  final String id;
  final String roomId;
  final String senderId;
  String senderName;
  String content;
  final DateTime createdAt;
  MessageType type;
  String? mediaStorageId;

  /// Pixel size of [mediaStorageId], recorded by the sender.
  ///
  /// Null on anything sent before the field existed, and on media the sender
  /// couldn't measure. Read [mediaAspectRatio] rather than these directly.
  final double? mediaWidth;
  final double? mediaHeight;

  /// Width÷height of the attachment, or null when it isn't knowable from the
  /// message alone. A photo bubble sizes itself from this so it lays out at the
  /// picture's real ratio on the first frame; callers fall back to
  /// `MediaAspectCache` for messages that predate the field.
  double? get mediaAspectRatio {
    final w = mediaWidth, h = mediaHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

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

  /// Burn-after-reading photo. The server never sends [mediaStorageId] for one
  /// of these — the bytes come from `messages:openViewOnce` plus the
  /// `/viewOnce` stream, exactly once — so this flag, not the storage id, is
  /// what the bubble branches on.
  final bool viewOnce;

  /// Whether *this* viewer has already spent their look. Computed per-viewer by
  /// the server, which is what makes it hold across devices: opening on the web
  /// greys the bubble out on the phone.
  final bool viewOnceOpened;

  /// Set once the file has been deleted from the server. The message survives
  /// as a ghost bubble; nobody can open it again, including people who never did.
  final DateTime? viewOnceBurnedAt;

  bool get viewOnceBurned => viewOnceBurnedAt != null;

  /// The attachment's own bytes, present only on an optimistic message whose
  /// upload has not been reconciled away yet. Non-null is what makes a bubble
  /// paint the picture the sender chose instead of fetching back the one they
  /// just sent.
  ///
  /// Never leaves the process: [toJson] enumerates its keys and this is not among
  /// them, and the disk cache is only ever handed server-parsed messages — the
  /// pending list has no path to it at all.
  final PendingUpload? upload;

  /// Can this viewer still open it? False once burned, once spent, and on the
  /// sender's own copy — there is no reopen path for the sender, because with
  /// no authentication a "sender may always look" branch would be an oracle any
  /// recipient could drive by passing the sender's id.
  bool viewOnceOpenable({required bool isMine}) =>
      viewOnce && !isMine && !viewOnceOpened && !viewOnceBurned;

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
      mediaWidth: (j['mediaWidth'] as num?)?.toDouble(),
      mediaHeight: (j['mediaHeight'] as num?)?.toDouble(),
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
      viewOnce: (j['viewOnce'] ?? false) as bool,
      viewOnceOpened: (j['viewOnceOpened'] ?? false) as bool,
      viewOnceBurnedAt: j['viewOnceBurnedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['viewOnceBurnedAt'] as num).toInt())
          : null,
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
        // Round-trip the size too, or a cached photo bubble would come back from
        // a cold boot without the ratio it laid out with and settle all over
        // again — the exact reflow this field exists to prevent.
        if (mediaWidth != null) 'mediaWidth': mediaWidth,
        if (mediaHeight != null) 'mediaHeight': mediaHeight,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
        'edited': edited,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToPreview != null) 'replyToPreview': replyToPreview!.toJson(),
        // Round-trips through CacheStore — without it, cached messages lose
        // their thread membership on cold boot.
        if (rootId != null) 'rootId': rootId,
        // These have to survive the disk cache too. Without them a cold boot
        // would redraw a spent or burned photo as an unopened one, inviting a
        // tap that can only ever be refused.
        if (viewOnce) 'viewOnce': true,
        if (viewOnceOpened) 'viewOnceOpened': true,
        if (viewOnceBurnedAt != null)
          'viewOnceBurnedAt': viewOnceBurnedAt!.millisecondsSinceEpoch,
      };

  ChatMessage copyWith({
    String? id,
    MessageStatus? status,
    String? content,
    List<MessageReaction>? reactions,
    String? replyToId,
    ReplyPreview? replyToPreview,
    String? rootId,
    bool? viewOnceOpened,
  }) => ChatMessage(
        id: id ?? this.id,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        content: content ?? this.content,
        createdAt: createdAt,
        type: type,
        mediaStorageId: mediaStorageId,
        mediaWidth: mediaWidth,
        mediaHeight: mediaHeight,
        expiresAt: expiresAt,
        status: status ?? this.status,
        edited: edited,
        reactions: reactions ?? this.reactions,
        replyToId: replyToId ?? this.replyToId,
        replyToPreview: replyToPreview ?? this.replyToPreview,
        rootId: rootId ?? this.rootId,
        viewOnce: viewOnce,
        viewOnceOpened: viewOnceOpened ?? this.viewOnceOpened,
        viewOnceBurnedAt: viewOnceBurnedAt,
        // Carried, not droppable. A copyWith that quietly lost the bytes of an
        // in-flight send would leave a bubble that can neither paint its picture
        // nor be retried, and nothing about the call site would hint at it.
        upload: upload,
      );
}
