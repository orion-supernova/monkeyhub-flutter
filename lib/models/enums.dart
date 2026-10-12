enum FriendshipStatus { none, friend, outgoingPending, incomingPending }

enum RoomType { regular, secret }

/// Ordering is free: [MessageTypeWire.wire] is `name`, so nothing anywhere
/// depends on the index.
///
/// [location] and [liveLocation] are two members rather than one plus a flag
/// for the same reason [image] and [video] are: every renderer here dispatches
/// on this enum with an exhaustive `switch`, so a share that moves and a share
/// that does not are two cases the compiler makes somebody answer. Folded into
/// one member with a nullable deadline beside it, "did you handle the live
/// case?" would be a question no tool could ask.
///
/// [videoNote] is separate from [video] on the same principle: it is a video
/// by storage and a different thing by every rule that matters — round, capped
/// at a minute, played in place. A `video` with an `isNote` flag would have let
/// every existing `case video:` silently claim it.
///
/// [poll], [checklist] and [event] are the interactive kinds: a message the
/// room answers rather than reads. Three members and not one `interactive`
/// plus a kind field, for the third time and the same reason — each draws a
/// different card, and the exhaustive switches in `message_bubble.dart` are
/// where a missed case has to become a compile error rather than a blank
/// bubble. Their body does NOT live on [ChatMessage]: it arrives on its own
/// subscription as a [MessageInteraction], because a vote must not rebuild the
/// transcript. See `backend/convex/schema.ts:messageInteractions`.
///
/// [gif] and [sticker] are pictures that are not attachments: nothing was
/// uploaded, the row names the art (a KLIPY URL, or a sticker pack's blob) and
/// both draw bubble-less. Two members for the usual reason — a sticker is a
/// cut-out that floats on the transcript, a GIF is a rectangle that loops.
enum MessageType {
  text,
  image,
  video,
  videoNote,
  audio,
  file,
  url,
  system,
  location,
  liveLocation,
  poll,
  checklist,
  event,
  gif,
  sticker,

  /// An in-chat game's card: `content` is the game's name, and the live body
  /// (seats, board, result) is a `ChatMatch` from `MatchesStore`.
  game,

  /// "Beat my time": a daily result sent as a dare. `content` is a readable
  /// line; the body is a `GameChallenge` from `ChallengesStore`.
  challenge,
}

/// Whether this type's body is a [MessageInteraction] delivered beside the
/// transcript rather than carried on the message row.
///
/// One reading of the condition, because four places have to agree about it:
/// the bubble picking a renderer, the capability table deciding what a
/// long-press affords, the repository deciding which ids to ask
/// `interactions:stateForMessages` about after a page load, and the cache
/// deciding what to write beside the messages it saves.
extension MessageTypeInteractive on MessageType {
  bool get isInteractive =>
      this == MessageType.poll ||
      this == MessageType.checklist ||
      this == MessageType.event;
}

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
      case 'location':
        return MessageType.location;
      case 'liveLocation':
        return MessageType.liveLocation;
      // The three interactive kinds. A client too old to know them falls
      // through to `text` below and renders the prompt as a plain sentence,
      // which is exactly what `content` holds — see the schema note on why the
      // question lives on the message row. A poll degrades to the words it
      // asked rather than to a blank bubble.
      case 'poll':
        return MessageType.poll;
      case 'checklist':
        return MessageType.checklist;
      case 'event':
        return MessageType.event;
      // A client too old to know these shows `content` as text: the GIF's
      // title, or the emoji a sticker stands for — see `messages:send`.
      case 'gif':
        return MessageType.gif;
      // An old client shows the game's name as a line of text.
      case 'game':
        return MessageType.game;
      case 'challenge':
        return MessageType.challenge;
      case 'sticker':
        return MessageType.sticker;
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
