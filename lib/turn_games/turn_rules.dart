/// The contract every in-chat turn game implements — the Dart mirror of
/// `backend/convex/turnGames/types.ts`.
///
/// The server decides what is legal. This side exists so a tap can draw before
/// the round trip lands, and so a bot can search a position with no network at
/// all. Both mirrors replay `test/fixtures/turn_games/<id>.json`, and drifting
/// from the server is a real bug: a move drawn here that `matches:move` then
/// refuses snaps back under the player's finger.
///
/// [S] is the decoded position and [M] a decoded move. The bot works in those
/// types throughout — parsing a string per searched node would spend the search
/// budget on string handling — and only [encodeMove] / [decodeMove] cross the
/// wire.
library;

/// How a finished game ended. [winner] is a seat index, or null for a draw.
class TurnOutcome {
  const TurnOutcome({required this.winner, required this.reason});

  final int? winner;
  final String reason;

  bool get isDraw => winner == null;
}

/// Thrown by [TurnRules.apply] for a move [TurnRules.legalMoves] would not list.
class IllegalMove implements Exception {
  const IllegalMove([this.detail = '']);

  final String detail;

  @override
  String toString() => 'IllegalMove($detail)';
}

abstract class TurnRules<S, M> {
  const TurnRules();

  /// Wire id, matching the TS module and the fixture file name.
  String get id;
  int get minSeats;
  int get maxSeats;

  S initial(int seats);

  /// Whose turn it is. Extra turns and forced passes are already folded in.
  int toMove(S state);

  /// Every legal move, in the same stable order as the TS mirror.
  List<M> legalMoves(S state);

  /// The position after [move]. Pure; never mutates [state]. Throws
  /// [IllegalMove] for anything [legalMoves] would not list.
  S apply(S state, M move);

  /// Null while the game is still going.
  TurnOutcome? outcome(S state);

  String encode(S state);

  /// Throws [FormatException] on anything [encode] could not have produced.
  S decode(String raw);

  String encodeMove(M move);
  M decodeMove(String raw);
}

/// What the bot needs on top of the rules: a score for a position, from
/// [seat]'s point of view, and optionally a move ordering that makes
/// alpha-beta prune earlier.
///
/// A win must score above every non-terminal position and a loss below — the
/// search adds depth to terminal scores itself, so return [winScore] /
/// `-winScore` flat and it will still prefer the faster win.
abstract class TurnEvaluator<S, M> {
  const TurnEvaluator();

  static const double winScore = 1e9;

  double evaluate(S state, int seat);

  /// [evaluate] for a search that only needs to know where the score falls
  /// against ([alpha], [beta]), both from [seat]'s side: anything at or below
  /// alpha may come back as any value <= alpha, and likewise above beta. The
  /// default ignores the window. An evaluator that searches on its own (chess
  /// runs a capture search at the horizon) overrides it to prune that search.
  double evaluateBounded(S state, int seat, double alpha, double beta) =>
      evaluate(state, seat);

  /// Best-first guess at move order. The default leaves [moves] alone.
  List<M> order(S state, List<M> moves) => moves;
}
