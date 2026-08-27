@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/brain_download.dart';
import 'package:monkeyhub/companions/brain_spec.dart';
import 'package:monkeyhub/companions/brain_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The download, against a real HTTP server.
///
/// ── Why a real socket and not a mocked client ──────────────────────────────
///
/// Every property worth testing here is a property of the HTTP conversation:
/// that a resume sends `Range` from the right offset, that it sends `If-Range`
/// so the SERVER gets to decide whether the partial is still good, that a 200
/// in reply to a range request means "throw your bytes away" rather than
/// "append these". A mock would be me asserting that my code sends what I
/// already believe it sends. A loopback server lets the test read the actual
/// request headers and answer like a CDN — including answering badly.
///
/// The failure this is really guarding against is not a download that breaks.
/// It is a download that SUCCEEDS onto the wrong bytes: a file of exactly the
/// right length, made of two halves that were never adjacent, which installs
/// cleanly and crashes an inference engine days later with nothing to point at.
void main() {
  late Directory tmp;
  late _FakeCdn cdn;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('brain_download_test');
    PathProviderPlatform.instance = _TmpPathProvider(tmp.path);
    // The store memoises its directory, so without this every case after the
    // first would write into the first case's (already deleted) temp dir.
    BrainStore.instance.resetForTest();
    cdn = await _FakeCdn.start();
  });

  tearDown(() async {
    await cdn.stop();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// A spec pointing at the loopback server, with the digest of whatever the
  /// server is actually serving — so "the happy path" really is verified end
  /// to end rather than against a hash the test invented.
  BrainSpec specFor(List<int> body, {String? sha, int? size}) => BrainSpec(
        id: 'test-brain',
        label: 'Test',
        fileName: 'test-brain.litertlm',
        url: cdn.url,
        sizeBytes: size ?? body.length,
        sha256: sha ?? sha256.convert(body).toString(),
        family: BrainFamily.qwen3,
        contextTokens: 2048,
        license: 'Apache 2.0',
      );

  /// One attempt, with the two moments a pause test needs to synchronise on.
  ///
  /// Waiting for `firstBytes` rather than for the server's stall is the whole
  /// point: the server having flushed and the client having WRITTEN are
  /// different events, and only the second one makes "how big is the partial?"
  /// a fair question.
  _Run run(BrainSpec spec) => _Run(BrainDownload(spec));

  Future<Object?> drain(Stream<DownloadProgress> s) async {
    try {
      await s.drain<void>();
      return null;
    } catch (e) {
      return e;
    }
  }

  group('a download that finishes', () {
    test('lands at the final path with the right bytes', () async {
      final body = _bytes(64 * 1024);
      final spec = specFor(body);
      cdn.body = body;

      final error = await drain(BrainDownload(spec).start());

      expect(error, isNull);
      final file = await BrainStore.instance.brainFile(spec);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), body);
    });

    /// The invariant everything else leans on: a partial never occupies the
    /// final path, so "that file exists at full length" is a trustworthy
    /// definition of installed. The `.part` and its note must both be gone.
    test('leaves no partial or resume note behind', () async {
      final body = _bytes(64 * 1024);
      final spec = specFor(body);
      cdn.body = body;

      await drain(BrainDownload(spec).start());

      expect(await (await BrainStore.instance.partFile(spec)).exists(), isFalse);
      expect(await (await BrainStore.instance.resumeFile(spec)).exists(), isFalse);
    });
  });

  group('pause and resume', () {
    test('keeps the bytes, then continues from exactly where it stopped',
        () async {
      final body = _bytes(256 * 1024);
      final spec = specFor(body);
      cdn.body = body;
      // Stall partway so there is something to pause.
      cdn.stallAfterBytes = 64 * 1024;

      final first = run(spec);
      await first.firstBytes;
      first.download.pause();
      await first.finished;
      final received = first.received;

      final part = await BrainStore.instance.partFile(spec);
      final kept = await part.length();
      expect(kept, greaterThan(0));
      expect(kept, lessThan(body.length));
      expect(received, kept,
          reason: 'progress must not claim bytes the file cannot back up');

      // Now let it finish.
      cdn.stallAfterBytes = null;
      cdn.requests.clear();
      final error = await drain(BrainDownload(spec).start());

      expect(error, isNull);
      // The second request asked to continue, not to start over.
      expect(cdn.requests.single.range, 'bytes=$kept-');
      final file = await BrainStore.instance.brainFile(spec);
      expect(await file.readAsBytes(), body,
          reason: 'the two halves must join into the original file');
    });

    /// `If-Range` is what lets the SERVER decide whether our partial is still
    /// valid, rather than us guessing from an ETag we half-understand.
    test('offers the stored validator on resume', () async {
      final body = _bytes(256 * 1024);
      final spec = specFor(body);
      cdn.body = body;
      cdn.etag = '"v1"';
      cdn.stallAfterBytes = 64 * 1024;

      final first = run(spec);
      await first.firstBytes;
      first.download.pause();
      await first.finished;

      cdn.stallAfterBytes = null;
      cdn.requests.clear();
      await drain(BrainDownload(spec).start());

      expect(cdn.requests.single.ifRange, '"v1"');
    });
  });

  group('the file changed under a partial', () {
    /// The case that produces a corrupt install if it is handled naively. The
    /// server answers a range request with 200 (whole body) because the ETag
    /// no longer matches — appending that to what we already have would give a
    /// file that is too long, or, on a same-length change, exactly the right
    /// length and completely wrong.
    test('a 200 in reply to a range request discards the partial', () async {
      final first = _bytes(256 * 1024, seed: 1);
      final spec = specFor(first);
      cdn.body = first;
      cdn.etag = '"v1"';
      cdn.stallAfterBytes = 64 * 1024;

      final attempt = run(spec);
      await attempt.firstBytes;
      attempt.download.pause();
      await attempt.finished;
      expect(await (await BrainStore.instance.partFile(spec)).length(),
          greaterThan(0));

      // Same length, different contents, new validator — the nastiest shape.
      final second = _bytes(256 * 1024, seed: 2);
      cdn.body = second;
      cdn.etag = '"v2"';
      cdn.refuseIfRange = true;
      cdn.stallAfterBytes = null;

      // The spec still expects the ORIGINAL digest, so this must fail rather
      // than silently install a different file.
      final error = await drain(BrainDownload(spec).start());
      expect(error, isA<DownloadException>());
      expect((error as DownloadException).failure, DownloadFailure.integrity);

      // And it must not have left the mixed file anywhere.
      expect(await (await BrainStore.instance.brainFile(spec)).exists(), isFalse);
      expect(await (await BrainStore.instance.partFile(spec)).exists(), isFalse);
    });

    /// The catalog is the authority on how big a brain is. A server offering a
    /// different total is not serving the file this build was written against,
    /// whatever it says about validators.
    test('a total length that disagrees with the catalog is refused', () async {
      final body = _bytes(128 * 1024);
      // Claim a size the server will not agree with.
      final spec = specFor(body, size: 999999, sha: sha256.convert(body).toString());
      cdn.body = body;

      final error = await drain(BrainDownload(spec).start());

      expect(error, isA<DownloadException>());
      expect((error as DownloadException).failure, DownloadFailure.integrity);
      expect(await (await BrainStore.instance.brainFile(spec)).exists(), isFalse);
    });
  });

  group('integrity', () {
    /// Right length, wrong contents. Length alone cannot catch this, which is
    /// the entire argument for paying for a digest pass over a 328 MB file.
    test('a digest mismatch is caught and the file is thrown away', () async {
      final body = _bytes(64 * 1024);
      final spec = specFor(body, sha: sha256.convert(_bytes(64 * 1024, seed: 9)).toString());
      cdn.body = body;

      final error = await drain(BrainDownload(spec).start());

      expect(error, isA<DownloadException>());
      expect((error as DownloadException).failure, DownloadFailure.integrity);
      expect(await (await BrainStore.instance.brainFile(spec)).exists(), isFalse,
          reason: 'a file that failed its digest must never reach the load path');
      expect(await (await BrainStore.instance.partFile(spec)).exists(), isFalse,
          reason: 'and must not be left behind to be resumed onto');
    });

    /// A partial with no note beside it cannot be validated, so it is not a
    /// partial — it is an unknown file of the right name.
    test('a partial with no resume note is discarded rather than continued',
        () async {
      final body = _bytes(128 * 1024);
      final spec = specFor(body);
      cdn.body = body;

      // Plant junk where the partial goes, with no note.
      final part = await BrainStore.instance.partFile(spec);
      await part.parent.create(recursive: true);
      await part.writeAsBytes(_bytes(32 * 1024, seed: 7));

      final error = await drain(BrainDownload(spec).start());

      expect(error, isNull);
      expect(cdn.requests.first.range, isNull,
          reason: 'an unvalidatable partial must start over, not resume');
      final file = await BrainStore.instance.brainFile(spec);
      expect(await file.readAsBytes(), body);
    });
  });

  group('cancel', () {
    test('deletes the partial and its note', () async {
      final body = _bytes(256 * 1024);
      final spec = specFor(body);
      cdn.body = body;
      cdn.stallAfterBytes = 64 * 1024;

      final attempt = run(spec);
      await attempt.firstBytes;
      attempt.download.cancel();
      await attempt.finished;

      expect(await (await BrainStore.instance.partFile(spec)).exists(), isFalse);
      expect(await (await BrainStore.instance.resumeFile(spec)).exists(), isFalse);
    });
  });
}

