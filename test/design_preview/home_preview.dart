// Renders a realistic home chat list to PNG under every theme.
//
//   flutter test test/design_preview/home_preview.dart
//
// Output: kPreviewDir/home_<themeId>.png (see preview_kit.dart). Not a test of
// behaviour — it asserts nothing beyond "it rendered". Edit [_rooms] to try
// other data; edit [_FakeHome] to mirror a layout change before shipping it.
import 'dart:io';
import 'dart:typed_data';


import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_mute.dart';
import 'package:monkeyhub/screens/navigation/pill_bottom_nav.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_list_row.dart';
import 'package:monkeyhub/widgets/chat_row_swipe.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/room_card.dart';
import 'package:monkeyhub/widgets/room_filter_bar.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

import 'preview_kit.dart';

final _now = DateTime.now();
DateTime _ago(Duration d) => _now.subtract(d);

ChatUser _user(String id, String name, {String? status}) =>
    ChatUser(id: id, username: id, name: name, status: status, lastSeen: _now);

final _me = _user('me', 'Murat Can');
final _ece = _user('u_ece', 'Ece', status: 'online');
final _deniz = _user('u_deniz', 'Deniz Kaya', status: 'away');
final _mom = _user('u_mom', 'Mom', status: 'offline');

/// One row of the fake list: the room plus what the repository would have
/// resolved for it (the DM peer, who is typing).
typedef _Row = ({ChatRoom room, ChatUser? dmUser, List<ChatUser> typists});

List<_Row> _rooms() => [
      (
        room: ChatRoom(
          id: 'saved',
          name: 'dm:self:me',
          createdBy: 'me',
          createdAt: _ago(const Duration(days: 90)),
          isPrivate: true,
          memberCount: 1,
          lastMessage: 'Passport renewal — bring 2 photos',
          lastMessageTime: _ago(const Duration(days: 2)),
          lastReadAt: _now,
          isPinned: true,
          participantIds: ['me'],
        ),
        dmUser: null,
        typists: const <ChatUser>[],
      ),
      (
        room: ChatRoom(
          id: 'ece',
          name: 'dm:me:u_ece',
          createdBy: 'me',
          createdAt: _ago(const Duration(days: 40)),
          isPrivate: true,
          memberCount: 2,
          lastMessage: 'ok see you at 8 then',
          lastMessageTime: _ago(const Duration(minutes: 2)),
          unreadCount: 2,
          participantIds: ['me', 'u_ece'],
        ),
        dmUser: _ece,
        typists: const <ChatUser>[],
      ),
      (
        room: ChatRoom(
          id: 'crew',
          name: 'Weekend Crew',
          createdBy: 'u_deniz',
          createdAt: _ago(const Duration(days: 120)),
          isPrivate: true,
          memberCount: 6,
          lastMessage: 'Deniz: @murat are you driving or should I?',
          lastMessageTime: _ago(const Duration(minutes: 14)),
          unreadCount: 3,
          hasMention: true,
        ),
        dmUser: null,
        typists: const <ChatUser>[],
      ),
      (
        room: ChatRoom(
          id: 'deniz',
          name: 'dm:me:u_deniz',
          createdBy: 'u_deniz',
          createdAt: _ago(const Duration(days: 300)),
          isPrivate: true,
          memberCount: 2,
          lastMessage: 'Sent a photo',
          lastMessageTime: _ago(const Duration(hours: 1)),
          lastReadAt: _now,
          participantIds: ['me', 'u_deniz'],
        ),
        dmUser: _deniz,
        typists: [_deniz],
      ),
      (
        room: ChatRoom(
          id: 'mom',
          name: 'dm:me:u_mom',
          createdBy: 'u_mom',
          createdAt: _ago(const Duration(days: 500)),
          isPrivate: true,
          memberCount: 2,
          lastMessage: 'Did you eat? Call me when you can',
          lastMessageTime: _ago(const Duration(hours: 3)),
          lastReadAt: _now,
          participantIds: ['me', 'u_mom'],
        ),
        dmUser: _mom,
        typists: const <ChatUser>[],
      ),
      (
        room: ChatRoom(
          id: 'secret',
          name: 'Surprise for Ece',
          createdBy: 'me',
          createdAt: _ago(const Duration(days: 3)),
          isPrivate: true,
          memberCount: 4,
          lastMessage: 'Arda: cake is ordered, don’t tell her',
          lastMessageTime: _ago(const Duration(hours: 5)),
          lastReadAt: _now,
          type: RoomType.secret,
          messageLifetime: const Duration(hours: 24),
        ),
        dmUser: null,
        typists: const <ChatUser>[],
      ),
      (
        room: ChatRoom(
          id: 'flat',
          name: 'Flat 4B',
          createdBy: 'u_arda',
          createdAt: _ago(const Duration(days: 200)),
          isPrivate: true,
          memberCount: 5,
          lastMessage: 'Arda: who left the oven on',
          lastMessageTime: _ago(const Duration(hours: 9)),
          unreadCount: 12,
          mute: const RoomMute(notifications: true, untilMs: kMuteAlwaysMs),
        ),
        dmUser: null,
        typists: const <ChatUser>[],
      ),
      (
        room: ChatRoom(
          id: 'public',
          name: 'Istanbul Film Club',
          createdBy: 'u_x',
          createdAt: _ago(const Duration(days: 60)),
          isPrivate: false,
          memberCount: 248,
          lastMessage: 'Screening of Kış Uykusu moved to Thursday',
          lastMessageTime: _ago(const Duration(days: 1)),
          lastReadAt: _now,
        ),
        dmUser: null,
        typists: const <ChatUser>[],
      ),
    ];

