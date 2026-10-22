import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../backend/presence_api.dart';

/// What the viewer may see of one person's presence.
///
/// [status] is `online`, `away` or `offline`; null means the person hides it
/// from this viewer. [lastSeen] is epoch millis, only present when allowed.
@immutable
class PresenceInfo {
  const PresenceInfo({this.status, this.lastSeen});

  final String? status;
  final int? lastSeen;

  bool get isOnline => status == 'online';

  static PresenceInfo? fromJson(Map<String, dynamic> j) {
    final s = j['s'];
    final ls = j['ls'];
    final status = s is String ? s : null;
    final lastSeen = ls is num ? ls.toInt() : null;
    // Hidden entirely: indistinguishable from unknown, so no dot is drawn.
    if (status == null && lastSeen == null) return null;
    return PresenceInfo(status: status, lastSeen: lastSeen);
  }

  @override
  bool operator ==(Object other) =>
      other is PresenceInfo &&
      other.status == status &&
      other.lastSeen == lastSeen;

  @override
  int get hashCode => Object.hash(status, lastSeen);
}

/// One hold on a set of ids. [release] is idempotent.
class PresenceLease {
  PresenceLease._(this._store, this._ids, this._epoch);
  final PresenceStore _store;
  final List<String> _ids;
  final int _epoch;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _store._release(_ids, _epoch);
  }
}

/// Binds `presenceApi:forUsers`; returns the canceller. Injected for tests.
typedef PresenceSubscribe = Future<void Function()> Function(
  List<String> ids,
  void Function(dynamic) onData,
  void Function(Object error) onError,
);

/// Presence for the people on screen, and only them.
///
/// Widgets [lease] the ids they draw and release on dispose; the store keeps
/// ONE `presenceApi:forUsers` subscription over the union, so a scrolling list
/// costs one standing query rather than one per row, and a friend's heartbeat
/// re-runs only that query.
///
/// * **Adds coalesce 250 ms** (a lazy list leasing a screenful at once is one
///   subscribe); **removals wait 3 s** (scrolling back is free). An add that
///   fires while removals are pending keeps the stale ids riding along, up to
///   the cap, newest lease first.
/// * **Key-based dedupe:** the sorted ids joined; an identical key never
///   re-subscribes.
/// * **Cap [maxIds] = 100**, the server's limit; past it the most recently
///   leased win and the rest show no dot.
/// * **One [ValueNotifier] per id**, and only ids whose info changed notify.
/// * A value for an id that left the subscription is kept [staleTtl], then
///   dropped to unknown (a stale "online" is worse than no dot).
/// * **Legacy mode** when the server has no `presenceApi` (function not found):
///   no subscription is made and [legacy] turns true, so `UserAvatar` can fall
///   back to `user.status`.
/// * Never persisted.
class PresenceStore extends ChangeNotifier {
  PresenceStore._({PresenceSubscribe? subscribe})
    : _subscribe = subscribe ?? _backendSubscribe;

  static final PresenceStore instance = PresenceStore._();

  /// A private store with its own subscribe function, for tests.
  @visibleForTesting
  factory PresenceStore.forTest(PresenceSubscribe subscribe) =>
      PresenceStore._(subscribe: subscribe);

  static const int maxIds = 100;

  @visibleForTesting
  static Duration addDelay = const Duration(milliseconds: 250);
  @visibleForTesting
  static Duration removeDelay = const Duration(seconds: 3);
  @visibleForTesting
  static Duration staleTtl = const Duration(minutes: 2);

  static Future<void Function()> _backendSubscribe(
    List<String> ids,
    void Function(dynamic) onData,
    void Function(Object error) onError,
  ) async {
    final sub = await ConvexBackend.instance.subscribe(
      PresenceApi.forUsersName,
      {'ids': ids},
      onData: onData,
      onError: onError,
    );
    return sub.cancel;
  }

  final PresenceSubscribe _subscribe;

  /// Lease counts, in lease order: the last entry is the most recently leased.
  /// Re-leasing an id moves it to the end.
  final Map<String, int> _counts = {};
  final Map<String, _Slot> _slots = {};
  final Map<String, Timer> _expiry = {};

  /// The ids the live subscription covers, and its key.
  Set<String> _subscribed = {};
  String? _key;
  void Function()? _cancelSub;

  Timer? _addTimer;
  Timer? _removeTimer;
  bool _legacy = false;

  /// Bumped by [clear] and on every resubscribe, so late callbacks from a
  /// superseded subscription are ignored.
  int _epoch = 0;
  int _subGen = 0;

  /// True once the server answered "function not found".
  bool get legacy => _legacy;

  /// Ids the live subscription covers. For tests and diagnostics.
  @visibleForTesting
  Set<String> get subscribedIds => Set.unmodifiable(_subscribed);

  /// The presence of [id]; null while unknown or hidden. Safe to listen to
  /// whether or not a lease is held.
  ValueListenable<PresenceInfo?> of(String id) => _slot(id);

  /// The current value without listening.
  PresenceInfo? peek(String id) => _slots[id]?.value;

  _Slot _slot(String id) => _slots.putIfAbsent(id, _Slot.new);

