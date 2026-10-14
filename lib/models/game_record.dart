import 'daily_game.dart';
import 'puzzle.dart';

/// What a friend may react to a record with. Mirrors `RECORD_REACTIONS` in
/// backend/convex/records.ts — the server refuses anything else, and the board
/// also sends its palette, which wins when the two ever disagree.
const List<String> kRecordReactions = ['🔥', '👏', '🤯', '🐐', '😮', '😂'];

/// A game a record can be held in: the code puzzle, then the timed dailies in
/// [DailyGame] order.
enum RecordGame {
  code,
  queens,
  tango,
  zip,
  sudoku,
  flow,
  futoshiki,
  nonogram,
  minesweeper,
  starbattle,
  patches;

  /// The id the backend keys records by.
  String get wire => name;

  /// The daily this is, or null for the code puzzle.
  DailyGame? get daily => switch (this) {
        RecordGame.code => null,
        RecordGame.queens => DailyGame.queens,
        RecordGame.tango => DailyGame.tango,
        RecordGame.zip => DailyGame.zip,
        RecordGame.sudoku => DailyGame.sudoku,
        RecordGame.flow => DailyGame.flow,
        RecordGame.futoshiki => DailyGame.futoshiki,
        RecordGame.nonogram => DailyGame.nonogram,
        RecordGame.minesweeper => DailyGame.minesweeper,
        RecordGame.starbattle => DailyGame.starbattle,
        RecordGame.patches => DailyGame.patches,
      };

  static RecordGame of(DailyGame game) => switch (game) {
        DailyGame.queens => RecordGame.queens,
        DailyGame.tango => RecordGame.tango,
        DailyGame.zip => RecordGame.zip,
        DailyGame.sudoku => RecordGame.sudoku,
        DailyGame.flow => RecordGame.flow,
        DailyGame.futoshiki => RecordGame.futoshiki,
        DailyGame.nonogram => RecordGame.nonogram,
        DailyGame.minesweeper => RecordGame.minesweeper,
        DailyGame.starbattle => RecordGame.starbattle,
        DailyGame.patches => RecordGame.patches,
      };

  static RecordGame? parse(String? s) {
    for (final g in values) {
      if (g.wire == s) return g;
    }
    return null;
  }

  /// A best as it reads on its tile: a stopwatch for the dailies, guesses for
  /// the code — the same two forms the day's own standings use.
  String formatBest(int best) => this == RecordGame.code
      ? '$best/$kPuzzleMaxGuesses'
      : formatGameTime(best);
}

/// One emoji on a record, and how many friends chose it.
class RecordReaction {
  const RecordReaction({required this.emoji, required this.count});
  final String emoji;
  final int count;
}

/// One person's all-time best at one game.
class GameRecordRow {
  const GameRecordRow({
    required this.recordId,
    required this.userId,
    required this.name,
    required this.rank,
    required this.best,
    required this.dayKey,
    required this.achievedAt,
    required this.solves,
    this.reactions = const [],
    this.reactors = const [],
    this.mine,
  });

  final String recordId;
  final String userId;

  /// Empty for the viewer's own row: the UI says "you" in the reader's
  /// language rather than echoing their own name back.
  final String name;

  /// 1-based, among everyone on the board — the viewer's own row carries its
  /// real rank even when it sits below the rows the board returns.
  final int rank;

  /// Milliseconds for a daily, guesses for the code. Lower wins either way.
  final int best;
  final String dayKey;
  final DateTime achievedAt;

  /// Every solve of this game, best or not.
  final int solves;

  final List<RecordReaction> reactions;

  /// Who reacted, newest first, with what — for the "who" line.
  final List<({String userId, String name, String emoji})> reactors;

  /// The viewer's own reaction on this record, if any.
  final String? mine;

  int get reactionCount => reactions.fold(0, (sum, r) => sum + r.count);

  GameRecordRow copyWith({
    List<RecordReaction>? reactions,
    List<({String userId, String name, String emoji})>? reactors,
    String? mine,
    bool clearMine = false,
  }) =>
      GameRecordRow(
        recordId: recordId,
        userId: userId,
        name: name,
        rank: rank,
        best: best,
        dayKey: dayKey,
        achievedAt: achievedAt,
        solves: solves,
        reactions: reactions ?? this.reactions,
        reactors: reactors ?? this.reactors,
        mine: clearMine ? null : (mine ?? this.mine),
      );

