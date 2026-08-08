import 'package:flutter/widgets.dart';
import 'enums.dart';
import 'family.dart';

/// Per-field visibility for a user's profile. Matches backend's
/// `users.visibility` shape. New users default to `nobody` across the board;
/// existing server-stored values are returned verbatim.
enum FieldVisibility { public, friends, nobody }

extension FieldVisibilityWire on FieldVisibility {
  String get wire => name;
  static FieldVisibility parse(String? s) {
    switch (s) {
      case 'public':
        return FieldVisibility.public;
      case 'friends':
        return FieldVisibility.friends;
      case 'nobody':
        return FieldVisibility.nobody;
      default:
        return FieldVisibility.nobody;
    }
  }
}

class ProfileVisibility {
  ProfileVisibility({
    this.avatar = FieldVisibility.nobody,
    this.status = FieldVisibility.nobody,
    this.lastSeen = FieldVisibility.nobody,
    this.seen = FieldVisibility.nobody,
    this.friendRequests = FieldVisibility.nobody, // public | nobody only
    // The three Feed keys are the ONE place in this object where absent does
    // not mean "nobody". A board nobody opted into is a dead board, so sharing
    // today with friends is the default and only the PAST is opt-in. The
    // server owns that decision (`visibilityOf` in backend/convex/feed.ts);
    // these defaults exist so an optimistic local update agrees with it.
    this.feed = FieldVisibility.friends,
    this.points = FieldVisibility.friends,
    this.puzzle = FieldVisibility.friends,
    this.pointsPast = FieldVisibility.nobody,
  });

  FieldVisibility avatar;
  FieldVisibility status;
  FieldVisibility lastSeen;

  /// Controls whether your read receipts ("SEEN" indicator) are surfaced
  /// to people whose messages you've read. Nobody by default — opt-in only.
  FieldVisibility seen;
  FieldVisibility friendRequests;

  /// Whether your moments appear on friends' Feed boards. Friends or nobody —
  /// never public; the board fans out over accepted friendships and nothing
  /// else, so "public" would be a promise the reader could not keep.
  FieldVisibility feed;

  /// Whether your POINTS reach friends' boards. Separate from [feed], which
  /// governs photo highlights — sharing your running joke but not your camera
  /// roll is a perfectly reasonable position and used to be unrepresentable.
  FieldVisibility points;

  /// Whether your daily puzzle score is comparable on friends' scoreboards.
  FieldVisibility puzzle;

  /// Whether friends may look back past today. Off by default — today is
  /// shared, history is opt-in, and that split is the whole reason this
  /// setting exists.
  FieldVisibility pointsPast;

  factory ProfileVisibility.fromJson(Map<String, dynamic> j) => ProfileVisibility(
        avatar: FieldVisibilityWire.parse(j['avatar'] as String?),
        status: FieldVisibilityWire.parse(j['status'] as String?),
        lastSeen: FieldVisibilityWire.parse(j['lastSeen'] as String?),
        seen: FieldVisibilityWire.parse(j['seen'] as String?),
        friendRequests: FieldVisibilityWire.parse(j['friendRequests'] as String?),
        // `FieldVisibilityWire.parse` fails closed to `nobody`, which is right
        // for every other key here and wrong for these two — so an ABSENT
        // value (a user who has never touched the setting) must read as
        // `friends`, matching the server. A stored "nobody" still wins.
        feed: j['feed'] == null
            ? FieldVisibility.friends
            : FieldVisibilityWire.parse(j['feed'] as String?),
        points: j['points'] == null
            ? FieldVisibility.friends
            : FieldVisibilityWire.parse(j['points'] as String?),
        puzzle: j['puzzle'] == null
            ? FieldVisibility.friends
            : FieldVisibilityWire.parse(j['puzzle'] as String?),
        pointsPast: FieldVisibilityWire.parse(j['pointsPast'] as String?),
      );

  ProfileVisibility copyWith({
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? seen,
    FieldVisibility? friendRequests,
    FieldVisibility? feed,
    FieldVisibility? points,
    FieldVisibility? puzzle,
    FieldVisibility? pointsPast,
  }) =>
      ProfileVisibility(
        avatar: avatar ?? this.avatar,
        status: status ?? this.status,
        lastSeen: lastSeen ?? this.lastSeen,
        seen: seen ?? this.seen,
        friendRequests: friendRequests ?? this.friendRequests,
        feed: feed ?? this.feed,
        points: points ?? this.points,
        puzzle: puzzle ?? this.puzzle,
        pointsPast: pointsPast ?? this.pointsPast,
      );
}

class ChatUser {
  ChatUser({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    this.avatarStorageId,
    this.status,
    this.lastSeen,
    this.friendshipStatus = FriendshipStatus.none,
    this.requestId,
    this.role,
    this.visibility,
    this.isRedacted = false,
    this.acceptsFriendRequests = true,
    this.accountType = AccountType.adult,
    this.childPolicy,
    this.hasRecoveryKey,
    this.hasPassword,
    this.usernameChangedAt,
  });

  final String id;
  final String username;
  String name;
  String? email;
  String? avatarStorageId;
  String? status; // "online" | "away" | "offline"
  DateTime? lastSeen;

  FriendshipStatus friendshipStatus;
  String? requestId; // friendship row id (for accept/reject ops)
  String? role; // "owner" | "member" (room context)

