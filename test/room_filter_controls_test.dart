import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/room_filter_bar.dart';
import 'package:monkeyhub/widgets/room_filter_drawer.dart';

/// The chat list ships two interchangeable filter controls, chosen in settings.
/// They must produce the same [RoomFilter] from the same intent — otherwise the
/// setting silently changes behaviour, not just appearance.
void main() {
  final rooms = [
    ChatRoom(
      id: 'a',
      name: 'dm:u0:u1',
      createdBy: 'u0',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: 2,
      unreadCount: 2,
    ),
    ChatRoom(
      id: 'b',
      name: 'general',
      createdBy: 'u0',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: 5,
    ),
  ];
  final counts = RoomFacetCounts.of(rooms);

  Widget host(Widget child, {double width = 375}) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  group('both styles agree', () {
    testWidgets('tapping "dms" yields the same filter either way', (
      tester,
    ) async {
      RoomFilter? fromChips;
      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: RoomFilter.empty,
            counts: counts,
            onChanged: (f) => fromChips = f,
          ),
        ),
      );
      await tester.tap(find.text('dms'));
      await tester.pump();

      RoomFilter? fromDrawer;
      await tester.pumpWidget(
        host(
          RoomFilterPanel(
            filter: RoomFilter.empty,
            counts: counts,
            expanded: true,
            onChanged: (f) => fromDrawer = f,
            onDone: () {},
          ),
        ),
      );
      await tester.tap(find.text('dms'));
      await tester.pump();

      expect(fromChips, RoomFilter({RoomFacet.dms}));
      expect(fromDrawer, fromChips);
    });

    testWidgets('tapping an active facet clears it, either way', (
      tester,
    ) async {
      final active = RoomFilter({RoomFacet.dms});

      RoomFilter? fromChips;
      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: active,
            counts: counts,
            onChanged: (f) => fromChips = f,
          ),
        ),
      );
      await tester.tap(find.text('dms'));
      await tester.pump();

      RoomFilter? fromDrawer;
      await tester.pumpWidget(
        host(
          RoomFilterPanel(
            filter: active,
            counts: counts,
            expanded: true,
            onChanged: (f) => fromDrawer = f,
            onDone: () {},
          ),
        ),
      );
      await tester.tap(find.text('dms'));
      await tester.pump();

      expect(fromChips, RoomFilter.empty);
      expect(fromDrawer, RoomFilter.empty);
    });
  });

  group('chip row', () {
    testWidgets('offers every facet plus an "all" reset', (tester) async {
      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: RoomFilter.empty,
            counts: counts,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('all'), findsOneWidget);
      for (final f in RoomFacet.values) {
        // The row scrolls, so drag rather than assume everything is on screen.
        await tester.scrollUntilVisible(
          find.text(f.label),
          60,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(f.label), findsOneWidget, reason: f.name);
      }
    });

    testWidgets('"all" clears an active filter', (tester) async {
      RoomFilter? next;
      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: RoomFilter({RoomFacet.dms, RoomFacet.unread}),
            counts: counts,
            onChanged: (f) => next = f,
          ),
        ),
      );
      await tester.tap(find.text('all'));
      await tester.pump();
      expect(next, RoomFilter.empty);
    });

    testWidgets('renders at the 375pt phone width without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: RoomFilter.empty,
            counts: counts,
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in the 360pt desktop chat column', (tester) async {
      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: RoomFilter.empty,
            counts: counts,
            onChanged: (_) {},
          ),
          width: 360,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('drawer panel', () {
    testWidgets('shows a live count beside each facet', (tester) async {
      await tester.pumpWidget(
        host(
          RoomFilterPanel(
            filter: RoomFilter.empty,
            counts: counts,
            expanded: true,
            onChanged: (_) {},
            onDone: () {},
          ),
        ),
      );
      // One DM, one group, both private, one unread — the counts are what make
      // "private matches nearly everything" self-evident rather than a trap.
      expect(find.text('dms'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // private == 2
      expect(find.text('CLEAR'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets('collapsed, it occupies no vertical space', (tester) async {
      await tester.pumpWidget(
        host(
          RoomFilterPanel(
            filter: RoomFilter.empty,
            counts: counts,
            expanded: false,
            onChanged: (_) {},
            onDone: () {},
          ),
        ),
      );
      expect(find.text('dms'), findsNothing);
      expect(tester.getSize(find.byType(RoomFilterPanel)).height, 0);
    });

    testWidgets('CLEAR resets everything at once', (tester) async {
      RoomFilter? next;
      await tester.pumpWidget(
        host(
          RoomFilterPanel(
            filter: RoomFilter({RoomFacet.dms, RoomFacet.unread}),
            counts: counts,
            expanded: true,
            onChanged: (f) => next = f,
            onDone: () {},
          ),
        ),
      );
      await tester.tap(find.text('CLEAR'));
      await tester.pump();
      expect(next, RoomFilter.empty);
    });
  });

  group('filtered-empty state', () {
    testWidgets('names the filter and offers a way back to every chat', (
      tester,
    ) async {
      var cleared = false;
      await tester.pumpWidget(
        host(
          FilteredEmptyState(
            filter: RoomFilter({RoomFacet.unread}),
            total: 17,
            onClear: () => cleared = true,
          ),
        ),
      );

      // Because the filter persists, a cold start can land here. It has to read
      // as "filtered", never as "the app lost my conversations".
      expect(find.text('nothing matches unread'), findsOneWidget);
      expect(find.text('show all 17 chats'), findsOneWidget);

      await tester.tap(find.text('show all 17 chats'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('counts one chat in the singular', (tester) async {
      await tester.pumpWidget(
        host(
          FilteredEmptyState(
            filter: RoomFilter({RoomFacet.dms}),
            total: 1,
            onClear: () {},
          ),
        ),
      );
      expect(find.text('show all 1 chat'), findsOneWidget);
    });
  });

  group('active-filter cue', () {
    testWidgets('states the filter and the match count', (tester) async {
      await tester.pumpWidget(
        host(
          ActiveFilterCue(
            filter: RoomFilter({RoomFacet.dms, RoomFacet.unread}),
            matchCount: 0,
            onClear: () {},
          ),
        ),
      );
      expect(find.text('dms + unread · 0'), findsOneWidget);
      expect(find.text('clear'), findsOneWidget);
    });
  });
}
