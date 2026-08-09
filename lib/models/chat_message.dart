import 'enums.dart';
import 'location_share.dart';
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

/// One @-mention carried by a message: who was named, and what they were
/// called when they were named.
///
/// The username is stored alongside the id for the same reason [ReplyPreview]
/// snapshots its parent — so rendering never depends on a live roster. Three
/// places have none: history containing someone who has since left the room,
/// the thread overlay, and a cold boot off the disk cache.
///
/// Unlike a display-name snapshot this one cannot drift, and handles being
/// changeable does not alter that: this pair is frozen in the same write as the
/// `content` it points into, and [ChatMessage.mentionHandles] matches the two
/// against each other rather than against anyone's current name.
class MessageMention {
  const MessageMention({required this.userId, required this.username});

  final String userId;
  final String username;

  factory MessageMention.fromJson(Map<String, dynamic> j) => MessageMention(
        userId: (j['userId']).toString(),
        username: (j['username'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'username': username};
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
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.mediaDurationMs,
    this.posterStorageId,
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
    this.clientId,
    List<MessageMention>? mentions,
    this.mentionsEveryone = false,
    this.latitude,
    this.longitude,
    this.locationAccuracyM,
    this.liveExpiresAt,
    this.liveUpdatedAt,
    this.liveEndedAt,
    this.liveShareDurationMs,
  })  : reactions = reactions ?? [],
        mentions = mentions ?? const [];

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

  /// What the sender's filesystem called the attachment, its size in bytes, and
  /// what to upload it as. Set on [MessageType.file] and nothing else.
  ///
  /// The name is the entire content of a document bubble — there is no
  /// thumbnail to fall back on — so unlike [mediaWidth] these are not
  /// optimisations. A document that loses its name renders as an anonymous
  /// grey row that says only how big it is.
  ///
  /// [mimeType] is derived from the name by `mimeTypeForFileName`, not taken
  /// from the picker's own `XFile.mimeType`, which is null on most Android
  /// content providers and only as good as the browser's guess on web.
  final String? fileName;
  final int? fileSize;
  final String? mimeType;

  /// Playing time of an audio or video attachment, when the sender measured
  /// it. Lets a list row show `0:42` without fetching and decoding the media
  /// first — the same argument as [mediaWidth].
  final int? mediaDurationMs;

  /// A still frame of a video, stored as a second blob.
  ///
  /// Null on every video sent from web or desktop and on all history, because
  /// extraction is Android/iOS only. That is permanent rather than a migration
  /// state, so surfaces must treat its absence as an ordinary case — the grid
  /// draws a play glyph — and never as a load that has not finished.
  ///
  /// Never present on a view-once message: `messages:send` refuses to write one
  /// on an armed send, and `sanitizeViewOnce` strips it besides.
  ///
  /// Mutable for the same reason [mediaStorageId] is: the upload queue fills it
  /// in when the poster blob lands, before the message itself is posted.
  String? posterStorageId;

  DateTime? expiresAt;
  MessageStatus status;

  /// The id the server minted for an optimistic message, recorded the moment
  /// `messages:send` acks. Only ever set on a `tmp_` bubble.
  ///
  /// A successful mutation is proof the message exists, and it has to be
  /// treated as such independently of the subscription: the two travel over the
  /// same socket but not the same machinery, and the web client resets its
  /// query set on every reconnect without replaying subscriptions. So a send
  /// that acked while the socket was churning left a bubble stuck on "sending"
  /// for a message the recipient was already reading — and, worse, one that
  /// `flushPending` would post a *second* time on the next reconnect, because
  /// it re-posts anything still `pending`.
  ///
  /// With this recorded, [reconcilesWith] can drop the bubble on an exact id
  /// match rather than guessing from content and a ±10-minute window.
  String? serverId;

  /// The idempotency key the sender minted for this message, echoed back by the
  /// server on the live row. Present only on messages sent by a client new
  /// enough to send one, against a deployment new enough to store it.
  ///
  /// On a live row this names the exact optimistic bubble that produced it, so
  /// reconciliation needs no inference at all — and unlike [serverId] it is
  /// known to the *receiver* of the echo before the sender's own ack comes
  /// back, which is the case where the ack is the thing that got lost.
  final String? clientId;
  bool edited;
  List<MessageReaction> reactions;

  /// Everyone this message named with an `@`, resolved by the server at send
  /// time. Empty on the overwhelming majority of messages.
  ///
  /// The bubble re-derives the highlighted spans by looking for these exact
  /// handles in [content], rather than storing offsets: `_LinkAwareBubble`
  /// rewrites the text it renders when the user has link URLs hidden, which
  /// would shift every offset out from under them.
  final List<MessageMention> mentions;

