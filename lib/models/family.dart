import 'chat_user.dart';

// ── Guard error codes ───────────────────────────────────────────────────────
// Thrown by `backend/convex/childGuard.ts` and surfaced verbatim through the
// Convex client. Kept beside the models rather than beside the sheet that
// renders them, so non-UI layers (the repository) can recognise them without
// importing a widget.

/// The action needs a guardian's yes first.
const kChildApprovalRequired = 'CHILD_APPROVAL_REQUIRED';

/// The action is switched off for this child — asking won't help.
const kChildNotAllowed = 'CHILD_NOT_ALLOWED';

/// This account can only sign in by redeeming a pairing code.
const kChildMustPair = 'CHILD_MUST_PAIR';

/// True when [error] is a child guard rejection rather than a real failure.
/// These must not be retried: they'll fail identically until a guardian acts.
bool isChildGateError(Object error) {
  final s = error.toString();
  return s.contains(kChildApprovalRequired) || s.contains(kChildNotAllowed);
}

/// True specifically for "switched off for you", as opposed to "needs
/// approval" — a different sentence, because asking won't change it.
bool isChildBlockedOutright(Object error) =>
    error.toString().contains(kChildNotAllowed);

/// Adult or supervised. Mirrors `users.accountType` on the backend, where the
/// field is absent for every account that predates child accounts — so an
/// unknown/missing value must read as [adult].
enum AccountType { adult, child }

extension AccountTypeWire on AccountType {
  String get wire => name;

  static AccountType parse(String? s) =>
      s == 'child' ? AccountType.child : AccountType.adult;
}

/// What a child is allowed to do without asking. Guardian-controlled; the
/// child can never edit it. Defaults here match `DEFAULT_CHILD_POLICY` in
/// `backend/convex/childGuard.ts` — keep the two in step.
class ChildPolicy {
  const ChildPolicy({
    this.publicRoomsEnabled = false,
    this.callsEnabled = true,
    this.mediaEnabled = true,
    this.canRequestContacts = true,
    this.canCreateRooms = false,
  });

  final bool publicRoomsEnabled;
  final bool callsEnabled;
  final bool mediaEnabled;
  final bool canRequestContacts;
  final bool canCreateRooms;

  static const locked = ChildPolicy();

  factory ChildPolicy.fromJson(Map<String, dynamic> j) => ChildPolicy(
        publicRoomsEnabled: (j['publicRoomsEnabled'] as bool?) ?? false,
        callsEnabled: (j['callsEnabled'] as bool?) ?? true,
        mediaEnabled: (j['mediaEnabled'] as bool?) ?? true,
        canRequestContacts: (j['canRequestContacts'] as bool?) ?? true,
        canCreateRooms: (j['canCreateRooms'] as bool?) ?? false,
      );

  ChildPolicy copyWith({
    bool? publicRoomsEnabled,
    bool? callsEnabled,
    bool? mediaEnabled,
    bool? canRequestContacts,
    bool? canCreateRooms,
  }) =>
      ChildPolicy(
        publicRoomsEnabled: publicRoomsEnabled ?? this.publicRoomsEnabled,
        callsEnabled: callsEnabled ?? this.callsEnabled,
        mediaEnabled: mediaEnabled ?? this.mediaEnabled,
        canRequestContacts: canRequestContacts ?? this.canRequestContacts,
        canCreateRooms: canCreateRooms ?? this.canCreateRooms,
      );
}

/// How far a pending contact request has travelled along the guardian relay.
/// `null` on the wire means "never supervised" — an ordinary adult-to-adult
/// request, which behaves exactly as it always has.
enum RequestStage {
  senderGuardian,
  recipientGuardian,
  recipient;

  static RequestStage? parse(String? s) {
    switch (s) {
      case 'awaitingSenderGuardian':
        return RequestStage.senderGuardian;
      case 'awaitingRecipientGuardian':
        return RequestStage.recipientGuardian;
      case 'awaitingRecipient':
        return RequestStage.recipient;
      default:
        return null;
    }
  }

  /// What the *sender* should be told while the request sits here. Kept vague
  /// about the far end on purpose: a sender must never learn that the person
  /// they asked for is a child.
  String get senderLabel {
    switch (this) {
      case RequestStage.senderGuardian:
        return 'waiting for a grown-up';
      case RequestStage.recipientGuardian:
      case RequestStage.recipient:
        return 'waiting for them';
    }
  }
}

/// A child, as their guardian sees them on the dashboard.
class ChildSummary {
  ChildSummary({
    required this.user,
    required this.policy,
    required this.pendingCount,
    this.status,
    this.lastSeen,
  });

  final ChatUser user;
  final ChildPolicy policy;
  final int pendingCount;
  final String? status;
  final DateTime? lastSeen;

  factory ChildSummary.fromJson(Map<String, dynamic> j) {
    final ls = j['lastSeen'];
    final pol = j['childPolicy'];
    return ChildSummary(
      user: ChatUser.fromJson(j),
      policy: pol is Map
          ? ChildPolicy.fromJson(pol.cast<String, dynamic>())
          : ChildPolicy.locked,
      pendingCount: ((j['pendingCount'] ?? 0) as num).toInt(),
      status: j['status'] as String?,
      lastSeen: ls is num
          ? DateTime.fromMillisecondsSinceEpoch(ls.toInt())
          : null,
    );
  }
}

