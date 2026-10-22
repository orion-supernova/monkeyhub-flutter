import '../../games/game_names.dart';
import '../../games/ranking.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../models/puzzle.dart';

/// Every game of a day, in the order every shelf draws them: the code first
/// (the game the app had first, and the one the daily nudge names), then the
/// timed boards in [DailyGame] order. The solved-dots on a leaderboard row follow
/// this order, so dot 1 is always the code.
///
/// Null is the code — the same convention `showCodePuzzleInfo` uses for "the
/// one game that is not a [DailyGame]".
const List<DailyGame?> kLeaderboardGames = [null, ...DailyGame.values];

/// The game a capsule names; null is the code.
String leaderboardGameName(AppLocalizations l10n, DailyGame? game) =>
    switch (game) {
      null => l10n.gameCodeName,
      final DailyGame daily => dailyGameName(l10n, daily),
    };

/// One player's line on the overall ("Today") leaderboard.
class LeaderRow {
  const LeaderRow({
    required this.userId,
    required this.name,
    required this.isViewer,
    required this.solved,
    required this.wins,
    required this.place,
    required this.solvedByGame,
  });

  final String userId;

  /// The first non-empty name across the player's rows. Empty for the viewer
  /// — the UI says "You" there, never their own name back at them.
  final String name;
  final bool isViewer;

  /// Games solved today, out of [kLeaderboardGames]. The score.
  final int solved;

  /// Boards this player SOLVED and placed first on. Everyone sharing first
  /// place on a board wins it; a gave-up row at the top of an otherwise
  /// empty board is not a win.
  final int wins;

  /// Their place on this board, shared on a tie ("1, 1, 2").
  final int place;

  /// Solved or not, per game, in [kLeaderboardGames] order — the row's dots.
  final List<bool> solvedByGame;
}

/// Today's overall standings across every game, best first, from data
/// the leaderboard already holds — no new query, no subscription.
///
/// A point per puzzle solved; equal points go to whoever won more boards.
/// Equal on both is a tie: they share the place and are listed A to Z. The
/// viewer's row is nameless, so it sorts by [you], the "You" the row shows.
///
/// Only players with at least one FINISHED row appear (a gave-up row counts:
/// it is on the board, ranked, just not solved). The viewer is in the list
/// only if they have finished something; the screen pins them otherwise.
List<LeaderRow> overallStandings(
  GameStandings standings,
  PuzzleState puzzle,
  String viewerId, {
  required String you,
}) {
  // Per game: who finished, with their shared place on that board.
  final boards = <List<({String userId, String name, bool solved, int place})>>[
    for (final game in kLeaderboardGames)
      game == null
          ? _codeBoard(puzzle.scores)
          : _timedBoard(standings.boards[game] ?? const <GameResult>[]),
  ];

  final ids = <String>[];
  final names = <String, String>{};
  for (final rows in boards) {
    for (final r in rows) {
      if (r.userId.isEmpty) continue;
      if (!names.containsKey(r.userId)) ids.add(r.userId);
      final known = names[r.userId] ?? '';
      if (known.isEmpty) names[r.userId] = r.name;
    }
  }

  final out = <({
    String id,
    String name,
    bool viewer,
    int solved,
    int wins,
    List<bool> dots,
  })>[];
  for (final id in ids) {
    var solved = 0;
    var wins = 0;
    final dots = <bool>[];
    for (final rows in boards) {
      final i = rows.indexWhere((r) => r.userId == id);
      if (i < 0) {
        dots.add(false);
        continue;
      }
      final ok = rows[i].solved;
      dots.add(ok);
      if (ok) solved++;
      if (ok && rows[i].place == 1) wins++;
    }
    final viewer = id == viewerId;
    out.add((
      id: id,
      name: viewer ? '' : names[id] ?? '',
      viewer: viewer,
      solved: solved,
      wins: wins,
      dots: List.unmodifiable(dots),
    ));
  }

  out.sort((a, b) {
    final bySolved = b.solved.compareTo(a.solved);
    if (bySolved != 0) return bySolved;
    return b.wins.compareTo(a.wins);
  });
  final ranked = rankByPlace(
    out,
    sameScore: (a, b) => a.solved == b.solved && a.wins == b.wins,
    nameOf: (r) => r.viewer ? you : r.name,
  );
  return [
    for (final e in ranked)
      LeaderRow(
        userId: e.row.id,
        name: e.row.name,
        isViewer: e.row.viewer,
        solved: e.row.solved,
        wins: e.row.wins,
        place: e.place,
        solvedByGame: e.row.dots,
      ),
  ];
}

/// One timed board as [overallStandings] reads it: each row's shared place,
/// computed at display precision.
List<({String userId, String name, bool solved, int place})> _timedBoard(
  List<GameResult> rows,
) {
  final places = rankedPlaces(rows, sameGameScore);
  return [
    for (final (i, r) in rows.indexed)
      (
        userId: r.userId,
        name: r.name,
        solved: r.solved,
        place: places[i],
      ),
  ];
}

/// The code's board as [overallStandings] reads it, the same way.
List<({String userId, String name, bool solved, int place})> _codeBoard(
  List<PuzzleScore> rows,
) {
  final places = rankedPlaces(rows, samePuzzleScore);
  return [
    for (final (i, s) in rows.indexed)
      (
        userId: s.userId,
        name: s.name,
        solved: s.solved,
        place: places[i],
      ),
  ];
}