class _Run {
  _Run(this.download) {
    _sub = download.start().listen(
      (p) {
        received = p.received;
        if (p.received > 0 && !_first.isCompleted) _first.complete();
      },
      onError: (Object e) {
        error = e;
        if (!_first.isCompleted) _first.complete();
        if (!_done.isCompleted) _done.complete();
      },
      onDone: () {
        if (!_first.isCompleted) _first.complete();
        if (!_done.isCompleted) _done.complete();
      },
    );
  }

  final BrainDownload download;
  late final StreamSubscription<DownloadProgress> _sub;
  final Completer<void> _first = Completer<void>();
  final Completer<void> _done = Completer<void>();

  int received = 0;
  Object? error;

  /// Completes once at least one byte has been written.
  Future<void> get firstBytes => _first.future;

  /// Completes when the attempt has finished, however it finished.
  Future<void> get finished => _done.future;

  Future<void> dispose() => _sub.cancel();
}

List<int> _bytes(int n, {int seed = 0}) {
  final r = Random(seed);
  return List<int>.generate(n, (_) => r.nextInt(256));
}

/// One recorded request, reduced to the headers this feature depends on.
class _Request {
  _Request(this.range, this.ifRange);
  final String? range;
  final String? ifRange;
}

/// A loopback stand-in for the CDN, with the misbehaviours that matter.
class _FakeCdn {
  _FakeCdn(this._server);

