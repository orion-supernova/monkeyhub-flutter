import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_bookmark.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/models/room_content_item.dart';
import 'package:monkeyhub/screens/room_content_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/segmented_control.dart';

/// The SAVED tab of the shared-content browser — what used to be a standalone
/// block in room info.
///
/// The move is only safe if the three properties that made that block a
/// *personal shelf* rather than a fifth gallery survived it, so these pin
/// exactly those: it is scoped to one room and one reader, it is ordered by
/// when things were SAVED rather than when they were sent, and it says out loud
/// that nobody else can see it. The fourth is the gate — a room that cannot
/// save must not offer a door to a list that can never fill.

class _FakeRepo extends Fake implements ChatRepository {
  _FakeRepo(this.byRoom, {this.canSave = true});

  /// roomId → that room's saves, so a test can prove the tab never reaches
  /// past the room it was given.
  final Map<String, List<MessageBookmark>> byRoom;
  final bool canSave;

  final List<String> unsaved = [];

  @override
  String? get userId => 'me';

  @override
  List<MessageBookmark> savedFor(String roomId) => byRoom[roomId] ?? const [];

  @override
  List<ChatMessage> messagesFor(String roomId) => const [];

  @override
  ChatRoom? roomById(String id) => ChatRoom(
        id: id,
        name: 'general',
        createdBy: 'u0',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 2,
        participantIds: const ['me', 'alice'],
      );

  @override
  RoomCapabilities capabilitiesFor(ChatRoom room) =>
      canSave ? RoomCapabilities.group : RoomCapabilities.savedMessages;

  @override
  Future<void> unsaveMessage(String roomId, String messageId) async {
    unsaved.add('$roomId/$messageId');
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Only ever consulted for the counts query, which the screen treats as
/// decoration and swallows, and for media thumbnails no fixture here has.
class _FakeApi extends Fake implements ChatApi {}

void main() {
  final l10n = AppLocalizationsEn();

  ChatMessage msg(String id, String content, {String sender = 'alice', int day = 1}) =>
      ChatMessage(
        id: id,
        roomId: 'rA',
        senderId: sender,
        senderName: sender,
        content: content,
        createdAt: DateTime(2026, 3, day, 12),
        type: MessageType.text,
      );

  MessageBookmark saved(
    String id,
    String content, {
    String sender = 'alice',
    int day = 1,
    int savedDay = 1,
  }) =>
      MessageBookmark(
        message: msg(id, content, sender: sender, day: day),
        savedAt: DateTime(2026, 3, savedDay, 13),
      );

  final themeController = ThemeController(BasicTheme.midnight());

  /// The scope goes in `builder`, not in `home`: the browser is a PUSHED route,
  /// so it lands above `home` in the navigator and would see no ancestor scope
  /// at all if the theme were wrapped there.
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, inner) =>
            ThemeScope(controller: themeController, child: inner!),
        home: child,
      );

  final api = _FakeApi();

