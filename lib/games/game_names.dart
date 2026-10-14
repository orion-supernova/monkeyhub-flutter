import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';

/// [game]'s name as its tile, its board and its standings spell it.
///
/// One switch rather than one per surface: the tile, the leaderboard capsule,
/// the records board and the info sheet each used to carry their own, and a
/// game added to three of them and forgotten in the fourth is a capsule with
/// no label.
String dailyGameName(AppLocalizations l10n, DailyGame game) => switch (game) {
  DailyGame.queens => l10n.gameQueensName,
  DailyGame.tango => l10n.gameTangoName,
  DailyGame.zip => l10n.gameZipName,
  DailyGame.sudoku => l10n.gameSudokuName,
  DailyGame.flow => l10n.gameFlowName,
  DailyGame.futoshiki => l10n.gameFutoshikiName,
  DailyGame.nonogram => l10n.gameNonogramName,
  DailyGame.minesweeper => l10n.gameMinesweeperName,
  DailyGame.starbattle => l10n.gameStarbattleName,
  DailyGame.patches => l10n.gamePatchesName,
};
