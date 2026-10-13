import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../game_names.dart';
import 'daily_demos.dart';
import 'how_to_play.dart';

/// The how-to-play guide for a daily puzzle, or for the code puzzle when
/// [game] is null.
HowToPlayGuide dailyGuide(AppLocalizations l10n, DailyGame? game) {
  final timed =
      '${l10n.gameInfoScoringTimed} ${l10n.gameInfoSameForEveryone}';
  HowToStep s(String text, HowToDemo demo, {bool tip = false}) =>
      HowToStep(text: text, demo: demo, tip: tip);
  return switch (game) {
    DailyGame.queens => HowToPlayGuide(
      id: 'daily.queens',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToQueens1, const QueensRulesDemo()),
        s(l10n.howToQueens2, const QueensTouchDemo()),
        s(l10n.howToQueens3, const QueensControlsDemo()),
        s(l10n.howToQueens4, const QueensTipDemo(), tip: true),
      ],
    ),
    DailyGame.tango => HowToPlayGuide(
      id: 'daily.tango',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToTango1, const TangoFillDemo()),
        s(l10n.howToTango2, const TangoBalanceDemo()),
        s(l10n.howToTango3, const TangoThreeDemo()),
        s(l10n.howToTango4, const TangoSignsDemo()),
      ],
    ),
    DailyGame.zip => HowToPlayGuide(
      id: 'daily.zip',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToZip1, const ZipOrderDemo()),
        s(l10n.howToZip2, const ZipFillDemo()),
        s(l10n.howToZip3, const ZipUndoDemo(), tip: true),
      ],
    ),
    DailyGame.sudoku => HowToPlayGuide(
      id: 'daily.sudoku',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToSudoku1, const SudokuRulesDemo()),
        s(l10n.howToSudoku2, const SudokuTapDemo()),
        s(l10n.howToSudoku3, const SudokuClashDemo()),
        s(l10n.howToSudoku4, const SudokuTipDemo(), tip: true),
      ],
    ),
    DailyGame.flow => HowToPlayGuide(
      id: 'daily.flow',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToFlow1, const FlowConnectDemo()),
        s(l10n.howToFlow2, const FlowLongWayDemo()),
      ],
    ),
    DailyGame.futoshiki => HowToPlayGuide(
      id: 'daily.futoshiki',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToFutoshiki1, const FutoshikiRulesDemo()),
        s(l10n.howToFutoshiki2, const FutoshikiSignDemo()),
        s(l10n.howToFutoshiki3, const FutoshikiWrongDemo()),
      ],
    ),
    DailyGame.nonogram => HowToPlayGuide(
      id: 'daily.nonogram',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToNonogram1, const NonogramClueDemo()),
        s(l10n.howToNonogram2, const NonogramGapDemo()),
        s(l10n.howToNonogramOrder, const NonogramOrderDemo()),
        s(l10n.howToNonogram3, const NonogramControlsDemo()),
        s(l10n.howToNonogram4, const NonogramPictureDemo()),
      ],
    ),
    DailyGame.minesweeper => HowToPlayGuide(
      id: 'daily.minesweeper',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToMines1, const MinesOpenDemo()),
        s(l10n.howToMines2, const MinesNumberDemo()),
        s(l10n.howToMines3, const MinesFlagDemo()),
        s(l10n.howToMines4, const MinesPenaltyDemo()),
      ],
    ),
    DailyGame.starbattle => HowToPlayGuide(
      id: 'daily.starbattle',
      title: dailyGameName(l10n, game!),
      footnote: timed,
      steps: [
        s(l10n.howToStars1, const StarsRulesDemo()),
        s(l10n.howToStars2, const StarsTouchDemo()),
        s(l10n.howToStarsControls, const StarsControlsDemo()),
        s(l10n.howToStars3, const StarsTipDemo(), tip: true),
      ],
    ),
    null => HowToPlayGuide(
      id: 'daily.code',
      title: l10n.gameCodeName,
      footnote:
          '${l10n.gameInfoScoringGuesses} ${l10n.gameInfoSameForEveryone}',
      steps: [
        s(l10n.howToCode1, const CodeGoalDemo()),
        s(l10n.howToCode2, const CodeGreenDemo()),
        s(l10n.howToCode3, const CodeYellowDemo()),
        s(l10n.howToCode4, const CodeWinDemo()),
      ],
    ),
  };
}
