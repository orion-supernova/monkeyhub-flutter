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
    required this.canCopyCoordinates,
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

  /// Puts a location's coordinates on the clipboard — the same reason
  /// [canCopyName] exists apart from [canCopy]: a location bubble has no text
  /// body either. True for a [MessageType.liveLocation] as well as a static
  /// one: the map preview and the "open in maps" tap already read whatever
  /// the latest fix is regardless of whether the share is still running, so
  /// there is no reason for this one row alone to refuse it.
  final bool canCopyCoordinates;
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
    canCopyCoordinates: false,
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
    bool? canCopyCoordinates,
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
        canCopyCoordinates: canCopyCoordinates ?? this.canCopyCoordinates,
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
  // No `isInteractive` local, deliberately, even though a poll/checklist/event
  // changes four of the answers below. Each of those rules already excludes it
  // for a reason of its own — EDIT and COPY through `isEditableText`, which
  // names the two text types positively rather than listing what isn't one —
  // and a shared flag would let a future rule opt out of the interactive kinds
  // without anyone saying which of the four reasons applied to it.

  // `url` is grandfathered wire vocabulary for a text message that is mostly
  // a link — same renderer, same edit mutation. The window is measured
  // against the SERVER's clock (skew-corrected by the repository), because
  // `createdAt` is server-minted and a device five minutes fast would
  // otherwise close the window early on its own messages.
  // Excludes the interactive kinds without naming them, which is the right
  // shape: EDIT rewrites `content`, and on a poll that is the question — moving
  // it under answers people have already given. A checklist grows through its
  // own mutation (`interactions:addItem`) and a poll's options never change at
  // all, which is what makes a result mean something.
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
    // Interactive cards forward like everything else, and the server makes the
    // copy a FRESH one — same question, no answers, open even if the original
    // was closed. See `forkInteraction`: carrying the votes would attribute
    // this room's members' answers to people who are not in it.
    canForward:
        !isPending && isSent && !isSystem && !roomIsEphemeral && !message.viewOnce,
    canViewThread: message.isReply,
    // `isEditableText`, not a bare `type == text`: `url` is the same
    // grandfathered text-with-a-link content EDIT already treats as text
    // (see the comment above), and this gate had been left checking only
    // `text` — the one shape that can edit itself as text couldn't copy
    // itself as text either.
    // Deliberately NOT extended to an interactive card, even though
    // `message.content` holds its prompt and would copy cleanly. Copying "which
    // night suits everyone?" out of a poll gives you a question with none of
    // the answers — which reads, on the clipboard, exactly like a text message
    // somebody sent. The thing worth carrying away from a poll is its result,
    // and that is the respondents sheet's job rather than the clipboard's.
    canCopy: isEditableText && message.content.isNotEmpty,
    canCopyName: message.type == MessageType.file && message.fileName != null,
    // See the doc comment on [MessageCapabilities.canCopyCoordinates] for why
    // this reads `locationShare` rather than `message.type` directly — it is
    // what folds in both the type gate and the "coordinates actually
    // present" gate a stale-cache or downgraded send can fail.
    canCopyCoordinates: message.locationShare != null,
    // An optimistic bubble has no server id to pin, and a system notice is
    // not something anyone means to keep.
    // Offered on an interactive card like anything else. A poll pinned to the
    // top of a room is one of the better reasons the banner exists — "vote on
    // this" is exactly what a pin says — and the banner renders it through
    // `messagePreviewLine`, which gives the prompt.
    canPin: !isPending && isSent && !isSystem,
    // Same three gates as pinning, plus the room capability — which is what
    // keeps Saved Messages from offering to save into itself. See
    // `RoomCapabilities.canSaveMessages`.
    // A saved poll is a saved place in the conversation, exactly like a saved
    // photo — `messageBookmarks` marks the message where it was said rather
    // than copying it, so the card the reader comes back to is the live one
    // with whatever the tally has become.
    canSave: !isPending && isSent && !isSystem && room.canSaveMessages,
    // Offered on anything the transcript will let you long-press — including
    // messages that aren't yours and can't be forwarded, because SELECT is
    // how you reach the bar that says which of the two actions apply. Not a
    // system notice, though: there is no batch of "X joined the room" anyone
    // means to reach for, and it can't be forwarded, pinned or saved either.
    canSelect: !isPending && !isSystem,
    // Neither of these has anyone to aim at on a system notice. It carries a
    // `senderId` (the system account that wrote it) but no one reads that as
    // "the sender" the way they would on a real message — there is no one to
    // view the profile of or report.
    canViewProfile: !isMine && !isSystem,
    canDelete: isMine,
    canReport: !isMine && !isSystem,
  );
}
