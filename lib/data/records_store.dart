import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../backend/convex_client.dart';
import '../backend/games_api.dart';
import '../models/game_record.dart';
import 'games_store.dart';

/// Everyone's all-time bests, held across screens — the hub's ALL-TIME section
/// and the records sheet a game screen opens both read this one copy.
///
/// Its own store rather than more state on [GamesStore]: that one is about
/// today (four boards and a day's standings, all dropped at midnight), and this
/// is about every day there has ever been. Mixing the two would mean every
/// rollover had to remember which half not to clear.
///
/// **Nothing here subscribes**, for the reason `records.ts` gives: personal
/// bests move a few times a week, and a live query would re-run on every
/// friend's presence heartbeat to say so. It is read when a surface that shows
/// it opens, and folds the reader's own reactions in without waiting.
class RecordsStore extends ChangeNotifier {
  RecordsStore._();
  static final RecordsStore instance = RecordsStore._();

  GamesApi? _injected;
  GamesApi get api => _injected ??= GamesApi(ConvexBackend.instance);

  @visibleForTesting
  set api(GamesApi value) => _injected = value;

  RecordBoard _board = const RecordBoard();
  String? _userId;
  bool _answered = false;
  bool _loading = false;
  Object? _error;
  int _gen = 0;

  /// The read in flight, which a second plain [load] waits on rather than
  /// returning before the board it is about to draw has landed.
  Future<void>? _pending;

  /// When the held board was last answered, and how many games the viewer had
  /// finished by then ([GamesStore.finishedSeq]). A plain [load] inside
  /// [ttl] with no finish since is answered from the held board.
  DateTime? _answeredAt;
  int _answeredSeq = -1;

  /// How long a held board answers a plain [load]. Records only move when
  /// somebody finishes a game, and the viewer's own finishes are tracked
  /// separately, so this only bounds how late a friend's new best shows up.
  @visibleForTesting
  static Duration ttl = const Duration(seconds: 30);

  /// The clock [ttl] is measured on. Swappable for the tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Reactions sent and not yet answered, by record — so a board that lands
  /// mid-flight does not snap a fresh reaction back to what the server had a
  /// moment before it.
  final Map<String, String?> _inFlight = {};

  RecordBoard get board => _board;

  /// Whether the server has answered at least once for this user. Tells "no
  /// records yet" apart from "not loaded yet" — see [PendingPlaceholder].
  bool get answered => _answered;
  bool get loading => _loading;
  Object? get error => _error;

  /// Never notify from inside a build — the same guard, for the same reason, as
  /// `GamesStore._notify`: screens kick [load] off from `initState`.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(notifyListeners);
      return;
    }
    notifyListeners();
  }

  /// Reads the board for [userId]. Coalesced: a call while one is in flight
  /// shares it rather than starting a second, and a plain call with a fresh
  /// board held (see [ttl]) does not read at all. [force] always reads.
  Future<void> load(String userId, {bool force = false}) {
    if (userId != _userId) {
      _board = const RecordBoard();
      _answered = false;
      _answeredAt = null;
      _inFlight.clear();
    }
    if (!force && userId == _userId) {
      if (_loading) return _pending ?? Future.value();
      final at = _answeredAt;
      if (_answered &&
          at != null &&
          _answeredSeq == GamesStore.instance.finishedSeq &&
          now().difference(at) < ttl) {
        return Future.value();
      }
    }
    return _pending = _read(userId);
  }

  Future<void> _read(String userId) async {
    final gen = ++_gen;
    final seq = GamesStore.instance.finishedSeq;
    _userId = userId;
    _loading = true;
    _error = null;
    _notify();
    try {
      final next = await api.recordBoard(userId: userId);
      if (gen != _gen) return;
      _board = _withInFlight(next);
      _answered = true;
      _answeredAt = now();
      _answeredSeq = seq;
      _error = null;
    } catch (e) {
      if (gen != _gen) return;
      // Keeps whatever was already on screen: a dropped socket must not blank
      // a board somebody is reading.
      _error = e;
    }
    _loading = false;
    _notify();
  }

  /// Sets the viewer's reaction on [row] to [emoji], or takes it off when it is
  /// already that emoji. Applied at once and reverted if the server refuses.
  Future<Object?> toggleReaction(GameRecordRow row, String emoji) async {
    final userId = _userId;
    if (userId == null) return StateError('not loaded');
    final removing = row.mine == emoji;
    final next = removing ? null : emoji;
    final before = _rowById(row.recordId) ?? row;
    _inFlight[row.recordId] = next;
    _board = _board.replacing(_applyMine(before, next));
    _notify();
    try {
      if (removing) {
        await api.unreactToRecord(userId: userId, recordId: row.recordId);
      } else {
        await api.reactToRecord(
          userId: userId,
          recordId: row.recordId,
          emoji: emoji,
        );
      }
      return null;
    } catch (e) {
      _board = _board.replacing(before);
      return e;
    } finally {
      if (_inFlight[row.recordId] == next) _inFlight.remove(row.recordId);
      _notify();
    }
  }

  GameRecordRow? _rowById(String recordId) {
    for (final rows in _board.games.values) {
      for (final r in rows) {
        if (r.recordId == recordId) return r;
      }
    }
    return null;
  }

  RecordBoard _withInFlight(RecordBoard board) {
    var out = board;
    for (final e in _inFlight.entries) {
      for (final rows in board.games.values) {
        for (final r in rows) {
          if (r.recordId == e.key) out = out.replacing(_applyMine(r, e.value));
        }
      }
    }
    return out;
  }

  /// [row] with the viewer's reaction set to [emoji] (or removed, for null),
  /// the counts moved to match. The reactor list is left to the server — it
  /// names people, and the viewer is not one the board shows by name.
  static GameRecordRow _applyMine(GameRecordRow row, String? emoji) {
    if (row.mine == emoji) return row;
    final counts = <String, int>{
      for (final r in row.reactions) r.emoji: r.count,
    };
    final previous = row.mine;
    if (previous != null) {
      final left = (counts[previous] ?? 1) - 1;
      if (left <= 0) {
        counts.remove(previous);
      } else {
        counts[previous] = left;
      }
    }
    if (emoji != null) counts[emoji] = (counts[emoji] ?? 0) + 1;
    final reactions = [
      for (final e in counts.entries)
        RecordReaction(emoji: e.key, count: e.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return emoji == null
        ? row.copyWith(reactions: reactions, clearMine: true)
        : row.copyWith(reactions: reactions, mine: emoji);
  }

  /// Drops everything on sign-out: the board carries friends' names.
  void clear() {
    _gen++;
    _board = const RecordBoard();
    _userId = null;
    _answered = false;
    _answeredAt = null;
    _pending = null;
    _loading = false;
    _error = null;
    _inFlight.clear();
    _notify();
  }
}
