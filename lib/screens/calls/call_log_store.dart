import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../backend/call_log_api.dart';
import '../../data/settings_store.dart';
import 'call_log_models.dart';

/// The Calls tab's data: one live first-page subscription per filter, older
/// pages on demand, and the two summaries.
///
/// Cost budget (docs/design/calls.md): `callLog` rows are written once at the
/// end of a call and never patched but for one quality report, so a
/// subscription on the first page is cheap. The "missed" subscription is
/// shared between the tab badge and the Missed segment, and exists only while
/// the tab is switched on; the "all" one starts the first time the screen
/// opens.
class CallLogStore extends ChangeNotifier {
  CallLogStore._(this._source);

  /// The app-wide store, on the real API.
  static final CallLogStore instance = CallLogStore._(CallLogApi.shared);

  /// A store on a fake source, for tests.
  @visibleForTesting
  factory CallLogStore.test(CallLogSource source) = CallLogStore._;

  static const int pageSize = 50;
  static const String all = 'all';
  static const String missed = 'missed';

  final CallLogSource _source;
  final Map<String, _Feed> _feeds = {};
  bool _enabled = false;

  // The user's pins. `_favs` is the server's list; the two pending sets are
  // what was tapped but not yet echoed back, so the row moves at once.
  List<CallFavourite> _favs = const [];
  bool _favsLoaded = false;
  void Function()? _favsCancel;
  int _favsGen = 0;
  final List<String> _pendingAdd = [];
  final Set<String> _pendingRemove = {};

  CallLogSummary? _week;
  CallLogSummary? _month;
  final Set<String> _removed = {};
  int _removedVersion = 0;

  CallLogSummary? get week => _week;
  CallLogSummary? get month => _month;

  /// Turns the background work on or off with the tab. Off cancels every
  /// subscription and forgets the data, so a hidden tab costs nothing.
  void setEnabled(bool on) {
    if (_enabled == on) return;
    _enabled = on;
    if (on) {
      ensure(missed);
      ensureFavourites();
    } else {
      reset();
    }
  }

  /// Cancels everything and forgets it (sign-out, tab off).
  void reset() {
    for (final f in _feeds.values) {
      f.cancel?.call();
      f.gen++;
    }
    _feeds.clear();
    _favsCancel?.call();
    _favsCancel = null;
    _favsGen++;
    _favs = const [];
    _favsLoaded = false;
    _pendingAdd.clear();
    _pendingRemove.clear();
    _removed.clear();
    _removedVersion++;
    _week = null;
    _month = null;
    _all = null;
    notifyListeners();
  }

  bool isLoaded(String filter) => _feeds[filter]?.loaded ?? false;
  bool hasMore(String filter) {
    final f = _feeds[filter];
    return f != null && f.loaded && !f.done;
  }

  bool failed(String filter) => _feeds[filter]?.failed ?? false;

  /// Newest first: the live head, then whatever older pages were fetched.
  List<CallLogEntry> entries(String filter) {
    final f = _feeds[filter];
    if (f == null) return const [];
    return f.merged(_removed, _removedVersion);
  }

  /// Whether the pins have arrived (or failed to), so the row is not drawn
  /// as "no favourites" while they are still on the way.
  bool get favouritesLoaded => _favsLoaded;

  /// Who I pinned, in the order I added them, with taps not yet confirmed.
  List<String> get favouriteIds {
    final out = <String>[
      for (final f in _favs)
        if (!_pendingRemove.contains(f.peerId)) f.peerId,
    ];
    for (final id in _pendingAdd) {
      if (!out.contains(id) && !_favs.any((f) => f.peerId == id)) out.add(id);
    }
    return out;
  }

  bool isFavourite(String peerId) => favouriteIds.contains(peerId);

  /// Starts the one shared `callFavorites:list` subscription.
  void ensureFavourites() {
    if (_favsCancel != null || _favsStarting) return;
    _favsStarting = true;
    final gen = _favsGen;
    unawaited(() async {
      try {
        final cancel = await _source.subscribeFavourites(
          onData: (list) {
            if (_favsGen != gen) return;
            _favs = list;
            _favsLoaded = true;
            final have = {for (final f in list) f.peerId};
            _pendingAdd.removeWhere(have.contains);
            _pendingRemove.removeWhere((id) => !have.contains(id));
            notifyListeners();
          },
          onError: (e) {
            if (_favsGen != gen) return;
            _favsLoaded = true;
            notifyListeners();
          },
        );
        if (_favsGen != gen) {
          cancel();
        } else {
          _favsCancel = cancel;
        }
      } catch (_) {
        if (_favsGen == gen) {
          _favsLoaded = true;
          notifyListeners();
        }
      } finally {
        _favsStarting = false;
      }
    }());
  }

  bool _favsStarting = false;

  /// Pins [peerId]: in the row at once, rolled back if the server refuses.
  /// True when it stuck.
  Future<bool> addFavourite(String peerId) async {
    if (isFavourite(peerId)) return true;
    _pendingRemove.remove(peerId);
    _pendingAdd.add(peerId);
    notifyListeners();
    try {
      await _source.addFavourite(peerId);
      return true;
    } catch (_) {
      _pendingAdd.remove(peerId);
      notifyListeners();
      return false;
    }
  }

