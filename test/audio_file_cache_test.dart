@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/media/audio_file_cache.dart';
import 'package:monkeyhub/media/file_url_cache.dart';

/// The byte half of the "audio failed" fix.
///
/// Voice notes were unplayable because Convex serves storage from an
/// extension-less URL under a content type (`audio/m4a`) that AVFoundation's
/// MIME→UTI table doesn't know, so iOS had no signal at all about the
/// container. This cache exists to hand the player a real file with a real
/// extension instead. The properties that matter: the extension comes from the
/// bytes rather than from anything the server said, a burst of widgets sharing
/// an id does one download, and a half-written file is never handed out.
void main() {
  final cache = AudioFileCache.instance;
  late Directory dir;

  /// A minimal MP4: `ftyp` at offset 4, which is the marker `_extensionFor`
  /// keys on. Same layout as what `package:record` produces.
  Uint8List m4a() => Uint8List.fromList([
        0, 0, 0, 24, // box size
        ...'ftyp'.codeUnits,
        ...'mp42'.codeUnits,
        0, 0, 0, 0,
      ]);

  Uint8List ogg() => Uint8List.fromList([
        ...'OggS'.codeUnits,
        ...List.filled(12, 0),
      ]);

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
    dir = Directory.systemTemp.createTempSync('mh_audio_test');
    cache.debugReset();
    cache.debugDir = dir;
  });

  tearDown(() {
    cache.debugReset();
    cache.debugDir = null;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('names the file from the container magic, not the served type', () async {
    final s = serving(m4a());
    final path = await cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: s.client);

    // `.m4a` is the whole point: it is the only thing telling iOS what this is,
    // because the URL it came from had no extension and the wrong MIME.
    expect(path, endsWith('.m4a'));
    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsBytesSync(), m4a());
  });

  test('an ogg body is named .ogg, so a future web upload is not relabelled',
      () async {
    final s = serving(ogg());
    final path = await cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: s.client);
    expect(path, endsWith('.ogg'));
  });

  test('concurrent resolves of one id share a single download', () async {
    // A room full of voice notes mounts every visible player in one frame, and
    // a note plus the reply preview quoting it share a storage id.
    final gate = Completer<void>();
    final s = serving(m4a(), gate: gate);
    final futures = List.generate(
      10,
      (_) => cache.resolve('abc', () async => 'https://example.test/api/storage/1',
          client: s.client),
    );
    gate.complete();
    final paths = await Future.wait(futures);

    expect(s.calls(), 1);
    expect(paths.toSet(), hasLength(1));
  });

  test('a resolved id is warm afterwards and does not re-download', () async {
    final s = serving(m4a());
    Future<String> get() => cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: s.client);

    final first = await get();
    final second = await get();
    expect(second, first);
    expect(s.calls(), 1);
  });

  test('a null URL surfaces as FileUnavailable, not a download', () async {
    final s = serving(m4a());
    await expectLater(
      cache.resolve('abc', () async => null, client: s.client),
      throwsA(isA<FileUnavailable>()),
    );
    expect(s.calls(), 0);
  });

  test('an id that is not a safe path segment is refused', () async {
    // The id becomes a path segment; a `../` would write outside the cache dir.
    await expectLater(
      cache.resolve('../evil', () async => 'https://example.test/api/storage/1'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a body too short to identify is rejected rather than written', () async {
    final s = serving(Uint8List.fromList([1, 2, 3]));
    await expectLater(
      cache.resolve('abc', () async => 'https://example.test/api/storage/1',
          client: s.client),
      throwsA(isA<FormatException>()),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('a failed download does not wedge the id', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('nope', 500);
    });
    Future<String> get() => cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: client);

    await expectLater(get(), throwsA(isA<HttpException>()));
    // The in-flight entry has to clear on failure too, or one dropped request
    // would pin that note to "tap to retry" for the rest of the session.
    await expectLater(get(), throwsA(isA<HttpException>()));
    expect(calls, 2);
  });

  test('evict deletes the file and forces a re-download', () async {
    final s = serving(m4a());
    Future<String> get() => cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: s.client);

    final path = await get();
    await cache.evict('abc');
    expect(File(path).existsSync(), isFalse);

    await get();
    expect(s.calls(), 2);
  });

  test('a leftover .part is swept rather than adopted', () async {
    // A download killed by app suspension leaves a truncated file that
    // setFilePath accepts and then fails on. Indexing must never pick one up.
    File('${dir.path}/abc.m4a.part').writeAsBytesSync(m4a().sublist(0, 8));
    final s = serving(m4a());
    final path = await cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: s.client);

    expect(path, endsWith('.m4a'));
    expect(path, isNot(endsWith('.part')));
    expect(File('${dir.path}/abc.m4a.part').existsSync(), isFalse);
    expect(File(path).readAsBytesSync(), hasLength(m4a().length));
  });

  test('a warm directory is adopted on a cold start with no download', () async {
    // The index is what makes the cache survive a restart without a hop in
    // main() — and what makes airplane-mode playback work.
    final s = serving(m4a());
    final path = await cache.resolve(
        'abc', () async => 'https://example.test/api/storage/1',
        client: s.client);

    cache.debugReset();
    cache.debugDir = dir;

    final again = await cache.resolve('abc', () async {
      fail('a warm file must not re-resolve its URL');
    }, client: s.client);
    expect(again, path);
    expect(s.calls(), 1);
  });

  test('clear removes the directory', () async {
    final s = serving(m4a());
    await cache.resolve('abc', () async => 'https://example.test/api/storage/1',
        client: s.client);
    await cache.clear();
    expect(dir.existsSync(), isFalse);
  });
}
