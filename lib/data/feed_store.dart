import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../backend/feed_api.dart';
import '../models/daily_game.dart';
import '../models/moment.dart';
import '../models/puzzle.dart';
import 'feed_day.dart';

/// Board state that must outlive the Feed tab's widget.
///
/// This is not an optional convenience — it is forced by the shell. `HomeShell`
/// wraps the active section in an `AnimatedSwitcher` keyed
/// `'${section.name}_${theme.id}'`, and `app.dart` keys the whole shell
/// `'home_${theme.id}'`. So switching tabs **or changing theme** fully disposes
/// `FeedScreen` and re-runs `initState`. Anything held in the screen's `State`
/// is gone: a "played the intro already" flag would replay the intro every time
/// you tapped away and back, and again on every theme switch.
///
/// So the rule for this board is: if losing it would be *visible*, it lives
/// here. Currently the day identity, the rollover timer and the once-per-day
/// intro latch. Phase 2 adds the unseen watermark and the cached digest.
///
/// A singleton in the shape of [SettingsStore] rather than something threaded
/// through constructors, because the nav badge in three separate chromes needs
/// to read it without the Feed tab being mounted at all.
class FeedStore extends ChangeNotifier {
  FeedStore._();
  static final FeedStore instance = FeedStore._();

  /// Injectable clock. Production reads the wall clock; tests drive the day
  /// boundary directly instead of waiting for midnight.
  ///
  /// Not a constructor argument because this is a singleton — the shell reads
  /// it before any test gets a chance to construct one.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  Timer? _rollover;
  String _dayKey = '';
  int _edition = 0;
  String? _introPlayedForDay;

  FeedApi? _api;
  String? _userId;
  Subscription? _board;

  /// Guards against a stale [attach] finishing after a newer one.
  ///
  /// Every `await` before a subscription handle is published needs one of
  /// these: without it a superseded attach wires the on-screen board to the
  /// wrong query, with nobody holding its cancel handle. `openRoom` has four
  /// of these checks for the same reason.
  int _attachGen = 0;

  List<Moment> _moments = const [];
  PuzzleState _puzzle = const PuzzleState();
  Map<DailyGame, GameResult> _games = const {};
  DateTime _serverNow = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loaded = false;
  Object? _error;

  /// What the viewer's own mutations reported, overlaid on top of the board
  /// payload until the subscription catches up.
  ///
  /// Not an optimisation. The board is ONE live query, and a subscription that
  /// has gone quiet — a socket the OS suspended, a bind that threw while the
  /// handshake was still in flight — takes the whole surface down with it. Both
  /// of these writes are confirmed by the server before they land here, so
  /// without the overlay a player watches an accepted guess vanish: the screen
  /// clears its draft, the board still shows the pre-guess attempt, and the
  /// only cure is a restart. [GamesStore.noteFinished] has carried the same
  /// overlay for the hub since it shipped; the Feed's own surfaces did not.
  ///
  /// Day-stamped rather than cleared on a timer, so the midnight rollover drops
  /// them for free: neither is [_dayKey]'s any more the moment the day turns.
  PuzzleAttempt? _localAttempt;
  String _localAttemptDay = '';

  /// The day the viewer told friends about their code, ahead of the board
  /// catching up with it. Day-stamped like the two above. See
  /// [markPuzzleShared].
  String _puzzleSharedDay = '';
  Map<DailyGame, GameResult> _localGames = const {};
  String _localGamesDay = '';

  /// Today's moments — the viewer's own plus every friend's that is still
  /// live — newest first. An unmodifiable view; resolve it once per build.
  List<Moment> get moments => List.unmodifiable(_moments);

  /// The server's clock as of the last board payload.
  ///
  /// Expiry and the decay overlay are judged against this rather than
  /// `DateTime.now()`, so a device running a few minutes fast cannot fade out a
  /// card the server still considers live.
  DateTime get serverNow => _serverNow;

  /// False until the first payload lands. Distinct from "loaded and empty",
  /// which is what lets the board show a real empty state rather than a
  /// spinner that never resolves for someone with no friends.
  bool get loaded => _loaded;

  Object? get error => _error;

  /// Moments from friends the viewer has not opened yet — the rail's unseen
  /// ring, and the count on the Feed tab's nav badge.
  int get unseenCount => _moments.where((m) => !m.mine && !m.seen).length;

  /// Untagged moments — the HIGHLIGHTS rail. Photos and videos worth showing.
  ///
  /// Split from [points] because these are two different things to a person
  /// even though they are one row in the database. A highlight is something you
  /// saw; a point is something that happened to you. Mixing them into one rail
  /// made the photos carry the scoring and the scores need a photo, and neither
  /// is true.
  List<Moment> get highlights =>
      List.unmodifiable(_moments.where((m) => m.tag == null));

  /// Tagged moments — the POINTS board. Usually just a line of text.
  List<Moment> get points =>
      List.unmodifiable(_moments.where((m) => m.tag != null));

