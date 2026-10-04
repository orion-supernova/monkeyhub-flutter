import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';
import 'package:monkeyhub/widgets/schedule_message_sheet.dart';
import 'package:monkeyhub/widgets/schedule_time_picker.dart';

/// The sheet a hold on Send opens, and the sentence it keeps at the bottom.
///
/// Two properties are worth pinning, and neither is visible in a screenshot.
///
/// The first is that the sheet resolves its presets against the instant it
/// OPENED rather than against a fresh clock per build. Without that, a sheet
/// left open across 9am would silently relabel the lit chip from "Tomorrow
/// morning" to "This morning" — changing what the user is about to commit to
/// without them touching anything.
///
/// The second is that every chip renders the clock time it resolves to. That
/// line is the only thing standing between "Tomorrow morning" and a user who
/// scheduled something for seven hours' time believing it was a day away.
void main() {
  final en = AppLocalizationsEn();

  final controller = ThemeController(BasicTheme.midnight());

  // ThemeScope goes in `builder`, NOT in `home`. `showAdaptiveSheet` pushes its
  // route into MaterialApp's own Navigator, whose overlay sits ABOVE `home` —
  // a scope nested inside `home` is not an ancestor of the sheet, and the sheet
  // asserts on the missing scope the moment it builds. `builder` wraps the
  // Navigator itself, so every route it pushes is a descendant.
  /// A phone, not the 800x600 default. The sheet is bounded and scrollable, so
  /// on the default surface its CTAs sit below the fold and every `tap` misses
  /// — which says nothing about the sheet and everything about the viewport.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, navigator) => ThemeScope(
          controller: controller,
          child: navigator!,
        ),
        home: Scaffold(body: child),
      );

  /// A context inside the open sheet, for the platform date/time formatters.
  BuildContext sheetContext(WidgetTester tester) =>
      tester.element(find.text(en.scheduleSheetSubtitle));

  /// Opens the real sheet through the real `showAdaptiveSheet` route, so the
  /// test exercises what ships rather than the private widget behind it.
  Future<ScheduleChoice?> open(
    WidgetTester tester, {
    String? preview,
    DateTime? initial,
    ScheduleSheetMode mode = ScheduleSheetMode.create,
  }) async {
    ScheduleChoice? result;
    var opened = false;
    phone(tester);
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          opened = true;
          result = await showScheduleMessageSheet(
            context,
            preview: preview,
            initial: initial,
            mode: mode,
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    return result;
  }

  testWidgets('offers every preset plus the custom route', (tester) async {
    await open(tester);

    expect(find.text(en.schedulePresetInAnHour), findsOneWidget);
    expect(find.text(en.schedulePresetInEightHours), findsOneWidget);
    expect(find.text(en.schedulePresetInAWeek), findsOneWidget);
    expect(find.text(en.scheduleSheetCustomChip), findsOneWidget);
    // One grouped card, not a ragged Wrap of chips — the whole point of the
    // redesign. Aligned trailing times are what a Wrap could not give.
    expect(find.byType(Wrap), findsNothing);
    // Exactly one of the two morning wordings, never both.
    final morning = find.text(en.schedulePresetTomorrowMorning).evaluate().length +
        find.text(en.schedulePresetThisMorning).evaluate().length;
    expect(morning, 1);
  });

  testWidgets('every preset shows the clock time it resolves to', (
    tester,
  ) async {
    await open(tester);

    // One clock line per preset. Formatted by MaterialLocalizations, so the
    // test asserts the shape rather than a literal — the point is that the
    // line is THERE, on every chip, not what today's hour happens to be.
    final now = DateTime.now();
    for (final p in SchedulePreset.values) {
      final at = p.resolve(now);
      final expected = MaterialLocalizations.of(sheetContext(tester))
          .formatTimeOfDay(TimeOfDay.fromDateTime(at));
      expect(
        find.text(expected),
        findsWidgets,
        reason: 'no resolved clock time rendered for $p',
      );
    }
  });

  testWidgets('the running sentence names the selected time', (tester) async {
    await open(tester);

    // The default chip is "in 1 hour", so the sentence says today unless the
    // hour crosses midnight — either way it must be a real sentence, not a
    // bare timestamp.
    expect(find.textContaining('Sends '), findsOneWidget);

    await tester.tap(find.text(en.schedulePresetInAWeek));
    await tester.pumpAndSettle();
    // A week out is never today or tomorrow, so the dated form must appear.
    final material = MaterialLocalizations.of(sheetContext(tester));
    final at = SchedulePreset.inAWeek.resolve(DateTime.now());
    expect(
      find.textContaining(material.formatMediumDate(at)),
      findsOneWidget,
    );
  });

  testWidgets('confirming returns the resolved instant', (tester) async {
    ScheduleChoice? got;
    phone(tester);
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          got = await showScheduleMessageSheet(context);
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final before = DateTime.now();
    await tester.tap(_label(en.scheduleSheetConfirmButton));
    await tester.pumpAndSettle();

    expect(got, isA<ScheduleAt>());
    // The default row is one hour out; allow a minute of slack for the pump.
    final delta = (got! as ScheduleAt).at.difference(before);
    expect(delta.inMinutes, closeTo(60, 1));
  });

  testWidgets('cancelling returns nothing at all', (tester) async {
    ScheduleChoice? got;
    var completed = false;
    phone(tester);
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          got = await showScheduleMessageSheet(context);
          completed = true;
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The × every sheet wears, top-leading — it replaced a text Cancel.
    await tester.tap(find.byType(SheetCloseButton));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(got, isNull);
  });

  testWidgets('shows the message it is about to schedule', (tester) async {
    await open(tester, preview: 'happy birthday!');
    expect(find.text('happy birthday!'), findsOneWidget);
  });

  testWidgets('the custom chip swaps in the picker and back', (tester) async {
    await open(tester);

    expect(find.byType(ScheduleTimePicker), findsNothing);

    await tester.tap(find.text(en.scheduleSheetCustomChip));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleTimePicker), findsOneWidget);
    expect(_label(en.scheduleTimePickerTitle), findsOneWidget);
    // The quick chips are gone while the picker is up — one decision at a time.
    expect(find.text(en.schedulePresetInAnHour), findsNothing);

    await tester.tap(find.text(en.scheduleTimePickerBack));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleTimePicker), findsNothing);
    expect(find.text(en.schedulePresetInAnHour), findsOneWidget);
  });

  // "Open current by default": a calendar that opened an hour ahead made every
  // "in twenty minutes" a matter of winding the clock backwards first. The
  // default-lit row is not a choice anybody made, so it does not seed it.
  Future<ScheduleChoice?> customAndConfirm(
    WidgetTester tester, {
    String? rowFirst,
  }) async {
    ScheduleChoice? got;
    phone(tester);
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async => got = await showScheduleMessageSheet(context),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (rowFirst != null) {
      await tester.tap(find.text(rowFirst));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(en.scheduleSheetCustomChip));
    await tester.pumpAndSettle();
    await tester.tap(_label(en.scheduleSheetConfirmButton));
    await tester.pumpAndSettle();
    return got;
  }

  testWidgets('the calendar opens on now when no row was chosen',
      (tester) async {
    final before = DateTime.now();
    final got = await customAndConfirm(tester);

    // The first minute that can still be scheduled — the lead time, rounded
    // onto the picker's five-minute grid — not an hour out.
    final delta = (got! as ScheduleAt).at.difference(before);
    expect(delta, greaterThanOrEqualTo(kScheduleMinLead));
    expect(delta, lessThan(const Duration(minutes: 10)));
  });

  testWidgets('a row the user tapped carries into the calendar',
      (tester) async {
    final before = DateTime.now();
    final got = await customAndConfirm(
      tester,
      rowFirst: en.schedulePresetInAWeek,
    );

    final delta = (got! as ScheduleAt).at.difference(before);
    expect(delta.inHours, closeTo(7 * 24, 1));
  });

  testWidgets('reschedule mode says SAVE, not SCHEDULE', (tester) async {
    await open(
      tester,
      mode: ScheduleSheetMode.reschedule,
      initial: DateTime.now().add(const Duration(days: 2)),
    );
    expect(_label(en.scheduleSheetSaveButton), findsWidgets);
    expect(_label(en.scheduleSheetConfirmButton), findsNothing);
  });

  testWidgets('an out-of-range start is pulled into the window, not refused', (
    tester,
  ) async {
    // Beyond the one-year horizon — reachable from a row scheduled by an older
    // build, or one the picker was handed by a stale list.
    //
    // The picker clamps its own selection, so the sheet has to agree: a sheet
    // that kept the impossible date would render a picker sitting on a legal
    // one while the summary underneath called it out of range, and the user
    // would be looking at two contradictory answers to the same question.
    ScheduleChoice? got;
    phone(tester);
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          got = await showScheduleMessageSheet(
            context,
            mode: ScheduleSheetMode.reschedule,
            initial: DateTime.now().add(const Duration(days: 400)),
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No contradiction on screen, and the button is live.
    expect(find.text(en.scheduleErrorOutOfRange), findsNothing);

    await tester.tap(_label(en.scheduleSheetSaveButton).last);
    await tester.pumpAndSettle();

    expect(got, isA<ScheduleAt>());
    final at = (got! as ScheduleAt).at;
    expect(
      at.isBefore(DateTime.now().add(kScheduleMaxHorizon)),
      isTrue,
      reason: 'the sheet must never return an instant the server would refuse',
    );
    expect(at.isAfter(DateTime.now().add(kScheduleMinLead)), isTrue);
  });

  testWidgets('the queue is reachable even with nothing queued', (
    tester,
  ) async {
    // The regression this guards: the pill was the only route to the queued
    // list, so choosing "badge" hid the list AND the setting that would bring
    // the pill back — a one-way door out of the feature. This row is the way
    // in, and it is shown at zero precisely so it is also the way back.
    ScheduleChoice? got;
    phone(tester);
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          got = await showScheduleMessageSheet(context, queuedCount: 0);
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final row = find.text(en.scheduleSheetQueuedRow(0));
    expect(row, findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(got, isA<ScheduleShowQueued>());
  });

  testWidgets('the queue row counts what is waiting', (tester) async {
    phone(tester);
    await open(tester);
    expect(find.text(en.scheduleSheetQueuedRow(0)), findsOneWidget);
  });

  testWidgets('reschedule mode offers no way back into the queue', (
    tester,
  ) async {
    // It is reached FROM the queue, so a row leading back to it is a loop.
    await open(
      tester,
      mode: ScheduleSheetMode.reschedule,
      initial: DateTime.now().add(const Duration(days: 2)),
    );
    expect(find.text(en.scheduleSheetQueuedRow(0)), findsNothing);
  });
}

/// Finds a button by its string, whatever case the sheet sets it in: the
/// shared sheet buttons show their labels in sentence case, while the
/// strings themselves are stored in capitals.
Finder _label(String s) => find.byWidgetPredicate(
      (w) => w is Text && w.data?.toLowerCase() == s.toLowerCase(),
    );
