import 'package:flutter/foundation.dart';

import 'chat_room.dart';
import 'chat_user.dart';

/// What a room IS, for the purpose of deciding what chrome it gets.
///
/// Not the same axis as [RoomType] (regular vs. Chamber of Secrets), which is
/// about how long messages live. Two rooms can share a [RoomType] and want
/// completely different headers.
enum RoomKind {
  /// An ordinary many-person room, public or private.
  group,

  /// A one-to-one conversation between two people.
  dm,

  /// The single-member `dm:self:<userId>` notes-to-self room.
  savedMessages,

  /// A fixture of the app rather than a conversation — the maintainer's
  /// `MonkeyHub Logs` feed today; support, announcements or any other bot room
  /// later. Which one is named by [ChatRoom.systemRole].
  system,
}

/// What a room affords, resolved once from its [RoomKind] instead of re-derived
/// at every widget that draws a button.
///
/// ── Why this type exists ───────────────────────────────────────────────────
///
/// Saved Messages used to be handled by scattering `if (!room.isSavedMessages)`
/// through the header, the room info screen, the transcript intro and the
/// forward sheet — nine sites, each of which had independently worked out that
/// a chat with only yourself in it has nobody to call and nothing to describe.
/// That is fine for one special room and completely unworkable for the second,
/// because the second one is not special in the SAME ways: `MonkeyHub Logs` has
/// a member list that is technically real (you and the bot) and a peer profile
/// that technically loads, and both are still dead ends.
///
/// So the question each site asks changed from "which room is this?" to "may I
/// draw this?". Adding a kind of room is now one row in the table below rather
/// than a hunt through the widget tree for the checks somebody forgot.
///
/// ── Adding a system room ───────────────────────────────────────────────────
///
/// Stamp `rooms.system` with a new slug server-side (see
/// `backend/convex/systemAccount.ts`), and — only if it wants something other
/// than the locked-down default — add an entry to [_systemRoomOverrides]. A
/// slug this client has never heard of gets [system], which affords nothing;
/// that is what makes shipping the backend first safe.
@immutable
class RoomCapabilities {
  const RoomCapabilities({
    required this.canCall,
    required this.canLeave,
    required this.canDelete,
    required this.hasDescription,
    required this.hasMembers,
    required this.canEditSettings,
    required this.canOpenPeerProfile,
    required this.canReceiveForwards,
    required this.canMute,
  });

  /// Whether the header offers to start a call — the 1:1 button in a DM, the
  /// group-call button everywhere else.
  final bool canCall;

  /// Whether "Leave room" is offered. False wherever leaving is incoherent
  /// rather than merely unavailable: in a DM you would stop being a member
  /// while the room lived on, stranding you.
  final bool canLeave;

  /// Whether this KIND of room can be disposed of at all — "End conversation"
  /// for a DM, "Delete room" for a group. Deliberately not the same question as
  /// "may THIS viewer delete it": a group room is deletable by its owner only,
  /// and that check stays with the caller who knows who the viewer is.
  final bool canDelete;

  /// Whether the room has a description worth editing or showing. False when
  /// there is nobody to describe it to.
  final bool hasDescription;

  /// Whether a member list says anything. "Members (1): you" is not
  /// information, and neither is "Members (2): you and a bot".
  final bool hasMembers;

  /// Whether name, visibility, password and avatar are the viewer's to change.
  /// True for group rooms only — a DM is just the two people, and a system
  /// room's name is load-bearing server-side.
  final bool canEditSettings;

  /// Whether tapping the header travels to the other party's profile. False for
  /// a bot, whose profile offers a friend request it will refuse and a call it
  /// cannot take.
  final bool canOpenPeerProfile;

  /// Whether the room appears in the forward-target sheet. Saved Messages is
  /// the prime target; a write-only bot feed is not a place to put things.
  final bool canReceiveForwards;

  /// Whether this room can be silenced — notifications, unread counts, or
  /// both. See `lib/models/room_mute.dart`.
  ///
  /// The one flag in this table whose safe default runs the OTHER way, and the
  /// reason is worth stating because it looks like an inconsistency. Every
  /// other affordance here fails safe when it's off: a missing call button is
  /// a button that can't ring nothing, a missing "leave" is a room that can't
  /// be quietly broken. Mute inverts that. Off means the app keeps buzzing
  /// about a room the user has already decided they don't want to hear from,
  /// and there is no way for muting to break a room at all — it patches one
  /// column on the viewer's own membership and touches nothing anyone else can
  /// see. So this defaults ON, including for a system room this build has
  /// never heard of, where the ability to shut a talkative bot up is the first
  /// thing anybody would reach for.
  ///
  /// False for Saved Messages alone, and not as a policy: a mute there is a
  /// control that provably does nothing. Every push and every unread count
  /// already excludes the sender, and in a room whose only member is you,
  /// that's every message. A switch that can't change anything is worse than
  /// no switch, because the user has to find out the hard way.
  final bool canMute;

