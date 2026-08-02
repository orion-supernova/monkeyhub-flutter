import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/file_url_cache.dart';

/// The URL half of the image-cache fix.
///
/// Three widgets used to keep their own process-local map, so a cold start
/// issued one `files:getFileUrl` query per distinct attachment before any byte
/// could be requested — a few dozen round trips sitting in front of the first
/// frame of the chat list. The properties that matter: a warm id resolves with
/// no query at all, and a burst of widgets mounting the same id in one frame
/// produces one query rather than N.
void main() {
  final cache = FileUrlCache.instance;

  // Deliberately NO binding. Persistence is switched off instead, because
  // initializing one for `SharedPreferences` would put the whole file in a
  // fake-async zone where a plain awaited Future never completes — the same
  // trap image_crop_geometry_test.dart documents for image codecs. What's under
  // test here is the in-memory coalescing, not the write.
  setUp(() {
    cache.debugReset();
    cache.debugPersist = false;
  });
  tearDown(cache.debugReset);

  test('a seeded id is readable synchronously, so no frame shimmers', () {
    cache.debugSeed({'abc': 'https://example.test/api/storage/1'});
    expect(cache.peek('abc'), 'https://example.test/api/storage/1');
  });

  test('an unknown id peeks null rather than throwing', () {
    expect(cache.peek('never-seen'), isNull);
  });

  test('a warm id never calls the fetcher', () async {
    cache.debugSeed({'abc': 'https://example.test/api/storage/1'});
    var calls = 0;
    final url = await cache.resolve('abc', () async {
      calls++;
      return 'wrong';
    });
    expect(url, 'https://example.test/api/storage/1');
    expect(calls, 0);
  });

  test('concurrent resolves of one id share a single fetch', () async {
    // The chat list mounts every row in one frame; without coalescing, ten rows
    // sharing a sender fire ten identical queries.
    var calls = 0;
    final gate = Completer<String>();
    final futures = List.generate(
      10,
      (_) => cache.resolve('abc', () {
        calls++;
        return gate.future;
      }),
    );
    gate.complete('https://example.test/api/storage/1');
    final urls = await Future.wait(futures);

    expect(calls, 1);
    expect(urls, everyElement('https://example.test/api/storage/1'));
  });

  test('a resolved id is warm afterwards, and the next resolve is free', () async {
    var calls = 0;
    Future<String> fetch() async {
      calls++;
      return 'https://example.test/api/storage/1';
    }

    await cache.resolve('abc', fetch);
    expect(cache.peek('abc'), 'https://example.test/api/storage/1');
    await cache.resolve('abc', fetch);
    expect(calls, 1);
  });

  test('a failed fetch is not cached, and does not wedge the id', () async {
    var calls = 0;
    Future<String> failing() async {
      calls++;
      throw StateError('offline');
    }

    await expectLater(cache.resolve('abc', failing), throwsStateError);
    expect(cache.peek('abc'), isNull);

    // The in-flight entry has to be cleared on failure too, or one dropped
    // request would poison that id for the rest of the session.
    await expectLater(cache.resolve('abc', failing), throwsStateError);
    expect(calls, 2);
  });

  test('a null URL is not cached, so the id can heal later', () async {
    // `files:getFileUrl` answers null for a view-once file and for a swept
    // blob. The old code did `res.toString()` on that, cached the literal
    // string "null" as if it were a URL, and persisted it — pinning the id to
    // broken for the life of the install. A null must stay an answer, not
    // become an entry.
    var calls = 0;
    Future<String?> gone() async {
      calls++;
      return null;
    }

    expect(await cache.resolve('abc', gone), isNull);
    expect(cache.peek('abc'), isNull);

    expect(await cache.resolve('abc', gone), isNull);
    expect(calls, 2);

    // And once the backend does have a URL, the id resolves normally.
    final url =
        await cache.resolve('abc', () async => 'https://example.test/api/storage/1');
    expect(url, 'https://example.test/api/storage/1');
  });

  test('an empty URL is treated as no URL', () async {
    expect(await cache.resolve('abc', () async => ''), isNull);
    expect(cache.peek('abc'), isNull);
  });

  test('invalidate forces the next resolve back to the fetcher', () async {
    cache.debugSeed({'abc': 'https://example.test/api/storage/old'});
    cache.invalidate('abc');
    expect(cache.peek('abc'), isNull);

    final url =
        await cache.resolve('abc', () async => 'https://example.test/api/storage/new');
    expect(url, 'https://example.test/api/storage/new');
  });
}