  static GameRecordRow fromJson(Map<String, dynamic> j) => GameRecordRow(
        recordId: j['recordId'].toString(),
        userId: j['userId'].toString(),
        name: j['name']?.toString() ?? '',
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        best: (j['best'] as num?)?.toInt() ?? 0,
        dayKey: j['dayKey']?.toString() ?? '',
        achievedAt: DateTime.fromMillisecondsSinceEpoch(
          (j['achievedAt'] as num?)?.toInt() ?? 0,
        ),
        solves: (j['solves'] as num?)?.toInt() ?? 0,
        reactions: [
          for (final r in (j['reactions'] as List?) ?? const [])
            if (r is Map)
              RecordReaction(
                emoji: r['emoji']?.toString() ?? '',
                count: (r['count'] as num?)?.toInt() ?? 0,
              ),
        ],
        reactors: [
          for (final r in (j['reactors'] as List?) ?? const [])
            if (r is Map)
              (
                userId: r['userId']?.toString() ?? '',
                name: r['name']?.toString() ?? '',
                emoji: r['emoji']?.toString() ?? '',
              ),
        ],
        mine: j['mine']?.toString(),
      );
}

/// Everyone's bests, per game, best first.
class RecordBoard {
  const RecordBoard({
    this.games = const {},
    this.palette = kRecordReactions,
    this.avatars = const {},
  });

  final Map<RecordGame, List<GameRecordRow>> games;
  final List<String> palette;

  /// Profile pictures by person, holders and cheerers alike: only the ones
  /// each owner lets friends see. Absent draws a monogram.
  final Map<String, String> avatars;

  List<GameRecordRow> rowsFor(RecordGame game) => games[game] ?? const [];

  /// The record for [game] — the top of its board — or null if nobody has
  /// solved it yet.
  GameRecordRow? holderOf(RecordGame game) {
    final rows = rowsFor(game);
    return rows.isEmpty ? null : rows.first;
  }

  /// Everyone who shares the record for [game]: an exact tie on the best is
  /// a shared record, not a race to whoever happened to set it first. Empty
  /// when nobody has solved it yet. In board order; display order is the
  /// caller's (alphabetical, by the name it shows).
  List<GameRecordRow> holdersOf(RecordGame game) {
    final rows = rowsFor(game);
    if (rows.isEmpty) return const [];
    // The server ranks ties as one shared place at display precision (whole
    // seconds), so every rank-1 row holds it. The equal-best test covers a
    // server from before shared places, which numbered ties 1, 2.
    final best = rows.first.best;
    return [for (final r in rows) if (r.rank == 1 || r.best == best) r];
  }

  /// The viewer's own best at [game], wherever it ranks.
  GameRecordRow? mineFor(RecordGame game, String viewerId) {
    for (final r in rowsFor(game)) {
      if (r.userId == viewerId) return r;
    }
    return null;
  }

  bool get isEmpty => games.values.every((rows) => rows.isEmpty);

  /// A copy with one record's row replaced, for an optimistic reaction.
  RecordBoard replacing(GameRecordRow row) => RecordBoard(
        palette: palette,
        avatars: avatars,
        games: {
          for (final e in games.entries)
            e.key: [
              for (final r in e.value) r.recordId == row.recordId ? row : r,
            ],
        },
      );

  static RecordBoard fromJson(dynamic raw) {
    if (raw is! Map) return const RecordBoard();
    final games = <RecordGame, List<GameRecordRow>>{};
    final byGame = raw['games'];
    if (byGame is Map) {
      for (final e in byGame.entries) {
        final game = RecordGame.parse(e.key?.toString());
        if (game == null) continue;
        games[game] = [
          for (final r in (e.value as List?) ?? const [])
            if (r is Map) GameRecordRow.fromJson(r.cast<String, dynamic>()),
        ];
      }
    }
    final palette = [
      for (final p in (raw['palette'] as List?) ?? const []) p.toString(),
    ];
    return RecordBoard(
      games: games,
      palette: palette.isEmpty ? kRecordReactions : palette,
      avatars: {
        for (final e in ((raw['avatars'] as Map?) ?? const {}).entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key.toString(): e.value as String,
      },
    );
  }
}
