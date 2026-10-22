import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../backend/convex_client.dart';
import '../backend/profile_api.dart';

/// What the viewer may know of one person: the live profile, not the copy that
/// was stamped into a message or a moment when it was sent.
@immutable
class ProfileInfo {
  const ProfileInfo({
    required this.id,
    this.name = '',
    this.username = '',
    this.avatarStorageId,
    this.deleted = false,
    this.isSystem = false,
    this.updatedAt = 0,
  });

  final String id;
  final String name;
  final String username;

  /// The avatar blob as this viewer may see it; null when there is none.
  final String? avatarStorageId;

  /// Tombstone: the account is gone. Show "Deleted account", not [name].
  final bool deleted;
  final bool isSystem;

  /// The server's version stamp; compared with `profiles:versions`' `u`.
  final int updatedAt;

  bool get hasAvatar => avatarStorageId != null;

  static ProfileInfo? fromServer(Map<String, dynamic> j, {String? id}) {
    final rid = j['id'] ?? id;
    if (rid is! String || rid.isEmpty) return null;
    final u = j['updatedAt'];
    final a = j['avatarStorageId'];
    return ProfileInfo(
      id: rid,
      name: j['name'] is String ? j['name'] as String : '',
      username: j['username'] is String ? j['username'] as String : '',
      avatarStorageId: a is String && a.isNotEmpty ? a : null,
      deleted: j['deleted'] == true,
      isSystem: j['isSystem'] == true,
      updatedAt: u is num ? u.toInt() : 0,
    );
  }

  /// Disk form: `{n, un, a, u, d}` (+ `s` for system accounts).
  Map<String, dynamic> toDisk() => {
    'n': name,
    'un': username,
    if (avatarStorageId != null) 'a': avatarStorageId,
    'u': updatedAt,
    if (deleted) 'd': true,
    if (isSystem) 's': true,
  };

  static ProfileInfo? fromDisk(String id, Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final u = j['u'];
    return ProfileInfo(
      id: id,
      name: j['n'] is String ? j['n'] as String : '',
      username: j['un'] is String ? j['un'] as String : '',
      avatarStorageId: j['a'] is String ? j['a'] as String : null,
      deleted: j['d'] == true,
      isSystem: j['s'] == true,
      updatedAt: u is num ? u.toInt() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileInfo &&
      other.id == id &&
      other.name == name &&
      other.username == username &&
      other.avatarStorageId == avatarStorageId &&
      other.deleted == deleted &&
      other.isSystem == isSystem &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    username,
    avatarStorageId,
    deleted,
    isSystem,
    updatedAt,
  );
}

/// Binds `profiles:get`. Injected for tests.
typedef ProfileFetch =
    Future<List<Map<String, dynamic>?>> Function(List<String> ids);

/// Binds `profiles:versions`; returns the canceller. Injected for tests.
typedef ProfileSubscribe =
    Future<void Function()> Function(
      List<String> ids,
      void Function(dynamic) onData,
      void Function(Object error) onError,
    );

/// Where the per-user cache folder lives. Injected for tests.
typedef ProfileDirProvider = Future<Directory> Function();

/// Names and avatars by user id, so a message stores WHO sent it and the app
/// looks up what they are called now.
///
/// * **Disk:** `<documents>/cache/<userId>/profiles.json`, one file per signed
///   in user (avatars are viewer-dependent), schema-versioned, written 600 ms
///   after the last change, LRU-capped at [maxEntries]. Web keeps memory only.
///   Load it with [attach].
/// * **Fetch:** unknown ids are batched by a [coalesceDelay] coalescer into
///   `profiles:get` in chunks of 100. An id already in flight is not asked for
///   again, and an id the server answered null for is not asked for again for
///   [negativeTtl].
/// * **Freshness:** the ids touched in the last [activeWindow] (at most
///   [maxActive], newest first) are subscribed to `profiles:versions`, with the
///   [PresenceStore] debounce and key dedupe. A changed `u` or `av` refetches
///   just that id.
/// * **Legacy mode:** on "function not found" nothing is fetched or subscribed
///   and every lookup returns the caller's fallback.
///
/// Reads never block and never throw: a miss returns the fallback and queues a
/// fetch, and listeners hear about the answer once per batch.
class ProfileCache extends ChangeNotifier {
  ProfileCache._({
    ProfileFetch? fetch,
    ProfileSubscribe? subscribe,
    ProfileDirProvider? dir,
    bool? memoryOnly,
  }) : _fetch = fetch ?? _backendFetch,
       _subscribe = subscribe ?? _backendSubscribe,
       _dir = dir ?? getApplicationDocumentsDirectory,
       _memoryOnly = memoryOnly ?? kIsWeb;

  static final ProfileCache instance = ProfileCache._();

