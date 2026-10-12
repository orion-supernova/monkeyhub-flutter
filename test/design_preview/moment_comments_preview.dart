// A highlight's comments sheet: a thread opened under its root, an author
// reply with the badge, a reply-to-a-reply's "@name", a sticker comment, likes
// and other reactions — light and dark.
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
  _c('d', 'Can', text: 'ok this is wallpaper material', minutes: 8),
  _c('e', 'Selin', text: 'POSTCARD', minutes: 2, counts: {'🔥': 3, '❤️': 2}),
  _c('f', 'Selin', text: 'reply under Can', parent: 'd', minutes: 1),
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
  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('moment comments preview: $id', (tester) async {
      MomentConversation.debugComments = _fixture;
      addTearDown(() => MomentConversation.debugComments = null);
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          Builder(
            builder: (context) => Align(
              alignment: Alignment.bottomCenter,
              child: MomentConversation(
                moment: _moment,
                api: ChatApi(ConvexBackend.instance),
                feedApi: FeedApi(ConvexBackend.instance),
                userId: 'Murat',
              ),
            ),
          ),
        ),
        'moment_comments_$id.png',
      );
    });
  }
}
