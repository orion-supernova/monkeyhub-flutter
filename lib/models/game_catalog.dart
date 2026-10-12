import 'daily_game.dart';

/// How hard a daily is, as the Feed's games row groups them.
///
/// Fixed per game rather than rotating by weekday: a player who likes the
/// easy ones finds them in the same place every morning, and a game's
/// standings compare like with like every day of the week.
enum GameTier { easy, medium, hard }

/// [game]'s tier. Null is the symbol-code puzzle, which opens the easy group:
/// the daily nudge names the code, so the tile a notification lands on has to
/// be the first one under the thumb (see `games_hub_order_test.dart`), and six
/// guesses with feedback on every one is a gentle start anyway.
GameTier tierOf(DailyGame? game) => switch (game) {
  null => GameTier.easy,
  DailyGame.zip => GameTier.easy,
  DailyGame.sudoku => GameTier.easy,
  DailyGame.tango => GameTier.easy,
  DailyGame.flow => GameTier.easy,
  DailyGame.queens => GameTier.medium,
  DailyGame.futoshiki => GameTier.medium,
  DailyGame.nonogram => GameTier.medium,
  DailyGame.minesweeper => GameTier.medium,
  DailyGame.starbattle => GameTier.hard,
};
