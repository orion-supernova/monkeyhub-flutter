import 'dart:async';

import 'package:flutter/widgets.dart';

import '../backend/games_api.dart';
import '../data/feed_store.dart';
import '../data/games_store.dart';
import '../models/daily_game.dart';

/// The clock, the server round trips and the lifecycle rules that every daily
/// game shares.
///
/// Pulled out because every board needs the identical dance — claim a start
/// time, restore whatever was left half-finished, run a stopwatch that stops
/// when the app does, autosave on the way out, submit, and handle a surrender —
/// and four copies of that is four places for the timer to leak or the autosave
/// to be forgotten. What stays in each screen is the part that is actually
/// different: the grid, and what a tap on it means.
///
/// ## Why the stopwatch is here rather than on the server
///
/// The clock stops when the player backgrounds the app or pauses, and starts
/// again when they come back. A purely server-measured duration would time the
/// interruption instead of the solve — answer the door on Queens and you are
/// last on the board for the day. The server still clamps whatever is reported
/// to the window since `start`, so a time can never be *longer* than the player
/// has genuinely had the puzzle in front of them; below that ceiling this is a
/// private app between friends whose points board is already, openly,
/// self-reported.
class GamePlayController extends ChangeNotifier with WidgetsBindingObserver {
  GamePlayController({required this.game, required this.userId});

  final DailyGame game;
  final String userId;

  GamesApi get _api => GamesStore.instance.api;

  String get _dayKey => FeedStore.instance.dayKey;

  Duration _accumulated = Duration.zero;
  DateTime? _since;
  Timer? _tick;

  bool _ready = false;
  bool _started = false;
  bool _busy = false;
  bool _paused = false;
  bool _finished = false;
  bool _solved = false;
  bool _gaveUp = false;
  bool _shared = false;
  int _mistakes = 0;
  int _hints = 0;
  int? _durationMs;
  String? _errorCode;
  List<int> _restored = const [];
  bool _stalled = false;
  bool _disposed = false;

  /// A submit or a surrender is out. The clock stays stopped for all of it —
  /// including across an app resume, which would otherwise restart it while a
  /// solved board sat waiting for a connection.
  bool _finishing = false;
  Completer<void>? _wake;

  static const _retryAfter = Duration(seconds: 4);

  /// False until [begin] has heard back. The board renders inert until then, so
  /// a tap cannot land before there is a clock to time it against.
  bool get ready => _ready;

  /// Whether the player has touched the board yet. The clock waits for it —
  /// opening a game is not starting it, and a stopwatch that ran while the
  /// screen was still settling, or while somebody read the rules, would time
  /// the walk in rather than the solve.
  bool get started => _started;

  /// A server round trip is in flight. Submit and hint disable themselves.
  bool get busy => _busy;

  bool get paused => _paused;

  /// The player can no longer act on today's board — solved, or given up.
  bool get finished => _finished;

  bool get solved => _solved;
  bool get gaveUp => _gaveUp;

  /// Wrong moves the player made. Advisory: shown beside a result, never used
  /// to rank one, because sorting on a number the client reports and the server
  /// cannot check would make the leaderboard a claim rather than a race.
  int get mistakes => _mistakes;

  int get hintsUsed => _hints;

  /// The final time once [finished] and [solved].
  int? get durationMs => _durationMs;

  /// The last failure, as the bare server code (`NOT_SOLVED`, `NO_HINT`, …) so
  /// the screen can pick a localized line for it. Null once anything succeeds.
  String? get errorCode => _errorCode;

  /// The board as the player left it last time, empty on a fresh start.
  List<int> get restored => _restored;

  /// A finish — a solved board, or a surrender — is waiting on the network.
  ///
  /// The board stays inert and the clock stays stopped while this is true, and
  /// the call is resent every few seconds until the server answers. See
  /// [_untilLanded] for why that is the only safe thing to do with it.
  bool get stalled => _stalled;

  /// Resends a stalled finish now rather than at the next retry.
  void retryNow() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Whether this result has already been pushed to the player's friends.
  ///
  /// Seeded from the standings on [begin] so reopening a board finished and
  /// shared this morning does not offer the action again, and set locally by
  /// [shareWithFriends] so the button retires the moment it is used rather
  /// than waiting for the standings to come back.
  bool get shared => _shared;