  /// `@everyone` — addressed to the whole room rather than to anybody named.
  final bool mentionsEveryone;

  /// Whether [userId] is on the receiving end of this message's mentions.
  /// `@everyone` counts for every reader, which is the point of it.
  bool mentionsUser(String userId) =>
      mentionsEveryone || mentions.any((m) => m.userId == userId);

  /// The handles to look for in [content], keyed by who they belong to —
  /// the shape `MentionDetector` consumes.
  Map<String, String> get mentionHandles => {
        for (final m in mentions) m.userId: m.username,
      };

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

  // ── Location ──────────────────────────────────────────────────────────────
  //
  // Flat here and bundled by [locationShare], matching how every other
  // attachment's metadata is stored on this class and matching the wire. The
  // behaviour — is it live, has it ended, is it stale — lives on
  // [LocationShare] rather than here, because all of it is pure and all of it
  // is worth testing without a message.
  //
  // Mutable, unlike `mediaWidth` and friends, and that is the one thing about
  // these fields that is not obvious: a live share is the only message in this
  // app whose content is REWRITTEN after it is sent. The server patches the
  // same row as the sharer moves and `messages:list` re-delivers it, so the
  // local copy has to be able to take the new numbers in place.
  double? latitude;
  double? longitude;
  double? locationAccuracyM;

  /// Live shares only — see [LocationShare.liveExpiresAt].
  DateTime? liveExpiresAt;
  DateTime? liveUpdatedAt;
  DateTime? liveEndedAt;

  /// The duration this live share was STARTED for, in milliseconds.
  ///
  /// Send-side only, and never serialized: [toJson] omits it and the server has
  /// no such column — it stores the resulting deadline, which is what everyone
  /// reads. It exists for the same reason [upload] does. `_postMessage` builds
  /// its arguments entirely from the optimistic bubble, so both reconnect
  /// sweepers re-post from this object alone; without the duration recorded
  /// here, a live share retried after a dropped ack would be re-sent with no
  /// duration and the server would write it as a static pin.
  ///
  /// Null on every message that came from the server, which is correct — a
  /// received share is not something this device can re-send.
  final int? liveShareDurationMs;

  /// The location this message carries, or null if it carries none.
  ///
  /// Gated on the type as well as on the coordinates so a stray `latitude` on a
  /// text message — which the server refuses to write, but which a hand-built
  /// test fixture or a future field could produce — cannot turn a text bubble
  /// into a map.
  LocationShare? get locationShare {
    if (type != MessageType.location && type != MessageType.liveLocation) {
      return null;
    }
    final lat = latitude, lng = longitude;
    if (lat == null || lng == null) return null;
    return LocationShare(
      latitude: lat,
      longitude: lng,
      accuracyM: locationAccuracyM,
      liveExpiresAt: liveExpiresAt,
      liveUpdatedAt: liveUpdatedAt,
      liveEndedAt: liveEndedAt,
    );
  }

  /// Whether this viewer may still be shown a moving dot for this message.
  ///
  /// Takes `now` rather than reading the clock so the caller — a widget that
  /// already ticks once a second, or a test — decides what time it is. See
  /// [LocationShare.stateAt] for why expiry is derived and never stored.
  bool isLiveLocationRunning(DateTime now) =>
      locationShare?.stateAt(now) == LiveShareState.live;

  bool get isEphemeral => expiresAt != null;

