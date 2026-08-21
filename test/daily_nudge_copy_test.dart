import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The daily games nudge is written by the backend, in a table the Dart
/// localization tooling knows nothing about.
///
/// That is unavoidable — the notification is composed on a server, hours before
/// any `BuildContext` exists — but it means the app can gain a thirteenth
/// language and this one push will keep arriving in English, with nothing
/// failing to say so. `flutter gen-l10n` cannot catch it and neither can `tsc`.
///
/// So this test reads both sides and insists they agree: every `app_*.arb` has a
/// row in `NUDGE_COPY`, and every line in it fits the payload budget that
/// `push.ts` would otherwise silently truncate with an ellipsis.
void main() {
  const copyFile = 'backend/convex/dailyNudge.ts';
  // `TITLE_MAX` / `BODY_MAX` in backend/convex/push.ts, past which `clamp`
  // replaces the tail with "…". A truncated push in a language nobody on the
  // team reads is a thing you find out about from a user.
  const titleMax = 64;
  const bodyMax = 200;

  late String source;
  setUpAll(() {
    final file = File(copyFile);
    expect(file.existsSync(), isTrue, reason: 'missing $copyFile');
    source = file.readAsStringSync();
  });

  /// The locales the app actually ships, as `NUDGE_COPY` keys them: lowercase,
  /// hyphenated. `app_pt_BR.arb` → `pt-br`.
  List<String> shippedLocales() {
    final dir = Directory('lib/l10n');
    expect(dir.existsSync(), isTrue, reason: 'missing lib/l10n');
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('app_') && n.endsWith('.arb'))
        .map((n) => n.substring(4, n.length - 4).toLowerCase().replaceAll('_', '-'))
        .toList()
      ..sort();
  }

  /// The body of the `NUDGE_COPY` literal, so a stray "en" elsewhere in the
  /// file (a doc comment, the fallback in `copyFor`) cannot pass for a row.
  String copyTable() {
    final start = source.indexOf('const NUDGE_COPY');
    expect(start, greaterThan(-1), reason: 'NUDGE_COPY not found — renamed?');
    final open = source.indexOf('{', start);
    final end = source.indexOf('\n};', open);
    expect(end, greaterThan(open), reason: 'NUDGE_COPY is not closed by "\\n};"');
    return source.substring(open, end);
  }

  test('every shipped language has its own nudge copy', () {
    final table = copyTable();
    for (final locale in shippedLocales()) {
      // Bare tags are written unquoted in TS ("en:"); ones with a hyphen must
      // be quoted ('"pt-br":'). Accept either so the table stays idiomatic.
      final present = RegExp('(^|\\s)("?)$locale\\2\\s*:').hasMatch(table);
      expect(
        present,
        isTrue,
        reason:
            'lib/l10n/app_$locale.arb ships, but NUDGE_COPY in $copyFile has '
            'no "$locale" row — the daily games nudge would reach every one of '
            'those users in English',
      );
    }
  });

  test('no nudge line is long enough to be clamped', () {
    final table = copyTable();
    // Every string literal in the table: the three lines of each row.
    final lines = RegExp(r'"((?:[^"\\]|\\.)*)"')
        .allMatches(table)
        .map((m) => m.group(1)!)
        // Keys, not copy — a row's own tag matches this pattern too.
        .where((s) => s.contains(' ') || s.length > 12)
        .toList();
    expect(lines, isNotEmpty, reason: 'no copy found — did the table move?');
    for (final line in lines) {
      expect(
        line.length,
        lessThanOrEqualTo(bodyMax),
        reason: 'push.ts would clamp this to $bodyMax chars: "$line"',
      );
    }
  });

  test('every title fits the APNs title budget', () {
    // Titles are the first field of each row, so they are the literals that
    // follow "title:".
    final titles = RegExp(r'title:\s*"((?:[^"\\]|\\.)*)"')
        .allMatches(copyTable())
        .map((m) => m.group(1)!)
        .toList();
    expect(titles.length, shippedLocales().length,
        reason: 'one title per shipped language, no more and no fewer');
    for (final title in titles) {
      expect(title.length, lessThanOrEqualTo(titleMax),
          reason: 'push.ts would clamp this title: "$title"');
      expect(title.trim(), isNotEmpty);
    }
  });

  test('every row carries both bodies', () {
    // The two variants are chosen by `claimNudges` from the day's results, so a
    // row missing one would resolve to `undefined` and send a bodyless push —
    // a notification that renders as a bare app name.
    final table = copyTable();
    final rows = RegExp(r'title:').allMatches(table).length;
    expect(RegExp(r'codeLeft:').allMatches(table).length, rows);
    expect(RegExp(r'boardsLeft:').allMatches(table).length, rows);
  });
}
