import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'diag_event.dart';

/// The in-memory ring plus its append-only mirror on disk.
///
/// Shaped after `lib/data/cache_store.dart` — same lazily-cached base
/// directory, same `Map<String, Timer>` write debounce, same `kIsWeb` guards,
/// same swallow-and-report error policy. Deviating from a storage pattern the
/// app already runs in production would be inventing risk for no reason.
class DiagBuffer {
  DiagBuffer._();
  static final DiagBuffer instance = DiagBuffer._();

  /// Events held in memory.
  ///
  /// 3000, where the reference implementation holds 500. That number was chosen
  /// for ordinary API traffic; the bug being chased emits tens of events per
  /// second, so 500 would be eight seconds of history and the interesting part
  /// would already have scrolled out of existence.
  static const int maxEvents = 3000;

  /// Hard ceiling on accumulated [DiagEvent.bytes]. A count cap alone is not a
  /// memory bound — one Convex page can be most of a megabyte, and thirty of
  /// them would sit comfortably under 3000 events while pinning the heap.
  static const int maxBytes = 2 * 1024 * 1024;

  /// Bodies are cut at write time, not render time. Truncating on the way out
  /// would mean the buffer had already paid to hold the whole thing.
  static const int maxBodyChars = 2048;

  static const Duration _writeDebounce = Duration(milliseconds: 600);

  /// Rotation threshold. Two files of this size is the whole on-disk footprint.
  static const int maxFileBytes = 4 * 1024 * 1024;

  final ListQueue<DiagEvent> _events = ListQueue<DiagEvent>();
  int _seq = 0;
  int _bytes = 0;
  int _dropped = 0;

  /// Bumped on every mutation so the viewer can rebuild off a cheap counter
  /// rather than listening to the list itself — a diagnostics screen that
  /// rebuilds 3000 rows per arriving event would be its own performance bug.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Stopwatch _uptime = Stopwatch()..start();

  Directory? _dir;
  final Map<String, Timer> _pendingWrites = {};
  int _flushedThroughSeq = 0;
  bool _rotating = false;

  /// Reported through the ORIGINAL debugPrint, never the overridden one — see
  /// `diag_log.dart`. Set by DiagLog at install time.
  void Function(String)? onInternalError;

  int get length => _events.length;
  int get dropped => _dropped;
  int get bytes => _bytes;
  int get uptimeMs => _uptime.elapsedMilliseconds;

  /// Newest last. Returned as a fixed list because the viewer indexes into it.
  List<DiagEvent> snapshot() => _events.toList(growable: false);

  /// Mints the next sequence number without recording anything. Used to
  /// correlate a request with the result that arrives later.
  int nextSeq() => ++_seq;

  DiagEvent add({
    required DiagCat cat,
    required DiagSev sev,
    required String event,
    String? name,
    String? corrId,
    int? durationMs,
    bool? ok,
    String? detail,
    String? body,
    String? screen,
    int? seq,
  }) {
    var truncated = false;
    var b = body;
    if (b != null && b.length > maxBodyChars) {
      final omitted = b.length - maxBodyChars;
      b = '${b.substring(0, maxBodyChars)}…[+$omitted chars truncated]';
      truncated = true;
    }

    final e = DiagEvent(
      seq: seq ?? ++_seq,
      tsMs: DateTime.now().millisecondsSinceEpoch,
      upMs: _uptime.elapsedMilliseconds,
      cat: cat,
      sev: sev,
      event: event,
      name: name,
      corrId: corrId,
      durationMs: durationMs,
      ok: ok,
      detail: detail,
      body: b,
      bodyTruncated: truncated,
      screen: screen,
    );

    _events.addLast(e);
    _bytes += e.bytes;

    // Both caps in one loop. ListQueue gives amortised O(1) at both ends; the
    // reference implementation rebuilt a 500-element list on every single
    // insert, which is the last thing you want while capturing a burst.
    while (_events.length > maxEvents || _bytes > maxBytes) {
      final gone = _events.removeFirst();
      _bytes -= gone.bytes;
      _dropped++;
    }

    revision.value++;

    // A warning or an error is often the last thing to happen before the
    // process dies, so it does not get to wait out the debounce.
    if (sev.index >= DiagSev.warn.index) {
      unawaited(flush());
    } else {
      _scheduleFlush();
    }
    return e;
  }