  /// A private cache with injected backend and folder, for tests.
  @visibleForTesting
  factory ProfileCache.forTest({
    required ProfileFetch fetch,
    required ProfileSubscribe subscribe,
    ProfileDirProvider? dir,
  }) => ProfileCache._(
    fetch: fetch,
    subscribe: subscribe,
    dir: dir,
    memoryOnly: dir == null,
  );

  static const int schemaVersion = 1;
  static const int maxEntries = 2000;
  static const int maxActive = ProfileApi.maxIds;

  @visibleForTesting
  static Duration coalesceDelay = const Duration(milliseconds: 50);
  @visibleForTesting
  static Duration writeDebounce = const Duration(milliseconds: 600);
  @visibleForTesting
  static Duration negativeTtl = const Duration(seconds: 60);
  @visibleForTesting
  static Duration activeWindow = const Duration(seconds: 60);
  @visibleForTesting
  static Duration subscribeDelay = const Duration(seconds: 1);
  @visibleForTesting
  static Duration pruneEvery = const Duration(seconds: 15);

  /// The clock behind the negative cache and the active window.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  static Future<List<Map<String, dynamic>?>> _backendFetch(List<String> ids) =>
      ProfileApi(ConvexBackend.instance).get(ids);

  static Future<void Function()> _backendSubscribe(
    List<String> ids,
    void Function(dynamic) onData,
    void Function(Object error) onError,
  ) async {
    final sub = await ConvexBackend.instance.subscribe(
      ProfileApi.versionsName,
      {'ids': ids},
      onData: onData,
      onError: onError,
    );
    return sub.cancel;
  }

  final ProfileFetch _fetch;
  final ProfileSubscribe _subscribe;
  final ProfileDirProvider _dir;
  final bool _memoryOnly;

  /// Insertion order is recency: the first key is the next to evict.
  final LinkedHashMap<String, ProfileInfo> _entries =
      LinkedHashMap<String, ProfileInfo>();

  String? _userId;
  bool _legacy = false;

  /// Bumped by [clear]; late callbacks from a previous user are ignored.
  int _epoch = 0;

  // Fetching.
  final Set<String> _queued = {};
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _negative = {};
  Timer? _coalesceTimer;

  // Freshness.
  final LinkedHashMap<String, DateTime> _touched =
      LinkedHashMap<String, DateTime>();
  Set<String> _subscribed = {};
  String? _key;
  void Function()? _cancelSub;
  int _subGen = 0;
  Timer? _subTimer;
  Timer? _pruneTimer;
  DateTime? _lastSubAt;

  /// `u|av` last acted on per id, so a re-delivered version isn't re-fetched.
  final Map<String, String> _handled = {};

  // Disk.
  Timer? _writeTimer;
  bool _dirty = false;
  bool _notifyQueued = false;
  bool _disposed = false;

  /// True once the server answered "function not found".
  bool get legacy => _legacy;

  int get length => _entries.length;

  @visibleForTesting
  Set<String> get subscribedIds => Set.unmodifiable(_subscribed);

  @visibleForTesting
  Iterable<String> get cachedIds => List.unmodifiable(_entries.keys);

  // ───────────────────────────── reads ─────────────────────────────

  /// The cached profile, or null. Pure: no fetch, no recency change, safe in
  /// any context.
  ProfileInfo? peek(String id) => _entries[id];

  /// The live name of [id], or [fallback] while unknown, empty, deleted or in
  /// legacy mode. A miss queues a fetch.
  String nameFor(String id, {String fallback = ''}) {
    final p = _use(id);
    if (p == null || p.deleted || p.name.isEmpty) return fallback;
    return p.name;
  }

  /// The live `@username` of [id], or [fallback].
  String usernameFor(String id, {String fallback = ''}) {
    final p = _use(id);
    if (p == null) return fallback;
    // A tombstone never shows the copied handle.
    return p.deleted ? '' : p.username;
  }

  /// The avatar blob id of [id] as this viewer sees it, or [fallback] (the
  /// copy the caller holds, often null).
  String? avatarFor(String id, {String? fallback}) {
    final p = _use(id);
    if (p == null) return fallback;
    // A known profile wins, including "no avatar" (access may have been lost);
    // a tombstone never shows the copied face.
    return p.deleted ? null : p.avatarStorageId;
  }

  /// Whether [id] is a known tombstone.
  bool isDeleted(String id) => _use(id)?.deleted ?? false;

  /// Marks [id] in demand and returns what is cached.
  ProfileInfo? _use(String id) {
    if (id.isEmpty || _legacy || _userId == null) return null;
    _touch(id);
    final p = _entries.remove(id);
    if (p != null) {
      _entries[id] = p; // most recently used
      return p;
    }
    _want(id);
    return null;
  }