  /// Unpins [peerId]: gone from the row at once, back if the server refuses.
  Future<bool> removeFavourite(String peerId) async {
    if (!isFavourite(peerId)) return true;
    _pendingAdd.remove(peerId);
    _pendingRemove.add(peerId);
    notifyListeners();
    try {
      await _source.removeFavourite(peerId);
      return true;
    } catch (_) {
      _pendingRemove.remove(peerId);
      notifyListeners();
      return false;
    }
  }

  /// Missed calls since the tab was last opened.
  int get badgeCount =>
      missedSince(entries(missed), SettingsStore.instance.callsSeenAt);

  /// Starts [filter]'s first-page subscription once.
  void ensure(String filter) {
    if (_feeds.containsKey(filter)) return;
    final f = _feeds[filter] = _Feed();
    final gen = f.gen;
    unawaited(() async {
      try {
        final cancel = await _source.subscribeFirstPage(
          filter: filter,
          numItems: pageSize,
          onPage: (page) {
            if (f.gen != gen) return;
            f.head = page.rows;
            f.headDone = page.isDone;
            f.headCursor = page.continueCursor;
            f.loaded = true;
            f.failed = false;
            // Until older pages are fetched, the head decides "more".
            if (f.tail.isEmpty) {
              f.done = page.isDone;
              f.cursor = page.continueCursor;
            }
            notifyListeners();
          },
          onError: (e) {
            if (f.gen != gen) return;
            f.failed = true;
            f.loaded = true;
            notifyListeners();
          },
        );
        if (f.gen != gen) {
          cancel();
        } else {
          f.cancel = cancel;
        }
      } catch (e) {
        if (f.gen != gen) return;
        f.failed = true;
        f.loaded = true;
        notifyListeners();
      }
    }());
  }

  /// Fetches the page after what the list holds.
  Future<void> loadMore(String filter) async {
    final f = _feeds[filter];
    if (f == null || f.loading || f.done || f.cursor == null) return;
    f.loading = true;
    final gen = f.gen;
    try {
      final page = await _source.page(
        filter: filter,
        numItems: pageSize,
        cursor: f.cursor!,
      );
      if (f.gen != gen) return;
      f.tail = [...f.tail, ...page.rows];
      f.done = page.isDone;
      f.cursor = page.continueCursor;
    } catch (_) {
      // Leave the cursor: the next scroll to the end tries again.
    } finally {
      f.loading = false;
      if (f.gen == gen) notifyListeners();
    }
  }

  /// Loads both summaries (week for the talk-time header, month for the
  /// favourite suggestion). Failures leave the old values.
  Future<void> loadSummaries({required int weekSince, required int monthSince}) async {
    try {
      final r = await Future.wait([
        _source.summary(since: weekSince, tzOffsetMin: _tz()),
        _source.summary(since: monthSince, tzOffsetMin: _tz()),
      ]);
      _week = r[0];
      _month = r[1];
      notifyListeners();
    } catch (_) {}
  }

  /// The viewer's UTC offset in minutes, so the server buckets by their clock.
  static int _tz() => DateTime.now().timeZoneOffset.inMinutes;

  CallLogSummary? _all;
  bool _allLoading = false;

  /// The newest-1000-calls summary for "All time"; fetched the first time the
  /// stats sheet asks (never on opening the tab), then kept for the session.
  CallLogSummary? get allTime => _all;

  Future<void> loadAllTime() async {
    if (_all != null || _allLoading) return;
    _allLoading = true;
    try {
      _all = await _source.summary(since: 0, tzOffsetMin: _tz());
      notifyListeners();
    } catch (_) {
    } finally {
      _allLoading = false;
    }
  }

  /// Removes [ids] from my history: gone from the list at once, then on the
  /// server. A failed delete brings them back.
  Future<void> remove(Iterable<String> ids) async {
    final list = ids.toList();
    _removed.addAll(list);
    _all = null;
    _removedVersion++;
    notifyListeners();
    for (final id in list) {
      try {
        await _source.remove(id);
      } catch (_) {
        _removed.remove(id);
        _removedVersion++;
        notifyListeners();
      }
    }
  }
}

class _Feed {
  List<CallLogEntry> head = const [];
  List<CallLogEntry> tail = const [];
  bool headDone = false;
  String? headCursor;
  String? cursor;
  bool done = false;
  bool loaded = false;
  bool failed = false;
  bool loading = false;
  int gen = 0;
  void Function()? cancel;

  List<CallLogEntry>? _cache;
  List<CallLogEntry>? _cacheHead;
  List<CallLogEntry>? _cacheTail;
  int _cacheRemoved = -1;

  List<CallLogEntry> merged(Set<String> removed, int version) {
    if (identical(_cacheHead, head) &&
        identical(_cacheTail, tail) &&
        _cacheRemoved == version &&
        _cache != null) {
      return _cache!;
    }
    final seen = <String>{};
    final out = <CallLogEntry>[];
    for (final e in head) {
      if (!removed.contains(e.id) && seen.add(e.id)) out.add(e);
    }
    for (final e in tail) {
      if (!removed.contains(e.id) && seen.add(e.id)) out.add(e);
    }
    _cacheHead = head;
    _cacheTail = tail;
    _cacheRemoved = version;
    return _cache = out;
  }
}
