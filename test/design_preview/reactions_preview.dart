// Reaction badges hanging off bubbles, WhatsApp's way: mine and theirs, one
// chip and a run that wraps onto a second line, a short bubble whose stamp
// sits right where the badge hangs, and a jumbo emoji with no bubble at all.
//
//   flutter test test/design_preview/reactions_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';

import 'preview_kit.dart';

final _api = ChatApi(ConvexBackend.instance);
final _day = DateTime(2026, 10, 2, 21, 0);
final _ece =
    ChatUser(id: 'ece', username: 'ece', name: 'Ece', status: 'online');

int _n = 0;
ChatMessage _m(String from, String text, List<(String, String)> reactions) {
  final id = 'm${_n++}';
  return ChatMessage(
    id: id,
    roomId: 'r',
    senderId: from,
    senderName: from == 'me' ? 'Murat' : 'Ece',
    content: text,
    createdAt: _day.add(Duration(minutes: _n)),
    status: MessageStatus.sent,
    reactions: [
      for (final (i, (who, e)) in reactions.indexed)
        MessageReaction(
          id: '$id-r$i',
          messageId: id,
          userId: who,
          emoji: e,
          createdAt: _day,
        ),
    ],
  );
}

List<ChatMessage> _transcript() => [
      _m('ece', 'are you still coming tonight?', [('me', '👍')]),
      _m('ece', 'ok', [('me', '❤️'), ('ece', '❤️')]),
      _m('me', 'yes! leaving in 10', [('ece', '🔥')]),
      _m('me', 'k', [('ece', '😂'), ('me', '😂')]),
      _m('me', 'no reactions on this one, just checking the rhythm', []),
      _m('ece', 'the playlist from last week was so good, send it again?', [
        ('me', '👍'), ('ece', '❤️'), ('me', '😂'), ('ece', '😮'),
        ('me', '😢'), ('ece', '🔥'), ('me', '🎉'), ('ece', '🙏'),
        ('me', '💯'), ('ece', '👏'),
      ]),
      _m('me', 'sure', []),
      _m('me', '🎉', [('ece', '🎉')]),
      _m('ece', 'see you', []),
    ];

class _Transcript extends StatelessWidget {
  const _Transcript({required this.group});
  final bool group;

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
      rows.add(MessageBubble(
        message: m,
        now: _day.add(const Duration(minutes: 20)),
        currentUserId: 'me',
        api: _api,
        author: m.senderId == 'me' ? null : _ece,
        grouped: grouped,
        lastInRun: last,
        showAvatarSlot: group,
        showAvatar: last,
        seenByOthers: true,
        deliveredToOthers: true,
        onReactionTap: (_) {},
        onReactionLongPress: (_) {},
      ));
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final id in ['basic', 'basic_daylight', 'vault_noir', 'risograph_pop']) {
    testWidgets('reactions preview: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), _Transcript(group: id == 'basic')),
        'reactions_$id.png',
      );
    });
  }
}
