import 'package:flutter/foundation.dart';

import 'chat_room.dart';
import 'chat_user.dart';
import 'room_posting_policy.dart';

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
/// because the second one is not special in the SAME ways: `MonkeyHub Logs` had
/// a member list that was technically real (you and the bot) and a peer profile
/// that technically loaded, and both were still dead ends.
///
/// So the question each site asks changed from "which room is this?" to "may I
/// draw this?". Adding a kind of room is now one row in the table below rather
/// than a hunt through the widget tree for the checks somebody forgot.
///
/// The logs room since grew a third member and got its roster back
/// ([_systemRoomOverrides]), which is the argument for this shape landing
/// rather than against it: one row changed, and the header, the intro card and
/// the info screen all followed. Under the old scheme that was three separate
/// `if (!isLogsRoom)` to find.
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
    required this.hasPeerHandle,
    required this.canEditSettings,
    required this.canOpenPeerProfile,
    required this.canReceiveForwards,
    required this.canSaveMessages,
    required this.canMute,
    this.posting = RoomPostingPolicy.open,
    this.canReport = false,
    this.canModerate = false,
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
  ///
  /// Off for a DM, and that is not the same reason Saved Messages is off. A DM
  /// has two people who could both read a description, so the field WORKS — it
  /// is just answering a question nobody asks. A description is a room's
  /// standing notice to people who arrive later and were not part of agreeing
  /// it; a DM has no later, and no arrivals. Whatever one party wrote there is
  /// a message they could have sent, sitting in a slot the other party never
  /// looks at, above a transcript where it would actually have been read.
  final bool hasDescription;

  /// Whether a member list says anything. "Members (1): you" is not
  /// information, and neither is "Members (2): you and a bot" — nor, for the
  /// same reason, "Members (2): you and the person whose name is already the
  /// title of this screen".
  final bool hasMembers;

  /// Whether the chat header names the other party by `@handle`.
  ///
  /// Split out of [hasMembers] rather than folded into it, because the header's
  /// subtitle line and a roster are the same widget slot answering two
  /// different questions. A group says "PRIVATE · 12 members" there — a count,
  /// which is what [hasMembers] is about. A DM says `@handle`, which is not a
  /// count of anything: it is the one fact the display name above it leaves
  /// out, and it is how you tell two people called "Sam" apart.
  ///
  /// So a DM turning [hasMembers] off must not take the handle with it, and a
  /// bot room turning the handle off must not be read as having members.
  final bool hasPeerHandle;

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

  /// Whether a message here can be SAVED — the per-reader bookmark behind the
  /// bubble menu's SAVE row and room info's "Saved messages" section.
  ///
  /// Note this is the opposite polarity to [canReceiveForwards] on exactly the
  /// room where the two are easiest to confuse. Saved Messages is the best place
  /// in the app to forward something TO, and the worst place to bookmark
  /// anything IN: the room already is the pile of things you kept, so marking
  /// one of them "kept" sorts nothing from nothing. That is a fact about the
  /// KIND of room, which is why it belongs here rather than as an
  /// `if (room.isSavedMessages)` at the two menu call sites — which is the exact
  /// nine-site sprawl this table was built to end.
  final bool canSaveMessages;
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

  /// What members may post here — the room's posting policy, see
  /// `room_posting_policy.dart`.
  ///
  /// A second axis rather than more rows in the kind table above: the kind
  /// says what CHROME a room gets, the policy says what CONTENT goes in, and a
  /// group room can be read-only while a system room might take text. The
  /// two meet in [roomCapabilitiesFor], which ANDs the policy's [canCall] and
  /// [canReceiveForwards] into these, so the header and the forward and share
  /// sheets honour a policy without reading it. The composer, the attachment
  /// menu and the message menu read this directly.
  ///
  /// Defaults to [RoomPostingPolicy.open] in every constant below; the real
  /// value is attached by [roomCapabilitiesFor] from the room row.
  final RoomPostingPolicy posting;

  /// Room info offers "Report": the room itself for a group, the other person
  /// for a DM. Nobody reports Saved Messages, and a system room is the app's
  /// own fixture, with no one in it to report.
  final bool canReport;

  /// A report card here can be acted on: remove the message, ban or unban the
  /// person, dismiss. Only the moderation room. Presentation only: the server
  /// checks the caller against its staff list on every action regardless,
  /// because this is decided by a slug any client can read.
  final bool canModerate;

  /// An ordinary room: everything on. [canDelete] still narrows to the owner at
  /// the call site.
  static const group = RoomCapabilities(
    canCall: true,
    canLeave: true,
    canDelete: true,
    hasDescription: true,
    hasMembers: true,
    hasPeerHandle: false, // no single peer to name
    canEditSettings: true,
    canOpenPeerProfile: false, // no single peer to open
    canReceiveForwards: true,
    canSaveMessages: true,
    canMute: true,
    canReport: true,
  );

  /// A two-person conversation. No leaving and no settings — the room is the
  /// pair, so there is nothing to rename and nowhere to leave to. Either side
  /// may end it outright.
  ///
  /// No description and no roster either, for the reasons those two fields
  /// give: both are chrome a group needs and a pair cannot use. What survives
  /// is [hasPeerHandle] — the header still says who you are talking to.
  static const dm = RoomCapabilities(
    canCall: true,
    canLeave: false,
    canDelete: true,
    hasDescription: false,
    hasMembers: false,
    hasPeerHandle: true,
    canEditSettings: false,
    canOpenPeerProfile: true,
    canReceiveForwards: true,
    canSaveMessages: true,
    canMute: true,
    canReport: true,
  );

  /// Notes to self. Nobody to call, nothing to describe, no list worth drawing,
  /// and a permanent fixture with nothing to end — but the single most useful
  /// place in the app to forward something to.
  ///
  /// [canSaveMessages] is false for the reason that field spells out: this room
  /// is already the pile of things you kept, so a bookmark inside it marks
  /// nothing apart from anything.
  static const savedMessages = RoomCapabilities(
    canCall: false,
    canLeave: false,
    canDelete: false,
    hasDescription: false,
    hasMembers: false,
    hasPeerHandle: false,
    canEditSettings: false,
    canOpenPeerProfile: false,
    canReceiveForwards: true,
    canSaveMessages: false,
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
    hasPeerHandle: false,
    canEditSettings: false,
    canOpenPeerProfile: false,
    canReceiveForwards: false,
    canSaveMessages: false,
    // The exception to "nothing is afforded" — see [canMute].
    canMute: true,
    // And nothing may be posted: the floor of the posting policy as well,
    // matching `roomPolicy.postingPresetOf` server-side, where an unstamped
    // system room resolves to read-only.
    posting: RoomPostingPolicy.readOnly,
  );

  RoomCapabilities copyWith({
    bool? canCall,
    bool? canLeave,
    bool? canDelete,
    bool? hasDescription,
    bool? hasMembers,
    bool? hasPeerHandle,
    bool? canEditSettings,
    bool? canOpenPeerProfile,
    bool? canReceiveForwards,
    bool? canSaveMessages,
    bool? canMute,
    RoomPostingPolicy? posting,
    bool? canReport,
    bool? canModerate,
  }) =>
      RoomCapabilities(
        canCall: canCall ?? this.canCall,
        canLeave: canLeave ?? this.canLeave,
        canDelete: canDelete ?? this.canDelete,
        hasDescription: hasDescription ?? this.hasDescription,
        hasMembers: hasMembers ?? this.hasMembers,
        hasPeerHandle: hasPeerHandle ?? this.hasPeerHandle,
        canEditSettings: canEditSettings ?? this.canEditSettings,
        canOpenPeerProfile: canOpenPeerProfile ?? this.canOpenPeerProfile,
        canReceiveForwards: canReceiveForwards ?? this.canReceiveForwards,
        canSaveMessages: canSaveMessages ?? this.canSaveMessages,
        canMute: canMute ?? this.canMute,
        posting: posting ?? this.posting,
        canReport: canReport ?? this.canReport,
        canModerate: canModerate ?? this.canModerate,
      );

  /// These capabilities under [policy]: [posting] set, and the two answers the
  /// policy shares with the kind table narrowed by it. Only ever narrows — a
  /// permissive policy cannot give a call button to a room whose kind has
  /// nobody to call.
  RoomCapabilities underPolicy(RoomPostingPolicy policy) => copyWith(
        canCall: canCall && policy.canCall,
        canReceiveForwards: canReceiveForwards && policy.canReceiveForwards,
        posting: policy,
      );
}

