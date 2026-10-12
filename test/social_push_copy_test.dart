import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Friend-activity notifications are written by the backend, in a table the
/// Dart localization tooling knows nothing about.
///
/// Exactly the problem `daily_nudge_copy_test.dart` guards, one table over, and
/// worth stating again because the failure is the same and just as quiet: the
/// app gains a thirteenth language, `flutter gen-l10n` is happy, `tsc` is
/// happy, and every highlight notification in that language arrives in English
/// forever with nothing anywhere saying so.
///
/// This table has a second way to rot that `NUDGE_COPY` does not. Its `tags`
/// and `games` entries are LIFTED from `lib/l10n/app_*.arb` — the point label a
/// friend sees on the composer, the game name on its own tile — so a row that
/// is present but short falls back to the raw id (`"calledIt"`, `"sudoku"`) for
/// one entry only, in one language, on a banner nobody on the team reads.
void main() {
  const copyFile = 'backend/convex/socialPush.ts';
  // `TITLE_MAX` / `BODY_MAX` in backend/convex/push.ts, past which `clamp`
  // replaces the tail with "…".
  const bodyMax = 200;

  /// The one-line fields. Every row needs all of them.
  const lines = [
    'highlight',
    'more',
    'gameSolved',
    'gameGaveUp',
    'codeSolved',
    'codeFailed',
    'commented',
    'replied',
    'reacted',
    'reactedComment',
  ];

  /// What each line MUST interpolate. A missing placeholder is not a crash —
  /// `fill` leaves the text alone — so "finished in 2:14" silently becomes
  /// "finished", which reads as complete and says nothing.
  const required = {
    'more': ['{count}'],
    'gameSolved': ['{game}', '{time}'],
    'gameGaveUp': ['{game}'],
    'codeSolved': ['{score}'],
    'reacted': ['{emoji}'],
    'reactedComment': ['{emoji}'],
  };

  /// The five tags `feed.ts` accepts and the nine games `games.ts` serves.
  /// Mirrored here rather than imported because that is the whole point: these
  /// are two files in two languages that have to agree.
  const tagIds = ['fate', 'jinx', 'luck', 'calledIt', 'npc'];
  const gameIds = [
    'queens',
    'tango',
    'zip',
    'sudoku',
    'flow',
    'futoshiki',
    'nonogram',
    'minesweeper',
    'starbattle',
  ];

  late String source;
  setUpAll(() {
    final file = File(copyFile);
    expect(file.existsSync(), isTrue, reason: 'missing $copyFile');
    source = file.readAsStringSync();
  });

  /// The locales the app ships, keyed as `SOCIAL_COPY` keys them: lowercase,
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

  /// The body of the `SOCIAL_COPY` literal, so a stray "en" elsewhere in the
  /// file (a doc comment, the fallback in `socialCopyFor`) cannot pass for a
  /// row.
  String copyTable() {
    final start = source.indexOf('const SOCIAL_COPY');
    expect(start, greaterThan(-1), reason: 'SOCIAL_COPY not found — renamed?');
    final open = source.indexOf('{', start);
    final end = source.indexOf('\n};', open);
    expect(end, greaterThan(open),
        reason: 'SOCIAL_COPY is not closed by "\\n};"');
    return source.substring(open, end);
  }

  /// Every row, split into its raw text. Parsed rather than eval'd, which is
  /// why the table's two-space row keys are load-bearing.
  Map<String, String> rows() {
    final table = copyTable();
    // Bare tags are unquoted in TS ("en:"); hyphenated ones must be quoted.
    final rowStart =
        RegExp(r'^  "?([a-z]{2}(?:-[a-z]{2})?)"?: \{$', multiLine: true);
    final starts = rowStart.allMatches(table).toList();
    expect(starts, isNotEmpty, reason: 'no rows found — did the table move?');
    final out = <String, String>{};
    for (var i = 0; i < starts.length; i++) {
      final to = i + 1 < starts.length ? starts[i + 1].start : table.length;
      out[starts[i].group(1)!] = table.substring(starts[i].end, to);
    }
    return out;
  }

  /// One `field: "value"` out of a row, at any nesting depth.
  String? field(String row, String name) {
    final m = RegExp('(?:^|\\s)$name: "((?:[^"\\\\]|\\\\.)*)"').firstMatch(row);
    return m?.group(1);
  }

  test('every shipped language has its own row', () {
    final table = rows();
    for (final locale in shippedLocales()) {
      expect(
        table.containsKey(locale),
        isTrue,
        reason: 'lib/l10n/app_$locale.arb ships, but SOCIAL_COPY in $copyFile '
            'has no "$locale" row — every highlight, point and shared game '
            'result would reach those users in English',
      );
    }
  });

  test('every row carries every line, none of them empty', () {
    rows().forEach((locale, row) {
      for (final name in lines) {
        final value = field(row, name);
        expect(value, isNotNull, reason: '"$locale" has no `$name` line');
        expect(value, isNotEmpty, reason: '"$locale".$name is empty');
      }
    });
  });

  test('every line keeps the placeholders it is filled with', () {
    rows().forEach((locale, row) {
      required.forEach((name, tokens) {
        final value = field(row, name) ?? '';
        for (final token in tokens) {
          expect(
            value.contains(token),
            isTrue,
            reason: '"$locale".$name is missing $token — `fill` would leave '
                'the line alone, so it renders as a complete sentence that '
                'has quietly dropped the number it was written to carry',
          );
        }
      });
    });
  });

  test('every row names all five tags and all nine games', () {
    rows().forEach((locale, row) {
      for (final id in [...tagIds, ...gameIds]) {
        final value = field(row, id);
        expect(
          value,
          isNotNull,
          reason: '"$locale" has no label for "$id" — `momentLine`/'
              '`sendGameResultPush` fall back to the raw id, so that one '
              'notification reads "$id" in $locale and nothing else changes',
        );
        expect(value, isNotEmpty, reason: '"$locale".$id is empty');
      }
    });
  });

  test('no line can be truncated by the payload clamp', () {
    // A body past BODY_MAX loses its tail to "…". These are short lines, so
    // this is a guard against a future translation rather than a live risk —
    // which is exactly when a truncated push in a language nobody on the team
    // reads gets shipped.
    rows().forEach((locale, row) {
      for (final name in lines) {
        final value = field(row, name) ?? '';
        expect(
          value.length,
          lessThanOrEqualTo(bodyMax),
          reason: '"$locale".$name is ${value.length} chars, past BODY_MAX '
              '($bodyMax) — push.ts would clamp it',
        );
      }
    });
  });

  test('the two kinds are unbadged', () {
    // Neither is an unread item and neither has a list the app could clear, so
    // a badge on one is a count nothing can take back down. `push.ts` expresses
    // this as a set on two transports and as an allow-list on the third; this
    // asserts the set, which is the half a new kind gets added to.
    final push = File('backend/convex/push.ts').readAsStringSync();
    final start = push.indexOf('UNBADGED_KINDS');
    expect(start, greaterThan(-1), reason: 'UNBADGED_KINDS not found');
    final end = push.indexOf(']);', start);
    expect(end, greaterThan(start));
    final decl = push.substring(start, end);
    for (final kind in ['friend_moment', 'game_result']) {
      expect(decl.contains('"$kind"'), isTrue,
          reason: '$kind is not in UNBADGED_KINDS — it would carry a badge '
              'count that nothing in the app can clear');
    }
  });
}
