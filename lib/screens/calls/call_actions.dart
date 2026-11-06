import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/server_limits.dart';
import '../../calls/call_models.dart';
import '../../calls/call_service.dart';
import '../../calls/group_call_service.dart';
import '../../calls/live_calls_store.dart';
import '../../family/family_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../widgets/app_toast.dart';
import 'call_log_models.dart';
import 'calls_directory.dart';

/// Starting a call from the Calls tab, by whichever surface asked: a swipe, the
/// hold menu, the details sheet, a favourite's chooser, the new-call picker.
/// One place, so every surface refuses a second call, explains why, and
/// reports a failure the same way the chat header's buttons do.

String _error(BuildContext context, Object e) {
  final l10n = AppLocalizations.of(context);
  final limit = serverLimitMessage(e, l10n);
  if (limit != null) return limit;
  final s = e.toString();
  if (s.contains('BUSY')) return l10n.callButtonErrorBusy;
  if (s.contains('CALL_FAILED')) return l10n.callButtonErrorCallFailed;
  if (s.contains('NOT_A_MEMBER')) return l10n.callButtonErrorNotMember;
  return l10n.callButtonErrorGeneric;
}

/// Why a new call cannot start right now, or null.
String? _busy(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final direct = CallService.maybeInstance;
  final group = GroupCallService.maybeInstance;
  if ((direct?.inCall ?? false) || (group?.inCall ?? false)) {
    return l10n.callButtonAlreadyOnCall;
  }
  if (direct?.busyElsewhere ?? false) return l10n.callButtonBusyElsewhere;
  return null;
}

/// A 1:1 call to [peer] in their DM [roomId].
Future<void> startDirectCall(
  BuildContext context, {
  required ChatUser peer,
  required String roomId,
  required CallMediaKind kind,
}) async {
  if (FamilyService.maybeInstance?.canCall == false) return;
  final service = CallService.maybeInstance;
  if (service == null) return;
  final busy = _busy(context);
  if (busy != null) {
    showAppToast(context, busy, duration: const Duration(seconds: 3));
    return;
  }
  HapticFeedback.mediumImpact();
  try {
    await service.initiate(
      peerUserId: peer.id,
      peerName: peer.displayName,
      roomId: roomId,
      kind: kind,
      peerAvatarStorageId: peer.avatarStorageId,
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppToast(context, _error(context, e), duration: const Duration(seconds: 3));
  }
}

/// Calls back what [entry] was: the same person (direct) or the same room
/// (group, huddle). A call still live in a group room is joined rather than
/// started again.
Future<void> callBack(
  BuildContext context, {
  required CallsDirectory directory,
  required CallLogEntry entry,
  required CallMediaKind kind,
}) async {
  if (FamilyService.maybeInstance?.canCall == false) return;
  if (entry.kind == CallLogKind.direct) {
    final peerId = entry.peerId;
    final peer = peerId == null ? null : directory.user(peerId);
    if (peer == null) {
      // Not a friend we hold: the chat is still the way in.
      directory.openChat(context, entry.roomId);
      return;
    }
    await startDirectCall(context, peer: peer, roomId: entry.roomId, kind: kind);
    return;
  }
  final group = GroupCallService.maybeInstance;
  if (group == null) return;
  final busy = _busy(context);
  if (busy != null) {
    showAppToast(context, busy, duration: const Duration(seconds: 3));
    return;
  }
  HapticFeedback.mediumImpact();
  try {
    final live = LiveCallsStore.instance.forRoom(entry.roomId);
    final liveId = live?.groupCallId;
    if (liveId != null) {
      await group.joinCall(liveId);
    } else if (entry.kind == CallLogKind.huddle && kind == CallMediaKind.audio) {
      await group.startHuddle(roomId: entry.roomId);
    } else {
      await group.startCall(roomId: entry.roomId, kind: kind);
    }
  } catch (e) {
    if (!context.mounted) return;
    showAppToast(context, _error(context, e), duration: const Duration(seconds: 3));
  }
}

/// Joins the group call going on in a live-strip tile.
Future<void> joinLiveCall(BuildContext context, LiveRoomCall call) async {
  final svc = GroupCallService.maybeInstance;
  final id = call.groupCallId;
  if (svc == null || id == null) return;
  final busy = _busy(context);
  if (busy != null) {
    showAppToast(context, busy, duration: const Duration(seconds: 3));
    return;
  }
  HapticFeedback.mediumImpact();
  try {
    await svc.joinCall(id);
  } catch (e) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final msg = e.toString().contains('CALL_FULL')
        ? l10n.groupCallBannerCallFullError
        : friendlyServerError(e, l10n, l10n.groupCallBannerJoinFailedError);
    showAppToast(context, msg);
  }
}
