@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/composer_reply_card.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_context_menu.dart';
import 'package:monkeyhub/widgets/photo_mosaic.dart' show MosaicTile;
import 'package:monkeyhub/widgets/reaction_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An album answers to reactions and replies as a whole as well as photo by
/// photo. The whole-album ones ride on its first message, flagged, and are
/// drawn under the stack rather than on a card; the long-press menu opens on
/// the whole album with a switch to the pressed photo.
void main() {
  final api = ChatApi(ConvexBackend.instance);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MessageReaction reaction(String emoji, {bool album = false}) =>
      MessageReaction(
        id: 'r_$emoji$album',
        messageId: 'm0',
        userId: 'bob',
        emoji: emoji,
        createdAt: DateTime(2026),
        album: album,
      );

  ChatMessage photo(String id, {List<MessageReaction>? reactions}) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1),
        type: MessageType.image,
        albumId: 'alb',
        reactions: reactions,
      );

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  testWidgets('album reactions sit under the stack, a photo\'s on its card',
      (tester) async {
    final album = [
      photo('m0', reactions: [reaction('❤️', album: true), reaction('👍')]),
      photo('m1'),
      photo('m2'),
    ];
    final stackTaps = <String>[];
    await tester.pumpWidget(host(MessageBubble(
      message: album.last,
      now: DateTime(2026, 3, 1),
      currentUserId: 'bob',
      api: api,
      album: album,
      onAlbumReactionTap: (m, e) {},
      onAlbumStackReactionTap: (first, e) => stackTaps.add('${first.id}$e'),
    )));
    await tester.pump();

    final rows = tester.widgetList<ReactionRow>(find.byType(ReactionRow));
    final onCard = find.descendant(
        of: find.byType(MosaicTile), matching: find.byType(ReactionRow));
    final cardRows = tester.widgetList<ReactionRow>(onCard).toList();
    expect(cardRows, hasLength(1));
    expect(cardRows.single.reactions.map((r) => r.emoji), ['👍']);
    final stackRow = rows.firstWhere((r) => !cardRows.contains(r));
    expect(stackRow.reactions.map((r) => r.emoji), ['❤️']);

    stackRow.onToggle('❤️');
    expect(stackTaps, ['m0❤️']);
  });

  testWidgets('the menu opens on the whole album and switches to one photo',
      (tester) async {
    final anchor = GlobalKey();
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return SizedBox(key: anchor, width: 200, height: 240);
    })));

    Future<MessageActionResult?> open() => showMessageActionMenu(
          context: ctx,
          anchorKey: anchor,
          bubbleBuilder: (_) => const SizedBox.expand(),
          isMine: false,
          capabilities: MessageCapabilities.none.copyWith(canReply: true),
          album: MessageMenuAlbum(
            allLabel: 'All 3',
            oneLabel: 'This one',
            capabilities: MessageCapabilities.none.copyWith(canReply: true),
          ),
        );

    var result = open();
    await tester.pumpAndSettle();
    expect(find.text('All 3'), findsOneWidget);
    expect(find.text('This one'), findsOneWidget);
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect((await result)?.album, isTrue);

    result = open();
    await tester.pumpAndSettle();
    await tester.tap(find.text('This one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    final picked = await result;
    expect(picked?.emoji, '👍');
    expect(picked?.album, isFalse);
  });

  testWidgets('a reply to the whole album says how many', (tester) async {
    await tester.pumpWidget(host(ComposerReplyCard(
      parent: photo('m0'),
      api: api,
      albumCount: 4,
      onCancel: () {},
    )));
    await tester.pump();
    expect(find.text('4 items'), findsOneWidget);
  });

  testWidgets('the right-click menu has the same switch', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MessageActionResult? got;
    await tester.pumpWidget(host(SizedBox.expand(
      child: Stack(children: [
        MessageContextMenu(
          position: const Offset(300, 200),
          capabilities: MessageCapabilities.none.copyWith(canReply: true),
          album: MessageMenuAlbum(
            allLabel: 'All 3',
            oneLabel: 'This one',
            capabilities: MessageCapabilities.none.copyWith(canReply: true),
          ),
          onResolve: (r) => got = r,
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.text('All 3'), findsOneWidget);
    await tester.tap(find.text('This one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect(got?.emoji, '👍');
    expect(got?.album, isFalse);
  });
}