  /// Present only on a self-profile fetch — null when viewing other users.
  /// Other viewers seeing someone's settings would itself be a privacy leak.
  ProfileVisibility? visibility;

  /// True when the backend redacted at least one field for this viewer.
  /// Drives the "limited view" indicator on profile.
  bool isRedacted;

  /// True when the target accepts friend requests. False means the SEND
  /// REQUEST button should be disabled (or return USER_NOT_FOUND server-side).
  bool acceptsFriendRequests;

  /// Whether this account is supervised. Drives whether Sign Out is offered,
  /// whether the visibility screen is editable, and whether Discover exists.
  AccountType accountType;

  /// Only present on a self-fetch, or when the viewer is this child's
  /// guardian. Null for everyone else — and for every adult.
  ChildPolicy? childPolicy;

  /// Whether this account has a recovery phrase set. The backend never sends
  /// the hash itself — it IS the reset credential.
  ///
  /// Three states, and the null one is load-bearing:
  ///   true  — a phrase is set.
  ///   false — none is set; prompt for one.
  ///   null  — UNKNOWN: not a self-fetch, a child account, or a backend that
  ///           predates the field. Must be treated as "do not prompt", so a
  ///           client shipped ahead of the backend deploy never nags.
  bool? hasRecoveryKey;

  /// Whether this account can be asked for a password at all — false for one
  /// created through Apple or Google that has never set one.
  ///
  /// Three states, same shape as [hasRecoveryKey] and load-bearing for the same
  /// reason: null means "not a self-fetch, or a backend that predates the
  /// field", and the rename sheet treats it as "assume a password", which is
  /// the safe way to be wrong — the worst case is a password prompt the user
  /// cannot satisfy, rather than a rename attempt with no proof at all.
  bool? hasPassword;

  /// When the handle was last changed, or null for an account still on the one
  /// it signed up with. Self-only.
  ///
  /// Read solely to grey out the rename row during the cooldown, so the refusal
  /// arrives before the user has thought of a name rather than after they have
  /// typed it. The backend enforces the window regardless.
  DateTime? usernameChangedAt;

  bool get isChild => accountType == AccountType.child;

  String get displayName => name.trim().isNotEmpty ? name : username;
  String get displayInitial {
    final n = displayName.trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  factory ChatUser.fromJson(Map<String, dynamic> j) {
    final ls = j['lastSeen'];
    final visRaw = j['visibility'];
    return ChatUser(
      id: (j['_id'] ?? j['id']).toString(),
      username: (j['username'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      email: j['email'] as String?,
      avatarStorageId: j['avatarStorageId'] as String?,
      status: j['status'] as String?,
      lastSeen: ls is num ? DateTime.fromMillisecondsSinceEpoch(ls.toInt()) : null,
      friendshipStatus: FriendshipStatusWire.parse(j['friendshipStatus'] as String?),
      requestId: j['requestId'] as String?,
      role: j['role'] as String?,
      visibility: visRaw is Map
          ? ProfileVisibility.fromJson(visRaw.cast<String, dynamic>())
          : null,
      isRedacted: (j['isRedacted'] as bool?) ?? false,
      acceptsFriendRequests: (j['acceptsFriendRequests'] as bool?) ?? true,
      accountType: AccountTypeWire.parse(j['accountType'] as String?),
      childPolicy: j['childPolicy'] is Map
          ? ChildPolicy.fromJson(
              (j['childPolicy'] as Map).cast<String, dynamic>())
          : null,
      // Deliberately NOT defaulted. An absent key means "unknown", which is
      // not the same as "no phrase set" — see the field's doc comment.
      hasRecoveryKey: j['hasRecoveryKey'] as bool?,
      // Same three-state reading as above.
      hasPassword: j['hasPassword'] as bool?,
      usernameChangedAt: switch (j['usernameChangedAt']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        _ => null,
      },
    );
  }

  ChatUser copyWith({
    String? name,
    String? email,
    String? avatarStorageId,
    String? status,
    FriendshipStatus? friendshipStatus,
    String? requestId,
    String? role,
    ProfileVisibility? visibility,
    bool? isRedacted,
    bool? acceptsFriendRequests,
    AccountType? accountType,
    ChildPolicy? childPolicy,
    bool? hasRecoveryKey,
  }) => ChatUser(
        id: id,
        username: username,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarStorageId: avatarStorageId ?? this.avatarStorageId,
        status: status ?? this.status,
        lastSeen: lastSeen,
        friendshipStatus: friendshipStatus ?? this.friendshipStatus,
        requestId: requestId ?? this.requestId,
        role: role ?? this.role,
        visibility: visibility ?? this.visibility,
        isRedacted: isRedacted ?? this.isRedacted,
        acceptsFriendRequests: acceptsFriendRequests ?? this.acceptsFriendRequests,
        accountType: accountType ?? this.accountType,
        childPolicy: childPolicy ?? this.childPolicy,
        hasRecoveryKey: hasRecoveryKey ?? this.hasRecoveryKey,
        // Carried through even though nothing overrides them. `copyWith` drops
        // whatever it does not name, and ProfileScreen calls it on every fresh
        // fetch to graft friendship state on — so omitting these would erase
        // the rename row's gate and cooldown the moment the profile reloaded.
        hasPassword: hasPassword,
        usernameChangedAt: usernameChangedAt,
      );
}
