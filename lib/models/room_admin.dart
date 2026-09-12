import 'chat_user.dart';

/// Group-chat administration: roles, the join link, and the two kinds of
/// invite that can end in a membership.
///
/// The backend counterparts are `roomAdmin.ts`, `roomInvites.ts` and
/// `roomInvitations.ts`. Everything here is a read model — nothing in this
/// file decides anything. [RoomPermissions] in particular is only ever the
/// answer to "which controls do I draw"; every mutation re-checks server-side,
/// because a client that could be trusted with this would not need it sent.

/// A member's rank in one room.
///
/// Parsed leniently: a role string this build has never heard of resolves to
/// [member] rather than throwing, so a server that grows a fourth tier
/// degrades an old client to "can't do the new thing" instead of crashing it
/// on the member list.
enum RoomRole { owner, admin, member }

extension RoomRoleWire on RoomRole {
  String get wire => name;

  /// True for the ranks that can run the room. The owner is an admin too —
  /// forgetting that is the bug that hides a group's controls from the one
  /// person who definitely has them.
  bool get isAdmin => this == RoomRole.owner || this == RoomRole.admin;

  static RoomRole parse(String? s) {
    switch (s) {
      case 'owner':
        return RoomRole.owner;
      case 'admin':
        return RoomRole.admin;
      default:
        return RoomRole.member;
    }
  }
}

/// What redeeming a room's invite link does — `rooms.linkJoinPolicy`.
enum RoomJoinPolicy {
  /// Holding the link is the whole test; tapping it joins.
  open,

  /// Tapping it files a request an admin answers.
  approval,
}

extension RoomJoinPolicyWire on RoomJoinPolicy {
  String get wire => this == RoomJoinPolicy.approval ? 'approval' : 'open';

  static RoomJoinPolicy parse(String? s) =>
      s == 'approval' ? RoomJoinPolicy.approval : RoomJoinPolicy.open;
}

/// The caller's own standing in one room, from `roomAdmin:myPermissions`.
///
/// Null from the server means "you are not in this room", which the info
/// screen can reach for a beat after being removed. [RoomPermissions.none] is
/// the local stand-in for that and for the not-yet-loaded first frame: every
/// flag false, so a slow query draws a plain member's view and then fills in,
/// rather than flashing admin controls at someone who does not have them.
class RoomPermissions {
  const RoomPermissions({
    required this.role,
    required this.isGroup,
    required this.canEditRoom,
    required this.canRemoveMembers,
    required this.canAssignAdmins,
    required this.canManageLink,
    required this.canReviewJoinRequests,
    required this.canInvite,
    required this.membersCanInvite,
    required this.linkJoinPolicy,
  });

  static const none = RoomPermissions(
    role: RoomRole.member,
    isGroup: false,
    canEditRoom: false,
    canRemoveMembers: false,
    canAssignAdmins: false,
    canManageLink: false,
    canReviewJoinRequests: false,
    canInvite: false,
    membersCanInvite: true,
    linkJoinPolicy: RoomJoinPolicy.open,
  );

  final RoomRole role;
  final bool isGroup;
  final bool canEditRoom;
  final bool canRemoveMembers;
  final bool canAssignAdmins;
  final bool canManageLink;
  final bool canReviewJoinRequests;

  /// May send a direct invite. True for admins always, and for a plain member
  /// while [membersCanInvite] is on.
  final bool canInvite;

  /// The room's switch, not the caller's own power — shown to admins as the
  /// state of a toggle, and to members as the reason an invite button is gone.
  final bool membersCanInvite;

  final RoomJoinPolicy linkJoinPolicy;

  bool get isOwner => role == RoomRole.owner;
  bool get isAdmin => role.isAdmin;

  factory RoomPermissions.fromJson(Map<String, dynamic> j) => RoomPermissions(
        role: RoomRoleWire.parse(j['role'] as String?),
        isGroup: j['isGroup'] == true,
        canEditRoom: j['canEditRoom'] == true,
        canRemoveMembers: j['canRemoveMembers'] == true,
        canAssignAdmins: j['canAssignAdmins'] == true,
        canManageLink: j['canManageLink'] == true,
        canReviewJoinRequests: j['canReviewJoinRequests'] == true,
        canInvite: j['canInvite'] == true,
        membersCanInvite: j['membersCanInvite'] != false,
        linkJoinPolicy: RoomJoinPolicyWire.parse(j['linkJoinPolicy'] as String?),
      );
}

