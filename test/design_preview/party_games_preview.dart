// Throwaway: the party games (Liar's Dice, Imposter, Puzzle Race), every
// phase of every table, the start sheet's Party section and the chat cards,
// on Midnight and Daylight. See preview_kit.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/matches_api.dart';
import 'package:monkeyhub/chat_games/game_start_sheet.dart';
import 'package:monkeyhub/data/matches_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/games/match_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_bubble.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

import '../fakes/fake_matches_api.dart';
import 'preview_kit.dart';

const _people = [
  ('me', 'Ada'),
  ('bob', 'Bob'),
  ('cem', 'Cem'),
  ('dee', 'Deniz'),
  ('eli', 'Elif'),
];

int get _now => DateTime.now().millisecondsSinceEpoch;

ChatMatch _party(
  String game,
  Map<String, dynamic>? view, {
  int seats = 4,
  MatchStatus status = MatchStatus.active,
  int seq = 3,
  int? turnSeat,
  int? winner,
  List<int>? winners,
  bool draw = false,
  String? reason,
  bool ready = false,
  String id = 'p1',
}) => ChatMatch(
  id: id,
  roomId: 'r1',
  messageId: 'msg-$id',
  game: game,
  mode: MatchMode.live,
  status: status,
  seats: [
    for (final (uid, name) in _people.take(seats))
      MatchSeat(userId: uid, name: name, ready: ready && uid != 'me'),
  ],
  state: view == null ? null : jsonEncode({'game': game, ...view}),
  seq: seq,
  turnSeat: turnSeat,
  createdBy: 'me',
  createdAt: DateTime(2026, 10, 12),
  lastMoveAt: DateTime.now(),
  winner: winner,
  winners: winners,
  draw: draw,
  reason: reason,
  party: true,
);

Map<String, dynamic> _dice({
  Map<String, dynamic>? bid,
  int turn = 0,
  int round = 2,
  Map<String, dynamic>? reveal,
  String phase = 'bidding',
  List<int> counts = const [5, 4, 5, 3],
  List<List<int>>? dice,
}) => {
  'phase': phase,
  'round': round,
  'turn': phase == 'over' ? null : turn,
  'deadline': phase == 'over' ? null : _now + 38000,
  'bid': bid,
  'bids': [?bid],
  'counts': counts,
  'out': [for (final c in counts) c <= 0],
  'left': [for (final _ in counts) false],
  'totalDice': counts.fold<int>(0, (a, b) => a + b),
  'reveal': reveal,
  'winner': phase == 'over' ? 0 : null,
  'dice': ?dice,
};

const _revealDice = [
  [1, 3, 4, 4, 6],
  [2, 2, 5, 6, 6],
  [1, 4, 5, 5, 3],
  [4, 6, 2, 1],
];

Map<String, dynamic> _reveal({bool holds = false}) => {
  'round': 1,
  'dice': _revealDice,
  'bid': {'seat': 2, 'qty': holds ? 6 : 8, 'face': 4},
  'caller': 1,
  'count': 7,
  'holds': holds,
  'loser': holds ? 1 : 2,
  'auto': false,
};

Map<String, dynamic> _imp(
  String phase, {
  int? turn,
  List<Map<String, dynamic>> clues = const [],
  List<bool> voted = const [false, true, false, true],
  Map<String, dynamic> extra = const {},
}) => {
  'phase': phase,
  'deadline': phase == 'over' ? null : _now + 27000,
  'voice': false,
  'order': [2, 3, 0, 1],
  'turn': turn,
  'clues': clues,
  'seen': [true, true, false, true],
  'voted': voted,
  'left': [false, false, false, false],
  'votes': null,
  'voteCounts': null,
  'skips': null,
  'accused': null,
  'result': null,
  'reason': null,
  'imposter': null,
  'word': null,
  'guess': null,
  'guessCorrect': null,
  ...extra,
};

const _clues = [
  {'seat': 2, 'text': 'sandy towels'},
  {'seat': 3, 'text': 'sunburn'},
];

