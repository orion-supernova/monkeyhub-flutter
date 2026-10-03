// Renders a realistic transcript — runs, a reply, a reaction, a day marker —
// with the real MessageBubble under a few themes.
//
//   flutter test test/design_preview/chat_preview.dart
//
// The transcript rows are laid out the way RoomScreen lays them out (owner of
// the gap above, MessageGap rhythm); the header and composer are the real
// widgets where they can stand alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/screens/room_screen.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/reply_indicator.dart';

import 'package:monkeyhub/screens/navigation/native_tab_bar.dart';

import 'preview_kit.dart';

final _api = ChatApi(ConvexBackend.instance);
final _day = DateTime(2026, 10, 2, 21, 0);
final _ece =
    ChatUser(id: 'ece', username: 'ece', name: 'Ece', status: 'online');
const _noCaps = RoomCapabilities(
  canCall: false,
  canLeave: true,
  canDelete: false,
  hasDescription: false,
  hasMembers: true,
  hasPeerHandle: false,
  canEditSettings: false,
  canOpenPeerProfile: false,
  canReceiveForwards: true,
  canSaveMessages: true,
  canMute: true,
);
final _dm = ChatRoom(
  id: 'dm1',
  name: 'dm:regular:me:ece',
  createdBy: 'me',
  createdAt: _day,
  isPrivate: true,
  memberCount: 2,
  participantIds: const ['me', 'ece'],
);
final _group = ChatRoom(
  id: 'g1',
  name: 'Weekend Crew',
  createdBy: 'me',
  createdAt: _day,
  isPrivate: true,
  memberCount: 6,
  participantIds: const ['me', 'ece'],
);

int _n = 0;
ChatMessage _m(
  String from,
  String text, {
  int min = 0,
  ReplyPreview? reply,
  List<String> reactions = const [],
  MessageStatus status = MessageStatus.sent,
}) {
  final id = 'm${_n++}';
  return ChatMessage(
    id: id,
    roomId: 'r',
    senderId: from,
    senderName: from == 'me' ? 'Murat' : 'Ece',
    content: text,
    createdAt: _day.add(Duration(minutes: min)),
    status: status,
    replyToId: reply == null ? null : 'x',
    replyToPreview: reply,
    reactions: [
      for (final (i, e) in reactions.indexed)
        MessageReaction(
          id: '$id-r$i',
          messageId: id,
          userId: i.isEven ? 'me' : 'ece',
          emoji: e,
          createdAt: _day,
        ),
    ],
  );
}

List<ChatMessage> _transcript() => [
      _m('ece', 'are you still coming tonight?', min: 0),
      _m('ece', 'Deniz said the place closes at 11', min: 0),
      _m('me', 'yes! leaving in 10', min: 2),
      _m('me', 'should I bring anything?', min: 2, reactions: ['❤']),
      _m(
        'ece',
        'just yourself. and maybe that playlist from last week, it was so good',
        min: 4,
        reply: const ReplyPreview(
          senderId: 'me',
          senderName: 'Murat',
          contentPreview: 'should I bring anything?',
          type: MessageType.text,
        ),
      ),
      _m(
        'me',
        'deal',
        min: 5,
        reply: const ReplyPreview(
          senderId: 'ece',
          senderName: 'Ece',
          contentPreview: 'just yourself. and maybe that playlist from last week',
          type: MessageType.text,
        ),
      ),
      _m('me', 'on my way', min: 12, status: MessageStatus.sent),
    ];

class _Transcript extends StatelessWidget {
  const _Transcript();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final msgs = _transcript();
    final rows = <Widget>[];
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final prev = i > 0 ? msgs[i - 1] : null;
      final next = i < msgs.length - 1 ? msgs[i + 1] : null;
      final grouped = prev != null && prev.senderId == m.senderId;
      final last = next == null || next.senderId != m.senderId;
      // No spacer: each MessageBubble owns the gap above it (MessageGap).
      rows.add(MessageBubble(
        message: m,
        now: _day.add(const Duration(minutes: 20)),
        currentUserId: 'me',
        api: _api,
        author: m.senderId == 'me' ? null : _ece,
        grouped: grouped,
        lastInRun: last,
        // A DM reclaims the avatar column.
        showAvatarSlot: false,
        seenByOthers: i < msgs.length - 1,
        deliveredToOthers: true,
      ));
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 90),
              children: rows,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  debugRoomHeader(
                    room: _dm,
                    api: _api,
                    caps: _noCaps,
                    dmUser: _ece,
                    typists: [_ece],
                  ),
                  debugRoomHeader(
                    room: _group,
                    api: _api,
                    caps: _noCaps,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ChatComposerLiquid(
              controller: TextEditingController(text: 'see you in a bit'),
              ephemeral: false,
              onSend: () {},
              onAttach: () {},
              onCamera: () {},
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  // Render as an iOS 26 phone on the default Liquid Glass setting, which is
  // what most people see: app-drawn glass wears the matched recipe.
  setUp(() => NativeChrome.debugSupported = true);
  tearDown(() => NativeChrome.debugSupported = false);
  for (final id in ['basic', 'basic_daylight', 'risograph_pop', 'vault_noir']) {
    testWidgets('chat preview: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _Transcript()),
        'chat_$id.png',
      );
    });
  }
  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('classic chrome: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _ClassicChrome()),
        'chat_classic_$id.png',
      );
    });
  }
  testWidgets('reply styles', (tester) async {
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), const _ReplyStyles()),
      'chat_reply_styles.png',
    );
  });
}

class _ReplyStyles extends StatelessWidget {
  const _ReplyStyles();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    const preview = ReplyPreview(
      senderId: 'me',
      senderName: 'Murat',
      contentPreview: 'should I bring anything?',
      type: MessageType.text,
    );
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 40),
        children: [
          for (final s in ReplyStyle.values) ...[
            Text(s.name, style: theme.caption),
            ReplyIndicator(
              preview: preview,
              isMine: false,
              parentIsMine: true,
              api: _api,
              onTap: () {},
              styleOverride: s,
            ),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }
}


class _ClassicChrome extends StatelessWidget {
  const _ClassicChrome();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            debugRoomHeader(
              room: _dm,
              api: _api,
              caps: _noCaps,
              dmUser: _ece,
              typists: [_ece],
              classic: true,
            ),
            debugRoomHeader(
              room: _group,
              api: _api,
              caps: _noCaps,
              classic: true,
            ),
            const Spacer(),
            ChatComposerClassic(
              controller: TextEditingController(text: 'see you in a bit'),
              ephemeral: false,
              onSend: () {},
              onAttach: () {},
              onCamera: () {},
            ),
            ChatComposerClassic(
              controller: TextEditingController(),
              ephemeral: false,
              onSend: () {},
              onAttach: () {},
              onCamera: () {},
            ),
          ],
        ),
      ),
    );
  }
}
