import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_content_item.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/media_filmstrip.dart';

/// What this pins: **the gallery fetches older media as the reader nears the
/// oldest picture it holds, without moving the one on screen.**
///
///  * An oldest-first set (the transcript's) grows at its start; the page on
///    screen, the filmstrip's ring and the result on close all stay on the
///    same message.
///  * A batch is deduped by id, asked for one request at a time, and never
///    again once the loader says there is no more.
///  * A newest-first set (the grid's) grows at its end.
class _FakeApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  final api = _FakeApi();

  ChatMessage photo(String id) => ChatMessage(
        id: id,
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'Ada',
        content: '',
        createdAt: DateTime(2026, 1, 1, 12, id.codeUnitAt(0)),
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

  Future<Future<ChatMessage?>> open(
    WidgetTester tester, {
    required List<ChatMessage> items,
    required int initialIndex,
    required Future<RoomContentPage> Function(ChatMessage oldest) loadOlder,
    bool newestFirst = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
      loadOlder: loadOlder,
      newestFirst: newestFirst,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return result;
  }

  MediaFilmstrip strip(WidgetTester tester) =>
      tester.widget<MediaFilmstrip>(find.byType(MediaFilmstrip));

  /// The page whose left edge is at the screen's: the one being looked at.
  bool onScreen(WidgetTester tester, String id) {
    final f = find.byKey(ValueKey<String>(id));
    return f.evaluate().isNotEmpty && tester.getTopLeft(f).dx.abs() < 0.5;
  }

  Future<void> swipeBack(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
  }

  testWidgets('older media slides in before the start, the page stays put',
      (tester) async {
    final asked = <String>[];
    final result = await open(
      tester,
      items: [photo('c'), photo('d'), photo('e')],
      initialIndex: 0,
      loadOlder: (oldest) async {
        asked.add(oldest.id);
        // 'c' again: the pager must not show it twice.
        return RoomContentPage(
          items: [photo('a'), photo('b'), photo('c')],
          hasMore: false,
        );
      },
    );
    await tester.pumpAndSettle();

    expect(asked, ['c'], reason: 'opened on the oldest: asked at once');
    expect(strip(tester).count, 5);
    expect(strip(tester).index, 2);
    expect(onScreen(tester, 'c'), isTrue);

    // Back through the new ones; the loader said there is no more.
    await swipeBack(tester);
    expect(onScreen(tester, 'b'), isTrue);
    await swipeBack(tester);
    expect(onScreen(tester, 'a'), isTrue);
    expect(strip(tester).index, 0);
    expect(asked, ['c']);

    // Escape rather than the close button: the flings above can toggle the
    // chrome away, and the close path is the same either way.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect((await result)?.id, 'a');
  });

  testWidgets('one request at a time, and a batch waits for the swipe to end',
      (tester) async {
    final pending = <Completer<RoomContentPage>>[];
    final asked = <String>[];
    await open(
      tester,
      items: [photo('m'), photo('n'), photo('o'), photo('p'), photo('q')],
      initialIndex: 4,
      loadOlder: (oldest) {
        asked.add(oldest.id);
        final c = Completer<RoomContentPage>();
        pending.add(c);
        return c.future;
      },
    );
    // Four pages from the oldest: past the lead, nothing asked.
    expect(asked, isEmpty);
    await swipeBack(tester); // index 3: within three pages
    expect(asked, ['m']);
    await swipeBack(tester); // index 2: still in flight, no second request
    expect(asked, ['m']);
    expect(onScreen(tester, 'o'), isTrue);

    // Answer mid-drag: nothing may move until the finger lifts.
    final drag = await tester.startGesture(const Offset(200, 400));
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    pending.single.complete(RoomContentPage(
      items: [photo('k'), photo('l')],
      hasMore: true,
    ));
    await tester.pump();
    expect(strip(tester).count, 5, reason: 'held while the pages move');
    await drag.moveBy(const Offset(-40, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(strip(tester).count, 7);
    expect(strip(tester).index, 4);
    expect(onScreen(tester, 'o'), isTrue);
    // Index 4 is past the lead again, so no new request yet.
    expect(asked, ['m']);
    await swipeBack(tester); // index 3
    expect(asked, ['m', 'k']);
    pending.last.complete(const RoomContentPage(items: [], hasMore: false));
    await tester.pumpAndSettle();
    await swipeBack(tester);
    expect(asked, ['m', 'k'], reason: 'exhausted: never asked again');
  });

  testWidgets('a newest-first set grows at its end', (tester) async {
    final result = await open(
      tester,
      items: [photo('e'), photo('d'), photo('c')],
      initialIndex: 1,
      newestFirst: true,
      loadOlder: (oldest) async {
        expect(oldest.id, 'c');
        return RoomContentPage(items: [photo('a'), photo('b')], hasMore: false);
      },
    );
    await tester.pumpAndSettle();
    expect(strip(tester).count, 5);
    expect(strip(tester).index, 1);
    expect(onScreen(tester, 'd'), isTrue);

    // Forward is older here: c, then b.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(onScreen(tester, 'b'), isTrue);
    // Escape rather than the close button: the flings above can toggle the
    // chrome away, and the close path is the same either way.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect((await result)?.id, 'b');
  });
}
