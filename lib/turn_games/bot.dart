/// The one bot every turn game plays against: a generic alpha-beta search over
/// [TurnRules] + [TurnEvaluator], tuned per game and level in `registry.dart`.
///
/// Nothing in here knows a single game. That is the point: a game earns a bot
/// by implementing the rules contract and a scoring function, and every fix
/// to the search lands in all of them at once.
///
/// ## How it searches
///
/// Minimax where a node maximises iff it is the root seat's turn. That rule,
/// rather than strict alternation, is what makes extra turns (Dots and Boxes)
/// and forced passes (Reversi) come out right with no special casing, and
/// with more than two seats it is "paranoid" minimax: everyone else is assumed
/// to be against the bot. Every score is from the root seat's side.
///
/// Iterative deepening under a wall-clock budget and a node cap, so a level
/// is "think this long" rather than "this deep" and a slow phone gets a
/// shallower bot instead of a frozen one. An iteration that runs out is thrown
/// away whole and the previous depth's answer stands. An iteration in which
/// no leaf was cut off by depth has solved the position, and deepening stops.
///
/// A transposition table keyed by `encode(state)`, bounded and simply cleared
/// when it fills. Terminal scores are `winScore - ply`, so the bot takes the
/// fastest win and drags out a loss; the table stores them relative to the
/// node so a hit at another ply still reads true.
///
/// ## How it plays badly on purpose
///
/// Weaker levels are the same search with a shallower depth, random noise on
/// the root scores, and a chance to pick among the top few (or any) moves.
/// Two guards sit above all that: an immediate win is always taken (unless a
/// level's [BotConfig.winRate] says otherwise — easy tic-tac-toe), and with
/// [BotConfig.blockLosses] a move that hands the opponent a win next turn is
/// never chosen while a safe one exists. Losing to a bot that blundered on
/// purpose feels fine; losing to one that ignored a win in one feels broken.
library;

import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'registry.dart';
import 'turn_rules.dart';

enum BotLevel { easy, medium, hard }

/// One level of one game's bot.
class BotConfig<S, M> {
  const BotConfig({
    required this.maxDepth,
    required this.budgetMs,
    this.nodeCap = 1000000,
    this.noise = 0,
    this.blunderRate = 0,
    this.blunderTopK = 0,
    this.winRate = 1,
    this.blockLosses = true,
    this.evaluator,
    this.solveWhen,
    this.solveBudgetMs,
  });

  /// Deepest iteration, in plies.
  final int maxDepth;

  /// Wall-clock budget for the whole search. Halved on web.
  final int budgetMs;

  /// Nodes before the search stops deepening, whatever the clock says.
  final int nodeCap;

  /// Each root move's score is moved by up to ± this, uniformly. Zero keeps
  /// the search exact; anything else makes it score every root move fully.
  final double noise;

  /// Chance of ignoring the best move for a random one among the top
  /// [blunderTopK] (or among all candidates when that is 0).
  final double blunderRate;
  final int blunderTopK;

  /// Chance of taking an available immediate win. 1 everywhere but the
  /// easiest levels: missing a win in one reads as a bug, not as weakness.
  final double winRate;

  /// Never pick a move that lets the next player win at once while another
  /// move would not.
  final bool blockLosses;

  /// Replaces the game's evaluator at this level, for a level that should
  /// see the board more simply (Reversi's medium only knows square weights).
  final TurnEvaluator<S, M>? evaluator;

  /// When true for the root position, search to the end: no depth limit, no
  /// noise, no blunders, and [solveBudgetMs] instead of [budgetMs]. Reversi
  /// uses it for the last ten empties, where exact play is affordable and a
  /// heuristic is at its worst.
  final bool Function(S state)? solveWhen;
  final int? solveBudgetMs;
}

/// What a search found, for tests and timing. [score] is the chosen move's
/// root score before noise; [exact] means the position was solved.
class BotSearchResult<M> {
  const BotSearchResult({
    required this.move,
    required this.score,
    required this.depth,
    required this.nodes,
    required this.elapsedMs,
    required this.exact,
  });