  /// Carries an attachment, so it is unsendable until a storage id exists.
  ///
  /// Both callers are the same guard — a message of this shape with no
  /// `mediaStorageId` references nothing and must never be posted — which is
  /// why [MessageType.file] belongs here despite "media" reading like it is
  /// only about pictures. A document left out would be the one attachment the
  /// guard didn't cover, and this chain is not a `switch`, so nothing would
  /// have said so.
  bool get isMedia =>
      type == MessageType.image ||
      type == MessageType.video ||
      type == MessageType.audio ||
      type == MessageType.file;
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
      fileName: j['fileName'] as String?,
      fileSize: (j['fileSize'] as num?)?.toInt(),
      mimeType: j['mimeType'] as String?,
      mediaDurationMs: (j['mediaDurationMs'] as num?)?.toInt(),
      posterStorageId: j['posterStorageId'] as String?,
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
      clientId: j['clientId'] as String?,
      mentions: (j['mentions'] as List?)
              ?.map((m) =>
                  MessageMention.fromJson((m as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      mentionsEveryone: (j['mentionsEveryone'] ?? false) as bool,
      // `num` rather than `double` because Convex hands back a whole-number
      // latitude as an int, and a location on the equator or the prime meridian
      // would otherwise throw on the wire rather than render.
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      locationAccuracyM: (j['locationAccuracyM'] as num?)?.toDouble(),
      liveExpiresAt: _epochMs(j['liveExpiresAt']),
      liveUpdatedAt: _epochMs(j['liveUpdatedAt']),
      liveEndedAt: _epochMs(j['liveEndedAt']),
    );
  }

  static DateTime? _epochMs(Object? v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch(v.toInt())
      : null;

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
        // A document bubble is its name and its size — there is no thumbnail
        // underneath to carry it — so dropping these from the cache would give
        // a cold boot a row of anonymous grey plates.
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        // Same reasoning as `mediaWidth` above: without these a cold boot
        // redraws a video tile with no running time and no poster, then
        // acquires both when the subscription lands.
        if (mediaDurationMs != null) 'mediaDurationMs': mediaDurationMs,
        if (posterStorageId != null) 'posterStorageId': posterStorageId,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
        'edited': edited,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToPreview != null) 'replyToPreview': replyToPreview!.toJson(),
        // Round-trips through CacheStore — without it, cached messages lose
        // their thread membership on cold boot.
        if (rootId != null) 'rootId': rootId,
        // These have to round-trip too. This map is the disk cache's whole
        // record of a message, so without them a cold boot would redraw every
        // highlighted mention as flat text — and the reader's own name would
        // stop standing out in the one message that was actually aimed at them.
        if (mentions.isNotEmpty)
          'mentions': mentions.map((m) => m.toJson()).toList(),
        if (mentionsEveryone) 'mentionsEveryone': true,
        // These have to survive the disk cache too. Without them a cold boot
        // would redraw a spent or burned photo as an unopened one, inviting a
        // tap that can only ever be refused.
        if (viewOnce) 'viewOnce': true,
        if (viewOnceOpened) 'viewOnceOpened': true,
        if (viewOnceBurnedAt != null)
          'viewOnceBurnedAt': viewOnceBurnedAt!.millisecondsSinceEpoch,
        // A location bubble IS its coordinates — there is no thumbnail and no
        // text underneath — so dropping these from the cache would give a cold
        // boot a row of empty map cards, the same failure the `fileName`
        // comment above describes. `liveExpiresAt` in particular has to survive:
        // it is what a restored bubble derives its expired state from, and
        // without it a share that ended overnight would come back claiming to
        // be static and current.
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationAccuracyM != null) 'locationAccuracyM': locationAccuracyM,
        if (liveExpiresAt != null)
          'liveExpiresAt': liveExpiresAt!.millisecondsSinceEpoch,
        if (liveUpdatedAt != null)
          'liveUpdatedAt': liveUpdatedAt!.millisecondsSinceEpoch,
        if (liveEndedAt != null)
          'liveEndedAt': liveEndedAt!.millisecondsSinceEpoch,
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
        // Carried for the same reason as `mentions` below: `copyWith` runs on
        // the reaction and view-once paths, neither of which knows documents
        // exist, and a reaction that anonymised the file it was reacting to
        // would have nothing at the call site to hint at why.
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        mediaDurationMs: mediaDurationMs,
        posterStorageId: posterStorageId,
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
        // Carried for the same reason: a copy that lost these would render a
        // bubble whose text says "@bob" and whose highlighting says nothing,
        // with nothing at the call site to hint at why. `copyWith` runs on the
        // reaction and view-once paths, neither of which knows mentions exist.
        mentions: mentions,
        mentionsEveryone: mentionsEveryone,
        // Carried for the same reason as everything else in this list, and with
        // the sharpest consequence: `copyWith` runs on the reaction path, so a
        // thumbs-up on a live share that dropped these would replace a moving
        // map with an empty card — and, because `liveExpiresAt` would go too,
        // one that no longer knew it had ever been live.
        latitude: latitude,
        longitude: longitude,
        locationAccuracyM: locationAccuracyM,
        liveExpiresAt: liveExpiresAt,
        liveUpdatedAt: liveUpdatedAt,
        liveEndedAt: liveEndedAt,
        // Carried for the same reason [upload] is: a copy that lost it could
        // neither be retried as the share it was, nor say at the call site why.
        liveShareDurationMs: liveShareDurationMs,
      );
}
