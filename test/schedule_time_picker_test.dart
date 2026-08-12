import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/schedule_time_picker.dart';

/// The hand-rolled date and time picker.
///
/// It exists at all because this app has no `ThemeData` and no Material dialog
/// anywhere — see the widget's own header. What that buys in consistency it
/// costs in the things `showDatePicker` would have got right for free, and
/// those are what this file pins:
///
///  * the wheels are built for the reader's clock, so a 12-hour locale gets an
///    AM/PM column and a 24-hour one does not — get this wrong and half the
///    world can only schedule things in the morning;
///  * a selection can never leave the allowed window, however the user got
///    there. Scrolling the hour wheel backwards past `now` is the ordinary way
///    to name an instant in the past, and the picker has to correct rather than
///    refuse, or the wheel reads as broken.
void main() {
  final en = AppLocalizationsEn();

  final controller = ThemeController(BasicTheme.midnight());

  Widget host(Widget child, {bool use24Hour = true}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, navigator) => ThemeScope(
          controller: controller,
          // An ancestor MediaQuery is discarded by MaterialApp, so the
          // 24-hour flag has to be injected from inside `builder` — the trick
          // `spoiler_overlay_test.dart` uses for `disableAnimations`.
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(alwaysUse24HourFormat: use24Hour),
            child: navigator!,
          ),
        ),
        home: Scaffold(body: child),
      );

  testWidgets('names the first two days rather than dating them', (
    tester,
  ) async {
    await tester.pumpWidget(host(ScheduleTimePicker(
      initial: DateTime.now().add(const Duration(hours: 2)),
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text(en.scheduleTimePickerToday), findsOneWidget);
    expect(find.text(en.scheduleTimePickerTomorrow), findsOneWidget);
  });

  testWidgets('a 12-hour reader gets an AM/PM column', (tester) async {
    await tester.pumpWidget(host(
      ScheduleTimePicker(
        initial: DateTime.now().add(const Duration(hours: 2)),
        onChanged: (_) {},
      ),
      use24Hour: false,
    ));
    await tester.pumpAndSettle();

    final material = MaterialLocalizations.of(
      tester.element(find.byType(ScheduleTimePicker)),
    );
    expect(find.text(material.anteMeridiemAbbreviation), findsWidgets);
    expect(find.text(material.postMeridiemAbbreviation), findsWidgets);
  });

  testWidgets('a 24-hour reader gets no AM/PM column', (tester) async {
    await tester.pumpWidget(host(
      ScheduleTimePicker(
        initial: DateTime.now().add(const Duration(hours: 2)),
        onChanged: (_) {},
      ),
      use24Hour: true,
    ));
    await tester.pumpAndSettle();

    final material = MaterialLocalizations.of(
      tester.element(find.byType(ScheduleTimePicker)),
    );
    expect(find.text(material.anteMeridiemAbbreviation), findsNothing);
    expect(find.text(material.postMeridiemAbbreviation), findsNothing);
    // Hours are zero-padded in this mode. Only the rows in view exist — the
    // wheel is virtualized — so this asserts the FORMAT of whatever is on
    // screen rather than the presence of a particular hour.
    final hours = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListWheelScrollView),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .whereType<String>();
    expect(hours, isNotEmpty);
    expect(
      hours.every((h) => h.length == 2 && int.tryParse(h) != null),
      isTrue,
      reason: 'every wheel label should be a zero-padded number, got $hours',
    );
  });

  testWidgets('opens on the instant it was handed', (tester) async {
    DateTime? reported;
    // Two days out at a clean five-minute boundary, so nothing is snapped.
    final want = DateTime.now().add(const Duration(days: 2));
    final initial = DateTime(want.year, want.month, want.day, 14, 30);

    await tester.pumpWidget(host(ScheduleTimePicker(
      initial: initial,
      onChanged: (at) => reported = at,
    )));
    await tester.pumpAndSettle();

    // Nothing has been touched, so nothing has been reported — the picker only
    // speaks when the user changes something.
    expect(reported, isNull);
    // The day it opened on is selected; its card is the one showing that date.
    expect(find.text('${initial.day}'), findsWidgets);
  });

  testWidgets('an initial in the past is pulled into the window', (
    tester,
  ) async {
    DateTime? reported;
    await tester.pumpWidget(host(ScheduleTimePicker(
      // Yesterday. A caller should never do this, but the correction is what
      // stops a stale sheet from opening on an instant that cannot be sent.
      initial: DateTime.now().subtract(const Duration(days: 1)),
      onChanged: (at) => reported = at,
    )));
    await tester.pumpAndSettle();

    // Today's card is selected rather than a card that does not exist.
    expect(find.text(en.scheduleTimePickerToday), findsOneWidget);
    // Tapping tomorrow reports an instant comfortably inside the window.
    await tester.tap(find.text(en.scheduleTimePickerTomorrow));
    await tester.pumpAndSettle();
    expect(reported, isNotNull);
    expect(reported!.isAfter(DateTime.now().add(kScheduleMinLead)), isTrue);
    expect(
      reported!.isBefore(DateTime.now().add(kScheduleMaxHorizon)),
      isTrue,
    );
  });

  testWidgets('every reported instant stays inside the window', (tester) async {
    final reported = <DateTime>[];
    await tester.pumpWidget(host(ScheduleTimePicker(
      initial: DateTime.now().add(const Duration(hours: 3)),
      onChanged: reported.add,
    )));
    await tester.pumpAndSettle();

    // Walk the visible day cards. Whatever the picker hands back, it must be
    // schedulable — the sheet's confirm button trusts this.
    await tester.tap(find.text(en.scheduleTimePickerTomorrow));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.scheduleTimePickerToday));
    await tester.pumpAndSettle();

    expect(reported, isNotEmpty);
    final floor = DateTime.now().add(kScheduleMinLead);
    final ceiling = DateTime.now().add(kScheduleMaxHorizon);
    for (final at in reported) {
      expect(
        at.isAfter(floor) || at.isAtSameMomentAs(floor),
        isTrue,
        reason: '$at is before the minimum lead',
      );
      expect(at.isBefore(ceiling), isTrue, reason: '$at is past the horizon');
    }
  });

  testWidgets('the strip stops at the one-year horizon', (tester) async {
    await tester.pumpWidget(host(ScheduleTimePicker(
      initial: DateTime.now().add(const Duration(hours: 2)),
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    // 366 cards: today plus a year. One more or one fewer is a day the sheet
    // offers that the server refuses, or a day it refuses that the server
    // would take.
    expect(list.semanticChildCount, 366);
  });
}
