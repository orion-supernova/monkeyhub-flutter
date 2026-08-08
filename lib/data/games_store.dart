import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../backend/convex_client.dart';
import '../backend/games_api.dart';
import '../models/daily_game.dart';
import 'cache_store.dart';
import 'feed_day.dart';
import 'feed_store.dart';

/// Today's four boards and everyone's times, held across screen rebuilds.
///
/// A singleton in the shape of [FeedStore], and for the same reason: the shell
/// disposes the whole section subtree on a tab switch *and* on a theme change,
/// so anything a game screen holds in its own `State` is gone the moment the
/// player glances at another tab. Re-fetching four boards on every such rebuild
/// would be a network round trip to render a grid the device already had.
///
/// **Nothing here subscribes.** The standings are pulled when the hub opens and
/// again when a board is finished, which for a daily leaderboard is
/// indistinguishable from live, and costs nothing while the app is idle. The
/// codebase has repeatedly refused new live queries and this feature adds none.
class GamesStore extends ChangeNotifier {
  GamesStore._();
  static final GamesStore instance = GamesStore._();

  GamesApi? _injected;

  /// The backend facade. Built from the shared [ConvexBackend] singleton rather
  /// than threaded down from `app.dart`, so no screen between the shell and a
  /// game board has to carry an argument it never reads.
  GamesApi get api => _injected ??= GamesApi(ConvexBackend.instance);

  @visibleForTesting
  set api(GamesApi value) => _injected = value;

  String _dayKey = '';
  String? _userId;
  DailyBoards _boards = const DailyBoards();
  GameStandings _standings = const GameStandings();
  bool _loading = false;
  bool _fetchingBoards = false;
  Object? _error;

  /// Guards against a stale [load] finishing after a newer one — the same
  /// generation check `FeedStore.attach` uses, and needed for the same reason:
  /// a day rollover or a re-entry mid-flight would otherwise let the older
  /// response overwrite the newer one's state.
  int _gen = 0;

  /// Today's four boards. Empty until the first load lands; check
  /// [DailyBoards.ready] rather than a spinner flag, so a partial payload
  /// cannot render as four empty grids that look playable.
  DailyBoards get boards => _boards;

  /// The viewer's own rows, any half-finished board, and the friend
  /// leaderboards.
  GameStandings get standings => _standings;

  bool get loading => _loading;
  Object? get error => _error;

  /// The day the held state belongs to.
  String get dayKey => _dayKey;

