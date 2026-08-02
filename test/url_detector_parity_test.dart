@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/services/link_preview_service.dart';

/// What this pins: URL detection now exists twice, in two languages, and the
/// two halves answer different questions about the same message.
///
/// The server's `LINK_PATTERN` decides which rows carry `hasLink`, i.e. which
/// messages the LINKS tab is allowed to *read*. The client's
/// `UrlDetector._pattern` decides what it *renders* once it has them. If they
/// drift, nothing throws: the tab fetches a page of thirty messages and draws
/// zero rows, or worse, quietly never sees a link the bubbles happily
/// linkified. Neither failure points at a regex.
///
/// A source scan rather than a behaviour test because the other half is
/// TypeScript — there is no way to execute it from here. Same shape and same
/// reasoning as `web_safe_apis_test.dart`.
void main() {
  test('the server link regex is character-identical to UrlDetector', () {
    final source = File('backend/convex/messages.ts').readAsStringSync();

    // The literal as written in messages.ts: body between the delimiters, then
    // whatever flags follow.
    final match = RegExp(
      r'export const LINK_PATTERN = /(.+)/([a-z]*);',
    ).firstMatch(source);
    expect(
      match,
      isNotNull,
      reason:
          'LINK_PATTERN was renamed, moved out of messages.ts, or stopped '
          'being a plain regex literal. It is one half of a pair that must '
          'stay in step, so it has to remain readable from here.',
    );

    final serverBody = match!.group(1)!;
    final serverFlags = match.group(2)!;

    // A Dart raw string escapes nothing of its own, so the two bodies are
    // directly comparable once JS's mandatory escaping of the `/` delimiters is
    // undone: `https?:\/\/[^\s<>"]+` there is `https?://[^\s<>"]+` here.
    expect(
      serverBody.replaceAll(r'\/', '/'),
      UrlDetector.pattern.pattern,
      reason:
          'The server decides which messages the LINKS tab may read and the '
          'client decides what it renders from them. A disagreement shows up '
          'as a tab that pages forever drawing nothing, with no error anywhere.',
    );

    // Flags count as much as the body. Dart is `caseSensitive: false`, so
    // without `i` the server would leave `HTTP://EXAMPLE.COM` out of the index
    // while the bubble linkified it — the message would be a link everywhere
    // except in the tab that lists links.
    expect(
      serverFlags.contains('i'),
      !UrlDetector.pattern.isCaseSensitive,
      reason:
          'Case sensitivity must match. Server flags: "$serverFlags", '
          'Dart isCaseSensitive: ${UrlDetector.pattern.isCaseSensitive}.',
    );
  });

  test('the shared pattern actually matches what a message looks like', () {
    // Cheap end-to-end sanity on the Dart half, so a parity test passing
    // because BOTH sides were broken identically still gets caught.
    expect(UrlDetector.extract('see https://example.com/a?b=1'), [
      'https://example.com/a?b=1',
    ]);
    expect(UrlDetector.extract('http://x.dev and https://y.dev').length, 2);
    expect(UrlDetector.extract('no links here'), isEmpty);
    expect(
      UrlDetector.extract('ftp://nope.example'),
      isEmpty,
      reason: 'only http(s) — the server agrees, and must',
    );
  });
}