  void clear() {
    _events.clear();
    _bytes = 0;
    _dropped = 0;
    revision.value++;
  }

  // ───────── disk ─────────

  Future<Directory?> _ensureDir() async {
    if (kIsWeb) return null;
    final cached = _dir;
    if (cached != null) return cached;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/diagnostics');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      return dir;
    } catch (e) {
      onInternalError?.call('DiagBuffer._ensureDir: $e');
      return null;
    }
  }

  Future<File?> sessionFile() async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    return File('${dir.path}/session.ndjson');
  }

  Future<File?> previousFile() async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    return File('${dir.path}/previous.ndjson');
  }

  /// Called once at boot: last run's session becomes `previous`, so a crash
  /// leaves its evidence exactly one file away.
  Future<void> rollSessions() async {
    if (kIsWeb) return;
    try {
      final session = await sessionFile();
      final previous = await previousFile();
      if (session == null || previous == null) return;
      if (await session.exists()) {
        if (await previous.exists()) await previous.delete();
        await session.rename(previous.path);
      }
    } catch (e) {
      onInternalError?.call('DiagBuffer.rollSessions: $e');
    }
  }

  void _scheduleFlush() {
    if (kIsWeb) return;
    _pendingWrites['session']?.cancel();
    _pendingWrites['session'] = Timer(_writeDebounce, () {
      _pendingWrites.remove('session');
      unawaited(flush());
    });
  }

  /// Appends every event not yet written.
  ///
  /// `writeAsString(mode: append)` rather than a retained `IOSink`: a sink
  /// keeps a buffer in the process, and the process dying with that buffer
  /// unflushed loses precisely the tail that explains why it died.
  Future<void> flush() async {
    if (kIsWeb) return;
    _pendingWrites['session']?.cancel();
    _pendingWrites.remove('session');
    try {
      final file = await sessionFile();
      if (file == null) return;

      final pending = _events.where((e) => e.seq > _flushedThroughSeq).toList();
      if (pending.isEmpty) return;

      final sb = StringBuffer();
      for (final e in pending) {
        sb.write(e.toNdjsonLine());
      }
      await file.writeAsString(
        sb.toString(),
        mode: FileMode.append,
        flush: true,
      );
      _flushedThroughSeq = pending.last.seq;

      await _rotateIfNeeded(file);
    } catch (e) {
      onInternalError?.call('DiagBuffer.flush: $e');
    }
  }

  Future<void> _rotateIfNeeded(File session) async {
    if (_rotating) return;
    try {
      final len = await session.length();
      if (len < maxFileBytes) return;
      _rotating = true;
      final previous = await previousFile();
      if (previous == null) return;
      if (await previous.exists()) await previous.delete();
      await session.rename(previous.path);
      // Everything in memory belongs to the new file now.
      _flushedThroughSeq = 0;
    } catch (e) {
      onInternalError?.call('DiagBuffer._rotateIfNeeded: $e');
    } finally {
      _rotating = false;
    }
  }

  /// Reads a session file back. Never loaded at boot — only when the viewer or
  /// an export asks, so a 4 MiB file is not a startup cost.
  Future<List<DiagEvent>> readFile({required bool previous}) async {
    if (kIsWeb) return const [];
    try {
      final file = previous ? await previousFile() : await sessionFile();
      if (file == null || !await file.exists()) return const [];
      return DiagEvent.parseNdjson(await file.readAsString());
    } catch (e) {
      onInternalError?.call('DiagBuffer.readFile: $e');
      return const [];
    }
  }

  Future<void> deleteAll() async {
    if (kIsWeb) return;
    try {
      for (final f in [await sessionFile(), await previousFile()]) {
        if (f != null && await f.exists()) await f.delete();
      }
      _flushedThroughSeq = 0;
    } catch (e) {
      onInternalError?.call('DiagBuffer.deleteAll: $e');
    }
  }

  /// Test seam — resets everything the singleton holds.
  void resetForTest() {
    _events.clear();
    _seq = 0;
    _bytes = 0;
    _dropped = 0;
    _flushedThroughSeq = 0;
    for (final t in _pendingWrites.values) {
      t.cancel();
    }
    _pendingWrites.clear();
    revision.value = 0;
  }
}
