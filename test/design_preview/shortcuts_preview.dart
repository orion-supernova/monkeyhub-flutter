// Renders the keyboard-shortcut surfaces (⌘K palette, hold-⌘ peek, ⌘/ panel)
// at a desktop window size, in a dark and a light theme.
//
//   flutter test test/design_preview/shortcuts_preview.dart
//
// PNGs land in build/design_preview/shortcuts_*.png.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/keyboard/app_shortcuts.dart';
import 'package:monkeyhub/keyboard/escape_to_pop.dart';
import 'package:monkeyhub/keyboard/shortcut_host.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

import 'preview_kit.dart';

class _Repo extends Fake implements ChatRepository {
  _Repo(this.activeRooms);

  @override
  final List<ChatRoom> activeRooms;

  @override
  String? get userId => 'me';

  @override
  ChatUser? otherUserFor(ChatRoom room) => null;
}

ChatRoom _room(String id, String name, {int unread = 0}) => ChatRoom(
      id: id,
      name: name,
      createdBy: 'me',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: 4,
      unreadCount: unread,
    );

final _rooms = [
  _room('1', 'Family', unread: 3),
  _room('2', 'Weekend hike crew'),
  _room('3', 'Design review'),
  _room('4', 'Şükrü & Ayşe'),
  _room('5', 'Book club', unread: 1),
  _room('6', 'Flatmates'),
];

void main() {
  setUpAll(loadPreviewFonts);
  const desktop = Size(1280, 800);

  Widget shell(AppTheme theme, GlobalKey<NavigatorState> nav) => previewApp(
        theme,
        Navigator(
          key: nav,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ShortcutHost(
              navigatorKey: nav,
              repo: _Repo(_rooms),
              onOpenRoom: (_) {},
              child: EscapeToPop(
                navigatorKey: nav,
                child: ShortcutBindings(
                  // What an open chat on a desktop window binds.
                  bindings: {
                    AppShortcuts.search: () {},
                    AppShortcuts.newChat: () {},
                    AppShortcuts.nextChat: () {},
                    AppShortcuts.previousChat: () {},
                    AppShortcuts.nextUnread: () {},
                    AppShortcuts.roomInfo: () {},
                    AppShortcuts.searchInChat: () {},
                    AppShortcuts.jumpToLatest: () {},
                    AppShortcuts.attach: () {},
                    AppShortcuts.voiceCall: () {},
                    AppShortcuts.videoCall: () {},
                    AppShortcuts.emoji: () {},
                  },
                  child: Builder(
                    builder: (context) => Stack(
                      children: [
                        theme.backgroundLayer(context),
                        const Focus(autofocus: true, child: SizedBox.expand()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  for (final (name, theme) in [
    ('midnight', BasicTheme.midnight()),
    ('daylight', BasicTheme.daylight()),
  ]) {
    testWidgets('palette $name', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await snap(
        tester,
        shell(theme, nav),
        '/private/tmp/claude-501/-Users-muratcankoc-Documents-Projects-monkeyhub-flutter-monkeyhub/5c97f795-b529-43ef-991b-e5951f794673/scratchpad/shortcuts_palette_$name.png',
        size: desktop,
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
        act: () async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.enterText(find.byType(TextField), 'f');
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        },
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('peek $name', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await snap(
        tester,
        shell(theme, nav),
        '/private/tmp/claude-501/-Users-muratcankoc-Documents-Projects-monkeyhub-flutter-monkeyhub/5c97f795-b529-43ef-991b-e5951f794673/scratchpad/shortcuts_peek_$name.png',
        size: desktop,
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
        act: () async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
          await tester.pump(const Duration(milliseconds: 700));
        },
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('panel $name', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await snap(
        tester,
        shell(theme, nav),
        '/private/tmp/claude-501/-Users-muratcankoc-Documents-Projects-monkeyhub-flutter-monkeyhub/5c97f795-b529-43ef-991b-e5951f794673/scratchpad/shortcuts_panel_$name.png',
        size: desktop,
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
        act: () async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.slash);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        },
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
