import 'dart:async';

import '../auth/recovery_phrase.dart';
import '../auth/session_store.dart';
import '../auth/social_sign_in.dart';
import '../legal_links.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/expression_item.dart';
import '../models/friend_request.dart';
import '../models/family.dart';
import '../models/friend_request_message.dart';
import '../models/message_formatting.dart';
import '../models/message_interaction.dart';
import '../models/room_admin.dart';
import '../models/room_content_item.dart';
import '../models/sticker_pack.dart';
import '../models/user_device.dart';
import '../push/device_identity.dart';
import 'convex_client.dart';
import 'hashing.dart';
import 'server_store.dart';

export 'hashing.dart' show sha256Hash;

/// Single home for every Convex function call the client makes.
/// Mirrors v02's `ConvexChatAPI` — one method per backend endpoint.
class ChatApi {
  ChatApi(this._cv);
  final ConvexBackend _cv;

  // ─────────────────────────────────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates an account. [recoveryKeyHash] is required and is already hashed:
  /// the plaintext phrase lives in exactly one widget's state and never
  /// reaches this layer, so there is nothing here to accidentally log.
  ///
  /// No `email` parameter. It was collected at signup and used for nothing —
  /// this app sends no mail — so it is now a profile-only contact field.
  Future<AuthResult> signup({
    required String username,
    required String name,
    required String password,
    required String recoveryKeyHash,
  }) async {
    final res = await _cv.mutation('auth:signup', {
      'username': username,
      'name': name,
      'passwordHash': sha256Hash(password),
      'recoveryKeyHash': recoveryKeyHash,
      // Binds the minted session to this device, so it can be named and
      // revoked from the Devices screen.
      'deviceId': await DeviceIdentity.ensure(),
      // The EULA box on the sign-up form, which the form will not submit
      // without. See `terms.ts`.
      'termsVersion': kTermsVersion,
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String username, required String password}) async {
    final res = await _cv.mutation('auth:login', {
      'username': username,
      'passwordHash': sha256Hash(password),
      'deviceId': await DeviceIdentity.ensure(),
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  /// Who the server thinks this device's token belongs to.
  ///
  /// Takes no arguments on purpose — the whole value of this call is that it
  /// trusts nothing the client believes about itself. See `auth.whoami`.
  ///
  /// Null on a malformed reply rather than throwing: the caller treats "no
  /// answer" as "ask again later", and a session that has actually died throws
  /// from the layer below, where `SessionGuard` is watching.
  Future<Session?> whoami() async {
    final res = await _cv.query('auth:whoami', const {});
    if (res is! Map<String, dynamic>) return null;
    final userId = res['userId'] as String?;
    final username = res['username'] as String?;
    if (userId == null || username == null) return null;
    return Session(
      userId: userId,
      username: username,
      name: res['name'] as String? ?? username,
      accountType: AccountTypeWire.parse(res['accountType'] as String?),
    );
  }

  Future<void> logout({required String userId}) async {
    // `userId` is now derived from the token server-side; the device id is what
    // names WHICH session to revoke.
    await _cv.mutation('auth:logout', {
      'deviceId': await DeviceIdentity.ensure(),
    });
  }

  /// Resets a password using a recovery phrase, as typed.
  ///
  /// Sends TWO candidate hashes and lets the server accept either, so that
  /// both the new 12-word phrases and the legacy freehand ones keep working.
  /// The server can never upgrade a legacy hash on its own — it never sees
  /// plaintext — so this compatibility is permanent by design. See the table
  /// on `recoveryResetHashes`.
  Future<AuthResult> resetPassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final hashes = recoveryResetHashes(recoveryKey);
    final res = await _cv.mutation('auth:resetPasswordWithRecoveryKey', {
      'username': username,
      'recoveryKeyHash': hashes.primary,
      'legacyRecoveryKeyHash': hashes.legacy,
      'newPasswordHash': sha256Hash(newPassword),
      'deviceId': await DeviceIdentity.ensure(),
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  /// Sets or replaces the recovery phrase on an existing account.
  ///
  /// Password-authenticated: this is an account-takeover primitive, so it must
  /// not rely on the client-supplied `userId` the way the rest of this API
  /// does. See `auth.setRecoveryKey` on the backend.
  Future<void> setRecoveryKey({
    required String userId,
    required String password,
    required String recoveryKeyHash,
  }) async {
    await _cv.mutation('auth:setRecoveryKey', {
      'userId': userId,
      'passwordHash': sha256Hash(password),
      'recoveryKeyHash': recoveryKeyHash,
    });
  }

  /// Whether a handle could be claimed right now.
  ///
  /// Feeds the typeahead under every pick-a-username field, never a decision —
  /// the answer is stale the moment it arrives, and all four write paths
  /// re-check inside their own transaction. See `users.isUsernameAvailable` for
  /// what accepting this endpoint cost.
  ///
  /// [excludeUserId] is the rename case: your own current handle is taken by
  /// you, and saying so about the value the field opens with is nonsense.
  Future<UsernameAvailability> isUsernameAvailable({
    required String username,
    String? excludeUserId,
  }) async {
    final res = await _cv.query('users:isUsernameAvailable', {
      'username': username,
      'excludeUserId': ?excludeUserId,
    });
    final map = (res as Map).cast<String, dynamic>();
    return UsernameAvailability(
      available: (map['available'] as bool?) ?? false,
      reason: map['reason'] as String?,
    );
  }

  /// Changes the handle on a password account.
  ///
  /// Password-authenticated for a sharper reason than [setRecoveryKey]: the
  /// handle IS the login credential, so this call changes what the user types
  /// to sign in. See `auth.changeUsername`.
  ///
  /// Returns the handle as the SERVER normalised it, which is what belongs in
  /// the session — not the string the user typed, which may carry whitespace
  /// the backend trimmed off.
  Future<String> changeUsername({
    required String userId,
    required String password,
    required String username,
  }) async {
    final res = await _cv.mutation('auth:changeUsername', {
      'userId': userId,
      'passwordHash': sha256Hash(password),
      'username': username,
    });
    return (res as Map<String, dynamic>)['username'] as String;
  }

  /// The same, for an account that has no password because it signs in with
  /// Apple or Google.
  ///
  /// The proof is a freshly minted provider token rather than a password. The
  /// caller must have just re-run the native sheet — a stored credential would
  /// prove only that the user signed in once, which is not the same claim.
  Future<String> changeUsernameWithIdentity({
    required String userId,
    required SocialCredential credential,
    required String username,
  }) async {
    final res = await _cv.action('socialAuth:changeUsernameWithIdentity', {
      'userId': userId,
      'provider': credential.provider.wire,
      'idToken': credential.idToken,
      if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
      'username': username,
    });
    return (res as Map<String, dynamic>)['username'] as String;
  }

  Future<void> deleteAccount({required String userId}) async {
    await _cv.mutation('auth:deleteAccount', {'userId': userId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Social sign-in (Apple / Google)
  //
  // ACTIONS, not mutations: verifying a provider token means fetching that
  // provider's JWKS, and only actions can reach the network.
  //
  // These return the same `{userId, username, name}` shape `auth:login` does,
  // so `AuthService` persists the session through the identical code path.
  // ─────────────────────────────────────────────────────────────────────────

  /// Verifies a provider token and either signs in or reports that this
  /// identity has no account yet.
  ///
  /// Returns `null` when the backend answered `needsUsername` — the caller then
  /// collects a username and calls [completeSocialSignUp] with the SAME
  /// credential, which the backend re-verifies. Holding a verified-but-unclaimed
  /// state server-side would need a table and a forgeable handle; re-verifying
  /// needs neither.
  Future<SocialSignInOutcome> socialSignIn(SocialCredential credential) async {
    final res = await _cv.action('socialAuth:signIn', {
      'provider': credential.provider.wire,
      'deviceId': await DeviceIdentity.ensure(),
      'idToken': credential.idToken,
      if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
      if (credential.authorizationCode != null)
        'authorizationCode': credential.authorizationCode,
      if (credential.suggestedName != null) 'fullName': credential.suggestedName,
    });
    final map = res as Map<String, dynamic>;
    if (map['status'] == 'needsUsername') {
      return SocialSignInOutcome.needsUsername(
        suggestedName: map['suggestedName'] as String?,
        email: map['email'] as String?,
      );
    }
    return SocialSignInOutcome.signedIn(AuthResult.fromJson(map));
  }

  Future<AuthResult> completeSocialSignUp({
    required SocialCredential credential,
    required String username,
    String? name,
  }) async {
    final res = await _cv.action('socialAuth:completeSignUp', {
      'provider': credential.provider.wire,
      'deviceId': await DeviceIdentity.ensure(),
      'idToken': credential.idToken,
      if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
      if (credential.authorizationCode != null)
        'authorizationCode': credential.authorizationCode,
      'username': username,
      if (name != null && name.isNotEmpty) 'name': name,
      // The EULA box on the username step, which will not submit without it.
      'termsVersion': kTermsVersion,
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  /// Signs in to an existing username/password account AND attaches the
  /// provider to it, in one call.
  ///
  /// The "I already have an account" path. Distinct from [linkSocialIdentity]
  /// because the caller is not signed in yet and has no `userId` — the username
  /// is the lookup and the password is the proof.
  Future<AuthResult> linkSocialToExistingAccount({
    required SocialCredential credential,
    required String username,
    required String password,
  }) async {
    final res = await _cv.action('socialAuth:linkExistingAccount', {
      'provider': credential.provider.wire,
      'deviceId': await DeviceIdentity.ensure(),
      'idToken': credential.idToken,
      if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
      if (credential.authorizationCode != null)
        'authorizationCode': credential.authorizationCode,
      'username': username,
      'passwordHash': sha256Hash(password),
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  /// Attaches a provider to an account that already exists.
  ///
  /// Password-authenticated for the same reason [setRecoveryKey] is: without it
  /// this would let anyone who learned a `userId` bolt their own Apple ID onto
  /// that account and sign in as it.
  Future<void> linkSocialIdentity({
    required String userId,
    required String password,
    required SocialCredential credential,
  }) async {
    await _cv.action('socialAuth:link', {
      'userId': userId,
      'passwordHash': sha256Hash(password),
      'provider': credential.provider.wire,
      'idToken': credential.idToken,
      if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
      if (credential.authorizationCode != null)
        'authorizationCode': credential.authorizationCode,
    });
  }

  Future<void> unlinkSocialIdentity({
    required String userId,
    required String password,
    required SocialProvider provider,
  }) async {
    await _cv.mutation('socialAuth:unlink', {
      'userId': userId,
      'passwordHash': sha256Hash(password),
      'provider': provider.wire,
    });
  }

  /// Which providers are attached to this account. Provider names only — the
  /// backend deliberately withholds the provider email; see `socialAuth.dart`.
  Future<List<SocialProvider>> linkedProviders({required String userId}) async {
    final res = await _cv.query('socialAuth:linkedProviders', {'userId': userId});
    final rows = (res as List?) ?? const [];
    final out = <SocialProvider>[];
    for (final row in rows) {
      final wire = (row as Map<String, dynamic>)['provider'] as String?;
      for (final provider in SocialProvider.values) {
        if (provider.wire == wire) out.add(provider);
      }
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Users
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch a user's profile. Pass [viewerUserId] so the backend can apply
  /// per-field visibility for the viewer (friends-only / nobody fields are
  /// stripped from the response).
  Future<ChatUser?> getProfile(String userId, {String? viewerUserId}) async {
    final res = await _cv.query('users:getProfile', {
      'userId': userId,
      'viewerUserId': ?viewerUserId,
    });
    if (res == null) return null;
    return ChatUser.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Updates per-field profile visibility. Only non-null fields are touched;
  /// pass exactly what you want to change.
  Future<void> updateVisibility({
    required String userId,
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? seen,
    FieldVisibility? friendRequests,
    FieldVisibility? feed,
    FieldVisibility? points,
    FieldVisibility? puzzle,
    FieldVisibility? pointsPast,
  }) async {
    await _cv.mutation('users:updateVisibility', {
      'userId': userId,
      if (avatar != null) 'avatar': avatar.wire,
      if (status != null) 'status': status.wire,
      if (lastSeen != null) 'lastSeen': lastSeen.wire,
      if (seen != null) 'seen': seen.wire,
      if (friendRequests != null) 'friendRequests': friendRequests.wire,
      // Feed keys accept only friends/nobody — the server drops "public"
      // rather than storing a value the board could not honour.
      if (feed != null) 'feed': feed.wire,
      if (points != null) 'points': points.wire,
      if (puzzle != null) 'puzzle': puzzle.wire,
      if (pointsPast != null) 'pointsPast': pointsPast.wire,
    });
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    String? email,
  }) async {
    await _cv.mutation('users:updateProfile', {
      'userId': userId,
      'name': name,
      'email': ?email,
    });
  }

  Future<void> updateAvatar({required String userId, required String storageId}) async {
    await _cv.mutation('users:updateAvatar', {'userId': userId, 'storageId': storageId});
  }

  Future<void> updateStatus({required String userId, required String status}) async {
    await _cv.mutation('users:updateStatus', {'userId': userId, 'status': status});
  }

  /// Presence keepalive — refreshes `lastSeen` without changing the stored
  /// online/away status. Called on an interval by the app so a client that
  /// stops heartbeating (closed browser tab, killed app) is treated as offline
  /// by the server's staleness fallback. See backend `users:heartbeat`.
  Future<void> heartbeat({required String userId}) async {
    await _cv.mutation('users:heartbeat', {'userId': userId});
  }

  /// Persist the PushKit (iOS) VoIP token so the backend can wake this device
  /// into CallKit even when the app is killed. Keyed by (userId, deviceId)
  /// so multiple devices for the same user keep their own tokens.
  /// [locale] and [tzOffsetMinutes] ride along with every push credential, and
  /// deliberately duplicate [setDeviceContext]. They are what the daily games
  /// nudge addresses its audience by, and a row that holds a token but no zone
  /// is pushable and permanently invisible to it — so the two facts travel with
  /// the token rather than depending on a second call having also landed.
  Future<void> setVoipToken({
    required String userId,
    required String deviceId,
    required String platform,
    required String token,
    String? deviceName,
    String? apnsEnv, // "sandbox" | "production"
    String? locale,
    int? tzOffsetMinutes,
  }) async {
    await _cv.mutation('voipTokens:setVoipToken', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'token': token,
      'deviceName': ?deviceName,
      'apnsEnv': ?apnsEnv,
      'locale': ?locale,
      'tzOffsetMinutes': ?tzOffsetMinutes,
    });
  }

  /// Persist the ordinary APNs (iOS) token — the one every banner, badge and
  /// silent dismiss is addressed to.
  ///
  /// A DIFFERENT token from [setVoipToken], on a different APNs topic. They
  /// are stored in separate columns and must never be crossed: sent on the
  /// wrong topic APNs answers 400, and the backend's dead-token sweep would
  /// then clear a perfectly good credential.
  Future<void> setApnsToken({
    required String userId,
    required String deviceId,
    required String platform,
    required String token,
    String? deviceName,
    String? apnsEnv, // "sandbox" | "production"
    String? locale,
    int? tzOffsetMinutes,
  }) async {
    await _cv.mutation('voipTokens:setApnsToken', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'token': token,
      'deviceName': ?deviceName,
      'apnsEnv': ?apnsEnv,
      'locale': ?locale,
      'tzOffsetMinutes': ?tzOffsetMinutes,
    });
  }

  /// Persist a browser Web Push subscription (RFC 8030). All three fields move
  /// together: the endpoint says which push service to POST to, the two keys
  /// seed the payload encryption, and a partial update yields a subscription
  /// that can be addressed but not encrypted for.
  Future<void> setWebPushSubscription({
    required String userId,
    required String deviceId,
    required String endpoint,
    required String p256dh,
    required String auth,
    String? deviceName,
  }) async {
    await _cv.mutation('voipTokens:setWebPushSubscription', {
      'userId': userId,
      'deviceId': deviceId,
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'deviceName': ?deviceName,
    });
  }

  /// The notifications toggle, per device. Suppresses alert pushes only —
  /// calls still ring.
  Future<void> setPushEnabled({
    required String userId,
    required String deviceId,
    required bool enabled,
  }) async {
    await _cv.mutation('voipTokens:setPushEnabled', {
      'userId': userId,
      'deviceId': deviceId,
      'enabled': enabled,
    });
  }

  /// The daily-games reminder toggle, per device. Suppresses only the
  /// once-a-day nudge — messages, approvals and calls are untouched, which is
  /// the entire reason it is a second switch and not a mode of the first.
  Future<void> setGameReminders({
    required String userId,
    required String deviceId,
    required bool enabled,
  }) async {
    await _cv.mutation('voipTokens:setGameReminders', {
      'userId': userId,
      'deviceId': deviceId,
      'enabled': enabled,
    });
  }

  /// The friend-activity toggle, per device. Suppresses highlights, points and
  /// shared game results — the pushes other PEOPLE cause — and nothing else.
  ///
  /// A third switch because it is the only class of notification whose volume
  /// somebody else sets. See socialPush.ts.
  Future<void> setFriendActivity({
    required String userId,
    required String deviceId,
    required bool enabled,
  }) async {
    await _cv.mutation('voipTokens:setFriendActivity', {
      'userId': userId,
      'deviceId': deviceId,
      'enabled': enabled,
    });
  }

  /// This device's language and time zone, as the running app resolved them.
  ///
  /// The backend composes the daily nudge itself, so it needs both: the
  /// language to write it in, and the offset that says when noon is here. Sent
  /// together and re-sent whenever either moves — see
  /// [PushManager.syncDeviceContext].
  Future<void> setDeviceContext({
    required String userId,
    required String deviceId,
    required String platform,
    String? deviceName,
    String? locale,
    int? tzOffsetMinutes,
  }) async {
    await _cv.mutation('voipTokens:setDeviceContext', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'deviceName': ?deviceName,
      'locale': ?locale,
      'tzOffsetMinutes': ?tzOffsetMinutes,
    });
  }

  /// Persist the FCM (Android) token. Carries both the high-priority data
  /// pushes that wake a killed app into the native ringer and the ordinary
  /// notifications rendered by ChatNotifications.
  Future<void> setFcmToken({
    required String userId,
    required String deviceId,
    required String platform,
    required String token,
    String? deviceName,
    String? locale,
    int? tzOffsetMinutes,
  }) async {
    await _cv.mutation('voipTokens:setFcmToken', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'token': token,
      'deviceName': ?deviceName,
      'locale': ?locale,
      'tzOffsetMinutes': ?tzOffsetMinutes,
    });
  }

  /// Tokenless device registration for platforms without native push
  /// (macOS, Windows, Linux, Web). Records the deviceId + label so the
  /// global "Move call here" pill can name this device when it holds
  /// the active call.
  Future<void> registerDevice({
    required String userId,
    required String deviceId,
    required String platform,
    String? deviceName,
  }) async {
    await _cv.mutation('voipTokens:registerDevice', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'deviceName': ?deviceName,
    });
  }

  /// Every device this account has signed in on, newest sighting first with
  /// this one pinned to the top.
  ///
  /// A one-shot read rather than a subscription: the list changes when the
  /// user signs in somewhere or removes a row, neither of which happens while
  /// they are staring at this screen, and a live subscription here would be
  /// one more thing fanning out on every `userDevices` write.
  ///
  /// [deviceId] is this device's own id, so the server can mark its row.
  Future<List<UserDevice>> listDevices({
    required String userId,
    required String deviceId,
  }) async {
    final res = await _cv.query('voipTokens:listDevices', {
      'userId': userId,
      'deviceId': deviceId,
    });
    final rows = (res as List?) ?? const [];
    return rows
        .map((row) => UserDevice.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Remove every device except this one. Returns how many rows went.
  ///
  /// The server derives the victims from [deviceId] rather than taking a list,
  /// so a device that signed in since the screen last rendered is swept too —
  /// which is the only promise this button actually makes.
  Future<int> removeOtherDevices({
    required String userId,
    required String deviceId,
  }) async {
    final res = await _cv.mutation('voipTokens:removeOtherDevices', {
      'userId': userId,
      'deviceId': deviceId,
    });
    return ((res as Map<String, dynamic>?)?['removed'] as num?)?.toInt() ?? 0;
  }

  /// Logout from a single device — remove only this device's row from
  /// the userDevices registry. Sibling devices stay logged in.
  Future<void> clearDeviceToken({
    required String userId,
    required String deviceId,
  }) async {
    await _cv.mutation('voipTokens:clearDeviceToken', {
      'userId': userId,
      'deviceId': deviceId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rooms
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String userId,
    required String name,
    required bool isPrivate,
    String? description,
    String? password,
    RoomType type = RoomType.regular,
    Duration? messageLifetime,
  }) async {
    final res = await _cv.mutation('rooms:create', {
      'userId': userId,
      'name': name,
      'isPrivate': isPrivate,
      if (description != null && description.isNotEmpty) 'description': description,
      if (password != null && password.isNotEmpty) 'passwordHash': sha256Hash(password),
      'type': type.wire,
      if (messageLifetime != null) 'messageLifetime': messageLifetime.inSeconds,
    });
    return res.toString();
  }

  Future<void> joinRoom({required String roomId, required String userId, String? password}) async {
    await _cv.mutation('rooms:join', {
      'roomId': roomId,
      'userId': userId,
      if (password != null && password.isNotEmpty) 'passwordHash': sha256Hash(password),
    });
  }

  Future<void> leaveRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:leave', {'roomId': roomId, 'userId': userId});
  }

  Future<void> deleteRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:deleteRoom', {'roomId': roomId, 'userId': userId});
  }

  Future<void> updateRoom({
    required String roomId,
    required String userId,
    required String name,
    String? description,
    bool? isPrivate,
    Duration? messageLifetime,
  }) async {
    await _cv.mutation('rooms:updateRoom', {
      'roomId': roomId,
      'userId': userId,
      'name': name,
      'description': ?description,
      'isPrivate': ?isPrivate,
      'messageLifetime': ?messageLifetime?.inSeconds,
    });
  }

  /// Pass null/empty password to clear the password on a room. Owner only.
  Future<void> updateRoomPassword({
    required String roomId,
    required String userId,
    String? password,
  }) async {
    await _cv.mutation('rooms:updatePassword', {
      'roomId': roomId,
      'userId': userId,
      if (password != null && password.isNotEmpty)
        'passwordHash': sha256Hash(password),
    });
  }

  Future<void> updateRoomAvatar({
    required String roomId,
    required String userId,
    required String storageId,
  }) async {
    await _cv.mutation('rooms:updateRoomAvatar', {
      'roomId': roomId,
      'userId': userId,
      'storageId': storageId,
    });
  }

  Future<List<ChatRoom>> listUserRooms(String userId) async {
    final res = await _cv.query('rooms:listUserRooms', {'userId': userId});
    return _decodeRooms(res);
  }

  /// Pass [viewerUserId] so the backend can return an empty list for a child
  /// whose guardian hasn't unlocked public rooms — the client hides Discover
  /// too, but this is the half that can't be worked around.
  Future<List<ChatRoom>> listPublic({String? viewerUserId}) async {
    final res = await _cv.query('rooms:listPublic', {
      'viewerUserId': ?viewerUserId,
    });
    return _decodeRooms(res);
  }

  Future<ChatRoom?> getRoom(String roomId) async {
    final res = await _cv.query('rooms:getRoom', {'roomId': roomId});
    if (res == null) return null;
    return ChatRoom.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Pass [viewerUserId] — the server redacts each member's avatar and
  /// presence to what that viewer is allowed to see, and without it everyone
  /// comes back at the public-only level.
  Future<List<ChatUser>> getMembers(String roomId, {String? viewerUserId}) async {
    final res = await _cv.query('rooms:getMembers', {
      'roomId': roomId,
      'viewerUserId': ?viewerUserId,
    });
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> getOrCreateDM({
    required String userId,
    required String friendId,
    RoomType roomType = RoomType.regular,
    Duration? messageLifetime,
  }) async {
    final res = await _cv.mutation('rooms:getOrCreateDM', {
      'userId': userId,
      'friendId': friendId,
      'roomType': roomType.displayLabel,
      'messageLifetime': ?messageLifetime?.inSeconds,
    });
    return res.toString();
  }

  Future<void> pinRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:pinRoom', {'roomId': roomId, 'userId': userId});
  }

  Future<void> unpinRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:unpinRoom', {'roomId': roomId, 'userId': userId});
  }

  Future<void> archiveRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:archiveRoom', {'roomId': roomId, 'userId': userId});
  }

  Future<void> unarchiveRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:unarchiveRoom', {'roomId': roomId, 'userId': userId});
  }

  /// Silence a room for this user. See `lib/models/room_mute.dart`.
  ///
  /// [durationMs] is a LENGTH, and null means "always". The server turns it
  /// into an absolute deadline with its own clock, deliberately — sending our
  /// own instant would mute for the wrong stretch of time on any device whose
  /// clock has drifted.
  ///
  /// Re-muting an already-muted room is the same call: the backend overwrites
  /// all three columns, so there is no previous deadline to reconcile.
  Future<void> muteRoom({
    required String roomId,
    required String userId,
    required bool notifications,
    required bool badges,
    int? durationMs,
  }) async {
    await _cv.mutation('rooms:muteRoom', {
      'roomId': roomId,
      'userId': userId,
      'notifications': notifications,
      'badges': badges,
      'durationMs': ?durationMs,
    });
  }

  Future<void> unmuteRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:unmuteRoom', {'roomId': roomId, 'userId': userId});
  }

  /// Idempotent — safe to call on every launch. Returns the self-chat's room
  /// id; the room itself surfaces to the UI via the `rooms:listUserRooms`
  /// subscription, not through this return value.
  Future<String> ensureSavedMessagesRoom({required String userId}) async {
    final res = await _cv.mutation('rooms:ensureSavedMessagesRoom', {'userId': userId});
    return res.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Group administration
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Roles, the join link, and the two kinds of invite. See `roomAdmin.ts`,
  // `roomInvites.ts` and `roomInvitations.ts`; the models are in
  // `models/room_admin.dart`.
  //
  // Nothing here is an authorization boundary. Every one of these mutations
  // re-derives the caller's role server-side and refuses on its own — the
  // permission flags this file fetches exist to stop us DRAWING a control that
  // would refuse, which is a different job and a much less important one.

  /// The caller's own standing in one room. Null when they are not in it.
  Future<RoomPermissions?> roomPermissions({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomAdmin:myPermissions', {
      'roomId': roomId,
      'userId': userId,
    });
    if (res == null) return null;
    return RoomPermissions.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Promote a member to admin, or demote an admin back to member. One call
  /// for both directions, because the UI is one toggle and the two share every
  /// check — see `roomAdmin.setAdmin`.
  Future<void> setRoomAdmin({
    required String roomId,
    required String userId,
    required String targetUserId,
    required bool makeAdmin,
  }) async {
    await _cv.mutation('roomAdmin:setAdmin', {
      'roomId': roomId,
      'userId': userId,
      'targetUserId': targetUserId,
      'makeAdmin': makeAdmin,
    });
  }

  /// Hand the room to another member. The caller becomes an admin, not a
  /// plain member — giving a group away is not the same as walking out of it.
  Future<void> transferRoomOwnership({
    required String roomId,
    required String userId,
    required String targetUserId,
  }) async {
    await _cv.mutation('roomAdmin:transferOwnership', {
      'roomId': roomId,
      'userId': userId,
      'targetUserId': targetUserId,
    });
  }

  Future<void> removeRoomMember({
    required String roomId,
    required String userId,
    required String targetUserId,
  }) async {
    await _cv.mutation('roomAdmin:removeMember', {
      'roomId': roomId,
      'userId': userId,
      'targetUserId': targetUserId,
    });
  }

  /// The room's two administrative switches. Both optional so the caller can
  /// flip one without restating the other.
  Future<void> setRoomPolicy({
    required String roomId,
    required String userId,
    bool? membersCanInvite,
    RoomJoinPolicy? linkJoinPolicy,
  }) async {
    await _cv.mutation('roomAdmin:setRoomPolicy', {
      'roomId': roomId,
      'userId': userId,
      'membersCanInvite': ?membersCanInvite,
      'linkJoinPolicy': ?linkJoinPolicy?.wire,
    });
  }

  // ── The join link ────────────────────────────────────────────────────────

  /// The room's current link, or null when no link has ever been issued.
  ///
  /// Reading deliberately does NOT create one: a room with no link should not
  /// grow one because an admin opened a settings screen.
  Future<RoomInviteLink?> getRoomInviteLink({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomInvites:getLink', {
      'roomId': roomId,
      'userId': userId,
    });
    if (res == null) return null;
    return RoomInviteLink.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Issue a link, revoking any existing one in the same breath. This is both
  /// "create" and "regenerate" — see `roomInvites.rotate`.
  ///
  /// [expiresIn] is sent as a DURATION, never as an absolute instant: the
  /// server computes the deadline from its own clock so a phone that is hours
  /// off cannot mint a link that is already dead.
  Future<RoomInviteLink> rotateRoomInviteLink({
    required String roomId,
    required String userId,
    Duration? expiresIn,
    int? maxUses,
  }) async {
    final res = await _cv.mutation('roomInvites:rotate', {
      'roomId': roomId,
      'userId': userId,
      'expiresInMs': ?expiresIn?.inMilliseconds,
      'maxUses': ?maxUses,
    });
    return RoomInviteLink.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Kill the link without issuing a replacement.
  Future<void> revokeRoomInviteLink({
    required String roomId,
    required String userId,
  }) async {
    await _cv.mutation('roomInvites:revoke', {'roomId': roomId, 'userId': userId});
  }

  /// What is behind a code, without joining. Never throws for a bad code —
  /// the outcome comes back as [InvitePreview.problem], because this is the
  /// first screen after tapping a link and a typo is not an exception.
  Future<InvitePreview> previewInvite({
    required String code,
    String? userId,
  }) async {
    final res = await _cv.query('roomInvites:preview', {
      'code': code,
      'userId': ?userId,
    });
    return InvitePreview.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Use a code. Joins, or files a request, depending on the room's policy.
  Future<({RedeemOutcome outcome, String roomId})> redeemInvite({
    required String code,
    required String userId,
  }) async {
    final res = await _cv.mutation('roomInvites:redeem', {
      'code': code,
      'userId': userId,
    });
    final m = (res as Map).cast<String, dynamic>();
    final status = m['status'] as String?;
    return (
      outcome: switch (status) {
        'joined' => RedeemOutcome.joined,
        'pending' => RedeemOutcome.requested,
        _ => RedeemOutcome.alreadyMember,
      },
      roomId: m['roomId'].toString(),
    );
  }

  // ── Join requests (someone with the link asking to come in) ──────────────

  Future<List<RoomJoinRequest>> listJoinRequests({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomInvites:listJoinRequests', {
      'roomId': roomId,
      'userId': userId,
    });
    return ((res as List?) ?? const [])
        .map((e) => RoomJoinRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> decideJoinRequest({
    required String requestId,
    required String userId,
    required bool approve,
  }) async {
    await _cv.mutation('roomInvites:decideJoinRequest', {
      'requestId': requestId,
      'userId': userId,
      'approve': approve,
    });
  }

  // ── Change requests (a member asking to redecorate the group) ────────────

  /// Ask for the group's name, description or picture to change.
  ///
  /// Returns true when it went into the admins' queue, false when it applied
  /// straight away — which happens only if the caller turned out to be an
  /// admin after all (promoted while they were picking a photo). The client
  /// never chooses this path for somebody it knows can edit; see
  /// `roomChangeRequests.propose`.
  Future<bool> proposeRoomChange({
    required String roomId,
    required String userId,
    required RoomChangeField field,
    String? value,
    String? storageId,
  }) async {
    final res = await _cv.mutation('roomChangeRequests:propose', {
      'roomId': roomId,
      'userId': userId,
      'field': field.wire,
      'value': ?value,
      'storageId': ?storageId,
    });
    return ((res as Map?) ?? const {})['status'] != 'applied';
  }

  Future<void> withdrawRoomChange({
    required String requestId,
    required String userId,
  }) async {
    await _cv.mutation('roomChangeRequests:withdraw', {
      'requestId': requestId,
      'userId': userId,
    });
  }

  Future<void> decideRoomChange({
    required String requestId,
    required String userId,
    required bool approve,
  }) async {
    await _cv.mutation('roomChangeRequests:decide', {
      'requestId': requestId,
      'userId': userId,
      'approve': approve,
    });
  }

  /// The admin queue for one room. Empty, never an error, for anyone else.
  Future<List<RoomChangeRequest>> listRoomChangeRequests({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomChangeRequests:listPending', {
      'roomId': roomId,
      'userId': userId,
    });
    return ((res as List?) ?? const [])
        .map((e) =>
            RoomChangeRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// The caller's own outstanding suggestions for one room.
  Future<List<RoomChangeRequest>> myRoomChangeRequests({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomChangeRequests:mine', {
      'roomId': roomId,
      'userId': userId,
    });
    return ((res as List?) ?? const [])
        .map((e) =>
            RoomChangeRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ── Direct invites (a member naming a friend) ────────────────────────────

  /// The friend picker's list: friends not already in the room and not
  /// already invited to it. Filtered server-side — doing it here would mean
  /// shipping the client a roster of a room the user might not be in.
  Future<List<ChatUser>> invitableFriends({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomInvitations:invitableFriends', {
      'roomId': roomId,
      'userId': userId,
    });
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> inviteToRoom({
    required String roomId,
    required String userId,
    required String inviteeId,
  }) async {
    await _cv.mutation('roomInvitations:invite', {
      'roomId': roomId,
      'userId': userId,
      'inviteeId': inviteeId,
    });
  }

  /// The invitee's answer. Returns the room so an accept can open it.
  Future<String> respondToRoomInvitation({
    required String invitationId,
    required String userId,
    required bool accept,
  }) async {
    final res = await _cv.mutation('roomInvitations:respond', {
      'invitationId': invitationId,
      'userId': userId,
      'accept': accept,
    });
    return ((res as Map).cast<String, dynamic>())['roomId'].toString();
  }

  /// Withdraw an invite — the sender's own, or anyone's if the caller is an
  /// admin.
  /// A guardian releasing (or refusing) one hop of a group invite — the exact
  /// counterpart of `family:advanceContactRequest`, and the mutation the
  /// [QueueRelay.roomInvite] branch of the approvals queue calls.
  Future<void> advanceRoomInvitation({
    required String invitationId,
    required String guardianId,
    required bool approve,
  }) async {
    await _cv.mutation('roomInvitations:advance', {
      'invitationId': invitationId,
      'guardianId': guardianId,
      'approve': approve,
    });
  }

  Future<void> cancelRoomInvitation({
    required String invitationId,
    required String userId,
  }) async {
    await _cv.mutation('roomInvitations:cancel', {
      'invitationId': invitationId,
      'userId': userId,
    });
  }

  Future<List<RoomInvitation>> listIncomingRoomInvitations(String userId) async {
    final res = await _cv.query('roomInvitations:listIncoming', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => RoomInvitation.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Invites this room has out and nobody has answered yet.
  Future<List<PendingRoomInvite>> listRoomInvitations({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomInvitations:listForRoom', {
      'roomId': roomId,
      'userId': userId,
    });
    return ((res as List?) ?? const [])
        .map((e) => PendingRoomInvite.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Messages
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaStorageId,
    /// Pixel size of [mediaStorageId] when the sender knows it, so receivers can
    /// lay the bubble out at the picture's real ratio without decoding it first.
    double? mediaWidth,
    double? mediaHeight,

    /// Set on [MessageType.file] and nothing else. Convex storage records
    /// neither the original name nor a usable content type, so a document that
    /// doesn't carry them here can never be presented as anything but a UUID.
    String? fileName,
    int? fileSize,
    String? mimeType,

    /// Playing time of an audio or video attachment, when the sender measured
    /// it, so a shared-content row shows a duration without decoding first.
    int? mediaDurationMs,

    /// A still frame for a video, uploaded as a second blob. The server
    /// refuses to store one on an armed send.
    String? posterStorageId,
    String? senderName,
    String? replyToId,

    /// With [replyToId] naming an album's first message: the reply is to the
    /// whole album, and the server counts it into the preview.
    bool replyToAlbum = false,

    /// The sender's count of that album, for one from before album ids,
    /// which the server cannot count itself.
    int? replyAlbumCount,

    /// The album this photo or video belongs to (see `ChatMessage.albumId`).
    String? albumId,

    /// Burn-after-reading. The server drops [mediaWidth]/[mediaHeight] for one
    /// of these and never hands the storage id back out again.
    bool viewOnce = false,

    /// Sent as a spoiler: everyone sees it blurred under dust until they tap.
    /// The server keeps it only on an image or video with a blob.
    bool mediaSpoiler = false,
    /// Idempotency key — the optimistic message's local id, reused verbatim on
    /// every retry of that message. The server returns the row it already wrote
    /// rather than writing a second one.
    String? clientId,
    /// Who this message names with an `@`. Ids only: the server resolves each
    /// one to a handle itself, and drops any that isn't a current member of the
    /// room or isn't actually written into [content].
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,

    /// Set on [MessageType.location] and [MessageType.liveLocation]. The server
    /// range-checks both and downgrades the message to text rather than
    /// refusing it if they don't survive — a coordinate a retry cannot fix must
    /// not strand a bubble in the pending list forever.
    double? latitude,
    double? longitude,
    double? locationAccuracyM,

    /// How long a live share runs for, in milliseconds. Only read on
    /// [MessageType.liveLocation], and only accepted server-side if it is one
    /// of the three offered durations — see [LiveShareDuration]. A value the
    /// server refuses makes the message a static location, not an unbounded
    /// share.
    int? liveDurationMs,

    /// Rich-text spans over [content] — see `message_formatting.dart`. The
    /// server clamps them against the text; a span it refuses just renders
    /// plain on every device.
    List<FormattingEntity> formatting = const [],

    /// The GIF or sticker, on [MessageType.gif] and [MessageType.sticker].
    /// Supplies the type and the picture-naming fields; the server decides
    /// what is written — see `expressionFieldsFor` in messages.ts.
    ExpressionItem? expression,
  }) async {
    final res = await _cv.mutation('messages:send', {
      ...?expression?.toSendArgs(),
      'roomId': roomId,
      'userId': userId,
      'content': content,
      'type': type.wire,
      'clientId': ?clientId,
      'mediaStorageId': ?mediaStorageId,
      'mediaWidth': ?mediaWidth,
      'mediaHeight': ?mediaHeight,
      'fileName': ?fileName,
      'fileSize': ?fileSize,
      'mimeType': ?mimeType,
      'mediaDurationMs': ?mediaDurationMs,
      'posterStorageId': ?posterStorageId,
      'senderName': ?senderName,
      'replyToId': ?replyToId,
      if (replyToAlbum && replyToId != null) 'replyToAlbum': true,
      if (replyToAlbum && replyToId != null) 'replyAlbumCount': ?replyAlbumCount,
      'albumId': ?albumId,
      if (viewOnce) 'viewOnce': true,
      // Only ever `true`, never `false`: an ordinary send stays the shape a
      // server from before spoilers accepts.
      if (mediaSpoiler) 'mediaSpoiler': true,
      // Omitted rather than sent empty, matching `viewOnce` above — the common
      // message mentions nobody and shouldn't widen the wire to say so.
      if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      if (mentionsEveryone) 'mentionsEveryone': true,
      if (formatting.isNotEmpty)
        'formatting': [for (final f in formatting) f.toJson()],
      'latitude': ?latitude,
      'longitude': ?longitude,
      'locationAccuracyM': ?locationAccuracyM,
      'liveDurationMs': ?liveDurationMs,
    });
    return res.toString();
  }

  /// Moves a running live share to a new position.
  ///
  /// Returns whether the share is still live. False is an ordinary answer, not
  /// an error: the deadline may have passed, the sharer may have stopped it
  /// from another device, or the message may have been deleted. The publisher
  /// reads a false as "shut down", which is how a share ended elsewhere reaches
  /// this device without anything polling for it.
  ///
  /// Swallows transport failures as `true`. A dropped mutation on bad cellular
  /// must not be read as "the share is over" — the next fix will land, and if
  /// it genuinely is over the server will say so with an answer rather than
  /// with a socket error.
  Future<bool> updateLiveLocation({
    required String messageId,
    required String userId,
    required double latitude,
    required double longitude,
    double? accuracyM,
  }) async {
    try {
      final res = await _cv.mutation('messages:updateLiveLocation', {
        'messageId': messageId,
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'locationAccuracyM': ?accuracyM,
      });
      final m = (res as Map?)?.cast<String, dynamic>() ?? const {};
      return (m['ok'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Ends a live share early. Idempotent server-side — a share that already
  /// expired reports success, because "it has stopped" is what the caller asked
  /// for.
  Future<void> stopLiveLocation({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('messages:stopLiveLocation', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  /// Spends this viewer's one look at a view-once photo and returns a ticket
  /// for [viewOnceStreamUrl].
  ///
  /// The view is recorded server-side the moment this returns a nonce, NOT when
  /// the picture is dismissed — a client that crashes mid-view has still used
  /// its look, because it could not have got the ticket otherwise. Calling
  /// again with the same nonce still live is a retry, not a second view.
  ///
  /// Returns a null [nonce] when the photo is spent, burned, or was never
  /// armed; [alreadyViewed] distinguishes "you had your look" from "it's gone".
  Future<({String? nonce, bool alreadyViewed, bool gone})> openViewOnce({
    required String messageId,
    required String userId,
  }) async {
    final res = await _cv.mutation('messages:openViewOnce', {
      'messageId': messageId,
      'userId': userId,
    });
    final m = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      nonce: m['nonce'] as String?,
      alreadyViewed: (m['alreadyViewed'] as bool?) ?? false,
      gone: (m['gone'] as bool?) ?? false,
    );
  }

  /// Where to fetch the bytes for a ticket minted by [openViewOnce].
  ///
  /// Deliberately not a Convex storage URL: those are unsigned and never
  /// expire on this deployment, so one would be a permanent copy of a photo
  /// that is supposed to stop existing. This URL dies with its nonce.
  static Uri viewOnceStreamUrl({
    required String messageId,
    required String userId,
    required String nonce,
  }) {
    // From the store, not from Env: on a self-hosted install this has to point
    // at the user's own backend, or the ticket minted a line above is presented
    // to a deployment that never issued it. `siteUrl` already resolves the
    // cloud/self-host split — see [ServerEndpoint.siteUrl].
    final base = ServerStore.instance.siteUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/viewOnce').replace(queryParameters: {
      'm': messageId,
      'u': userId,
      'n': nonce,
    });
  }

  /// One page of the thread rooted at [rootId], walking *older*: pass the
  /// oldest `createdAt` you already hold as [before], or omit it for the
  /// newest page. Result is chronological (oldest first).
  ///
  /// There is deliberately no "load newer" — the newest end of a thread is
  /// covered by the room's live `messages:list` subscription, which
  /// [ChatRepository.threadFor] merges in.
  Future<({List<ChatMessage> messages, bool hasMore})> getThreadPage({
    required String roomId,
    required String rootId,
    required String viewerUserId,
    DateTime? before,
    int limit = 25,
  }) async {
    final res = await _cv.query('messages:getThreadPage', {
      'roomId': roomId,
      'rootId': rootId,
      'viewerUserId': viewerUserId,
      'beforeTimestamp': ?before?.millisecondsSinceEpoch,
      'limit': limit,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      messages: _decodeMessages(map['messages']),
      hasMore: (map['hasMore'] as bool?) ?? false,
    );
  }

  /// DEPRECATED — use [getThreadPage]. Fetches the entire conversational
  /// thread containing [messageId] in one unpaged shot, capped at [maxTotal].
  Future<List<ChatMessage>> getThread({
    required String messageId,
    int maxTotal = 50,
  }) async {
    final res = await _cv.query('messages:getThread', {
      'messageId': messageId,
      'maxTotal': maxTotal,
    });
    return _decodeMessages(res);
  }

  Future<void> deleteMessage({required String messageId, required String userId}) async {
    await _cv.mutation('messages:deleteMessage', {'messageId': messageId, 'userId': userId});
  }

  /// Rewrites the text of the caller's own message, inside the server's
  /// 15-minute window.
  ///
  /// Returns null on success, else an error-code string for the caller to
  /// surface — the `pinMessage` shape, because Edit is a menu row and a menu
  /// row that silently does nothing reads as broken. `EDIT_WINDOW_EXPIRED` is
  /// the one refusal the UI can genuinely race into; anything the server
  /// throws (not the sender, not a text message, gone) flattens to
  /// `EDIT_FAILED`, since none of it is distinguishable to the person holding
  /// the phone from "it didn't work".
  ///
  /// Mentions and formatting are re-sent in full: the server re-resolves both
  /// against the NEW text, so an `@bob` the edit deleted drops its mention
  /// and a span the edit outgrew is clamped.
  Future<String?> editMessage({
    required String messageId,
    required String userId,
    required String content,
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async {
    try {
      final res = await _cv.mutation('messages:editMessage', {
        'messageId': messageId,
        'userId': userId,
        'content': content,
        if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
        if (mentionsEveryone) 'mentionsEveryone': true,
        if (formatting.isNotEmpty)
          'formatting': [for (final f in formatting) f.toJson()],
      });
      final code = res.toString();
      return code == 'OK' ? null : code;
    } catch (_) {
      return 'EDIT_FAILED';
    }
  }

  /// The server's clock. One-shot, not subscribed — `ChatRepository` samples
  /// it to compute a skew offset and gates the Edit affordance with that, so
  /// a device whose clock is minutes wrong doesn't offer an edit the server
  /// will only refuse (or hide one it would accept). The mutation re-checks
  /// with its own clock regardless.
  Future<DateTime> serverNow() async {
    final res = await _cv.query('messages:now', const {});
    return DateTime.fromMillisecondsSinceEpoch((res as num).toInt());
  }

  /// [viewerUserId] doesn't filter anything — it only lets the server say
  /// whether *this* viewer has already spent their look at each view-once
  /// photo. Omitting it costs the "Opened" state, not correctness.
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:list', {
      'roomId': roomId,
      'limit': limit,
      'viewerUserId': ?viewerUserId,
    });
    return _decodeMessages(res);
  }

  /// [upTo] is the `createdAt` of the newest message this device holds for the
  /// room. Given one, the server writes it as the read cursor and skips its own
  /// read of the room document — which is what keeps this call from colliding
  /// with `messages:send`, whose patch of that same document was aborting and
  /// re-running these under a fast two-way chat. See `messages.markRoomRead`.
  /// Omitted, the server falls back to the room's `lastMessageTime` as before.
  Future<void> markRoomRead({
    required String roomId,
    required String userId,
    DateTime? upTo,
  }) async {
    await _cv.mutation('messages:markRoomRead', {
      'roomId': roomId,
      'userId': userId,
      'upTo': ?upTo?.millisecondsSinceEpoch,
    });
  }

  /// Reports that this device now HAS the room's traffic, without claiming
  /// anyone looked at it — the second tick on the sender's message.
  ///
  /// Deliberately not per message: the server keeps one cursor per membership
  /// row, so this is safe to call once per room per burst of new traffic and
  /// pointless to call more often than that. See `messages:markRoomDelivered`,
  /// which drops the write entirely when the cursor is already current.
  ///
  /// [upTo] is the `createdAt` of the newest message this device holds — the
  /// most it can honestly claim. Omitted, the server takes the room's newest.
  Future<void> markRoomDelivered({
    required String roomId,
    required String userId,
    DateTime? upTo,
  }) async {
    await _cv.mutation('messages:markRoomDelivered', {
      'roomId': roomId,
      'userId': userId,
      'upTo': ?upTo?.millisecondsSinceEpoch,
    });
  }

  /// When the message stamped [createdAt] reached each other member of
  /// [roomId], and when they read it — live, for the receipts screen.
  ///
  /// userId → (deliveredAt, readAt). A time is null when it is not known, or
  /// the cursor has not reached the message; the cursors in
  /// `messages:getReadState` decide which. Members who do not share receipts
  /// with this viewer are absent. See `messages:getReceiptTimes`.
  Future<Subscription> subscribeReceiptTimes({
    required String roomId,
    required String viewerUserId,
    required DateTime createdAt,
    required void Function(
            Map<String, ({DateTime? deliveredAt, DateTime? readAt})> times)
        onTimes,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'messages:getReceiptTimes',
      {
        'roomId': roomId,
        'viewerUserId': viewerUserId,
        'createdAt': createdAt.millisecondsSinceEpoch,
      },
      onData: (raw) {
        final out = <String, ({DateTime? deliveredAt, DateTime? readAt})>{};
        for (final e in (raw as List?) ?? const []) {
          final m = (e as Map).cast<String, dynamic>();
          out[m['userId'].toString()] = (
            deliveredAt: _msOrNull(m['deliveredAt']),
            readAt: _msOrNull(m['readAt']),
          );
        }
        onTimes(out);
      },
      onError: onError,
    );
  }

  /// Returns `[{userId, lastReadAt(ms), lastDeliveredAt(ms)}]` for every member
  /// of the room who shares at least one of the two with this viewer — reads
  /// behind their `seen` level, deliveries behind their `lastSeen` level. The
  /// viewer's own row is always present, in full.
  ///
  /// Either timestamp is null where the viewer may not have it, which is NOT
  /// the same as epoch: a member who shares delivery but hides reads is a real
  /// row with a real second tick and no third one.
  ///
  /// Subscribe via the repo for live receipts.
  Future<List<({String userId, DateTime? lastReadAt, DateTime? lastDeliveredAt})>>
      getReadState({
    required String roomId,
    required String viewerUserId,
  }) async {
    final res = await _cv.query(
      'messages:getReadState',
      {'roomId': roomId, 'viewerUserId': viewerUserId},
    );
    return ((res as List?) ?? const []).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return (
        userId: (m['userId']).toString(),
        lastReadAt: _msOrNull(m['lastReadAt']),
        lastDeliveredAt: _msOrNull(m['lastDeliveredAt']),
      );
    }).toList();
  }

  /// A wire timestamp that is allowed to be absent. Absent means "you may not
  /// have this", which the receipt ladder has to tell apart from "1970".
  static DateTime? _msOrNull(Object? raw) {
    final n = raw as num?;
    return n == null ? null : DateTime.fromMillisecondsSinceEpoch(n.toInt());
  }

  Future<List<ChatMessage>> listBefore({
    required String roomId,
    required DateTime before,
    int limit = 30,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:listBefore', {
      'roomId': roomId,
      'beforeTimestamp': before.millisecondsSinceEpoch,
      'limit': limit,
      'viewerUserId': ?viewerUserId,
    });
    return _decodeMessages(res);
  }

  /// The ascending counterpart to [listBefore]. Only used to walk back down
  /// toward the present after [listAround] dropped the reader into old
  /// history — the newest end is covered by the live `messages:list`
  /// subscription.
  Future<List<ChatMessage>> listAfter({
    required String roomId,
    required DateTime after,
    int limit = 30,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:listAfter', {
      'roomId': roomId,
      'afterTimestamp': after.millisecondsSinceEpoch,
      'limit': limit,
      'viewerUserId': ?viewerUserId,
    });
    return _decodeMessages(res);
  }

  /// A window of history centred on [messageId] — the message itself plus
  /// [before] older and [after] newer, chronological. Lets the UI jump
  /// straight to a quoted message that predates everything it holds instead
  /// of paging the whole gap. `found` is false when the message has been
  /// deleted or doesn't belong to this room.
  Future<
      ({
        List<ChatMessage> messages,
        bool hasMoreOlder,
        bool hasMoreNewer,
        bool found,
      })> listAround({
    required String roomId,
    required String messageId,
    int before = 25,
    int after = 25,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:listAround', {
      'roomId': roomId,
      'messageId': messageId,
      'before': before,
      'after': after,
      'viewerUserId': ?viewerUserId,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      messages: _decodeMessages(map['messages']),
      hasMoreOlder: (map['hasMoreOlder'] as bool?) ?? false,
      hasMoreNewer: (map['hasMoreNewer'] as bool?) ?? false,
      found: (map['found'] as bool?) ?? false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scheduled messages
  // ─────────────────────────────────────────────────────────────────────────

  /// Queues [content] for delivery at a later time. Returns the staged row's id.
  ///
  /// Exactly one of [delayMs] and [sendAt] — the server refuses both and
  /// neither. See `SchedulePreset` for which presets use which and why the two
  /// forms are not interchangeable.
  ///
  /// Throws the server's own strings, which the caller is expected to map to a
  /// sentence: `SCHEDULE_OUT_OF_RANGE`, `TOO_MANY_SCHEDULED`,
  /// `SCHEDULE_NOT_IN_EPHEMERAL`, plus everything `guardOutgoing` can throw —
  /// the child-gate codes especially, which reach the same sheet a live send's
  /// refusal does.
  Future<String> scheduleMessage({
    required String roomId,
    required String userId,
    required String content,
    int? delayMs,
    int? sendAt,
    String? replyToId,

    /// Ids only. The server resolves each to a handle at RELEASE time, not now,
    /// so a member who leaves the room in the meantime is dropped rather than
    /// notified — the same rule a live send follows, applied at the moment the
    /// message actually exists.
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],

    /// Idempotency key, so a `schedule` that times out on the wire and is
    /// retried stages one row rather than two. Carried all the way into the
    /// eventual `messages:send` insert.
    required String clientId,

    /// A photo, already uploaded. [content] is then its caption.
    String? mediaStorageId,
    double? mediaWidth,
    double? mediaHeight,
    bool viewOnce = false,
    bool mediaSpoiler = false,
  }) async {
    final res = await _cv.mutation('scheduledMessages:schedule', {
      if (mediaStorageId != null) ...{
        'type': 'image',
        'mediaStorageId': mediaStorageId,
        'mediaWidth': ?mediaWidth,
        'mediaHeight': ?mediaHeight,
        if (viewOnce) 'viewOnce': true,
        if (mediaSpoiler) 'mediaSpoiler': true,
      },
      'roomId': roomId,
      'userId': userId,
      'content': content,
      'delayMs': ?delayMs,
      'sendAt': ?sendAt,
      'replyToId': ?replyToId,
      if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      if (mentionsEveryone) 'mentionsEveryone': true,
      if (formatting.isNotEmpty)
        'formatting': [for (final f in formatting) f.toJson()],
      'clientId': clientId,
    });
    return res.toString();
  }

  /// Moves a queued message to a new time. Same [delayMs]/[sendAt] contract as
  /// [scheduleMessage]. Also the retry path for a failed one — the server puts
  /// it back in the pending bucket and clears the failure.
  Future<void> rescheduleMessage({
    required String id,
    required String userId,
    int? delayMs,
    int? sendAt,
  }) async {
    await _cv.mutation('scheduledMessages:reschedule', {
      'id': id,
      'userId': userId,
      'delayMs': ?delayMs,
      'sendAt': ?sendAt,
    });
  }

  /// Rewrites a queued message's text. Leaves its send time alone.
  ///
  /// The mention and formatting sets travel with the text rather than being
  /// preserved server-side: spans are offsets into the OLD string, and mentions
  /// name people the new words may no longer mention.
  Future<void> updateScheduledText({
    required String id,
    required String userId,
    required String content,
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async {
    await _cv.mutation('scheduledMessages:updateText', {
      'id': id,
      'userId': userId,
      'content': content,
      if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      if (mentionsEveryone) 'mentionsEveryone': true,
      if (formatting.isNotEmpty)
        'formatting': [for (final f in formatting) f.toJson()],
    });
  }

  Future<void> cancelScheduledMessage({
    required String id,
    required String userId,
  }) async {
    await _cv.mutation('scheduledMessages:cancel', {
      'id': id,
      'userId': userId,
    });
  }

  /// Sends a queued message immediately, inline — not by rescheduling it to
  /// now. Returns the real message's id.
  Future<String> sendScheduledNow({
    required String id,
    required String userId,
  }) async {
    final res = await _cv.mutation('scheduledMessages:sendNow', {
      'id': id,
      'userId': userId,
    });
    return res.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,

    /// The reaction is to the whole album [messageId] heads.
    bool album = false,
  }) async {
    await _cv.mutation('reactions:addReaction', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      if (album) 'album': true,
    });
  }

  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,

    /// The reaction is to the whole album [messageId] heads.
    bool album = false,
  }) async {
    await _cv.mutation('reactions:removeReaction', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      if (album) 'album': true,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Interactive messages — polls, checklists and events
  // ─────────────────────────────────────────────────────────────────────────

  /// Posts a poll, checklist or event.
  ///
  /// One method for all three because the backend has one mutation, and it has
  /// one mutation because they are the same object with different words on it.
  /// The per-kind arguments are all optional and all ignored by the kinds they
  /// do not belong to — the server refuses a combination that makes no sense
  /// (an event with client-named buttons, a quiz with no answer) rather than
  /// quietly reinterpreting it.
  ///
  /// [labels] is the poll's options or the checklist's items, in order. Omitted
  /// for an event, whose three RSVP buttons are server-owned: a client naming
  /// its own would be inventing a fourth answer no other client can render.
  ///
  /// [correctIndex] indexes [labels], not a choice id — the client is naming
  /// one of the options it is sending, and has no ids yet.
  ///
  /// Returns the new message's id, so the caller can reconcile its optimistic
  /// bubble exactly as [sendMessage] lets it.
  Future<String> createInteraction({
    required String roomId,
    required String userId,
    required MessageType kind,
    required String prompt,
    List<String>? labels,
    bool multiple = false,
    bool anonymous = false,
    bool quiz = false,
    int? correctIndex,
    String? explanation,
    bool othersMayCheck = true,
    bool othersMayAdd = true,
    DateTime? startsAt,
    DateTime? endsAt,
    String? place,
    String? replyToId,
    String? senderName,
    String? clientId,
  }) async {
    final res = await _cv.mutation('interactions:create', {
      'roomId': roomId,
      'userId': userId,
      'kind': kind.wire,
      'prompt': prompt,
      'labels': ?labels,
      // Omitted rather than sent false, matching `sendMessage`'s treatment of
      // `viewOnce`: the ordinary poll is single-answer and public, and the
      // wire should not widen to say so.
      if (multiple) 'multiple': true,
      if (anonymous) 'anonymous': true,
      if (quiz) 'quiz': true,
      'correctIndex': ?correctIndex,
      'explanation': ?explanation,
      // These two are the other way round — they default ON, so the wire
      // carries only the author switching one off.
      if (!othersMayCheck) 'othersMayCheck': false,
      if (!othersMayAdd) 'othersMayAdd': false,
      if (startsAt != null) 'startsAt': startsAt.millisecondsSinceEpoch,
      if (endsAt != null) 'endsAt': endsAt.millisecondsSinceEpoch,
      'place': ?place,
      'replyToId': ?replyToId,
      'senderName': ?senderName,
      'clientId': ?clientId,
    });
    return res.toString();
  }

  /// Records one answer: a vote, a tick, or an RSVP.
  ///
  /// Toggles. Sending a choice this user already holds takes it back, which is
  /// what lets one control do both jobs — except on a quiz, where the server
  /// refuses and the answer stands.
  Future<void> respondToInteraction({
    required String messageId,
    required String userId,
    required String choiceId,
  }) async {
    await _cv.mutation('interactions:respond', {
      'messageId': messageId,
      'userId': userId,
      'choiceId': choiceId,
    });
  }

  /// Clears every answer this user holds on one interaction.
  ///
  /// Distinct from toggling a single choice off: a multiple-answer poll needs
  /// one control that means "retract my vote" rather than six taps.
  Future<void> retractInteraction({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('interactions:retract', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  /// Appends an item to a checklist. Refused by the server on the other two
  /// kinds, and on a list whose author switched shared adding off.
  Future<void> addChecklistItem({
    required String messageId,
    required String userId,
    required String label,
  }) async {
    await _cv.mutation('interactions:addItem', {
      'messageId': messageId,
      'userId': userId,
      'label': label,
    });
  }

  /// Removes an item, and whatever tick it was carrying. Author or room admin
  /// only — adding to a shared list is collaboration, deleting from one is
  /// editing what somebody else wrote.
  Future<void> removeChecklistItem({
    required String messageId,
    required String userId,
    required String choiceId,
  }) async {
    await _cv.mutation('interactions:removeItem', {
      'messageId': messageId,
      'userId': userId,
      'choiceId': choiceId,
    });
  }

  /// Ends an interaction. One-way: there is no reopen, because "final" is the
  /// only thing closing communicates.
  Future<void> closeInteraction({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('interactions:close', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  /// Who answered what, in full — the sheet behind the faces on a card.
  ///
  /// Throws `POLL_IS_ANONYMOUS` on an anonymous poll rather than returning an
  /// empty list, because an empty list is a claim ("nobody voted") and a
  /// refusal is the truth ("this poll does not say"). The caller never opens
  /// this on one, so reaching the throw means a stale screen.
  Future<List<InteractionRespondentDetail>> interactionRespondents({
    required String messageId,
    required String userId,
  }) async {
    final res = await _cv.query('interactions:respondents', {
      'messageId': messageId,
      'viewerUserId': userId,
    });
    return ((res as List?) ?? const [])
        .whereType<Map>()
        .map((e) =>
            InteractionRespondentDetail.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// State for interactions older than the room's live window.
  ///
  /// The paging counterpart to the `interactions:listForRoom` subscription:
  /// called with the ids a `listBefore` page just delivered, so a poll scrolled
  /// back to renders its tally rather than an empty card. A one-shot on
  /// purpose — the messages on that page are not live either, and a card that
  /// updated while the transcript around it did not would be the odd one out.
  Future<List<MessageInteraction>> interactionStateFor({
    required List<String> messageIds,
    required String userId,
  }) async {
    if (messageIds.isEmpty) return const [];
    final res = await _cv.query('interactions:stateForMessages', {
      'messageIds': messageIds,
      'viewerUserId': userId,
    });
    return ((res as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MessageInteraction.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pins
  // ─────────────────────────────────────────────────────────────────────────

  /// Neither of these takes a `roomId`: the server derives it from the message,
  /// so a pin naming a room its message doesn't live in cannot be expressed.
  Future<void> pinMessage({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('pins:pin', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  Future<void> unpinMessage({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('pins:unpin', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Saved messages (per-reader bookmarks)
  // ─────────────────────────────────────────────────────────────────────────

  /// Marks [messageId] as saved for [userId], where it is.
  ///
  /// Nothing to do with the `dm:self:` Saved Messages ROOM, which is reached by
  /// forwarding — see `bookmarks.ts`. Takes no `roomId` for the same reason the
  /// pins above don't: the server derives it from the message, so a bookmark
  /// naming a room its message doesn't live in cannot be expressed.
  ///
  /// There is no matching read method here on purpose. The list is a live
  /// subscription, and every live subscription in this app is registered by
  /// `ChatRepository` so the reconnect rebinding covers it.
  Future<void> saveMessage({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('bookmarks:save', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  /// Pins [subjectId] to a palette [slot] for [viewerId] in [roomId], or clears
  /// the pin when [slot] is null.
  ///
  /// Writes land in a table only [viewerId] reads (see `speakerColors.ts`), so
  /// this is one of the very few room-scoped mutations that costs the other
  /// members of the room precisely nothing.
  Future<void> setSpeakerSlot({
    required String viewerId,
    required String roomId,
    required String subjectId,
    required int? slot,
  }) async {
    await _cv.mutation('speakerColors:setSlot', {
      'viewerId': viewerId,
      'roomId': roomId,
      'subjectId': subjectId,
      'slot': slot,
    });
  }

  /// Drops every speaker-colour override [viewerId] holds in [roomId].
  Future<void> clearSpeakerSlots({
    required String viewerId,
    required String roomId,
  }) async {
    await _cv.mutation('speakerColors:clearRoom', {
      'viewerId': viewerId,
      'roomId': roomId,
    });
  }

  Future<void> unsaveMessage({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('bookmarks:unsave', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared content
  // ─────────────────────────────────────────────────────────────────────────

  /// One page of a room's attachments of one kind, newest first.
  ///
  /// Paged on `createdAt` like [listMessagesBefore] rather than an opaque
  /// cursor: pass the `createdAt` of the oldest row you hold as [before], or
  /// omit it for the first page.
  ///
  /// Unlike the transcript queries these are one-shot — the browser is not
  /// subscribed, which is why `roomContent` can afford a membership check that
  /// `pins:listForRoom` deliberately skips.
  Future<RoomContentPage> listRoomContent({
    required String roomId,
    required String userId,
    required String bucket,
    DateTime? before,
    int limit = 30,
  }) async {
    final res = await _cv.query('roomContent:listBucket', {
      'roomId': roomId,
      'userId': userId,
      'bucket': bucket,
      'beforeTimestamp': ?before?.millisecondsSinceEpoch,
      'limit': limit,
    });
    return _decodeContentPage(res);
  }

  /// One page of the room's messages that contain a URL, newest first.
  ///
  /// Returns whole messages, not links: the server records only that a message
  /// has one (see `messages.hasLink`), so the URLs are re-derived client-side
  /// with the same `UrlDetector` the bubbles linkify with.
  Future<RoomContentPage> listRoomLinks({
    required String roomId,
    required String userId,
    DateTime? before,
    int limit = 30,
  }) async {
    final res = await _cv.query('roomContent:listLinks', {
      'roomId': roomId,
      'userId': userId,
      'beforeTimestamp': ?before?.millisecondsSinceEpoch,
      'limit': limit,
    });
    return _decodeContentPage(res);
  }

  /// How much each tab holds, capped server-side — see [RoomContentCount].
  Future<Map<String, RoomContentCount>> roomContentCounts({
    required String roomId,
    required String userId,
  }) async {
    final res = await _cv.query('roomContent:counts', {
      'roomId': roomId,
      'userId': userId,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return {
      for (final e in map.entries)
        e.key: RoomContentCount.fromJson((e.value as Map).cast<String, dynamic>()),
    };
  }

  /// Re-sends [messageIds] into a single other room.
  ///
  /// One room per call because a Convex mutation is one transaction — see
  /// `messages:forwardToRoom`. Callers forwarding to several rooms issue
  /// several of these so one refusal doesn't roll back the rest.
  ///
  /// [clientIds] are per-message idempotency keys in the same order, so a retry
  /// after a dropped ack collapses onto the same rows rather than duplicating
  /// them.
  ///
  /// Throws `SOURCE_IS_EPHEMERAL` when forwarding out of a Chamber of Secrets
  /// room, which is refused outright: the target's lifetime is what would
  /// apply, so it would launder a self-destructing message into a permanent one.
  Future<({int forwarded, int refused})> forwardToRoom({
    required String sourceRoomId,
    required String targetRoomId,
    required String userId,
    required List<String> messageIds,
    List<String>? clientIds,
  }) async {
    final res = await _cv.mutation('messages:forwardToRoom', {
      'sourceRoomId': sourceRoomId,
      'targetRoomId': targetRoomId,
      'userId': userId,
      'messageIds': messageIds,
      'clientIds': ?clientIds,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      forwarded: (map['forwarded'] as num?)?.toInt() ?? 0,
      refused: (map['refused'] as num?)?.toInt() ?? 0,
    );
  }

  /// Deletes every message in [messageIds] the caller is entitled to delete.
  ///
  /// Partial success is the normal outcome, not an error: the server skips what
  /// the caller doesn't own rather than throwing, so a mixed selection removes
  /// what it can. `refused` is what the caller reports.
  Future<({int deleted, int refused})> deleteMessages({
    required String userId,
    required List<String> messageIds,
  }) async {
    final res = await _cv.mutation('messages:deleteMany', {
      'userId': userId,
      'messageIds': messageIds,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      deleted: (map['deleted'] as num?)?.toInt() ?? 0,
      refused: (map['refused'] as num?)?.toInt() ?? 0,
    );
  }

  RoomContentPage _decodeContentPage(dynamic res) {
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return RoomContentPage(
      items: _decodeMessages(map['items']),
      hasMore: (map['hasMore'] as bool?) ?? false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Typing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> setTyping({required String roomId, required String userId}) async {
    await _cv.mutation('typing:setTyping', {'roomId': roomId, 'userId': userId});
  }

  Future<void> clearTyping({required String roomId, required String userId}) async {
    await _cv.mutation('typing:clearTyping', {'roomId': roomId, 'userId': userId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Friends
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<ChatUser>> listFriends(String userId) async {
    final res = await _cv.query('friends:listFriends', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FriendRequest>> listIncomingDirectRequests(String userId) async {
    final res = await _cv.query('friends:listIncomingDirectRequests', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => FriendRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FriendRequest>> listOutgoingDirectRequests(String userId) async {
    final res = await _cv.query('friends:listOutgoingDirectRequests', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => FriendRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> createDirectRequest({
    required String userId,
    required String friendId,
    required RoomType roomType,
    Duration? messageLifetime,
    String? initialMessage,
  }) async {
    final res = await _cv.mutation('friends:createDirectRequest', {
      'userId': userId,
      'friendId': friendId,
      'roomType': roomType.displayLabel,
      'messageLifetime': ?messageLifetime?.inSeconds,
      'initialMessage': ?initialMessage,
    });
    return res.toString();
  }

  Future<void> appendDirectRequestMessage({
    required String requestId,
    required String userId,
    required String content,
  }) async {
    await _cv.mutation('friends:appendDirectRequestMessage', {
      'requestId': requestId,
      'userId': userId,
      'content': content,
    });
  }

  Future<List<FriendRequestMessage>> listDirectRequestMessages(String requestId) async {
    final res = await _cv.query('friends:listDirectRequestMessages', {'requestId': requestId});
    return ((res as List?) ?? const [])
        .map((e) => FriendRequestMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String?> approveDirectRequest({required String userId, required String requesterId}) async {
    final res = await _cv.mutation('friends:approveDirectRequest', {
      'userId': userId,
      'requesterId': requesterId,
    });
    return res?.toString();
  }

  Future<void> cancelDirectRequest({required String userId, required String friendId}) async {
    await _cv.mutation('friends:cancelDirectRequest', {'userId': userId, 'friendId': friendId});
  }

  Future<void> rejectDirectRequest({required String userId, required String requesterId}) async {
    await _cv.mutation('friends:rejectDirectRequest', {'userId': userId, 'requesterId': requesterId});
  }

  Future<void> removeFriend({required String userId, required String friendId}) async {
    await _cv.mutation('friends:removeFriend', {'userId': userId, 'friendId': friendId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Blocking + reporting
  // ─────────────────────────────────────────────────────────────────────────

  /// Block a user. When [deleteDm] is true, the shared DM room (if any) is
  /// wiped completely on the backend — every message, reaction, media file,
  /// and both memberships go. Group rooms are not touched.
  Future<void> blockUser({
    required String userId,
    required String targetUserId,
    bool deleteDm = false,
  }) async {
    await _cv.mutation('users:blockUser', {
      'userId': userId,
      'targetUserId': targetUserId,
      if (deleteDm) 'deleteDm': true,
    });
  }

  Future<void> unblockUser({required String userId, required String targetUserId}) async {
    await _cv.mutation('users:unblockUser', {
      'userId': userId,
      'targetUserId': targetUserId,
    });
  }

  Future<List<ChatUser>> listBlocked(String userId) async {
    final res = await _cv.query('users:listBlocked', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Returns rooms BOTH users belong to, split into group rooms and a
  /// DM-present flag. Used by the block confirm sheet.
  Future<SharedRoomsInfo> listSharedRooms({
    required String userId,
    required String otherUserId,
  }) async {
    final res = await _cv.query('rooms:listShared', {
      'userId': userId,
      'otherUserId': otherUserId,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (map['groupRooms'] as List?) ?? const [];
    final rooms = list
        .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return SharedRoomsInfo(
      groupRooms: rooms,
      hasDm: (map['hasDm'] as bool?) ?? false,
    );
  }

  Future<bool> isBlocked({required String userId, required String otherUserId}) async {
    final res = await _cv.query('users:isBlocked', {
      'userId': userId,
      'otherUserId': otherUserId,
    });
    return (res as bool?) ?? false;
  }

  /// Submit a report against a user / message / room.
  /// `targetType` ∈ {"user", "message", "room"}.
  ///
  /// The server posts it, with the reported message and the last few messages
  /// of the conversation, to the moderators' room — what the report sheet
  /// tells the user before they send. [alsoBlock] blocks the person in the
  /// same call. Returns whether a block was written.
  Future<bool> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
    bool alsoBlock = false,
  }) async {
    final res = await _cv.mutation('users:report', {
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
      if (alsoBlock) 'alsoBlock': true,
    });
    return res is Map && res['blocked'] == true;
  }

  /// A moderator's action on a report card. [action] is one of
  /// `removeMessage`, `ban`, `unban`, `dismiss`. Staff only: the server checks
  /// the caller against its staff list and throws `NOT_AUTHORIZED` otherwise.
  Future<void> moderationAct({
    required String reportId,
    required String action,
  }) async {
    await _cv.mutation('moderation:act', {
      'reportId': reportId,
      'action': action,
    });
  }

  /// Whether this account has accepted the current Terms of Use (EULA).
  /// Null when the server could not say (offline, or a backend too old to
  /// know): the acceptance sheet only blocks on a definite "no".
  Future<bool?> termsAccepted() async {
    try {
      final res = await _cv.query('terms:status', const {});
      if (res is! Map) return null;
      return res['accepted'] == true;
    } catch (_) {
      return null;
    }
  }

  /// Records acceptance of [kTermsVersion].
  Future<void> acceptTerms() async {
    await _cv.mutation('terms:accept', {'version': kTermsVersion});
  }

  Future<List<ChatUser>> searchUsers({required String query, required String currentUserId}) async {
    final res = await _cv.query('users:searchUsers', {
      'query': query,
      'currentUserId': currentUserId,
    });
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Family
  // ─────────────────────────────────────────────────────────────────────────

  /// Am I a child, what may I do, who's in my family, and how much is waiting
  /// on me. One call — the client leans on this to decide what to render.
  Future<FamilyContext?> getFamilyContext(String userId) async {
    final res = await _cv.query('family:getFamilyContext', {'userId': userId});
    if (res == null) return null;
    return FamilyContext.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Live version of [getFamilyContext]. A guardian tightening or loosening a
  /// rule reaches the child's phone over the socket that's already open, so
  /// the child doesn't have to restart the app to lose (or gain) a tab.
  Future<Subscription> subscribeFamilyContext({
    required String userId,
    required void Function(FamilyContext? context) onContext,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'family:getFamilyContext',
      {'userId': userId},
      onData: (raw) {
        if (raw == null) {
          onContext(null);
          return;
        }
        onContext(FamilyContext.fromJson((raw as Map).cast<String, dynamic>()));
      },
      onError: onError,
    );
  }

  Future<AuthResult> createChildAccount({
    required String guardianId,
    required String username,
    required String name,
    int? birthYear,
  }) async {
    final res = await _cv.mutation('family:createChildAccount', {
      'guardianId': guardianId,
      'username': username,
      'name': name,
      'birthYear': ?birthYear,
    });
    return AuthResult.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> addGuardian({
    required String guardianId,
    required String childId,
    required String newGuardianUsername,
  }) async {
    await _cv.mutation('family:addGuardian', {
      'guardianId': guardianId,
      'childId': childId,
      'newGuardianUsername': newGuardianUsername,
    });
  }

  /// Registers a pairing code for a child device. [code] is generated on this
  /// device and shown to the user; only its hash crosses the wire, exactly as
  /// passwords do. Returns when the code expires.
  Future<DateTime> createPairingCode({
    required String guardianId,
    required String childId,
    required String code,
  }) async {
    final res = await _cv.mutation('family:createPairingCode', {
      'guardianId': guardianId,
      'childId': childId,
      'codeHash': sha256Hash(code),
    });
    final map = (res as Map).cast<String, dynamic>();
    return DateTime.fromMillisecondsSinceEpoch(
      ((map['expiresAt'] ?? 0) as num).toInt(),
    );
  }

  Future<void> revokePairingCode({
    required String guardianId,
    required String childId,
  }) async {
    await _cv.mutation('family:revokePairingCode', {
      'guardianId': guardianId,
      'childId': childId,
    });
  }

  /// Mints the code that hands a child's phone back. Same shape as
  /// [createPairingCode] — only the hash crosses the wire — but a different
  /// table server-side, so a release code can never be redeemed as a sign-in.
  Future<DateTime> createReleaseCode({
    required String guardianId,
    required String childId,
    required String code,
  }) async {
    final res = await _cv.mutation('family:createReleaseCode', {
      'guardianId': guardianId,
      'childId': childId,
      'codeHash': sha256Hash(code),
    });
    final map = (res as Map).cast<String, dynamic>();
    return DateTime.fromMillisecondsSinceEpoch(
      ((map['expiresAt'] ?? 0) as num).toInt(),
    );
  }

  /// Releases this handset with a guardian's six-digit code. Single-use.
  Future<void> releaseDeviceByCode({
    required String code,
    required String deviceId,
  }) async {
    await _cv.mutation('family:releaseDeviceByCode', {
      'codeHash': sha256Hash(code),
      'deviceId': deviceId,
    });
  }

  /// Releases this handset with a guardian's own password — the path that
  /// works when there's only one phone and no adult session to mint a code.
  /// Every failure comes back as the same error by design.
  Future<void> releaseDeviceByGuardianPassword({
    required String childId,
    required String guardianUsername,
    required String password,
    required String deviceId,
  }) async {
    await _cv.mutation('family:releaseDeviceByGuardianPassword', {
      'childId': childId,
      'guardianUsername': guardianUsername,
      'passwordHash': sha256Hash(password),
      'deviceId': deviceId,
    });
  }

  /// Trades a pairing code for a session on the child's device. Single-use —
  /// a second attempt with the same code fails with PAIRING_CODE_INVALID.
  Future<AuthResult> redeemPairingCode({
    required String code,
    required String deviceId,
    required String platform,
    String? deviceName,
  }) async {
    final res = await _cv.mutation('family:redeemPairingCode', {
      'codeHash': sha256Hash(code),
      'deviceId': deviceId,
      'platform': platform,
      'deviceName': ?deviceName,
    });
    return AuthResult.fromJson((res as Map).cast<String, dynamic>());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Device login — QR / short-code sign-in for a signed-out web or desktop
  // client, approved from an already-signed-in phone. Mirrors the pairing-
  // code shape above (mint, hash, single-use, short TTL) but lives in its own
  // backend table — see `deviceLoginRequests` in schema.ts.
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts a request. Called once, on the desktop/web login screen mounting,
  /// before anyone is signed in — there is no identity to attach yet.
  /// [code] is generated by the caller the same way a pairing code is; only
  /// its hash crosses the wire.
  Future<DeviceLoginRequest> createDeviceLoginRequest({
    required String deviceInfo,
  }) async {
    final res = await _cv.mutation('deviceLogin:createLoginRequest', {
      'deviceInfo': deviceInfo,
    });
    final map = (res as Map).cast<String, dynamic>();
    return DeviceLoginRequest(
      requestId: map['requestId'] as String,
      code: map['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['expiresAt'] ?? 0) as num).toInt(),
      ),
    );
  }

  /// Live status of [requestId] — subscribes rather than polling, so the
  /// desktop/web client's UI updates the instant the phone decides. See
  /// `ChatRepository`'s subscriptions for the same pattern elsewhere in this
  /// app.
  Future<Subscription> subscribeDeviceLoginStatus({
    required String requestId,
    required void Function(String status) onStatus,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'deviceLogin:getDeviceLoginRequestStatus',
      {'requestId': requestId},
      onData: (data) {
        final map = (data as Map?)?.cast<String, dynamic>();
        onStatus((map?['status'] as String?) ?? 'invalid');
      },
      onError: onError,
    );
  }

  /// Trades an APPROVED request for the session it names. Call this the
  /// instant [subscribeDeviceLoginStatus] reports `'approved'` — never
  /// before, and never off the strength of that status alone without also
  /// handling this throwing (the approval and the exchange are deliberately
  /// two separate calls; see the schema comment on why).
  Future<AuthResult> exchangeDeviceLoginRequest(String requestId) async {
    final res = await _cv.mutation('deviceLogin:exchangeDeviceLoginRequest', {
      // The desktop claiming the session names itself, so the new sign-in
      // shows up in the Devices list as this machine.
      'deviceId': await DeviceIdentity.ensure(),
      'requestId': requestId,
    });
    return AuthResult.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Phone-side peek at what's asking to sign in, before the confirmation
  /// screen offers APPROVE/DENY. Exactly one of [requestId] (from a scanned
  /// QR) or [code] (typed by hand) must be set.
  Future<String> peekDeviceLoginRequest({
    required String callerId,
    String? requestId,
    String? code,
  }) async {
    final res = await _cv.mutation('deviceLogin:peekDeviceLoginRequest', {
      'callerId': callerId,
      'requestId': ?requestId,
      'codeHash': ?(code == null ? null : sha256Hash(code)),
    });
    final map = (res as Map).cast<String, dynamic>();
    return map['deviceInfo'] as String;
  }

  /// Approves or denies a request from the phone, authenticated as
  /// [callerId] — the session it mints belongs to whoever calls this, never
  /// to whoever merely created the request. Same [requestId]/[code] contract
  /// as [peekDeviceLoginRequest].
  Future<void> respondToDeviceLoginRequest({
    required String callerId,
    required bool approve,
    String? requestId,
    String? code,
  }) async {
    await _cv.mutation('deviceLogin:respondToDeviceLoginRequest', {
      'callerId': callerId,
      'approve': approve,
      'requestId': ?requestId,
      'codeHash': ?(code == null ? null : sha256Hash(code)),
    });
  }

  /// Everything waiting on this guardian, across all their children.
  Future<List<QueueItem>> listGuardianQueue(String guardianId) async {
    final res = await _cv.query('family:listGuardianQueue', {
      'guardianId': guardianId,
    });
    return ((res as List?) ?? const [])
        .map((e) => QueueItem.fromJson((e as Map).cast<String, dynamic>()))
        .whereType<QueueItem>()
        .toList();
  }

  /// Live version of [listGuardianQueue].
  ///
  /// The approvals screen used to read the queue exactly once, on open. A
  /// request arriving while a parent had the screen up simply did not appear,
  /// and neither did one a co-parent had just decided from their own phone —
  /// the parent was looking at a list that had stopped being true. Everything
  /// the queue is built from is a live Convex subscription already; this just
  /// stops throwing that away.
  Future<Subscription> subscribeGuardianQueue({
    required String guardianId,
    required void Function(List<QueueItem> items) onItems,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'family:listGuardianQueue',
      {'guardianId': guardianId},
      onData: (raw) {
        onItems(
          ((raw as List?) ?? const [])
              .map((e) => QueueItem.fromJson((e as Map).cast<String, dynamic>()))
              .whereType<QueueItem>()
              .toList(),
        );
      },
      onError: onError,
    );
  }

  /// The guardian's own group rooms that this child is not already in.
  Future<List<RoomBrief>> grantableRooms({
    required String guardianId,
    required String childId,
  }) async {
    final res = await _cv.query('family:grantableRooms', {
      'guardianId': guardianId,
      'childId': childId,
    });
    return ((res as List?) ?? const [])
        .map((e) => RoomBrief.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Puts the child in one of the guardian's own rooms and records the grant,
  /// so the child settings screen can take it back later like any other.
  Future<void> grantRoomToChild({
    required String guardianId,
    required String childId,
    required String roomId,
  }) async {
    await _cv.mutation('family:grantRoomToChild', {
      'guardianId': guardianId,
      'childId': childId,
      'roomId': roomId,
    });
  }

  /// Moves a contact request one hop along the guardian relay, or kills it.
  /// Used for both [QueueItemType.contactOutgoing] and `contactIncoming`.
  Future<void> advanceContactRequest({
    required String friendshipId,
    required String guardianId,
    required bool approve,
  }) async {
    await _cv.mutation('family:advanceContactRequest', {
      'friendshipId': friendshipId,
      'guardianId': guardianId,
      'approve': approve,
    });
  }

  /// Raises a "can I join this room?" with the child's guardians.
  Future<String> requestApproval({
    required String childId,
    required String kind,
    String? targetRoomId,
    String? note,
  }) async {
    final res = await _cv.mutation('family:requestApproval', {
      'childId': childId,
      'kind': kind,
      'targetRoomId': ?targetRoomId,
      'note': ?note,
    });
    return res.toString();
  }

  /// Approving also performs the join, so the child doesn't have to re-tap.
  Future<String?> decideApproval({
    required String approvalId,
    required String guardianId,
    required bool approve,
  }) async {
    final res = await _cv.mutation('family:decideApproval', {
      'approvalId': approvalId,
      'guardianId': guardianId,
      'approve': approve,
    });
    return res?.toString();
  }

  Future<void> revokeApproval({
    required String guardianId,
    required String approvalId,
  }) async {
    await _cv.mutation('family:revokeApproval', {
      'guardianId': guardianId,
      'approvalId': approvalId,
    });
  }

  /// Whitelists [username] for a child: a standing pre-approval that skips
  /// this guardian's hop in the relay from now on, in both directions. Not a
  /// friendship — the other person still has to accept.
  ///
  /// With [sendRequestNow] the request is also fired on the child's behalf,
  /// entering the relay at whatever hop the pre-approval just unlocked.
  /// Returns whether a request actually went out (false when they were
  /// already connected, or one was already in flight).
  Future<bool> allowContactByUsername({
    required String guardianId,
    required String childId,
    required String username,
    bool sendRequestNow = false,
  }) async {
    final res = await _cv.mutation('family:allowContactByUsername', {
      'guardianId': guardianId,
      'childId': childId,
      'username': username,
      if (sendRequestNow) 'sendRequestNow': true,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (map['requested'] as bool?) ?? false;
  }

  /// Links up a family created before auto-friending existed. Idempotent —
  /// safe to call on every family-screen load.
  Future<void> backfillFamilyFriendships(String guardianId) async {
    await _cv.mutation('family:backfillFamilyFriendships', {
      'guardianId': guardianId,
    });
  }

  /// What removing this contact would destroy. Call before confirming — the
  /// removal itself is unconditional and total.
  Future<ContactRemovalPreview> previewContactRemoval({
    required String guardianId,
    required String childId,
    required String contactUserId,
  }) async {
    final res = await _cv.query('family:previewContactRemoval', {
      'guardianId': guardianId,
      'childId': childId,
      'contactUserId': contactUserId,
    });
    return ContactRemovalPreview.fromJson(
      (res as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Severs the contact AND wipes every DM the pair share — messages,
  /// reactions, and media, for both of them. Not reversible.
  Future<void> revokeContact({
    required String guardianId,
    required String childId,
    required String contactUserId,
  }) async {
    await _cv.mutation('family:revokeContact', {
      'guardianId': guardianId,
      'childId': childId,
      'contactUserId': contactUserId,
    });
  }

  Future<List<PendingApproval>> listMyApprovals(String childId) async {
    final res = await _cv.query('family:listMyApprovals', {'childId': childId});
    return ((res as List?) ?? const [])
        .map((e) => PendingApproval.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<ChildGrants> listChildGrants({
    required String guardianId,
    required String childId,
  }) async {
    final res = await _cv.query('family:listChildGrants', {
      'guardianId': guardianId,
      'childId': childId,
    });
    return ChildGrants.fromJson(
      (res as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Only the flags you pass are touched.
  ///
  /// There is no `publicRoomsEnabled`. Discover is off for every child with no
  /// guardian override, and the backend rejects the argument outright rather
  /// than accepting and ignoring it.
  Future<ChildPolicy> setChildPolicy({
    required String guardianId,
    required String childId,
    bool? callsEnabled,
    bool? mediaEnabled,
    /// Static and live location shares. Separate from [mediaEnabled] on
    /// purpose — see `LOCATION_POLICY_FLAG` in backend/convex/childGuard.ts.
    bool? locationSharingEnabled,
    bool? canRequestContacts,
    bool? canCreateRooms,
  }) async {
    final res = await _cv.mutation('family:setChildPolicy', {
      'guardianId': guardianId,
      'childId': childId,
      'callsEnabled': ?callsEnabled,
      'mediaEnabled': ?mediaEnabled,
      'locationSharingEnabled': ?locationSharingEnabled,
      'canRequestContacts': ?canRequestContacts,
      'canCreateRooms': ?canCreateRooms,
    });
    return ChildPolicy.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> unlinkChild({
    required String guardianId,
    required String childId,
  }) async {
    await _cv.mutation('family:unlinkChild', {
      'guardianId': guardianId,
      'childId': childId,
    });
  }

  Future<void> promoteToAdult({
    required String guardianId,
    required String childId,
    required String password,
  }) async {
    await _cv.mutation('family:promoteToAdult', {
      'guardianId': guardianId,
      'childId': childId,
      'passwordHash': sha256Hash(password),
    });
  }

  Future<void> deleteChildAccount({
    required String guardianId,
    required String childId,
  }) async {
    await _cv.mutation('family:deleteChildAccount', {
      'guardianId': guardianId,
      'childId': childId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Files
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> generateUploadUrl() async {
    final res = await _cv.mutation('files:generateUploadUrl', const {});
    return res.toString();
  }

  /// The serving URL for [storageId], or null when there isn't one.
  ///
  /// Nullable because the backend query is: `files:getFileUrl` returns null for
  /// a view-once file and for an id whose blob has been swept. This used to be
  /// a bare `res.toString()`, and `null.toString()` is the four-character
  /// string "null" — which every caller then treated as a URL, handed to a
  /// player or an image loader, and persisted in [FileUrlCache] for the life of
  /// the install.
  Future<String?> getFileUrl(String storageId) async {
    final res = await _cv.query('files:getFileUrl', {'storageId': storageId});
    if (res == null) return null;
    final url = res.toString();
    return url.isEmpty ? null : url;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GIFs and stickers — see backend/convex/expressions.ts
  // ─────────────────────────────────────────────────────────────────────────

  /// KLIPY's app key and whether ads are on, or a null key where this server
  /// has no GIF search configured.
  Future<({String? klipyAppKey, bool klipyAds})> expressionsConfig() async {
    final res = await _cv.query('expressions:config', const {});
    final m = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      klipyAppKey: m['klipyAppKey'] as String?,
      klipyAds: m['klipyAds'] == true,
    );
  }

  /// Every sticker pack the viewer can pick from, live — a new personal
  /// sticker made on another device appears here without a refresh.
  Future<Subscription> subscribeStickerPacks({
    required void Function(List<StickerPack> packs) onPacks,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'expressions:packs',
      const {},
      onData: (raw) => onPacks([
        for (final p in (raw as List? ?? const []))
          StickerPack.fromJson((p as Map).cast<String, dynamic>()),
      ]),
      onError: onError,
    );
  }

  /// The viewer's recent and starred GIFs/stickers, and the official packs
  /// they have added to their strip (in their order), live across devices.
  Future<Subscription> subscribeExpressionState({
    required void Function(List<ExpressionItem> recents,
            List<ExpressionItem> favorites, List<String> installedPackIds)
        onState,
    void Function(Object error)? onError,
  }) {
    List<ExpressionItem> parse(Object? list) => [
          for (final r in (list as List? ?? const []))
            ?ExpressionItem.fromRefJson((r as Map).cast<String, dynamic>()),
        ];
    return _cv.subscribe(
      'expressions:state',
      const {},
      onData: (raw) {
        final m = (raw as Map?)?.cast<String, dynamic>() ?? const {};
        onState(
          parse(m['recents']),
          parse(m['favorites']),
          [
            for (final id in (m['installedPackIds'] as List? ?? const []))
              id.toString(),
          ],
        );
      },
      onError: onError,
    );
  }

  /// Adds an official pack to the viewer's strip, or takes it off.
  Future<void> setStickerPackInstalled(String packId, bool installed) async {
    await _cv.mutation('expressions:setPackInstalled',
        {'packId': packId, 'installed': installed});
  }

  /// Puts the viewer's added packs in [packIds]' order.
  Future<void> reorderStickerPacks(List<String> packIds) async {
    await _cv.mutation('expressions:reorderPacks', {'packIds': packIds});
  }

  Future<void> recordExpressionUse(ExpressionItem item) async {
    await _cv.mutation('expressions:recordUse', {'ref': item.toRefJson()});
  }

  /// Returns whether [item] is starred now.
  Future<bool> toggleExpressionFavorite(ExpressionItem item) async {
    final res = await _cv
        .mutation('expressions:toggleFavorite', {'ref': item.toRefJson()});
    return res == true;
  }

  Future<void> forgetRecentExpression(ExpressionItem item) async {
    await _cv.mutation('expressions:forgetRecent', {'ref': item.toRefJson()});
  }

  /// Files an uploaded, already-cut-out image as one of the viewer's stickers.
  Future<String> createPersonalSticker({
    required String storageId,
    required String emoji,
    required double width,
    required double height,
  }) async {
    final res = await _cv.mutation('expressions:createPersonalSticker', {
      'storageId': storageId,
      'emoji': emoji,
      'width': width,
      'height': height,
    });
    return res.toString();
  }

  Future<void> deletePersonalSticker(String stickerId) async {
    await _cv.mutation(
        'expressions:deletePersonalSticker', {'stickerId': stickerId});
  }

  // No deleteFile: freeing a stored file is the server's job, done in the same
  // mutation that drops the reference (users:updateAvatar, rooms:deleteRoom,
  // messages:deleteMessage, …). The old `files:deleteFile` endpoint let any
  // client delete any file given its id, and nothing ever called it.

  // ─────────────────────────────────────────────────────────────────────────
  // Problem reports
  // ─────────────────────────────────────────────────────────────────────────

  /// Files a problem report. See `backend/convex/problemReports.ts` for where it
  /// lands and why.
  ///
  /// Throws whatever the mutation threw — `TOO_MANY_REPORTS` when the device has
  /// spent its hourly budget, `REPORT_INBOX_MISSING` if the deployment has no
  /// maintainer account. The screen distinguishes the first and treats the rest
  /// as a generic failure, because the rest are ours to fix, not the user's.
  Future<void> submitProblemReport({
    required String deviceId,
    String? reporterId,
    required String body,
    String? logStorageId,
    String? logFileName,
    int? logFileSize,
    List<String> screenshots = const [],
  }) async {
    await _cv.mutation('problemReports:submit', {
      'deviceId': deviceId,
      // Omitted rather than sent as null: every one of these is `v.optional`
      // server-side, and Convex rejects an explicit null against an optional
      // validator.
      'reporterId': ?reporterId,
      'body': body,
      'logStorageId': ?logStorageId,
      'logFileName': ?logFileName,
      'logFileSize': ?logFileSize,
      if (screenshots.isNotEmpty) 'screenshots': screenshots,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  List<ChatRoom> _decodeRooms(dynamic res) {
    return ((res as List?) ?? const [])
        .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<ChatMessage> _decodeMessages(dynamic res) {
    return ((res as List?) ?? const [])
        .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

}

class SharedRoomsInfo {
  SharedRoomsInfo({required this.groupRooms, required this.hasDm});
  final List<ChatRoom> groupRooms;
  final bool hasDm;
}

/// One answer from `users:isUsernameAvailable`.
///
/// [reason] is `"invalid"`, `"reserved"` or `"taken"` when [available] is false,
/// and null when it is true. Kept as the server's own strings rather than an
/// enum parsed here: an older client meeting a reason it does not know should
/// fall back to a generic "not available", not crash on a name it could have
/// simply refused.
class UsernameAvailability {
  const UsernameAvailability({required this.available, this.reason});

  final bool available;
  final String? reason;
}

class AuthResult {
  AuthResult({
    required this.userId,
    required this.username,
    required this.name,
    required this.token,
  });
  final String userId;
  final String username;
  final String name;

  /// The bearer token, returned exactly once — at mint. It is not recoverable
  /// from the server afterwards (only its hash is stored), so a caller that
  /// drops it has signed the user in and immediately lost the session.
  final String token;
  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        userId: (j['userId']).toString(),
        username: (j['username']).toString(),
        name: (j['name']).toString(),
        token: (j['token'] ?? '').toString(),
      );
}

/// What `deviceLogin:createLoginRequest` hands back: the id that goes into
/// the QR (and is subscribed on for status), the six-digit fallback code to
/// show, and when both die. The server mints the code: one chosen here could
/// be pre-registered by somebody else, and the phone would approve theirs.
class DeviceLoginRequest {
  DeviceLoginRequest({
    required this.requestId,
    required this.code,
    required this.expiresAt,
  });
  final String requestId;
  final String code;
  final DateTime expiresAt;
}

/// What `socialAuth:signIn` came back with.
///
/// Two outcomes, because Apple and Google give us a subject and maybe an email,
/// but this app's public identity is a user-chosen username — so a first-time
/// social sign-in has to stop and ask for one.
class SocialSignInOutcome {
  const SocialSignInOutcome._({this.result, this.suggestedName, this.email});

  /// Present exactly when this identity already had an account.
  final AuthResult? result;

  /// Prefill for the username step. Apple supplies a name only on the very
  /// first authorization for an Apple ID, so this is frequently null even when
  /// the account is genuinely new.
  final String? suggestedName;
  final String? email;

  factory SocialSignInOutcome.signedIn(AuthResult result) =>
      SocialSignInOutcome._(result: result);

  factory SocialSignInOutcome.needsUsername({
    String? suggestedName,
    String? email,
  }) =>
      SocialSignInOutcome._(suggestedName: suggestedName, email: email);

  bool get needsUsername => result == null;
}
