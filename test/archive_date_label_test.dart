import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/feed/archive_screen.dart';

/// What this pins: **an archive date says which year it is.**
///
/// The section headers used `formatFullDate` — "Friday, August 28, 2026" — in
/// a `Flexible` with `maxLines: 1`, beside a rule and a count. On a phone that
/// ellipsizes, and the part that falls off the end is the year: the one thing a
/// reader scrolling back through months cannot infer from anything else on
/// screen. The day chips along the top had the same hole for a different
/// reason — they were a bare "28 / 08" stamp with no year in them at all.
///
/// So the label is composed rather than taken whole, and it is short enough not
/// to need truncating. Both halves come from `MaterialLocalizations`, which is
/// the only date formatter this app has: `intl` is a transitive dependency and
/// not worth promoting for one string.
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
    // Short enough to survive the header's single line beside a rule and a
    // count — which is the whole reason it is not `formatFullDate`.
    expect(label.length, lessThan(28));
  });

  testWidgets('it is localized, not English glued together', (tester) async {
    final ctx = await host(tester, const Locale('tr'));
    final label = archiveDayLabel(ctx, '2024-03-07');
    expect(label, contains('2024'));
    // "Per" is Perşembe — Turkish for Thursday. English would say "Thu", so
    // this fails the moment anybody hardcodes an English date here.
    expect(label, contains('Per'));
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
