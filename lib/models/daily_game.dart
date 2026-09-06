/// The daily games' client-side models.
///
/// Four boards a day — Queens, Tango, Zip and Mini Sudoku — generated on the
/// server from the day key alone, so everyone in every locale plays the
/// identical board and the standings compare something real.
///
/// **Why these four.** They contain no words. `backend/convex/games.ts` and
/// `models/puzzle.dart` both spell out the argument at length: this app ships
/// in twelve languages, and LinkedIn's word games (Crossclimb, Pinpoint) would
/// need a curated answer list per locale, which puts friends on different app
/// languages in front of different puzzles and quietly makes the shared
/// scoreboard meaningless. A crown, a sun, a line and the digits 1-6 read the
/// same everywhere.
///
/// Nothing here holds a solution. The server validates a finished board and the
/// client only ever mirrors the *rules* (see `lib/games/game_rules.dart`), so
/// what the device knows is what a player could work out anyway.
library;

/// The games that exist. Wire names mirror `GAMES` in backend/convex/games.ts.
enum DailyGame {
  queens,
  tango,
  zip,
  sudoku;

  String get wire => name;

  static DailyGame? parse(String? s) {
    for (final g in DailyGame.values) {
      if (g.wire == s) return g;
    }
    return null;
  }
}

/// QUEENS — one crown per row, per column and per colour region, none touching.
class QueensBoard {
  const QueensBoard({required this.size, required this.regions});

  final int size;

  /// Region index per cell, row-major. Values are `0..size-1`.
  final List<int> regions;

  static const empty = QueensBoard(size: 0, regions: []);

  bool get isEmpty => size == 0;

  static QueensBoard fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return QueensBoard(
      size: (j['size'] as num?)?.toInt() ?? 0,
      regions: _ints(j['regions']),
    );
  }
}

/// One `=` or `×` printed between two orthogonally adjacent Tango cells.
class TangoSign {
  const TangoSign({required this.a, required this.b, required this.eq});

  /// Cell index, row-major. Always the smaller of the pair.
  final int a;

  /// The cell to the right of, or below, [a].
  final int b;

  /// `=` when true, `×` when false.
  final bool eq;

  /// Whether the pair sits side by side rather than one above the other. The
  /// operator is drawn on the edge between them, so this decides which edge.
  bool horizontal(int size) => b == a + 1;

  static TangoSign fromJson(Map<String, dynamic> j) => TangoSign(
    a: (j['a'] as num?)?.toInt() ?? 0,
    b: (j['b'] as num?)?.toInt() ?? 0,
    eq: j['eq'] == true,
  );
}

/// TANGO — fill the grid with two symbols, three of each per line, never three
/// in a row, honouring every `=` and `×`.
class TangoBoard {
  const TangoBoard({
    required this.size,
    required this.givens,
    required this.signs,
  });

  final int size;

  /// [tangoEmpty], [tangoSun] or [tangoMoon] per cell, row-major.
  final List<int> givens;

  final List<TangoSign> signs;

  static const empty = TangoBoard(size: 0, givens: [], signs: []);

  bool get isEmpty => size == 0;