/// Per-slug departures from [RoomCapabilities.system].
///
/// The seam for bot rooms that want an affordance back — a support room, say,
/// would want `canReceiveForwards: true` so a user can forward the message they
/// are complaining about into it.
///
/// Keys are the `rooms.system` slugs from `backend/convex/systemAccount.ts`.
///
/// Values are spelled as `copyWith` off the locked-down default rather than as
/// literals, so an affordance a bot room does NOT ask for keeps tracking that
/// default when it changes — the whole point of the fallback being a floor.
final Map<String, RoomCapabilities> _systemRoomOverrides = <String, RoomCapabilities>{
  // `MonkeyHub Logs` stopped being a DM between the bot and one maintainer and
  // became a staff room the bot posts into, so its roster went from "you and a
  // bot" — the example [RoomCapabilities.hasMembers] cites as saying nothing —
  // to the answer to a question that now has one: which of us can see the
  // reports. Everything else stays locked down; a room the app writes to is
  // still not a room anybody renames, leaves or deletes.
  'logs': RoomCapabilities.system.copyWith(hasMembers: true),
  // The moderation inbox: a read-only feed Monkey Reporter posts report cards
  // into, exactly like the log room, plus the one thing the log room does not
  // need: acting on a card. See `backend/convex/moderation.ts`.
  'moderation': RoomCapabilities.system.copyWith(
    hasMembers: true,
    canModerate: true,
  ),
};

