enum FriendshipStatus { none, friend, outgoingPending, incomingPending }

enum RoomType { regular, secret }

enum MessageType { text, image, video, audio, url, system }

enum MessageStatus { pending, sent, error }

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
