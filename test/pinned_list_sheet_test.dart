import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_pin.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/pinned_list_sheet.dart';

/// The banner above the transcript dropped its "Pinned message" heading — the
/// accent pin glyph and the message right underneath say it, and the room
/// header is directly above. This sheet deliberately KEPT its header, and these
/// pin that asymmetry so a later tidy-up doesn't "finish the job".
///
/// A sheet is a surface the reader navigates TO. Nothing around it survived the
/// transition: no room header, no transcript, no strip. Its rows are sender,
/// clock time and preview — the shape of a search result or a forward picker
/// just as much as a pin list — and the only pin-shaped glyph on them is the
/// UNPIN button, which names an action, not the collection. The count lives in
/// the header too, and has nowhere else to go. Removing it here would cost more
/// than it cleaned up.
void main() {
  ChatMessage msg(String id, String content) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: 'alice',
    senderName: 'alice',
    content: content,
    createdAt: DateTime(2026, 3, 1, 12),
    type: MessageType.text,
  );

  RoomPin pin(String id, String content) => RoomPin(
    message: msg(id, content),
    pinnedAt: DateTime(2026, 3, 1, 13),
    pinnedBy: 'bob',
  );

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: child),
    ),
  );

  Widget sheet(List<RoomPin> pins) => host(
    PinnedListSheet(
      repo: _FakeRepo(pins),
      api: _FakeApi(),
      roomId: 'r',
      onJump: (_) {},
    ),
  );

  testWidgets('the sheet keeps its header, with the count', (tester) async {
    await tester.pumpWidget(sheet([pin('m1', 'deploy at 4pm'), pin('m2', 'b')]));
    await tester.pump();

    // The title, and the count as the bar's quiet second line.
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('2 messages'), findsOneWidget);
    expect(find.text('alice'), findsNWidgets(2));
  });

  testWidgets('the header survives the last pin going, and says so', (
    tester,
  ) async {
    // Somebody unpinned the last one while this was open. The sheet stays up —
    // popping out from under a finger is worse — so it still has to identify
    // itself, and now there is not a single row left to do that for it.
    await tester.pumpWidget(sheet(const []));
    await tester.pump();

    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Nothing pinned anymore'), findsOneWidget);
  });
}

/// [PinnedListSheet] reads through to the repository on every build and listens
/// for unpins, so the fake has to be a working [Listenable] — nothing here ever
/// notifies, so the no-op registration is enough.
class _FakeRepo extends Fake implements ChatRepository {
  _FakeRepo(this.pins);

  final List<RoomPin> pins;

  @override
  List<RoomPin> pinsFor(String roomId) => pins;

  /// Nobody is in the roster: each row falls back to the sender's name.
  @override
  ChatUser? userById(String id) => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Only ever consulted for media thumbnails, and every fixture here is text.
class _FakeApi extends Fake implements ChatApi {}