  /// An ordinary room: everything on. [canDelete] still narrows to the owner at
  /// the call site.
  static const group = RoomCapabilities(
    canCall: true,
    canLeave: true,
    canDelete: true,
    hasDescription: true,
    hasMembers: true,
    canEditSettings: true,
    canOpenPeerProfile: false, // no single peer to open
    canReceiveForwards: true,
    canMute: true,
  );

  /// A two-person conversation. No leaving and no settings — the room is the
  /// pair, so there is nothing to rename and nowhere to leave to. Either side
  /// may end it outright.
  static const dm = RoomCapabilities(
    canCall: true,
    canLeave: false,
    canDelete: true,
    hasDescription: true,
    hasMembers: true,
    canEditSettings: false,
    canOpenPeerProfile: true,
    canReceiveForwards: true,
    canMute: true,
  );

  /// Notes to self. Nobody to call, nothing to describe, no list worth drawing,
  /// and a permanent fixture with nothing to end — but the single most useful
  /// place in the app to forward something to.
  static const savedMessages = RoomCapabilities(
    canCall: false,
    canLeave: false,
    canDelete: false,
    hasDescription: false,
    hasMembers: false,
    canEditSettings: false,
    canOpenPeerProfile: false,
    canReceiveForwards: true,
    canMute: false,
  );

  /// The floor every system room stands on, and what an unrecognised
  /// [ChatRoom.systemRole] resolves to.
  ///
  /// Nothing is afforded, [canMute] excepted. Each affordance a specific bot
  /// room wants back is an explicit opt-in in [_systemRoomOverrides], so the
  /// failure mode of a slug this build predates is a room with too little
  /// chrome — never a call button that rings nothing or a "leave" that quietly
  /// breaks the room. Mute is on because for that one flag "too little chrome"
  /// means a bot you cannot shut up; see its own note.
  static const system = RoomCapabilities(
    canCall: false,
    canLeave: false,
    canDelete: false,
    hasDescription: false,
    hasMembers: false,
    canEditSettings: false,
    canOpenPeerProfile: false,
    canReceiveForwards: false,
    // The exception to "nothing is afforded" — see [canMute].
    canMute: true,
  );

  RoomCapabilities copyWith({
    bool? canCall,
    bool? canLeave,
    bool? canDelete,
    bool? hasDescription,
    bool? hasMembers,
    bool? canEditSettings,
    bool? canOpenPeerProfile,
    bool? canReceiveForwards,
    bool? canMute,
  }) =>
      RoomCapabilities(
        canCall: canCall ?? this.canCall,
        canLeave: canLeave ?? this.canLeave,
        canDelete: canDelete ?? this.canDelete,
        hasDescription: hasDescription ?? this.hasDescription,
        hasMembers: hasMembers ?? this.hasMembers,
        canEditSettings: canEditSettings ?? this.canEditSettings,
        canOpenPeerProfile: canOpenPeerProfile ?? this.canOpenPeerProfile,
        canReceiveForwards: canReceiveForwards ?? this.canReceiveForwards,
        canMute: canMute ?? this.canMute,
      );
}

/// Per-slug departures from [RoomCapabilities.system].
///
/// Empty today, and that is the correct starting state rather than an oversight:
/// `logs` wants exactly the locked-down default. It exists as the seam for the
/// bot rooms that are coming — a support room, say, would want
/// `RoomCapabilities.system.copyWith(canReceiveForwards: true)` so a user can
/// forward the message they are complaining about into it.
///
/// Keys are the `rooms.system` slugs from `backend/convex/systemAccount.ts`.
const Map<String, RoomCapabilities> _systemRoomOverrides = <String, RoomCapabilities>{};

/// Which [RoomKind] [room] is.
///
/// [peer] is the resolved other party of a DM, and is what closes the gap on a
/// room the server has not stamped: a DM with a bot is a system room whether or
/// not `rooms.system` was set on it. Pass it wherever it is already in hand —
/// omitting it is safe, just less complete.
RoomKind roomKindOf(ChatRoom room, {ChatUser? peer}) {
  // Checked before [ChatRoom.isSavedMessages] and [ChatRoom.isDm], both of
  // which a system room can also satisfy: the report room is a real DM, and a
  // future system room might be seeded as a self-room. The stamp wins.
  if (room.isSystemRoom || (peer?.isSystem ?? false)) return RoomKind.system;
  if (room.isSavedMessages) return RoomKind.savedMessages;
  if (room.isDm) return RoomKind.dm;
  return RoomKind.group;
}

/// What [room] affords. See [roomKindOf] for the role of [peer].
///
/// Prefer `ChatRepository.capabilitiesFor`, which resolves [peer] for you.
RoomCapabilities roomCapabilitiesFor(ChatRoom room, {ChatUser? peer}) {
  switch (roomKindOf(room, peer: peer)) {
    case RoomKind.group:
      return RoomCapabilities.group;
    case RoomKind.dm:
      return RoomCapabilities.dm;
    case RoomKind.savedMessages:
      return RoomCapabilities.savedMessages;
    case RoomKind.system:
      // `??` and not `[]!`: an unknown slug is the expected case for a client
      // older than the backend, not a programming error.
      return _systemRoomOverrides[room.systemRole] ?? RoomCapabilities.system;
  }
}