  /// The stopwatch. Ticks only once [startClock] has run, and then only while
  /// the board is open, in the foreground and unpaused.
  Duration get elapsed {
    final since = _since;
    if (since == null) return _accumulated;
    return _accumulated + DateTime.now().difference(since);
  }

  /// Claims a start time and restores any half-finished board.
  ///
  /// Idempotent on the server by existence, so returning to a board you walked
  /// away from does not reset its clock — otherwise a good time is farmable by
  /// backing out and coming straight back in.
  Future<void> begin() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final session = await _api.start(
        userId: userId,
        dayKey: _dayKey,
        game: game,
      );
      _restored = session.progress;
      _accumulated = Duration(milliseconds: session.elapsedMs);
      _hints = session.hintsUsed;
      _mistakes = session.mistakes;
      _finished = session.finished;
      _ready = true;
      if (_finished) {
        _durationMs = GamesStore.instance.standings.mine[game]?.durationMs;
        _solved = GamesStore.instance.standings.mine[game]?.solved ?? false;
        _gaveUp = GamesStore.instance.standings.mine[game]?.gaveUp ?? false;
        _shared = GamesStore.instance.standings.mine[game]?.shared ?? false;
      }
    } catch (e) {
      _errorCode = _codeOf(e);
      // Ready anyway, with the clock running locally. A board that refuses to
      // open because one mutation missed is worse than a board whose start time
      // the server will settle on the next call — and `submit` re-derives the
      // ceiling from its own row regardless.
      _ready = true;
    }
    notifyListeners();
  }

  /// Starts the clock on the player's first touch of the board. Every later
  /// call is a no-op, so the board can call it on every touch.
  ///
  /// A board restored mid-solve waits for a touch too: its saved time carries
  /// on from where it stopped, not from the moment the screen opened.
  void startClock() {
    if (!_ready || _started || _finished || _paused) return;
    _started = true;
    _resume();
    notifyListeners();
  }

  /// Stops the clock and shows the pause card. The board is hidden behind it —
  /// a paused stopwatch over a readable grid is just a free think.
  void pause() {
    if (_paused || _finished) return;
    _paused = true;
    _hold();
    notifyListeners();
  }

  void resume() {
    if (!_paused || _finished) return;
    _paused = false;
    _resume();
    notifyListeners();
  }

  /// Counts a wrong move.
  void noteMistake() {
    _mistakes++;
    notifyListeners();
  }

  /// Puts [penalty] on the clock, as if the player had spent it.
  ///
  /// Minesweeper's price for walking onto a mine. Ending the game there would
  /// make one slip worth more than ten minutes of clean deduction, and on a
  /// no-guess board a mine is always a misread number rather than bad luck, so
  /// it costs time instead and the board carries on. Added to the banked time
  /// rather than faked into a moving clock, so the stopwatch jumps by exactly
  /// the penalty the player can see they were charged. The server lets a
  /// reported time run past the real one by this much per counted mistake, and
  /// no further (see `MINE_PENALTY_MS` in backend/convex/games.ts).
  void addPenalty(Duration penalty) {
    if (_finished) return;
    _accumulated += penalty;
    notifyListeners();
  }

  /// Reveals one correct cell. Returns null when there is nothing left to
  /// reveal, or when the call failed — [errorCode] carries why.
  ///
  /// [board] must be in the shape [GamesApi.hint] documents for this game:
  /// mostly the submission's own shape, a working grid for Nonogram and
  /// Minesweeper, and the pipes end to end for Flow. Zip has no hint at all.
  Future<GameHint?> hint(List<int> board) async {
    if (_busy || _finished) return null;
    // A hint is a move like any other — asking for one before touching the
    // board must not be a way to get a cell for free off the clock.
    startClock();
    _busy = true;
    _errorCode = null;
    notifyListeners();
    try {
      final result = await _api.hint(
        userId: userId,
        dayKey: _dayKey,
        game: game,
        board: board,
        seq: _hints,
      );
      _hints++;
      _busy = false;
      notifyListeners();
      return result.isEmpty ? null : result;
    } catch (e) {
      _busy = false;
      _errorCode = _codeOf(e);
      notifyListeners();
      return null;
    }
  }

  /// Submits a finished board. True once the server agrees it is solved.
  ///
  /// A board that cannot reach the server is not handed back. It stays locked,
  /// with the clock stopped at the moment it was solved, and the same result is
  /// resent until it lands — see [_untilLanded]. The future completes then, so
  /// the caller's win sweep plays when the server agrees rather than never.
  Future<bool> submit(List<int> solution) async {
    if (_busy || _finished) return false;
    _busy = true;
    _finishing = true;
    _errorCode = null;
    _hold();
    notifyListeners();
    // Read once, here. Every resend reports the time the board was solved at,
    // not the time the connection came back.
    final elapsedMs = elapsed.inMilliseconds;
    final hints = _hints;
    final mistakes = _mistakes;
    Future<GameOutcome> send() => _api.submit(
      userId: userId,
      dayKey: _dayKey,
      game: game,
      solution: solution,
      elapsedMs: elapsedMs,
      hintsUsed: hints,
      mistakes: mistakes,
    );
    try {
      final outcome = await _untilLanded(() async {
        try {
          return await send();
        } catch (e) {
          // The clock was claimed while offline and never reached the server.
          // Claim it now — `start` is idempotent — and try again.
          if (_codeOf(e) != 'NOT_STARTED') rethrow;
          await _api.start(userId: userId, dayKey: _dayKey, game: game);
          return send();
        }
      });
      _busy = false;
      _finishing = false;
      _finished = true;
      _solved = outcome.solved;
      _durationMs = outcome.durationMs;
      final result = GameResult(
        game: game,
        solved: outcome.solved,
        gaveUp: false,
        finished: true,
        durationMs: outcome.durationMs,
        hintsUsed: _hints,
        mistakes: _mistakes,
      );
      GamesStore.instance.noteFinished(game, result);
      // The hub is not the only surface counting this game. The Feed band's
      // "3 left" line and the nav badge read FeedStore, which is fed by the
      // board subscription alone — so a board that has gone quiet kept
      // offering a game the player had just finished until they restarted.
      FeedStore.instance.noteGameFinished(game, result);
      // Behind the optimistic row above, so the leaderboard settles into the
      // authoritative ordering without the player watching a dash where their
      // own time should be.
      unawaited(GamesStore.instance.refreshStandings());
      _notify();
      return outcome.solved;
    } catch (e) {
      _busy = false;
      _finishing = false;
      if (_disposed) return false;
      _errorCode = _codeOf(e);
      // The clock restarts: a rejected submit means they are still playing, and
      // leaving it stopped would quietly hand them free thinking time.
      if (!_paused) _resume();
      notifyListeners();
      return false;
    }
  }

  /// Gives up. Returns the answer, or null if the server refused.
  ///
  /// Held through a network failure exactly as [submit] is, and for a sharper
  /// reason: a surrender that timed out here is still in the native client's
  /// queue, and handing the board back would let the player carry on solving
  /// until the reconnect delivered it and ended the game under them.
  Future<List<int>?> reveal() async {
    if (_busy || _finished) return null;
    _busy = true;
    _finishing = true;
    _errorCode = null;
    _hold();
    notifyListeners();
    try {
      final answer = await _untilLanded(
        () => _api.reveal(userId: userId, dayKey: _dayKey, game: game),
      );
      _busy = false;
      _finishing = false;
      _finished = true;
      _solved = false;
      _gaveUp = true;
      final result = GameResult(
        game: game,
        solved: false,
        gaveUp: true,
        finished: true,
        hintsUsed: _hints,
        mistakes: _mistakes,
      );
      GamesStore.instance.noteFinished(game, result);
      FeedStore.instance.noteGameFinished(game, result);
      unawaited(GamesStore.instance.refreshStandings());
      _notify();
      return answer;
    } catch (e) {
      _busy = false;
      _finishing = false;
      if (_disposed) return null;
      _errorCode = _codeOf(e);
      if (!_paused) _resume();
      notifyListeners();
      return null;
    }
  }

  /// Pushes this result to the player's friends, once.
  ///
  /// The only outbound notification in the app a person sends about themselves,
  /// and the reason it is a button rather than something [submit] does: a
  /// moment is published on purpose, but finishing a board is just Tuesday, and
  /// an app that announced it unasked would be turned off by the people who
  /// play most.
  ///
  /// [shared] flips BEFORE the round trip and stays flipped on failure, which
  /// is deliberate. The server refuses a second send (`ALREADY_SHARED`) off a
  /// column it has already written, so the honest ambiguity here — did the
  /// mutation land, or the reply get lost? — resolves the same way either way:
  /// leave the button retired and let them find out from their friends. The
  /// opposite choice, re-offering it, is the one that notifies fifty people
  /// twice.
  ///
  /// Returns the error code when the server refused, so the caller can say
  /// which of the refusals it was — `RESULT_PRIVATE` in particular is worth
  /// telling somebody about, because the fix is a setting they own.
  Future<String?> shareWithFriends() async {
    if (!_finished || _shared || _busy) return null;
    _shared = true;
    notifyListeners();
    try {
      await _api.shareResult(userId: userId, dayKey: _dayKey, game: game);
      return null;
    } catch (e) {
      return _codeOf(e);
    }
  }

  /// Stores a half-finished board and the clock that goes with it.
  ///
  /// Called on the way out of the screen, never per move — a mutation per tap
  /// on a grid you tap sixty times would be the chattiest thing in the app.
  /// Failures are swallowed: losing an autosave is a disappointment, and an
  /// error toast on a screen the player has already left is worse.
  void checkpoint(List<int> board) {
    if (!_ready || _finished || board.isEmpty) return;
    unawaited(
      _api
          .saveProgress(
            userId: userId,
            dayKey: _dayKey,
            game: game,
            progress: board,
            elapsedMs: elapsed.inMilliseconds,
            mistakes: _mistakes,
          )
          .catchError((_) {}),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The clock follows the app, not the screen. A player who takes a call
    // mid-Queens should come back to the time they left, and a stopwatch that
    // kept running in the background would be timing the call.
    if (state == AppLifecycleState.resumed) {
      if (!_paused && !_finished) _resume();
    } else {
      _hold();
    }
  }

  void _resume() {
    if (_since != null || _finished || _finishing || !_started) return;
    _since = DateTime.now();
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _hold() {
    final since = _since;
    if (since != null) _accumulated += DateTime.now().difference(since);
    _since = null;
    _tick?.cancel();
    _tick = null;
  }

  /// Runs [call] until the server gives an answer — a result, or a refusal
  /// that is a verdict (`NOT_SOLVED`, …) — and returns or throws that answer.
  ///
  /// A failure that is not a verdict — a timeout, a dead socket — says nothing
  /// about the call, and in particular does not mean it did not happen. The
  /// native client keeps every sent mutation in flight and resends it when the
  /// socket comes back, however long ago this side gave up on it. Treating a
  /// timeout as "it failed, carry on" is how a surrender could land minutes
  /// after the player was handed their board back. So the finish is held and
  /// resent until it is answered; both calls are idempotent on the server, so
  /// the copies cost nothing.
  ///
  /// Stops when the controller is disposed, and the last error is rethrown so
  /// the caller unwinds. Whatever was still in flight lands on its own; a board
  /// that was solved is submitted again the next time it is opened.
  Future<T> _untilLanded<T>(Future<T> Function() call) async {
    while (true) {
      try {
        final result = await call();
        _stalled = false;
        return result;
      } catch (e) {
        if (_disposed || _codeOf(e) != 'UNKNOWN') {
          _stalled = false;
          rethrow;
        }
        _stalled = true;
        _notify();
        final wake = _wake = Completer<void>();
        final timer = Timer(_retryAfter, () {
          if (!wake.isCompleted) wake.complete();
        });
        await wake.future;
        timer.cancel();
        _wake = null;
        if (_disposed) rethrow;
      }
    }
  }

  /// [notifyListeners], unless the screen has already gone. A finish can
  /// outlive the controller by one round trip.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The bare error code out of a thrown Convex failure, whose `toString`
  /// wraps it in a stack of framing this UI has no use for.
  String _codeOf(Object e) {
    const known = [
      'NOT_SOLVED',
      'NOT_STARTED',
      'ALREADY_FINISHED',
      'UNKNOWN_GAME',
      'NO_HINT',
      'BAD_SOLUTION',
      'BAD_PROGRESS',
    ];
    final text = e.toString();
    return known.firstWhere(text.contains, orElse: () => 'UNKNOWN');
  }

  @override
  void dispose() {
    _disposed = true;
    retryNow();
    WidgetsBinding.instance.removeObserver(this);
    _hold();
    super.dispose();
  }
}
