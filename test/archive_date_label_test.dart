import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/feed/archive_screen.dart';

/// What this pins: **an archive date says which year it is, in words.**
///
/// The section headers once used `formatFullDate` in a one-line header beside
/// a rule and a count; on a phone that ellipsized, and the part that fell off
/// the end was the year — the one thing a reader scrolling back through months
/// cannot infer from anything else on screen. A composed "medium date · year"
/// fixed the year but read as a stamp ("4 Eki Paz · 2026"). The header wraps
/// to two lines now, so the label is the full, spelled-out date again.
///
/// It comes from `MaterialLocalizations`, which is the only date formatter
/// this app has: `intl` is a transitive dependency and not worth promoting for
/// one string.
void main() {
  Future<BuildContext> host(WidgetTester tester, Locale locale) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return ctx;
  }

  testWidgets('the label carries the year', (tester) async {
    final ctx = await host(tester, const Locale('en'));
    final label = archiveDayLabel(ctx, '2024-03-07');
    expect(label, contains('2024'));
    // Spelled out, not abbreviated: a date, not a stamp.
    expect(label, contains('March'));
    expect(label, contains('Thursday'));
  });

  testWidgets('it is localized, not English glued together', (tester) async {
    final ctx = await host(tester, const Locale('tr'));
    final label = archiveDayLabel(ctx, '2024-03-07');
    expect(label, contains('2024'));
    // Perşembe is Turkish for Thursday and Mart for March, both in full.
    // English would say "Thursday", so this fails the moment anybody
    // hardcodes an English date here — and "Per" alone would mean the stamp
    // is back.
    expect(label, contains('Perşembe'));
    expect(label, contains('Mart'));
  });

  test('a dayKey parses, and a broken one does not take the screen with it', () {
    expect(archiveDay('2026-08-28'), DateTime(2026, 8, 28));
    // Rows written by a newer client, or a truncated key: the archive renders
    // the raw string rather than throwing on a whole page of photographs.
    expect(archiveDay('2026-08'), isNull);
    expect(archiveDay('not-a-date'), isNull);
    expect(archiveDay(''), isNull);
  });

  testWidgets('an unparseable key falls back to itself, not to a crash', (
    tester,
  ) async {
    final ctx = await host(tester, const Locale('en'));
    expect(archiveDayLabel(ctx, 'whatever'), 'whatever');
  });
}
