/// The interactive board for an in-chat turn game, and its inert thumbnail.
///
/// One widget for all six games so the chat card, the game sheet and the
/// lobby never switch on a game id themselves: they hand over the id and the
/// encoded state, and get back encoded move tokens.
///
/// The rules engine is the gate. A board only ever emits a token that
/// `rules.legalMoves` lists for the position it is showing, and never while
/// [TurnBoard.enabled] is false, so a stray tap can at worst do nothing.
library;

import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../dots.dart';
import '../registry.dart';
import 'board_kit.dart';
import 'checkers_board.dart';
import 'chess_board.dart';
import 'connect_four_board.dart';
import 'dots_board.dart';
import 'reversi_board.dart';
import 'seat_palette.dart';
import 'tic_tac_toe_board.dart';

export 'seat_palette.dart' show SeatPalette;

/// A turn-game board.
///
/// Sizes itself to the game's own aspect ratio inside whatever width it is
/// given (see [aspectRatioOf]); give it a width, and either an unbounded or a
/// generous height.
///
/// Repaints only through its painters: a position change rebuilds the board
/// once, and any animation that follows (a mark drawing on, a disc falling,
/// flips cascading) runs on one controller that only the painter listens to.
class TurnBoard extends StatefulWidget {
  const TurnBoard({
    super.key,
    required this.gameId,
    required this.state,
    this.mySeat,
    this.enabled = false,
    this.onMove,
    this.lastMove,
    this.thumbnail = false,
    this.winLine = true,
    this.seatLabels,
  });

  /// Registry id: `tictactoe`, `connectfour`, `reversi`, `checkers`, `dots`,
  /// `chess`.
  final String gameId;

  /// The encoded state, authoritative or optimistic. A string the rules
  /// cannot decode keeps the last good position on screen (or nothing, on
  /// first mount) rather than throwing in the middle of a transcript.
  final String state;

  /// The viewer's seat; null for spectators and thumbnails. Checkers turns
  /// the board round for seat 0 so the viewer's men start at the bottom;
  /// chess turns it round for seat 1, so black plays up the screen.
  final int? mySeat;

  /// True only when it is [mySeat]'s turn and input is allowed.
  final bool enabled;

  /// The encoded move token, emitted once per complete move. A checkers
  /// multi-jump is assembled tap by tap and emitted once, whole.
  final ValueChanged<String>? onMove;

  /// The last move's token, for its highlight and so a checkers multi-jump
  /// animates along its real route. Optional: without it the board works the
  /// move out from the difference between positions.
  final String? lastMove;

  /// An inert miniature for chat cards: no gestures, no tickers, no
  /// animation and no semantics tree. Several render per card, so each costs
  /// one picture.
  final bool thumbnail;

  /// Highlight a finished game's winning line or cells.
  final bool winLine;

  /// Seat initials for the claimed boxes in Dots. Defaults to A, B, C, D.
  final List<String>? seatLabels;

  /// Width over height for [gameId] at [state]. Connect Four is square when
  /// playable (a lane above the slab for the disc in hand) and 7:6 as a
  /// thumbnail; Dots follows its box grid; the rest (chess included) are
  /// square.
  static double aspectRatioOf(
    String gameId,
    String state, {
    bool thumbnail = false,
  }) {
    switch (gameId) {
      case 'connectfour':
        return ConnectFourGeometry.aspect(lane: !thumbnail);
      case 'dots':
        final m = RegExp(r'^([1-9])x([1-9])\|').firstMatch(state);
        if (m == null) {
          return DotsLayout.aspect(dotsDefaultSize, dotsDefaultSize);
        }
        return DotsLayout.aspect(int.parse(m.group(1)!), int.parse(m.group(2)!));
      default:
        return 1;
    }
  }

  @override
  State<TurnBoard> createState() => _TurnBoardState();
}

class _TurnBoardState extends State<TurnBoard> {
  static const _defaultLabels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final w = widget;
    if (turnGameFor(w.gameId) == null) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final props = BoardProps(
      state: w.state,
      mySeat: w.mySeat,
      enabled: w.enabled && !w.thumbnail,
      onMove: w.thumbnail ? null : w.onMove,
      lastMove: w.lastMove,
      thumbnail: w.thumbnail,
      winLine: w.winLine,
      seatLabels: w.seatLabels ?? _defaultLabels,
      theme: theme,
      seats: SeatPalette(theme, gameId: w.gameId),
      // A thumbnail never animates, so it does not subscribe to the motion
      // budget either: one fewer dependency per card in a long transcript.
      calm: w.thumbnail || MotionScope.of(context).calm,
      highContrast: !w.thumbnail && (MediaQuery.maybeHighContrastOf(context) ?? false),
    );
    final key = ValueKey(w.gameId);
    final Widget board = switch (w.gameId) {
      'tictactoe' => TicTacToeBoardView(key: key, props: props),
      'connectfour' => ConnectFourBoardView(key: key, props: props),
      'reversi' => ReversiBoardView(key: key, props: props),
      'checkers' => CheckersBoardView(key: key, props: props),
      'dots' => DotsBoardView(key: key, props: props),
      'chess' => ChessBoardView(key: key, props: props),
      _ => const SizedBox.shrink(),
    };
    // Boards are spatial, not text: a right-to-left locale must not mirror
    // column 1 to the right-hand side.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AspectRatio(
        aspectRatio: TurnBoard.aspectRatioOf(w.gameId, w.state, thumbnail: w.thumbnail),
        child: board,
      ),
    );
  }
}