  final HttpServer _server;
  List<int> body = const [];
  String etag = '"etag"';

  /// Stop writing after this many bytes and hold the connection open, so a
  /// test has a stable moment to pause or cancel in.
  int? stallAfterBytes;

  /// Answer a range request with 200 and the whole body — what a real server
  /// does when `If-Range` no longer matches.
  bool refuseIfRange = false;

  final List<_Request> requests = [];
  Completer<void> stalled = Completer<void>();

  String get url => 'http://127.0.0.1:${_server.port}/model.litertlm';

  static Future<_FakeCdn> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cdn = _FakeCdn(server);
    unawaited(cdn._serve());
    return cdn;
  }

  Future<void> _serve() async {
    // Each request handled off the accept loop. A stalled response holds its
    // connection open indefinitely — that is the point of it — and serving
    // sequentially would mean the RESUME request could never be accepted,
    // which looks exactly like the download hanging.
    await for (final req in _server) {
      unawaited(_handle(req));
    }
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      final ifRange = req.headers.value(HttpHeaders.ifRangeHeader);
      requests.add(_Request(range, ifRange));

      var start = 0;
      final wantsRange = range != null && !refuseIfRange;
      if (wantsRange) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      }

      final res = req.response;
      res.headers.set(HttpHeaders.etagHeader, etag);
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (wantsRange) {
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-${body.length - 1}/${body.length}');
      } else {
        res.statusCode = HttpStatus.ok;
      }

      final slice = body.sublist(start);
      final stall = stallAfterBytes;
      if (stall == null) {
        res.add(slice);
        await res.close();
        return;
      }

      // Write up to the stall point, announce it, and then simply stop —
      // leaving the response open so the client is genuinely mid-transfer.
      res.add(slice.take(stall).toList());
      await res.flush();
      if (!stalled.isCompleted) stalled.complete();
      // Held open deliberately; the client is torn down by pause/cancel.
    } catch (_) {
      // A client that hung up mid-write is the normal end of a stalled
      // response, not a test failure.
    }
  }

  Future<void> stop() async => _server.close(force: true);
}

/// path_provider has no implementation under `flutter test`, so [BrainStore]
/// would throw on its first path lookup.
class _TmpPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TmpPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}
