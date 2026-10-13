import 'package:flutter/foundation.dart';

import 'chat_room.dart';
import 'enums.dart';

/// What a member may PUT into a room, as opposed to what chrome the room gets.
///
/// The client's mirror of `backend/convex/roomPolicy.ts`, which is the
/// authority: every send, edit, forward, reaction, pin, vote and call is
/// re-checked there, and refused with `ROOM_POSTING_RESTRICTED`. This copy only
/// decides what is OFFERED, so a read-only room shows a quiet footer instead of
/// a composer whose every send would bounce.
///
/// It rides on [RoomCapabilities.posting] rather than standing beside it, so
/// there is still one question every widget asks ("what does this room
/// afford?") and one place the answer is assembled (`roomCapabilitiesFor`).
/// The two fields this table shares with the room-kind table, [canCall] and
/// [canReceiveForwards], are ANDed into it there, so the header and the
/// forward/share sheets follow a policy without knowing it exists.
///
/// ── Presets ───────────────────────────────────────────────────────────────
///
/// A room names a preset in `rooms.postingPolicy`; the table below must match
/// `POSTING_PRESETS` server-side. An absent field means [open] on an ordinary
/// room and [readOnly] on a system room, and a preset this build has never
/// heard of means [readOnly], the same fail-closed rule an unknown
/// `rooms.system` slug gets in `room_capabilities.dart`.
@immutable
class RoomPostingPolicy {
  const RoomPostingPolicy({
    required this.kinds,
    required this.canReply,
    required this.canReact,
    required this.canReceiveForwards,
    required this.canCall,
    required this.canInteract,
    required this.canPin,
  });

  /// The kinds members may post. Null means every kind, including ones this
  /// build has not been taught.
  final Set<PostKind>? kinds;

  /// Whether a message may be posted as a reply (the REPLY row, swipe-to-reply).
  final bool canReply;

  /// Whether the reaction pill and the hover react button are offered.
  final bool canReact;

  /// Whether other rooms' messages may be forwarded or shared in.
  final bool canReceiveForwards;

  /// Whether a call can be started from this room.
  final bool canCall;

  /// Whether polls can be voted in, checklists ticked and events answered.
  final bool canInteract;

  /// Whether a message may be pinned here.
  final bool canPin;

  /// Whether [kind] may be posted.
  bool allows(PostKind kind) => kinds == null || kinds!.contains(kind);

  /// Whether every one of [wanted] may be posted.
  bool allowsAll(Iterable<PostKind> wanted) => wanted.every(allows);

  /// Whether any of [wanted] may be posted.
  bool allowsAny(Iterable<PostKind> wanted) => wanted.any(allows);

  /// Whether members may post anything at all. False is what swaps the
  /// composer for the read-only footer.
  bool get canPost => kinds == null || kinds!.isNotEmpty;

  /// Every ordinary room. Affords exactly what the app always did.
  static const open = RoomPostingPolicy(
    kinds: null,
    canReply: true,
    canReact: true,
    canReceiveForwards: true,
    canCall: true,
    canInteract: true,
    canPin: true,
  );

  /// A feed the app writes and members read: `MonkeyHub Logs`.
  static const readOnly = RoomPostingPolicy(
    kinds: <PostKind>{},
    canReply: false,
    canReact: false,
    canReceiveForwards: false,
    canCall: false,
    canInteract: false,
    canPin: false,
  );

  /// A conversation with a bot: words and pictures, replies and reactions;
  /// nothing that needs a second human or that the bot cannot read.
  static const agent = RoomPostingPolicy(
    kinds: <PostKind>{PostKind.text, PostKind.image},
    canReply: true,
    canReact: true,
    canReceiveForwards: true,
    canCall: false,
    canInteract: true,
    canPin: true,
  );

  /// Wire name → preset. Keys are `rooms.postingPolicy` values.
  static const Map<String, RoomPostingPolicy> presets = {
    'open': open,
    'readOnly': readOnly,
    'agent': agent,
  };
}

/// The kinds of content a member can post. Mirrors `POST_KINDS` in
/// `backend/convex/roomPolicy.ts` (less `system` and `other`, which no member
/// UI ever offers).
enum PostKind {
  text,
  image,
  video,
  voice,
  file,
  sticker,
  location,
  poll,
  checklist,
  event,
  game,
}

/// The one mapping from a message type to the kind a policy grants. Null for
/// a type no member posts (`system`).
PostKind? postKindOfMessageType(MessageType type) {
  switch (type) {
    case MessageType.text:
    case MessageType.url:
      return PostKind.text;
    case MessageType.image:
      return PostKind.image;
    case MessageType.video:
    case MessageType.videoNote:
      return PostKind.video;
    case MessageType.audio:
      return PostKind.voice;
    case MessageType.file:
      return PostKind.file;
    case MessageType.gif:
    case MessageType.sticker:
      return PostKind.sticker;
    case MessageType.location:
    case MessageType.liveLocation:
      return PostKind.location;
    case MessageType.poll:
      return PostKind.poll;
    case MessageType.checklist:
      return PostKind.checklist;
    case MessageType.event:
      return PostKind.event;
    case MessageType.game:
    case MessageType.gameMove:
    case MessageType.challenge:
      return PostKind.game;
    case MessageType.system:
      return null;
  }
}

/// [postKindOfMessageType] over a batch, with the types no member posts
/// dropped.
Set<PostKind> postKindsOf(Iterable<MessageType> types) => {
      for (final t in types) ?postKindOfMessageType(t),
    };

/// Which preset governs [room]. See the class doc for the resolution order.
///
/// Prefer `ChatRepository.capabilitiesFor(room).posting`, which is this folded
/// into the rest of what the room affords.
RoomPostingPolicy roomPostingPolicyOf(ChatRoom room) {
  final stored = room.postingPolicy;
  if (stored != null && stored.isNotEmpty) {
    return RoomPostingPolicy.presets[stored] ?? RoomPostingPolicy.readOnly;
  }
  return room.isSystemRoom ? RoomPostingPolicy.readOnly : RoomPostingPolicy.open;
}
