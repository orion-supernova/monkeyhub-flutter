import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/room_filter_bar.dart';
import 'package:monkeyhub/widgets/room_filter_drawer.dart';

final _l10n = AppLocalizationsEn();

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

  /// Chips in the order the row lays them out — `unread` first. Scrolling is
  /// forward-only, so walking [RoomFacet.values] instead sends the row chasing
  /// a chip that is already behind it, all the way to the end.
  final chipOrder = [
    for (final d in facetDimensionOrder)
      ...RoomFacet.values.where((f) => f.dimension == d),
  ];

  /// The row scrolls, and only the first dimension or so fits a phone width, so
  /// a chip has to be brought into view before it can be tapped.
  ///
  /// The finder is `.hitTestable()`, not a plain `find.text`: the viewport
  /// builds a cache band past its right edge, so an off-screen chip is findable
  /// while still being untappable — and `scrollUntilVisible` would return
  /// having scrolled nothing, leaving the tap to land on empty space.
  Future<void> revealChip(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label).hitTestable(),
      60,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Widget host(Widget child, {double width = 375}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
      await revealChip(tester, 'dms');
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
      await revealChip(tester, 'dms');
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
      for (final f in chipOrder) {
        // The row scrolls, so drag rather than assume everything is on screen.
        await revealChip(tester, f.label(_l10n));
        expect(find.text(f.label(_l10n)), findsOneWidget, reason: f.name);
      }
    });

    testWidgets('"unread" sits directly after the "all" reset', (tester) async {
      // Laid out on a surface the whole row fits on. Comparing offsets needs
      // every chip built in one frame, and at a phone width the later ones fall
      // outside the viewport's cache band and are never built at all — which
      // made this assertion a hostage to how much of the row happened to fit.
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(
          RoomFilterBar(
            filter: RoomFilter.empty,
            counts: counts,
            onChanged: (_) {},
          ),
          width: 1400,
        ),
      );
      final all = tester.getTopLeft(find.text('all')).dx;
      final unread = tester.getTopLeft(find.text('unread')).dx;
      final dms = tester.getTopLeft(find.text('dms')).dx;
      expect(unread, greaterThan(all));
      expect(unread, lessThan(dms));
    });

    testWidgets('the daily-driver "unread" needs no scrolling on a phone', (
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
      // `.hitTestable()`, not a plain find: the row's leading gutter shifts every
      // chip inward, and a chip parked in the cache band past the right edge is
      // findable while being neither visible nor tappable.
      expect(find.text('unread').hitTestable(), findsOneWidget);
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