  static TangoBoard fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return TangoBoard(
      size: (j['size'] as num?)?.toInt() ?? 0,
      givens: _ints(j['givens']),
      signs: [
        for (final s in (j['signs'] as List?) ?? const [])
          TangoSign.fromJson((s as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// Tango cell values. Mirrors `SUN`/`MOON`/`EMPTY` in backend/convex/games/tango.ts.
const int tangoSun = 0;
const int tangoMoon = 1;
const int tangoEmpty = -1;

/// ZIP — one line from ① to the last dot, through every cell, in order.
class ZipBoard {
  const ZipBoard({required this.size, required this.checkpoints});

  final int size;

  /// Cell index of each numbered dot, ① first.
  final List<int> checkpoints;

  static const empty = ZipBoard(size: 0, checkpoints: []);

  bool get isEmpty => size == 0;

  static ZipBoard fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return ZipBoard(
      size: (j['size'] as num?)?.toInt() ?? 0,
      checkpoints: _ints(j['checkpoints']),
    );
  }
}

/// MINI SUDOKU — the digits 1-6, once per row, column and 2×3 box.
class SudokuBoard {
  const SudokuBoard({required this.size, required this.givens});

  final int size;

  /// [sudokuEmpty] or `1..size` per cell, row-major.
  final List<int> givens;

  /// Box shape. Mirrors `BOX_ROWS`/`BOX_COLS` in backend/convex/games/sudoku.ts.
  static const boxRows = 2;
  static const boxCols = 3;

  static const empty = SudokuBoard(size: 0, givens: []);

  bool get isEmpty => size == 0;

  static SudokuBoard fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return SudokuBoard(
      size: (j['size'] as num?)?.toInt() ?? 0,
      givens: _ints(j['givens']),
    );
  }
}

/// Sudoku's blank. Mirrors `EMPTY` in backend/convex/games/sudoku.ts.
const int sudokuEmpty = 0;

/// Every board for one day.
class DailyBoards {
  const DailyBoards({
    this.dayKey = '',
    this.queens = QueensBoard.empty,
    this.tango = TangoBoard.empty,
    this.zip = ZipBoard.empty,
    this.sudoku = SudokuBoard.empty,
  });

  final String dayKey;
  final QueensBoard queens;
  final TangoBoard tango;
  final ZipBoard zip;
  final SudokuBoard sudoku;

  /// Whether every board arrived. The hub waits on this rather than on a
  /// separate loading flag, so a partial payload cannot render as a set of
  /// empty grids that look playable.
  bool get ready =>
      !queens.isEmpty && !tango.isEmpty && !zip.isEmpty && !sudoku.isEmpty;

  static DailyBoards fromJson(dynamic raw) {
    if (raw is! Map) return const DailyBoards();
    final j = raw.cast<String, dynamic>();
    return DailyBoards(
      dayKey: j['dayKey']?.toString() ?? '',
      queens: QueensBoard.fromJson((j['queens'] as Map?)?.cast<String, dynamic>()),
      tango: TangoBoard.fromJson((j['tango'] as Map?)?.cast<String, dynamic>()),
      zip: ZipBoard.fromJson((j['zip'] as Map?)?.cast<String, dynamic>()),
      sudoku: SudokuBoard.fromJson((j['sudoku'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

/// One player's outcome on one game today.
class GameResult {
  const GameResult({
    required this.game,
    required this.solved,
    required this.gaveUp,
    required this.finished,
    this.durationMs,
    this.hintsUsed = 0,
    this.mistakes = 0,
    this.userId = '',
    this.name = '',
    this.shared = false,
  });

  final DailyGame game;
  final bool solved;

  /// Asked for the answer. Distinct from an unfinished board, which nobody but
  /// its owner ever sees — a surrender is a result and the standings show it,
  /// the way an unsolved daily puzzle shows as X/6.
  final bool gaveUp;

  /// Whether the player can still act on this board today.
  final bool finished;

  /// How long the solve took. Null unless [solved].
  final int? durationMs;

  final int hintsUsed;
  final int mistakes;

  /// Only populated on a standings row, never on the viewer's own summary.
  final String userId;

  /// Empty for the viewer's own row — the UI shows the localized word for
  /// "you" there rather than echoing the player their own name.
  final String name;

  /// Whether this result has already been pushed to the player's friends.
  ///
  /// Only ever true on the viewer's OWN row: the backend puts it on `mine` and
  /// deliberately not on the standings rows, because whether somebody pressed
  /// "tell friends" is a fact about their notification habits and not about the
  /// board. Its one job is to stop the result card offering an action the
  /// server would now refuse with `ALREADY_SHARED`.
  final bool shared;

  static GameResult? fromJson(Map<String, dynamic>? j, {DailyGame? game}) {
    if (j == null) return null;
    final id = game ?? DailyGame.parse(j['game']?.toString());
    if (id == null) return null;
    return GameResult(
      game: id,
      solved: j['solved'] == true,
      gaveUp: j['gaveUp'] == true,
      finished: j['finished'] == true || j['finishedAt'] != null,
      durationMs: (j['durationMs'] as num?)?.toInt(),
      hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
      mistakes: (j['mistakes'] as num?)?.toInt() ?? 0,
      userId: j['userId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      shared: j['shared'] == true,
    );
  }
}

/// The viewer's own progress plus a leaderboard per game.
class GameStandings {
  const GameStandings({
    this.mine = const {},
    this.progress = const {},
    this.boards = const {},
  });

  /// The viewer's row per game, whether or not it is finished.
  final Map<DailyGame, GameResult> mine;

  /// A half-finished board, kept so closing the app does not throw it away.
  final Map<DailyGame, List<int>> progress;

  /// Everyone who has FINISHED, best first. Unfinished boards are absent by
  /// design — knowing a friend is nine minutes into Queens and still going
  /// leaks how hard today is, and a live counter turns a quiet daily into a
  /// race.
  final Map<DailyGame, List<GameResult>> boards;

  /// Where the viewer placed on [game], 1-based, or null if unfinished.
  int? rankOf(DailyGame game, String userId) {
    final rows = boards[game];
    if (rows == null) return null;
    final i = rows.indexWhere((r) => r.userId == userId);
    return i < 0 ? null : i + 1;
  }

  static GameStandings fromJson(dynamic raw) {
    if (raw is! Map) return const GameStandings();
    final j = raw.cast<String, dynamic>();

    final mine = <DailyGame, GameResult>{};
    for (final e in ((j['mine'] as Map?) ?? const {}).entries) {
      final game = DailyGame.parse(e.key.toString());
      final row = GameResult.fromJson(
        (e.value as Map?)?.cast<String, dynamic>(),
        game: game,
      );
      if (game != null && row != null) mine[game] = row;
    }

    final progress = <DailyGame, List<int>>{};
    for (final e in ((j['progress'] as Map?) ?? const {}).entries) {
      final game = DailyGame.parse(e.key.toString());
      if (game != null) progress[game] = _ints(e.value);
    }

    final boards = <DailyGame, List<GameResult>>{};
    for (final e in ((j['boards'] as Map?) ?? const {}).entries) {
      final game = DailyGame.parse(e.key.toString());
      if (game == null) continue;
      boards[game] = [
        for (final r in (e.value as List?) ?? const [])
          ?GameResult.fromJson((r as Map).cast<String, dynamic>(), game: game),
      ];
    }

    return GameStandings(mine: mine, progress: progress, boards: boards);
  }
}

/// A stopwatch reading, as `m:ss` or `h:mm:ss`.
///
/// Deliberately not localized. Digits and colons are what a stopwatch looks
/// like in every locale this app ships in, and routing it through
/// `NumberFormat` would render Arabic-Indic digits in one language and Latin in
/// the next — on a leaderboard where the whole point is comparing the numbers
/// side by side.
String formatGameTime(int? ms) {
  if (ms == null) return '—';
  final total = ms ~/ 1000;
  final seconds = (total % 60).toString().padLeft(2, '0');
  final minutes = total ~/ 60;
  if (minutes < 60) return '$minutes:$seconds';
  final mm = (minutes % 60).toString().padLeft(2, '0');
  return '${minutes ~/ 60}:$mm:$seconds';
}

List<int> _ints(dynamic raw) => [
  for (final v in (raw as List?) ?? const []) (v as num).toInt(),
];
