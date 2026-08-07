@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/media/video_file_cache.dart';

/// Why a video is downloaded rather than streamed.
///
/// Nothing sits in front of `AVPlayer` or `ExoPlayer` caching an HTTP response,
/// so a streamed clip re-downloads in full on every play and rebuffers on every
/// seek — which is exactly when the native scrubber invites you to seek. A
/// complete local file removes all of it. The properties that make that safe:
/// one download per id no matter how many widgets ask, a `.part` that is never
/// handed out or adopted, an extension read from the container's own magic
/// (Convex serves storage from an extension-less URL, which is what made every
/// voice note unplayable until [AudioFileCache] stopped trusting the server),
/// and a size ceiling that hands the caller back to streaming instead of
/// evicting a dozen ordinary clips for one enormous one.
void main() {
  final cache = VideoFileCache.instance;
  late Directory dir;

  /// A minimal MP4: `ftyp` at offset 4 with an MP4-family brand.
  Uint8List mp4() => Uint8List.fromList([
    0, 0, 0, 24, // box size
    ...'ftyp'.codeUnits,
    ...'mp42'.codeUnits,
    ...List.filled(64, 7),
  ]);

  /// QuickTime — same `ftyp` marker, different brand. iOS records these.
  Uint8List mov() => Uint8List.fromList([
    0, 0, 0, 24,
    ...'ftyp'.codeUnits,
    ...'qt  '.codeUnits,
    ...List.filled(64, 7),
  ]);

  Uint8List webm() =>
      Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, ...List.filled(64, 7)]);

  /// A client that answers every GET with [body], counting the calls.
  ({http.Client client, int Function() calls}) serving(
    Uint8List body, {
    Completer<void>? gate,
  }) {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (gate != null) await gate.future;
      return http.Response.bytes(body, 200);
    });
    return (client: client, calls: () => calls);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mh_video_test');
    cache.debugReset();
    cache.debugDir = dir;
  });

  tearDown(() {
    cache.debugReset();
    cache.debugDir = null;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<String> get(http.Client client, {String id = 'abc'}) => cache.resolve(
    id,
    () async => 'https://example.test/api/storage/1',
    client: client,
  );

  test('names the file from the container magic, not the served type', () async {
    final s = serving(mp4());
    final path = await get(s.client);

    // The extension is the only thing telling AVFoundation what this is: the
    // URL it came from has none and the stored content type cannot be patched.
    expect(path, endsWith('.mp4'));
    expect(File(path).readAsBytesSync(), mp4());
  });

  test('a QuickTime brand is named .mov, not folded into .mp4', () async {
    expect(await get(serving(mov()).client), endsWith('.mov'));
  });

  test('an EBML body is named .webm', () async {
    expect(await get(serving(webm()).client), endsWith('.webm'));
  });

  test('lookup is a hit-or-null read that never reaches the network', () async {
    expect(await cache.lookup('abc'), isNull);

    final s = serving(mp4());
    final path = await get(s.client);
    expect(await cache.lookup('abc'), path);

    // Cold start: the hit has to come back off the disk index alone, with no
    // URL resolve — this is what makes a replay instant and offline.
    cache.debugReset();
    cache.debugDir = dir;
    expect(await cache.lookup('abc'), path);
    expect(s.calls(), 1);
  });

  test('lookup reports a miss for a file deleted underneath it', () async {
    // Library/Caches is purgeable: iOS can reclaim these bytes at any time, and
    // handing the player a path to a file that is gone is worse than a miss.
    final path = await get(serving(mp4()).client);
    File(path).deleteSync();
    expect(await cache.lookup('abc'), isNull);
  });

  test('concurrent resolves of one id share a single download', () async {
    final gate = Completer<void>();
    final s = serving(mp4(), gate: gate);
    final futures = List.generate(10, (_) => get(s.client));
    gate.complete();
    final paths = await Future.wait(futures);

    expect(s.calls(), 1);
    expect(paths.toSet(), hasLength(1));
  });

  test('a resolved id is warm afterwards and does not re-download', () async {
    final s = serving(mp4());
    final first = await get(s.client);
    expect(await get(s.client), first);
    expect(s.calls(), 1);
  });

  test('progress is reported against the declared total', () async {
    final seen = <(int, int?)>[];
    await cache.resolve(
      'abc',
      () async => 'https://example.test/api/storage/1',
      client: serving(mp4()).client,
      onProgress: (received, total) => seen.add((received, total)),
    );

    expect(seen, isNotEmpty);
    expect(seen.last.$1, mp4().length);
    expect(seen.last.$2, mp4().length);
  });

  test('a file over the cap is refused, not cached', () async {
    // The caller streams it instead. Checked before a byte is written, so the
    // refusal doesn't cost the download it is avoiding.
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(
        Stream.value(mp4()),
        200,
        contentLength: 99 * 1024 * 1024,
      ),
    );

    await expectLater(get(client), throwsA(isA<MediaTooLarge>()));
    expect(dir.listSync(), isEmpty);
    expect(await cache.lookup('abc'), isNull);
  });

  test('a null URL surfaces as FileUnavailable, not a download', () async {
    final s = serving(mp4());
    await expectLater(
      cache.resolve('abc', () async => null, client: s.client),
      throwsA(isA<FileUnavailable>()),
    );
    expect(s.calls(), 0);
  });

  test('an id that is not a safe path segment is refused', () async {
    // The id becomes a path segment; a `../` would write outside the cache dir.
    await expectLater(
      cache.resolve('../evil', () async => 'https://example.test/x'),
      throwsA(isA<ArgumentError>()),
    );
    expect(await cache.lookup('../evil'), isNull);
  });

  test('a failed download leaves no .part and does not wedge the id', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('nope', 500);
    });

    await expectLater(get(client), throwsA(isA<HttpException>()));
    // A partial left behind would be adopted by the next launch's index and
    // handed to a player that accepts it and then fails, permanently.
    expect(dir.listSync(), isEmpty);
    // And the in-flight entry has to clear on failure too, or one dropped
    // request would pin this video to "tap to retry" for the whole session.
    await expectLater(get(client), throwsA(isA<HttpException>()));
    expect(calls, 2);
  });

  test('a leftover .part is swept rather than adopted', () async {
    File('${dir.path}/abc.part').writeAsBytesSync(mp4().sublist(0, 8));
    final path = await get(serving(mp4()).client);

    expect(path, endsWith('.mp4'));
    expect(File('${dir.path}/abc.part').existsSync(), isFalse);
    expect(File(path).readAsBytesSync(), hasLength(mp4().length));
  });

  test('a warm directory is adopted on a cold start with no download', () async {
    final s = serving(mp4());
    final path = await get(s.client);

    cache.debugReset();
    cache.debugDir = dir;

    final again = await cache.resolve('abc', () async {
      fail('a warm file must not re-resolve its URL');
    }, client: s.client);
    expect(again, path);
    expect(s.calls(), 1);
  });

  test('evict deletes the file and forces a re-download', () async {
    final s = serving(mp4());
    final path = await get(s.client);
    await cache.evict('abc');
    expect(File(path).existsSync(), isFalse);

    await get(s.client);
    expect(s.calls(), 2);
  });

  test('clear removes the directory', () async {
    await get(serving(mp4()).client);
    await cache.clear();
    expect(dir.existsSync(), isFalse);
  });
}
