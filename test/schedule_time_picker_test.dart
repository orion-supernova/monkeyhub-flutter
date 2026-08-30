import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/schedule_time_picker.dart';

/// The hand-rolled calendar.
///
/// It exists at all because this app has no `ThemeData` and no Material dialog
/// anywhere — see the widget's own header. What that buys in consistency it
/// costs in everything `showDatePicker` would have got right for free, and
/// those are what this file pins:
///
///  * **the grid is the reader's calendar, not an English one.** The column
///    order comes from `firstDayOfWeekIndex` and the numerals from
///    `formatDecimal`, so a Swedish week starts on Monday and an Arabic one
///    reads ٢٣ rather than 23. Both are invisible in an English screenshot and
///    both are wrong for most of the app's twelve locales if hardcoded;
///  * **a selection can never leave the allowed window**, however the user got
///    there — and the days that would leave it are not tappable in the first
///    place;
///  * **the month is reachable**, which is the entire reason the horizontal day
///    strip this replaced had to go: it could only be advanced one day at a
///    time, so next April was about two hundred swipes away.
void main() {
  final controller = ThemeController(BasicTheme.midnight());

  Widget host(Widget child, {bool use24Hour = true, Locale? locale}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, navigator) => ThemeScope(
          controller: controller,
          // An ancestor MediaQuery is discarded by MaterialApp, so the 24-hour
          // flag has to be injected from inside `builder` — the trick
          // `spoiler_veil_test.dart` uses for `disableAnimations`.
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(alwaysUse24HourFormat: use24Hour),
            child: navigator!,
          ),
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  Widget picker({
    DateTime? initial,
    ValueChanged<DateTime>? onChanged,
  }) =>
      ScheduleTimePicker(
        initial: initial ?? DateTime.now().add(const Duration(days: 3)),
        onChanged: onChanged ?? (_) {},
      );

  MaterialLocalizations materialOf(WidgetTester tester) =>
      MaterialLocalizations.of(tester.element(find.byType(ScheduleTimePicker)));

  /// A day cell, not a wheel row. The hour and minute wheels render numbers of
  /// their own — "18" is both a day and an hour — so a bare `find.text` picks
  /// whichever the tree happens to reach first.
  Finder dayCell(String label) => find.descendant(
        of: find.byType(GridView),
        matching: find.text(label),
      );

  testWidgets('shows the month it opened on, and a week header', (
    tester,
  ) async {
    final at = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(host(picker(initial: at)));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    expect(find.text(material.formatMonthYear(at)), findsOneWidget);
    // Seven weekday columns. `narrowWeekdays` repeats letters in English
    // (T, T and S, S), so this counts the strip rather than naming its cells.
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('the month label is NOT upper-cased', (tester) async {
    // Dart's `toUpperCase` is locale-independent, so upper-casing a localized
    // month turns a Turkish "i" into "I" where the language needs "İ" — a
    // visible mistranslation. The codebase calls this trap out twice elsewhere;
    // an earlier version of this widget fell into it.
    final at = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(host(picker(initial: at)));
    await tester.pumpAndSettle();

    final label = materialOf(tester).formatMonthYear(at);
    expect(find.text(label), findsOneWidget);
    if (label != label.toUpperCase()) {
      expect(find.text(label.toUpperCase()), findsNothing);
    }
  });

  testWidgets('day numbers go through the localized formatter', (tester) async {
    // Arabic renders ٢٣, not 23. `'$day'` would be right in English and wrong
    // in two of the twelve locales, which is exactly the kind of bug that
    // survives every screenshot review.
    final at = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(host(picker(initial: at), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    expect(dayCell(material.formatDecimal(at.day)), findsWidgets);
  });

  testWidgets('a 12-hour reader gets an AM/PM column', (tester) async {
    await tester.pumpWidget(host(picker(), use24Hour: false));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    expect(find.text(material.anteMeridiemAbbreviation), findsWidgets);
    expect(find.text(material.postMeridiemAbbreviation), findsWidgets);
  });

  testWidgets('a 24-hour reader gets no AM/PM column', (tester) async {
    await tester.pumpWidget(host(picker(), use24Hour: true));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    expect(find.text(material.anteMeridiemAbbreviation), findsNothing);
    expect(find.text(material.postMeridiemAbbreviation), findsNothing);
  });

  testWidgets('picking a day reports an instant inside the window', (
    tester,
  ) async {
    DateTime? reported;
    final at = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(host(picker(
      initial: at,
      onChanged: (v) => reported = v,
    )));
    await tester.pumpAndSettle();

    // Nothing touched yet, so nothing reported — the picker only speaks when
    // the user changes something.
    expect(reported, isNull);

    final material = materialOf(tester);
    final other = at.add(const Duration(days: 1));
    // Same month as `at`, so the cell is on the page already.
    if (other.month == at.month) {
      await tester.tap(dayCell(material.formatDecimal(other.day)).first);
      await tester.pumpAndSettle();
      expect(reported, isNotNull);
      expect(reported!.isAfter(DateTime.now().add(kScheduleMinLead)), isTrue);
      expect(
        reported!.isBefore(DateTime.now().add(kScheduleMaxHorizon)),
        isTrue,
      );
    }
  });

  testWidgets('yesterday is on the grid but cannot be picked', (tester) async {
    // A month grid necessarily renders days before the floor — they are part of
    // the month. They must render dimmed and refuse the tap, or the sheet can
    // return an instant the server will decline.
    final now = DateTime.now();
    // Only meaningful when there IS an earlier day in this month to test.
    if (now.day < 2) return;
    DateTime? reported;
    await tester.pumpWidget(host(picker(
      initial: now.add(const Duration(days: 2)),
      onChanged: (v) => reported = v,
    )));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    await tester.tap(dayCell(material.formatDecimal(1)).first);
    await tester.pumpAndSettle();
    expect(
      reported,
      isNull,
      reason: 'a day before the minimum lead must not be selectable',
    );
  });

  testWidgets('the header opens a jump list covering the whole horizon', (
    tester,
  ) async {
    await tester.pumpWidget(host(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    // The far end of the window has to be REACHABLE — that is the whole point
    // of the jump, and the failure of the strip this replaced. Thirteen months
    // do not all fit at once, so this scrolls rather than expecting them to.
    final lastMonth = DateTime.now().add(kScheduleMaxHorizon);
    await tester.scrollUntilVisible(
      find.text(material.formatMonthYear(lastMonth)),
      120,
      scrollable: find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text(material.formatMonthYear(lastMonth)), findsOneWidget);
  });

  testWidgets('stepping back from the first month is refused', (tester) async {
    await tester.pumpWidget(host(picker(initial: DateTime.now().add(
      const Duration(days: 2),
    ))));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    final thisMonth = material.formatMonthYear(DateTime.now());
    expect(find.text(thisMonth), findsOneWidget);

    // The back arrow is disabled on the first page; tapping it must not page
    // into a month the window does not contain.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(thisMonth), findsOneWidget);
  });

  testWidgets('stepping forward moves to the next month', (tester) async {
    await tester.pumpWidget(host(picker(initial: DateTime.now().add(
      const Duration(days: 2),
    ))));
    await tester.pumpAndSettle();

    final material = materialOf(tester);
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text(material.formatMonthYear(next)), findsOneWidget);
  });
}
