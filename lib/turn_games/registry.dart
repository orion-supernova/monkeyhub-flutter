/// Every turn game the app knows, by wire id: its rules, its evaluator, and
/// how hard each bot level tries.
///
/// The Dart side of `backend/convex/turnGames/registry.ts`. The ids must match
/// it exactly — they are what a match row and a fixture file are named by.
///
/// The bot is generic (`bot.dart`); everything game-specific about it lives
/// here as numbers. Noise is in the evaluator's own units, so it reads
/// differently per game: tic-tac-toe scores a handful per line, Connect Four
/// a few per window, Reversi, checkers and Dots tens to hundreds.
library;

import 'dart:math';

import 'bot.dart';
import 'checkers.dart';
import 'chess.dart';
import 'connect_four.dart';
import 'dots.dart';
import 'reversi.dart';
import 'tic_tac_toe.dart';
import 'turn_rules.dart';

/// One game: rules, evaluator and per-level bot settings, with [S] and [M]
/// kept together so the registry's `dynamic` view never has to cast them.
class TurnGame<S, M> {
  const TurnGame({
    required this.rules,
    required this.evaluator,
    required this.levels,
    this.searchRules,
  });

  final TurnRules<S, M> rules;

  /// What the bot searches with, when that is not [rules]: the same game,
  /// the same wire format and the same answers (both replay the server's
  /// fixtures), only faster. Chess uses it to search on a lean move
  /// generator while the screens keep the rules of record.
  final TurnRules<S, M>? searchRules;
  final TurnEvaluator<S, M> evaluator;
  final Map<BotLevel, BotConfig<S, M>> levels;

  String get id => rules.id;

  // ── The wire view ─────────────────────────────────────────────────────────
  //
  // Screens hold positions and moves as the strings the server stores. These
  // decode, act, and re-encode inside this class, at the game's real types,
  // so nothing outside ever handles an `S` or an `M` through `dynamic`.

  /// The opening position for [seats] players, encoded.
  String initialEncoded(int seats) => rules.encode(rules.initial(seats));

  /// [state] after [move], encoded. Throws [IllegalMove] or
  /// [FormatException] exactly as the rules do.
  String applyEncoded(String state, String move) => rules.encode(
    rules.apply(rules.decode(state), rules.decodeMove(move)),
  );

  /// Whose turn it is in [state].
  int toMoveEncoded(String state) => rules.toMove(rules.decode(state));

  /// How [state] ended, or null while it is still going.
  TurnOutcome? outcomeEncoded(String state) =>
      rules.outcome(rules.decode(state));

  /// Every legal move in [state], encoded.
  List<String> legalEncoded(String state) => [
    for (final m in rules.legalMoves(rules.decode(state))) rules.encodeMove(m),
  ];

  /// The bot's encoded move for an encoded [state]. Runs inside this class so
  /// the search is instantiated at the game's real types.
  String botMove(
    String state,
    BotLevel level,
    Random random, {
    double budgetScale = 1,
  }) {
    final search = searchRules ?? rules;
    final move = searchBest(
      rules: search,
      evaluator: evaluator,
      state: search.decode(state),
      config: levels[level]!,
      random: random,
      budgetScale: budgetScale,
    );
    return search.encodeMove(move);
  }

  /// [botMove] with the search stats, for tests and tuning.
  BotSearchResult<M> botSearch(
    S state,
    BotLevel level,
    Random random, {
    double budgetScale = 1,
  }) =>
      searchBotMove(
        rules: searchRules ?? rules,
        evaluator: evaluator,
        state: state,
        config: levels[level]!,
        random: random,
        budgetScale: budgetScale,
      );
}

bool _reversiEndgame(ReversiState state) => reversiEmpties(state) <= 10;

const ticTacToeGame = TurnGame<TicTacToeState, int>(
  rules: ticTacToeRules,
  evaluator: ticTacToeEvaluator,
  levels: {
    // Mostly random, and only takes a win about three times in four.
    BotLevel.easy: BotConfig(
      maxDepth: 1,
      budgetMs: 50,
      noise: 4,
      blunderRate: 0.5,
      winRate: 0.5,
      blockLosses: false,
    ),
    // Always wins and blocks; otherwise one ply of "open lines" plus noise,
    // which is random with a lean towards the centre.
    BotLevel.medium: BotConfig(maxDepth: 1, budgetMs: 50, noise: 1.5),
    // The whole tree. The noise is far below the 1-point gap between a win
    // and the next-fastest one, so it only chooses among equally good moves.
    BotLevel.hard: BotConfig(
      maxDepth: 9,
      budgetMs: 2000,
      nodeCap: 5000000,
      noise: 0.01,
    ),
  },
);