PartySecret _crew({Object? vote}) => PartySecret(
  seat: 0,
  seq: 3,
  secret: jsonEncode({
    'role': 'crew',
    'wordId': 'beach',
    'names': {'en': 'Beach', 'tr': 'Plaj'},
    'category': 'places',
    'categoryNames': {'en': 'Places', 'tr': 'Mekânlar'},
    'myVote': vote,
  }),
);

final _impSecret = PartySecret(
  seat: 0,
  seq: 3,
  secret: jsonEncode({
    'role': 'imposter',
    'category': 'places',
    'categoryNames': {'en': 'Places'},
    'myVote': null,
  }),
);

Map<String, dynamic> _queensFixture() {
  final fixture = jsonDecode(
    File('test/fixtures/daily_games.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final day = (fixture['days'] as List).first as Map<String, dynamic>;
  return day['queens'] as Map<String, dynamic>;
}

Map<String, dynamic> _race(Map<String, dynamic> board, {bool over = false}) => {
  'phase': over ? 'over' : 'racing',
  'kind': 'queens',
  'puzzle': board,
  'startedAt': _now - 95000,
  'deadline': over ? null : _now + 505000,
  'players': [
    {'progress': over ? 100 : 25, 'rank': over ? 2 : null, 'durationMs': over ? 128400 : null, 'left': false},
    {'progress': 100, 'rank': 1, 'durationMs': 94200, 'left': false},
    {'progress': over ? 62 : 50, 'rank': null, 'durationMs': null, 'left': false},
    {'progress': over ? 0 : 12, 'rank': null, 'durationMs': null, 'left': over},
  ],
  'reason': over ? 'time' : null,
};

void main() {
  setUpAll(loadPreviewFonts);

  late FakeMatchesApi api;
  setUp(() {
    api = FakeMatchesApi();
    MatchesStore.instance
      ..detach()
      ..api = api;
  });

  Future<void> table(
    WidgetTester tester,
    String themeId,
    String name,
    ChatMatch m, {
    PartySecret? secret,
    Future<void> Function()? then,
    Size size = const Size(393, 1100),
  }) async {
    final theme = ThemeController.byId(themeId);
    await snap(
      tester,
      previewApp(theme, const MatchScreen(matchId: 'p1', userId: 'me')),
      'party_${name}_$themeId.png',
      size: size,
      act: () async {
        api.push(m);
        await tester.pump();
        if (secret != null) api.pushSecret('p1', secret);
        await tester.pump();
        await then?.call();
      },
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('start sheet $id', (tester) async {
      final theme = ThemeController.byId(id);
      await snap(
        tester,
        previewApp(
          theme,
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 1560,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: ColoredBox(
                  color: sheetFill(theme),
                  child: const StartGameSheet(isDm: false),
                ),
              ),
            ),
          ),
        ),
        'party_start_sheet_$id.png',
        size: const Size(393, 1600),
        act: () async {
          await tester.tap(find.byKey(const ValueKey('party_race')));
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        },
      );
    });

    testWidgets('lobby $id', (tester) async {
      await table(
        tester,
        id,
        'lobby',
        _party('imposter', null, seats: 2, status: MatchStatus.lobby, ready: true),
        size: const Size(393, 852),
      );
    });

    testWidgets('liars dice bidding $id', (tester) async {
      await table(
        tester,
        id,
        'dice_bid',
        _party(
          'liarsdice',
          _dice(bid: {'seat': 3, 'qty': 4, 'face': 5}),
          turnSeat: 0,
        ),
        secret: PartySecret(
          seat: 0,
          seq: 3,
          secret: jsonEncode({'round': 2, 'dice': [1, 2, 5, 5, 6]}),
        ),
      );
    });

    testWidgets('liars dice waiting $id', (tester) async {
      await table(
        tester,
        id,
        'dice_wait',
        _party('liarsdice', _dice(turn: 2), turnSeat: 2),
        secret: PartySecret(
          seat: 0,
          seq: 3,
          secret: jsonEncode({'round': 2, 'dice': [2, 3, 3, 4, 6]}),
        ),
        size: const Size(393, 852),
      );
    });

    testWidgets('liars dice reveal $id', (tester) async {
      await table(
        tester,
        id,
        'dice_reveal',
        _party('liarsdice', _dice(round: 1, turn: 1), turnSeat: 1, seq: 2),
        secret: PartySecret(
          seat: 0,
          seq: 2,
          secret: jsonEncode({'round': 1, 'dice': [1, 3, 4, 4, 6]}),
        ),
        then: () async {
          // The call lands while the screen is open: the reveal shows over
          // the next round.
          api.push(_party(
            'liarsdice',
            _dice(round: 2, turn: 2, counts: [5, 5, 4, 4], reveal: _reveal()),
            turnSeat: 2,
            seq: 3,
          ));
          api.pushSecret(
            'p1',
            PartySecret(
              seat: 0,
              seq: 3,
              secret: jsonEncode({'round': 2, 'dice': [2, 2, 3, 5, 6]}),
            ),
          );
          await tester.pump();
        },
      );
    });

    testWidgets('liars dice over $id', (tester) async {
      await table(
        tester,
        id,
        'dice_over',
        _party(
          'liarsdice',
          _dice(
            phase: 'over',
            round: 9,
            counts: [2, 0, 0, 0],
            reveal: {
              'round': 9,
              'dice': [
                [3, 5],
                [6],
                [],
                [],
              ],
              'bid': {'seat': 1, 'qty': 2, 'face': 6},
              'caller': 0,
              'count': 1,
              'holds': false,
              'loser': 1,
              'auto': false,
            },
            dice: const [
              [3, 5],
              [6],
              [],
              [],
            ],
          ),
          status: MatchStatus.finished,
          winner: 0,
          reason: 'win',
        ),
      );
    });

    testWidgets('imposter reveal held $id', (tester) async {
      await table(
        tester,
        id,
        'imp_reveal',
        _party('imposter', _imp('reveal')),
        secret: _crew(),
        size: const Size(393, 852),
        then: () async {
          await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('imp_card'))),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        },
      );
    });

    testWidgets('imposter reveal imposter $id', (tester) async {
      await table(
        tester,
        id,
        'imp_reveal_imposter',
        _party('imposter', _imp('reveal')),
        secret: _impSecret,
        size: const Size(393, 852),
        then: () async {
          await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('imp_card'))),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        },
      );
    });

    testWidgets('imposter reveal face down $id', (tester) async {
      await table(
        tester,
        id,
        'imp_reveal_down',
        _party('imposter', _imp('reveal')),
        secret: _crew(),
        size: const Size(393, 852),
      );
    });

    testWidgets('imposter clues $id', (tester) async {
      await table(
        tester,
        id,
        'imp_clues',
        _party('imposter', _imp('clues', turn: 0, clues: _clues), turnSeat: 0),
        secret: _crew(),
      );
    });

    testWidgets('imposter clues waiting $id', (tester) async {
      await table(
        tester,
        id,
        'imp_clues_wait',
        _party(
          'imposter',
          _imp(
            'clues',
            turn: 1,
            clues: [
              ..._clues,
              {'seat': 0, 'text': '(passed)', 'passed': true},
            ],
          ),
          turnSeat: 1,
        ),
        secret: _crew(),
        size: const Size(393, 852),
      );
    });

    testWidgets('imposter vote $id', (tester) async {
      await table(
        tester,
        id,
        'imp_vote',
        _party(
          'imposter',
          _imp(
            'vote',
            clues: [
              ..._clues,
              {'seat': 0, 'text': 'waves'},
              {'seat': 1, 'text': 'very hot'},
            ],
          ),
        ),
        secret: _crew(vote: 1),
        size: const Size(393, 852),
      );
    });

    testWidgets('imposter guess $id', (tester) async {
      await table(
        tester,
        id,
        'imp_guess',
        _party('imposter', _imp('guess', extra: {'accused': 0}), turnSeat: 0),
        secret: _impSecret,
        size: const Size(393, 852),
      );
    });

    testWidgets('imposter guess waiting $id', (tester) async {
      await table(
        tester,
        id,
        'imp_guess_wait',
        _party('imposter', _imp('guess', extra: {'accused': 3}), turnSeat: 3),
        secret: _crew(),
        size: const Size(393, 852),
      );
    });

    testWidgets('imposter over $id', (tester) async {
      await table(
        tester,
        id,
        'imp_over',
        _party(
          'imposter',
          _imp(
            'over',
            clues: [
              ..._clues,
              {'seat': 0, 'text': 'waves'},
              {'seat': 1, 'text': 'very hot'},
            ],
            extra: {
              'votes': [3, 3, -1, 1],
              'voteCounts': [0, 1, 0, 2],
              'skips': 1,
              'accused': 3,
              'result': 'crew',
              'reason': 'caught',
              'imposter': 3,
              'word': {
                'id': 'beach',
                'category': 'places',
                'names': {'en': 'Beach'},
                'categoryNames': {'en': 'Places'},
              },
              'guess': 'Desert',
              'guessCorrect': false,
            },
          ),
          status: MatchStatus.finished,
          winners: const [0, 1, 2],
          reason: 'caught',
        ),
        secret: _crew(),
        size: const Size(393, 1300),
      );
    });

    testWidgets('race $id', (tester) async {
      final q = _queensFixture();
      final board = q['board'] as Map<String, dynamic>;
      final answer = (q['answer'] as List).cast<int>();
      final n = board['size'] as int;
      await table(
        tester,
        id,
        'race',
        _party('race', _race(board)),
        then: () async {
          final surface = find.byType(GameBoardSurface);
          final origin = tester.getTopLeft(surface);
          final grid = GameGrid(side: tester.getSize(surface).width, n: n);
          // Two crowns down, and a cross.
          for (final row in [0, 1]) {
            final at = origin + grid.center(row * n + answer[row]);
            await tester.tapAt(at);
            await tester.pump(const Duration(milliseconds: 40));
            await tester.tapAt(at);
            await tester.pump(const Duration(milliseconds: 40));
          }
          await tester.tapAt(origin + grid.center(5 * n + 3));
          await tester.pump(const Duration(seconds: 1));
        },
      );
    });

    testWidgets('race over $id', (tester) async {
      final board = _queensFixture()['board'] as Map<String, dynamic>;
      await table(
        tester,
        id,
        'race_over',
        _party(
          'race',
          _race(board, over: true),
          status: MatchStatus.finished,
          winner: 1,
          reason: 'finished',
        ),
        size: const Size(393, 852),
      );
    });

    testWidgets('party cards $id', (tester) async {
      final theme = ThemeController.byId(id);
      final cards = [
        _party('liarsdice', _dice(turn: 2), turnSeat: 2, id: 'c1'),
        _party('imposter', _imp('vote'), id: 'c2'),
        _party('imposter', _imp('clues', turn: 0, clues: _clues), turnSeat: 0, id: 'c5'),
        _party(
          'race',
          _race(_queensFixture()['board'] as Map<String, dynamic>),
          seats: 5,
          id: 'c3',
        ),
        _party(
          'imposter',
          _imp('over'),
          status: MatchStatus.finished,
          winners: const [0, 1, 2],
          reason: 'caught',
          id: 'c4',
        ),
      ];
      for (final c in cards) {
        MatchesStore.instance.note(c);
      }
      await snap(
        tester,
        previewApp(
          theme,
          Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 40),
              children: [
                for (final c in cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GameBubble(
                        theme: ThemeScope.of(context),
                        message: ChatMessage(
                          id: c.messageId,
                          roomId: 'r1',
                          senderId: 'me',
                          senderName: 'Ada',
                          content: c.game,
                          type: MessageType.game,
                          createdAt: DateTime(2026, 10, 12),
                        ),
                        isMine: true,
                        width: 300,
                        radius: BorderRadius.circular(18),
                        currentUserId: 'me',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        'party_cards_$id.png',
        size: const Size(393, 1150),
      );
    });
  }
}
