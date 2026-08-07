import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../backend/feed_api.dart';
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
  DateTime _serverNow = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loaded = false;
  Object? _error;

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
  PuzzleState get puzzle => _puzzle;

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
          _moments = board.moments;
          _puzzle = board.puzzle;
          _serverNow = board.serverNow;
          _loaded = true;
          _error = null;
          notifyListeners();
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
    _serverNow = DateTime.fromMillisecondsSinceEpoch(0);
    _loaded = false;
    _error = null;
    _introPlayedForDay = null;
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
      notifyListeners();
      // The board query is scoped to a dayKey ARGUMENT, so the live
      // subscription keeps serving yesterday until it is re-issued. Anyone who
      // leaves the app open overnight would otherwise wake to a frozen board
      // that looks like a sync failure.
      _rebindForNewDay();
    });
  }
}