  final M move;
  final double score;
  final int depth;
  final int nodes;
  final int elapsedMs;
  final bool exact;

  @override
  String toString() =>
      'BotSearchResult(move: $move, score: $score, depth: $depth, '
      'nodes: $nodes, ${elapsedMs}ms, exact: $exact)';
}

/// The bot's move for [state] in game [gameId], encoded for the wire.
///
/// Off the UI isolate on native. Web has no isolates to spawn, so there the
/// search runs inline after one event-loop turn (so a "thinking…" frame can
/// paint first) with half the budget, since every millisecond of it is a
/// frozen page.
Future<String> pickBotMove({
  required String gameId,
  required String state,
  required BotLevel level,
  int? seed,
}) async {
  final s = seed ?? DateTime.now().microsecondsSinceEpoch;
  if (kIsWeb) {
    await Future<void>.delayed(Duration.zero);
    return pickBotMoveSync(
      gameId: gameId,
      state: state,
      level: level,
      seed: s,
      budgetScale: 0.5,
    );
  }
  return Isolate.run(
    () => pickBotMoveSync(gameId: gameId, state: state, level: level, seed: s),
  );
}

/// [pickBotMove] without the isolate, for tests and for the isolate itself.
/// Throws [ArgumentError] for an unknown game and [StateError] for a finished
/// position.
String pickBotMoveSync({
  required String gameId,
  required String state,
  required BotLevel level,
  required int seed,
  double budgetScale = 1,
}) {
  final game = turnGameFor(gameId);
  if (game == null) throw ArgumentError.value(gameId, 'gameId', 'unknown');
  return game.botMove(state, level, Random(seed), budgetScale: budgetScale);
}

/// The move the bot would play. Deterministic for a given [random] seed as
/// long as the clock does not cut the search short — tests that need exact
/// answers give it a budget it cannot hit.
M searchBest<S, M>({
  required TurnRules<S, M> rules,
  required TurnEvaluator<S, M> evaluator,
  required S state,
  required BotConfig<S, M> config,
  required Random random,
  double budgetScale = 1,
}) =>
    searchBotMove(
      rules: rules,
      evaluator: evaluator,
      state: state,
      config: config,
      random: random,
      budgetScale: budgetScale,
    ).move;

