import 'package:flutter/painting.dart';

import '../../chat_games/match_copy.dart';
import '../../chat_games/play_style.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_match.dart';
import '../../widgets/ios_kit.dart';
import 'chat_demos.dart';
import 'how_to_play.dart';

/// The how-to-play guide for chat game [game] ('tictactoe', 'liarsdice', ...).
///
/// After the game's own steps come a page or two on each play mode in
/// [modes]: pass the one being played (the match screen), every mode the room
/// offers (the start sheet), or none (a game against the bot). [group] adds
/// the spectators and seat swap page to Live; [voice] adds Imposter's
/// say-it-out-loud step. [practice] is a game against the bot, whose footnote
/// cannot talk about chats: practice is the only place it is played.
HowToPlayGuide chatGuide(
  AppLocalizations l10n,
  String game, {
  List<PlayStyle> modes = const [],
  bool group = false,
  bool voice = false,
  bool practice = false,
}) {
  HowToStep s(String text, HowToDemo demo, {bool tip = false}) =>
      HowToStep(text: text, demo: demo, tip: tip);
  final steps = switch (game) {
    'tictactoe' => [
      s(l10n.howToTtt1, const TicTacToeRulesDemo()),
      s(l10n.howToTtt2, const TicTacToeBlockDemo(), tip: true),
    ],
    'connectfour' => [
      s(l10n.howToC41, const ConnectFourDropDemo()),
      s(l10n.howToC42, const ConnectFourWinDemo()),
      s(l10n.howToC4Tip, const ConnectFourTipDemo(), tip: true),
    ],
    'checkers' => [
      s(l10n.howToCheckers1, const CheckersMoveDemo()),
      s(l10n.howToCheckers2, const CheckersJumpDemo()),
      s(l10n.howToCheckers3, const CheckersMultiDemo()),
      s(l10n.howToCheckers4, const CheckersKingDemo()),
      s(l10n.howToCheckersTip, const CheckersTipDemo(), tip: true),
    ],
    'reversi' => [
      s(l10n.howToReversi1, const ReversiTrapDemo()),
      s(l10n.howToReversi2, const ReversiFlipDemo()),
      s(l10n.howToReversi3, const ReversiCountDemo()),
      s(l10n.howToReversiTip, const ReversiTipDemo(), tip: true),
    ],
    'dots' => [
      s(l10n.howToDots1, const DotsLinesDemo()),
      s(l10n.howToDots2, const DotsBoxDemo()),
      s(l10n.howToDots3, const DotsThirdSideDemo(), tip: true),
    ],
    'chess' => [
      s(l10n.howToChess1, const ChessMoveDemo()),
      s(l10n.howToChess2, const ChessCaptureDemo()),
      s(l10n.howToChess3, const ChessPromoteDemo()),
      s(l10n.howToChess4, const ChessMateDemo()),
      s(l10n.howToChessTip, const ChessTipDemo(), tip: true),
    ],
    'liarsdice' => [
      s(l10n.howToLiars1, const LiarsSecretDemo()),
      s(l10n.howToLiars2, const LiarsBidDemo()),
      s(l10n.howToLiars3, const LiarsWildDemo()),
      s(l10n.howToLiars4, const LiarsRaiseDemo()),
      s(l10n.howToLiars5, const LiarsCallDemo()),
      s(l10n.howToLiars6, const LiarsLoseDemo()),
      s(l10n.howToLiars7, const LiarsWinDemo()),
      s(l10n.howToLiarsTip, const LiarsTipDemo(), tip: true),
    ],
    'imposter' => [
      s(l10n.howToImposter1, const ImposterWordDemo()),
      s(l10n.howToImposter2, const ImposterClueDemo()),
      if (voice) s(l10n.howToImposterVoice, const ImposterVoiceDemo()),
      s(l10n.howToImposter3, const ImposterVoteDemo()),
      s(l10n.howToImposter4, const ImposterGuessDemo()),
    ],
    'race' => [
      s(l10n.howToRace1, const RaceSameDemo()),
      s(l10n.howToRace2, const RaceProgressDemo()),
      s(l10n.howToRace3, const RaceFinishDemo()),
    ],
    _ => <HowToStep>[],
  };

  HowToChip chip(PlayStyle style) => HowToChip(
    label: style.badge(l10n),
    icon: style.icon,
    color: (theme) => tileColor(theme, style.tone),
  );
  HowToStep mode(PlayStyle style, String text, HowToDemo demo) =>
      HowToStep(text: text, demo: demo, chip: chip(style));

  final notRanked = practice ? l10n.practiceNotRanked : l10n.chatGameNotRanked;
  return HowToPlayGuide(
    id: 'chat.$game',
    title: chatGameName(l10n, game),
    footnote: switch (game) {
      'checkers' => '${l10n.howToCheckersWin} $notRanked',
      'dots' => '${l10n.howToDotsWin} $notRanked',
      'liarsdice' => '${l10n.howToLiarsClock} $notRanked',
      _ => notRanked,
    },
    steps: [
      ...steps,
      for (final style in modes)
        if (style == PlayStyle.turns && !isPartyGame(game)) ...[
          mode(style, l10n.howToTurns1, TurnsSendDemo(color: _turns)),
          mode(style, l10n.howToTurns2, TurnsClockDemo(color: _turns)),
          mode(style, l10n.howToTurns3, TurnsTimeoutDemo(color: _turns)),
        ] else if (style == PlayStyle.live) ...[
          mode(style, l10n.howToLive1, LiveReadyDemo(color: _live)),
          mode(style, l10n.howToLive2, LivePauseDemo(color: _live)),
          if (group) mode(style, l10n.howToLive3, LiveWatchDemo(color: _live)),
        ],
    ],
  );
}

// The modes' own colours, exactly as their badges wear them (`tileColor`'s
// pink and indigo, which are the same on every theme).
const _live = Color(0xFFFF2D55);
const _turns = Color(0xFF5856D6);
