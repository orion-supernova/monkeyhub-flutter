@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: which messages the shared-content browser can see at all.
///
/// `galleryBucketFor` is a pure three-argument function in
/// backend/convex/messages.ts, and its two easy-to-lose arguments each guard a
/// specific, silent failure:
///
///  * `hasBlob` — `messages:send` accepts `type: "image"` with no
///    `mediaStorageId`, and `ChatRepository` posts exactly that when its
///    retained-bytes cap refuses an upload. Bucketing one puts a tile in the
///    grid that can never load and can never be dismissed.
///  * `viewOnce` — an armed photo must get NO bucket, because that is what
///    keeps it out of the browser structurally. `eq()` cannot match an absent
///    field, so the row is outside the index range rather than filtered out of
///    it, and no read path has to remember to exclude it.
///
/// Returning `undefined` rather than a `"none"` sentinel is load-bearing for
/// the same reason, so the absence is asserted as absence.
///
/// A source scan rather than a behaviour test because the function is
/// TypeScript and there is no VM to run it in. Same shape as
/// `web_safe_apis_test.dart` and `url_detector_parity_test.dart`.
void main() {
  late String body;

  setUpAll(() {
    final source = File('backend/convex/messages.ts').readAsStringSync();
    final start = source.indexOf('export function galleryBucketFor(');
    expect(
      start,
      isNonNegative,
      reason: 'galleryBucketFor was renamed or moved out of messages.ts',
    );
    // Bounded at the next top-level declaration so nothing below leaks in.
    final end = source.indexOf('\n/**', start);
    body = source.substring(start, end == -1 ? source.length : end);
  });

  test('refuses to bucket anything without a blob, first', () {
    // Must be the FIRST branch: a later check would let the `type` switch
    // below return "media" for an image whose upload never landed.
    final guard = body.indexOf('if (!hasBlob || viewOnce) return undefined;');
    final switchAt = body.indexOf('switch (type)');

    expect(
      guard,
      isNonNegative,
      reason:
          'The combined hasBlob/viewOnce guard is gone. A failed upload '
          'would become a permanently broken grid tile, and a view-once '
          'photo would enter the gallery index.',
    );
    expect(
      guard,
      lessThan(switchAt),
      reason:
          'The guard has to run before the type switch, or the switch '
          'answers for rows the guard was meant to exclude.',
    );
  });

  test('returns undefined rather than a sentinel', () {
    expect(body.contains('return undefined'), isTrue);
    expect(
      body.contains('"none"'),
      isFalse,
      reason:
          'A sentinel string would be IN the index. Absence is what keeps '
          'excluded rows outside the scan range entirely.',
    );
  });

  test('maps every attachment type, and only attachment types', () {
    // Photos and videos share one tab; voice and files get their own.
    expect(body.contains('case "image":'), isTrue);
    expect(body.contains('case "video":'), isTrue);
    expect(body.contains('return "media";'), isTrue);
    expect(body.contains('case "audio":'), isTrue);
    expect(body.contains('return "voice";'), isTrue);
    expect(body.contains('case "file":'), isTrue);
    expect(body.contains('return "file";'), isTrue);
    // Text, url and system fall through. A default that returned a bucket
    // would put every text message in the browser.
    expect(body.contains('default:'), isTrue);
  });

  test('the buckets it can return are exactly the ones roomContent serves', () {
    final rc = File('backend/convex/roomContent.ts').readAsStringSync();
    final match = RegExp(r'const BUCKETS = \[(.*?)\] as const;').firstMatch(rc);
    expect(match, isNotNull, reason: 'BUCKETS moved or changed shape');

    final served = RegExp(
      '"([a-z]+)"',
    ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
    final produced = RegExp(
      r'return "([a-z]+)";',
    ).allMatches(body).map((m) => m.group(1)!).toSet();

    expect(
      produced,
      served,
      reason:
          'A bucket written by send but not served by listBucket is content '
          'nobody can ever reach; one served but never written is a tab that '
          'is always empty. Produced: $produced, served: $served.',
    );
  });
}
