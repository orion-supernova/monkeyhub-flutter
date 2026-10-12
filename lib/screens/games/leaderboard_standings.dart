import '../../games/game_names.dart';
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
    required this.rankSum,
    required this.solvedByGame,
  });

  final String userId;

  /// The first non-empty name across the player's rows. Empty for the viewer
  /// — the UI says "You" there, never their own name back at them.
  final String name;
  final bool isViewer;

  /// Games solved today, out of [kLeaderboardGames]. The score.
  final int solved;

  /// Games where this player is first on the board AND solved it — a
  /// gave-up row at the top of an otherwise empty board is not a win.
  final int wins;

  /// The sum of their 1-based ranks across every game; a game they have
  /// no row on counts as one place behind its last row. Lowest is best.
  final int rankSum;

  /// Solved or not, per game, in [kLeaderboardGames] order — the row's dots.
  final List<bool> solvedByGame;
}

/// Today's overall standings across every game, best first, from data
/// the leaderboard already holds — no new query, no subscription.
///
/// A point per puzzle solved. Ties go to whoever won more boards, then to the
/// lower rank sum (placed higher overall), then alphabetically so the order
/// never shuffles between two refreshes of identical data.
///
/// Only players with at least one FINISHED row appear (a gave-up row counts:
/// it is on the board, ranked, just not solved). The viewer is in the list
/// only if they have finished something; the screen pins them otherwise.
List<LeaderRow> overallStandings(
  GameStandings standings,
  PuzzleState puzzle,
  String viewerId,
) {
  // Per game: who finished, in board order (best first).
  final boards = <List<({String userId, String name, bool solved})>>[
    for (final game in kLeaderboardGames)
      game == null
          ? [
              for (final s in puzzle.scores)
                (userId: s.userId, name: s.name, solved: s.solved),
            ]
          : [
              for (final r in standings.boards[game] ?? const <GameResult>[])
                (userId: r.userId, name: r.name, solved: r.solved),
            ],
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

  final out = <LeaderRow>[];
  for (final id in ids) {
    var solved = 0;
    var wins = 0;
    var rankSum = 0;
    final dots = <bool>[];
    for (final rows in boards) {
      final i = rows.indexWhere((r) => r.userId == id);
      if (i < 0) {
        rankSum += rows.length + 1;
        dots.add(false);
        continue;
      }
      rankSum += i + 1;
      final ok = rows[i].solved;
      dots.add(ok);
      if (ok) solved++;
      if (ok && i == 0) wins++;
    }
    final viewer = id == viewerId;
    out.add(
      LeaderRow(
        userId: id,
        name: viewer ? '' : names[id] ?? '',
        isViewer: viewer,
        solved: solved,
        wins: wins,
        rankSum: rankSum,
        solvedByGame: List.unmodifiable(dots),
      ),
    );
  }

  out.sort((a, b) {
    final bySolved = b.solved.compareTo(a.solved);
    if (bySolved != 0) return bySolved;
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byRank = a.rankSum.compareTo(b.rankSum);
    if (byRank != 0) return byRank;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return a.userId.compareTo(b.userId);
  });
  return out;
}
