// Throwaway: the five turn-game boards, mid-game and finished, playable and
// as thumbnails, on Midnight and Daylight. See preview_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/turn_games/registry.dart';

import 'preview_kit.dart';

/// Plays [moves] (tokens) from the initial position, or, for a number, that
/// many plies of the rules' first legal move rotated by ply, which wanders
/// enough to look like a real game.
(String, String?) _play(String id, {List<String> moves = const [], int plies = 0}) {
  final game = turnGameFor(id)!;
  final rules = game.rules;
  dynamic s = rules.initial(2);
  String? last;
  for (final m in moves) {
    s = rules.apply(s, rules.decodeMove(m));
    last = m;
  }
  for (var i = 0; i < plies; i++) {
    if (rules.outcome(s) != null) break;
    final legal = rules.legalMoves(s);
    if (legal.isEmpty) break;
    final m = legal[(i * 7 + 3) % legal.length];
    last = rules.encodeMove(m);
    s = rules.apply(s, m);
  }
  return (rules.encode(s), last);
}

(String, String?) _finish(String id, {int cap = 400}) => _play(id, plies: cap);

void main() {
  setUpAll(loadPreviewFonts);

  final games = <String, List<(String, String?)>>{
    'tictactoe': [
      _play('tictactoe', moves: ['4', '0', '2']),
      _play('tictactoe', moves: ['0', '3', '1', '4', '2']),
    ],
    'connectfour': [
      _play('connectfour', moves: ['3', '3', '2', '4', '4', '2', '5', '1', '3']),
      _play('connectfour', moves: ['3', '4', '3', '4', '3', '4', '2', '2', '3']),
    ],
    'reversi': [_play('reversi', plies: 18), _finish('reversi')],
    'checkers': [_play('checkers', plies: 24), _play('checkers', plies: 70)],
    'dots': [_play('dots', plies: 26), _finish('dots')],
  };

  Widget cell(String label, Widget child) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('turn boards $id', (tester) async {
      final theme = ThemeController.byId(id);
      await snap(
        tester,
        previewApp(
          theme,
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in games.entries)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cell(
                          '${e.key} mid, my turn',
                          SizedBox(
                            width: 240,
                            child: TurnBoard(
                              gameId: e.key,
                              state: e.value[0].$1,
                              lastMove: e.value[0].$2,
                              mySeat: _toMove(e.key, e.value[0].$1),
                              enabled: true,
                              onMove: (_) {},
                            ),
                          ),
                        ),
                        cell(
                          '${e.key} finished',
                          SizedBox(
                            width: 240,
                            child: TurnBoard(
                              gameId: e.key,
                              state: e.value[1].$1,
                              lastMove: e.value[1].$2,
                              mySeat: 1,
                            ),
                          ),
                        ),
                        cell(
                          'thumb',
                          SizedBox(
                            width: 96,
                            child: TurnBoard(
                              gameId: e.key,
                              state: e.value[0].$1,
                              thumbnail: true,
                            ),
                          ),
                        ),
                        cell(
                          'thumb done',
                          SizedBox(
                            width: 96,
                            child: TurnBoard(
                              gameId: e.key,
                              state: e.value[1].$1,
                              thumbnail: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        'turn_boards_$id.png',
        size: const Size(800, 1480),
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
      );
    });
  }

  // One frame from the middle of each animation, to judge the motion's
  // shape and not only where it lands.
  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('turn boards in flight $id', (tester) async {
      final theme = ThemeController.byId(id);
      final steps = <String, ((String, String?), (String, String?), int)>{
        'tictactoe': (
          _play('tictactoe', moves: ['4', '0']),
          _play('tictactoe', moves: ['4', '0', '2']),
          110,
        ),
        'connectfour': (
          _play('connectfour', moves: ['3', '3']),
          _play('connectfour', moves: ['3', '3', '2']),
          140,
        ),
        'reversi': (
          _play('reversi', plies: 17),
          _play('reversi', plies: 18),
          200,
        ),
        'checkers': (
          _play('checkers', plies: 23),
          _play('checkers', plies: 24),
          90,
        ),
        'dots': (_play('dots', plies: 25), _play('dots', plies: 26), 90),
      };
      final states = ValueNotifier<bool>(false);
      await snap(
        tester,
        previewApp(
          theme,
          ValueListenableBuilder<bool>(
            valueListenable: states,
            builder: (context, after, _) => Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  children: [
                    for (final e in steps.entries)
                      cell(
                        '${e.key} in flight',
                        SizedBox(
                          width: 220,
                          child: TurnBoard(
                            gameId: e.key,
                            state: after ? e.value.$2.$1 : e.value.$1.$1,
                            lastMove: after ? e.value.$2.$2 : e.value.$1.$2,
                            mySeat: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        'turn_boards_flight_$id.png',
        size: const Size(760, 560),
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
        settle: const Duration(milliseconds: 140),
        act: () async {
          states.value = true;
          await tester.pump();
        },
      );
    });
  }
}

int _toMove(String id, String state) {
  final rules = turnGameFor(id)!.rules;
  return rules.toMove(rules.decode(state));
}
