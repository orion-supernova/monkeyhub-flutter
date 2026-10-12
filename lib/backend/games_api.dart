import '../models/daily_game.dart';
import '../models/game_record.dart';
import 'convex_client.dart';

/// Every Convex call the daily games make.
///
/// A facade beside [FeedApi] for the same reason that one sits beside
/// [ChatApi]: the games are a self-contained surface with their own backend
/// module, and decoding here means no screen ever handles a raw map.
///
/// **Nothing in here subscribes.** That is the point. This app runs ~15 live
/// queries and the codebase has repeatedly turned down new ones; a daily
/// leaderboard refreshed when the hub opens and again when someone finishes is
/// indistinguishable from a live one, at zero standing cost. The board tiles on
/// the Feed ride along in the board payload that was already being delivered.
class GamesApi {
  GamesApi(this._cv);
  final ConvexBackend _cv;

  /// Today's four boards.
  ///
  /// [dayKey] must be the VIEWER's local day, for the same reason the Feed
  /// board takes one: the server has no idea what zone the phone is in, and
  /// assuming UTC hands everyone west of Greenwich yesterday's games all
  /// evening.
  ///
  /// Server-side this reads no table at all — the boards are a pure function of
  /// the day key — so it is about as cheap as a network call gets.
  Future<DailyBoards> daily({required String dayKey}) async =>
      DailyBoards.fromJson(await dailyRaw(dayKey: dayKey));

  /// The same call, undecoded.
  ///
  /// Exists so the store can put the payload on disk verbatim. Caching the
  /// parsed [DailyBoards] instead would mean a `toJson` on all five board
  /// classes whose only reader is the cache, and a new field on a board would
  /// then be a backend change plus a serialiser nobody thinks to update — it
  /// would go missing on relaunch and nowhere else.
  Future<dynamic> dailyRaw({required String dayKey}) =>
      _cv.query('games:daily', {'dayKey': dayKey});

  /// The viewer's own rows, any half-finished board, and a leaderboard per game
  /// over accepted friends.
  Future<GameStandings> standings({
    required String userId,
    required String dayKey,
  }) async {
    final res = await _cv.query('games:standings', {
      'userId': userId,
      'dayKey': dayKey,
    });
    return GameStandings.fromJson(res);
  }

  /// Starts the clock, or returns the clock that is already running.
  ///
  /// Idempotent on the server by existence rather than a flag, so reopening a
  /// board you walked away from does not reset its start — otherwise a good
  /// time is farmable by backing out and coming straight back in.
  Future<GameSession> start({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async {
    final res = await _cv.mutation('games:start', {
      'userId': userId,
      'dayKey': dayKey,
      'game': game.wire,
    });
    final j = (res as Map).cast<String, dynamic>();
    return GameSession(
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['startedAt'] as num?)?.toInt() ?? 0,
      ),
      progress: [
        for (final v in (j['progress'] as List?) ?? const []) (v as num).toInt(),
      ],
      elapsedMs: (j['elapsedMs'] as num?)?.toInt() ?? 0,
      hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
      mistakes: (j['mistakes'] as num?)?.toInt() ?? 0,
      finished: j['finished'] == true,
    );
  }

  /// Stores a half-finished board.
  ///
  /// Called when the player leaves the screen, never per move — a mutation per
  /// tap on a grid you tap sixty times would be the chattiest thing in the app.
  /// Failures are swallowed by the caller on purpose: losing an autosave is a
  /// disappointment, and an error toast on the way out of a screen is worse.
  Future<void> saveProgress({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> progress,
    required int elapsedMs,
    int mistakes = 0,
  }) async {
    await _cv.mutation('games:saveProgress', {
      'userId': userId,
      'dayKey': dayKey,
      'game': game.wire,
      'progress': progress,
      'elapsedMs': elapsedMs,
      'mistakes': mistakes,
    });
  }

  /// Reveals one correct cell of [board] and counts it against the player.
  ///
  /// [board] is in the same shape [submit] takes for most games: a column per
  /// row for Queens — so [GameHint.index] is a ROW there — and a value per
  /// cell for Tango, Sudoku, Futoshiki and Star Battle. Three send their
  /// working state instead, because that is what the hint reasons from:
  /// Nonogram its fill/cross/unknown grid, Minesweeper its open/flag/hidden
  /// grid (the hint is the next square that can be PROVED from it), and Flow
  /// its pipes laid end to end, which comes back as a whole pipe in
  /// [GameHint.cells].
  ///
  /// Throws `NO_HINT` for Zip, which has no single next-correct move to point
  /// at: any route covering every cell in order wins, so the only thing the
  /// server could steer someone onto is the route it happened to generate,
  /// discarding whatever legal line they had already drawn.
  ///
  /// [seq] is how many hints the player has already been given. A hint the
  /// native client resends after a reconnect — it keeps every sent mutation in
  /// flight, however long ago this side timed it out — names a number the
  /// server has already counted past, and is answered without being charged
  /// again.
  Future<GameHint> hint({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> board,
    required int seq,
  }) async {
    final res = await _cv.mutation('games:hint', {
      'userId': userId,
      'dayKey': dayKey,
      'game': game.wire,
      'board': board,
      'seq': seq,
    });
    final j = (res as Map).cast<String, dynamic>();
    return GameHint(
      index: (j['index'] as num?)?.toInt() ?? -1,
      value: (j['value'] as num?)?.toInt() ?? 0,
      cells: [
        for (final c in (j['cells'] as List?) ?? const []) (c as num).toInt(),
      ],
    );
  }