/// One round trip's worth of "who am I, what may I do, who's in my family".
class FamilyContext {
  const FamilyContext({
    required this.accountType,
    required this.childPolicy,
    required this.guardians,
    required this.children,
    required this.pendingCount,
  });

  final AccountType accountType;

  /// Only set when [accountType] is [AccountType.child].
  final ChildPolicy? childPolicy;

  /// My grown-ups (child view).
  final List<ChatUser> guardians;

  /// My kids (parent view).
  final List<ChildSummary> children;

  /// How many things are waiting on me across all my children.
  final int pendingCount;

  bool get isChild => accountType == AccountType.child;

  /// The effective policy — a locked-down default rather than null, so callers
  /// can read flags without null-checking. Adults are unrestricted, so this is
  /// only meaningful when [isChild].
  ChildPolicy get policy => childPolicy ?? ChildPolicy.locked;

  static const empty = FamilyContext(
    accountType: AccountType.adult,
    childPolicy: null,
    guardians: [],
    children: [],
    pendingCount: 0,
  );

  factory FamilyContext.fromJson(Map<String, dynamic> j) {
    final pol = j['childPolicy'];
    return FamilyContext(
      accountType: AccountTypeWire.parse(j['accountType'] as String?),
      childPolicy: pol is Map
          ? ChildPolicy.fromJson(pol.cast<String, dynamic>())
          : null,
      guardians: ((j['guardians'] as List?) ?? const [])
          .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      children: ((j['children'] as List?) ?? const [])
          .map((e) => ChildSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      pendingCount: ((j['pendingCount'] ?? 0) as num).toInt(),
    );
  }
}

/// The three things that can land in a guardian's queue. They read very
/// differently to a parent, which is why they stay distinct rather than
/// collapsing into one "request" type.
enum QueueItemType {
  /// My child asked to add someone.
  contactOutgoing,

  /// Someone asked to add my child. The child does not know this exists.
  contactIncoming,

  /// My child asked to join a room.
  joinRoom;

  static QueueItemType? parse(String? s) {
    switch (s) {
      case 'contactOutgoing':
        return QueueItemType.contactOutgoing;
      case 'contactIncoming':
        return QueueItemType.contactIncoming;
      case 'joinRoom':
        return QueueItemType.joinRoom;
      default:
        return null;
    }
  }
}

/// A room as it appears inside a queue item — deliberately lighter than
/// [ChatRoom], which needs fields the queue doesn't carry.
class RoomBrief {
  RoomBrief({
    required this.id,
    required this.name,
    this.description,
    this.memberCount = 0,
    this.avatarStorageId,
    this.approvalId,
  });

  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final String? avatarStorageId;

  /// Set when this room came from a grants list, so it can be revoked.
  final String? approvalId;

  factory RoomBrief.fromJson(Map<String, dynamic> j) => RoomBrief(
        id: (j['_id'] ?? j['id']).toString(),
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        memberCount: ((j['memberCount'] ?? 0) as num).toInt(),
        avatarStorageId: j['avatarStorageId'] as String?,
        approvalId: j['approvalId']?.toString(),
      );
}

/// One row in the parent's approval queue.
class QueueItem {
  QueueItem({
    required this.type,
    required this.id,
    required this.createdAt,
    required this.child,
    this.other,
    this.room,
    this.note = '',
  });

  final QueueItemType type;

  /// A `friendships` id for the contact types, an `approvalRequests` id for
  /// [QueueItemType.joinRoom] — they go to different mutations.
  final String id;
  final DateTime createdAt;

  /// Which of my children this is about.
  final ChatUser child;

  /// The other person, for the contact types.
  final ChatUser? other;

  /// The room, for [QueueItemType.joinRoom].
  final RoomBrief? room;
  final String note;

  bool get isContact => type != QueueItemType.joinRoom;

  static QueueItem? fromJson(Map<String, dynamic> j) {
    final type = QueueItemType.parse(j['type'] as String?);
    if (type == null) return null; // unknown kind from a newer backend
    final other = j['other'];
    final room = j['room'];
    return QueueItem(
      type: type,
      id: (j['_id']).toString(),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(((j['createdAt'] ?? 0) as num).toInt()),
      child: ChatUser.fromJson((j['child'] as Map).cast<String, dynamic>()),
      other: other is Map
          ? ChatUser.fromJson(other.cast<String, dynamic>())
          : null,
      room: room is Map ? RoomBrief.fromJson(room.cast<String, dynamic>()) : null,
      note: (j['note'] ?? '') as String,
    );
  }
}

/// A child's own "waiting on a grown-up" entry.
class PendingApproval {
  PendingApproval({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.roomId,
    this.roomName,
  });

  final String id;
  final String kind;
  final DateTime createdAt;
  final String? roomId;
  final String? roomName;

  factory PendingApproval.fromJson(Map<String, dynamic> j) => PendingApproval(
        id: (j['_id']).toString(),
        kind: (j['kind'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            ((j['createdAt'] ?? 0) as num).toInt()),
        roomId: j['roomId']?.toString(),
        roomName: j['roomName'] as String?,
      );
}

/// What a guardian has already granted a child, for the dashboard.
class ChildGrants {
  ChildGrants({required this.rooms, required this.contacts});

  final List<RoomBrief> rooms;
  final List<ChatUser> contacts;

  factory ChildGrants.fromJson(Map<String, dynamic> j) => ChildGrants(
        rooms: ((j['rooms'] as List?) ?? const [])
            .map((e) => RoomBrief.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        contacts: ((j['contacts'] as List?) ?? const [])
            .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
