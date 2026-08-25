@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: poster extraction reads `XFile.path`, and on web that is a
/// `blob:` URL with no filesystem behind it.
///
/// It is the same trap `UploadService` documents for `uploadXFile`, and it
/// fails the same quiet way: the value is a perfectly good non-empty String,
/// so nothing throws at the call site. `video_thumbnail` has no web
/// implementation either, so the actual outcome on web is a
/// `MissingPluginException` on every video send — inside a `try` that is
/// supposed to be swallowing codec failures, which means a send path that
/// silently costs a round trip and a caught exception on every video, forever.
///
/// Guarding inside [VideoPoster.extract] is not sufficient on its own and is
/// not the point. The call site must not evaluate `picked.path` on web at all,
/// because reading it is what the platform has no answer for.
///
/// A source scan because the failure only exists in a browser, which the VM
/// test runner is not. Same shape and same reasoning as
/// `web_safe_apis_test.dart`, which this file sits beside deliberately.
void main() {
  test('every VideoPoster.extract call site is behind a kIsWeb guard', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The implementation is allowed to name itself; it carries its own
      // internal guard as defence in depth.
      if (entity.path.endsWith('media/video_poster.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // Prose about the trap is the point of the trap, not a violation.
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        if (!line.contains('VideoPoster.extract')) continue;

        // The guard has to be on the same EXPRESSION, not merely somewhere in
        // the file — a `kIsWeb` check three methods away protects nothing. But
        // "expression" is not "line": a wrapped ternary puts the condition
        // above the call, which is how the (correctly guarded) share path in
        // room_screen.dart read as a violation for as long as this test only
        // looked at one line.
        //
        // So walk back to the start of the statement and no further. A
        // previous line that ended in `;`, `{` or `}` closed something else,
        // and anything beyond it is a different expression.
        // Comments are EXCLUDED from the walk-back, and that is not a detail:
        // the prose above this very call site says the words "the `kIsWeb`
        // guard is belt-and-braces", so counting comment text made the whole
        // check pass on code with no guard at all.
        final buffer = StringBuffer(line);
        for (var j = i - 1; j >= 0 && j >= i - 6; j--) {
          final prev = lines[j].trimRight();
          final prevTrimmed = prev.trimLeft();
          if (prevTrimmed.startsWith('//') || prevTrimmed.startsWith('*')) {
            continue;
          }
          buffer.write(prev);
          if (prev.endsWith(';') || prev.endsWith('{') || prev.endsWith('}')) {
            break;
          }
        }
        if (!buffer.toString().contains('kIsWeb')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'VideoPoster.extract reads a filesystem path. On web XFile.path '
          'is a blob: URL and video_thumbnail has no implementation at all, so '
          'an unguarded call is a caught MissingPluginException on every video '
          'send.\nFound at: ${offenders.join(', ')}',
    );
  });

  test('the extractor keeps its own guard as well', () {
    final source = File('lib/media/video_poster.dart').readAsStringSync();
    expect(
      source.contains('if (kIsWeb) return null;'),
      isTrue,
      reason:
          'defence in depth — the call-site guard is the contract, this '
          'is what makes a missed one degrade instead of throw',
    );
  });

  test('a poster is never uploaded for an armed send', () {
    // A still frame of a view-once video is precisely the thing that must not
    // outlive it. The server refuses to store one, so uploading it anyway
    // would orphan a blob containing exactly the leaked content.
    final source = File('lib/data/chat_repository.dart').readAsStringSync();
    expect(
      source.contains('posterBytes: viewOnce ? null : posterBytes'),
      isTrue,
      reason:
          'sendMediaLocal must drop the poster on an armed send, matching '
          "the server's refusal in messages:send",
    );
  });

  test('the poster upload cannot fail the video it belongs to', () {
    final source = File('lib/data/chat_repository.dart').readAsStringSync();
    final at = source.indexOf('poster upload failed');
    expect(
      at,
      isNonNegative,
      reason:
          'the poster upload must be wrapped in its own catch — a poster '
          'is an enhancement to a send that has to happen regardless',
    );
  });
}