/// Minimal re-creation of `_Header` in home_screen.dart (private there).
class _FakeHeader extends StatelessWidget {
  const _FakeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          UserAvatar(user: _me, size: 36, showStatus: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).homeScreenGreeting('murat'),
              style: theme.displayMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accent,
                border: Border.all(
                  color: theme.ink.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(CupertinoIcons.plus, size: 16, color: theme.accentInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// The home screen's layout (HomeScreen.build + _RoomsPanel list branch)
/// with the repository swapped for [_rooms].
class _FakeHome extends StatelessWidget {
  const _FakeHome({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final all = [for (final r in rows) r.room];
    final pinned = [for (final r in rows) if (r.room.isPinned) r];
    final regular = [for (final r in rows) if (!r.room.isPinned) r];
    Widget card(_Row r) => RoomCard(
          room: r.room,
          dmUser: r.dmUser,
          typists: r.typists,
          onTap: () {},
        );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _FakeHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 110),
                    children: [
                      RoomFilterBar(
                        filter: RoomFilter.empty,
                        counts: RoomFacetCounts.projected(all, RoomFilter.empty),
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 6),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final r in pinned) card(r),
                            if (pinned.isNotEmpty) const SizedBox(height: 10),
                            for (final r in regular) card(r),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PillBottomNav(
            active: HomeSection.chat,
            onSelect: (_) {},
            badges: const {HomeSection.chat: 5},
          ),
        ],
      ),
    );
  }
}

