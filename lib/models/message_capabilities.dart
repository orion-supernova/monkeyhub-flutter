import 'package:flutter/foundation.dart';

import 'chat_message.dart';
import 'enums.dart';
import 'room_capabilities.dart';

/// How long after sending a message its author may still edit it. Mirrors
/// `EDIT_WINDOW_MS` in `backend/convex/messages.ts`, which is the authority —
/// this constant only decides whether the EDIT row is *offered*.
const Duration kMessageEditWindow = Duration(minutes: 15);

/// Shaved off the client's copy of the window so a row tapped at 14:59.8
/// doesn't arrive server-side at 15:00.2 and bounce. The server refusal is
/// still handled (as the expired snack); this just keeps it rare enough to be
/// a race instead of an experience.
const Duration _kEditWindowGrace = Duration(seconds: 10);

/// What a MESSAGE affords in the long-press menu, resolved once instead of
/// re-derived at every call site.
///
/// ── Why this type exists ───────────────────────────────────────────────────
///
/// The same story `RoomCapabilities` tells, one level down. The action menu
/// took eleven independent booleans, and the two screens that open it —
/// `RoomScreen` and `ThreadOverlay` — each derived them by hand, with the
/// predicates (`!isPending && status == sent && type != system`, three times
/// over) copied between them and already drifting in punctuation. Worse, the
/// menu itself counted its rows TWICE: once building them and once in a
/// hand-synced `_actionCount()` whose comment warned that a missed row
/// mispositions the whole menu by 48pt. Every new action meant four edits in
/// three files.
///
/// So the question each site asks changed from "which message is this?" to
/// "may I draw this row?". The menu builds its row list from this object once,
/// and the count IS that list's length — the desync bug class is gone
/// structurally, not by care.
///
/// [none] affords nothing, and that is the safe default for any message state
/// this table has not been taught: a missing row is a row that can't be
/// mis-tapped.
@immutable
class MessageCapabilities {
  const MessageCapabilities({
    required this.canReply,
    required this.canEdit,
    required this.canForward,
    required this.canViewThread,
    required this.canCopy,
    required this.canCopyName,
    required this.canPin,
    required this.canSave,
    required this.canSelect,
    required this.canViewProfile,
    required this.canDelete,
    required this.canReport,
  });

  final bool canReply;

  /// Whether the EDIT row is offered: the viewer's own sent text message,
  /// still inside the (skew-corrected, grace-shaved) 15-minute window. The
  /// server re-checks with its own clock either way — see
  /// `messages.editMessage`.
  final bool canEdit;
  final bool canForward;

  /// The VIEW THREAD row — this message is a reply whose thread can be
  /// opened. `ThreadOverlay` switches it off via [copyWith]: opening a thread
  /// from inside the thread would recurse.
  final bool canViewThread;
  final bool canCopy;

  /// Puts a document's filename on the clipboard — a document has no body for
  /// [canCopy] to take, and its name is the one thing worth carrying away.
  final bool canCopyName;
  final bool canPin;
  final bool canSave;
  final bool canSelect;
  final bool canViewProfile;
  final bool canDelete;
  final bool canReport;

  /// Affords nothing. What an unknown state gets, and the base
  /// pending-message posture before the one row it keeps is added back.
  static const none = MessageCapabilities(
    canReply: false,
    canEdit: false,
    canForward: false,
    canViewThread: false,
    canCopy: false,
    canCopyName: false,
    canPin: false,
    canSave: false,
    canSelect: false,
    canViewProfile: false,
    canDelete: false,
    canReport: false,
  );

  MessageCapabilities copyWith({
    bool? canReply,
    bool? canEdit,
    bool? canForward,
    bool? canViewThread,
    bool? canCopy,
    bool? canCopyName,
    bool? canPin,
    bool? canSave,
    bool? canSelect,
    bool? canViewProfile,
    bool? canDelete,
    bool? canReport,
  }) =>
      MessageCapabilities(
        canReply: canReply ?? this.canReply,
        canEdit: canEdit ?? this.canEdit,
        canForward: canForward ?? this.canForward,
        canViewThread: canViewThread ?? this.canViewThread,
        canCopy: canCopy ?? this.canCopy,
        canCopyName: canCopyName ?? this.canCopyName,
        canPin: canPin ?? this.canPin,
        canSave: canSave ?? this.canSave,
        canSelect: canSelect ?? this.canSelect,
        canViewProfile: canViewProfile ?? this.canViewProfile,
        canDelete: canDelete ?? this.canDelete,
        canReport: canReport ?? this.canReport,
      );
}

/// What [message] affords. A PORT of the predicates that lived inline at the
/// two menu call sites, not a redesign — every rule below existed before this
/// function did, and the comments travelled with them.
///
/// Prefer `ChatRepository.capabilitiesForMessage`, which resolves
/// [room]/[roomIsEphemeral]/[serverNow] for you.
///
/// [roomIsEphemeral] is a fact about the ROOM (`ChatRoom.isEphemeral`) that
/// [RoomCapabilities] deliberately doesn't carry — it is about message
/// lifetime, not room kind — so it rides in beside the table.
MessageCapabilities messageCapabilitiesFor({
  required ChatMessage message,
  required bool isMine,
  required RoomCapabilities room,
  required bool roomIsEphemeral,
  required DateTime serverNow,
}) {
  final isPending = message.id.startsWith('tmp_');
  final isSent = message.status == MessageStatus.sent;
  final isSystem = message.type == MessageType.system;

  // `url` is grandfathered wire vocabulary for a text message that is mostly
  // a link — same renderer, same edit mutation. The window is measured
  // against the SERVER's clock (skew-corrected by the repository), because
  // `createdAt` is server-minted and a device five minutes fast would
  // otherwise close the window early on its own messages.
  final isEditableText =
      message.type == MessageType.text || message.type == MessageType.url;
  final canEdit = isMine &&
      !isPending &&
      isSent &&
      isEditableText &&
      !message.viewOnce &&
      serverNow.difference(message.createdAt) <
          (kMessageEditWindow - _kEditWindowGrace);

  return MessageCapabilities(
    canReply: !isPending && isSent && !isSystem,
    canEdit: canEdit,
    // The rule the selection bar applies to a whole batch, asked of one
    // message: nothing leaves an ephemeral room, nothing sealed, nothing the
    // server hasn't confirmed.
    canForward:
        !isPending && isSent && !isSystem && !roomIsEphemeral && !message.viewOnce,
    canViewThread: message.isReply,
    canCopy: message.type == MessageType.text && message.content.isNotEmpty,
    canCopyName: message.type == MessageType.file && message.fileName != null,
    // An optimistic bubble has no server id to pin, and a system notice is
    // not something anyone means to keep.
    canPin: !isPending && isSent && !isSystem,
    // Same three gates as pinning, plus the room capability — which is what
    // keeps Saved Messages from offering to save into itself. See
    // `RoomCapabilities.canSaveMessages`.
    canSave: !isPending && isSent && !isSystem && room.canSaveMessages,
    // Offered on anything the transcript will let you long-press — including
    // messages that aren't yours and can't be forwarded, because SELECT is
    // how you reach the bar that says which of the two actions apply.
    canSelect: !isPending,
    canViewProfile: !isMine,
    canDelete: isMine,
    canReport: !isMine,
  );
}
