import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/screens/feed/archive_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// What this pins: **the fast-scroll rail can be grabbed, and it tells the
/// truth about where it is.**
///
/// Both halves shipped broken, and both were invisible to the analyzer.
///
///  * The rail faded in only *while the list was already moving* and was
///    `IgnorePointer`'d the rest of the time. That is a control you cannot
///    reach: by the time it appeared your finger was on the grid, and putting
///    it back where the rail had been did nothing, because there was nothing
///    drawn OR hittable there. It is now on screen the whole time the list is
///    long enough to want it.
///  * The day label measured section positions against `State.context` — the
///    whole screen — rather than against the scroller, which starts well below
///    it, under the title and the date rail. Every section read as "still below
///    the fold", nothing ever matched, and the label sat on its fallback (the
///    first day in the archive) almost always.
class _FakeChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

/// Twelve days with uneven photo counts, delivered in the order the real
/// backend would deliver them: `feed:archive` pages by `createdAt` DESCENDING,
/// while a row is filed under its author's local `dayKey`. Those two disagree
/// whenever a zone does, so day 03-14 here is written by an author three hours
/// ahead and arrives out of day order — the interleaving the screen has to sort
/// out before any date rail over it can be right.
class _FakeFeedApi extends Fake implements FeedApi {
  @override
  Future<MomentPage> archive({
    required String userId,
    String? ofUserId,
    int? beforeTimestamp,
    int? limit,
  }) async {
    final items = <Moment>[];
    for (final day in _emissionOrder) {
      final count = photosOn(day);
      for (var i = 0; i < count; i++) {
        final parts = day.split('-').map(int.parse).toList();
        final at = DateTime(parts[0], parts[1], parts[2], 12, i);
        items.add(
          Moment(
            id: '${day}_$i',
            userId: 'u1',
            dayKey: day,
            createdAt: at,
            expiresAt: at.add(const Duration(days: 1)),
            authorName: 'Ada',
            authorUsername: 'ada',
            mine: true,
            seen: true,
            mediaStorageId: 'blob${day}_$i',
            mediaKind: MomentMedia.image,
          ),
        );
      }
    }
    return MomentPage(items: items, hasMore: false);
  }
}

/// The reported shape: five days, one photo each — an archive barely taller
/// than the screen, where the top edge of the viewport travels through only the
/// first day or two of it.
class _ShortFeedApi extends Fake implements FeedApi {
  @override
  Future<MomentPage> archive({
    required String userId,
    String? ofUserId,
    int? beforeTimestamp,
    int? limit,
  }) async => MomentPage(
    items: [
      for (var d = 0; d < shortDays.length; d++)
        Moment(
          id: 'short$d',
          userId: 'u1',
          dayKey: shortDays[d],
          createdAt: DateTime(2026, 3, 19 - d, 12),
          expiresAt: DateTime(2026, 3, 20 - d, 12),
          authorName: 'Ada',
          authorUsername: 'ada',
          mine: true,
          seen: true,
          mediaStorageId: 'sb$d',
          mediaKind: MomentMedia.image,
        ),
    ],
    hasMore: false,
  );
}

final shortDays = [
  for (var d = 0; d < 5; d++)
    '2026-03-${(19 - d).toString().padLeft(2, '0')}',
];

/// Two short pages: five days, then two more. Reproduces the report that days
/// existed but only turned up after dragging the list into its overscroll
/// bounce — pagination hung off scroll events, and a first page shorter than
/// the screen produced none.
class _PagedFeedApi extends Fake implements FeedApi {
  int calls = 0;

  @override
  Future<MomentPage> archive({
    required String userId,
    String? ofUserId,
    int? beforeTimestamp,
    int? limit,
  }) async {
    final first = calls++ == 0;
    final days = first ? shortDays : extraDays;
    return MomentPage(
      items: [
        for (var d = 0; d < days.length; d++)
          Moment(
            id: '${days[d]}_0',
            userId: 'u1',
            dayKey: days[d],
            createdAt: DateTime(
              2026,
              3,
              int.parse(days[d].split('-').last),
              12,
            ),
            expiresAt: DateTime(2026, 4, 1),
            authorName: 'Ada',
            authorUsername: 'ada',
            mine: true,
            seen: true,
            mediaStorageId: 'pb${days[d]}',
            mediaKind: MomentMedia.image,
          ),
      ],
      hasMore: first,
    );
  }
}

/// The days the second page carries.
final extraDays = ['2026-03-13', '2026-03-12'];

/// Chronological, newest first — what the screen must end up rendering.
final dayKeys = [
  for (var day = 1; day <= 12; day++)
    '2026-03-${(20 - day).toString().padLeft(2, '0')}',
];

/// The order the API hands them over: chronological except for one pair
/// swapped, standing in for a moment written either side of a zone change.
final _emissionOrder = () {
  final out = [...dayKeys];
  final tmp = out[5];
  out[5] = out[6];
  out[6] = tmp;
  return out;
}();

/// Photos on a given day. Uneven on purpose: a model that only ever saw
/// four-photo days would pass with the row count hard-coded.
int photosOn(String dayKey) => 1 + (int.parse(dayKey.split('-').last) % 7);

