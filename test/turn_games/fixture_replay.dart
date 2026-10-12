import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/turn_games/turn_rules.dart';

/// Replays the server engine's own playouts against a Dart mirror.
///
/// `backend/tools/turn-fixtures.ts` plays seeded random games with the TS
/// rules and writes every step to `test/fixtures/turn_games/<id>.json`. A test
/// of either mirror alone only checks it against its own idea of the rules;
/// this checks the Dart one against what the server will actually decide. So
/// a drift here is a real bug: a move the client draws that `matches:move`
/// then refuses, or one it refuses that the server would have taken.
///
/// For every step it asserts, exactly: the state decodes and re-encodes to
/// the same string, whose turn it is, the legal moves in the server's order,
/// the next state, and its outcome. The chain is also played forward from the
/// opening WITHOUT re-decoding, so any state a Dart `apply` caches (Connect
/// Four's result, Reversi's move list) is held to the same answers as one
/// rebuilt by `decode`.
void replayTurnFixtures<S, M>(TurnRules<S, M> rules, {int minGames = 8}) {
  group('${rules.id} replays the server fixtures', () {
    final file = File('test/fixtures/turn_games/${rules.id}.json');
    final games = (jsonDecode(file.readAsStringSync()) as List)
        .map((g) => (g as List).cast<Map<String, dynamic>>())
        .toList();

    test('the fixture file is not empty or truncated', () {
      // Guards the rest: an empty file would make every replay vacuous.
      expect(games.length, greaterThanOrEqualTo(minGames));
      for (final g in games) {
        expect(g, isNotEmpty);
        expect(g.last['outcome'], isNotNull, reason: 'games are played out');
      }
    });

    for (var gi = 0; gi < games.length; gi++) {
      test('game $gi', () {
        final steps = games[gi];
        final opening = steps.first['state'] as String;
        final seats = [
          for (var n = rules.minSeats; n <= rules.maxSeats; n++)
            if (rules.encode(rules.initial(n)) == opening) n,
        ];
        expect(seats, isNotEmpty, reason: 'opens from initial(seats)');
        var live = rules.initial(seats.first);

        for (var si = 0; si < steps.length; si++) {
          final step = steps[si];
          final where = 'game $gi step $si';
          final raw = step['state'] as String;
          expect(rules.encode(live), raw, reason: '$where: live state');

          final decoded = rules.decode(raw);
          expect(rules.encode(decoded), raw, reason: '$where: round trip');
          for (final s in [live, decoded]) {
            expect(rules.toMove(s), step['toMove'], reason: '$where: toMove');
            expect(rules.outcome(s), isNull, reason: '$where: still going');
            expect(
              rules.legalMoves(s).map(rules.encodeMove).toList(),
              (step['legal'] as List).cast<String>(),
              reason: '$where: legal moves',
            );
          }

          final move = rules.decodeMove(step['move'] as String);
          expect(rules.encodeMove(move), step['move'], reason: where);
          final next = rules.apply(decoded, move);
          // apply is pure: the position it was given still reads the same.
          expect(rules.encode(decoded), raw, reason: '$where: apply mutated');
          expect(rules.encode(next), step['next'], reason: '$where: next');

          live = rules.apply(live, rules.decodeMove(step['move'] as String));
          final expected = step['outcome'] as Map<String, dynamic>?;
          for (final s in [next, live, rules.decode(step['next'] as String)]) {
            final got = rules.outcome(s);
            if (expected == null) {
              expect(got, isNull, reason: '$where: outcome');
            } else {
              expect(got, isNotNull, reason: '$where: outcome');
              expect(got!.winner, expected['winner'], reason: '$where: winner');
              expect(got.reason, expected['reason'], reason: '$where: reason');
              expect(rules.legalMoves(s), isEmpty, reason: '$where: over');
            }
          }
        }
      });
    }
  });
}
