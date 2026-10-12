import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/bot.dart';
import 'package:monkeyhub/turn_games/chess.dart';
import 'package:monkeyhub/turn_games/registry.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

import 'fixture_replay.dart';

/// The Dart chess mirrors, checked against the server's own playouts
/// (`test/fixtures/turn_games/chess.json`, written by chess.js through
/// `backend/tools/turn-fixtures.ts`), the lean engine by perft, and the bot.
void main() {
  /// A state from a bare FEN; the clock must be 0 so the history is empty.
  ChessState at(String fen) => chessRules.decode('$fen|');

  List<String> uci(TurnRules<ChessState, int> rules, ChessState s) =>
      rules.legalMoves(s).map(rules.encodeMove).toList();

  group('rules of record (chess package)', () {
    replayTurnFixtures(chessRules);
  });

  group('lean engine', () {
    replayTurnFixtures(chessEngineRules);
  });

  group('perft', () {
    // The standard counts: https://www.chessprogramming.org/Perft_Results
    test('start position, depths 1 to 4', () {
      final s = chessEngineRules.initial(2);
      expect([for (var d = 1; d <= 4; d++) chessEngineRules.perft(s, d)], [
        20,
        400,
        8902,
        197281,
      ]);
    });

    test('Kiwipete, depths 1 to 3', () {
      final s = at(
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      );
      expect([for (var d = 1; d <= 3; d++) chessEngineRules.perft(s, d)], [
        48,
        2039,
        97862,
      ]);
    });

    test('position 3: en passant pins and rook endgames, depths 1 to 4', () {
      final s = at('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
      expect([for (var d = 1; d <= 4; d++) chessEngineRules.perft(s, d)], [
        14,
        191,
        2812,
        43238,
      ]);
    });
  });

  group('rules', () {
    test('both mirrors agree on promotions, castling and en passant', () {
      for (final fen in [
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
        '8/4P3/8/8/8/8/k7/4K3 w - - 0 1',
        'rnbqkbnr/1pp1pppp/p7/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
      ]) {
        final s = at(fen);
        expect(uci(chessEngineRules, s), uci(chessRules, s), reason: fen);
      }
      final promo = at('8/4P3/8/8/8/8/k7/4K3 w - - 0 1');
      expect(
        uci(chessRules, promo).where((m) => m.startsWith('e7e8')),
        ['e7e8b', 'e7e8n', 'e7e8q', 'e7e8r'],
      );
    });

    test('a dead en passant square is dropped, as chess.js drops it', () {
      for (final rules in [chessRules, chessEngineRules]) {
        var s = rules.initial(2);
        s = rules.apply(s, rules.decodeMove('e2e4'));
        expect(s.fen.split(' ')[3], '-');
        // b5xc6 would open the fifth rank to the rook: the pawn is pinned.
        final pin = at('7k/2p5/8/KP5r/8/8/8/8 b - - 0 1');
        final past = rules.apply(pin, rules.decodeMove('c7c5'));
        expect(past.fen.split(' ')[3], '-');
        expect(past.enPassant, isNull);
      }
    });

    test('the streamed repetition hash is the hash of the key string', () {
      final games = jsonDecode(
        File('test/fixtures/turn_games/chess.json').readAsStringSync(),
      ) as List;
      var n = 0;
      for (final g in games) {
        for (final step in g as List) {
          final s = chessEngineRules.decode((step as Map)['state'] as String);
          expect(s.debugStreamHash, s.debugKeyHash, reason: s.fen);
          n++;
        }
      }
      expect(n, greaterThan(1000));
    });

    test('move ints sort like their tokens', () {
      final s = at(
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      );
      final tokens = uci(chessEngineRules, s);
      expect(tokens, [...tokens]..sort());
      expect(chessRules.decodeMove('e7e8q'), chessMove(12, 4, chessQueen));
      expect(chessMoveFrom(chessRules.decodeMove('e2e4')), 52);
      expect(chessMoveTo(chessRules.decodeMove('e2e4')), 36);
      expect(chessSquareName(36), 'e4');
    });

    test('decode refuses what encode could not produce', () {
      const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
      for (final raw in [
        '',
        '$start w KQkq - 0 1',
        '$start w KQkq - 0 1|AAAAA',
        '$start w KQkq - 1 1|',
        '$start w KQkq - 0 01|',
        '$start w KQqk - 0 1|',
        '$start w KQkq e6 0 1|',
        '4k3/8/8/8/8/8/8/4K3 w K - 0 1|',
        '3Qk3/8/8/8/8/8/8/4K3 w - - 0 1|',
        '8/8/8/8/8/8/8/4K3 w - - 0 1|',
        '4k3/8/8/8/8/8/8/44 w - - 0 1|',
        '4k3/8/8/8/8/8/8/4K3 w - - 1 1|AAAA!',
      ]) {
        expect(() => chessRules.decode(raw), throwsFormatException, reason: raw);
      }
      for (final raw in ['', 'e2', 'e2e9', 'e7e8k', 'E2E4', 'e2-e4']) {
        expect(() => chessRules.decodeMove(raw), throwsFormatException, reason: raw);
      }
    });
  });

  group('bot', () {
    final game = turnGameFor('chess')! as TurnGame<ChessState, int>;

    test('finds mate in one at every level', () {
      // Back-rank mate: Rd8#.
      final s = at('6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1');
      for (final level in BotLevel.values) {
        final r = game.botSearch(s, level, Random(7));
        expect(chessRules.encodeMove(r.move), 'd1d8', reason: '$level');
      }
    });

    test('takes a hanging queen and does not hang its own', () {
      final s = at('4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1');
      final r = game.botSearch(s, BotLevel.medium, Random(1));
      expect(chessRules.encodeMove(r.move), 'd2d5');
      // Qxb2?? loses the queen to the rook on b1.
      final t = at('4k3/8/8/8/8/8/1P5q/1R2K3 b - - 0 1');
      for (final level in [BotLevel.medium, BotLevel.hard]) {
        final u = game.botSearch(t, level, Random(1));
        expect(chessRules.encodeMove(u.move), isNot('h2b2'), reason: '$level');
      }
    });

    test('never plays an illegal move, at any level, through a game', () {
      for (final level in BotLevel.values) {
        var s = chessRules.initial(2);
        for (var ply = 0; ply < 12 && chessRules.outcome(s) == null; ply++) {
          final m = game.botMove(chessRules.encode(s), level, Random(ply), budgetScale: 0.2);
          expect(chessRules.legalMoves(s).map(chessRules.encodeMove), contains(m));
          s = chessRules.apply(s, chessRules.decodeMove(m));
        }
      }
    });

    test('respects its budget, and reports its speed', () {
      final s = at(
        'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4',
      );
      for (final level in BotLevel.values) {
        final config = game.levels[level]!;
        final r = game.botSearch(s, level, Random(3));
        // Some slack: an iteration checks the clock every 256 nodes, and the
        // root guards run before the clock starts mattering.
        expect(r.elapsedMs, lessThan(config.budgetMs * 1.6 + 150), reason: '$level');
        // ignore: avoid_print
        print('chess bot $level: depth ${r.depth}, ${r.nodes} nodes in '
            '${r.elapsedMs} ms (${r.elapsedMs == 0 ? '-' : (r.nodes * 1000 / r.elapsedMs).round()} nodes/s)');
      }
    });
  });

  group('evaluator', () {
    test('is symmetric at the opening and counts material', () {
      final s = chessRules.initial(2);
      expect(chessEvaluator.evaluate(s, 0), -chessEvaluator.evaluate(s, 1));
      final up = at('4k3/8/8/8/8/8/8/3QK3 w - - 0 1');
      expect(chessEvaluator.staticScore(up, 0), greaterThan(800));
    });

    test('sees the recapture past the horizon', () {
      // Qxd5 wins a pawn and loses the queen to cxd5.
      final s = at('4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1');
      final after = chessRules.apply(s, chessRules.decodeMove('d1d5'));
      expect(chessEvaluator.evaluate(after, 0), lessThan(0));
    });

    test('orders queen promotions, then captures, then checks', () {
      final s = at('3r2k1/4P3/8/8/8/8/8/R5K1 w - - 0 1');
      final ordered = chessEvaluator
          .order(s, chessEngineRules.legalMoves(s))
          .map(chessRules.encodeMove)
          .toList();
      expect(ordered.take(2), ['e7d8q', 'e7e8q']);
      expect(ordered.indexOf('a1a8'), lessThan(ordered.indexOf('a1a2')));
    });
  });
}
