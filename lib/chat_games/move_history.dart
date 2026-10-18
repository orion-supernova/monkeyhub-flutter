import 'package:chess/chess.dart' as pkg;

import '../l10n/generated/app_localizations.dart';
import '../turn_games/chess.dart';
import '../turn_games/registry.dart';
import 'move_notation.dart';

/// One move of a game's line, as the move list shows it.
class HistoryEntry {
  const HistoryEntry({
    required this.seat,
    required this.move,
    required this.label,
    required this.stateAfter,
  });

  /// Who played it.
  final int seat;

  /// The wire token.
  final String move;

  /// How the list writes it: SAN for chess ("Nf3", "exd5", "O-O+"), the
  /// board's own coordinates elsewhere. Empty where words would say less than
  /// the board does (a line in Dots and Boxes).
  final String label;

  /// The encoded position right after it, for stepping back through the game.
  final String stateAfter;
}

/// A game's line replayed from the opening: every position along it, and a
/// label per move.
///
/// The server keeps only the current position on the match row, so the
/// earlier ones are rebuilt here from the move tokens, with the same rules
/// that check a tap. A token this build cannot apply (a newer server, a
/// corrupt row) ends the replay there rather than throwing: the list then
/// shows what it could, and the board keeps showing the server's position.
class GameLine {
  GameLine._(this.game, this.initial, this.entries);

  factory GameLine.replay({
    required AppLocalizations l10n,
    required String game,
    required int seats,
    required List<String> moves,
  }) {
    final rules = turnGameFor(game);
    if (rules == null) return GameLine._(game, '', const []);
    final initial = rules.initialEncoded(seats);
    var state = initial;
    final out = <HistoryEntry>[];
    // SAN needs the position before the move; the `chess` package writes it
    // (BSD, already the client's chess dependency).
    final san = game == 'chess' ? pkg.Chess() : null;
    for (final move in moves) {
      final String next;
      final int seat;
      try {
        seat = rules.toMoveEncoded(state);
        next = rules.applyEncoded(state, move);
      } catch (_) {
        break;
      }
      out.add(HistoryEntry(
        seat: seat,
        move: move,
        label: san != null
            ? _sanOf(san, move)
            : _labelOf(l10n, game, move, state),
        stateAfter: next,
      ));
      state = next;
    }
    return GameLine._(game, initial, List.unmodifiable(out));
  }

  final String game;

  /// The opening position.
  final String initial;
  final List<HistoryEntry> entries;

  int get length => entries.length;

  /// The position after [ply] moves: 0 is the opening.
  String stateAt(int ply) {
    if (ply <= 0 || entries.isEmpty) return initial;
    return entries[(ply > entries.length ? entries.length : ply) - 1]
        .stateAfter;
  }

  /// The move that produced the position after [ply] moves, for the board's
  /// last-move highlight. Null at the opening.
  String? moveAt(int ply) {
    if (ply <= 0 || ply > entries.length) return null;
    return entries[ply - 1].move;
  }
}

String _sanOf(pkg.Chess board, String uci) {
  if (uci.length < 4) return uci;
  final from = uci.substring(0, 2);
  final to = uci.substring(2, 4);
  final promo = uci.length == 5 ? uci[4] : null;
  for (final m in board.generate_moves()) {
    if (m.fromAlgebraic != from || m.toAlgebraic != to) continue;
    if (promo != null && m.promotion?.name != promo) continue;
    final san = board.move_to_san(m);
    board.move(m);
    return san;
  }
  return '$from-$to';
}

String _labelOf(
  AppLocalizations l10n,
  String game,
  String move,
  String before,
) {
  switch (game) {
    case 'tictactoe':
      final cell = int.tryParse(move);
      if (cell == null || cell < 0 || cell > 8) return '';
      return '${String.fromCharCode(0x41 + cell % 3)}${cell ~/ 3 + 1}';
    case 'connectfour':
      final col = int.tryParse(move);
      return col == null ? '' : '${col + 1}';
    case 'dots':
      return '';
    default:
      return moveNotation(l10n, game, move) ?? '';
  }
}

/// Material each side has taken in a chess position: the pieces missing from
/// the opponent's starting set (a promotion can make a count go "negative",
/// which is clamped), and who is ahead by how much in the usual 1/3/3/5/9.
class ChessMaterial {
  const ChessMaterial._(this.taken, this.advantage);

  /// `taken[seat]` = the piece codes (without colour) [seat] has captured,
  /// most valuable first.
  final List<List<int>> taken;

  /// White's material minus black's. Positive: white is ahead.
  final int advantage;

  static const _start = {
    chessPawn: 8,
    chessKnight: 2,
    chessBishop: 2,
    chessRook: 2,
    chessQueen: 1,
  };
  static const _value = {
    chessPawn: 1,
    chessKnight: 3,
    chessBishop: 3,
    chessRook: 5,
    chessQueen: 9,
  };

  static ChessMaterial? of(String encoded) {
    final ChessState state;
    try {
      state = chessRules.decode(encoded);
    } catch (_) {
      return null;
    }
    final counts = [<int, int>{}, <int, int>{}];
    var white = 0;
    var black = 0;
    for (var sq = 0; sq < 64; sq++) {
      final p = state.pieceAt(sq);
      if (p == 0) continue;
      final type = p & 7;
      final side = p >= chessBlack ? 1 : 0;
      counts[side][type] = (counts[side][type] ?? 0) + 1;
      final v = _value[type] ?? 0;
      if (side == 0) {
        white += v;
      } else {
        black += v;
      }
    }
    // Seat s took what is missing from the OTHER side's set.
    List<int> takenBy(int seat) {
      final other = counts[1 - seat];
      final out = <int>[];
      for (final type in const [
        chessQueen,
        chessRook,
        chessBishop,
        chessKnight,
        chessPawn,
      ]) {
        final missing = _start[type]! - (other[type] ?? 0);
        for (var i = 0; i < missing; i++) {
          out.add(type);
        }
      }
      return out;
    }

    return ChessMaterial._([takenBy(0), takenBy(1)], white - black);
  }
}
