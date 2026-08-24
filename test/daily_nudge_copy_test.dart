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
/// So this test reads both sides and insists they agree: every `app_*.arb` has
/// a row in `NUDGE_COPY`, every row is as varied as English's, and every line
/// fits the payload budget `push.ts` would otherwise silently truncate.
void main() {
  const copyFile = 'backend/convex/dailyNudge.ts';
  // `TITLE_MAX` / `BODY_MAX` in backend/convex/push.ts, past which `clamp`
  // replaces the tail with "…". A truncated push in a language nobody on the
  // team reads is a thing you find out about from a user.
  const titleMax = 64;
  const bodyMax = 200;

  /// The six lists every row carries. `titles` is the notification title; the
  /// rest are bodies, one list per thing that can be true of the reader.
  const fields = [
    'titles',
    'fresh',
    'partway',
    'halfDone',
    'oneLeft',
    'friendsAhead',
  ];

  /// The lists whose lines may carry `{count}` — how many are LEFT, and how
  /// many FRIENDS. Anywhere else it would render a number that means nothing,
  /// or worse, the literal braces.
  const countable = {'partway', 'friendsAhead'};

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
        .map((n) =>
            n.substring(4, n.length - 4).toLowerCase().replaceAll('_', '-'))
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

  /// Every row, as locale → field → lines. Parsed rather than eval'd, which is
  /// why the table's shape (two-space keys, four-space fields) is load-bearing
  /// and the failure messages below say so.
  Map<String, Map<String, List<String>>> rows() {
    final table = copyTable();
    // Bare tags are written unquoted in TS ("en:"); ones with a hyphen must be
    // quoted ('"pt-br":'). Accept either so the table stays idiomatic.
    final rowStart = RegExp(r'^  "?([a-z]{2}(?:-[a-z]{2})?)"?: \{$', multiLine: true);
    // `titles` fits on one line, the body lists do not — accept either.
    final listStart = RegExp(r'^    (\w+): \[', multiLine: true);
    final literal = RegExp(r'"((?:[^"\\]|\\.)*)"');

    final out = <String, Map<String, List<String>>>{};
    final starts = rowStart.allMatches(table).toList();
    expect(starts, isNotEmpty, reason: 'no rows found — did the table move?');
    for (var i = 0; i < starts.length; i++) {
      final from = starts[i].end;
      final to = i + 1 < starts.length ? starts[i + 1].start : table.length;
      final body = table.substring(from, to);
      final lists = <String, List<String>>{};
      final listStarts = listStart.allMatches(body).toList();
      for (var j = 0; j < listStarts.length; j++) {
        final lFrom = listStarts[j].end;
        final close = body.indexOf('],', lFrom);
        expect(close, greaterThan(lFrom),
            reason: '${starts[i].group(1)}.${listStarts[j].group(1)} is not '
                'closed by "],"');
        lists[listStarts[j].group(1)!] = literal
            .allMatches(body.substring(lFrom, close))
            .map((m) => m.group(1)!)
            .toList();
      }
      out[starts[i].group(1)!] = lists;
    }
    return out;
  }

  test('every shipped language has its own nudge copy', () {
    final table = rows();
    for (final locale in shippedLocales()) {
      expect(
        table.containsKey(locale),
        isTrue,
        reason: 'lib/l10n/app_$locale.arb ships, but NUDGE_COPY in $copyFile '
            'has no "$locale" row — the daily games nudge would reach every '
            'one of those users in English',
      );
    }
  });

  test('every row carries all six lists, none of them empty', () {
    // A missing list resolves to `undefined` inside `poolFor`, and the reader
    // gets a bodyless push — a notification that renders as a bare app name.
    rows().forEach((locale, lists) {
      for (final field in fields) {
        expect(lists[field], isNotNull,
            reason: '"$locale" has no `$field` list');
        expect(lists[field], isNotEmpty,
            reason: '"$locale".$field is empty');
      }
    });
  });

  test('no language is given less variety than English', () {
    // The whole point of the rewrite: this notification arrives at the same
    // hour every day forever, and a row quietly down to one line puts that
    // language back on the treadmill the rest of them just got off — silently,
    // because nothing else compares the rows.
    final table = rows();
    final en = table['en'];
    expect(en, isNotNull, reason: 'no "en" row to measure against');
    table.forEach((locale, lists) {
      for (final field in fields) {
        expect(
          lists[field]!.length,
          en![field]!.length,
          reason: '"$locale".$field has ${lists[field]!.length} lines, '
              'en has ${en[field]!.length}',
        );
      }
    });
  });

  test('no line is long enough to be clamped, blank, or duplicated', () {
    rows().forEach((locale, lists) {
      lists.forEach((field, lines) {
        final max = field == 'titles' ? titleMax : bodyMax;
        for (final line in lines) {
          expect(line.trim(), isNotEmpty,
              reason: '"$locale".$field has a blank line');
          expect(line.length, lessThanOrEqualTo(max),
              reason: 'push.ts would clamp "$locale".$field: "$line"');
        }
        expect(lines.toSet().length, lines.length,
            reason: '"$locale".$field repeats a line — the rotation would '
                'land on the same words twice in a cycle');
      });
    });
  });

  test('{count} appears only where a number is passed', () {
    // `composeNudge` substitutes one number, and which number it is comes from
    // the list the line was drawn from. A placeholder in `fresh` or `oneLeft`
    // would render whatever happened to be in scope.
    rows().forEach((locale, lists) {
      lists.forEach((field, lines) {
        for (final line in lines) {
          if (countable.contains(field)) continue;
          expect(line.contains('{count}'), isFalse,
              reason: '"$locale".$field cannot carry {count}: "$line"');
        }
      });
    });
  });
}
