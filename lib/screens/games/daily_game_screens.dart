import 'package:flutter/widgets.dart';

import '../../models/daily_game.dart';
import 'flow_screen.dart';
import 'futoshiki_screen.dart';
import 'minesweeper_screen.dart';
import 'nonogram_screen.dart';
import 'patches_screen.dart';
import 'queens_screen.dart';
import 'starbattle_screen.dart';
import 'sudoku_screen.dart';
import 'tango_screen.dart';
import 'zip_screen.dart';

/// The board screen for [game].
///
/// One switch, used by every place a daily is opened from (the Feed's games
/// row and the leaderboard), so a new game is wired in once and cannot open
/// from one of them and not the other.
Widget dailyGameScreen(DailyGame game, String userId) => switch (game) {
  DailyGame.queens => QueensScreen(userId: userId),
  DailyGame.tango => TangoScreen(userId: userId),
  DailyGame.zip => ZipScreen(userId: userId),
  DailyGame.sudoku => SudokuScreen(userId: userId),
  DailyGame.flow => FlowScreen(userId: userId),
  DailyGame.futoshiki => FutoshikiScreen(userId: userId),
  DailyGame.nonogram => NonogramScreen(userId: userId),
  DailyGame.minesweeper => MinesweeperScreen(userId: userId),
  DailyGame.starbattle => StarBattleScreen(userId: userId),
  DailyGame.patches => PatchesScreen(userId: userId),
};