  /// Submits a finished board.
  ///
  /// The server re-validates the grid against the same generator it came from,
  /// so [solved] in the reply is a verdict rather than an echo. [elapsedMs] is
  /// what the client measured and the server clamps it to the window since
  /// `start` — see `submit` in backend/convex/games.ts for why a stopwatch that
  /// stops when you put the phone down is the right trade here.
  ///
  /// Throws `NOT_STARTED` if no clock is running and `NOT_SOLVED` if the grid
  /// does not actually finish the board.
  Future<GameOutcome> submit({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> solution,
    required int elapsedMs,
    int hintsUsed = 0,
    int mistakes = 0,
  }) async {
    final res = await _cv.mutation('games:submit', {
      'userId': userId,
      'dayKey': dayKey,
      'game': game.wire,
      'solution': solution,
      'elapsedMs': elapsedMs,
      'hintsUsed': hintsUsed,
      'mistakes': mistakes,
    });
    final j = (res as Map).cast<String, dynamic>();
    return GameOutcome(
      solved: j['solved'] == true,
      durationMs: (j['durationMs'] as num?)?.toInt(),
      replay: j['replay'] == true,
    );
  }

  /// Pushes a finished result to the player's friends.
  ///
  /// Reached only from the "tell friends" action on the result card — this is
  /// the one notification in the app a person deliberately sends about
  /// themselves, and nothing calls it automatically.
  ///
  /// Throws `ALREADY_SHARED` if this result has been sent once already (the
  /// server remembers, so a reinstall does not re-notify everyone),
  /// `NOT_FINISHED` for a board still in progress, and `RESULT_PRIVATE` when
  /// the player's own daily-score visibility is set to nobody — their friends
  /// could not see the standings the notification opens.
  Future<void> shareResult({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async {
    await _cv.mutation('games:shareResult', {
      'userId': userId,
      'dayKey': dayKey,
      'game': game.wire,
    });
  }

  /// Everyone's all-time bests — the viewer's and their friends' — per game,
  /// with the reactions on each. One-shot, like [standings]; see
  /// `records.ts` for why it is not a subscription.
  Future<RecordBoard> recordBoard({required String userId}) async {
    final res = await _cv.query('records:board', {'userId': userId});
    return RecordBoard.fromJson(res);
  }

  /// Reacts to a friend's record, or swaps the reaction already on it.
  ///
  /// Throws `OWN_RECORD`, `NOT_FRIENDS`, `RECORD_PRIVATE` or `BAD_REACTION`
  /// for the cases the server refuses — none of which the UI offers.
  Future<void> reactToRecord({
    required String userId,
    required String recordId,
    required String emoji,
  }) async {
    await _cv.mutation('records:react', {
      'userId': userId,
      'recordId': recordId,
      'emoji': emoji,
    });
  }

  /// Takes the viewer's reaction off a record. Absent is not an error.
  Future<void> unreactToRecord({
    required String userId,
    required String recordId,
  }) async {
    await _cv.mutation('records:unreact', {
      'userId': userId,
      'recordId': recordId,
    });
  }

  /// Gives up and returns the answer.
  ///
  /// Recorded as a result, not left blank — and it closes the board, so the
  /// answer cannot then be handed back as a solve.
  Future<List<int>> reveal({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async {
    final res = await _cv.mutation('games:reveal', {
      'userId': userId,
      'dayKey': dayKey,
      'game': game.wire,
    });
    final j = (res as Map).cast<String, dynamic>();
    return [
      for (final v in (j['answer'] as List?) ?? const []) (v as num).toInt(),
    ];
  }
}

/// A running clock on one board.
class GameSession {
  const GameSession({
    required this.startedAt,
    required this.progress,
    required this.elapsedMs,
    required this.hintsUsed,
    required this.mistakes,
    required this.finished,
  });

  /// The server's clock when the player first opened this board. The ceiling on
  /// any time they can report.
  final DateTime startedAt;

  /// The board as they left it, empty if they have not played it yet.
  final List<int> progress;

  /// The stopwatch as it stood when they last left. Restored rather than reset,
  /// or backing out of a board four minutes in would hand back a better time
  /// than sitting still and finishing it.
  final int elapsedMs;

  final int hintsUsed;
  final int mistakes;

  /// Whether they have already finished it today.
  final bool finished;
}

/// One revealed cell.
class GameHint {
  const GameHint({
    required this.index,
    required this.value,
    this.cells = const [],
  });

  /// Cell to fill — or, in Queens, the ROW whose crown belongs at [value], and
  /// in Flow the COLOUR whose pipe is [cells]. `-1` when there was nothing left
  /// to reveal.
  final int index;

  final int value;

  /// A whole stretch of the answer at once, dot to dot. Only Flow sends one:
  /// its natural unit of help is a pipe, since "this square is red" still
  /// leaves the player to find the route through it. Empty for every other
  /// game.
  final List<int> cells;

  bool get isEmpty => index < 0;
}

/// What `submit` decided.
class GameOutcome {
  const GameOutcome({
    required this.solved,
    required this.durationMs,
    required this.replay,
  });

  final bool solved;
  final int? durationMs;

  /// True when the board was already finished — a retried call after a flaky
  /// socket, answered with the stored result rather than a new one.
  final bool replay;
}
