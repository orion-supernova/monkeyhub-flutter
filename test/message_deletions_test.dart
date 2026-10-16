import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/screens/view_once_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/dust_dissolve.dart';
import 'package:monkeyhub/widgets/message_deletions.dart';

/// Deleting turns a row to dust: only a row that is being deleted, only one
/// on screen, and the list closes over it afterwards. Frames are pumped by
/// hand throughout.
void main() {
  ChatMessage msg(String id, int at, {DateTime? expiresAt}) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: 'me',
    senderName: 'me',
    content: id,
    createdAt: DateTime(2026, 3, 1, 12, 0, at),
    expiresAt: expiresAt,
  );

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  group('a transcript', () {
    late List<ChatMessage> source;
    late MessageDeletions deletions;
    late StateSetter rebuild;
    final keys = <String, GlobalKey>{};

    Widget list() => MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final shown = deletions.withHeld(source);
            return ListView(
              children: [
                for (final m in shown)
                  Builder(
                    builder: (_) {
                      final key = keys.putIfAbsent(m.id, GlobalKey.new);
                      deletions.registerRow(m.id, [m.id], key);
                      return KeyedSubtree(
                        key: key,
                        child: DissolvingRow(
                          entry: deletions.entryFor(m.id),
                          onGone: () => deletions.end(m.id),
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
      deletions = MessageDeletions(onChanged: () => rebuild(() {}));
    });

    testWidgets('a deleted row dissolves, closes, and is gone', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      final below = tester.getTopLeft(find.text('m2')).dy;

      // As the screen does: the ledger first, then the optimistic removal.
      expect(deletions.begin([source[1]]), 1);
      source = [for (final m in source) if (m.id != 'm1') m];
      rebuild(() {});
      await tester.pump();
      // Held: still drawn, still taking its place, and now burning.
      expect(find.text('m1'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.widget<DustDissolve>(find.byType(DustDissolve).at(1)).active,
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
      expect(deletions.isEmpty, isTrue);
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
      expect(deletions.begin([source[2], source[0], source[15]]), 2);
      expect(deletions.isHeld('m15'), isFalse);
      // Top to bottom, a beat apart, sharing one budget.
      final first = deletions.entryFor('m0')!;
      final second = deletions.entryFor('m2')!;
      expect(first.delay, Duration.zero);
      expect(second.delay, MessageDeletions.stagger);
      expect(
        first.particles + second.particles,
        lessThanOrEqualTo(MessageDeletions.defaultBudget),
      );
      await pumpFor(tester, const Duration(seconds: 2));
      expect(deletions.isEmpty, isFalse, reason: 'still listed: hidden');
      expect(find.text('m0'), findsNothing);
      expect(find.text('m2'), findsNothing);
      // The server stops listing them: forgotten.
      source = [
        for (final m in source)
          if (m.id != 'm0' && m.id != 'm2' && m.id != 'm15') m,
      ];
      rebuild(() {});
      await tester.pump();
      expect(deletions.isEmpty, isTrue);
    });

    testWidgets('a failed delete gives the row back', (tester) async {
      await tester.pumpWidget(list());
      deletions.begin([source[0]]);
      await pumpFor(tester, const Duration(milliseconds: 200));
      deletions.cancel(['m0']);
      await tester.pump();
      await tester.pump();
      expect(find.text('m0'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('m0'), findsOneWidget);
    });

    testWidgets('an ephemeral row is never taken', (tester) async {
      source = [msg('e', 0, expiresAt: DateTime(2030)), ...source];
      await tester.pumpWidget(list());
      expect(deletions.begin([source.first]), 0);
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
