/// Translations that have already been paid for.
///
/// ── Why this is on disk and not just in memory ─────────────────────────────
///
/// A translation costs about a second of a phone's full attention. Scrolling
/// a translated room back up past something already translated, backgrounding
/// the app and returning, or reopening the room tomorrow must not spend that
/// second again — and without a cache each of those does, because the message
/// list is rebuilt from the repository every time.
///
/// The cache is keyed by the CONTENT, not the message id. That looks like a
/// detail and is not:
///
///  * An edited message is different content, so it re-translates. Keyed by id
///    it would show the old translation under the new text — silently, and
///    forever.
///  * "good morning" said by nine people in a group room is one translation,
///    not nine.
///  * A forwarded message arrives already translated.
///  * It survives the message id changing out from under an optimistic bubble
///    (`tmp_…` → server id), which happens on every message you send.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TranslationCache {
  TranslationCache._();
  static final TranslationCache instance = TranslationCache._();

  /// Entries kept. At roughly 120 bytes of key plus the translated text, two
  /// thousand entries is well under a megabyte on disk — small next to the
  /// 328 MB that made them possible — and covers far more than anyone scrolls
  /// through in a session.
  static const int _maxEntries = 2000;

  /// How long a translation may outlive the message it came from.
  ///
  /// `Sebastian.forgetMissing` evicts a translation the moment its message
  /// leaves the room, which covers deletion, expiry and edits — while the app
  /// is running. It cannot cover one case, and the gap is structural rather
  /// than an oversight: a message deleted while the app was CLOSED is simply
  /// absent when the room next loads, and a cache keyed by content hash has no
  /// way to tell "this was deleted" from "this is older than the page that
  /// loaded". Reconciling would need the full history, which is the one thing
  /// a paginated transcript does not have.
  ///
  /// So the residue is bounded by time instead of by knowledge. Thirty days
  /// turns "indefinitely, in one narrow case" into a definite answer, and the
  /// cost of being wrong is one re-run of a model already on the device.
  static const Duration _maxAge = Duration(days: 30);

  /// What produced the entries in the file.
  ///
  /// Bumped whenever the pipeline that turns a model's output into bubble text
  /// changes in a way that would have produced a different answer — a new
  /// sanitiser rule, a new prompt, a different brain. Everything stamped with
  /// an older number is dropped on load.
  ///
  /// This is not a schema version, though it doubles as one. It is a claim
  /// about QUALITY: the cache cannot tell a bad translation from a good one,
  /// so when the code that makes them gets better, the only honest thing to do
  /// with the old ones is forget them. A user who has already translated a
  /// message must not be the only user who never sees the fix.
  ///
  /// ── History ────────────────────────────────────────────────────────────
  /// 1 — first release.
  /// 2 — strips chat-template control tokens (`<|endoftext|>` and friends),
  ///     which were reaching bubbles as text on the iOS `.litertlm` path.
  /// 3 — rejects token soup, after a GPU backend the simulator cannot service
  ///     returned random tokens across four writing systems.
  static const int _version = 3;

  static const Duration _writeDebounce = Duration(seconds: 2);

  /// Insertion-ordered, which is what makes the eviction below an LRU rather
  /// than an arbitrary cull: [get] re-inserts on hit, so the front of the map
  /// is genuinely the coldest end.
  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap();

  Timer? _write;
  bool _loaded = false;
  Future<void>? _loading;

  /// Reads the cache off disk. Idempotent, memoised while in flight, and
  /// harmless to call from several widgets in the same frame.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= () async {
      try {
        final f = await _file();
        if (await f.exists()) {
          final raw = jsonDecode(await f.readAsString());
          if (raw is Map && raw['v'] == _version) {
            final entries = raw['e'];
            final cutoff = DateTime.now().subtract(_maxAge).millisecondsSinceEpoch;
            for (final e in (entries is Map ? entries : const {}).entries) {
              final v = e.value;
              // Anything that is not the current shape is dropped rather than
              // migrated — including the older `key: "translation"` form. A
              // cache whose entire contents can be recomputed has no reason to
              // carry a migration path, and a translation with no timestamp
              // cannot be aged out, which is the whole point of the field.
              if (v is! Map) continue;
              // ignore: avoid_dynamic_calls
              final at = v['t'];
              final text = v['v'];
              if (at is! int || text is! String) continue;
              if (at < cutoff) continue;
              _entries[e.key.toString()] = _Entry(text, at);
            }
          }
        }
      } catch (e) {
        // A corrupt cache is not worth an error path: the whole point of it is
        // that everything in it can be recomputed. Same for a file written by
        // an older [_version] — it is simply not read, and the first
        // translation of each message fills it back in with the current
        // pipeline's answer.
        debugPrint('TranslationCache load failed: $e');
      } finally {
        _loaded = true;
        _loading = null;
      }
    }();
  }

  /// The translation of [content] into [languageCode], or null.
  ///
  /// Promotes the hit to the warm end, which is the half of the LRU that is
  /// easy to forget and turns eviction from useful into random.
  String? get(String content, String languageCode) {
    final key = _key(content, languageCode);
    final hit = _entries.remove(key);
    if (hit == null) return null;
    // Re-inserted at its ORIGINAL timestamp, not refreshed. [_maxAge] bounds
    // how long a translation may outlive its message, and a bound that resets
    // every time the entry is read would not bound anything — a message
    // deleted from a room you keep scrolling through is exactly the case it
    // exists for.
    _entries[key] = hit;
    return hit.text;
  }

  bool has(String content, String languageCode) =>
      _entries.containsKey(_key(content, languageCode));

  /// Whether the disk read has happened yet.
  ///
  /// Exposed so a caller can take the synchronous path when it is safe to —
  /// see `Sebastian.settleWithoutModel`. After the first [ensureLoaded] the
  /// whole cache is an in-memory map, and making every reader await a future
  /// that has already completed costs a microtask per message and, worse,
  /// pushes an instant answer past the frame it should have landed in.
  bool get isLoaded => _loaded;

  void put(String content, String languageCode, String translation) {
    final key = _key(content, languageCode);
    _entries.remove(key);
    _entries[key] =
        _Entry(translation, DateTime.now().millisecondsSinceEpoch);
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _scheduleWrite();
  }

  /// Forgets one translation.
  ///
  /// Called when the message it belongs to leaves the conversation — deleted,
  /// expired, or edited into different text. See `Sebastian.forgetMissing`,
  /// which is what decides that; this end just does as it is told.
  void remove(String content, String languageCode) {
    if (_entries.remove(_key(content, languageCode)) != null) {
      _scheduleWrite();
    }
  }

  int get count => _entries.length;

  /// Drops everything, on disk and in memory.
  ///
  /// Offered in Settings next to Sebastian's storage line, and — more
  /// importantly — run automatically when the target language changes. A cache
  /// keyed by language does not strictly need that, but the entries for the
  /// old language are dead weight the moment nobody is reading it.
  Future<void> clear() async {
    _entries.clear();
    _write?.cancel();
    _write = null;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('TranslationCache clear failed: $e');
    }
  }

  /// Content hash, not content.
  ///
  /// MD5 rather than a stronger digest on purpose: this is a cache key, not a
  /// security boundary, and the cost is paid on every cache lookup — which
  /// means once per message per frame in the worst case. A collision would
  /// show one message's translation under another's; at 128 bits, across two
  /// thousand entries, that is not a risk anybody will encounter.
  ///
  /// Hashing rather than storing the text also means the file on disk is not a
  /// plaintext copy of everyone's messages sitting next to the app's cache.
  /// The translations are still there in the clear — they have to be, they are
  /// what gets rendered — but the originals are not duplicated out of the
  /// message store.
  String _key(String content, String languageCode) {
    final digest = md5.convert(utf8.encode(content.trim()));
    return '$digest:$languageCode';
  }

  void _scheduleWrite() {
    _write?.cancel();
    _write = Timer(_writeDebounce, () async {
      try {
        final f = await _file();
        await f.parent.create(recursive: true);
        await f.writeAsString(jsonEncode({
          'v': _version,
          'e': {
            for (final e in _entries.entries) e.key: e.value.toJson(),
          },
        }));
      } catch (e) {
        debugPrint('TranslationCache write failed: $e');
      }
    });
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/companions/translations.json');
  }
}

/// One cached translation and when it was made.
class _Entry {
  const _Entry(this.text, this.savedAtMs);

  final String text;

  /// Epoch milliseconds. Set once at [TranslationCache.put] and never
  /// refreshed — see [TranslationCache.get].
  final int savedAtMs;

  Map<String, Object> toJson() => {'t': savedAtMs, 'v': text};
}
