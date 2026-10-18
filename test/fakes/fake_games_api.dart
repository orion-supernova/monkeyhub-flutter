import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_record.dart';

/// Answers every call instantly with today's real boards and nobody's times.
///
/// Holds the wire payload rather than the decoded boards: the store reads the
/// raw one so it has something to put on disk, and a stub that only knew how to
/// answer the decoded call would pass while the cached path went untested.
class FakeGamesApi implements GamesApi {
  FakeGamesApi(
    this.payload, {
    this.standingsAnswer = const GameStandings(),
    this.progress = const {},
    this.hintAnswer = const GameHint(index: -1, value: 0),
  });

  final Map<String, dynamic> payload;

  /// A half-finished board per game, handed back by [start] as if the player
  /// had left it there — for renders and tests of a board mid-solve.
  final Map<DailyGame, List<int>> progress;

  /// What [hint] answers. Nothing to reveal unless a test says otherwise.
  final GameHint hintAnswer;

  /// Every board [hint] was sent, in order, so a test can check the shape a
  /// game asks for help in.
  final List<List<int>> hintBoards = [];

  /// What [standings] answers — nobody's times unless a test hands it a
  /// board (the leaderboard renders and tests do).
  final GameStandings standingsAnswer;

  @override
  Future<DailyBoards> daily({required String dayKey}) async =>
      DailyBoards.fromJson(payload);

  @override
  Future<dynamic> dailyRaw({required String dayKey}) async => payload;

  @override
  Future<GameStandings> standings({
    required String userId,
    required String dayKey,
  }) async => standingsAnswer;

  @override
  Future<GameSession> start({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async => GameSession(
    startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    progress: progress[game] ?? const [],
    elapsedMs: 0,
    hintsUsed: 0,
    mistakes: 0,
    finished: false,
  );

  @override
  Future<void> saveProgress({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> progress,
    required int elapsedMs,
    int mistakes = 0,
  }) async {
    saves.add((progress: List<int>.of(progress), elapsedMs: elapsedMs));
  }

  /// Every autosave, in order.
  final saves = <({List<int> progress, int elapsedMs})>[];

  @override
  Future<GameHint> hint({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> board,
    required int seq,
  }) async {
    hintBoards.add(List<int>.of(board));
    return hintAnswer;
  }

  /// Thrown by the next [submitFailures] calls to [submit], to stand in for a
  /// socket that is down. Each submit that throws one decrements it.
  int submitFailures = 0;

  /// Every elapsed time [submit] was handed, in order — a retry must resend the
  /// time the board was solved at, not a later one.
  final List<int> submitted = [];

  /// The mistake tally each [submit] carried, alongside [submitted].
  final List<int> submittedMistakes = [];

  /// The board each [submit] carried, alongside [submitted].
  final List<List<int>> submittedSolutions = [];

  @override
  Future<GameOutcome> submit({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> solution,
    required int elapsedMs,
    int hintsUsed = 0,
    int mistakes = 0,
  }) async {
    submitted.add(elapsedMs);
    submittedMistakes.add(mistakes);
    submittedSolutions.add(List<int>.of(solution));
    if (submitFailures > 0) {
      submitFailures--;
      throw Exception('MutationTimeout');
    }
    return const GameOutcome(solved: true, durationMs: 1000, replay: false);
  }

  @override
  Future<List<int>> reveal({
    required String userId,
    required String dayKey,
    required DailyGame game,
    int mistakes = 0,
  }) async => const [];

  /// Every game whose result this fake was asked to share, in order.
  ///
  /// Recorded rather than swallowed because the interesting property of the
  /// share is that it happens EXACTLY once per result — a test that only
  /// checked "no throw" would pass just as happily against a button that fired
  /// on every rebuild.
  final List<DailyGame> shared = [];

  @override
  Future<void> shareResult({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async {
    shared.add(game);
  }

  /// The all-time board this fake answers with. Empty unless a test sets it.
  RecordBoard records = const RecordBoard();

  /// Every reaction sent, as `recordId:emoji` — or `recordId:-` for a removal.
  final List<String> reactions = [];

  /// When set, reactions fail with this — for the revert path.
  Object? reactError;

  @override
  Future<RecordBoard> recordBoard({required String userId}) async => records;

  @override
  Future<void> reactToRecord({
    required String userId,
    required String recordId,
    required String emoji,
  }) async {
    if (reactError != null) throw reactError!;
    reactions.add('$recordId:$emoji');
  }

  @override
  Future<void> unreactToRecord({
    required String userId,
    required String recordId,
  }) async {
    if (reactError != null) throw reactError!;
    reactions.add('$recordId:-');
  }
}