  /// Notifies, but never from inside a build.
  ///
  /// Every game screen kicks [load] off from its `initState`, and [load]
  /// settles some state — the day key, the loading flag, a board cleared across
  /// a rollover — *before* its first `await`. That puts a `notifyListeners()`
  /// in the same call stack as the build that is mounting the screen, and
  /// `FeedScreen` is still listening from behind the new route, so it gets
  /// marked dirty mid-build. Flutter rejects that outright: the first tap on a
  /// game tile threw "setState() or markNeedsBuild() called during build".
  ///
  /// The guard lives on the store rather than at the call sites because this is
  /// a singleton reached from six places, and "remember to wrap your call in a
  /// post-frame callback" is a rule that holds until the seventh.
  ///
  /// A microtask rather than `addPostFrameCallback`: it fires whether or not
  /// another frame is scheduled, and it runs as soon as the frame's synchronous
  /// work unwinds, so a deferred notification is still handled on the next
  /// frame rather than whenever something else happens to request one.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(notifyListeners);
      return;
    }
    // Outside a build there is nothing to defer around, and routing every
    // update through a microtask would put a frame's delay on all of them.
    notifyListeners();
  }

  /// Loads whatever is missing for [userId]'s current local day.
  ///
  /// The boards themselves are fetched once per day and then held: they are a
  /// pure function of the day key, so there is no version of them that can go
  /// stale before midnight. Only the standings are re-read, and [force] is what
  /// the hub passes on a pull-to-refresh.
  Future<void> load(String userId, {bool force = false}) async {
    // FeedStore owns the day identity and the midnight timer for the whole app.
    // Deriving a second one here would give the games their own idea of "today"
    // that drifts from the board's across a rollover.
    FeedStore.instance.start();
    final day = FeedStore.instance.dayKey.isNotEmpty
        ? FeedStore.instance.dayKey
        : dayKeyOf(DateTime.now());

    final rolled = day != _dayKey;
    final switched = userId != _userId;
    if (rolled || switched) {
      _boards = const DailyBoards();
      _standings = const GameStandings();
    }
    if (!rolled && !switched && !force && _boards.ready && !_loading) {
      // Boards are held, but a leaderboard the player is looking at should
      // still catch up with whoever finished while they were away.
      await _refreshStandings(userId, day);
      return;
    }
    if (_loading && !force) return;

    final gen = ++_gen;
    _dayKey = day;
    _userId = userId;
    _loading = true;
    _error = null;
    _notify();

    try {
      // Issued together: the boards read no table server-side and the standings
      // read one index per friend, so there is nothing for one to wait on.
      final results = await Future.wait([
        _boards.ready && !rolled
            ? Future.value(null)
            : api.dailyRaw(dayKey: day),
        api.standings(userId: userId, dayKey: day),
      ]);
      if (gen != _gen) return;
      final raw = results[0];
      if (raw != null) {
        _boards = DailyBoards.fromJson(raw);
        // Whichever screen pays for the fetch fills the cache. Opening the hub
        // first and the Feed second is as common as the other way round, and
        // only one of them should ever cost a round trip.
        if (raw is Map && _boards.ready) {
          await CacheStore.instance.saveDailyBoards(
            day,
            raw.cast<String, dynamic>(),
          );
        }
      }
      _standings = results[1] as GameStandings;
      _loading = false;
      _error = null;
    } catch (e) {
      if (gen != _gen) return;
      _loading = false;
      // Deliberately keeps the boards already on screen. A transient socket
      // error mid-game must not blank a grid the player is halfway through.
      _error = e;
    }
    _notify();
  }

  /// Fetches today's boards and nothing else.
  ///
  /// What the Feed's games band calls. It wants to draw the four real boards as
  /// thumbnails and already has the viewer's own results in the board payload,
  /// so the friend fan-out [load] does would be a read per friend to render
  /// something nobody is looking at yet. `games:daily` reads no table at all
  /// server-side, and the result is held for the rest of the day.
  Future<void> loadBoards() async {
    FeedStore.instance.start();
    final day = FeedStore.instance.dayKey.isNotEmpty
        ? FeedStore.instance.dayKey
        : dayKeyOf(DateTime.now());
    if (_boards.ready && day == _dayKey) return;
    // The Feed calls this from every mount, and the shell remounts it on a tab
    // switch and on a theme change. Without this the retries below would each
    // get their own competing chain.
    if (_fetchingBoards) return;
    _fetchingBoards = true;

    final gen = ++_gen;
    // Across a rollover, drop yesterday's four before taking the new day key.
    // Otherwise a failed fetch leaves the store holding boards it now believes
    // belong to today, and `load` — which decides whether to re-fetch by
    // comparing the same two things — hands the hub yesterday's puzzles for
    // the rest of the day.
    if (day != _dayKey) _boards = const DailyBoards();
    _dayKey = day;
    try {
      // Disk first, and no network at all if it answers. The boards are a pure
      // function of the day key, so a cached payload for today is not a stale
      // copy of the truth — it is the truth, and the four squares are on screen
      // in the time it takes to read one small file.
      final cached = await CacheStore.instance.loadDailyBoards(day);
      if (gen != _gen) return;
      if (cached != null) {
        final boards = DailyBoards.fromJson(cached);
        if (boards.ready) {
          _boards = boards;
          _notify();
          return;
        }
      }

      // Three tries, then give up until something remounts the Feed. The first
      // launch of a day has nothing on disk to fall back on, and a socket that
      // is still coming up — which is where a cold start starts — fails this
      // call once and then works. Swallowing that left the band showing
      // placeholders until the player happened to switch tabs and come back.
      for (var attempt = 0; ; attempt++) {
        try {
          final raw = await api.dailyRaw(dayKey: day);
          if (gen != _gen) return;
          final boards = DailyBoards.fromJson(raw);
          if (!boards.ready) return;
          _boards = boards;
          _notify();
          if (raw is Map) {
            await CacheStore.instance.saveDailyBoards(
              day,
              raw.cast<String, dynamic>(),
            );
          }
          return;
        } catch (_) {
          if (attempt >= boardRetries.length) return;
          await Future<void>.delayed(boardRetries[attempt]);
          if (gen != _gen) return;
        }
      }
    } finally {
      _fetchingBoards = false;
    }
  }

  /// The waits between those attempts. Mutable only so the tests that pin the
  /// retry do not have to sit through them — the suite runs in ten seconds and
  /// four of those spent asleep is four the next person will not spend running
  /// it.
  @visibleForTesting
  static List<Duration> boardRetries = const [
    Duration(milliseconds: 600),
    Duration(seconds: 3),
  ];

  /// Re-reads the leaderboards alone. Called after a board is finished, so the
  /// player's own time appears in the standings they are being shown.
  Future<void> refreshStandings() async {
    final userId = _userId;
    if (userId == null || _dayKey.isEmpty) return;
    await _refreshStandings(userId, _dayKey);
  }

  Future<void> _refreshStandings(String userId, String day) async {
    final gen = _gen;
    try {
      final next = await api.standings(userId: userId, dayKey: day);
      if (gen != _gen) return;
      _standings = next;
      _error = null;
      _notify();
    } catch (e) {
      if (gen != _gen) return;
      _error = e;
      _notify();
    }
  }

  /// Folds one finished result in without waiting for a round trip.
  ///
  /// The results panel opens the instant a board is solved, and reading a dash
  /// where your own time should be — for the half second before the refetch
  /// lands — reads as the solve not having registered. [refreshStandings]
  /// still runs behind this and replaces it with the authoritative ordering.
  void noteFinished(DailyGame game, GameResult result) {
    _standings = GameStandings(
      mine: {..._standings.mine, game: result},
      progress: _standings.progress,
      boards: _standings.boards,
    );
    _notify();
  }

  /// Drops everything on sign-out.
  ///
  /// Clears the standings as well as the boards: they carry friends' names and
  /// must not flash on screen for whoever signs in next on a shared handset.
  void clear() {
    _gen++;
    _dayKey = '';
    _userId = null;
    _boards = const DailyBoards();
    _standings = const GameStandings();
    _loading = false;
    _error = null;
    _notify();
  }
}
