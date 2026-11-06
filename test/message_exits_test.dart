import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/view_once_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/dust_dissolve.dart';
import 'package:monkeyhub/widgets/message_exits.dart';

/// The exits ledger. Deleting (or a vanish burn) turns a row to dust: only a row that is being deleted, only one
/// on screen, and the list closes over it afterwards. Frames are pumped by
/// hand throughout.
void main() {
  ChatMessage msg(String id, int at, {DateTime? expiresAt, DateTime? vanishUntil}) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: 'me',
    senderName: 'me',
    content: id,
    createdAt: DateTime(2026, 3, 1, 12, 0, at),
    expiresAt: expiresAt,
    vanishUntil: vanishUntil,
  );

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  group('a transcript', () {
    late List<ChatMessage> source;
    late MessageExits exits;
    late StateSetter rebuild;
    final keys = <String, GlobalKey>{};

    Widget list() => MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final shown = exits.withHeld(source);
            return ListView(
              children: [
                for (final m in shown)
                  Builder(
                    builder: (_) {
                      final key = keys.putIfAbsent(m.id, GlobalKey.new);
                      exits.registerRow(m.id, [m.id], key);
                      return KeyedSubtree(
                        key: key,
                        child: DissolvingRow(
                          entry: exits.entryFor(m.id),
                          onGone: () => exits.end(m.id),
                          child: SizedBox(
                            height: 100,
                            child: ColoredBox(
                              color: const Color(0xFF3060F0),
                              child: Text(m.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );

    setUp(() {
      keys.clear();
      source = [for (var i = 0; i < 20; i++) msg('m$i', i)];
      exits = MessageExits(onChanged: () => rebuild(() {}));
    });

    testWidgets('a deleted row dissolves, closes, and is gone', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      final below = tester.getTopLeft(find.text('m2')).dy;
      // Idle rows are just rows: no dissolve wrapper is built until a delete
      // starts, which is what keeps a long fling at full frame rate.
      expect(find.byType(DustDissolve), findsNothing);

      // As the screen does: the ledger first, then the optimistic removal.
      expect(exits.begin([source[1]]), 1);
      source = [for (final m in source) if (m.id != 'm1') m];
      rebuild(() {});
      await tester.pump();
      // Held: still drawn, still taking its place, and now burning.
      expect(find.text('m1'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      // Only the burning row has one.
      expect(
        tester.widget<DustDissolve>(find.byType(DustDissolve)).active,
        isTrue,
      );
      expect(tester.getTopLeft(find.text('m2')).dy, below);

      await pumpFor(
        tester,
        DustDissolve.defaultDuration + DissolvingRow.collapseDuration,
      );
      expect(find.text('m1'), findsNothing);
      // The row below has moved up into the space.
      expect(tester.getTopLeft(find.text('m2')).dy, below - 100);
      expect(exits.isEmpty, isTrue);
    });

    testWidgets('a row that leaves without a delete just goes', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      // Paging, a window sliding: the row is simply not in the list any more,
      // and nobody asked the ledger.
      source = source.sublist(1);
      rebuild(() {});
      await tester.pump();
      expect(find.text('m0'), findsNothing);
      expect(
        tester
            .widgetList<DustDissolve>(find.byType(DustDissolve))
            .any((d) => d.active),
        isFalse,
      );
    });

    testWidgets('offscreen rows are not held; a selection goes as a wave', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      // 600pt of screen shows six rows; m15 is well below the fold.
      expect(exits.begin([source[2], source[0], source[15]]), 2);
      expect(exits.isHeld('m15'), isFalse);
      // Top to bottom, a beat apart, sharing one budget.
      final first = exits.entryFor('m0')!;
      final second = exits.entryFor('m2')!;
      expect(first.delay, Duration.zero);
      expect(second.delay, MessageExits.stagger);
      expect(
        first.particles + second.particles,
        lessThanOrEqualTo(MessageExits.defaultBudget),
      );
      await pumpFor(tester, const Duration(seconds: 2));
      expect(exits.isEmpty, isFalse, reason: 'still listed: hidden');
      expect(find.text('m0'), findsNothing);
      expect(find.text('m2'), findsNothing);
      // The server stops listing them: forgotten.
      source = [
        for (final m in source)
          if (m.id != 'm0' && m.id != 'm2' && m.id != 'm15') m,
      ];
      rebuild(() {});
      await tester.pump();
      expect(exits.isEmpty, isTrue);
    });

    testWidgets('a failed delete gives the row back', (tester) async {
      await tester.pumpWidget(list());
      exits.begin([source[0]]);
      await pumpFor(tester, const Duration(milliseconds: 200));
      exits.cancel(['m0']);
      await tester.pump();
      await tester.pump();
      expect(find.text('m0'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('m0'), findsOneWidget);
    });

    testWidgets('a held send is one row while its local copy is listed', (
      tester,
    ) async {
      // The server's copy is deleted and held for its dust, while the list is
      // (again) drawing the optimistic tmp_ row that names it as serverId. The
      // arrivals ledger keys both as the tmp_ row: splicing the held copy back
      // as well would put two rows on one key.
      final sent = ChatMessage(
        id: 'srv_1',
        roomId: 'r',
        senderId: 'me',
        senderName: 'me',
        content: 'sent',
        createdAt: DateTime(2026, 3, 1, 11, 59),
        clientId: 'tmp_1',
      );
      source = [sent, ...source];
      await tester.pumpWidget(list());
      expect(exits.begin([sent]), 1);
      final local = ChatMessage(
        id: 'tmp_1',
        roomId: 'r',
        senderId: 'me',
        senderName: 'me',
        content: 'sent',
        createdAt: sent.createdAt,
      )..serverId = 'srv_1';
      final shown = exits.withHeld([
        local,
        for (final m in source)
          if (m.id != 'srv_1') m,
      ]);
      expect(shown.where((m) => m.identities.contains('srv_1')).length, 1);
    });

    testWidgets('a held row stays hidden while the server still lists it', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      expect(exits.begin([source[1]]), 1);
      await pumpFor(
        tester,
        DustDissolve.defaultDuration + DissolvingRow.collapseDuration,
      );
      // The server has not caught up: m1 is still in the delivery.
      rebuild(() {});
      await tester.pump();
      expect(find.text('m1'), findsNothing);
      expect(exits.hasExited('m1'), isTrue);
      expect(exits.withHeld(source).map((m) => m.id), isNot(contains('m1')));
      // Then it stops being listed: forgotten, and the list is handed back.
      source = [for (final m in source) if (m.id != 'm1') m];
      expect(identical(exits.withHeld(source), source), isTrue);
      expect(exits.hasExited('m1'), isFalse);
    });

    testWidgets('a remote removal of a vanish message plays the dust exit', (
      tester,
    ) async {
      final burning = msg('v', -1, vanishUntil: DateTime(2030));
      source = [burning, ...source];
      await tester.pumpWidget(list());
      expect(
        exits.observeServerRemovals((serial: 1, ids: {'v'}), source),
        1,
      );
      expect(exits.entryFor('v')!.reason, ExitReason.vanished);
      expect(exits.captureFor('v'), isNull, reason: 'not the hurricane');
      expect(exits.isExpiring('v'), isFalse);
      // The server stopped sending it, as it does.
      source = source.sublist(1);
      rebuild(() {});
      await tester.pump();
      expect(find.text('v'), findsOneWidget, reason: 'held for its dust');
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester
            .widgetList<DustDissolve>(find.byType(DustDissolve))
            .any((d) => d.active),
        isTrue,
      );
      await pumpFor(
        tester,
        DustDissolve.defaultDuration + DissolvingRow.collapseDuration,
      );
      expect(find.text('v'), findsNothing);
    });

    testWidgets('a remote removal of an ordinary message is a delete', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      expect(exits.observeServerRemovals((serial: 1, ids: {'m1'}), source), 1);
      expect(exits.entryFor('m1')!.reason, ExitReason.deleted);
      // The same serial again is the same delivery.
      expect(exits.observeServerRemovals((serial: 1, ids: {'m3'}), source), 0);
    });

    testWidgets('a remote removal of off-screen rows just goes', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      expect(exits.observeServerRemovals((serial: 1, ids: {'m15'}), source), 0);
      expect(exits.isHeld('m15'), isFalse);
      expect(exits.isEmpty, isTrue);
    });

    testWidgets('a burst of removals is not a deletion anyone watched', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      final ids = {for (var i = 0; i < 13; i++) 'm$i'};
      expect(exits.observeServerRemovals((serial: 1, ids: ids), source), 0);
      expect(exits.isEmpty, isTrue);
    });

    testWidgets('an ephemeral row is never taken', (tester) async {
      source = [msg('e', 0, expiresAt: DateTime(2030)), ...source];
      await tester.pumpWidget(list());
      expect(exits.begin([source.first]), 0);
    });
  });

  group('an expired secret message', () {
    final born = DateTime(2026, 3, 1, 12);

    ChatMessage emsg(String id, {int minute = 0, bool ephemeral = true}) =>
        ChatMessage(
          id: id,
          roomId: 'r',
          senderId: 'alice',
          senderName: 'alice',
          content: 'm $id',
          createdAt: born.add(Duration(minutes: minute)),
          expiresAt: ephemeral ? born.add(Duration(minutes: minute + 10)) : null,
          type: MessageType.text,
          status: MessageStatus.sent,
        );

    const outline = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );

    /// A row with a capturable bubble in it, under the ledger's keys.
    Widget host(MessageExits ledger, String rowKey) {
      final rowBox = GlobalKey();
      ledger.registerExpiringRow(rowKey, rowBox);
      return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                KeyedSubtree(
                  key: rowBox,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, left: 8),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: RepaintBoundary(
                        key: ledger.anchorKeyFor(rowKey),
                        child: const SizedBox(
                          width: 120,
                          height: 40,
                          child: ColoredBox(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }

    test('withHeld hands back the very same list while nothing departs', () {
      final ledger = MessageExits(onChanged: () {});
      addTearDown(ledger.dispose);
      final timeline = [emsg('a'), emsg('b', minute: 1)];
      expect(identical(ledger.withHeld(timeline), timeline), isTrue);
    });

    testWidgets('a clock expiry rasters the bubble after the frame', (
      tester,
    ) async {
      var changes = 0;
      final ledger = MessageExits(onChanged: () => changes++);
      addTearDown(ledger.dispose);
      await tester.pumpWidget(host(ledger, 'k'));

      ledger.requestExpiry('k', emsg('a'), isMine: true, outline: outline);
      // Twice on the same tick is one capture.
      ledger.requestExpiry('k', emsg('a'), isMine: true, outline: outline);
      expect(ledger.isExpiring('k'), isFalse, reason: 'not until the frame ends');
      await tester.pump();

      expect(ledger.isExpiring('k'), isTrue);
      expect(changes, 1);
      final cap = ledger.captureFor('k')!;
      expect(cap.image, isNotNull);
      expect(cap.bubbleSize, const Size(120, 40));
      expect(cap.rowSize.height, 50, reason: 'the row is the bubble plus its gap');
      expect(cap.bubbleInRow, const Offset(8, 10));
      expect(cap.isMine, isTrue);
      expect(cap.outline.contains(const Offset(60, 20)), isTrue);
      expect(cap.outline.contains(const Offset(0.5, 0.5)), isFalse,
          reason: 'the corner is outside the rounded outline');

      // A later request for the same row changes nothing.
      ledger.requestExpiry('k', emsg('a'), isMine: true, outline: outline);
      await tester.pump();
      expect(changes, 1);
    });

    testWidgets('a row still on its optimistic id never departs', (tester) async {
      final ledger = MessageExits(onChanged: () {});
      addTearDown(ledger.dispose);
      await tester.pumpWidget(host(ledger, 'tmp_1'));
      ledger.requestExpiry('tmp_1', emsg('tmp_1'),
          isMine: true, outline: outline);
      await tester.pump();
      expect(ledger.isExpiring('tmp_1'), isFalse);
    });

    testWidgets('a message that has blown away stays away until the server '
        'drops it', (tester) async {
      final ledger = MessageExits(onChanged: () {});
      addTearDown(ledger.dispose);
      await tester.pumpWidget(host(ledger, 'a'));
      final live = [emsg('a'), emsg('b', minute: 1)];
      ledger.requestExpiry('a', emsg('a'),
          isMine: false, outline: outline);
      await tester.pump();
      expect(ledger.isExpiring('a'), isTrue);
      ledger.end('a');
      expect(ledger.hasExited('a'), isTrue);
      // The server still lists it — the delete is a round trip away — so the
      // row stays hidden rather than coming back as an expired bubble that
      // would blow up again.
      expect(ledger.withHeld(live).map((m) => m.id), ['b']);
      // The server dropped it: forgotten, and the list is handed back as is.
      final after = [emsg('b', minute: 1)];
      expect(identical(ledger.withHeld(after), after), isTrue);
      expect(ledger.hasExited('a'), isFalse);
    });

    testWidgets('a server removal is captured synchronously, once', (
      tester,
    ) async {
      var changes = 0;
      final ledger = MessageExits(onChanged: () => changes++);
      addTearDown(ledger.dispose);
      await tester.pumpWidget(host(ledger, 'a'));

      final previous = [emsg('a'), emsg('b', minute: 1), emsg('p', minute: 2, ephemeral: false)];
      final current = [emsg('b', minute: 1)];
      void observe() => ledger.observeExpiredRemoval(
            previous,
            current,
            keyFor: (m) => m.id,
            isMine: (_) => false,
            outlineFor: (_) => outline,
          );
      observe();
      expect(ledger.isExpiring('a'), isTrue, reason: 'taken before any frame');
      expect(ledger.captureFor('a')!.image, isNotNull);
      expect(ledger.isExpiring('p'), isFalse,
          reason: 'a plain message leaving is not an exit');
      expect(changes, 1);
      observe();
      expect(changes, 1, reason: 'the same removal seen twice is one departure');
    });

    testWidgets('a ghost is spliced back in at its place, then ends', (
      tester,
    ) async {
      final ledger = MessageExits(onChanged: () {});
      addTearDown(ledger.dispose);
      await tester.pumpWidget(host(ledger, 'b'));

      final b = emsg('b', minute: 1);
      ledger.observeExpiredRemoval(
        [emsg('a'), b, emsg('c', minute: 2)],
        [emsg('a'), emsg('c', minute: 2)],
        keyFor: (m) => m.id,
        isMine: (_) => false,
        outlineFor: (_) => outline,
      );
      final timeline = [emsg('a'), emsg('c', minute: 2)];
      final merged = ledger.withHeld(timeline);
      expect(merged.map((m) => m.id), ['a', 'b', 'c']);
      expect(identical(ledger.withHeld(timeline), merged), isTrue,
          reason: 'memoised on the timeline instance');

      // Still present in the delivery — no duplicate.
      final withB = [emsg('a'), b, emsg('c', minute: 2)];
      expect(ledger.withHeld(withB).map((m) => m.id), ['a', 'b', 'c']);

      final image = ledger.captureFor('b')!.image!;
      ledger.end('b');
      expect(ledger.isExpiring('b'), isFalse);
      expect(image.debugDisposed, isTrue, reason: 'the raster is freed');
      expect(identical(ledger.withHeld(timeline), timeline), isTrue);
    });

    testWidgets('keeps its own exit: a capture, never dust', (tester) async {
      final ledger = MessageExits(onChanged: () {});
      addTearDown(ledger.dispose);
      await tester.pumpWidget(host(ledger, 'a'));
      ledger.observeExpiredRemoval(
        [emsg('a')],
        const [],
        keyFor: (m) => m.id,
        isMine: (_) => false,
        outlineFor: (_) => outline,
      );
      expect(ledger.captureFor('a'), isNotNull);
      expect(ledger.entryFor('a'), isNull, reason: 'no dust for a secret');
      expect(ledger.captureFor('a')!.message.id, 'a');
      // And a delete never takes an ephemeral row, even a registered one.
      ledger.registerRow('a', ['a'], GlobalKey());
      expect(ledger.begin([emsg('a')]), 0);
    });
  });

  group('view-once photo', () {
    Uint8List png() =>
        Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30)));

    Widget host(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

    testWidgets('closing burns the picture, then the viewer goes', (
      tester,
    ) async {
      final bytes = png();
      var burns = 0;
      var closed = false;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await ViewOnceViewer.open(
                  context,
                  bytes: bytes,
                  onBurn: () => burns++,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byType(ViewOnceViewer), findsOneWidget);

      // Back is a close, and a close is a burn.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(burns, 1);
      expect(
        tester.widget<DustDissolve>(find.byType(DustDissolve)).active,
        isTrue,
      );
      expect(find.byType(ViewOnceViewer), findsOneWidget);

      await pumpFor(
        tester,
        DustDissolve.defaultDuration + const Duration(milliseconds: 400),
      );
      expect(find.byType(ViewOnceViewer), findsNothing);
      expect(closed, isTrue);
      expect(burns, 1);
    });

    testWidgets('leaving the app closes it at once, no burn', (tester) async {
      final bytes = png();
      var burns = 0;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ViewOnceViewer.open(
                context,
                bytes: bytes,
                onBurn: () => burns++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        tester
            .widgetList<DustDissolve>(find.byType(DustDissolve))
            .any((d) => d.active),
        isFalse,
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byType(ViewOnceViewer), findsNothing);
      expect(burns, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
