import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/share/shared_payload.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/share_target_sheet.dart';

/// What this pins: the one screen a share from outside the app lands on.
///
/// It is reached with the user's attention already spent — they have left
/// another app, tapped an icon, and are waiting. So the two things that matter
/// are that it shows what is about to be sent (the content arrives sight
/// unseen, and there is no going back to check) and that one tap answers the
/// question rather than arming a selection that needs a second confirm.
void main() {
  ChatRoom room(
    String id, {
    String? name,
    bool isMember = true,
    RoomType type = RoomType.regular,
    int? lastMessageMs,
  }) =>
      ChatRoom(
        id: id,
        name: name ?? id,
        createdBy: 'someone',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        isPrivate: false,
        memberCount: 2,
        isMember: isMember,
        type: type,
        lastMessageTime: lastMessageMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastMessageMs),
      );

  ChatUser user(String id, String name) => ChatUser(
        id: id,
        username: name.toLowerCase(),
        name: name,
      );

  /// Mirrors app.dart: [ThemeScope] sits ABOVE [MaterialApp], not inside it.
  ///
  /// Load-bearing, and the reason this helper exists rather than a one-liner
  /// per test. A modal sheet is a route on the navigator, so a ThemeScope
  /// placed at `home:` is BELOW it and `ThemeScope.of` inside the sheet throws.
  /// A harness that got this wrong would pass while the app crashed.
  Future<_Picked> open(
    WidgetTester tester, {
    required _FakeRepo repo,
    SharedPayload payload = const SharedPayload(text: 'https://example.test'),
  }) async {
    final picked = _Picked();
    var opened = false;
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          if (!opened) {
            opened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              picked.value = await showShareTargetSheet(
                context,
                repo: repo,
                api: _FakeApi(),
                payload: payload,
              );
            });
          }
          return const Scaffold(body: SizedBox.expand());
        }),
      ),
    ));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('lists recent chats, newest first', (tester) async {
    final repo = _FakeRepo(rooms: [
      room('a', name: 'Old chat', lastMessageMs: 1000),
      room('b', name: 'Newest chat', lastMessageMs: 3000),
      room('c', name: 'Middle chat', lastMessageMs: 2000),
    ]);
    await open(tester, repo: repo);

    expect(find.text('SHARE TO'), findsOneWidget);
    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t != null && t.endsWith('chat'))
        .toList();
    expect(rows, ['Newest chat', 'Middle chat', 'Old chat']);
  });

  testWidgets('one tap answers, without a second confirm', (tester) async {
    // The forward sheet arms a multi-selection and needs a SEND press; a share
    // does not. The user already committed by choosing this app in the system
    // sheet — the question left is "which chat", and one tap is the answer.
    final repo = _FakeRepo(rooms: [room('a', name: 'Trip planning')]);
    final picked = await open(tester, repo: repo, payload: const SharedPayload(text: 'hello'));

    await tester.tap(find.text('Trip planning'));
    await tester.pumpAndSettle();

    expect(picked.value, isA<ShareToRoom>());
    expect((picked.value! as ShareToRoom).room.id, 'a');
  });

  testWidgets('offers friends with no chat yet, under their own heading',
      (tester) async {
    // Somebody you have never messaged is exactly who is missing from a
    // "recent chats" list, and is a perfectly ordinary person to send a photo
    // to. A share sheet that can only reach people you already talk to is the
    // wrong shape.
    final repo = _FakeRepo(
      rooms: [room('a', name: 'Trip planning', lastMessageMs: 1)],
      friends: [user('u1', 'Ada')],
    );
    await open(tester, repo: repo);

    expect(find.text('SUGGESTED'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('a friend who already has a DM is not offered twice',
      (tester) async {
    final ada = user('u1', 'Ada');
    final repo = _FakeRepo(
      rooms: [room('dm1', name: 'dm:me:u1', lastMessageMs: 1)],
      friends: [ada],
      peers: {'dm1': ada},
    );
    await open(tester, repo: repo);

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('SUGGESTED'), findsNothing);
  });

  testWidgets('tapping a friend asks for a DM rather than a room',
      (tester) async {
    final repo = _FakeRepo(rooms: const [], friends: [user('u1', 'Ada')]);
    final picked = await open(tester, repo: repo, payload: const SharedPayload(text: 'hello'));

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    // Opening the DM is a mutation and belongs to the caller, after the sheet
    // is gone — a failed round trip must not happen under a modal the user
    // cannot dismiss.
    expect(picked.value, isA<ShareToFriend>());
    expect((picked.value! as ShareToFriend).friend.id, 'u1');
  });

  testWidgets('says how many attachments came in', (tester) async {
    final repo = _FakeRepo(rooms: [room('a', name: 'Trip planning')]);
    await open(
      tester,
      repo: repo,
      payload: const SharedPayload(items: [
        SharedItem(path: '/tmp/1.jpg', mimeType: 'image/jpeg', size: 10),
        SharedItem(path: '/tmp/2.jpg', mimeType: 'image/jpeg', size: 10),
      ]),
    );
    expect(find.text('2 attachments'), findsOneWidget);
  });

  testWidgets('names the cap when the platform refused something', (tester) async {
    // The refusal happened natively, before any copy, so there are no bytes to
    // fall back on. Saying nothing here would read as the share having failed.
    final repo = _FakeRepo(rooms: [room('a', name: 'Trip planning')]);
    await open(
      tester,
      repo: repo,
      payload: const SharedPayload(items: [
        SharedItem(path: '/tmp/1.jpg', mimeType: 'image/jpeg', size: 10),
        SharedItem(
          path: '',
          mimeType: 'video/mp4',
          size: 900000000,
          oversize: true,
        ),
      ]),
    );
    expect(
      find.textContaining('over the 20.0 MB limit'),
      findsOneWidget,
    );
  });

  testWidgets('search narrows both sections', (tester) async {
    final repo = _FakeRepo(
      rooms: [
        room('a', name: 'Trip planning', lastMessageMs: 2),
        room('b', name: 'Book club', lastMessageMs: 1),
      ],
      friends: [user('u1', 'Ada'), user('u2', 'Grace')],
    );
    await open(tester, repo: repo);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    // "Trip planning" and "Ada" and "Grace" all contain an 'a'; "Book club"
    // does not.
    expect(find.text('Book club'), findsNothing);
    expect(find.text('Trip planning'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('never renders Flutter\'s debug text fallback', (tester) async {
    // This app draws no yellow underlines anywhere. A sheet built outside a
    // Material ancestor is exactly how they appear, which is why the root is a
    // `Material(type: transparency)` + `DefaultTextStyle`.
    final repo = _FakeRepo(
      rooms: [room('a', name: 'Trip planning')],
      friends: [user('u1', 'Ada')],
    );
    await open(tester, repo: repo);

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final style = text.style;
      expect(
        style?.decoration,
        anyOf(isNull, TextDecoration.none),
        reason: 'a Text with an underline means no Material ancestor: '
            '"${text.data}"',
      );
    }
    expect(find.byType(Material), findsWidgets);
  });
}

/// Holds the sheet's answer, which arrives after the route pops rather than
/// from the call that opened it.
class _Picked {
  ShareDestination? value;
}

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends Fake implements ChatRepository {
  _FakeRepo({
    required List<ChatRoom> rooms,
    List<ChatUser> friends = const [],
    Map<String, ChatUser> peers = const {},
  })  : _rooms = rooms,
        _friends = friends,
        _peers = peers;

  final List<ChatRoom> _rooms;
  final List<ChatUser> _friends;
  final Map<String, ChatUser> _peers;

  @override
  List<ChatRoom> get rooms => _rooms;

  @override
  List<ChatUser> get friends => _friends;

  @override
  ChatUser? otherUserFor(ChatRoom room) => _peers[room.id];

  @override
  RoomCapabilities capabilitiesFor(ChatRoom room) => RoomCapabilities.group;

  @override
  ChatApi get api => _FakeApi();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
