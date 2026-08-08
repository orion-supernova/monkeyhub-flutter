import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_bookmark.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/saved_messages_section.dart';

/// Room info's "Saved messages" block.
///
/// The section's whole job is to be a *scoped, private* list and to say so, so
/// these check the three things that make it that rather than the other Saved
/// Messages: it asks the repository for one room only, it prints the caption
/// that states the scope, and it tells the reader how to fill it when it is
/// empty.

/// [SavedMessagesSection] reads through to the repository on every build and
/// listens for changes, so the fake has to be a working [Listenable] — nothing
/// here ever notifies, so the no-op registration is enough.
class _FakeRepo extends Fake implements ChatRepository {
  _FakeRepo(this.byRoom);

  /// roomId → that room's saves, so a test can prove the section never reaches
  /// past the room it was given.
  final Map<String, List<MessageBookmark>> byRoom;

  final List<String> unsaved = [];

  @override
  List<MessageBookmark> savedFor(String roomId) => byRoom[roomId] ?? const [];

  @override
  Future<void> unsaveMessage(String roomId, String messageId) async {
    unsaved.add('$roomId/$messageId');
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Only ever consulted for media thumbnails, and every fixture here is text.
class _FakeApi extends Fake implements ChatApi {}

void main() {
  final l10n = AppLocalizationsEn();

  ChatMessage msg(String id, String content, {String sender = 'alice'}) =>
      ChatMessage(
        id: id,
        roomId: 'rA',
        senderId: sender,
        senderName: sender,
        content: content,
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.text,
      );

  MessageBookmark saved(String id, String content, {String sender = 'alice'}) =>
      MessageBookmark(
        message: msg(id, content, sender: sender),
        savedAt: DateTime(2026, 3, 1, 13),
      );

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  Future<void> pumpSection(
    WidgetTester tester, {
    required _FakeRepo repo,
    String roomId = 'rA',
    void Function(ChatMessage)? onJump,
  }) async {
    await tester.pumpWidget(host(SavedMessagesSection(
      repo: repo,
      api: _FakeApi(),
      roomId: roomId,
      onJump: onJump ?? (_) {},
    )));
    await tester.pump();
  }

  testWidgets('names the section and states the scope, always', (tester) async {
    // The caption is not decoration: it is the only thing distinguishing this
    // from the personal Saved Messages chat, so it must be there even when
    // there is nothing to caption.
    await pumpSection(tester, repo: _FakeRepo({}));

    expect(find.text(l10n.roomInfoScreenSavedMessagesLabel), findsOneWidget);
    expect(find.text(l10n.roomInfoScreenSavedMessagesCaption), findsOneWidget);
  });

  testWidgets('empty says how to leave the empty state', (tester) async {
    await pumpSection(tester, repo: _FakeRepo({'rA': const []}));

    expect(find.text(l10n.roomInfoScreenSavedMessagesEmpty), findsOneWidget);
    expect(find.text('keep this'), findsNothing);
  });

  testWidgets('lists this room‘s saves, sender and preview', (tester) async {
    await pumpSection(
      tester,
      repo: _FakeRepo({
        'rA': [saved('m1', 'keep this'), saved('m2', 'and this', sender: 'bob')],
      }),
    );

    expect(find.text(l10n.roomInfoScreenSavedMessagesEmpty), findsNothing);
    expect(find.text('keep this'), findsOneWidget);
    expect(find.text('and this'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('shows only the room it was given, not every saved message',
      (tester) async {
    // The failure this rules out is the one the feature is named after: a
    // section that quietly turned into the global Saved Messages pile.
    await pumpSection(
      tester,
      roomId: 'rA',
      repo: _FakeRepo({
        'rA': [saved('m1', 'from this room')],
        'rB': [saved('m9', 'from somewhere else')],
      }),
    );

    expect(find.text('from this room'), findsOneWidget);
    expect(find.text('from somewhere else'), findsNothing);
  });

  testWidgets('a saved message the transcript no longer has simply is not there',
      (tester) async {
    // `removeMessageAndFanout` drops the bookmark with the message, and
    // `bookmarks:listForRoom` filters anything it cannot resolve, so what
    // reaches this widget after a delete or a self-destruct is a shorter list —
    // never a row it has to render as broken.
    final repo = _FakeRepo({'rA': [saved('m2', 'survivor')]});
    await pumpSection(tester, repo: repo);

    expect(find.text('survivor'), findsOneWidget);
    expect(find.text('gone'), findsNothing);
    // And the section is still a section, not an error state.
    expect(find.text(l10n.roomInfoScreenSavedMessagesLabel), findsOneWidget);
  });

  testWidgets('tapping a row hands the message up to be jumped to',
      (tester) async {
    ChatMessage? jumped;
    await pumpSection(
      tester,
      repo: _FakeRepo({'rA': [saved('m1', 'keep this')]}),
      onJump: (m) => jumped = m,
    );

    await tester.tap(find.text('keep this'));
    await tester.pump();

    // Handed up rather than travelled to here — RoomScreen owns the jump.
    expect(jumped?.id, 'm1');
  });

  testWidgets('the trailing bookmark drops the save', (tester) async {
    final repo = _FakeRepo({'rA': [saved('m1', 'keep this')]});
    await pumpSection(tester, repo: repo);

    await tester.tap(find.byIcon(CupertinoIcons.bookmark_fill));
    await tester.pump();

    expect(repo.unsaved, ['rA/m1']);
  });
}
