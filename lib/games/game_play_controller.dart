import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../backend/games_api.dart';
import '../calls/phone_call_activity.dart';
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
/// The clock stops whenever the board is not actually in front of the player
/// (see "When the clock stops" below), and starts again when they come back.
/// A purely server-measured duration would time the interruption instead of
/// the solve — answer the door on Queens and you are last on the board for the
/// day. The server still clamps whatever is reported to the window since
/// `start`, so a time can never be *longer* than the player has genuinely had
/// the puzzle in front of them; below that ceiling this is a private app
/// between friends whose points board is already, openly, self-reported. Which
/// is also why a pause needs nothing from the server: it can only ever make
/// the reported time shorter than the wall clock, and the ceiling never cared
/// how much shorter.
///
/// ## When the clock stops
///
/// Three things take the board away from the player, and none of them is the
/// player choosing to pause:
///
///   - **The app leaves the foreground.** `hidden` and `paused` put the pause
///     card up at once. `inactive` — notification centre pulled down, Control
///     Centre, a Face ID or permission sheet — stops the clock at once too,
///     but only puts the card up if it lasts [coverAfter]: a glance at a
///     notification should not cost a tap to get back in, while a long one
///     must not leave a readable board behind a stopped clock.
///   - **Something is on top of the game.** Another route pushed over it (the
///     call screen, the give-up sheet, a standings card): same rule as
///     `inactive`, reported by the scaffold through [setCovered].
///   - **A call starts.** Any call, ringing or answered — the OS's or ours,
///     via [PhoneCallActivity]. This is the one the lifecycle never sees: a
///     call answered from iOS's compact banner, or ours answered and then
///     minimised, leaves the app `resumed` throughout, and the clock used to
///     time the whole conversation. The card goes up on the edge into the
///     call, not for its whole length — a player who taps back in while still
///     talking is playing, and is timed.
class GamePlayController extends ChangeNotifier with WidgetsBindingObserver {
  GamePlayController({
    required this.game,
    required this.userId,
    ValueListenable<bool>? calls,
    @visibleForTesting DateTime Function()? now,
  }) : _calls = calls ?? PhoneCallActivity.instance,
       _now = now ?? DateTime.now;

  /// The wall clock, swappable so a test can move time without waiting.
  final DateTime Function() _now;

  /// How long a soft interruption (an `inactive` app, a route on top) may
  /// last before the pause card goes up over the board.
  static const coverAfter = Duration(seconds: 2);

  final DailyGame game;
  final String userId;

  GamesApi get _api => GamesStore.instance.api;

  String get _dayKey => FeedStore.instance.dayKey;

  Duration _accumulated = Duration.zero;
  DateTime? _since;
  Timer? _tick;

  final ValueListenable<bool> _calls;
  bool _onCall = false;

  /// The app is `resumed`. Anything else holds the clock.
  bool _foreground = true;

  /// Another route is on top of the game's own.
  bool _covered = false;

  /// Puts the pause card up once a soft interruption has lasted [coverAfter].
  Timer? _coverTimer;

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
  /// the board is open, on top, in the foreground and unpaused.
  Duration get elapsed {
    final since = _since;
    if (since == null) return _accumulated;
    return _accumulated + _now().difference(since);
  }

  /// Claims a start time and restores any half-finished board.
  ///
  /// Idempotent on the server by existence, so returning to a board you walked
  /// away from does not reset its clock — otherwise a good time is farmable by
  /// backing out and coming straight back in.
  Future<void> begin() async {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (_calls == PhoneCallActivity.instance) {
      PhoneCallActivity.instance.ensureListening();
    }
    _onCall = _calls.value;
    _calls.addListener(_onCallsChanged);
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
        () => _api.reveal(
          userId: userId,
          dayKey: _dayKey,
          game: game,
          mistakes: _mistakes,
        ),
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

  /// The board as [checkpoint] wants it, read when the app goes to the
  /// background. Set by the screen; null saves nothing there.
  ///
  /// The screen's own `dispose` is the usual save, and an app killed from the
  /// background never runs it: everything since the board was opened was
  /// lost, and so was anything the save carries that the player would rather
  /// lose (a Minesweeper penalty, a counted mistake). Saving on the way into
  /// the background closes both.
  List<int> Function()? snapshot;
  bool _savedOut = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The clock follows the app, not just the screen: a stopwatch that kept
    // running in the background would be timing whatever took the player away.
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _savedOut = false;
        _interruptionEnded();
      case AppLifecycleState.inactive:
        _foreground = false;
        _interrupted(coverNow: false);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
        _interrupted(coverNow: true);
        // Once per trip out: `hidden` and `paused` arrive back to back.
        final snap = snapshot;
        if (!_savedOut && snap != null && _started) {
          _savedOut = true;
          checkpoint(snap());
        }
    }
  }

  /// Whether another route sits on top of the game's. Reported by the
  /// scaffold whenever its route stops or starts being the current one.
  ///
  /// Never notifies synchronously — the scaffold calls it from
  /// `didChangeDependencies`, mid-build.
  void setCovered(bool covered) {
    if (covered == _covered) return;
    _covered = covered;
    if (covered) {
      _interrupted(coverNow: false);
    } else {
      _interruptionEnded();
    }
  }

  void _onCallsChanged() {
    final now = _calls.value;
    final rising = now && !_onCall;
    _onCall = now;
    if (!rising) return;
    // Out of whatever notified us, which may be mid-build.
    scheduleMicrotask(() {
      if (_disposed || !_started || _finished || _finishing) return;
      pause();
    });
  }

  /// The board just went out of the player's reach. The clock stops now; the
  /// card goes up now too for a hard interruption, or after [coverAfter] for
  /// a soft one that is still going.
  void _interrupted({required bool coverNow}) {
    _hold();
    if (!_started || _finished || _finishing || _paused) return;
    if (coverNow) {
      _coverTimer?.cancel();
      _coverTimer = null;
      pause();
      return;
    }
    _coverTimer ??= Timer(coverAfter, () {
      _coverTimer = null;
      if (_disposed || _foreground && !_covered) return;
      pause();
    });
  }

  /// One interruption is over. The clock carries on by itself only if nothing
  /// else is still in the way and the card never went up; once it has, the
  /// player taps back in.
  void _interruptionEnded() {
    if (!_foreground || _covered) return;
    _coverTimer?.cancel();
    _coverTimer = null;
    if (!_paused && !_finished) _resume();
  }

  void _resume() {
    if (_since != null || _finished || _finishing || !_started) return;
    if (!_foreground || _covered) return;
    _since = _now();
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _hold() {
    final since = _since;
    if (since != null) _accumulated += _now().difference(since);
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
    _calls.removeListener(_onCallsChanged);
    _coverTimer?.cancel();
    _hold();
    super.dispose();
  }
}
