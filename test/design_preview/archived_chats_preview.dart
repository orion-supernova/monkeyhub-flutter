// Design review: the Archived chats page and the folder row on the chat list.
//
//   flutter test test/design_preview/archived_chats_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/screens/archived_chats_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/archived_folder_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

final _now = DateTime.now();

ChatRoom _room(String id, String name, String last,
        {int unread = 0, int mins = 180, bool isPrivate = true}) =>
    ChatRoom(
      id: id,
      name: name,
      createdBy: 'me',
      createdAt: DateTime(2026),
      isPrivate: isPrivate,
      memberCount: 5,
      lastMessage: last,
      lastMessageTime: _now.subtract(Duration(minutes: mins)),
      isArchived: true,
      unreadCount: unread,
      unreadCountFromServer: true,
      isMember: true,
      participantIds: const [],
    );

List<ChatRoom> _rooms({bool unread = true}) => [
      _room('a', 'Bodrum trip 2025', 'photos are up', unread: unread ? 3 : 0, mins: 12),
      _room('b', 'Old flatmates', 'see you around!', mins: 600),
      _room('c', 'Istanbul Film Club', 'Sunday: Uzak', unread: unread ? 12 : 0, mins: 90, isPrivate: false),
      _room('d', 'Spring hackathon', 'demo is at 5', mins: 3000),
      _room('e', 'Dentist reminders', 'see you Tuesday', unread: unread ? 1 : 0, mins: 4000),
      _room('f', 'Book swap', 'got the novel!', mins: 8000),
      _room('g', 'Uni group project', 'final slides attached', mins: 12000),
    ];

class _Api extends Fake implements ChatApi {}

class _Repo extends Fake implements ChatRepository {
  _Repo(this._list);
  final List<ChatRoom> _list;
  @override
  String? get userId => 'me';
  @override
  List<ChatRoom> get archivedRooms => _list;
  @override
  ChatApi get api => _Api();
  @override
  RoomCapabilities capabilitiesFor(ChatRoom room) => const RoomCapabilities(
        canCall: false, canLeave: true, canDelete: false, hasDescription: false,
        hasMembers: true, hasPeerHandle: false, canEditSettings: false,
        canOpenPeerProfile: false, canReceiveForwards: true,
        canSaveMessages: true, canMute: true,
      );
  @override
  ChatUser? otherUserFor(ChatRoom room) => null;
  @override
  List<ChatUser> typingIn(String roomId) => const [];
  @override
  List<ChatMessage> messagesFor(String roomId) => const [];
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('page unread: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id),
            ArchivedChatsScreen(repo: _Repo(_rooms()), api: _Api())),
        'arch_page_unread_$id.png',
        settle: const Duration(seconds: 3),
        act: () async {},
      );
    });
    testWidgets('page allread: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id),
            ArchivedChatsScreen(repo: _Repo(_rooms(unread: false)), api: _Api())),
        'arch_page_read_$id.png',
        settle: const Duration(seconds: 3),
        act: () async {},
      );
    });
  }
  testWidgets('page search no match', (tester) async {
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'),
          ArchivedChatsScreen(repo: _Repo(_rooms()), api: _Api())),
      'arch_page_nomatch.png',
      settle: const Duration(seconds: 2),
      act: () async {
        await tester.enterText(find.byType(EditableText), 'zzzz');
        await tester.pump();
      },
    );
  });
  testWidgets('page search film', (tester) async {
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'),
          ArchivedChatsScreen(repo: _Repo(_rooms()), api: _Api())),
      'arch_page_search.png',
      settle: const Duration(seconds: 2),
      act: () async {
        await tester.enterText(find.byType(EditableText), 'film');
        await tester.pump();
      },
    );
  });
  testWidgets('folder row', (tester) async {
    await snap(
      tester,
      previewApp(
        ThemeController.byId('basic'),
        Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 16, 0),
            child: Column(children: [
              ArchivedFolderRow(
                totalCount: 7,
                unreadRooms: 3,
                unreadTitles: const ['Bodrum trip 2025', 'Istanbul Film Club', 'Dentist reminders'],
                onTap: () {},
              ),
              ArchivedFolderRow(
                totalCount: 7,
                unreadRooms: 0,
                unreadTitles: const [],
                onTap: () {},
              ),
            ]),
          ),
        ),
      ),
      'arch_folder_row.png',
    );
  });
}
