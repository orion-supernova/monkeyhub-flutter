// Renders the chat list in all three layouts (rows, cards, grid), with a
// live call, a typist, unread, muted, pinned, secret and quiet rooms, on a
// phone and in the desktop pane, light and dark, English and Turkish.
//
//   flutter test test/design_preview/chat_list_layouts_preview.dart
//
// Output: build/design_preview/chat_list_<layout>_<form>_<theme>_<locale>.png
// Not a test of behaviour. Mirrors `_RoomsPanel` in home_screen.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/live_calls_store.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_mute.dart';
import 'package:monkeyhub/theme/density.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_list_row.dart';
import 'package:monkeyhub/widgets/room_card.dart';
import 'package:monkeyhub/widgets/room_filter_bar.dart';
import 'package:monkeyhub/widgets/room_grid_tile.dart';

import 'preview_kit.dart';

final _now = DateTime.now();
DateTime _ago(Duration d) => _now.subtract(d);

ChatUser _user(String id, String name) =>
    ChatUser(id: id, username: id, name: name, status: 'online', lastSeen: _now);

final _ece = _user('u_ece', 'Ece');
final _deniz = _user('u_deniz', 'Deniz Kaya');
final _mom = _user('u_mom', 'Mom');

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
          lastMessage: 'Passport renewal, bring 2 photos',
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
          id: 'crew',
          name: 'Weekend Crew',
          createdBy: 'u_deniz',
          createdAt: _ago(const Duration(days: 120)),
          isPrivate: true,
          memberCount: 6,
          lastMessage: 'Deniz: are you driving or should I?',
          lastMessageTime: _ago(const Duration(minutes: 4)),
          unreadCount: 3,
          hasMention: true,
          isPinned: true,
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
          lastMessage: 'ok see you at 8 then, bring the projector',
          lastMessageTime: _ago(const Duration(minutes: 2)),
          unreadCount: 2,
          participantIds: ['me', 'u_ece'],
        ),
        dmUser: _ece,
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
          hasPassword: true,
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
      (
        room: ChatRoom(
          id: 'quiet',
          name: 'Book swap',
          createdBy: 'me',
          createdAt: _ago(const Duration(days: 6)),
          isPrivate: false,
          memberCount: 3,
        ),
        dmUser: null,
        typists: const <ChatUser>[],
      ),
    ];

List<LiveRoomCall> _calls() => [
      LiveRoomCall(
        roomId: 'crew',
        groupCallId: 'gc1',
        video: true,
        count: 3,
        mine: false,
        startedAt: _ago(const Duration(minutes: 4, seconds: 12)),
      ),
      LiveRoomCall(
        roomId: 'mom',
        video: false,
        count: 2,
        mine: true,
        startedAt: _ago(const Duration(minutes: 17, seconds: 3)),
      ),
    ];

enum _Layout { rows, cards, grid }

class _List extends StatelessWidget {
  const _List({required this.layout, required this.desktop});
  final _Layout layout;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final rows = _rooms();
    final all = [for (final r in rows) r.room];
    final ordered = [
      for (final r in rows) if (r.room.isPinned) r,
      for (final r in rows) if (!r.room.isPinned) r,
    ];
    final m = RoomGridMetrics.of(Density.of(context));
    final Widget body = switch (layout) {
      _Layout.rows => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < ordered.length; i++)
                ChatListRow(
                  room: ordered[i].room,
                  dmUser: ordered[i].dmUser,
                  typists: ordered[i].typists,
                  showDivider: i < ordered.length - 1,
                  onTap: () {},
                ),
            ],
          ),
        ),
      _Layout.cards => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in ordered)
                RoomCard(
                  room: r.room,
                  dmUser: r.dmUser,
                  typists: r.typists,
                  onTap: () {},
                ),
            ],
          ),
        ),
      _Layout.grid => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, box) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: m.columnsFor(box.maxWidth),
                mainAxisSpacing: m.spacing,
                crossAxisSpacing: m.spacing,
                mainAxisExtent: RoomGridMetrics.extentFor(context),
              ),
              itemCount: ordered.length,
              itemBuilder: (context, i) => RoomGridTile(
                room: ordered[i].room,
                dmUser: ordered[i].dmUser,
                typists: ordered[i].typists,
                onTap: () {},
              ),
            ),
          ),
        ),
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    AppLocalizations.of(context).homeScreenTitle,
                    style: theme.displayLarge.copyWith(letterSpacing: 0.37),
                  ),
                ),
                if (desktop)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RoomFilterSegments(
                      filter: RoomFilter({RoomFacet.unread, RoomFacet.mentions}),
                      counts: RoomFacetCounts.projected(all, RoomFilter.empty),
                      onChanged: (_) {},
                    ),
                  )
                else
                  RoomFilterBar(
                    filter: RoomFilter.empty,
                    counts: RoomFacetCounts.projected(all, RoomFilter.empty),
                    onChanged: (_) {},
                  ),
                const SizedBox(height: 14),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _themes = {'basic', 'basic_daylight', 'risograph_pop'};

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  for (final theme in ThemeController.all) {
    if (!_themes.contains(theme.id)) continue;
    for (final locale in const ['en', 'tr']) {
      for (final layout in _Layout.values) {
        for (final desktop in const [false, true]) {
          if (theme.id == 'risograph_pop' && (locale == 'tr' || desktop)) {
            continue;
          }
          final form = desktop ? 'desktop' : 'phone';
          testWidgets('${layout.name} $form ${theme.id} $locale', (t) async {
            if (desktop) debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
            LiveCallsStore.instance.debugShow(_calls());
            try {
              await snap(
                t,
                previewApp(
                  theme,
                  _List(layout: layout, desktop: desktop),
                  locale: Locale(locale),
                ),
                'chat_list_${layout.name}_${form}_${theme.id}_$locale.png',
                size: desktop ? const Size(360, 1100) : const Size(393, 1150),
                dpr: 2,
                topInset: desktop ? 0 : kIphoneTopInset,
                bottomInset: 0,
              );
              await t.pumpWidget(const SizedBox());
            } finally {
              LiveCallsStore.instance.debugShow(const []);
              debugDefaultTargetPlatformOverride = null;
            }
          });
        }
      }
    }
  }
}
