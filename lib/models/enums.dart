enum FriendshipStatus { none, friend, outgoingPending, incomingPending }

enum RoomType { regular, secret }

enum MessageType { text, image, video, audio, url, system }

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
      case 'audio':
        return MessageType.audio;
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