/// Why a link cannot be used. Mirrors the error strings `roomInvites.ts`
/// returns, kept as an enum so the UI switch is exhaustive and a new server
/// reason cannot silently fall through to a blank screen.
enum InviteProblem {
  none,
  notFound,
  revoked,
  expired,
  exhausted,

  /// Not a failure — you are already in this room.
  alreadyMember,

  /// Not a failure — you have already asked and an admin has not answered.
  requestPending,
}

extension InviteProblemWire on InviteProblem {
  static InviteProblem parse(String? s) {
    switch (s) {
      case null:
      case 'ok':
        return InviteProblem.none;
      case 'INVITE_REVOKED':
        return InviteProblem.revoked;
      case 'INVITE_EXPIRED':
        return InviteProblem.expired;
      case 'INVITE_EXHAUSTED':
        return InviteProblem.exhausted;
      case 'ALREADY_MEMBER':
        return InviteProblem.alreadyMember;
      case 'JOIN_REQUEST_PENDING':
        return InviteProblem.requestPending;
      default:
        return InviteProblem.notFound;
    }
  }
}

/// The room's one live join link, as an admin sees it.
class RoomInviteLink {
  const RoomInviteLink({
    required this.inviteId,
    required this.code,
    required this.formattedCode,
    required this.createdAt,
    required this.useCount,
    this.expiresAt,
    this.maxUses,
    this.problem = InviteProblem.none,
  });

  final String inviteId;

  /// The raw token — what goes in the URL, and what `normalizeCode`
  /// server-side turns typed input back into.
  final String code;

  /// The same token grouped for reading aloud: `K7M2-XQ94-RB`. Display only;
  /// never send this anywhere, send [code].
  final String formattedCode;

  final DateTime createdAt;
  final int useCount;
  final DateTime? expiresAt;
  final int? maxUses;

  /// Why this link is already dead, if it is. An admin can hold a link that
  /// has expired or run out of uses — the row survives so the sheet can say
  /// which, instead of showing a code that silently fails for everyone.
  final InviteProblem problem;

  bool get isUsable => problem == InviteProblem.none;

  int? get usesLeft => maxUses == null ? null : (maxUses! - useCount).clamp(0, maxUses!);

  factory RoomInviteLink.fromJson(Map<String, dynamic> j) => RoomInviteLink(
        inviteId: j['inviteId'].toString(),
        code: j['code'] as String,
        formattedCode: (j['formattedCode'] as String?) ?? j['code'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
        useCount: ((j['useCount'] as num?) ?? 0).toInt(),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['expiresAt'] as num).toInt()),
        maxUses: (j['maxUses'] as num?)?.toInt(),
        problem: InviteProblemWire.parse(j['invalidReason'] as String?),
      );
}

/// Where a supervised viewer stands with the room behind a code. Decided by
/// the server, because the child-facing approvals query lists pending rows
/// only and so cannot tell [granted] from [needed].
enum ChildGate {
  /// Not a supervised viewer at all — the ordinary join rules apply.
  none,

  /// A grown-up has to say yes before this one can be joined.
  needed,

  /// Asked, and nobody has answered yet.
  asked,

  /// Cleared: a guardian said yes, or the room is family-only. Joins normally.
  granted,
}

extension ChildGateWire on ChildGate {
  static ChildGate parse(String? s) => switch (s) {
        'needed' => ChildGate.needed,
        'asked' => ChildGate.asked,
        'granted' => ChildGate.granted,
        _ => ChildGate.none,
      };
}

/// The room behind a code, for the confirmation screen — everything ABOUT the
/// room and nothing from inside it.
class InvitePreview {
  const InvitePreview({
    required this.problem,
    this.roomId,
    this.name,
    this.description,
    this.memberCount = 0,
    this.isPrivate = false,
    this.avatarStorageId,
    this.joinPolicy = RoomJoinPolicy.open,
    this.childGate = ChildGate.none,
  });

  final InviteProblem problem;
  final String? roomId;
  final String? name;
  final String? description;
  final int memberCount;
  final bool isPrivate;

  /// A Convex storage id, not a URL — resolved through `RemoteImage`, which
  /// caches the bytes on disk and decodes to the painted size. `files:getFileUrl`
  /// takes no identity, so this renders for a signed-out visitor too.
  final String? avatarStorageId;

