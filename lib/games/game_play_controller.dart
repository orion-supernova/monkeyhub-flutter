import 'dart:async';

import 'package:flutter/widgets.dart';

import '../backend/games_api.dart';
import '../data/feed_store.dart';
import '../data/games_store.dart';
import '../models/daily_game.dart';

/// The clock, the server round trips and the lifecycle rules that all four
/// daily games share.
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
  bool _busy = false;
  bool _paused = false;
  bool _finished = false;
  bool _solved = false;
  bool _gaveUp = false;
  int _mistakes = 0;
  int _hints = 0;
  int? _durationMs;
  String? _errorCode;
  List<int> _restored = const [];

  /// False until [begin] has heard back. The board renders inert until then, so
  /// a tap cannot land before there is a clock to time it against.
  bool get ready => _ready;

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

  /// The stopwatch. Ticks only while the board is open, in the foreground and
  /// unpaused.
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
      } else {
        _resume();
      }
    } catch (e) {
      _errorCode = _codeOf(e);
      // Ready anyway, with the clock running locally. A board that refuses to
      // open because one mutation missed is worse than a board whose start time
      // the server will settle on the next call — and `submit` re-derives the
      // ceiling from its own row regardless.
      _ready = true;
      _resume();
    }
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

  /// Reveals one correct cell. Returns null when there is nothing left to
  /// reveal, or when the call failed — [errorCode] carries why.
  ///
  /// [board] must be in the shape this game submits: a column per row for
  /// Queens, a value per cell for Tango and Sudoku. Zip has no hint at all —
  /// see [GamesApi.hint].
  Future<GameHint?> hint(List<int> board) async {
    if (_busy || _finished) return null;
    _busy = true;
    _errorCode = null;
    notifyListeners();
    try {
      final result = await _api.hint(
        userId: userId,
        dayKey: _dayKey,
        game: game,
        board: board,
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
  Future<bool> submit(List<int> solution) async {
    if (_busy || _finished) return false;
    _busy = true;
    _errorCode = null;
    _hold();
    notifyListeners();
    try {
      final outcome = await _api.submit(
        userId: userId,
        dayKey: _dayKey,
        game: game,
        solution: solution,
        elapsedMs: elapsed.inMilliseconds,
        hintsUsed: _hints,
        mistakes: _mistakes,
      );
      _busy = false;
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
      notifyListeners();
      return outcome.solved;
    } catch (e) {
      _busy = false;
      _errorCode = _codeOf(e);
      // The clock restarts: a rejected submit means they are still playing, and
      // leaving it stopped would quietly hand them free thinking time.
      if (!_paused) _resume();
      notifyListeners();
      return false;
    }
  }

  /// Gives up. Returns the answer, or null if the call failed.
  Future<List<int>?> reveal() async {
    if (_busy || _finished) return null;
    _busy = true;
    _errorCode = null;
    _hold();
    notifyListeners();
    try {
      final answer = await _api.reveal(
        userId: userId,
        dayKey: _dayKey,
        game: game,
      );
      _busy = false;
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
      notifyListeners();
      return answer;
    } catch (e) {
      _busy = false;
      _errorCode = _codeOf(e);
      if (!_paused) _resume();
      notifyListeners();
      return null;
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
    if (_since != null || _finished) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _hold();
    super.dispose();
  }
}