  /// Per-author, per-tag totals for today, highest first.
  List<MomentTally> get tallies => MomentTally.from(_moments);

  /// Today's puzzle — the viewer's attempt and everyone who has finished.
  ///
  /// The viewer's own row comes from whichever source is further along. Guesses
  /// only ever grow within a day, so "more guesses wins" needs no sequencing:
  /// a board payload computed before the guess cannot roll the row back, and
  /// the moment the real one lands it takes over — it carries the revealed
  /// answer and the scoreboard, which a mutation reply never does.
  PuzzleState get puzzle {
    final state = _mergedPuzzle();
    final mine = state.mine;
    if (_puzzleSharedDay != _dayKey || mine == null || mine.shared) {
      return state;
    }
    return PuzzleState(mine: mine.markShared(), scores: state.scores);
  }

  PuzzleState _mergedPuzzle() {
    final local = _localAttemptDay == _dayKey ? _localAttempt : null;
    if (local == null) return _puzzle;
    final server = _puzzle.mine;
    if (server != null && server.guesses.length >= local.guesses.length) {
      return _puzzle;
    }
    return PuzzleState(mine: local, scores: _puzzle.scores);
  }

  /// Marks today's code as told to friends, the moment the server accepted it.
  ///
  /// The board subscription carries `shared` too and would catch up by itself;
  /// this only closes the beat in between, where TELL FRIENDS would otherwise
  /// sit there still offering a send the server now refuses.
  void markPuzzleShared() {
    if (_puzzleSharedDay == _dayKey) return;
    _puzzleSharedDay = _dayKey;
    notifyListeners();
  }

  /// How the viewer is doing on each daily game today.
  ///
  /// The viewer's own rows only — friends' times are one-shot fetched by
  /// [GamesStore] when the hub opens, rather than fanned out on every board
  /// render. An absent game has not been opened today.
  Map<DailyGame, GameResult> get games =>
      _localGamesDay == _dayKey && _localGames.isNotEmpty
      ? {..._games, ..._localGames}
      : _games;

  /// How many of today's games are still untouched, for the Feed band's
  /// "3 left" line and the nav badge.
  int get gamesLeft {
    final merged = games;
    return DailyGame.values
        .where((g) => !(merged[g]?.finished ?? false))
        .length;
  }

  /// Identity of the local calendar day the board is currently showing.
  String get dayKey => _dayKey;

  /// The masthead's edition number — local days since the Feed's epoch.
  int get edition => _edition;

  /// Whether the once-per-day masthead intro has already run.
  ///
  /// Keyed by day rather than a bare bool so the intro returns tomorrow — the
  /// whole conceit is that a new edition is published each morning, and an
  /// intro that only ever plays once makes the second day feel like the app
  /// forgot. Latching by day also means it survives the tab switch and theme
  /// change that dispose the screen.
  bool get introPlayed => _introPlayedForDay == _dayKey;

  /// Called by the board once its intro animation has been started. Idempotent.
  void markIntroPlayed() {
    if (introPlayed) return;
    _introPlayedForDay = _dayKey;
    // Deliberately silent. Notifying here would rebuild the board mid-intro and
    // restart the very animation this is recording.
  }

  /// Folds the attempt a `puzzle:guess` mutation just returned into the board.
  ///
  /// Call this with the mutation's own reply, not a guess assembled on the
  /// client: the reply is the server's authoritative attempt, feedback pegs and
  /// all, so the row it draws is the real one rather than a hopeful placeholder
  /// that could disagree with the scoreboard underneath it.
  void applyPuzzleAttempt(PuzzleAttempt attempt) {
    _localAttempt = attempt;
    _localAttemptDay = _dayKey;
    notifyListeners();
  }

  /// Folds one finished daily game into the board, so the Feed band and the nav
  /// badge stop counting it as unplayed without waiting for the subscription.
  ///
  /// The mirror of [GamesStore.noteFinished], which does this for the hub. A
  /// game never un-finishes within a day, so overlaying is safe in the one
  /// direction it can move.
  void noteGameFinished(DailyGame game, GameResult result) {
    _localGames = {
      ...(_localGamesDay == _dayKey ? _localGames : const {}),
      game: result,
    };
    _localGamesDay = _dayKey;
    notifyListeners();
  }

  /// Begins tracking the day boundary. Idempotent — the shell may call this
  /// from more than one place as sections mount.
  void start() {
    if (_rollover != null) return;
    _syncDay();
    _scheduleRollover();
  }

  /// Stops the rollover timer. Must be called on sign-out and in `tearDown` —
  /// a live `Timer` left behind fails widget tests with "A Timer is still
  /// pending even after the widget tree was disposed".
  void stop() {
    _rollover?.cancel();
    _rollover = null;
  }

