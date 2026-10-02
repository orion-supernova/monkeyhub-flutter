// Renders the expressive themes (Retro Wave, Bio-Organic, Deep Ocean,
// Cyberpunk, Neon Night, Risograph) on the new home and on cards + bubbles.
//
//   flutter test test/design_preview/expressive_preview.dart
//
// Output: build/design_preview/x_home_<id>.png, x_cards_<id>.png.
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
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
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        UserAvatar(user: _me, size: 34, showStatus: false),
                        const Spacer(),
                        LiquidGlass(
                          size: const Size(40, 40),
                          onTap: () {},
                          child: Icon(
                            CupertinoIcons.square_pencil,
                            size: 19,
                            color: theme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          AppLocalizations.of(context).homeScreenTitle,
                          style: theme.displayLarge
                              .copyWith(letterSpacing: 0.37),
                        ),
                      ),
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


/// Cards layout + a short transcript, to judge the theme's card and bubble
/// decorations and its outgoing bubble contrast.
class _CardsAndBubbles extends StatelessWidget {
  const _CardsAndBubbles({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    Widget bubble(String text, {required bool mine}) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: const BoxConstraints(maxWidth: 270),
            decoration: theme.messageBubbleDecoration(
              isMine: mine,
              ephemeral: false,
            ),
            child: Text(
              text,
              style: theme.body.copyWith(
                color: mine ? theme.accentInk : theme.ink,
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                for (final r in rows.take(3))
                  RoomCard(
                    room: r.room,
                    dmUser: r.dmUser,
                    typists: r.typists,
                    onTap: () {},
                  ),
                const SizedBox(height: 16),
                bubble('are we still on for tonight?', mine: false),
                bubble('yes! 8pm at the usual place', mine: true),
                bubble('perfect, I will bring the cake', mine: false),
                bubble('see you there', mine: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _themes = {
  'retro_wave', 'bio_organic', 'deep_ocean', 'cyberpunk', 'neon_night',
  'risograph_pop',
};

void main() {
  setUpAll(loadPreviewFonts);

  for (final theme in ThemeController.all) {
    if (!_themes.contains(theme.id)) continue;
    testWidgets('expressive home: ${theme.id}', (tester) async {
      await snap(
        tester,
        previewApp(theme, _FakeHomeV2(rows: _rooms())),
        'x_home_${theme.id}.png',
      );
    });
    testWidgets('expressive cards: ${theme.id}', (tester) async {
      await snap(
        tester,
        previewApp(theme, _CardsAndBubbles(rows: _rooms())),
        'x_cards_${theme.id}.png',
      );
    });
  }
}