/// Which [RoomKind] [room] is.
///
/// [peer] is the resolved other party of a DM, and is what closes the gap on a
/// room the server has not stamped: a DM with a bot is a system room whether or
/// not `rooms.system` was set on it. Pass it wherever it is already in hand —
/// omitting it is safe, just less complete.
RoomKind roomKindOf(ChatRoom room, {ChatUser? peer}) {
  // Checked before [ChatRoom.isSavedMessages] and [ChatRoom.isDm], both of
  // which a system room can also satisfy: the report room was a real DM until
  // it became a staff group, installs that predate the rename still hold the
  // `dm:` name, and a future system room might be seeded as a self-room. The
  // stamp wins.
  if (room.isSystemRoom || (peer?.isSystem ?? false)) return RoomKind.system;
  if (room.isSavedMessages) return RoomKind.savedMessages;
  if (room.isDm) return RoomKind.dm;
  return RoomKind.group;
}

/// What [room] affords. See [roomKindOf] for the role of [peer].
///
/// Prefer `ChatRepository.capabilitiesFor`, which resolves [peer] for you.
RoomCapabilities roomCapabilitiesFor(ChatRoom room, {ChatUser? peer}) {
  final RoomCapabilities base;
  switch (roomKindOf(room, peer: peer)) {
    case RoomKind.group:
      base = RoomCapabilities.group;
    case RoomKind.dm:
      base = RoomCapabilities.dm;
    case RoomKind.savedMessages:
      base = RoomCapabilities.savedMessages;
    case RoomKind.system:
      // `??` and not `[]!`: an unknown slug is the expected case for a client
      // older than the backend, not a programming error.
      base = _systemRoomOverrides[room.systemRole] ?? RoomCapabilities.system;
  }
  // A DM with a bot that the server never stamped is a system room by its
  // peer, and gets the system default policy with it: read-only.
  final policy = room.postingPolicy == null &&
          !room.isSystemRoom &&
          (peer?.isSystem ?? false)
      ? RoomPostingPolicy.readOnly
      : roomPostingPolicyOf(room);
  // Skipped when the row already carries this policy — the open policy on
  // every ordinary room, read-only on a system room — so those keep returning
  // the shared constant rather than a fresh copy per call.
  return identical(policy, base.posting) ? base : base.underPolicy(policy);
}
