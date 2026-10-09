// Renders the app's sheets, menus and toasts over a page, under a few themes.
//
//   flutter test test/design_preview/sheets_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_group.dart';
import 'package:monkeyhub/screens/create_room_sheet.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/discover_rows.dart';
import 'package:monkeyhub/widgets/ios_kit.dart' show PageSectionHeader;
import 'package:monkeyhub/widgets/moment_rail.dart';
import 'package:monkeyhub/widgets/pull_reveal_panel.dart';
import 'package:monkeyhub/widgets/app_toast.dart';
import 'package:monkeyhub/widgets/destructive_sheet.dart';
import 'package:monkeyhub/widgets/join_room_sheet.dart';
import 'package:monkeyhub/widgets/mute_room_sheet.dart';
import 'package:monkeyhub/widgets/new_chat_menu.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

import 'preview_kit.dart';

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends Fake implements ChatRepository {
  _FakeRepo(this._friends);
  final List<ChatUser> _friends;
  @override
  List<ChatUser> get friends => _friends;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final _friends = [
  for (final n in ['Ece', 'Deniz Kaya', 'Mom', 'Arda', 'Zeynep', 'Kerem',
      'Selin', 'Mert'])
    ChatUser(id: 'u_$n', username: n.toLowerCase().split(' ').first, name: n),
];

final _room = ChatRoom(
  id: 'r1',
  name: 'Istanbul Film Club',
  createdBy: 'x',
  createdAt: DateTime(2026),
  isPrivate: false,
  memberCount: 248,
  description: 'Weekly picks, Sunday screenings, no spoilers.',
  participantIds: const [],
);

/// A page with something on it, so the dim and the sheet's edge read.
class _Page extends StatefulWidget {
  const _Page({required this.open});
  final void Function(BuildContext context) open;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
        children: [
          Text('Chats', style: theme.displayLarge),
          for (var i = 0; i < 9; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                CircleAvatar(radius: 26, backgroundColor: theme.surfaceRaised),
                const SizedBox(width: 14),
                Expanded(child: Text('Conversation $i', style: theme.bodyEmph)),
              ]),
            ),
        ],
      ),
    );
  }
}

final Map<String, void Function(BuildContext)> _sheets = {
  'confirm': (c) => showConfirmSheet(
        c,
        headline: 'Delete this chat?',
        body: 'Every message in it goes, for everyone.',
        confirmLabel: 'DELETE CHAT',
      ),
  'actions': (c) => showIosActionSheet<int>(
        c,
        title: 'Weekend Crew',
        actions: const [
          IosSheetAction(label: 'Mark as read', value: 1),
          IosSheetAction(label: 'Pin', value: 2),
          IosSheetAction(label: 'Leave group', value: 3, destructive: true),
        ],
      ),
  'newchat': (c) => showNewChatMenu(
        c,
        repo: _FakeRepo(_friends),
        api: _FakeApi(),
        canCreateRoom: true,
        canJoinByCode: true,
      ),
  'join': (c) => showJoinRoomSheet(c, _room, _FakeApi()),
  'mute': (c) => showMuteRoomSheet(
        c,
        repo: _FakeRepo(const []),
        room: _room,
      ),
  'create': (c) => showAdaptiveSheet(
        c,
        useSafeArea: true,
        builder: (_) => CreateRoomSheet(repo: _FakeRepo(const []), api: _FakeApi()),
      ),
  'toast': (c) => AppToast.of(c).show(
        'Pinned to the top',
        actionLabel: 'Undo',
        onAction: () {},
      ),
};

Moment _moment(String id, String who, {bool seen = false, String? caption}) =>
    Moment(
      id: id,
      userId: 'u_$who',
      dayKey: '2026-10-03',
      createdAt: DateTime(2026, 10, 3),
      expiresAt: DateTime(2026, 10, 4),
      authorName: who,
      authorUsername: who.toLowerCase(),
      mine: false,
      seen: seen,
      caption: caption,
    );

/// Discover's rows, the home pull-down panel and the story rail on one page.
class _Bits extends StatelessWidget {
  const _Bits();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 70, 0, 40),
        children: [
          PullRevealSlot(
            panelKey: GlobalKey(),
            dragExtent: 0,
            dragThreshold: 64,
            instant: true,
            open: true,
            searchCtrl: TextEditingController(),
            searchFocus: FocusNode(),
            onSearchChanged: (_) {},
            onClearSearch: () {},
            archivedCount: 4,
            onOpenArchived: () {},
            onCollapse: () {},
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageSectionHeader('Public rooms', count: '87',
                    actionLabel: 'See all', onAction: () {}),
                PublicRoomTile(room: _room, onTap: () {}),
                PublicRoomTile(
                  room: ChatRoom(
                    id: 'r2',
                    name: 'Late Night Lo-fi',
                    createdBy: 'x',
                    createdAt: DateTime(2026),
                    isPrivate: false,
                    memberCount: 31,
                    hasPassword: true,
                    participantIds: const [],
                  ),
                  joined: true,
                  onTap: () {},
                ),
                FriendRow(user: _friends[0], api: _FakeApi(), onTap: () {}),
                const SizedBox(height: 16),
                MomentRail(
                  groups: MomentGroup.of([
                    _moment('m1', 'Ece', caption: 'first snow on the balcony'),
                    _moment('m2', 'Deniz Kaya', seen: true,
                        caption: 'new job!!'),
                    _moment('m3', 'Arda', caption: 'guess where'),
                  ]),
                  api: _FakeApi(),
                  serverNow: DateTime(2026, 10, 3),
                  onCapture: () {},
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final id in const ['basic', 'basic_daylight', 'risograph_pop']) {
    testWidgets('bits: $id', (tester) async {
      await _snapAfterOpen(
        tester,
        previewApp(ThemeController.byId(id), const _Bits()),
        'bits_$id.png',
      );
    });
  }
  const themes = ['basic', 'basic_daylight', 'risograph_pop'];
  for (final id in themes) {
    for (final e in _sheets.entries) {
      testWidgets('sheet ${e.key}: $id', (tester) async {
        await _snapAfterOpen(
          tester,
          previewApp(ThemeController.byId(id), _Page(open: e.value)),
          'sheet_${e.key}_$id.png',
        );
      });
    }
  }
}

/// [snap], but stepping the clock frame by frame afterwards: a route pushed
/// from a post-frame callback only starts its transition on the NEXT frame, so
/// one long pump captures it at t=0.
Future<void> _snapAfterOpen(
  WidgetTester tester,
  Widget widget,
  String name,
) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = kIphone16Pro * dpr;
  final pad = FakeViewPadding(
    top: kIphoneTopInset * dpr,
    bottom: kIphoneBottomInset * dpr,
  );
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: widget));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final out = File('$kPreviewDir/$name');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!);
}
