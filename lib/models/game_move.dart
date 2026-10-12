/// One move of a turn by turn chat game, as its `gameMove` message carries
/// it: which game, whose move, the token, and the position it made.
///
/// Everything the bubble draws is here, so a transcript full of moves costs
/// no subscriptions: only "is this still the latest move, and whose turn is
/// it now" comes from `MatchesStore`, which the room already watches.
class GameMoveSnapshot {
  const GameMoveSnapshot({
    required this.matchId,
    required this.game,
    required this.seq,
    required this.seat,
    required this.move,
    required this.state,
  });

  final String matchId;

  /// Registry id: `tictactoe`, `connectfour`, `reversi`, `checkers`, `dots`,
  /// `chess`.
  final String game;

  /// The game's seq right after this move: move number [seq].
  final int seq;

  /// The seat that moved.
  final int seat;

  /// The encoded move token.
  final String move;

  /// The encoded position after the move.
  final String state;

  /// Null for anything the server could not have written.
  static GameMoveSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final matchId = raw['matchId'];
    final game = raw['game'];
    final seq = raw['seq'];
    final seat = raw['seat'];
    final move = raw['move'];
    final state = raw['state'];
    if (matchId is! String ||
        game is! String ||
        seq is! num ||
        seat is! num ||
        move is! String ||
        state is! String) {
      return null;
    }
    return GameMoveSnapshot(
      matchId: matchId,
      game: game,
      seq: seq.toInt(),
      seat: seat.toInt(),
      move: move,
      state: state,
    );
  }

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'game': game,
    'seq': seq,
    'seat': seat,
    'move': move,
    'state': state,
  };
}