  // ───────────────────────────── attach ─────────────────────────────

  /// Bind to [userId] and load their disk cache. Idempotent for the same user;
  /// a different user clears first.
  Future<void> attach(String userId) async {
    if (userId.isEmpty) return;
    if (_userId == userId) return;
    if (_userId != null) clear();
    _userId = userId;
    final epoch = _epoch;
    if (_memoryOnly) return;
    try {
      final f = await _file(userId);
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (epoch != _epoch) return;
      if (raw is! Map || raw['v'] != schemaVersion) return;
      final map = raw['p'];
      if (map is! Map) return;
      // File order is oldest first, so recency survives the round trip.
      var loaded = false;
      for (final e in map.entries) {
        final id = e.key;
        if (id is! String || _entries.containsKey(id)) continue;
        final p = ProfileInfo.fromDisk(id, e.value);
        if (p != null) {
          _entries[id] = p;
          loaded = true;
        }
      }
      _evict();
      if (loaded) _notify();
    } catch (_) {
      // A corrupt cache must never break the app; it refills from the server.
    }
  }

  Future<File> _file(String userId) async {
    final docs = await _dir();
    final dir = Directory('${docs.path}/cache/$userId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/profiles.json');
  }

  // ───────────────────────────── fetch ─────────────────────────────

  void _want(String id) {
    if (_inFlight.contains(id) || _queued.contains(id)) return;
    final until = _negative[id];
    if (until != null) {
      if (now().isBefore(until)) return;
      _negative.remove(id);
    }
    _queued.add(id);
    _coalesceTimer ??= Timer(coalesceDelay, _flush);
  }

  /// Fetch [id] now regardless of the negative cache (the server said it
  /// changed).
  void _force(String id) {
    _negative.remove(id);
    _want(id);
  }

  void _flush() {
    _coalesceTimer = null;
    if (_legacy || _queued.isEmpty) {
      _queued.clear();
      return;
    }
    final ids = _queued.toList();
    _queued.clear();
    for (var i = 0; i < ids.length; i += ProfileApi.maxIds) {
      final end = i + ProfileApi.maxIds > ids.length
          ? ids.length
          : i + ProfileApi.maxIds;
      _run(ids.sublist(i, end));
    }
  }

  void _run(List<String> chunk) {
    final epoch = _epoch;
    _inFlight.addAll(chunk);
    _fetch(chunk).then(
      (rows) {
        if (epoch != _epoch) return;
        _inFlight.removeAll(chunk);
        _onFetched(chunk, rows);
      },
      onError: (Object e) {
        if (epoch != _epoch) return;
        _inFlight.removeAll(chunk);
        // Let the next version delivery retry these.
        for (final id in chunk) {
          _handled.remove(id);
        }
        if (ProfileApi.isMissing(e)) {
          _goLegacy();
          return;
        }
        // Transient: back off like a miss so a bad network doesn't spin.
        final until = now().add(negativeTtl);
        for (final id in chunk) {
          _negative[id] = until;
        }
      },
    );
  }

  void _onFetched(List<String> chunk, List<Map<String, dynamic>?> rows) {
    var changed = false;
    final until = now().add(negativeTtl);
    for (var i = 0; i < chunk.length; i++) {
      final id = chunk[i];
      final row = i < rows.length ? rows[i] : null;
      final p = row == null ? null : ProfileInfo.fromServer(row, id: id);
      if (p == null) {
        _negative[id] = until;
        continue;
      }
      _negative.remove(id);
      final key = p.id;
      final prev = _entries.remove(key);
      _entries[key] = p;
      if (prev != p) changed = true;
    }
    _evict();
    if (changed) {
      _scheduleWrite();
      _notify();
    }
  }

  void _evict() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  // ───────────────────────────── freshness ─────────────────────────────

  void _touch(String id) {
    final isNew = !_touched.containsKey(id);
    _touched.remove(id);
    _touched[id] = now();
    if (isNew) _scheduleSubscribe();
    _pruneTimer ??= Timer(pruneEvery, _prune);
  }

  void _scheduleSubscribe() {
    if (_legacy) return;
    _subTimer ??= Timer(subscribeDelay, () {
      _subTimer = null;
      _applySubscription(fromAdd: true);
    });
  }

  void _prune() {
    _pruneTimer = null;
    _expireTouched();
    if (_touched.isNotEmpty) _pruneTimer = Timer(pruneEvery, _prune);
    _applySubscription();
  }

  void _expireTouched() {
    final cutoff = now().subtract(activeWindow);
    _touched.removeWhere((_, at) => at.isBefore(cutoff));
  }

  List<String> _target() {
    _expireTouched();
    return _touched.keys.toList().reversed.take(maxActive).toList();
  }

