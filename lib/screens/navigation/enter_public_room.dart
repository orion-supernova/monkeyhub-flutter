import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../family/family_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_room.dart';
import '../../models/family.dart';
import '../../widgets/approval_gate.dart';
import '../../widgets/join_room_sheet.dart';
import 'open_room.dart';

/// The one way into a public room you are not yet in.
///
/// Extracted because there were two: Discover ran the full flow — child
/// approval gate, then preview/password sheet, then join — while the room
/// results in `SearchScreen` went straight to the join sheet. The server gate
/// still refused the child, so nothing unsafe got through, but the child was
/// told "couldn't join — try again" and **no approval request was ever filed**,
/// leaving them tapping a room they could never open and with no way to ask.
///
/// Both entry points now call this.
Future<void> enterPublicRoom(
  BuildContext context, {
  required ChatRoom room,
  required ChatRepository repo,
  required ChatApi api,

  /// Nullable to match `FamilyService.maybeInstance`, which is how widgets deep
  /// in the tree reach it. Null means "no restrictions known" — treated as an
  /// adult, matching the permissive fallbacks elsewhere.
  required FamilyService? family,

  /// Whether this child has already raised this room with their guardians.
  bool alreadyAsked = false,

  /// Called with the room id when a fresh approval request is filed, so the
  /// caller can grow its "waiting for a grown-up" set.
  ValueChanged<String>? onAsked,

  /// Called when the server rejects a join on child-gate grounds, so the caller
  /// can re-read `listMyApprovals` — a grant may have been revoked mid-session.
  VoidCallback? onChildGateRefused,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  // Already a member — just open it. Everything below is the flow for *getting*
  // into a room; running any of it against one you're already in is the bug
  // this guard prevents: an approval gate for access you have, then a sheet
  // re-asking for a password you've cleared, then a join the backend no-ops.
  if (repo.isJoined(room)) {
    openRoom(context, roomId: room.id, repo: repo, api: api);
    return;
  }

  // Child gate first: no point previewing a room they can't enter yet.
  if (family?.isChild == true) {
    final uid = repo.userId;
    if (uid == null) return;

    final wantsToAsk = await showApprovalGate(
      context,
      what: AppLocalizations.of(context).enterPublicRoomJoinWhat(room.name),
      detail: room.description,
      alreadyAsked: alreadyAsked,
    );
    // Both halves are load-bearing. `alreadyAsked` suppresses a SECOND request
    // even when the gate returns true, which is what stops a child re-tapping a
    // room from spamming their guardian's pending queue.
    if (!wantsToAsk || alreadyAsked) return;

    try {
      await api.requestApproval(
        childId: uid,
        kind: 'joinRoom',
        targetRoomId: room.id,
      );
      onAsked?.call(room.id);
    } catch (_) {
      // Its own message: "couldn't join" would be the wrong verb for an action
      // they cannot perform in the first place.
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).enterPublicRoomAskFailedMessage,
          ),
        ),
      );
    }
    // A child never proceeds to the join itself — the grown-up's answer is what
    // puts them in the room.
    return;
  }

  if (!context.mounted) return;
  // Preview + confirm before joining; a locked room's password field lives
  // inside this same sheet.
  final result = await showJoinRoomSheet(context, room, api);
  if (result == null) return;
  try {
    await repo.joinRoom(roomId: room.id, password: result.password);
    if (!context.mounted) return;
    openRoom(context, roomId: room.id, repo: repo, api: api);
  } catch (e) {
    // Reachable even for an adult-shaped caller if a grant was revoked between
    // listing and tapping.
    if (isChildGateError(e)) {
      onChildGateRefused?.call();
      return;
    }
    if (!context.mounted) return;
    final loc = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.toString().contains('WRONG_PASSWORD')
              ? loc.enterPublicRoomWrongPasswordMessage
              : loc.enterPublicRoomJoinFailedMessage,
        ),
      ),
    );
  }
}
