/// A download you can stop and pick up again.
///
/// ── Why this exists instead of the plugin's downloader ─────────────────────
///
/// flutter_gemma has a capable downloader with its own resume machinery — and
/// it deliberately switches it off for us. `smart_downloader.dart`:
///
///     final allowPause = !_isHuggingFaceUrl(url);
///
/// Every brain in [BrainCatalog] is on HuggingFace, so with the plugin's
/// installer `allowPause` is false for all of them, `FileDownloader.pause`
/// refuses, and a stopped download starts again from zero. Upstream's reason
/// is weak ETags, which is a fair worry in general and turns out not to apply
/// here — see [_Resume] below.
///
/// So the bytes are ours to fetch, and the plugin is handed a finished file
/// through `ModelSource.file`. That is a narrow, documented seam rather than a
/// fork of anything.
///
/// ── What makes it robust rather than merely resumable ──────────────────────
///
/// Three independent guards, because a partial file that resumes onto the
/// wrong bytes is worse than one that restarts: it produces a plausible file
/// of exactly the right length that crashes an inference engine days later.
///
///  1. **`If-Range` against the stored ETag.** HuggingFace serves a STRONG
///     ETag (no `W/` prefix — measured, not assumed). Handing it back on
///     resume means the server itself decides whether our partial is still
///     valid: 206 to continue, 200 to say the file moved on. We never have to
///     guess.
///  2. **The total length must match the catalog.** `content-range` carries
///     `bytes a-b/TOTAL`, and [BrainSpec.sizeBytes] is a measured constant. A
///     disagreement means the remote file is not the one this build was
///     written against, whatever the ETag said.
///  3. **SHA-256 at the end.** [BrainSpec.sha256] is the file's git-lfs oid,
///     pinned at build time. This is the only check that can catch a resume
///     that was byte-shifted rather than byte-truncated, and it is the reason
///     a resumed install can be trusted as much as a fresh one.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'brain_spec.dart';
import 'brain_store.dart';

/// Where a download has got to. Every field is bytes, never a percentage —
/// see [BrainInstallProgress].
@immutable
class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  double get fraction =>
      total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
}

/// Why a download stopped without finishing.
enum DownloadFailure {
  network,
  storage,

  /// The finished file is not the file this build expects — a length or a
  /// digest that disagrees with [BrainSpec]. Distinguished from [network]
  /// because retrying an identical request will produce an identical answer;
  /// what has to happen is a clean restart, which [BrainDownload] does
  /// automatically by discarding the partial first.
  integrity,

  unknown,
}

/// Thrown when the caller cancelled. Carries no data; the caller asked.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => 'DownloadCancelled';
}

/// Thrown when the caller paused. Distinct from [DownloadCancelled] in exactly
/// one way that matters: the partial file is still on disk afterwards.
class DownloadPaused implements Exception {
  const DownloadPaused();
  @override
  String toString() => 'DownloadPaused';
}

class DownloadException implements Exception {
  const DownloadException(this.failure, [this.detail]);
  final DownloadFailure failure;
  final String? detail;
  @override
  String toString() => 'DownloadException($failure${detail == null ? '' : ': $detail'})';
}

/// One brain's download, start to finish, across as many sessions as it takes.
///
/// Not a singleton and not long-lived: [BrainManager] makes one per attempt.
/// Everything that must survive an attempt — the partial bytes, the ETag —
/// lives on disk, which is what lets a download resume after the app was
/// killed rather than merely after a pause.
class BrainDownload {
  BrainDownload(this.spec);

  final BrainSpec spec;

  /// How long to wait for the response headers. The BODY is deliberately not
  /// on a deadline — it is hundreds of megabytes and a slow connection is not
  /// an error — but a server that never answers at all is.
  static const Duration _headerTimeout = Duration(seconds: 30);

  HttpClient? _client;
  IOSink? _sink;
  StreamSubscription<List<int>>? _sub;

