// A highlight's comments sheet, every thread shape on its rail: one reply,
// three inline (with a reply-to-a-reply's "@name"), five folded and five
// opened; an author reply with the badge. Light and dark.
//
//   flutter test test/design_preview/moment_comments_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_comment.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_comments_sheet.dart';

import 'preview_kit.dart';

final _now = DateTime.now();

MomentComment _c(
  String id,
  String name, {
  String? text,
  String? parent,
  String? replyTo,
  bool author = false,
  bool mine = false,
  int minutes = 5,
  Map<String, int> counts = const {},
  Set<String> myReactions = const {},
}) =>
    MomentComment(
      id: id,
      userId: name,
      userName: name,
      createdAt: _now.subtract(Duration(minutes: minutes)),
      isAuthor: author,
      mine: mine,
      canDelete: mine,
      parentId: parent,
      replyToName: replyTo,
      text: text,
      reactionCounts: counts,
      myReactions: myReactions,
    );

final _fixture = [
  // One reply: the rail turns straight into it.
  _c('d', 'Can', text: 'ok this is wallpaper material', minutes: 48),
  _c('d1', 'Selin', text: 'right?? already set it', parent: 'd', minutes: 40),
  // Three replies, inline, one of them answering a reply.
  _c('a', 'Ece',
      text: 'the light in this one 😍 where was this?',
      minutes: 42,
      counts: {'❤️': 4, '😮': 1},
      myReactions: {'❤️'}),
  _c('b', 'Murat',
      text: 'Kaş, last night. It went orange for like 3 minutes',
      parent: 'a',
      author: true,
      mine: true,
      minutes: 30,
      counts: {'❤️': 1}),
  _c('c', 'Deniz',
      text: 'jealous. take me next time',
      parent: 'a',
      replyTo: 'Murat',
      minutes: 12,
      counts: {'😂': 2}),
  _c('c2', 'Ece', text: 'same', parent: 'a', replyTo: 'Deniz', minutes: 10),
  // Five replies, folded.
  _c('e', 'Selin', text: 'POSTCARD', minutes: 9, counts: {'🔥': 3, '❤️': 2}),
  for (var i = 1; i <= 5; i++)
    _c('e$i', ['Can', 'Ece', 'Deniz', 'Murat', 'Can'][i - 1],
        text: 'postcard reply $i', parent: 'e', minutes: 9 - i),
  // Five replies, opened.
  _c('g', 'Deniz', text: 'who took it though', minutes: 6),
  _c('g1', 'Murat', text: 'me, obviously', parent: 'g', author: true, mine: true, minutes: 5),
  _c('g2', 'Deniz', text: 'with what', parent: 'g', replyTo: 'Murat', minutes: 4),
  _c('g3', 'Murat', text: 'my phone 😅', parent: 'g', author: true, mine: true, minutes: 3),
  _c('g4', 'Selin', text: 'no way', parent: 'g', minutes: 2),
  _c('g5', 'Can', text: 'teach me', parent: 'g', replyTo: 'Murat', minutes: 1),
];

final _moment = Moment(
  id: 'm',
  userId: 'Murat',
  dayKey: '2026-10-08',
  createdAt: _now,
  expiresAt: _now.add(const Duration(hours: 20)),
  authorName: 'Murat',
  authorUsername: 'murat',
  mine: true,
  seen: true,
);

void main() {
  setUpAll(loadPreviewFonts);
  for (final (id, rtl) in [
    ('basic', false),
    ('basic_daylight', false),
    ('basic_daylight', true),
  ]) {
    final name = rtl ? '${id}_rtl' : id;
    testWidgets('moment comments preview: $name', (tester) async {
      MomentConversation.debugComments = _fixture;
      MomentConversation.debugExpanded = {'g'};
      addTearDown(() {
        MomentConversation.debugComments = null;
        MomentConversation.debugExpanded = null;
      });
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          Builder(
            // The sheet's TextField wants a Material above it; a transparent
            // one paints nothing.
            builder: (context) => Material(
              type: MaterialType.transparency,
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: MomentConversation(
                  moment: _moment,
                  api: ChatApi(ConvexBackend.instance),
                  feedApi: FeedApi(ConvexBackend.instance),
                  userId: 'Murat',
                ),
              ),
            ),
          ),
        ),
        'moment_comments_$name.png',
        // Tall enough for every thread shape at once.
        size: const Size(393, 2000),
      );
    });
  }
}
