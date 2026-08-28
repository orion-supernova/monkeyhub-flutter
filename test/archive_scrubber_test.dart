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
      for (var i = 0; i < 4; i++) {
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

  testWidgets('the day it names is the day at the top of the list', (
    tester,
  ) async {
    await open(tester);

    // Somewhere in the middle, reached the ordinary way. Pumped rather than
    // settled: the rail goes quiet 1.2s after the list stops, and settling
    // would run that timer out and take the pill with it.
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    // Two frames: one for the scroll to lay out, one for the label the
    // post-frame refresh writes after it. See `_queueDayRefresh`.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final listTop = tester.getRect(find.byType(ListView).last).top;

    // The section header that is actually at the top of the viewport — the
    // last one that has already started by the time we reach the list's top
    // edge. That string is what the rail is supposed to be showing.
    String? expected;
    for (var day = 1; day <= 12; day++) {
      final key = '2026-03-${(20 - day).toString().padLeft(2, '0')}';
      final label = archiveDayLabel(
        tester.element(find.byType(ArchiveScreen)),
        key,
      );
      // Scoped to the list: the rail's pill carries the same string, and an
      // unscoped finder goes ambiguous the moment the two agree — which is the
      // outcome this test is here to check.
      final header = find.descendant(
        of: find.byType(ListView).last,
        matching: find.text(label),
      );
      if (header.evaluate().isEmpty) continue;
      if (tester.getRect(header).top - listTop <= 24) expected = label;
    }
    expect(expected, isNotNull, reason: 'the test itself found no header');

    // Twice: once in the section header, once in the rail's pill. Before the
    // fix the rail was still naming the first day of the archive here.
    expect(find.text(expected!), findsNWidgets(2));
    expect(l10n.archiveScreenTitle, isNotEmpty);
  });
}
