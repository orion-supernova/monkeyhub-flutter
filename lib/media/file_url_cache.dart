import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The backend has no URL for this storage id — a view-once file, or a blob
/// that has been swept.
///
/// Worth its own type because it is categorically different from a transport
/// failure: there is nothing to retry, and a widget that offers a retry button
/// for it is lying. See the `unavailable` branch in `AudioMessage`.
class FileUnavailable implements Exception {
  const FileUnavailable();
  @override
  String toString() => 'file unavailable';
}

/// Maps a Convex `_storage` id to its serving URL, in memory and across launches.
///
/// Three widgets used to keep their own private `static Map` of ids to URLs —
/// `RemoteImage`, `AudioMessage`, `VideoMessage` — each warm only
/// for the life of the process. That meant every cold start re-issued one
/// `files:getFileUrl` query *per distinct attachment* before a single byte could
/// be requested, which on the chat list is a few dozen round trips sitting
/// directly in front of the first frame.
///
/// Persisting is safe because the URLs are permanent. `ctx.storage.getUrl` on a
/// self-hosted deployment returns `<site>/api/storage/<uuid>` — no signature, no
/// expiry, no query string — verified stable across calls against the live
/// deployment. If that ever changes to a signed URL, [invalidate] is the escape
/// hatch and the disk cache below it is keyed on the URL, so a rotated URL would
/// simply miss and refetch rather than serve something wrong.
///
/// The store is deliberately tiny (a few dozen short strings), so it lives in
/// one JSON blob under a single `SharedPreferences` key rather than one key per
/// id — a bulk read at startup instead of N.
class FileUrlCache {
  FileUrlCache._();
  static final FileUrlCache instance = FileUrlCache._();

  static const _prefsKey = 'mh.fileUrls.v1';

  /// Above this, the oldest half is dropped on save. Storage ids are never
  /// reused, so without a bound this grows forever across a long-lived install.
  /// Insertion order in a Dart map is stable, so "oldest" is just "first".
  static const _maxEntries = 600;

  final Map<String, String> _urls = {};

  /// In-flight resolutions, so N widgets mounting the same avatar in one frame
  /// issue one query rather than N. Without this the chat list fires a
  /// duplicate query for every row sharing a sender.
  final Map<String, Future<String?>> _pending = {};

  bool _loaded = false;
  bool _dirty = false;
  Timer? _flush;

  /// Reads the persisted map. Call once from `main()` before the first frame so
  /// warm ids resolve synchronously and never render a placeholder.
  ///
  /// Failure is non-fatal by design: a corrupt or unreadable blob costs a round
  /// trip per image, not a broken launch.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((k, v) {
        if (k is! String || v is! String) return;
        // Builds before `getFileUrl` went nullable persisted the literal string
        // "null" for a file the backend declined to serve, which then poisoned
        // that id across restarts. Drop anything that isn't a URL on the way in
        // rather than bumping the prefs key — same result, without costing a
        // round trip per attachment on the next launch of every install that
        // was never poisoned.
        if (!v.startsWith('http')) return;
        _urls[k] = v;
      });
    } catch (e) {
      debugPrint('FileUrlCache.load failed (continuing cold): $e');
    }
  }

  /// The URL for [storageId] if it's already known, else null.
  ///
  /// Callers use this to render an image on the very first build with no
  /// placeholder frame — the difference between a cached avatar appearing
  /// instantly and shimmering for a round trip.
  String? peek(String storageId) => _urls[storageId];

  /// Resolves [storageId], calling [fetch] only on a miss. Null when the
  /// backend has no URL for it.
  ///
  /// Takes a fetcher rather than the API object so the cache has no opinion on
  /// where a URL comes from — and so this is testable without a backend.
  Future<String?> resolve(String storageId, Future<String?> Function() fetch) {
    final known = _urls[storageId];
    if (known != null) return Future.value(known);

    final inFlight = _pending[storageId];
    if (inFlight != null) return inFlight;

    final future = fetch().then((url) {
      // A null is an answer, not a URL, and caching one would pin this id to
      // "gone" for the life of the install. Leaving the miss uncached also
      // means an id that stops being view-once, or a blob that reappears,
      // heals on the next mount.
      if (url == null || url.isEmpty) return null;
      _urls[storageId] = url;
      _dirty = true;
      _scheduleSave();
      return url;
    }).whenComplete(() {
      // Braces, not an arrow. `Map.remove` returns the removed value — here a
      // `Future<String?>?`, and specifically *this* future — and `whenComplete`
      // waits on any Future its callback returns. An arrow body would make the
      // future await itself, so every cache miss would hang forever.
      _pending.remove(storageId);
    });

    _pending[storageId] = future;
    return future;
  }

  /// Records a URL the backend already resolved and handed over alongside
  /// [storageId] — a call invite carries the caller's avatar both ways — so
  /// the first [RemoteImage] for it starts downloading at once instead of
  /// spending a `getFileUrl` round trip of a ring that may last a second.
  void seed(String storageId, String url) {
    if (!url.startsWith('http') || _urls[storageId] == url) return;
    _urls[storageId] = url;
    _dirty = true;
    _scheduleSave();
  }

  /// Forgets [storageId] so the next [resolve] re-queries. For the case where a
  /// stored file was replaced under the same id, or a URL stopped working.
  void invalidate(String storageId) {
    if (_urls.remove(storageId) == null) return;
    _dirty = true;
    _scheduleSave();
  }

  /// Set false in tests so resolving doesn't reach for `SharedPreferences`,
  /// which needs a binding — and a binding installs a fake-async zone in which
  /// a plain awaited Future never completes.
  @visibleForTesting
  bool debugPersist = true;

  /// Coalesces the writes from a burst of resolutions into one. Opening a room
  /// full of photos resolves dozens of ids within a few frames; each one
  /// serializing the whole map would be pure jank on the platform channel.
  void _scheduleSave() {
    if (!debugPersist) return;
    _flush?.cancel();
    _flush = Timer(const Duration(seconds: 2), flush);
  }

  /// Writes the map out now. Safe to call at any time; a no-op when clean.
  Future<void> flush() async {
    _flush?.cancel();
    _flush = null;
    if (!_dirty) return;
    _dirty = false;
    try {
      if (_urls.length > _maxEntries) {
        // Drop the oldest half rather than trimming to exactly the cap, so this
        // runs once every few hundred inserts instead of on every one.
        final keep = _urls.entries.skip(_urls.length - _maxEntries ~/ 2).toList();
        _urls
          ..clear()
          ..addEntries(keep);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_urls));
    } catch (e) {
      // Losing the write costs a round trip next launch, nothing more.
      debugPrint('FileUrlCache.flush failed: $e');
    }
  }

  /// Drops everything, in memory and on disk. Used on sign-out — the URLs
  /// aren't secret, but a new account shouldn't inherit the old one's working
  /// set.
  Future<void> clear() async {
    _flush?.cancel();
    _flush = null;
    _urls.clear();
    _pending.clear();
    _dirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {/* nothing to recover */}
  }

  @visibleForTesting
  void debugSeed(Map<String, String> entries) {
    _loaded = true;
    _urls.addAll(entries);
  }

  @visibleForTesting
  void debugReset() {
    _flush?.cancel();
    _flush = null;
    _urls.clear();
    _pending.clear();
    _dirty = false;
    _loaded = false;
  }
}