/// [searchBest], with the numbers behind the choice.
BotSearchResult<M> searchBotMove<S, M>({
  required TurnRules<S, M> rules,
  required TurnEvaluator<S, M> evaluator,
  required S state,
  required BotConfig<S, M> config,
  required Random random,
  double budgetScale = 1,
}) {
  final clock = Stopwatch()..start();
  final moves = rules.legalMoves(state);
  if (moves.isEmpty) throw StateError('no legal move: game over');
  final me = rules.toMove(state);
  BotSearchResult<M> done(int i, double score, int depth, int nodes, bool ex) =>
      BotSearchResult(
        move: moves[i],
        score: score,
        depth: depth,
        nodes: nodes,
        elapsedMs: clock.elapsedMilliseconds,
        exact: ex,
      );
  if (moves.length == 1) return done(0, 0, 0, 0, false);

  final children = [for (final m in moves) rules.apply(state, m)];

  // An immediate win, whatever the level.
  final wins = [
    for (var i = 0; i < moves.length; i++)
      if (rules.outcome(children[i])?.winner == me) i,
  ];
  if (wins.isNotEmpty && random.nextDouble() < config.winRate) {
    final i = wins[random.nextInt(wins.length)];
    return done(i, TurnEvaluator.winScore - 1, 1, moves.length, true);
  }

  // Never hand over a win in one while a move exists that does not.
  var candidates = [for (var i = 0; i < moves.length; i++) i];
  if (config.blockLosses) {
    final safe = [
      for (final i in candidates)
        if (!_handsOverWin(rules, children[i], me)) i,
    ];
    if (safe.isNotEmpty) candidates = safe;
  }

  final solve = config.solveWhen?.call(state) ?? false;
  final noise = solve ? 0.0 : config.noise;
  final blunderRate = solve ? 0.0 : config.blunderRate;
  final budget =
      ((solve ? config.solveBudgetMs ?? config.budgetMs : config.budgetMs) *
              budgetScale)
          .round();
  final search = _Search<S, M>(
    rules: rules,
    evaluator: config.evaluator ?? evaluator,
    me: me,
    clock: clock,
    budgetMs: budget,
    nodeCap: (config.nodeCap * budgetScale).round(),
  );
  final maxDepth = solve ? 1 << 20 : config.maxDepth;
  // Noise and blunders compare every root move, so each needs a true score,
  // not the bound a narrowed window would give it.
  final fullWindow = noise > 0 || blunderRate > 0;

  // Root order: the evaluator's guess first, then each finished iteration's.
  var order = <int>[];
  {
    final candidateMoves = [for (final i in candidates) moves[i]];
    for (final m in search.evaluator.order(state, candidateMoves)) {
      final i = _indexOf(moves, m);
      if (i >= 0 && candidates.contains(i) && !order.contains(i)) order.add(i);
    }
    for (final i in candidates) {
      if (!order.contains(i)) order.add(i);
    }
  }

  List<double>? scores;
  var reached = 0;
  var exact = false;
  for (var depth = 1; depth <= maxDepth; depth++) {
    search
      ..canAbort = depth > 1
      ..cut = false;
    final iter = List<double>.filled(moves.length, double.negativeInfinity);
    try {
      var alpha = double.negativeInfinity;
      for (final i in order) {
        final v = search.minimax(
          children[i],
          depth - 1,
          1,
          fullWindow ? double.negativeInfinity : alpha,
          double.infinity,
        );
        iter[i] = v;
        if (v > alpha) alpha = v;
      }
    } on _OutOfBudget {
      break;
    }
    scores = iter;
    reached = depth;
    exact = !search.cut;
    // Stable: equal scores keep last iteration's order.
    order = [...order]..sort((a, b) => iter[b].compareTo(iter[a]));
    final best = iter[order.first];
    if (exact) break;
    // A proven result does not change with depth: a win found is the
    // fastest one, and when even the best move loses, all of them do.
    if (best.abs() > TurnEvaluator.winScore / 2) break;
    if (search.outOfTime()) break;
  }
  final s = scores!;

  // Pick: best by (noisy) score, or on a blunder one of the top few.
  final noisy = <int, double>{
    for (final i in order)
      i: s[i] + (noise > 0 ? (random.nextDouble() * 2 - 1) * noise : 0),
  };
  final ranked = [...order]..sort((a, b) => noisy[b]!.compareTo(noisy[a]!));
  var pick = ranked.first;
  if (blunderRate > 0 && random.nextDouble() < blunderRate) {
    final k = config.blunderTopK <= 0
        ? ranked.length
        : min(config.blunderTopK, ranked.length);
    pick = ranked[random.nextInt(k)];
  }
  return done(pick, s[pick], reached, search.nodes, exact);
}

/// Whether, after the root seat moved into [child], the next player (someone
/// else) has a move that wins on the spot.
bool _handsOverWin<S, M>(TurnRules<S, M> rules, S child, int me) {
  if (rules.outcome(child) != null) return false;
  final next = rules.toMove(child);
  if (next == me) return false;
  for (final r in rules.legalMoves(child)) {
    final w = rules.outcome(rules.apply(child, r))?.winner;
    if (w != null && w != me) return true;
  }
  return false;
}

int _indexOf<M>(List<M> moves, M m) {
  for (var i = 0; i < moves.length; i++) {
    if (identical(moves[i], m)) return i;
  }
  return moves.indexOf(m);
}

class _OutOfBudget implements Exception {
  const _OutOfBudget();
}

const _exactFlag = 0;
const _lowerFlag = 1;
const _upperFlag = 2;

class _Entry {
  _Entry(this.depth, this.value, this.flag, this.best, this.cut);