  /// Hold [ids] until the returned lease is released.
  PresenceLease lease(Iterable<String> ids) {
    final list = ids.toSet().where((e) => e.isNotEmpty).toList();
    var grew = false;
    for (final id in list) {
      final prev = _counts.remove(id);
      _counts[id] = (prev ?? 0) + 1;
      if (prev == null && !_subscribed.contains(id)) grew = true;
      // Back in demand: its value is live again, not aging out.
      _expiry.remove(id)?.cancel();
    }
    // Even with nothing new, a re-lease can change recency under the cap.
    if (!_legacy && (grew || _counts.length > maxIds)) _scheduleAdd();
    return PresenceLease._(this, list, _epoch);
  }

  void _release(List<String> ids, int epoch) {
    if (epoch != _epoch) return;
    var dropped = false;
    for (final id in ids) {
      final n = _counts[id];
      if (n == null) continue;
      if (n <= 1) {
        _counts.remove(id);
        dropped = true;
      } else {
        _counts[id] = n - 1;
      }
    }
    if (dropped && !_legacy) _scheduleRemove();
  }

  void _scheduleAdd() {
    _addTimer ??= Timer(addDelay, () {
      _addTimer = null;
      // Removals still waiting out their 3 s ride along while there is room.
      _apply(keepStale: _removeTimer != null);
    });
  }

  void _scheduleRemove() {
    _removeTimer?.cancel();
    _removeTimer = Timer(removeDelay, () {
      _removeTimer = null;
      _apply(keepStale: false);
    });
  }

  List<String> _target({required bool keepStale}) {
    // Newest lease first.
    final wanted = _counts.keys.toList().reversed.take(maxIds).toList();
    if (!keepStale || wanted.length >= maxIds) return wanted;
    final room = maxIds - wanted.length;
    final have = wanted.toSet();
    final stale = _subscribed.where((id) => !have.contains(id)).take(room);
    return [...wanted, ...stale];
  }

  void _apply({required bool keepStale}) {
    if (_legacy) return;
    final target = _target(keepStale: keepStale);
    final key = (List.of(target)..sort()).join(',');
    if (key == (_key ?? '')) return;

    final next = target.toSet();
    final previous = _subscribed;
    _cancelCurrent();
    // Ids leaving the subscription start aging; ids staying or joining don't.
    for (final id in previous.difference(next)) {
      _expiry[id]?.cancel();
      _expiry[id] = Timer(staleTtl, () => _expire(id));
    }
    for (final id in next) {
      _expiry.remove(id)?.cancel();
    }
    _subscribed = next;
    _key = key.isEmpty ? null : key;
    if (next.isEmpty) return;

    final gen = ++_subGen;
    final ids = List.of(target)..sort();
    _subscribe(
      ids,
      (data) {
        if (gen == _subGen) _onData(data, next);
      },
      (error) {
        if (gen == _subGen) _onError(error);
      },
    ).then((cancel) {
      if (gen == _subGen) {
        _cancelSub = cancel;
      } else {
        cancel();
      }
    }, onError: (Object e) {
      if (gen == _subGen) _onError(e);
    });
  }

  void _cancelCurrent() {
    _subGen++;
    final c = _cancelSub;
    _cancelSub = null;
    c?.call();
  }

  void _onData(dynamic data, Set<String> covered) {
    if (data is! List) return;
    final seen = <String>{};
    for (final row in data) {
      if (row is! Map) continue;
      final j = row.cast<String, dynamic>();
      final id = j['id'];
      if (id is! String) continue;
      seen.add(id);
      _slot(id).value = PresenceInfo.fromJson(j);
    }
    // Asked for but not returned: nothing visible about them.
    for (final id in covered) {
      if (!seen.contains(id)) _slots[id]?.value = null;
    }
  }

  void _onError(Object error) {
    if (!PresenceApi.isMissing(error)) return; // the registry heals the rest
    _cancelCurrent();
    _subscribed = {};
    _key = null;
    _addTimer?.cancel();
    _addTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;
    if (_legacy) return;
    _legacy = true;
    notifyListeners();
  }

  void _expire(String id) {
    _expiry.remove(id);
    final s = _slots[id];
    if (s == null) return;
    s.value = null;
    // Don't let a session's worth of ids accumulate.
    if (!s.listening) _slots.remove(id);
  }

  /// Sign-out or account switch: forget everything. Outstanding leases become
  /// no-ops. Leaves legacy mode too, since the next server may differ.
  void clear() {
    _epoch++;
    _addTimer?.cancel();
    _addTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;
    for (final t in _expiry.values) {
      t.cancel();
    }
    _expiry.clear();
    _cancelCurrent();
    _counts.clear();
    _subscribed = {};
    _key = null;
    for (final s in _slots.values) {
      s.value = null;
    }
    _slots.removeWhere((_, s) => !s.listening);
    if (_legacy) {
      _legacy = false;
      notifyListeners();
    }
  }
}

class _Slot extends ValueNotifier<PresenceInfo?> {
  _Slot() : super(null);
  bool get listening => hasListeners;
}
