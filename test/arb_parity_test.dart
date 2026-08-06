import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the twelve ARB files against silent drift.
///
/// Nothing enforced this before. A key added to `app_en.arb` and forgotten in
/// the other eleven compiles cleanly, passes `flutter analyze`, and falls back
/// to English at runtime for that locale — no test, no build step and no code
/// review reliably catches it, because the failure is invisible unless you
/// happen to be running the app in the affected language.
///
/// Deliberately reads the ARBs off disk rather than the generated Dart: the
/// generated code is derived from `app_en.arb` alone, so it is exactly the
/// artifact that CANNOT see a missing translation.
void main() {
  final dir = Directory('lib/l10n');
  final arbs = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, dynamic> read(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  /// Message keys only — `@@locale` and the `@key` metadata blocks are not
  /// translatable content and only English carries the latter.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final english = arbs.firstWhere((f) => f.path.endsWith('app_en.arb'));
  final en = read(english);
  final enKeys = messageKeys(en);

  test('every locale ships the same key set as English', () {
    expect(arbs.length, 12, reason: 'expected 12 ARB files in lib/l10n');

    final problems = <String>[];
    for (final f in arbs) {
      if (f.path == english.path) continue;
      final keys = messageKeys(read(f));
      final missing = enKeys.difference(keys);
      final extra = keys.difference(enKeys);
      if (missing.isNotEmpty) {
        problems.add('${f.uri.pathSegments.last} is MISSING ${missing.length}: '
            '${(missing.toList()..sort()).take(8).join(', ')}');
      }
      if (extra.isNotEmpty) {
        problems.add('${f.uri.pathSegments.last} has ORPHAN ${extra.length}: '
            '${(extra.toList()..sort()).take(8).join(', ')}');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every English key carries a translator description', () {
    // All 1300+ existing keys have one, and translators depend on it to know
    // where a string appears and what each placeholder holds.
    final undocumented = <String>[];
    for (final k in enKeys) {
      final meta = en['@$k'];
      if (meta is! Map || (meta['description'] as String?)?.trim().isEmpty != false) {
        undocumented.add(k);
      }
    }
    expect(
      undocumented..sort(),
      isEmpty,
      reason: 'keys in app_en.arb without an @key.description',
    );
  });

  test('placeholders match English in every locale', () {
    // The real bug this catches: a translation that drops `{count}` renders a
    // sentence with a hole in it, and one that invents `{name}` throws at
    // runtime in that locale only.
    final problems = <String>[];
    for (final f in arbs) {
      if (f.path == english.path) continue;
      final arb = read(f);
      final name = f.uri.pathSegments.last;
      for (final k in messageKeys(arb)) {
        final source = en[k];
        final target = arb[k];
        if (source is! String || target is! String) continue;
        final want = placeholders(source);
        final got = placeholders(target);
        if (want.difference(got).isNotEmpty || got.difference(want).isNotEmpty) {
          problems.add('$name/$k: expected $want, found $got');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.take(20).join('\n'));
  });
}

/// The ICU argument names referenced by [message].
///
/// A regex cannot do this. `{count, plural, one{copied} other{...}}` contains
/// `one{copied}`, and any pattern loose enough to catch `{name}` also catches
/// `{copied}` — a plural *case body* that happens to be a single word. That
/// false positive fires on real, correct strings in this repo, so the scanner
/// has to understand the two-level structure: an argument is `{name}` or
/// `{name, type, <selectors>}`, and each selector's body is itself a message
/// that may contain further arguments.
Set<String> placeholders(String message) {
  final found = <String>{};
  _scanMessage(message, found);
  return found;
}

final _ident = RegExp(r'^[A-Za-z_]\w*$');

void _scanMessage(String m, Set<String> out) {
  var i = 0;
  while (i < m.length) {
    if (m[i] != '{') {
      i++;
      continue;
    }
    final end = _matchBrace(m, i);
    if (end < 0) return; // unbalanced — malformed ARB, let another test say so
    final inner = m.substring(i + 1, end);
    final comma = inner.indexOf(',');
    if (comma < 0) {
      final name = inner.trim();
      if (_ident.hasMatch(name)) out.add(name);
    } else {
      final name = inner.substring(0, comma).trim();
      if (_ident.hasMatch(name)) out.add(name);
      // Everything after the type is a selector list; each `word{...}` body is
      // a nested message and is where `{count}` typically reappears.
      _scanSelectors(inner.substring(comma + 1), out);
    }
    i = end + 1;
  }
}

void _scanSelectors(String s, Set<String> out) {
  var i = 0;
  while (i < s.length) {
    if (s[i] != '{') {
      i++;
      continue;
    }
    final end = _matchBrace(s, i);
    if (end < 0) return;
    _scanMessage(s.substring(i + 1, end), out);
    i = end + 1;
  }
}

/// Index of the `}` closing the `{` at [open], or -1 if unbalanced.
int _matchBrace(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