  /// Completed when the body stream is finished with, one way or another.
  ///
  /// A field rather than a local, and that is load-bearing: [_stop] has to be
  /// able to complete it. Cancelling a [StreamSubscription] fires NEITHER
  /// `onDone` NOR `onError` — by design, since the consumer asked to stop
  /// listening — so a run loop awaiting only those two callbacks waits
  /// forever. The visible symptom is a Pause button that greys out and never
  /// comes back, with the sink still open behind it.
  Completer<void>? _done;

  bool _pauseRequested = false;
  bool _cancelRequested = false;

  /// Asks the download to stop and KEEP what it has.
  ///
  /// Returns immediately; the run loop flushes and closes the sink, then
  /// [start]'s stream ends with [DownloadPaused]. Flushing is the part that
  /// matters — a paused download whose last buffer never reached the disk
  /// would resume from a byte count the file cannot back up.
  void pause() {
    _pauseRequested = true;
    _stop();
  }

  /// Asks the download to stop and THROW AWAY what it has.
  void cancel() {
    _cancelRequested = true;
    _stop();
  }

  /// Ends the body stream and releases whatever is waiting on it.
  void _stop() {
    _sub?.cancel();
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// Runs (or continues) the download, emitting progress as bytes land.
  ///
  /// Safe to call on a spec whose partial file already exists — that IS the
  /// resume path, and it is the same code as the first attempt with a
  /// non-zero starting offset.
  Stream<DownloadProgress> start() {
    final controller = StreamController<DownloadProgress>();
    controller.onCancel = () {
      // The consumer walked away — treat it as a pause rather than a cancel.
      // Losing 900 MB because a widget was disposed would be an unforgivable
      // way to lose 900 MB.
      if (!_cancelRequested) pause();
    };
    unawaited(_run(controller));
    return controller.stream;
  }

  Future<void> _run(StreamController<DownloadProgress> out) async {
    final part = await BrainStore.instance.partFile(spec);
    final target = await BrainStore.instance.brainFile(spec);
    try {
      await part.parent.create(recursive: true);

      var received = await part.exists() ? await part.length() : 0;
      var resume = await _Resume.load(spec);

      // A partial with no note beside it cannot be validated on resume, so it
      // is not a partial — it is an unknown file of the right name. Discarded
      // rather than trusted, which costs a restart and buys the invariant that
      // every byte we keep was checked.
      if (received > 0 && resume == null) {
        await _discard(part);
        received = 0;
      }
      // Longer than the file is supposed to be: a previous run wrote past the
      // end, or the catalog changed under an old partial.
      if (received > spec.sizeBytes) {
        await _discard(part);
        received = 0;
        resume = null;
      }
      // Already complete but never promoted — the app died between the last
      // byte and the rename. Skip straight to verification.
      if (received == spec.sizeBytes) {
        await _finish(part, target, out);
        return;
      }

      final client = _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20)
        // The body is not on a deadline; see [_headerTimeout].
        ..idleTimeout = const Duration(seconds: 30);

      final request = await client
          .getUrl(Uri.parse(spec.url))
          .timeout(_headerTimeout);
      if (received > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
        final tag = resume?.etag;
        if (tag != null) {
          // The server decides whether our partial is still valid. 206 keeps
          // it; 200 quietly means "start over", which is handled below.
          request.headers.set(HttpHeaders.ifRangeHeader, tag);
        }
      }

      final response = await request.close().timeout(_headerTimeout);
      final status = response.statusCode;

      if (status == HttpStatus.ok) {
        // Either a fresh download, or a resume the server refused. Both mean
        // the bytes now arriving are the WHOLE file, so anything already on
        // disk has to go — appending here is what produces a file of the right
        // length made of the wrong bytes.
        if (received > 0) {
          await _discard(part);
          received = 0;
        }
      } else if (status == HttpStatus.partialContent) {
        final ok = _checkContentRange(response, received);
        if (ok != null) {
          await response.drain<void>();
          await _discard(part);
          throw DownloadException(DownloadFailure.integrity, ok);
        }
      } else {
        await response.drain<void>();
        throw DownloadException(
          status >= 500 ? DownloadFailure.network : DownloadFailure.unknown,
          'HTTP $status',
        );
      }

      // Recorded BEFORE any body byte is written, so a kill mid-stream leaves
      // a partial that can still be validated on the next attempt.
      await _Resume(
        etag: response.headers.value(HttpHeaders.etagHeader),
        totalBytes: spec.sizeBytes,
        url: spec.url,
      ).save(spec);

      final sink = _sink = part.openWrite(mode: FileMode.append);
      final done = _done = Completer<void>();
      var written = received;

      _sub = response.listen(
        (chunk) {
          sink.add(chunk);
          written += chunk.length;
          if (!out.isClosed) {
            out.add(DownloadProgress(received: written, total: spec.sizeBytes));
          }
        },
        onError: (Object e, StackTrace st) {
          if (!done.isCompleted) done.completeError(e, st);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );

      try {
        await done.future;
      } finally {
        // Always, on every path out — pause, cancel, error or completion. An
        // unflushed sink is the one way a resume can be handed a byte count
        // the file does not actually contain.
        //
        // Note this runs on the PAUSE path too, where the subscription was
        // cancelled and the writes already queued still have to reach the
        // disk before anyone reads the file's length.
        await sink.flush();
        await sink.close();
        _sink = null;
        _done = null;
      }

      if (_cancelRequested) {
        await _discard(part);
        throw const DownloadCancelled();
      }
      if (_pauseRequested) throw const DownloadPaused();

      await _finish(part, target, out);
    } on DownloadCancelled {
      out.addError(const DownloadCancelled());
    } on DownloadPaused {
      out.addError(const DownloadPaused());
    } on DownloadException catch (e) {
      out.addError(e);
    } catch (e) {
      // A cancel or pause races the socket, so a stream error can arrive
      // AFTER the flag is set. The flag is the truth about intent.
      if (_cancelRequested) {
        await _discard(part);
        out.addError(const DownloadCancelled());
      } else if (_pauseRequested) {
        out.addError(const DownloadPaused());
      } else {
        out.addError(DownloadException(_classify(e), e.toString()));
      }
    } finally {
      _client?.close(force: true);
      _client = null;
      await out.close();
    }
  }

  /// Checks the server's `content-range` against what we asked for and what
  /// the catalog says. Returns null when it agrees, or a reason when it does
  /// not.
  String? _checkContentRange(HttpClientResponse response, int expectedStart) {
    final raw = response.headers.value(HttpHeaders.contentRangeHeader);
    if (raw == null) return 'no content-range on a 206';
    // bytes <start>-<end>/<total>
    final m = RegExp(r'bytes\s+(\d+)-(\d+)/(\d+)').firstMatch(raw);
    if (m == null) return 'unparsable content-range: $raw';
    final start = int.parse(m.group(1)!);
    final total = int.parse(m.group(3)!);
    if (start != expectedStart) {
      return 'resumed at $start, expected $expectedStart';
    }
    if (total != spec.sizeBytes) {
      // The remote file is not the one this build was written against. Not a
      // transport problem, so retrying the same request cannot help — the
      // partial is discarded by the caller and the next attempt starts clean.
      return 'remote length $total, catalog says ${spec.sizeBytes}';
    }
    return null;
  }

  /// Length, digest, then promote.
  ///
  /// The rename is the last thing that happens and it is atomic, which is what
  /// makes "the file exists at its final path" a trustworthy definition of
  /// "installed". Nothing else in the subsystem has to know about partials.
  Future<void> _finish(
    File part,
    File target,
    StreamController<DownloadProgress> out,
  ) async {
    final length = await part.length();
    if (length != spec.sizeBytes) {
      await _discard(part);
      throw DownloadException(
        DownloadFailure.integrity,
        'finished at $length, expected ${spec.sizeBytes}',
      );
    }

    final digest = await _sha256Of(part);
    if (digest != spec.sha256) {
      // The only check that catches a resume which was byte-SHIFTED rather
      // than truncated: right length, wrong contents. Costly (one full read)
      // and worth it — the alternative is handing corrupt weights to an
      // inference engine and reading the crash weeks later.
      await _discard(part);
      throw DownloadException(
        DownloadFailure.integrity,
        'digest $digest, expected ${spec.sha256}',
      );
    }

    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    await BrainStore.instance.clearResume(spec);
    if (!out.isClosed) {
      out.add(
        DownloadProgress(received: spec.sizeBytes, total: spec.sizeBytes),
      );
    }
  }

  /// Streams the file through SHA-256 without holding it in memory.
  ///
  /// `Hash.bind` rather than a read-then-hash: a 2.6 GB `readAsBytes` is an
  /// out-of-memory kill on most phones. Being a stream it also yields between
  /// chunks, so the progress UI keeps painting through the several seconds a
  /// digest of that size takes.
  Future<String> _sha256Of(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> _discard(File part) async {
    try {
      if (await part.exists()) await part.delete();
    } catch (_) {}
    await BrainStore.instance.clearResume(spec);
  }

  DownloadFailure _classify(Object error) {
    if (error is SocketException || error is HttpException || error is TimeoutException) {
      return DownloadFailure.network;
    }
    final s = error.toString().toLowerCase();
    if (s.contains('no space') || s.contains('enospc') || s.contains('disk')) {
      return DownloadFailure.storage;
    }
    if (s.contains('socket') ||
        s.contains('connection') ||
        s.contains('timed out') ||
        s.contains('host')) {
      return DownloadFailure.network;
    }
    return DownloadFailure.unknown;
  }
}

/// The note beside a partial file: what the server said about it last time.
///
/// Small enough to be a sibling JSON file rather than a database. It has to
/// survive the process dying, which rules out memory, and it has to be deleted
/// with the partial, which rules out settings.
@immutable
class _Resume {
  const _Resume({
    required this.etag,
    required this.totalBytes,
    required this.url,
  });

  /// What the server called this file when we started.
  ///
  /// Handed back as `If-Range`, which is the whole reason it is stored.
  /// HuggingFace's is STRONG — measured, not assumed: `If-Range` is only
  /// honoured for strong validators, and against a weak one the server would
  /// silently restart the transfer. That restart is handled (a 200 discards
  /// the partial) so a weak ETag degrades to "no resume" rather than to
  /// corruption.
  final String? etag;

  /// What the file was supposed to be when this partial was started. Compared
  /// against the catalog so an app update that changes a brain invalidates any
  /// partial left behind by the old one.
  final int totalBytes;

  final String url;

  Future<void> save(BrainSpec spec) async {
    try {
      final f = await BrainStore.instance.resumeFile(spec);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode({'etag': etag, 'total': totalBytes, 'url': url}),
      );
    } catch (e) {
      // A partial with no note is discarded on the next attempt rather than
      // trusted, so failing to write one costs a restart and nothing else.
      debugPrint('BrainDownload: could not record resume state: $e');
    }
  }

  static Future<_Resume?> load(BrainSpec spec) async {
    try {
      final f = await BrainStore.instance.resumeFile(spec);
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return null;
      final total = raw['total'];
      final url = raw['url'];
      if (total is! int || url is! String) return null;
      // A brain whose URL or expected size moved between app versions leaves a
      // partial that can never be completed. Refusing it here is what turns
      // that into one wasted restart instead of a download that fails at the
      // digest every time.
      if (total != spec.sizeBytes || url != spec.url) return null;
      final etag = raw['etag'];
      return _Resume(
        etag: etag is String ? etag : null,
        totalBytes: total,
        url: url,
      );
    } catch (_) {
      return null;
    }
  }
}