  /// Lets the button read "Request to join" before the tap rather than after.
  final RoomJoinPolicy joinPolicy;

  /// Lets it read "ask a grown-up" for a child who has not been cleared, so
  /// the tap files a request instead of bouncing off the server's refusal.
  final ChildGate childGate;

  bool get isJoinable => problem == InviteProblem.none && roomId != null;

  factory InvitePreview.fromJson(Map<String, dynamic> j) {
    final room = (j['room'] as Map?)?.cast<String, dynamic>();
    return InvitePreview(
      problem: InviteProblemWire.parse(j['status'] as String?),
      roomId: room?['roomId']?.toString(),
      name: room?['name'] as String?,
      description: room?['description'] as String?,
      memberCount: ((room?['memberCount'] as num?) ?? 0).toInt(),
      isPrivate: room?['isPrivate'] == true,
      avatarStorageId: room?['avatarStorageId'] as String?,
      joinPolicy: RoomJoinPolicyWire.parse(room?['joinPolicy'] as String?),
      childGate: ChildGateWire.parse(j['childGate'] as String?),
    );
  }
}

/// What redeeming a code actually did.
enum RedeemOutcome {
  /// Straight in — the room's policy is [RoomJoinPolicy.open].
  joined,

  /// Filed for an admin to answer.
  requested,

  /// Already a member; the tap was a no-op and the room is open below.
  alreadyMember,
}

/// An invite somebody sent YOU: "come into this group".
class RoomInvitation {
  const RoomInvitation({
    required this.invitationId,
    required this.createdAt,
    required this.roomId,
    required this.roomName,
    required this.memberCount,
    required this.inviter,
    this.description,
    this.avatarStorageId,
    this.isPrivate = false,
  });

  final String invitationId;
  final DateTime createdAt;
  final String roomId;
  final String roomName;
  final String? description;
  final int memberCount;
  final bool isPrivate;
  final String? avatarStorageId;
  final ChatUser inviter;

  factory RoomInvitation.fromJson(Map<String, dynamic> j) {
    final room = (j['room'] as Map).cast<String, dynamic>();
    return RoomInvitation(
      invitationId: j['invitationId'].toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      roomId: room['roomId'].toString(),
      roomName: room['name'] as String,
      description: room['description'] as String?,
      memberCount: ((room['memberCount'] as num?) ?? 0).toInt(),
      isPrivate: room['isPrivate'] == true,
      avatarStorageId: room['avatarStorageId'] as String?,
      inviter: ChatUser.fromJson((j['inviter'] as Map).cast<String, dynamic>()),
    );
  }
}

/// An invite the ROOM has out and nobody has answered yet — shown under the
/// member list so the roster reads as the truth about who is coming.
class PendingRoomInvite {
  const PendingRoomInvite({
    required this.invitationId,
    required this.createdAt,
    required this.inviterId,
    required this.invitee,
    required this.canCancel,
    required this.awaitingGuardian,
  });

  final String invitationId;
  final DateTime createdAt;
  final String inviterId;
  final ChatUser invitee;

  /// True for the person who sent it and for any admin.
  final bool canCancel;

  /// Still sitting at a guardian hop, so the invitee does not know it exists.
  /// Worth saying out loud — otherwise "invited, no answer for two days" reads
  /// as a snub rather than as a parent who hasn't looked yet.
  final bool awaitingGuardian;

  factory PendingRoomInvite.fromJson(Map<String, dynamic> j) => PendingRoomInvite(
        invitationId: j['invitationId'].toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
        inviterId: j['inviterId'].toString(),
        invitee: ChatUser.fromJson((j['invitee'] as Map).cast<String, dynamic>()),
        canCancel: j['canCancel'] == true,
        awaitingGuardian: j['awaitingGuardian'] == true,
      );
}

/// Somebody with the link asking to come in, waiting on an admin.
class RoomJoinRequest {
  const RoomJoinRequest({
    required this.requestId,
    required this.user,
    required this.createdAt,
  });

  final String requestId;

  /// The full public view, through the admin's lens — the same shape
  /// `rooms.getMembers` returns, so the row renders with `UserAvatar` and
  /// obeys the requester's own visibility settings.
  final ChatUser user;

  final DateTime createdAt;

  factory RoomJoinRequest.fromJson(Map<String, dynamic> j) => RoomJoinRequest(
        requestId: j['requestId'].toString(),
        user: ChatUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      );
}
