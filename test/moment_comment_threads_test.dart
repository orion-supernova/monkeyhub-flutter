import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_comment.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_comments_sheet.dart';

import 'design_preview/preview_kit.dart';

/// A highlight's comment threads: up to three replies just show; a longer
/// thread folds behind "View N replies".
void main() {
  final now = DateTime.now();
  MomentComment c(String id, String text, {String? parent}) => MomentComment(
    id: id,
    userId: 'u$id',
    userName: 'Name$id',
    createdAt: now.subtract(const Duration(minutes: 5)),
    isAuthor: false,
    mine: false,
    canDelete: false,
    parentId: parent,
    text: text,
    reactionCounts: const {},
    myReactions: const {},
  );
  final moment = Moment(
    id: 'm',
    userId: 'me',
    dayKey: '2026-10-13',
    createdAt: now,
    expiresAt: now.add(const Duration(hours: 20)),
    authorName: 'Me',
    authorUsername: 'me',
    mine: true,
    seen: true,
  );

  testWidgets('short threads show, long ones fold', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    MomentConversation.debugComments = [
      c('a', 'root one'),
      c('a1', 'only reply', parent: 'a'),
      c('b', 'root two'),
      for (var i = 1; i <= 3; i++) c('b$i', 'b reply $i', parent: 'b'),
      c('z', 'root three'),
      for (var i = 1; i <= 4; i++) c('z$i', 'z reply $i', parent: 'z'),
    ];
    addTearDown(() => MomentConversation.debugComments = null);
    await tester.pumpWidget(previewApp(
      ThemeController.byId('basic'),
      Material(
        type: MaterialType.transparency,
        child: MomentConversation(
          moment: moment,
          api: ChatApi(ConvexBackend.instance),
          feedApi: FeedApi(ConvexBackend.instance),
          userId: 'me',
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('only reply', findRichText: true), findsOneWidget);
    expect(find.textContaining('b reply 3', findRichText: true), findsOneWidget);
    expect(find.text('View 1 reply'), findsNothing);
    expect(find.text('View 3 replies'), findsNothing);
    expect(find.textContaining('z reply 1', findRichText: true), findsNothing);
    expect(find.text('View 4 replies'), findsOneWidget);
    await tester.tap(find.text('View 4 replies'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('z reply 4', findRichText: true), findsOneWidget);
  });

  testWidgets('the rail ends on the last reply, or on the toggle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    MomentConversation.debugComments = [
      c('lone', 'no replies'),
      c('a', 'root one'),
      c('a1', 'only reply', parent: 'a'),
      c('b', 'root two'),
      for (var i = 1; i <= 3; i++) c('b$i', 'b reply $i', parent: 'b'),
      c('z', 'root three'),
      for (var i = 1; i <= 5; i++) c('z$i', 'z reply $i', parent: 'z'),
    ];
    MomentConversation.debugExpanded = {};
    addTearDown(() {
      MomentConversation.debugComments = null;
      MomentConversation.debugExpanded = null;
    });
    await tester.pumpWidget(previewApp(
      ThemeController.byId('basic'),
      Material(
        type: MaterialType.transparency,
        child: MomentConversation(
          moment: moment,
          api: ChatApi(ConvexBackend.instance),
          feedApi: FeedApi(ConvexBackend.instance),
          userId: 'me',
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    List<MomentRail> rails() => [
      for (final w in tester.widgetList<MomentThreadRail>(
        find.byType(MomentThreadRail),
      ))
        w.rail,
    ];
    const s = MomentRail.start, t = MomentRail.through, e = MomentRail.end;
    // A root alone hangs no rail; folded, the rail runs root to toggle.
    expect(rails(), [s, e, s, t, t, e, s, e]);
    await tester.tap(find.text('View 5 replies'));
    await tester.pump(const Duration(milliseconds: 600));
    // Opened, every reply is on the way to "Hide replies".
    expect(rails(), [s, e, s, t, t, e, s, t, t, t, t, t, e]);
  });
}
