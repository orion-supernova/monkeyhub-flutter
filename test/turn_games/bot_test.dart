import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/bot.dart';
import 'package:monkeyhub/turn_games/connect_four.dart';
import 'package:monkeyhub/turn_games/registry.dart';
import 'package:monkeyhub/turn_games/reversi.dart';
import 'package:monkeyhub/turn_games/tic_tac_toe.dart';

/// The generic bot, held to the promises each level makes: hard tic-tac-toe
/// never loses, nobody misses a win in one, medium and up always block one,
/// hard beats easy, and the clock is respected.
///
/// Every search here is seeded. The ones that assert exact moves run with a
/// budget they cannot reach, so the answer never depends on machine speed.
void main() {
  group('tic-tac-toe', () {
    const game = ticTacToeGame;
    const rules = ticTacToeRules;

    /// Walks every line the opponent could play against the hard bot,
    /// returning the outcomes reached. Bot positions are cached, so this is
    /// one search per distinct position rather than per line.
    Set<String> allOutcomes(int botSeat) {
      final reached = <String>{};
      final cache = <String, int>{};
      void walk(TicTacToeState s) {
        final o = rules.outcome(s);
        if (o != null) {
          reached.add(
            o.winner == null
                ? 'draw'
                : o.winner == botSeat
                ? 'win'
                : 'loss',
          );
          return;
        }
        if (rules.toMove(s) == botSeat) {
          final key = rules.encode(s);
          final m = cache[key] ??= game.botSearch(
            s,
            BotLevel.hard,
            Random(7),
          ).move;
          walk(rules.apply(s, m));
        } else {
          for (final m in rules.legalMoves(s)) {
            walk(rules.apply(s, m));
          }
        }
      }

      walk(rules.initial(2));
      return reached;
    }

    test('hard never loses, as X or as O, against every line', () {
      expect(allOutcomes(0), isNot(contains('loss')));
      expect(allOutcomes(1), isNot(contains('loss')));
    });

    test('hard solves the opening exactly', () {
      final r = game.botSearch(rules.initial(2), BotLevel.hard, Random(1));
      expect(r.exact, isTrue);
      expect(r.score, 0, reason: 'perfect play is a draw');
    });

    test('medium always takes a win and always blocks', () {
      // X: 0 1 _, O: 3 4 _. X to move wins at 2.
      final win = rules.decode('XX.OO..../0');
      // O to move, with no line of its own, must block X at 2.
      final block = rules.decode('XX.O...../1');
      for (var seed = 0; seed < 50; seed++) {
        expect(game.botSearch(win, BotLevel.medium, Random(seed)).move, 2);
        expect(game.botSearch(block, BotLevel.medium, Random(seed)).move, 2);
      }
    });

    test('easy is not perfect: it misses a block some of the time', () {
      final block = rules.decode('XX.O...../1');
      final picks = {
        for (var seed = 0; seed < 50; seed++)
          game.botSearch(block, BotLevel.easy, Random(seed)).move,
      };
      expect(picks.length, greaterThan(1));
    });
  });

  group('connect four', () {
    const game = connectFourGame;
    const rules = connectFourRules;

    ConnectFourState play(List<int> moves) {
      var s = rules.initial(2);
      for (final m in moves) {
        s = rules.apply(s, m);
      }
      return s;
    }

    test('every level takes a win in one', () {
      // X has 0 1 2 on the bottom row and moves.
      final s = play([0, 6, 1, 6, 2, 5]);
      for (final level in BotLevel.values) {
        for (var seed = 0; seed < 10; seed++) {
          expect(
            game.botSearch(s, level, Random(seed)).move,
            3,
            reason: '$level seed $seed',
          );
        }
      }
    });

    test('medium and hard block a loss in one', () {
      // X has 0 1 2 on the bottom row; O to move must take 3.
      final s = play([0, 6, 1, 6, 2]);
      for (final level in [BotLevel.medium, BotLevel.hard]) {
        for (var seed = 0; seed < 4; seed++) {
          // The block is a guard above the search, so a short clock is fine.
          expect(
            game.botSearch(s, level, Random(seed), budgetScale: 0.1).move,
            3,
            reason: '$level seed $seed',
          );
        }
      }
    });

    test('a win beats a block', () {
      // O to move: X threatens 3 on the bottom row, O can finish column 6.
      final s = play([0, 6, 1, 6, 2, 6, 5]);
      expect(game.botSearch(s, BotLevel.hard, Random(0)).move, 6);
    });

    test('hard stays within its 400 ms budget', () {
      final r = game.botSearch(rules.initial(2), BotLevel.hard, Random(0));
      // ignore: avoid_print
      print('connectfour hard from the opening: $r');
      expect(r.elapsedMs, lessThan(400 + 100));
      expect(r.depth, greaterThanOrEqualTo(6));
      expect(r.move, 3, reason: 'the centre is the only sound opening');
    });

    test('hard beats easy in most seeded games', () {
      const n = 6;
      var hardWins = 0;
      for (var g = 0; g < n; g++) {
        final hardSeat = g % 2;
        final random = Random(100 + g);
        var s = rules.initial(2);
        while (rules.outcome(s) == null) {
          final level = rules.toMove(s) == hardSeat
              ? BotLevel.hard
              : BotLevel.easy;
          // A tenth of the budget keeps the suite fast; easy is still weaker.
          final m = game.botSearch(s, level, random, budgetScale: 0.1).move;
          s = rules.apply(s, m);
        }
        if (rules.outcome(s)!.winner == hardSeat) hardWins++;
      }
      expect(hardWins, greaterThanOrEqualTo(n - 1));
    });
  });

  group('reversi', () {
    const game = reversiGame;
    const rules = reversiRules;

    ReversiState playout(int plies, int seed) {
      final random = Random(seed);
      var s = rules.initial(2);
      for (var i = 0; i < plies && rules.outcome(s) == null; i++) {
        final moves = rules.legalMoves(s);
        s = rules.apply(s, moves[random.nextInt(moves.length)]);
      }
      return s;
    }

    test('hard stays within its 700 ms budget in the middlegame', () {
      final s = playout(20, 3);
      final r = game.botSearch(s, BotLevel.hard, Random(0));
      // ignore: avoid_print
      print('reversi hard, 20 plies in: $r');
      expect(r.elapsedMs, lessThan(700 + 150));
      expect(r.depth, greaterThanOrEqualTo(4));
    });

    test('hard solves the last ten empties exactly', () {
      final random = Random(5);
      var s = rules.initial(2);
      while (rules.outcome(s) == null && reversiEmpties(s) > 10) {
        final moves = rules.legalMoves(s);
        s = rules.apply(s, moves[random.nextInt(moves.length)]);
      }
      expect(rules.outcome(s), isNull);
      final r = game.botSearch(s, BotLevel.hard, Random(0));
      // ignore: avoid_print
      print('reversi hard endgame, ${reversiEmpties(s)} empties: $r');
      expect(r.exact, isTrue);
      expect(r.elapsedMs, lessThan(1500 + 150));
    });

    test('hard beats easy in most seeded games', () {
      const n = 3;
      var hardWins = 0;
      for (var g = 0; g < n; g++) {
        final hardSeat = g % 2;
        final random = Random(200 + g);
        var s = rules.initial(2);
        while (rules.outcome(s) == null) {
          final level = rules.toMove(s) == hardSeat
              ? BotLevel.hard
              : BotLevel.easy;
          final m = game.botSearch(s, level, random, budgetScale: 0.03).move;
          s = rules.apply(s, m);
        }
        if (rules.outcome(s)!.winner == hardSeat) hardWins++;
      }
      expect(hardWins, greaterThanOrEqualTo(n - 1));
    });
  });

  group('the public API', () {
    test('pickBotMove runs in an isolate and returns a wire move', () async {
      final move = await pickBotMove(
        gameId: 'connectfour',
        state: connectFourRules.encode(connectFourRules.initial(2)),
        level: BotLevel.medium,
        seed: 1,
      );
      expect(['0', '1', '2', '3', '4', '5', '6'], contains(move));
    });

    test('every registered game has every level, and the bot can move', () {
      for (final game in turnGames.values) {
        expect(game.levels.keys.toSet(), BotLevel.values.toSet());
        final s = game.rules.initial(game.rules.minSeats);
        final raw = game.rules.encode(s);
        for (final level in BotLevel.values) {
          final move = pickBotMoveSync(
            gameId: game.id,
            state: raw,
            level: level,
            seed: 3,
            budgetScale: 0.1,
          );
          final legal = game.rules.legalMoves(game.rules.decode(raw));
          expect(
            legal.map(game.rules.encodeMove),
            contains(move),
            reason: '${game.id} $level',
          );
        }
      }
    });

    test('unknown games and finished positions are refused', () {
      expect(
        () => pickBotMoveSync(
          gameId: 'nope',
          state: '',
          level: BotLevel.easy,
          seed: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => pickBotMoveSync(
          gameId: 'tictactoe',
          state: 'XXXOO..../1',
          level: BotLevel.easy,
          seed: 0,
        ),
        throwsStateError,
      );
    });
  });
}