  /// Opens the board subscription for [userId].
  ///
  /// Called from `app.dart` when a session exists, NOT from the Feed screen:
  /// the shell disposes and rebuilds that screen on every tab switch and every
  /// theme change, and a subscription opened there would be torn down and
  /// re-established each time. It also has to stay live while the user is on
  /// another tab, or the nav badge could never light.
  Future<void> attach(FeedApi api, String userId) async {
    if (_api == api && _userId == userId && _board != null) return;
    final gen = ++_attachGen;
    await detach();
    if (gen != _attachGen) return;

    _api = api;
    _userId = userId;
    start();

    try {
      final sub = await api.subscribeBoard(
        userId: userId,
        dayKey: _dayKey,
        onData: (board) {
          // A payload from a superseded subscription must not overwrite the
          // current one's state.
          if (gen != _attachGen) return;
          applyBoard(board);
        },
        onError: (e) {
          if (gen != _attachGen) return;
          _error = e;
          // Deliberately does NOT clear `_moments`. A transient socket error
          // should leave the last good board on screen rather than blanking it
          // — the reconnect path will refresh it within seconds.
          notifyListeners();
        },
      );
      if (gen != _attachGen) {
        // A newer attach landed while this one was awaiting. Cancel the handle
        // we just created; nothing else holds it.
        sub.cancel();
        return;
      }
      _board = sub;
    } catch (e) {
      if (gen != _attachGen) return;
      _error = e;
      notifyListeners();
    }
  }

  /// Folds one board payload in. The subscription's only job.
  ///
  /// Public and [visibleForTesting] rather than private because the overlays
  /// above only mean anything against a board that is arriving — or, in the bug
  /// they exist for, NOT arriving. A test that could not deliver a payload
  /// could only ever assert half of the behaviour.
  @visibleForTesting
  void applyBoard(FeedBoard board) {
    _moments = board.moments;
    _puzzle = board.puzzle;
    _games = board.games;
    _serverNow = board.serverNow;
    _loaded = true;
    _error = null;
    notifyListeners();
  }

  /// Tears the board down on sign-out.
  ///
  /// Clears the cached moments too: they are another account's data and must
  /// not flash on screen for whoever signs in next on a shared handset.
  Future<void> detach() async {
    _board?.cancel();
    _board = null;
    _api = null;
    _userId = null;
    _moments = const [];
    _puzzle = const PuzzleState();
    _games = const {};
    _serverNow = DateTime.fromMillisecondsSinceEpoch(0);
    _loaded = false;
    _error = null;
    _introPlayedForDay = null;
    // The overlays are day-stamped, not user-stamped, so signing out on a
    // shared handset would otherwise show the next account today's guesses.
    _localAttempt = null;
    _localAttemptDay = '';
    _puzzleSharedDay = '';
    _localGames = const {};
    _localGamesDay = '';
    stop();
  }

  /// Re-subscribes at the new day boundary.
  ///
  /// The board query is scoped to a `dayKey` argument, so a live subscription
  /// keeps serving yesterday forever unless it is re-issued. Without this the
  /// board would silently freeze at midnight for anyone who left the app open.
  Future<void> _rebindForNewDay() async {
    final api = _api;
    final userId = _userId;
    if (api == null || userId == null) return;
    _api = null; // force attach() past its identity early-return
    await attach(api, userId);
  }

  @override
  void dispose() {
    _board?.cancel();
    _board = null;
    stop();
    super.dispose();
  }

  /// Called after the local day has actually turned over.
  ///
  /// Installed by app.dart, and kept as a hook rather than a direct call
  /// because this is the data layer: what needs to know that midnight passed
  /// (currently the push registry, which re-reads this device's UTC offset —
  /// a daylight-saving shift happens at 3am and would otherwise go unnoticed
  /// until the next resume) is not this file's business to name.
  VoidCallback? onDayRollover;

  void _syncDay() {
    final now = clock();
    _dayKey = dayKeyOf(now);
    _edition = editionNumber(now);
  }

  /// Arms a single timer for the next local midnight rather than polling.
  ///
  /// Re-arms from the *new* now on each fire, so the schedule cannot drift and
  /// so DST transitions are picked up from the real clock rather than
  /// accumulated from a fixed 24h stride.
  void _scheduleRollover() {
    _rollover?.cancel();
    _rollover = Timer(untilNextDay(clock()), () {
      final previous = _dayKey;
      _syncDay();
      _scheduleRollover();
      // Guard against a spurious early fire (a clock adjustment can land the
      // timer a hair before midnight). Without it the board would flash a
      // rebuild for no reason and, worse, re-run the day's intro.
      if (_dayKey == previous) return;
      onDayRollover?.call();
      notifyListeners();
      // The board query is scoped to a dayKey ARGUMENT, so the live
      // subscription keeps serving yesterday until it is re-issued. Anyone who
      // leaves the app open overnight would otherwise wake to a frozen board
      // that looks like a sync failure.
      _rebindForNewDay();
    });
  }
}
