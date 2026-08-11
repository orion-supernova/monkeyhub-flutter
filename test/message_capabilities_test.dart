import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';

/// The long-press menu's truth table: what a message affords, resolved once by
/// [messageCapabilitiesFor], and the row order [messageActionSpecs] draws from
/// it.
///
/// Both halves are deliberately pure — no widget is pumped anywhere in this
/// file. The resolver replaced eleven booleans that two screens each derived by
/// hand, and the spec list replaced a hand-synced row count whose drift used to
/// misposition the menu by 48pt. Which is exactly why they're pinned here as
/// tables rather than exercised through the overlay: the bug class they retired
/// was *disagreement between copies*, and a plain test of the single source is
/// the cheapest place to notice a rule quietly changing.
void main() {
  // All ages below are measured from this instant; `createdAt` is server-minted
  // in production and every window test states its `serverNow` relative to it.
  final t0 = DateTime(2026, 3, 1, 12, 0);

  ChatMessage msg({
    String id = 'm1',
    String content = 'hey',
    MessageType type = MessageType.text,
    MessageStatus status = MessageStatus.sent,
    bool viewOnce = false,
    String? fileName,
    String? replyToId,
    ReplyPreview? replyToPreview,
  }) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: 'alice',
    senderName: 'alice',
    content: content,
    createdAt: t0,
    type: type,
    status: status,
    viewOnce: viewOnce,
    fileName: fileName,
    replyToId: replyToId,
    replyToPreview: replyToPreview,
  );

  MessageCapabilities caps(
    ChatMessage m, {
    bool isMine = true,
    RoomCapabilities room = RoomCapabilities.dm,
    bool roomIsEphemeral = false,
    DateTime? serverNow,
  }) => messageCapabilitiesFor(
    message: m,
    isMine: isMine,
    room: room,
    roomIsEphemeral: roomIsEphemeral,
    serverNow: serverNow ?? t0.add(const Duration(minutes: 1)),
  );

  group('a pending message', () {
    // An optimistic bubble: `tmp_` id, nothing the server has confirmed.
    final pending = caps(msg(id: 'tmp_1', status: MessageStatus.pending));

    test('affords COPY — the text exists on this device if nowhere else', () {
      expect(pending.canCopy, isTrue);
    });

    test('affords none of the rows that need a server row to act on', () {
      expect(pending.canReply, isFalse);
      expect(pending.canEdit, isFalse);
      expect(pending.canForward, isFalse);
      expect(pending.canPin, isFalse);
      expect(pending.canSave, isFalse);
      // SELECT gates on `!isPending` alone: multi-select exists to feed the
      // forward/delete bar, and a bubble with no server id gives that bar
      // nothing it can address.
      expect(pending.canSelect, isFalse);
    });

    test('DOES afford DELETE — isMine alone, pending or not', () {
      // Surprising next to the row above, and deliberate: discarding your own
      // stuck send is the one thing you most need on a bubble that never made
      // it, and it needs no server row to act on.
      expect(pending.canDelete, isTrue);
    });

    test('carries no rows about the sender, because the sender is you', () {
      expect(pending.canViewProfile, isFalse);
      expect(pending.canReport, isFalse);
    });

    test('an empty pending message has nothing to copy either', () {
      expect(caps(msg(id: 'tmp_1', content: '', status: MessageStatus.pending)).canCopy, isFalse);
    });
  });

  group('canEdit', () {
    test('a fresh sent text message of mine', () {
      expect(caps(msg()).canEdit, isTrue);
    });

    test('a url-typed message edits like text', () {
      // `url` is grandfathered wire vocabulary for a text message that is
      // mostly a link — same renderer, same edit mutation.
      expect(caps(msg(type: MessageType.url)).canEdit, isTrue);
    });

    test('never someone else\'s message', () {
      expect(caps(msg(), isMine: false).canEdit, isFalse);
    });

    test('never an image — only text and url are editable shapes', () {
      expect(caps(msg(type: MessageType.image)).canEdit, isFalse);
    });

    test('never a view-once message', () {
      // A sealed message must not be rewritable after the recipient's one look.
      expect(caps(msg(viewOnce: true)).canEdit, isFalse);
    });

    test('a message 20 minutes old is past the window', () {
      expect(
        caps(msg(), serverNow: t0.add(const Duration(minutes: 20))).canEdit,
        isFalse,
      );
    });

    test('the grace bites: 14m55s is inside 15 minutes and still refused', () {
      // The client's copy of the window is 15min minus a 10s grace, so the
      // offer closes at 14:50 — a row tapped in the last real seconds would
      // otherwise arrive server-side after 15:00 and bounce.
      expect(
        caps(
          msg(),
          serverNow: t0.add(const Duration(minutes: 14, seconds: 55)),
        ).canEdit,
        isFalse,
      );
    });

    test('the grace takes ten seconds, not the last minute: 14m40s edits', () {
      // Boundary control for the test above — the shaved window is 14:50, so
      // a message 14:40 old is still on the offered side of it.
      expect(
        caps(
          msg(),
          serverNow: t0.add(const Duration(minutes: 14, seconds: 40)),
        ).canEdit,
        isTrue,
      );
    });

    test('a device five minutes fast does not close its own window early', () {
      // The window is measured against the SERVER's clock, handed in as
      // `serverNow` — `createdAt` is server-minted, so mixing in the device's
      // wall clock would subtract the skew from the author's own window.
      //
      // Here the device is five minutes fast: its wall clock reads t0+16:00,
      // an age past even the unshaved window, while the server knows only
      // eleven minutes have passed.
      final wallNow = t0.add(const Duration(minutes: 16));
      final serverNow = wallNow.subtract(const Duration(minutes: 5));
      expect(caps(msg(), serverNow: serverNow).canEdit, isTrue);
    });
  });

  group('canSave folds in the room', () {
    test('an ordinary DM offers SAVE', () {
      expect(caps(msg(), room: RoomCapabilities.dm).canSave, isTrue);
    });

    test('Saved Messages never offers to save into itself', () {
      // Same message, same viewer — only `RoomCapabilities.canSaveMessages`
      // differs. The room already IS the pile of things you kept, so a
      // bookmark inside it sorts nothing from nothing.
      expect(caps(msg(), room: RoomCapabilities.savedMessages).canSave, isFalse);
    });
  });

  group('canForward', () {
    test('an ordinary sent message forwards', () {
      expect(caps(msg()).canForward, isTrue);
    });

    test('nothing leaves an ephemeral room', () {
      expect(caps(msg(), roomIsEphemeral: true).canForward, isFalse);
    });

    test('nothing sealed leaves either', () {
      // Forwarding a view-once message would be a permanent copy of a
      // burn-after-reading photo.
      expect(caps(msg(viewOnce: true)).canForward, isFalse);
    });
  });

  group('a system-type message', () {
    final system = caps(msg(type: MessageType.system), isMine: false);

    test('is not something anyone replies to, pins, saves or forwards', () {
      expect(system.canReply, isFalse);
      expect(system.canPin, isFalse);
      expect(system.canSave, isFalse);
      expect(system.canForward, isFalse);
    });
  });

  group('canViewThread', () {
    test('follows the reply tether and nothing else', () {
      expect(caps(msg()).canViewThread, isFalse);
      final reply = msg(
        replyToId: 'm0',
        replyToPreview: const ReplyPreview(
          senderId: 'bob',
          senderName: 'bob',
          contentPreview: 'hi',
          type: MessageType.text,
        ),
      );
      expect(caps(reply).canViewThread, isTrue);
    });
  });

  group('a document', () {
    test('offers its NAME to the clipboard, not a body it does not have', () {
      final doc = caps(msg(type: MessageType.file, fileName: 'q3-report.pdf'));
      expect(doc.canCopyName, isTrue);
      expect(doc.canCopy, isFalse);
    });

    test('with no recorded name has nothing to copy', () {
      expect(caps(msg(type: MessageType.file)).canCopyName, isFalse);
    });
  });

  test('MessageCapabilities.none affords nothing', () {
    // Enumerated by hand so that a thirteenth capability added to the class
    // fails the length check below until it is taught to this list — `none` is
    // what every unknown message state resolves to, so "affords nothing" has
    // to stay true field by field.
    final fields = <String, bool Function(MessageCapabilities)>{
      'canReply': (c) => c.canReply,
      'canEdit': (c) => c.canEdit,
      'canForward': (c) => c.canForward,
      'canViewThread': (c) => c.canViewThread,
      'canCopy': (c) => c.canCopy,
      'canCopyName': (c) => c.canCopyName,
      'canPin': (c) => c.canPin,
      'canSave': (c) => c.canSave,
      'canSelect': (c) => c.canSelect,
      'canViewProfile': (c) => c.canViewProfile,
      'canDelete': (c) => c.canDelete,
      'canReport': (c) => c.canReport,
    };
    expect(
      fields.length,
      12,
      reason: 'a new capability must join this list before this test can vouch for `none`',
    );
    for (final entry in fields.entries) {
      expect(
        entry.value(MessageCapabilities.none),
        isFalse,
        reason: '${entry.key} must be off in the affords-nothing default',
      );
    }
  });

  group('messageActionSpecs', () {
    test('rows come out constructive → neutral → destructive, in one fixed order', () async {
      // No widget is pumped: the delegate hands back the English table
      // directly, which is all the spec builder needs.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final all = MessageCapabilities.none.copyWith(
        canReply: true,
        canEdit: true,
        canForward: true,
        canViewThread: true,
        canCopy: true,
        canCopyName: true,
        canPin: true,
        canSave: true,
        canSelect: true,
        canViewProfile: true,
        canDelete: true,
        canReport: true,
      );
      final specs = messageActionSpecs(
        l10n: l10n,
        capabilities: all,
        isPinned: false,
        isSaved: false,
        hasFileName: true,
      );

      // The order IS the product: this list is the single source both for the
      // rows the menu draws and for the height it lays itself out with, so a
      // reshuffle here moves every row under the user's thumb.
      expect(specs.map((s) => s.action).toList(), [
        MessageAction.reply,
        MessageAction.edit,
        MessageAction.forward,
        MessageAction.viewThread,
        MessageAction.copy,
        MessageAction.copyName,
        MessageAction.pin,
        MessageAction.save,
        MessageAction.select,
        MessageAction.viewProfile,
        MessageAction.delete,
        MessageAction.report,
      ]);

      expect(
        specs.where((s) => s.destructive).map((s) => s.action).toList(),
        [MessageAction.delete, MessageAction.report],
        reason: 'red ink is for the two rows that cannot be taken back with one tap',
      );
    });
  });
}
