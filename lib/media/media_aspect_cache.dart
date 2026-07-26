import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the width÷height of a stored image, in memory and across launches.
///
/// An image message renders at the photo's own aspect ratio, but nothing in the
/// message document says what that ratio is for anything sent before
/// `mediaWidth`/`mediaHeight` existed. The ratio is only knowable once the
/// picture itself has decoded — which is *after* the bubble has already been
/// laid out at some guessed height.
///
/// So the guess gets recorded. The first time a legacy image decodes, its real
/// ratio lands here and the bubble settles once; every later build of that same
/// image — further up the list, next time the room opens, next launch — reads
/// the ratio synchronously from [peek] and lays out correctly on the very first
/// frame. Without the persistence the same backlog would re-settle on every cold
/// start, which is precisely the kind of reflow this whole change exists to
/// remove.
///
/// Shaped after [FileUrlCache]: one JSON blob under a single `SharedPreferences`
/// key rather than a key per id, because a bulk read at startup beats N reads,
/// and the whole store is a few hundred short doubles.
class MediaAspectCache {
  MediaAspectCache._();
  static final MediaAspectCache instance = MediaAspectCache._();

  static const _prefsKey = 'mh.mediaAspects.v1';

  /// Above this, the oldest half is dropped on save. Storage ids are never
  /// reused, so without a bound this grows forever across a long-lived install.
  /// Insertion order in a Dart map is stable, so "oldest" is just "first".
  static const _maxEntries = 600;

  /// Ratios outside this are refused. A corrupt header or a divide that landed
  /// on zero would otherwise persist a bubble height of zero or of ten
  /// thousand, and it would persist it *forever* — the cache is the thing later
  /// launches trust. The bounds are far wider than any clamp the UI applies, so
  /// they reject nonsense without editing legitimate panoramas.
  static const _minAspect = 0.02;
  static const _maxAspect = 50.0;

  final Map<String, double> _aspects = {};

  /// In-flight measurements, so the several rows that can share one storage id
  /// (a forwarded photo, a reply preview beside its original) measure once.
  final Map<String, Future<double?>> _pending = {};

  bool _loaded = false;
  bool _dirty = false;
  Timer? _flush;

  /// Reads the persisted map. Call once from `main()` before the first frame, so
  /// a known image lays out at its true height on its first build instead of
  /// settling into it.
  ///
  /// Failure is non-fatal by design: a corrupt or unreadable blob costs one
  /// reflow per image, not a broken launch.
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
        if (k is! String || v is! num) return;
        final aspect = v.toDouble();
        if (_valid(aspect)) _aspects[k] = aspect;
      });
    } catch (e) {
      debugPrint('MediaAspectCache.load failed (continuing cold): $e');
    }
  }

  static bool _valid(double aspect) =>
      aspect.isFinite && aspect >= _minAspect && aspect <= _maxAspect;

  /// The width÷height of [storageId] if it's already known, else null.
  ///
  /// Synchronous on purpose: this is read during layout, and the whole point is
  /// to have the answer before the first frame rather than one frame later.
  double? peek(String storageId) => _aspects[storageId];

  /// Records the ratio of [storageId], measured from a decode or handed over by
  /// the sender. Ignores a ratio that is already known and unchanged, so the
  /// common case of every visible row reporting the same number doesn't mark the
  /// store dirty once per row.
  void remember(String storageId, double aspect) {
    if (!_valid(aspect)) return;
    if (_aspects[storageId] == aspect) return;
    _aspects[storageId] = aspect;
    _dirty = true;
    _scheduleSave();
  }

  /// Resolves the ratio of [storageId], calling [measure] only on a miss.
  ///
  /// Takes a measurer rather than a file or a provider so the cache has no
  /// opinion on where a ratio comes from — and so this is testable without
  /// decoding anything.
  Future<double?> resolve(
    String storageId,
    Future<double?> Function() measure,
  ) {
    final known = _aspects[storageId];
    if (known != null) return Future.value(known);

    final inFlight = _pending[storageId];
    if (inFlight != null) return inFlight;

    final future = measure().then((aspect) {
      if (aspect == null || !_valid(aspect)) return null;
      remember(storageId, aspect);
      return aspect;
    }).whenComplete(() {
      // Braces, not an arrow: `Map.remove` returns *this* future, and
      // `whenComplete` awaits any Future its callback returns — an arrow body
      // would make the future await itself and hang every miss forever.
      _pending.remove(storageId);
    });

    _pending[storageId] = future;
    return future;
  }

  /// Set false in tests so remembering doesn't reach for `SharedPreferences`,
  /// which needs a binding — and a binding installs a fake-async zone in which a
  /// plain awaited Future never completes.
  @visibleForTesting
  bool debugPersist = true;

  /// Coalesces the writes from a burst of measurements into one. Opening a room
  /// full of legacy photos resolves dozens of ids within a few frames; each one
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
      if (_aspects.length > _maxEntries) {
        // Drop the oldest half rather than trimming to exactly the cap, so this
        // runs once every few hundred inserts instead of on every one.
        final keep =
            _aspects.entries.skip(_aspects.length - _maxEntries ~/ 2).toList();
        _aspects
          ..clear()
          ..addEntries(keep);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_aspects));
    } catch (e) {
      // Losing the write costs one reflow next launch, nothing more.
      debugPrint('MediaAspectCache.flush failed: $e');
    }
  }

  /// Drops everything, in memory and on disk. Used on sign-out — the ratios
  /// aren't secret, but a new account shouldn't inherit the old one's working
  /// set.
  Future<void> clear() async {
    _flush?.cancel();
    _flush = null;
    _aspects.clear();
    _pending.clear();
    _dirty = false;
    if (!debugPersist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('MediaAspectCache.clear failed: $e');
    }
  }
}
