// Throwaway: turn by turn games. The match screen's turn panel (your move,
// staged with Send, waiting) and a run of move bubbles in a DM, on Midnight
// and Daylight. See preview_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/matches_store.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/game_move.dart';
import 'package:monkeyhub/screens/games/match_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/turn_games/registry.dart';
import 'package:monkeyhub/widgets/game_move_bubble.dart';

import '../fakes/fake_matches_api.dart';
import 'preview_kit.dart';

ChatMatch _match(
  String game,
  String state, {
  int seq = 0,
  int? turnSeat,
  String? lastMove,
  MatchStatus status = MatchStatus.active,
}) => ChatMatch(
  id: 'm1',
  roomId: 'r1',
  messageId: 'msg-m1',
  game: game,
  mode: MatchMode.async,
  status: status,
  seats: const [
    MatchSeat(userId: 'me', name: 'Ada'),
    MatchSeat(userId: 'bob', name: 'Bob'),
  ],
  state: state,
  seq: seq,
  turnSeat: turnSeat ?? turnGameFor(game)!.toMoveEncoded(state),
  lastMove: lastMove,
  createdBy: 'me',
  createdAt: DateTime(2026, 10, 12),
  lastMoveAt: DateTime.now().subtract(const Duration(hours: 3)),
  deadlineAt: DateTime.now().add(const Duration(hours: 45)),
);

/// Plays [moves] from the opening, returning every position on the way.
List<String> _line(String game, List<String> moves) {
  final g = turnGameFor(game)!;
  final out = <String>[g.initialEncoded(2)];
  for (final m in moves) {
    out.add(g.applyEncoded(out.last, m));
  }
  return out;
}

void main() {
  setUpAll(loadPreviewFonts);

  late FakeMatchesApi api;
  setUp(() {
    api = FakeMatchesApi();
    MatchesStore.instance
      ..detach()
      ..api = api;
  });

  const chess = ['e2e4', 'e7e5', 'g1f3', 'b8c6'];

  for (final id in ['basic', 'basic_daylight']) {
    Future<void> screen(
      WidgetTester tester,
      String name,
      ChatMatch m, {
      String? stage,
    }) async {
      final theme = ThemeController.byId(id);
      await snap(
        tester,
        previewApp(theme, const MatchScreen(matchId: 'm1', userId: 'me')),
        'turns_${name}_$id.png',
        size: const Size(393, 1100),
        act: () async {
          api.push(m);
          await tester.pump();
          if (stage != null) {
            tester.widget<TurnBoard>(find.byType(TurnBoard)).onMove!(stage);
            await tester.pump();
          }
        },
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    final pos = _line('chess', chess);
    testWidgets('your move $id', (tester) async {
      await screen(tester, 'mine', _match('chess', pos[4], seq: 4, lastMove: 'b8c6'));
    });
    testWidgets('staged $id', (tester) async {
      await screen(
        tester,
        'staged',
        _match('chess', pos[4], seq: 4, lastMove: 'b8c6'),
        stage: 'f1b5',
      );
    });
    testWidgets('waiting $id', (tester) async {
      await screen(tester, 'waiting', _match('chess', pos[3], seq: 3, lastMove: 'g1f3'));
    });

    testWidgets('thumbs $id', (tester) async {
      final theme = ThemeController.byId(id);
      // A few plies into each game, from its first legal moves, so the
      // preview never hard-codes a token format.
      Widget thumb(String game, int plies, {List<String>? moves}) {
        final g = turnGameFor(game)!;
        var state = g.initialEncoded(2);
        var last = '';
        for (var i = 0; i < plies; i++) {
          final legal = g.legalEncoded(state);
          last = moves != null ? moves[i] : legal[(i * 7) % legal.length];
          state = g.applyEncoded(state, last);
        }
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Builder(
            builder: (context) => GameMoveBubble(
              theme: ThemeScope.of(context),
              message: ChatMessage(
                id: 'mv-$game',
                roomId: 'r1',
                senderId: 'me',
                senderName: 'Ada',
                content: '',
                type: MessageType.gameMove,
                createdAt: DateTime(2026, 10, 13, 9),
                gameMove: GameMoveSnapshot(
                  matchId: 'none',
                  game: game,
                  seq: plies,
                  seat: (plies - 1) % 2,
                  move: last,
                  state: state,
                ),
              ),
              isMine: true,
              width: 250,
              radius: BorderRadius.circular(18),
              currentUserId: 'me',
            ),
          ),
        );
      }

      await snap(
        tester,
        previewApp(
          theme,
          SingleChildScrollView(
            child: Wrap(
              children: [
                thumb('chess', 5, moves: [...chess, 'f1b5']),
                thumb('tictactoe', 3),
                thumb('checkers', 4),
                thumb('reversi', 5),
                thumb('dots', 6),
                thumb('connectfour', 4),
              ],
            ),
          ),
        ),
        'turns_thumbs_$id.png',
        size: const Size(540, 1500),
      );
    });

    testWidgets('bubbles $id', (tester) async {
      final theme = ThemeController.byId(id);
      final c4 = _line('connectfour', ['3', '3', '2']);
      MatchesStore.instance.note(_match('connectfour', c4[3], seq: 3, lastMove: '2'));
      Widget bubble(String move, int seq, String state, {required bool mine}) =>
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Builder(
                builder: (context) => GameMoveBubble(
                  theme: ThemeScope.of(context),
                  message: ChatMessage(
                    id: 'mv$seq',
                    roomId: 'r1',
                    senderId: mine ? 'bob' : 'me',
                    senderName: mine ? 'Bob' : 'Ada',
                    content: 'Connect Four · move $seq',
                    type: MessageType.gameMove,
                    createdAt: DateTime(2026, 10, 13, 9, seq),
                    gameMove: GameMoveSnapshot(
                      matchId: 'm1',
                      game: 'connectfour',
                      seq: seq,
                      seat: (seq - 1) % 2,
                      move: move,
                      state: state,
                    ),
                  ),
                  isMine: mine,
                  width: 260,
                  radius: BorderRadius.circular(18),
                  currentUserId: 'bob',
                ),
              ),
            ),
          );
      await snap(
        tester,
        previewApp(
          theme,
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Seen from Bob's side: Ada's moves arrive on the left.
                bubble('3', 1, c4[1], mine: false),
                bubble('3', 2, c4[2], mine: true),
                bubble('2', 3, c4[3], mine: false),
              ],
            ),
          ),
        ),
        'turns_bubbles_$id.png',
        size: const Size(393, 1250),
      );
    });
  }
}
