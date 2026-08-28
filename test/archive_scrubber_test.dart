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

  double offset(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView).last).controller!.offset;

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
    tester.widget<ListView>(find.byType(ListView).last).controller!.jumpTo(px);
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

  testWidgets('every day is exactly as tall as the maths says', (tester) async {
    // The load-bearing test. The rail names a day from the scroll offset alone,
    // via `archiveSectionHeight` — so the moment that arithmetic and the real
    // layout disagree, the label is wrong everywhere and nothing else fails.
    //
    // Consecutive header positions rather than absolute offsets: the gap
    // between two headers IS one section's height, and it cancels out where
    // the text sits inside its own fixed-height row.
    await open(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final listBox = tester.renderObject<RenderBox>(find.byType(ListView).last);
    final inner = listBox.size.width - 20 - 28;
    final header = archiveHeaderHeight(ctx);

    double? headerTop(String key) {
      final f = find.descendant(
        of: find.byType(ListView).last,
        matching: find.text(archiveDayLabel(ctx, key)),
      );
      if (f.evaluate().isEmpty) return null;
      return tester.getRect(f).top + offset(tester);
    }

    var checked = 0;
    for (var i = 0; i + 1 < dayKeys.length; i++) {
      final a = headerTop(dayKeys[i]);
      final b = headerTop(dayKeys[i + 1]);
      if (a == null || b == null) {
        // Not both laid out yet — scroll on and pick them up further down.
        await tester.drag(find.byType(ListView).last, const Offset(0, -400));
        await tester.pump();
        continue;
      }
      expect(
        b - a,
        closeTo(
          archiveSectionHeight(
            count: photosOn(dayKeys[i]),
            width: inner,
            headerHeight: header,
          ),
          0.5,
        ),
        reason: 'day $i (${dayKeys[i]}) is not the height the maths predicts',
      );
      checked++;
    }
    expect(checked, greaterThan(4), reason: 'the test measured almost nothing');
  });

  testWidgets('the label flips exactly as a header crosses the top edge', (
    tester,
  ) async {
    // The threshold you asked about. It used to switch 24pt early, because the
    // walk counted a section as "at the top" while its header was still below
    // the fold.
    await open(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final listBox = tester.renderObject<RenderBox>(find.byType(ListView).last);
    final inner = listBox.size.width - 20 - 28;
    // Where the SECOND day's RULE reaches the top edge — the line a reader
    // watches a date cross, not the invisible top of the header row a header's
    // height above it.
    final header = archiveHeaderHeight(ctx);
    final boundary =
        8.0 +
        archiveSectionHeight(
          count: photosOn(dayKeys[0]),
          width: inner,
          headerHeight: header,
        ) +
        header;

    // Four points short of the rule: still the first day. One pump, because
    // the label is computed in the scroll callback from the offset rather than
    // walked out of render boxes after the frame.
    await scrollTo(tester, boundary - 4);
    expect(pill(tester), archiveDayLabel(ctx, dayKeys[0]));

    // Eight points later the rule has crossed, and so has the label.
    await scrollTo(tester, boundary + 4);
    expect(pill(tester), archiveDayLabel(ctx, dayKeys[1]));
  });

  testWidgets('EVERY switch lands on its rule, not just the first', (
    tester,
  ) async {
    // The first switch was exact and the later ones ran early, which is what a
    // sliding anchor does: it travels faster than the finger, so the error
    // compounds down the list. Checking one boundary could not see that.
    await open(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final listBox = tester.renderObject<RenderBox>(find.byType(ListView).last);
    final inner = listBox.size.width - 20 - 28;
    final header = archiveHeaderHeight(ctx);
    final pos = tester
        .widget<ListView>(find.byType(ListView).last)
        .controller!
        .position;

    var rule = 8.0;
    var checked = 0;
    for (var i = 0; i < dayKeys.length; i++) {
      rule += archiveSectionHeight(
        count: photosOn(dayKeys[i]),
        width: inner,
        headerHeight: header,
      );
      final boundary = rule + header;
      if (boundary + 4 > pos.maxScrollExtent) break;

      await scrollTo(tester, boundary - 4);
      expect(
        pill(tester),
        archiveDayLabel(ctx, dayKeys[i]),
        reason: 'switch ${i + 1} fired early',
      );
      await scrollTo(tester, boundary + 4);
      expect(
        pill(tester),
        archiveDayLabel(ctx, dayKeys[i + 1]),
        reason: 'switch ${i + 1} fired late',
      );
      checked++;
    }
    expect(checked, greaterThan(3), reason: 'barely any boundaries checked');
  });

  testWidgets('at the bottom it names the topmost header on screen', (
    tester,
  ) async {
    // The honest answer for a list whose final screenful can never scroll past
    // the top edge: the date it names is the one you can see at the top of it.
    await openShort(tester);
    final ctx = tester.element(find.byType(ArchiveScreen));
    final pos = tester
        .widget<ListView>(find.byType(ListView).last)
        .controller!
        .position;

    // No scrub rail on an archive this short, and that is right — there is
    // nothing to fast-scroll through. The chip is the only thing naming a day.
    expect(find.byKey(archiveScrubberPillKey), findsNothing);
    expect(activeChipDay(tester), shortDays.first.split('-').last);

    await scrollTo(tester, pos.maxScrollExtent);
    await tester.pumpAndSettle();

    final listTop = tester.getRect(find.byType(ListView).last).top;
    String? topmost;
    for (final day in shortDays) {
      final f = find.descendant(
        of: find.byType(ListView).last,
        matching: find.text(archiveDayLabel(ctx, day)),
      );
      if (f.evaluate().isEmpty) continue;
      if (tester.getRect(f).top <= listTop + 1) topmost = day;
    }
    expect(topmost, isNotNull);
    expect(activeChipDay(tester), topmost!.split('-').last);
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
          of: find.byType(ListView).last,
          matching: find.text(archiveDayLabel(ctx, key)),
        );
        if (f.evaluate().isEmpty) continue;
        if (!seen.contains(key)) seen.add(key);
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
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

  testWidgets('the date pill is a handle, not just a label', (tester) async {
    // What was actually reported: the rail dragged from the thin bar, but the
    // pill — the part that looks like a grip — painted outside the 28pt track
    // and so was never hit-tested at all.
    await open(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pump();
    final before = offset(tester);

    await tester.dragFrom(
      tester.getCenter(find.byKey(archiveScrubberPillKey)),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(
      offset(tester),
      greaterThan(before),
      reason: 'dragging the pill has to scrub',
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
        .widget<ListView>(find.byType(ListView).last)
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