const connectFourGame = TurnGame<ConnectFourState, int>(
  rules: connectFourRules,
  evaluator: connectFourEvaluator,
  levels: {
    BotLevel.easy: BotConfig(
      maxDepth: 2,
      budgetMs: 100,
      nodeCap: 50000,
      noise: 8,
      blunderRate: 0.2,
      blunderTopK: 3,
      blockLosses: false,
    ),
    BotLevel.medium: BotConfig(
      maxDepth: 6,
      budgetMs: 300,
      nodeCap: 500000,
      noise: 1,
      blunderRate: 0.05,
      blunderTopK: 2,
    ),
    BotLevel.hard: BotConfig(maxDepth: 42, budgetMs: 400, nodeCap: 3000000),
  },
);

const reversiGame = TurnGame<ReversiState, int>(
  rules: reversiRules,
  evaluator: reversiEvaluator,
  levels: {
    // Square weights plus heavy noise: a weighted random that still likes
    // corners and shies away from X-squares.
    BotLevel.easy: BotConfig(
      maxDepth: 1,
      budgetMs: 50,
      noise: 60,
      blunderRate: 0.3,
      blockLosses: false,
      evaluator: reversiPositionalEvaluator,
    ),
    BotLevel.medium: BotConfig(
      maxDepth: 4,
      budgetMs: 400,
      nodeCap: 500000,
      noise: 3,
      blunderRate: 0.05,
      blunderTopK: 2,
      evaluator: reversiPositionalEvaluator,
    ),
    BotLevel.hard: BotConfig(
      maxDepth: 60,
      budgetMs: 700,
      nodeCap: 3000000,
      solveWhen: _reversiEndgame,
      solveBudgetMs: 1500,
    ),
  },
);

const checkersGame = TurnGame<CheckersState, CheckersMove>(
  rules: checkersRules,
  evaluator: checkersEvaluator,
  levels: {
    BotLevel.easy: BotConfig(
      maxDepth: 2,
      budgetMs: 100,
      nodeCap: 50000,
      noise: 60,
      blunderRate: 0.2,
      blunderTopK: 3,
      blockLosses: false,
    ),
    BotLevel.medium: BotConfig(
      maxDepth: 6,
      budgetMs: 400,
      nodeCap: 500000,
      noise: 5,
      blunderRate: 0.05,
      blunderTopK: 2,
    ),
    BotLevel.hard: BotConfig(maxDepth: 40, budgetMs: 700, nodeCap: 3000000),
  },
);

const dotsGame = TurnGame<DotsState, int>(
  rules: dotsRules,
  evaluator: dotsEvaluator,
  levels: {
    BotLevel.easy: BotConfig(
      maxDepth: 1,
      budgetMs: 100,
      nodeCap: 50000,
      noise: 80,
      blunderRate: 0.25,
      blunderTopK: 3,
      blockLosses: false,
    ),
    BotLevel.medium: BotConfig(
      maxDepth: 4,
      budgetMs: 400,
      nodeCap: 500000,
      noise: 5,
      blunderRate: 0.05,
      blunderTopK: 2,
    ),
    BotLevel.hard: BotConfig(maxDepth: 40, budgetMs: 700, nodeCap: 3000000),
  },
);

/// Chess searches the lean engine ([chessEngineRules]); every leaf runs a
/// capture search, so even two plies see an exchange through.
///
/// Measured in `flutter test` (desktop JIT) on an Italian-game middlegame:
/// easy finishes depth 2 in ~10 ms; medium depth 3 in ~120 ms; hard reaches
/// depth 5 inside its second at ~100k nodes/s (capture-search nodes not
/// counted). A mid-range phone runs maybe half that speed, so hard is depth
/// 4 to 5 there, and the web (half budget, no isolate) about 4. Strength is
/// an estimate, never rated: easy is a beginner who takes what hangs and
/// hangs things; medium a casual player who rarely drops material; hard a
/// solid club player in tactics (very roughly 1400-1700) with no opening
/// book and a thin endgame.
const chessGame = TurnGame<ChessState, int>(
  rules: chessRules,
  searchRules: chessEngineRules,
  evaluator: chessEvaluator,
  levels: {
    // Two plies plus the capture search, then up to a pawn and a half of
    // noise and a one-in-four chance of any of the top four: it takes
    // what is hanging, and leaves things hanging.
    BotLevel.easy: BotConfig(
      maxDepth: 2,
      budgetMs: 150,
      nodeCap: 20000,
      noise: 150,
      blunderRate: 0.25,
      blunderTopK: 4,
      blockLosses: false,
    ),
    BotLevel.medium: BotConfig(
      maxDepth: 3,
      budgetMs: 600,
      nodeCap: 200000,
      noise: 15,
      blunderRate: 0.05,
      blunderTopK: 2,
    ),
    BotLevel.hard: BotConfig(maxDepth: 30, budgetMs: 1000, nodeCap: 3000000),
  },
);

const turnGames = <String, TurnGame<dynamic, dynamic>>{
  'tictactoe': ticTacToeGame,
  'connectfour': connectFourGame,
  'reversi': reversiGame,
  'checkers': checkersGame,
  'dots': dotsGame,
  'chess': chessGame,
};

/// The game for [id], or null for one this build does not know.
TurnGame<dynamic, dynamic>? turnGameFor(String id) => turnGames[id];
