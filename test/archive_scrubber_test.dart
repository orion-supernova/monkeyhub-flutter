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

/// Twelve days, four pictures each — enough that the list is several screens
/// long, which is the only case the rail exists for.
class _FakeFeedApi extends Fake implements FeedApi {
  @override
  Future<MomentPage> archive({
    required String userId,
    String? ofUserId,
    int? beforeTimestamp,
    int? limit,
  }) async {
    final items = <Moment>[];
    for (var day = 1; day <= 12; day++) {
      // Uneven on purpose: a model that only ever sees four-photo days would
      // pass with the row count hard-coded. 1..7 photos crosses every row
      // boundary of a three-column grid.
      for (var i = 0; i < 1 + (day % 7); i++) {
        final at = DateTime(2026, 3, 20 - day, 12, i);
        items.add(
          Moment(
            id: 'm${day}_$i',
            userId: 'u1',
            dayKey: '2026-03-${(20 - day).toString().padLeft(2, '0')}',
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

void main() {
  /// Every day's dayKey, newest first — the order `_loadMore` builds them in.
  final dayKeys = [
    for (var day = 1; day <= 12; day++)
      '2026-03-${(20 - day).toString().padLeft(2, '0')}',
  ];

  /// How many photos the fake puts on day [i] — mirrors the loop above.
  int photosOnDay(int i) => 1 + ((i + 1) % 7);

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

  testWidgets('the day it names is the day at the top of the list', (
    tester,
  ) async {
    await open(tester);

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    // ONE pump. The label is computed in the scroll callback from the offset,
    // not walked out of render boxes after the frame, so it is already right.
    await tester.pump();

    final ctx = tester.element(find.byType(ArchiveScreen));
    final listTop = tester.getRect(find.byType(ListView).last).top;

    // The last section header that has already crossed the list's top edge.
    String? expected;
    for (final key in dayKeys) {
      final header = find.descendant(
        of: find.byType(ListView).last,
        matching: find.text(archiveDayLabel(ctx, key)),
      );
      if (header.evaluate().isEmpty) continue;
      if (tester.getRect(header).top <= listTop) {
        expected = archiveDayLabel(ctx, key);
      }
    }
    expect(expected, isNotNull, reason: 'the test itself found no header');
    expect(pill(tester), expected);
  });

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
            count: photosOnDay(i),
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

    // Where the SECOND day's section begins.
    final boundary =
        8.0 +
        archiveSectionHeight(
          count: photosOnDay(0),
          width: inner,
          headerHeight: archiveHeaderHeight(ctx),
        );

    await tester.drag(find.byType(ListView).last, Offset(0, -(boundary - 4)));
    await tester.pump();
    expect(pill(tester), archiveDayLabel(ctx, dayKeys[0]));

    await tester.drag(find.byType(ListView).last, const Offset(0, -8));
    await tester.pump();
    expect(pill(tester), archiveDayLabel(ctx, dayKeys[1]));
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
}
