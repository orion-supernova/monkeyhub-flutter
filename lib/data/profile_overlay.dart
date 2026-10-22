import 'package:flutter/widgets.dart';

import '../models/chat_user.dart';
import 'profile_scope.dart';

/// A [ChatUser] for [userId] whose name, handle and face come from the profile
/// cache, with the given copies as the fallback.
///
/// For the synthetic users moment and reaction screens build from copies
/// stored on a row. The server's avatar rule is already applied in the cached
/// profile, so a known profile's face wins; the copy is used only when no
/// profile is known. A tombstone never shows the copied face.
ChatUser profileUser(
  BuildContext context, {
  required String userId,
  required String name,
  String? username,
  String? avatarStorageId,
  String? status,
  DateTime? lastSeen,
}) {
  final deleted = ProfileScope.maybeOf(context)?.isDeleted(userId) ?? false;
  final shownName = context.profileName(userId, fallback: name);
  return ChatUser(
    id: userId,
    username:
        deleted ? '' : context.profileUsername(userId, fallback: username ?? name),
    name: shownName,
    avatarStorageId:
        deleted ? null : context.profileAvatar(userId, fallback: avatarStorageId),
    status: status,
    lastSeen: lastSeen,
  );
}

/// [profileUser] over an existing [ChatUser].
ChatUser overlayProfile(BuildContext context, ChatUser u) => profileUser(
      context,
      userId: u.id,
      name: u.displayName,
      username: u.username,
      avatarStorageId: u.avatarStorageId,
      status: u.status,
      lastSeen: u.lastSeen,
    );
