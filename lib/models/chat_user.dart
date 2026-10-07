import 'package:flutter/widgets.dart';
import 'enums.dart';
import 'family.dart';

/// Per-field visibility for a user's profile. Matches backend's
/// `users.visibility` shape. An absent field reads exactly as the server
/// enforces it (`DEFAULT_LEVEL` in backend/convex/visibility.ts): `friends`
/// for the four identity keys, `public` for friend requests. Stored values are
/// returned verbatim.
enum FieldVisibility { public, friends, nobody }

extension FieldVisibilityWire on FieldVisibility {
  String get wire => name;
  /// [absent] is what a missing key means — the server's default for that
  /// field. An unrecognised value still fails closed to `nobody`.
  static FieldVisibility parse(String? s,
      [FieldVisibility absent = FieldVisibility.nobody]) {
    switch (s) {
      case null:
        return absent;
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
    this.avatar = FieldVisibility.friends,
    this.status = FieldVisibility.friends,
    this.lastSeen = FieldVisibility.friends,
    this.seen = FieldVisibility.friends,
    this.friendRequests = FieldVisibility.public, // public | nobody only
    // The Feed keys: a board nobody opted into is a dead board, so sharing
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
  /// to people whose messages you've read. Friends by default.
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
        avatar: FieldVisibilityWire.parse(
            j['avatar'] as String?, FieldVisibility.friends),
        status: FieldVisibilityWire.parse(
            j['status'] as String?, FieldVisibility.friends),
        lastSeen: FieldVisibilityWire.parse(
            j['lastSeen'] as String?, FieldVisibility.friends),
        seen: FieldVisibilityWire.parse(
            j['seen'] as String?, FieldVisibility.friends),
        friendRequests: FieldVisibilityWire.parse(
            j['friendRequests'] as String?, FieldVisibility.public),
        // An ABSENT value (a user who has never touched the setting) reads as
        // the server's default, so the screen shows what is enforced. A
        // stored "nobody" still wins.
        feed: FieldVisibilityWire.parse(
            j['feed'] as String?, FieldVisibility.friends),
        points: FieldVisibilityWire.parse(
            j['points'] as String?, FieldVisibility.friends),
        puzzle: FieldVisibilityWire.parse(
            j['puzzle'] as String?, FieldVisibility.friends),
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
    this.isSystem = false,
    this.joinedAt,
    this.awaitingGuardian = false,
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

  /// When this user joined the room they were fetched for — room context only,
  /// null everywhere else and on a backend that predates the field.
  ///
  /// Never displayed. It exists so per-speaker colours can be settled in JOIN
  /// order (`SpeakerSlots.forMembers`): whoever was here first keeps the colour
  /// they had, and a new member takes a free one instead of taking someone
  /// else's and cascading the whole room. Ordering by id instead — which is
  /// what a null everywhere degrades to — is still deterministic and identical
  /// on every client, it just loses that one guarantee.
  final DateTime? joinedAt;

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

  /// True when this row is the app rather than a person — the account bug
  /// reports are posted by, and whatever bots come after it.
  ///
  /// The backend already refuses every ordinary thing you can do to one
  /// (`calls.ts`, `groupCalls.ts`, `friends.ts` all guard on it), so this exists
  /// so the client can stop OFFERING those things: a call button that is
  /// refused server-side is still a dead end that looks like a live one.
  ///
  /// Defaults false, which is also what an older backend that never sends the
  /// key produces — the safe way to be wrong is treating a bot as a person for
  /// one deploy window, not the reverse.
  final bool isSystem;

  /// True when a pending request between the viewer and this person is parked
  /// at the VIEWER'S OWN guardian — i.e. "a grown-up is still deciding this".
  ///
  /// Only ever the viewer's own hop. A request held at the OTHER end's
  /// guardian is reported as an ordinary pending one, because saying otherwise
  /// would tell the sender that the person they asked for is a child — see
  /// `searchUsersCore` in `backend/convex/users.ts`, which is where this is
  /// computed and where that restriction is argued.
  ///
  /// It exists because the friendship status alone reads the row's existence
  /// and not its stage, so a supervised request rendered as an actionable
  /// APPROVE / SEND REQUEST that the backend could only ever refuse.
  ///
  /// Defaults false, which is also what a backend predating the field sends.
  bool awaitingGuardian;

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
      // Sent only when true — see `publicUserView` in backend/convex/visibility.ts.
      isSystem: (j['isSystem'] as bool?) ?? false,
      // Room-scoped, so absent on every other fetch — see the field's doc.
      joinedAt: switch (j['joinedAt']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        _ => null,
      },
      awaitingGuardian: (j['awaitingGuardian'] as bool?) ?? false,
    );
  }

  /// For [CacheStore]'s on-disk friends list and per-room rosters — the
  /// offline seed that lets a DM's real name paint on the very first
  /// cold-start frame instead of the raw `dm:<id>_<id>` room name while
  /// `friends:listFriends` is still in flight. Deliberately skips the
  /// self-only fields ([visibility], [childPolicy], [hasRecoveryKey],
  /// [hasPassword], [usernameChangedAt]): `friends:listFriends` never
  /// populates them on someone else's row (see [visibility]'s own doc), so
  /// there is nothing there to round-trip.
  Map<String, dynamic> toJson() => {
        '_id': id,
        'username': username,
        'name': name,
        if (email != null) 'email': email,
        if (avatarStorageId != null) 'avatarStorageId': avatarStorageId,
        if (status != null) 'status': status,
        if (lastSeen != null) 'lastSeen': lastSeen!.millisecondsSinceEpoch,
        'friendshipStatus': friendshipStatus.name,
        if (requestId != null) 'requestId': requestId,
        if (role != null) 'role': role,
        if (isRedacted) 'isRedacted': true,
        'acceptsFriendRequests': acceptsFriendRequests,
        'accountType': accountType.wire,
        if (isSystem) 'isSystem': true,
        // The same argument [copyWith] makes for carrying this through, and
        // for the same reason — except that here the reshuffle it prevents is
        // the one that happens across a RELAUNCH rather than mid-session.
        //
        // `CacheStore.loadMembers` seeds a room's speaker colours on the first
        // frame, before `rooms:getMembers` has answered. That seed is only
        // worth having if it settles the palette to the identical assignment
        // the live roster will, and `SpeakerSlots.forMembers` settles
        // collisions in JOIN order. Dropping this field here would have every
        // cached member read back as `joinedAt: 0`, degrade the seed to id
        // order, and repaint the whole room a different set of colours the
        // instant the network landed — which is worse than the uncoloured
        // frame the cache exists to replace.
        //
        // Null on every non-room fetch, so this is absent from `friends.json`
        // exactly as it was before.
        if (joinedAt != null) 'joinedAt': joinedAt!.millisecondsSinceEpoch,
      };

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
    bool? awaitingGuardian,
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
        // Same reason: ProfileScreen re-grafts friendship state onto a fresh
        // fetch, and dropping this would turn a bot back into a person.
        isSystem: isSystem,
        // And the same again: a member re-grafted mid-session must not lose
        // the join instant their speaker colour is settled from, or the room
        // would reshuffle its colours under the reader.
        joinedAt: joinedAt,
        // Overridable: ProfileScreen grafts friendship state from the live
        // request lists onto a fresh fetch, and this travels with it.
        awaitingGuardian: awaitingGuardian ?? this.awaitingGuardian,
      );
}
