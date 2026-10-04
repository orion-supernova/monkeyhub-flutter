import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/media_filmstrip.dart';

/// What this pins: **the gallery's chrome says who and when, and its toolbar
/// offers only what the reader may do.**
///
///  * The subtitle is when the picture was sent — "Today at 14:32" — not
///    "3 / 8"; the filmstrip already says where in the set this is.
///  * Share, Save and Forward show for any picture the opener can act on;
///    the trash only on the reader's own.
///  * Deleting the current picture leaves the reader on its neighbour, and
///    deleting the last one closes the gallery.
class _FakeApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  final api = _FakeApi();
  final now = DateTime.now();

  ChatMessage photo(String id, {String sender = 'u1', DateTime? at}) =>
      ChatMessage(
        id: id,
        roomId: 'r1',
        senderId: sender,
        senderName: 'Ada',
        content: '',
        createdAt: at ?? DateTime(now.year, now.month, now.day, 14, 32),
        type: MessageType.image,
        mediaStorageId: 'stor_$id',
        mediaWidth: 1200,
        mediaHeight: 1600,
      );

  Widget host(Widget home) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<Future<int?>> open(
    WidgetTester tester, {
    required List<ChatMessage> items,
    int initialIndex = 0,
    MediaPagerActions? actions,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    })));
    final result = MediaPagerScreen.open(
      ctx,
      items: items,
      initialIndex: initialIndex,
      api: api,
      actions: actions,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return result;
  }

  MediaPagerActions actions({Future<bool> Function(ChatMessage m)? onDelete}) =>
      MediaPagerActions(
        currentUserId: 'me',
        onShare: (_) async => true,
        onSave: (_) async => true,
        onForward: (_, _) async => 1,
        onDelete: onDelete ?? (_) async => true,
      );

  testWidgets('the subtitle says when, and the position is for screen readers',
      (tester) async {
    phone(tester);
    await open(tester, items: [photo('a'), photo('b'), photo('c')], initialIndex: 1);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Today at 14:32'), findsOneWidget);
    expect(find.text('2 / 3'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Item 2 of 3')), findsWidgets);
  });

  testWidgets('no actions, no toolbar', (tester) async {
    phone(tester);
    await open(tester, items: [photo('a'), photo('b')]);
    expect(find.byIcon(CupertinoIcons.square_arrow_up), findsNothing);
    expect(find.byIcon(CupertinoIcons.trash), findsNothing);
    // The rail is the gallery's — 40pt tiles.
    expect(find.byType(MediaFilmstrip), findsOneWidget);
    expect(
      tester.widget<MediaFilmstrip>(find.byType(MediaFilmstrip)).viewer,
      isTrue,
    );
  });

  testWidgets("someone else's picture: share, save, forward — no trash",
      (tester) async {
    phone(tester);
    await open(tester, items: [photo('a', sender: 'u1')], actions: actions());
    expect(find.byIcon(CupertinoIcons.square_arrow_up), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_down_to_line), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrowshape_turn_up_right), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.trash), findsNothing);
    // A set of one has no filmstrip.
    expect(find.byType(MediaFilmstrip), findsNothing);
  });

  testWidgets('deleting your own picture asks, then lands on its neighbour',
      (tester) async {
    phone(tester);
    final deleted = <String>[];
    final result = await open(
      tester,
      items: [photo('a', sender: 'me'), photo('b', sender: 'me'), photo('c')],
      initialIndex: 0,
      actions: actions(onDelete: (m) async {
        deleted.add(m.id);
        return true;
      }),
    );
    await tester.tap(find.byIcon(CupertinoIcons.trash));
    await tester.pumpAndSettle();
    // The confirm sheet, not an instant delete.
    expect(deleted, isEmpty);
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    expect(deleted, ['a']);

    // Still open, now on b, with two left in the rail.
    expect(find.byType(MediaPagerScreen), findsOneWidget);
    expect(
      tester.widget<MediaFilmstrip>(find.byType(MediaFilmstrip)).count,
      2,
    );
    expect(
      tester.widget<MediaFilmstrip>(find.byType(MediaFilmstrip)).index,
      0,
    );

    // Close: the index handed back is b's in the set the opener passed in.
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(await result, 1);
  });

  testWidgets('deleting the only picture closes the gallery', (tester) async {
    phone(tester);
    await open(
      tester,
      items: [photo('a', sender: 'me')],
      actions: actions(),
    );
    await tester.tap(find.byIcon(CupertinoIcons.trash));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPagerScreen), findsNothing);
  });
}