  void _applySubscription({bool fromAdd = false}) {
    if (_legacy || _userId == null) return;
    final target = _target();
    // Additions only, soon after the last subscribe: batch them. Touched ids
    // are fetched by `get` right away; the subscription only drives updates.
    if (fromAdd &&
        _subscribed.isNotEmpty &&
        target.toSet().containsAll(_subscribed) &&
        _lastSubAt != null) {
      final wait = subscribeDelay - now().difference(_lastSubAt!);
      if (wait > Duration.zero) {
        _subTimer ??= Timer(wait, () {
          _subTimer = null;
          _applySubscription(fromAdd: true);
        });
        return;
      }
    }
    final key = (List.of(target)..sort()).join(',');
    if (key == (_key ?? '')) return;

    _cancelCurrent();
    _subscribed = target.toSet();
    _key = key.isEmpty ? null : key;
    if (target.isEmpty) return;

    _lastSubAt = now();
    final gen = ++_subGen;
    final epoch = _epoch;
    final ids = List.of(target)..sort();
    _subscribe(
      ids,
      (data) {
        if (gen == _subGen && epoch == _epoch) _onVersions(data);
      },
      (error) {
        if (gen == _subGen && epoch == _epoch) _onSubError(error);
      },
    ).then(
      (cancel) {
        if (gen == _subGen && epoch == _epoch) {
          _cancelSub = cancel;
        } else {
          cancel();
        }
      },
      onError: (Object e) {
        if (gen == _subGen && epoch == _epoch) _onSubError(e);
      },
    );
  }

  void _cancelCurrent() {
    _subGen++;
    final c = _cancelSub;
    _cancelSub = null;
    c?.call();
  }

  void _onVersions(dynamic data) {
    if (data is! List) return;
    for (final row in data) {
      if (row is! Map) continue;
      final id = row['id'];
      if (id is! String) continue;
      final u = row['u'] is num ? (row['u'] as num).toInt() : 0;
      final av = row['av'] == true;
      final stamp = '$u|$av';
      if (_handled[id] == stamp) continue;
      final have = _entries[id];
      if (have != null && have.updatedAt == u && have.hasAvatar == av) {
        _handled[id] = stamp;
        continue;
      }
      _handled[id] = stamp;
      _force(id);
    }
  }

  void _onSubError(Object error) {
    if (!ProfileApi.isMissing(error)) return; // the registry heals the rest
    _goLegacy();
  }

  void _goLegacy() {
    if (_legacy) return;
    _legacy = true;
    _cancelCurrent();
    _subscribed = {};
    _key = null;
    _subTimer?.cancel();
    _subTimer = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _queued.clear();
    _notify();
  }

  // ───────────────────────────── disk ─────────────────────────────

  void _scheduleWrite() {
    if (_memoryOnly || _userId == null) return;
    _dirty = true;
    _writeTimer?.cancel();
    final epoch = _epoch;
    final userId = _userId!;
    _writeTimer = Timer(writeDebounce, () {
      _writeTimer = null;
      if (epoch != _epoch) return;
      _write(userId);
    });
  }

  Future<void> _write(String userId) async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final body = jsonEncode({
        'v': schemaVersion,
        'p': {for (final e in _entries.entries) e.key: e.value.toDisk()},
      });
      final f = await _file(userId);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(body, flush: true);
      await tmp.rename(f.path);
    } catch (_) {
      // Best effort: the next change writes again.
      _dirty = true;
    }
  }

  /// Write any pending change now. For tests and app shutdown.
  Future<void> flush() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    final u = _userId;
    if (u != null && !_memoryOnly) await _write(u);
  }

  // ───────────────────────────── lifecycle ─────────────────────────────

  void _notify() {
    if (_notifyQueued) return;
    _notifyQueued = true;
    scheduleMicrotask(() {
      _notifyQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  /// Sign-out or account switch: forget everything in memory (the disk file
  /// stays, it belongs to that user). Leaves legacy mode too, since the next
  /// server may differ. Outstanding fetches and subscriptions become no-ops.
  void clear() {
    _epoch++;
    _userId = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _subTimer?.cancel();
    _subTimer = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _writeTimer?.cancel();
    _writeTimer = null;
    _dirty = false;
    _cancelCurrent();
    _subscribed = {};
    _key = null;
    _lastSubAt = null;
    _queued.clear();
    _inFlight.clear();
    _negative.clear();
    _touched.clear();
    _handled.clear();
    final hadData = _entries.isNotEmpty;
    _entries.clear();
    final wasLegacy = _legacy;
    _legacy = false;
    if (hadData || wasLegacy) _notify();
  }

  @override
  void dispose() {
    clear();
    _disposed = true;
    super.dispose();
  }
}