/// The redesigned home: iOS bar + large title + [ChatListRow]s. Mirrors
/// `HomeScreen.build` / `_Header` / `_LargeTitle` after the redesign.
class _FakeHomeV2 extends StatelessWidget {
  const _FakeHomeV2({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final all = [for (final r in rows) r.room];
    final ordered = [
      for (final r in rows) if (r.room.isPinned) r,
      for (final r in rows) if (!r.room.isPinned) r,
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 60, 0, 110),
                    children: [
                      ...[
                        RoomFilterBar(
                          filter: RoomFilter.empty,
                          counts:
                              RoomFacetCounts.projected(all, RoomFilter.empty),
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < ordered.length; i++)
                              ChatRowSwipe(
                                leading: [
                                  SwipeAction(
                                    label: 'Pin',
                                    icon: CupertinoIcons.pin_fill,
                                    color: const Color(0xFFFF9500),
                                    onTap: () {},
                                  ),
                                ],
                                trailing: [
                                  SwipeAction(
                                    label: 'Mute',
                                    icon: CupertinoIcons.bell_slash_fill,
                                    color: const Color(0xFF5856D6),
                                    onTap: () {},
                                  ),
                                  SwipeAction(
                                    label: 'Archive',
                                    icon: CupertinoIcons.archivebox_fill,
                                    color: const Color(0xFF8E8E93),
                                    onTap: () {},
                                  ),
                                ],
                                child: ChatListRow(
                                  room: ordered[i].room,
                                  dmUser: ordered[i].dmUser,
                                  typists: ordered[i].typists,
                                  showDivider: i < ordered.length - 1,
                                  onTap: () {},
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 74,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.background,
                          theme.background.withValues(alpha: 0.92),
                          theme.background.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.62, 1],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context).homeScreenTitle,
                            style: theme.bodyEmph.copyWith(
                              color: theme.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              UserAvatar(user: _me, size: 36, showStatus: false),
                              const Spacer(),
                              GlassButtonGroup(
                                tone: GlassTone.app,
                                items: [
                                  GlassGroupItem(
                                    icon: CupertinoIcons.search,
                                    semanticLabel: 'Search',
                                    onTap: () {},
                                  ),
                                  GlassGroupItem(
                                    icon: CupertinoIcons.square_pencil,
                                    semanticLabel: 'New',
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PillBottomNav(
            active: HomeSection.chat,
            onSelect: (_) {},
            badges: const {HomeSection.chat: 5},
          ),
        ],
      ),
    );
  }
}

/// Only the v2 renders: `flutter test ... --plain-name v2`.
const _v2Themes = {
  'basic', 'basic_daylight', 'basic_graphite',
  'risograph_pop', 'retro_wave',
};

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    // No SF Pro on Linux: stand Inter in for the Cupertino family names so
    // the renders read as text rather than Ahem boxes.
    for (final family in const [
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      final loader = FontLoader(family);
      for (final w in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(() async {
          final b = await File('assets/google_fonts/Inter-$w.ttf').readAsBytes();
          return ByteData.sublistView(b);
        }());
      }
      await loader.load();
    }
  });

  for (final theme in ThemeController.all) {
    if (_v2Themes.contains(theme.id)) {
      testWidgets('v2 home preview: ${theme.id}', (tester) async {
        await snap(
          tester,
          previewApp(theme, _FakeHomeV2(rows: _rooms())),
          'v2_home_${theme.id}.png',
        );
      });
    }
    if (_v2Themes.contains(theme.id)) {
      testWidgets('swipe preview: ${theme.id}', (tester) async {
        await snap(
          tester,
          previewApp(theme, _FakeHomeV2(rows: _rooms())),
          'swipe_${theme.id}.png',
          // One row: opening a second would (correctly) close the first,
          // and the capture would catch it mid-close.
          act: () => tester.drag(find.text('Ece'), const Offset(-150, 0)),
        );
      });
    }
    testWidgets('home preview: ${theme.id}', (tester) async {
      await snap(
        tester,
        previewApp(theme, _FakeHome(rows: _rooms())),
        'home_${theme.id}.png',
      );
    });
    // The whole list on one tall canvas, so the rows below the fold
    // (muted, ephemeral, public) can be judged too.
    testWidgets('home preview (full list): ${theme.id}', (tester) async {
      await snap(
        tester,
        previewApp(theme, _FakeHome(rows: _rooms())),
        'home_${theme.id}_full.png',
        size: const Size(393, 1560),
        dpr: 2,
      );
    });
  }
}
