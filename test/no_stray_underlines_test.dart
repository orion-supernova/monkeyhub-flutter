@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: **nothing in this app is underlined unless it is a link or
/// the user asked for it.**
///
/// A standing instruction, given 2026-09-21 after the drag chrome shipped with
/// red and yellow underlines under every file name and verdict: "never use
/// yellow underlines… I hate underlines if it's specifically not needed like
/// hyperlinks etc."
///
/// Two ways an underline gets into this app, and this file guards both.
///
/// **Written deliberately** — caught by the allow-list below. Every entry is a
/// hyperlink or a formatting control the user drove themselves; anything else
/// has to earn a line here and a reason.
///
/// **Inherited by accident** — the subtler one, and the one that actually
/// shipped. A `TextStyle` inherits every field it does not set, so a widget
/// mounted outside a Scaffold picks up Flutter's debug fallback: red text
/// under a double yellow underline. `drop_chrome_test.dart` covers the drag
/// chrome directly; the rule here is that a `decorationColor` must never be
/// set where the `decoration` beside it can be null, because that combination
/// means "whatever is inherited, painted in this colour" — which is exactly
/// how the file names came out underlined in red.
void main() {
  /// Files allowed to underline, and why. A hyperlink or user-applied
  /// formatting; nothing else.
  const allowed = <String, String>{
    'lib/screens/login_screen.dart': 'the legal links under the sign-in form',
    'lib/widgets/composer_format_toolbar.dart':
        'the U button, which has to look like what it does',
    'lib/widgets/mention_text_controller.dart':
        'the composer drawing user-applied underline/link formatting live',
    'lib/widgets/linkified_text.dart':
        'the same user-applied formatting, in the transcript',
    'lib/widgets/message_bubble.dart': 'link styling in a bubble and a caption',
  };

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('only links and user formatting are underlined', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = file.path;
      if (allowed.containsKey(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Prose about the rule is the point of the rule, not a breach of it.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        if (!line.contains('TextDecoration.underline')) continue;
        offenders.add('$path:${i + 1}: ${trimmed.trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Underlines outside the allow-list. If this is a hyperlink or a '
          'formatting control, add the file to `allowed` with the reason. '
          'Otherwise take it out — the standing instruction is no underlines.\n'
          '${offenders.join('\n')}',
    );
  });

  test('every allow-listed file still underlines something', () {
    // Keeps the list honest. An entry left behind after its underline is gone
    // is a hole the next stray one walks through.
    final stale = <String>[];
    for (final path in allowed.keys) {
      final file = File(path);
      if (!file.existsSync()) {
        stale.add('$path (gone)');
        continue;
      }
      if (!file.readAsStringSync().contains('TextDecoration.underline')) {
        stale.add('$path (no longer underlines anything)');
      }
    }
    expect(stale, isEmpty, reason: 'drop these from `allowed`:\n${stale.join('\n')}');
  });

  test('no decorationColor is set beside a decoration that can be null', () {
    // The accidental path. `decoration: cond ? x : null` with an unconditional
    // `decorationColor` does not mean "no decoration" — it means "whatever is
    // inherited, in this colour", and outside a Scaffold what is inherited is
    // Flutter's yellow debug underline.
    final offenders = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('decorationColor:')) continue;
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//')) continue;
        // The `decoration:` it belongs to is the nearest one above it inside
        // the same copyWith / TextStyle call — six lines is generous for the
        // ternaries this codebase writes.
        final window = lines
            .sublist((i - 8).clamp(0, i), i)
            .where((l) => !l.trimLeft().startsWith('//'))
            .join(' ');
        if (!window.contains('decoration:')) {
          offenders.add('${file.path}:${i + 1}: no decoration: above it');
          continue;
        }
        final after = window.substring(window.lastIndexOf('decoration:'));
        if (RegExp(r':\s*null\s*,?\s*$').hasMatch(after.trimRight())) {
          offenders.add('${file.path}:${i + 1}: decoration can be null');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