void main() {
  Future<void> pumpArchive(WidgetTester tester, FeedApi feed) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveScreen(
            api: _FakeChatApi(),
            feedApi: feed,
            userId: 'u1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openShort(WidgetTester tester) =>
      pumpArchive(tester, _ShortFeedApi());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveScreen(
            api: _FakeChatApi(),
            feedApi: _FakeFeedApi(),
            userId: 'u1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double offset(WidgetTester tester) => tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!
      .offset;

  /// The horizontal day rail's offset — the FIRST ListView on the screen.
  double railOffset(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView).first).controller!.offset;

  /// The day-of-month printed on the highlighted chip in the top rail.
  String? activeChipDay(WidgetTester tester) {
    final chip = find.byKey(archiveActiveChipKey);
    if (chip.evaluate().isEmpty) return null;
    final texts = find.descendant(of: chip, matching: find.byType(Text));
    return tester.widget<Text>(texts.first).data;
  }

  /// Puts the list at an exact offset.
  ///
  /// `tester.drag` swallows `kDragSlopDefault` (20pt) before the scroll starts,
  /// so a test that cares about a boundary to the pixel cannot use it.
  Future<void> scrollTo(WidgetTester tester, double px) async {
    tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .jumpTo(px);
    await tester.pump();
  }

  testWidgets('the rail is there before you scroll, and dragging it moves the '
      'list', (tester) async {
    await open(tester);
    expect(offset(tester), 0);

    // Straight onto the rail from a standing start — no scroll first. The whole
    // failure was that this did nothing at all.
    final screen = tester.getSize(find.byType(ArchiveScreen));
    await tester.dragFrom(
      Offset(screen.width - 14, screen.height * 0.35),
      Offset(0, screen.height * 0.4),
    );
    await tester.pumpAndSettle();

    expect(
      offset(tester),
      greaterThan(0),
      reason: 'a drag on the rail has to scrub the list',
    );
  });

  /// The date the rail is currently showing, or null when it is not up.
  String? pill(WidgetTester tester) {
    final text = find.descendant(
      of: find.byKey(archiveScrubberPillKey),
      matching: find.byType(Text),
    );
    if (text.evaluate().isEmpty) return null;
    return tester.widget<Text>(text).data;
  }

  /// The day whose header is currently pinned to the top of the list — the
  /// date a reader is actually looking at, straight off the widget tree.
  ///
  /// With `SliverPersistentHeader(pinned: true)` exactly one header is stuck at
  /// the top edge at any moment, and it is the one drawn highest.
  String? pinnedDay(WidgetTester tester, BuildContext ctx) {
    String? best;
    var top = double.infinity;
    for (final day in [...dayKeys, ...shortDays, ...extraDays]) {
      final f = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text(archiveDayLabel(ctx, day)),
      );
      if (f.evaluate().isEmpty) continue;
      final y = tester.getRect(f.first).top;
      if (y < top) {
        top = y;
        best = day;
      }
    }
    return best;
  }

  testWidgets('the pill agrees with the pinned header at every offset', (
    tester,
  ) async {
    // The invariant that replaced three generations of arithmetic. The date on
    // screen IS the pinned section header — the layout system puts it there,
    // the same way `sectionHeadersPinToVisibleBounds` does on iOS — so there is
    // no second opinion to drift from it. This walks the whole archive and
    // checks the two never disagree, which is the only claim worth making.
    await open(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final pos = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .position;

    final max = pos.maxScrollExtent;
    var checked = 0;
    for (var px = 0.0; px <= max; px += 37) {
      await scrollTo(tester, px);
      final pinned = pinnedDay(tester, ctx);
      if (pinned == null) continue;
      // Both are checked when they are on screen rather than demanded at
      // rest: the pill is only up while the list moves, and the rail builds
      // lazily, so a chip far off its own viewport may not exist yet.
      final chip = activeChipDay(tester);
      if (chip != null) {
        expect(
          chip,
          pinned.split('-').last,
          reason: 'at offset $px the chips and the header disagree',
        );
      }
      final showing = pill(tester);
      if (showing != null) {
        expect(
          showing,
          archiveDayLabel(ctx, pinned),
          reason: 'at offset $px the rail and the header disagree',
        );
      }
      checked++;
    }
    expect(checked, greaterThan(10), reason: 'barely any offsets checked');
  });

  testWidgets('the chip agrees with the pinned header on a short archive', (
    tester,
  ) async {
    // The reported shape: a handful of days with one photo each. No scrub rail
    // here — there is nothing to fast-scroll through — so the chip is the only
    // thing naming a day, and it has to name the one that is pinned.
    await openShort(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final pos = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .position;

    expect(find.byKey(archiveScrubberPillKey), findsNothing);

    for (var px = 0.0; px <= pos.maxScrollExtent; px += 29) {
      await scrollTo(tester, px);
      final pinned = pinnedDay(tester, ctx);
      if (pinned == null) continue;
      expect(
        activeChipDay(tester),
        pinned.split('-').last,
        reason: 'at offset $px the chips and the header disagree',
      );
    }
  });

  testWidgets('the LAST day pins at the bottom, even on a short archive', (
    tester,
  ) async {
    // Five days of one photo each is an archive barely taller than the screen,
    // so the last sections have nothing below them to scroll through and their
    // headers could never reach the top: every date after the second was
    // unreachable, and the sticky header stopped partway down the list and
    // stayed there. The trailing reserve is what gives the last one room to
    // arrive.
    await openShort(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final pos = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .position;

    await scrollTo(tester, pos.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(
      pinnedDay(tester, ctx),
      shortDays.last,
      reason: 'the last day never reaches the top',
    );
    expect(activeChipDay(tester), shortDays.last.split('-').last);
  });

  testWidgets('days come out chronological even when the page does not', (
    tester,
  ) async {
    // `feed:archive` pages by `createdAt` descending while a row is filed under
    // its author's local `dayKey`, so the two interleave across a zone change.
    // Taking arrival order literally shuffled the sections — and a date rail
    // over a list that is not in date order is wrong however exactly it is
    // measured.
    await open(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));

    // Walk the whole list and record the headers in the order they are laid
    // out; they must come out newest-first.
    final seen = <String>[];
    for (var step = 0; step < 24; step++) {
      for (final key in dayKeys) {
        final f = find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.text(archiveDayLabel(ctx, key)),
        );
        if (f.evaluate().isEmpty) continue;
        if (!seen.contains(key)) seen.add(key);
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
    }

    expect(seen.length, greaterThan(6), reason: 'saw almost no headers');
    final sorted = [...seen]..sort((a, b) => b.compareTo(a));
    expect(seen, sorted, reason: 'sections are not in date order');
  });

  testWidgets('the chips at the top follow the scroll', (tester) async {
    // The third date surface. `_selectedDay` moved only when a chip was TAPPED,
    // so while you scrolled the highlighted chip named wherever you last jumped
    // from — two date indicators disagreeing, which reads as neither being
    // right.
    await open(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    expect(railOffset(tester), 0);

    // Far enough down that the active chip is well off the left end of a rail
    // that has not moved.
    await scrollTo(tester, 2600);
    await tester.pumpAndSettle();

    expect(
      pill(tester),
      isNot(archiveDayLabel(ctx, dayKeys[0])),
      reason: 'the list moved but the label did not follow it',
    );
    // The rail scrolled itself to keep the highlighted chip in view, which it
    // only does when `_selectedDay` tracks the list.
    expect(
      railOffset(tester),
      greaterThan(0),
      reason: 'the chips did not follow the scroll',
    );
  });

  testWidgets('the grip scrubs, and the pill does not steal the scroll', (
    tester,
  ) async {
    // Two halves of one trade. The grip has to be a real target — it was a 4pt
    // line, which is what made reaching for the rail miss — but the DATE PILL
    // beside it must not be, because it is as wide as a date and its hit box
    // would reach most of the way across the screen and swallow drags meant for
    // the photographs underneath.
    await open(tester);
    await scrollTo(tester, 600);
    await tester.pump();

    // A drag starting on the pill scrolls the grid, exactly as if the pill
    // were not there.
    final beforePill = offset(tester);
    await tester.dragFrom(
      tester.getCenter(find.byKey(archiveScrubberPillKey)),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(
      offset(tester),
      greaterThan(beforePill),
      reason: 'the pill ate a scroll meant for the grid',
    );

    // A drag on the grip scrubs. Aimed at the right edge, where the grip is.
    await scrollTo(tester, 600);
    await tester.pump();
    final beforeGrip = offset(tester);
    final screen = tester.getSize(find.byType(ArchiveScreen));
    await tester.dragFrom(
      Offset(screen.width - 10, screen.height * 0.45),
      Offset(0, screen.height * 0.3),
    );
    await tester.pumpAndSettle();
    expect(
      offset(tester),
      isNot(beforeGrip),
      reason: 'the rail did not take the drag',
    );
  });

  testWidgets('a page that does not fill the screen fetches the next one', (
    tester,
  ) async {
    // Pagination hangs off scroll events, so a first page shorter than the
    // viewport left the archive with no way to ask for the second: the extra
    // days were reachable only by dragging into the overscroll bounce, which
    // produces just enough scroll to trip the runway check.
    final feed = _PagedFeedApi();
    await pumpArchive(tester, feed);
    await tester.pumpAndSettle();

    expect(feed.calls, greaterThan(1), reason: 'never asked for page two');

    // And they are really in the list, not merely fetched. Scrolled to, because
    // a lazy list only builds what is near the viewport — the point is that
    // getting there is now an ordinary scroll rather than a bounce.
    final ctx = tester.element(find.byType(ArchiveScreen));
    final pos = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .position;
    await scrollTo(tester, pos.maxScrollExtent);
    await tester.pumpAndSettle();

    for (final day in extraDays) {
      expect(
        find.text(archiveDayLabel(ctx, day)),
        findsWidgets,
        reason: '$day never arrived',
      );
    }
  });
}
