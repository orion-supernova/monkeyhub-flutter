import 'daily_game.dart';
import 'puzzle.dart';

/// One finished daily result, as the Feed's Activity list shows it.
///
/// Covers all five dailies: the four timed games, and the symbol-code puzzle,
/// whose result is a guess count rather than a time. Only FINISHED results
/// exist here. An unfinished board never leaves its owner's device (see
/// `feed.board`), so a friend nine minutes into Queens is not an event.
class GamePlay {
  const GamePlay({
    required this.userId,
    required this.name,
    required this.game,
    required this.solved,
    required this.result,
    required this.finishedAt,
    this.durationMs,
    this.mistakes = 0,
    this.hintsUsed = 0,
  });

  final String userId;

  /// Empty for the viewer's own row, as on every scoreboard.
  final String name;

  /// Null is the symbol-code puzzle, matching `kLeaderboardGames`.
  final DailyGame? game;

  final bool solved;

  /// The score as a scoreboard prints it: a stopwatch reading for the timed
  /// games, `3/6` for the code. Digits only, so it needs no localizing.
  final String result;

  final DateTime finishedAt;

  /// The solve time, for ranking. Null for the code and for a surrender.
  final int? durationMs;

  /// Advisory, never ranked on: shown beside the result the way the
  /// leaderboard and the result sheet show them. Always 0 for the code, whose
  /// guesses are its whole score.
  final int mistakes;
  final int hintsUsed;

  /// Stable across board refreshes, so the Activity row keeps its identity.
  String get id => '${game?.wire ?? 'code'}_$userId';

  /// A finished timed game, or null for a game this build does not know.
  static GamePlay? fromJson(Map<String, dynamic> j) {
    final game = DailyGame.parse(j['game']?.toString());
    if (game == null) return null;
    final solved = j['solved'] == true;
    final durationMs = (j['durationMs'] as num?)?.toInt();
    return GamePlay(
      userId: j['userId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      game: game,
      solved: solved,
      result: solved ? formatGameTime(durationMs) : '',
      finishedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['finishedAt'] as num?)?.toInt() ?? 0,
      ),
      durationMs: durationMs,
      // Absent from a server older than the field: read as a clean run.
      mistakes: (j['mistakes'] as num?)?.toInt() ?? 0,
      hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
    );
  }

  /// A finished symbol-code attempt from the puzzle scoreboard.
  static GamePlay fromPuzzle(PuzzleScore s) => GamePlay(
    userId: s.userId,
    name: s.name,
    game: null,
    solved: s.solved,
    result: '${s.solved ? s.guessCount : 'X'}/$kPuzzleMaxGuesses',
    finishedAt: s.finishedAt,
  );
}