  /// Pushes the browser as a real route rather than as `home`, because "show in
  /// chat" pops a [ChatMessage] and there has to be something underneath to pop
  /// back to — which is also the shape the room-info → browser → transcript
  /// hand-off actually has.
  ///
  /// Returns a reader for whatever the browser eventually popped. Bounded pumps
  /// rather than `pumpAndSettle`: the route transition is the only animation in
  /// flight and half a second clears it.
  Future<ChatMessage? Function()> open(
    WidgetTester tester, {
    required _FakeRepo repo,
    RoomContentTab tab = RoomContentTab.saved,
  }) async {
    ChatMessage? popped;
    await tester.pumpWidget(host(
      Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: GestureDetector(
              onTap: () async {
                popped = await Navigator.of(ctx).push<ChatMessage>(
                  MaterialPageRoute(
                    builder: (_) => RoomContentScreen(
                      roomId: 'rA',
                      repo: repo,
                      api: api,
                      initialTab: tab,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return () => popped;
  }

  testWidgets('lists this room‘s saves, sender and preview', (tester) async {
    await open(
      tester,
      repo: _FakeRepo({
        'rA': [saved('m1', 'keep this'), saved('m2', 'and this', sender: 'bob')],
      }),
    );

    expect(find.text('keep this'), findsOneWidget);
    expect(find.text('and this'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('shows only the room it was given, not every saved message',
      (tester) async {
    // The failure this rules out is the one the feature is named after: a tab
    // that quietly turned into the global Saved Messages pile.
    await open(
      tester,
      repo: _FakeRepo({
        'rA': [saved('m1', 'from this room')],
        'rB': [saved('m9', 'from somewhere else')],
      }),
    );

    expect(find.text('from this room'), findsOneWidget);
    expect(find.text('from somewhere else'), findsNothing);
  });

  testWidgets('keeps the shelf order — newest SAVED first, not newest sent',
      (tester) async {
    // The one thing the move could most easily have destroyed. Every other tab
    // descends by `createdAt`, and re-sorting this one to match would look like
    // a tidy-up while quietly turning a shelf into a second gallery.
    await open(
      tester,
      repo: _FakeRepo({
        'rA': [
          // Sent first, kept last — so it must lead.
          saved('m1', 'old but freshly kept', day: 1, savedDay: 20),
          saved('m2', 'new but kept ages ago', day: 15, savedDay: 2),
        ],
      }),
    );

    final first = tester.getTopLeft(find.text('old but freshly kept'));
    final second = tester.getTopLeft(find.text('new but kept ages ago'));
    expect(first.dy, lessThan(second.dy));
  });

  testWidgets('empty says what the list IS, not only that it is empty',
      (tester) async {
    // This is the moment a reader is most likely to be wondering, and the
    // answer they must not guess wrong is the privacy one — so the copy carries
    // both the gesture that fills the list and the contrast with pinning.
    await open(tester, repo: _FakeRepo({'rA': const []}));

    expect(find.text(l10n.roomContentScreenEmptySaved), findsOneWidget);
    expect(
      l10n.roomContentScreenEmptySaved.toLowerCase(),
      contains('private'),
      reason: 'the empty state is one of the two homes for the distinction',
    );
    expect(l10n.roomContentScreenEmptySaved.toLowerCase(), contains('pinned'));
  });

  testWidgets('the trailing bookmark drops the save', (tester) async {
    final repo = _FakeRepo({'rA': [saved('m1', 'keep this')]});
    await open(tester, repo: repo);

    // Exactly one filled bookmark per row, and it is the release. The leading
    // square says what KIND of message this is — every row here is saved, so a
    // second bookmark there would carry no information.
    expect(find.byIcon(CupertinoIcons.bookmark_fill), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.bookmark_fill));
    await tester.pump();

    expect(repo.unsaved, ['rA/m1']);
  });

  testWidgets('tapping a row pops the message, whatever kind it is',
      (tester) async {
    // Not routed by type the way the other tabs are: the reason to keep a
    // message is the exchange around it, so every saved row travels.
    final read = await open(
      tester,
      repo: _FakeRepo({'rA': [saved('m1', 'keep this')]}),
    );

    await tester.tap(find.text('keep this'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(read()?.id, 'm1');
  });

  testWidgets('a room that cannot save is offered no SAVED tab', (tester) async {
    // Saved Messages is already the pile of things you kept. Gated on the
    // capability rather than an `isSavedMessages` check, per
    // `room_capabilities.dart`.
    await open(
      tester,
      repo: _FakeRepo({'rA': [saved('m1', 'keep this')]}, canSave: false),
      tab: RoomContentTab.media,
    );

    expect(find.text(l10n.roomContentTabLabelSaved), findsNothing);
    // The tab label and the bar's title are both "Media" now that both are
    // sentence case, so this looks for the tab itself.
    expect(
      find.byWidgetPredicate((w) =>
          w is IosSegmentedControl<RoomContentTab> &&
          w.segments.any((s) => s.value == RoomContentTab.media) &&
          w.segments.every((s) => s.value != RoomContentTab.saved)),
      findsOneWidget,
    );
  });

  testWidgets('asking for the SAVED tab of such a room lands on MEDIA',
      (tester) async {
    // A route that cannot build is a far worse outcome than a browser that
    // opened on the wrong tab.
    await open(
      tester,
      repo: _FakeRepo({'rA': const []}, canSave: false),
    );

    expect(
      tester
          .widget<IosSegmentedControl<RoomContentTab>>(
              find.byType(IosSegmentedControl<RoomContentTab>))
          .value,
      RoomContentTab.media,
    );
    expect(find.text(l10n.roomContentTabHeaderMedia), findsWidgets);
  });

  group('where the count comes from', () {
    test('SAVED is counted on the client, the other four on the server', () {
      const server = {
        'media': RoomContentCount(count: 12, capped: false),
        'link': RoomContentCount(count: 99, capped: true),
      };

      expect(
        roomContentCountFor(RoomContentTab.media,
                serverCounts: server, savedCount: 3)
            ?.count,
        12,
      );
      expect(
        roomContentCountFor(RoomContentTab.saved,
                serverCounts: server, savedCount: 3)
            ?.count,
        3,
        reason: 'the bookmark list is already in memory and already live',
      );
    });

    test('SAVED is never capped — 50 saves cannot reach 99+', () {
      final c = roomContentCountFor(RoomContentTab.saved,
          serverCounts: const {}, savedCount: 50);
      expect(c?.capped, isFalse);
      expect(c?.badge, '50');
    });

    test('an empty shelf badges nothing rather than a zero', () {
      final c = roomContentCountFor(RoomContentTab.saved,
          serverCounts: const {}, savedCount: 0);
      expect(c?.badge, isNull);
    });

    test('a server tab whose count has not landed stays unknown', () {
      // Not zero. "Not asked yet" and "genuinely empty" render differently, and
      // conflating them is what puts a permanent "none" on a full gallery.
      expect(
        roomContentCountFor(RoomContentTab.voice,
            serverCounts: const {}, savedCount: 3),
        isNull,
      );
    });
  });

  group('the saved tab is not a bucket', () {
    test('no message belongs in it by inspection', () {
      // Whether a message is saved is not a property of the message — it is a
      // row keyed by (room, reader, message) — so the client-side merge that
      // every other tab runs has nothing to answer here.
      expect(
        messageBelongsIn(msg('m1', 'hi'), RoomContentTab.saved),
        isFalse,
      );
      expect(
        messageBelongsIn(
          ChatMessage(
            id: 'm2',
            roomId: 'rA',
            senderId: 'alice',
            senderName: 'alice',
            content: '',
            createdAt: DateTime(2026, 3, 1),
            type: MessageType.image,
            mediaStorageId: 'stor',
          ),
          RoomContentTab.saved,
        ),
        isFalse,
      );
    });

    test('and has neither a server bucket nor a server count key', () {
      expect(RoomContentTab.saved.bucket, isNull);
      expect(RoomContentTab.saved.countKey, isNull);
      // The control: the four that DO.
      expect(RoomContentTab.media.bucket, 'media');
      expect(RoomContentTab.links.countKey, 'link');
    });
  });
}
