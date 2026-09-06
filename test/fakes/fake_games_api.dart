import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/models/daily_game.dart';

/// Answers every call instantly with today's real boards and nobody's times.
///
/// Holds the wire payload rather than the decoded boards: the store reads the
/// raw one so it has something to put on disk, and a stub that only knew how to
/// answer the decoded call would pass while the cached path went untested.
class FakeGamesApi implements GamesApi {
  FakeGamesApi(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<DailyBoards> daily({required String dayKey}) async =>
      DailyBoards.fromJson(payload);

  @override
  Future<dynamic> dailyRaw({required String dayKey}) async => payload;

  @override
  Future<GameStandings> standings({
    required String userId,
    required String dayKey,
  }) async => const GameStandings();

  @override
  Future<GameSession> start({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async => GameSession(
    startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    progress: const [],
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
  }) async {}

  @override
  Future<GameHint> hint({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> board,
  }) async => const GameHint(index: -1, value: 0);

  @override
  Future<GameOutcome> submit({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> solution,
    required int elapsedMs,
    int hintsUsed = 0,
    int mistakes = 0,
  }) async => const GameOutcome(solved: true, durationMs: 1000, replay: false);

  @override
  Future<List<int>> reveal({
    required String userId,
    required String dayKey,
    required DailyGame game,
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
}