  final int depth;
  final double value;
  final int flag;
  final Object? best;

  /// Whether any leaf under this entry was cut off by depth — so a hit tells
  /// the iteration it is not exact yet.
  final bool cut;
}

class _Search<S, M> {
  _Search({
    required this.rules,
    required this.evaluator,
    required this.me,
    required this.clock,
    required this.budgetMs,
    required this.nodeCap,
  });

  /// Entries before the table is cleared. ~100 bytes of key each for the
  /// largest boards, so this stays a few tens of MB at worst.
  static const ttCap = 200000;

  static const _win = TurnEvaluator.winScore;

  final TurnRules<S, M> rules;
  final TurnEvaluator<S, M> evaluator;
  final int me;
  final Stopwatch clock;
  final int budgetMs;
  final int nodeCap;
  final _tt = <String, _Entry>{};

  int nodes = 0;
  bool canAbort = false;

  /// Set when a leaf is scored by the evaluator rather than by an outcome.
  bool cut = false;

  bool outOfTime() =>
      clock.elapsedMilliseconds >= budgetMs || nodes >= nodeCap;

  double _terminal(TurnOutcome o, int ply) {
    final w = o.winner;
    if (w == null) return 0;
    return w == me ? _win - ply : -(_win - ply);
  }

  /// Win/loss scores carry their distance from the root; the table holds
  /// them as distance from the node instead.
  static double _toTable(double v, int ply) =>
      v > _win / 2 ? v + ply : (v < -_win / 2 ? v - ply : v);

  static double _fromTable(double v, int ply) =>
      v > _win / 2 ? v - ply : (v < -_win / 2 ? v + ply : v);

  double minimax(S state, int depth, int ply, double alpha, double beta) {
    nodes++;
    if (canAbort && (nodes >= nodeCap || (nodes & 255) == 0 && outOfTime())) {
      throw const _OutOfBudget();
    }
    final o = rules.outcome(state);
    if (o != null) return _terminal(o, ply);
    if (depth <= 0) {
      cut = true;
      return evaluator.evaluateBounded(state, me, alpha, beta);
    }

    // The table only pays for itself away from the horizon, where a node
    // has a subtree worth not searching twice.
    final key = depth >= 2 ? rules.encode(state) : null;
    Object? hint;
    if (key != null) {
      final e = _tt[key];
      if (e != null) {
        hint = e.best;
        if (e.depth >= depth) {
          final v = _fromTable(e.value, ply);
          if (e.flag == _exactFlag ||
              e.flag == _lowerFlag && v >= beta ||
              e.flag == _upperFlag && v <= alpha) {
            if (e.cut) cut = true;
            return v;
          }
        }
      }
    }

    final alpha0 = alpha;
    final beta0 = beta;
    final outerCut = cut;
    cut = false;
    var moves = evaluator.order(state, rules.legalMoves(state));
    if (hint != null) {
      final i = moves.indexWhere((m) => m == hint);
      if (i > 0) moves = [moves[i], ...moves.take(i), ...moves.skip(i + 1)];
    }
    final maximising = rules.toMove(state) == me;
    var best = maximising ? double.negativeInfinity : double.infinity;
    M? bestMove;
    for (final m in moves) {
      final v = minimax(rules.apply(state, m), depth - 1, ply + 1, alpha, beta);
      if (maximising) {
        if (v > best) {
          best = v;
          bestMove = m;
        }
        if (best > alpha) alpha = best;
      } else {
        if (v < best) {
          best = v;
          bestMove = m;
        }
        if (best < beta) beta = best;
      }
      if (alpha >= beta) break;
    }

    final subtreeCut = cut;
    cut = outerCut || subtreeCut;
    if (key != null) {
      if (_tt.length >= ttCap) _tt.clear();
      final flag = best <= alpha0
          ? _upperFlag
          : best >= beta0
          ? _lowerFlag
          : _exactFlag;
      _tt[key] = _Entry(depth, _toTable(best, ply), flag, bestMove, subtreeCut);
    }
    return best;
  }
}
