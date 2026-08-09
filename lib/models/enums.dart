enum FriendshipStatus { none, friend, outgoingPending, incomingPending }

enum RoomType { regular, secret }

/// Ordering is free: [MessageTypeWire.wire] is `name`, so nothing anywhere
/// depends on the index.
enum MessageType { text, image, video, audio, file, url, system, videoNote }

/// Where an outgoing message is in its journey.
///
/// [uploading] is media-only and load-bearing rather than cosmetic. An
/// attachment's bytes go up before the message that references them can be
/// posted, so for a few seconds there is an optimistic message with no
/// `mediaStorageId`. Both reconnect sweepers in `ChatRepository` re-issue
/// `messages:send` for anything sitting in `pending` or `error` — so without a
/// state that says "not sendable yet", the first socket reconnect during an
/// upload would post an image message pointing at nothing.
///
/// Never serialized: `ChatMessage.toJson` omits it and `fromJson` defaults to
/// [sent], which is why the order of these is free to change.
enum MessageStatus { uploading, pending, sent, error }

/// How much of a reply's quoted parent a row draws.
///
/// Three states rather than a bool because "always quote" and "never quote
/// the row above" are both wrong. Suppressing entirely made replying to the
/// newest message — the commonest action there is, one swipe — look like it
/// had done nothing. Quoting in full restated the bubble one row up, so the
/// transcript grew a second copy of a message already on screen.
enum ReplyMarker {
  /// Not a reply, or a context that deliberately wants a bare bubble (the
  /// style picker's samples, chrome that borrows the bubble for a preview).
  none,

  /// A single accent line naming the parent's sender. Used when the parent
  /// is the content row directly above: the relationship still needs saying,
  /// but the content does not need repeating.
  compact,

  /// The parent's full quote card, in whichever [ReplyStyle] is selected.
  full,
}

extension RoomTypeWire on RoomType {
  String get wire => this == RoomType.secret ? 'secret' : 'regular';
  static RoomType parse(String? raw) =>
      raw == 'secret' ? RoomType.secret : RoomType.regular;
  String get displayLabel =>
      this == RoomType.secret ? 'Chamber of Secrets' : 'Regular Room';
}

extension MessageTypeWire on MessageType {
  String get wire => name;
  static MessageType parse(String? raw) {
    switch (raw) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      // Its own type rather than a flag on `video`, because every read path
      // that lays a message out has to know the difference before it can
      // choose a shape — and a bool nobody remembered to check renders a
      // circular note as a 16∶9 tile.
      case 'videoNote':
        return MessageType.videoNote;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'url':
        return MessageType.url;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}

extension FriendshipStatusWire on FriendshipStatus {
  static FriendshipStatus parse(String? raw) {
    switch (raw) {
      case 'friend':
        return FriendshipStatus.friend;
      case 'outgoingPending':
        return FriendshipStatus.outgoingPending;
      case 'incomingPending':
        return FriendshipStatus.incomingPending;
      default:
        return FriendshipStatus.none;
    }
  }
}
