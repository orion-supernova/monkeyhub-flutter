import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/matches_api.dart';
import 'package:monkeyhub/chat_games/game_start_sheet.dart';
import 'package:monkeyhub/chat_games/match_copy.dart';
import 'package:monkeyhub/data/matches_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/party_games/imposter_table.dart';
import 'package:monkeyhub/party_games/party_views.dart';
import 'package:monkeyhub/screens/games/match_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_bubble.dart';

import 'fakes/fake_matches_api.dart';

/// In-chat games on the client: what a tap draws before the server answers,
/// what a refusal undoes, when the server is told a player left, and what a
/// card says at each stage.
ChatMatch game({
  String id = 'm1',
  MatchMode mode = MatchMode.live,
  MatchStatus status = MatchStatus.active,
  List<MatchSeat>? seats,
  String? state = '........./0',
  int seq = 0,
  int? turnSeat = 0,
  int? winner,
  String? reason,
}) => ChatMatch(
  id: id,
  roomId: 'r1',
  messageId: 'msg-$id',
  game: 'tictactoe',
  mode: mode,
  status: status,
  seats: seats ??
      const [
        MatchSeat(userId: 'me', name: 'Ada'),
        MatchSeat(userId: 'bob', name: 'Bob'),
      ],
  state: state,
  seq: seq,
  turnSeat: turnSeat,
  createdBy: 'me',
  createdAt: DateTime(2026, 10, 12),
  winner: winner,
  reason: reason,
);

/// A party game under way: [view] is its public view, as the server's
/// `publicView` writes it.
ChatMatch party(
  String game,
  Map<String, dynamic> view, {
  int seats = 3,
  MatchStatus status = MatchStatus.active,
  int seq = 1,
  int? turnSeat,
  int? winner,
  List<int>? winners,
  bool draw = false,
  String? reason,
}) => ChatMatch(
  id: 'p1',
  roomId: 'r1',
  messageId: 'msg-p1',
  game: game,
  mode: MatchMode.live,
  status: status,
  seats: [
    for (final (id, name) in [
      ('me', 'Ada'),
      ('bob', 'Bob'),
      ('cem', 'Cem'),
      ('dee', 'Dee'),
    ].take(seats))
      MatchSeat(userId: id, name: name),
  ],
  state: jsonEncode({'game': game, ...view}),
  seq: seq,
  turnSeat: turnSeat,
  createdBy: 'me',
  createdAt: DateTime(2026, 10, 12),
  winner: winner,
  winners: winners,
  draw: draw,
  reason: reason,
  party: true,
);

Map<String, dynamic> diceView({
  Map<String, dynamic>? bid,
  int turn = 0,
  String phase = 'bidding',
}) => {
  'phase': phase,
  'round': 1,
  'turn': turn,
  'deadline': DateTime.now().millisecondsSinceEpoch + 40000,
  'bid': bid,
  'bids': [?bid],
  'counts': [5, 5],
  'out': [false, false],
  'left': [false, false],
  'totalDice': 10,
  'reveal': null,
  'winner': null,
};

Map<String, dynamic> imposterView(String phase, {int? turn, List? clues}) => {
  'phase': phase,
  'deadline': DateTime.now().millisecondsSinceEpoch + 30000,
  'voice': false,
  'order': [0, 1, 2],
  'turn': turn,
  'clues': clues ?? [],
  'seen': [true, true, true],
  'voted': [false, true, false],
  'left': [false, false, false],
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
};

PartySecret crewSecret({Object? myVote}) => PartySecret(
  seat: 0,
  seq: 1,
  secret: jsonEncode({
    'role': 'crew',
    'wordId': 'beach',
    'names': {'en': 'Beach', 'tr': 'Plaj', 'pt-br': 'Praia'},
    'category': 'places',
    'categoryNames': {'en': 'Places', 'tr': 'Mekânlar'},
    'myVote': myVote,
  }),
);

void main() {
  late FakeMatchesApi api;

  setUp(() {
    api = FakeMatchesApi();
    MatchesStore.instance
      ..detach()
      ..api = api;
  });

  group('a move', () {
    test('draws at once, and the server board wins once it moves on', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game());
      await c.play('4');
      expect(c.match!.state, '....X..../1');
      expect(c.sending, isTrue);
      // Its echo lands: the optimistic layer goes.
      api.push(game(state: '....X..../1', seq: 1, turnSeat: 1));
      expect(c.sending, isFalse);
      expect(c.match!.seq, 1);
      c.dispose();
    });

    test('a refusal snaps back and is reported once', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game());
      api.failNextMove = 'STALE';
      await c.play('4');
      expect(c.match!.state, '........./0');
      expect(c.lastRejection, MoveRejection.stale);
      expect(c.rejectionCount, 1);
      c.dispose();
    });

    test('is not sent out of turn, nor twice while one is in flight', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game(turnSeat: 1));
      await c.play('4');
      expect(api.calls.where((x) => x.startsWith('move')), isEmpty);
      api.push(game());
      // Two taps before the first answer: one move.
      final first = c.play('4');
      await c.play('5');
      await first;
      expect(api.calls.where((x) => x.startsWith('move')), ['move:4']);
      c.dispose();
    });
  });

  group('presence', () {
    test('a live game beats while open and says away on the way out', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game());
      expect(api.calls, contains('beat'));
      c.dispose();
      expect(api.calls.last, 'away');
    });

    test('an async game never beats', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game(mode: MatchMode.async));
      c.dispose();
      expect(api.calls, isNot(contains('beat')));
      expect(api.calls, isNot(contains('away')));
    });
  });

  // ThemeScope above the app, as in the real one, so a route the test pushes
  // (a card's tap opening the game) can see it too.
  Widget host(Widget child, {Locale? locale}) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Widget card(ChatMatch m, {String viewer = 'me'}) {
    MatchesStore.instance.note(m);
    return Builder(
      builder: (context) => GameBubble(
        theme: ThemeScope.of(context),
        message: ChatMessage(
          id: m.messageId,
          roomId: 'r1',
          senderId: 'me',
          senderName: 'Ada',
          content: 'Tic-tac-toe',
          type: MessageType.game,
          createdAt: DateTime(2026, 10, 12),
        ),
        isMine: true,
        width: 300,
        radius: BorderRadius.circular(18),
        currentUserId: viewer,
      ),
    );
  }

  group('the card', () {
    testWidgets('a lobby offers a stranger a seat', (tester) async {
      await tester.pumpWidget(host(card(game(
        status: MatchStatus.lobby,
        seats: const [MatchSeat(userId: 'me', name: 'Ada', ready: true)],
        state: null,
        turnSeat: null,
      ), viewer: 'cem')));
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Open seat'), findsOneWidget);
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(api.calls, contains('join'));
    });

    testWidgets('says whose move it is', (tester) async {
      await tester.pumpWidget(host(card(game())));
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Your move'), findsOneWidget);
    });

    testWidgets('a finished game says who won, and that it is not ranked', (
      tester,
    ) async {
      await tester.pumpWidget(host(card(game(
        status: MatchStatus.finished,
        state: 'XXXOO..../1',
        turnSeat: null,
        winner: 1,
        reason: 'win',
      ))));
      expect(find.text('Bob won'), findsOneWidget);
      expect(find.text('Not ranked'), findsOneWidget);
      expect(find.text('Play'), findsNothing);
    });
  });

  group('the screen', () {
    testWidgets('the lobby readies a seated player', (tester) async {
      await tester.pumpWidget(host(const MatchScreen(matchId: 'm1', userId: 'me')));
      await tester.pump();
      api.push(game(
        status: MatchStatus.lobby,
        seats: const [MatchSeat(userId: 'me', name: 'Ada')],
        state: null,
        turnSeat: null,
      ));
      await tester.pump();
      await tester.tap(find.text('I’m ready'));
      await tester.pump();
      expect(api.calls, contains('ready:true'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a finished game offers a rematch to a player', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(const MatchScreen(matchId: 'm1', userId: 'me')));
      await tester.pump();
      api.push(game(
        status: MatchStatus.finished,
        state: 'XXXOO..../1',
        turnSeat: null,
        winner: 0,
        reason: 'win',
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('You won'), findsWidgets);
      expect(find.text('Rematch'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('party games', () {
    test('seat limits and the lobby wait on the game\'s own minimum', () {
      expect(minSeatsOf('imposter'), 3);
      expect(minSeatsOf('liarsdice'), 2);
      expect(maxSeatsOf('liarsdice'), 6);
      expect(maxSeatsOf('race'), 8);
      final l10n = lookupAppLocalizations(const Locale('en'));
      final lobby = party(
        'imposter',
        const {},
        seats: 2,
        status: MatchStatus.lobby,
      );
      expect(
        matchStatusLine(l10n, lobby, 'me'),
        'Waiting for 1 more player',
      );
    });

    test('a word is read in the viewer\'s language', () {
      const names = {'en': 'Beach', 'pt-br': 'Praia', 'pt': 'Praia PT'};
      expect(localName(names, const Locale('pt', 'BR')), 'Praia');
      expect(localName(names, const Locale('pt')), 'Praia PT');
      expect(localName(names, const Locale('sv')), 'Beach');
    });

    test('clues are one to four words, at most 24 characters', () {
      expect(clueProblem('  '), ClueProblem.empty);
      expect(clueProblem('sandy towel'), isNull);
      expect(clueProblem('one two three four'), isNull);
      expect(clueProblem('one two three four five'), ClueProblem.tooManyWords);
      expect(clueProblem('a' * 25), ClueProblem.tooLong);
    });

    test('an action goes out with an id and clears when its echo lands', () async {
      final c = MatchController(matchId: 'p1', userId: 'me');
      await c.start();
      api.push(party('liarsdice', diceView(), seats: 2, turnSeat: 0));
      expect(api.calls, contains('watchSecret'));
      final sent = c.act('bid:1:3');
      expect(c.pendingAction, 'bid:1:3');
      await sent;
      // Taken with a change: still pending until the row moves past it.
      expect(c.pendingAction, 'bid:1:3');
      api.push(party('liarsdice', diceView(turn: 1), seats: 2, seq: 2, turnSeat: 1));
      expect(c.pendingAction, isNull);
      c.dispose();
    });

    test('a refused action is reported, and a clock never runs negative', () async {
      final c = MatchController(matchId: 'p1', userId: 'me');
      await c.start();
      api.push(party('liarsdice', diceView(), seats: 2, turnSeat: 0));
      api.failNextAct = 'TOO_LATE';
      expect(await c.act('liar'), isFalse);
      expect(c.lastRejection, MoveRejection.tooLate);
      expect(c.pendingAction, isNull);
      expect(c.remaining(DateTime.now().millisecondsSinceEpoch - 5000), Duration.zero);
      c.dispose();
    });

    Future<void> openParty(
      WidgetTester tester,
      ChatMatch m, {
      PartySecret? secret,
      Locale? locale,
    }) async {
      // Tall enough that every panel of the table is on screen to tap.
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(const MatchScreen(matchId: 'p1', userId: 'me'), locale: locale),
      );
      await tester.pump();
      api.push(m);
      await tester.pump();
      if (secret != null) {
        api.pushSecret('p1', secret);
        await tester.pump();
      }
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('the bid picker only offers raises, and bids', (tester) async {
      await openParty(
        tester,
        party(
          'liarsdice',
          diceView(bid: {'seat': 1, 'qty': 3, 'face': 4}),
          seats: 2,
          turnSeat: 0,
        ),
        secret: PartySecret(
          seat: 0,
          seq: 1,
          secret: jsonEncode({'round': 1, 'dice': [1, 2, 4, 4, 6]}),
        ),
      );
      // The smallest raise of 3 × 4 is 3 × 5.
      expect(find.text('Bid  3 × 5'), findsOneWidget);
      // A lower face at the same quantity is not a raise: nothing happens.
      await tester.tap(find.byKey(const ValueKey('ld_face_2')));
      await tester.pump();
      expect(find.text('Bid  3 × 5'), findsOneWidget);
      // Nor can the quantity drop below the standing bid's.
      await tester.tap(find.byKey(const ValueKey('ld_qty_minus')));
      await tester.pump();
      expect(find.text('Bid  3 × 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ld_face_6')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('ld_bid')));
      await tester.tap(find.byKey(const ValueKey('ld_bid')));
      await tester.pump();
      expect(api.actions, ['bid:3:6']);
      await close(tester);
    });

    testWidgets('one more die opens every face', (tester) async {
      await openParty(
        tester,
        party(
          'liarsdice',
          diceView(bid: {'seat': 1, 'qty': 3, 'face': 6}),
          seats: 2,
          turnSeat: 0,
        ),
      );
      // 3 × 6 can only be raised by quantity: the picker starts at 4.
      expect(find.text('Bid  4 × 6'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ld_face_1')));
      await tester.pump();
      expect(find.text('Bid  4 × 1'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Liar! calls the standing bid', (tester) async {
      await openParty(
        tester,
        party(
          'liarsdice',
          diceView(bid: {'seat': 1, 'qty': 3, 'face': 4}),
          seats: 2,
          turnSeat: 0,
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('ld_liar')));
      await tester.tap(find.byKey(const ValueKey('ld_liar')));
      await tester.pump();
      expect(api.actions, ['liar']);
      await close(tester);
    });

    testWidgets('there is no Liar! before anybody bids', (tester) async {
      await openParty(
        tester,
        party('liarsdice', diceView(), seats: 2, turnSeat: 0),
      );
      expect(find.byKey(const ValueKey('ld_liar')), findsNothing);
      expect(find.text('Open the bidding'), findsOneWidget);
      await close(tester);
    });

    Future<void> holdCard(WidgetTester tester) async {
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('imp_card'))),
      );
      // The first frame starts the fill; the next lands it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      addTearDown(() => g.up());
    }

    testWidgets('the crew sees the word in their own language', (tester) async {
      await openParty(
        tester,
        party('imposter', imposterView('reveal')),
        secret: crewSecret(),
        locale: const Locale('tr'),
      );
      expect(find.text('Plaj'), findsNothing);
      await holdCard(tester);
      expect(find.text('Plaj'), findsOneWidget);
      expect(find.text('Kategori: Mekânlar'), findsOneWidget);
    });

    testWidgets('letting go of the card hides the word again', (tester) async {
      await openParty(
        tester,
        party('imposter', imposterView('reveal')),
        secret: crewSecret(),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('imp_card'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Beach'), findsOneWidget);
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Beach'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('imp_seen')));
      await tester.pump();
      expect(api.actions, isEmpty, reason: 'already seen in this view');
      await close(tester);
    });

    testWidgets('the imposter sees only the category', (tester) async {
      await openParty(
        tester,
        party('imposter', imposterView('reveal')),
        secret: PartySecret(
          seat: 0,
          seq: 1,
          secret: jsonEncode({
            'role': 'imposter',
            'category': 'places',
            'categoryNames': {'en': 'Places'},
            'myVote': null,
          }),
        ),
      );
      await holdCard(tester);
      expect(find.text('You’re the imposter'), findsOneWidget);
      expect(find.text('Category: Places'), findsOneWidget);
      expect(find.text('Beach'), findsNothing);
    });

    testWidgets('a clue is checked before it can be sent', (tester) async {
      await openParty(
        tester,
        party('imposter', imposterView('clues', turn: 0), turnSeat: 0),
        secret: crewSecret(),
      );
      final field = find.byKey(const ValueKey('imp_clue_field'));
      await tester.enterText(find.descendant(of: field, matching: find.byType(TextField)), 'one two three four five');
      await tester.pump();
      expect(find.text('Four words at most'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('imp_clue_send')));
      await tester.pump();
      expect(api.actions, isEmpty);
      // The field itself stops at 24 characters.
      await tester.enterText(find.descendant(of: field, matching: find.byType(TextField)), 'a' * 30);
      await tester.pump();
      expect(tester.widget<TextField>(find.descendant(of: field, matching: find.byType(TextField))).controller!.text.length, 24);
      await tester.enterText(find.descendant(of: field, matching: find.byType(TextField)), 'sandy towel');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('imp_clue_send')));
      await tester.pump();
      expect(api.actions, ['clue:sandy towel']);
      await close(tester);
    });

    testWidgets('a vote, then a change of mind to skip', (tester) async {
      await openParty(
        tester,
        party('imposter', imposterView('vote')),
        secret: crewSecret(),
      );
      expect(find.text('1 of 3 voted'), findsOneWidget);
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(api.actions, ['vote:1']);
      api.push(party('imposter', imposterView('vote'), seq: 2));
      api.pushSecret('p1', crewSecret(myVote: 1));
      await tester.pump();
      expect(find.text('Your vote'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('imp_skip')));
      await tester.tap(find.byKey(const ValueKey('imp_skip')));
      await tester.pump();
      expect(api.actions, ['vote:1', 'vote:skip']);
      await close(tester);
    });

    testWidgets('a solved race board is sent as the finish', (tester) async {
      final fixture = jsonDecode(
        File('test/fixtures/daily_games.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final day = (fixture['days'] as List).first as Map<String, dynamic>;
      final queens = day['queens'] as Map<String, dynamic>;
      final board = queens['board'] as Map<String, dynamic>;
      final answer = (queens['answer'] as List).cast<int>();
      final n = board['size'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      await openParty(
        tester,
        party('race', {
          'phase': 'racing',
          'kind': 'queens',
          'puzzle': board,
          'startedAt': now,
          'deadline': now + 600000,
          'players': [
            for (var i = 0; i < 3; i++)
              {'progress': 0, 'rank': null, 'durationMs': null, 'left': false},
          ],
          'reason': null,
        }),
      );
      final surface = find.byType(GameBoardSurface);
      final origin = tester.getTopLeft(surface);
      final grid = GameGrid(side: tester.getSize(surface).width, n: n);
      for (var row = 0; row < n; row++) {
        final at = origin + grid.center(row * n + answer[row]);
        // Nothing → cross → crown.
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
      }
      final finishes = api.actions.where((a) => a.startsWith('finish:')).toList();
      expect(finishes, ['finish:${jsonEncode(answer)}']);
      await close(tester);
    });
  });

  group('the party card', () {
    testWidgets('a Liar\'s Dice round says the round and dice', (tester) async {
      await tester.pumpWidget(host(card(party('liarsdice', diceView(), seats: 2, turnSeat: 1))));
      expect(find.text('Round 1 · 10 dice'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('an Imposter round says its phase', (tester) async {
      await tester.pumpWidget(host(card(party('imposter', imposterView('reveal')))));
      expect(find.text('Looking at cards'), findsOneWidget);
      await tester.pumpWidget(host(card(party('imposter', imposterView('clues', turn: 0), turnSeat: 0))));
      expect(find.text('Your turn to give a clue'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      await tester.pumpWidget(host(card(party('imposter', imposterView('vote')))));
      expect(find.text('Voting'), findsOneWidget);
      await tester.pumpWidget(host(card(party('imposter', imposterView('guess')))));
      expect(find.text('The imposter is guessing…'), findsOneWidget);
    });

    testWidgets('a race says how many have finished', (tester) async {
      await tester.pumpWidget(host(card(party('race', {
        'phase': 'racing',
        'kind': 'zip',
        'puzzle': {'size': 6, 'checkpoints': [0, 35]},
        'startedAt': 0,
        'deadline': 600000,
        'players': [
          {'progress': 100, 'rank': 1, 'durationMs': 61000, 'left': false},
          {'progress': 40, 'rank': null, 'durationMs': null, 'left': false},
          {'progress': 10, 'rank': null, 'durationMs': null, 'left': false},
        ],
        'reason': null,
      }))));
      expect(find.text('1 of 3 finished'), findsOneWidget);
    });

    testWidgets('a crew win says so, with why', (tester) async {
      await tester.pumpWidget(host(card(party(
        'imposter',
        imposterView('over'),
        status: MatchStatus.finished,
        winners: const [0, 2],
        reason: 'caught',
      ))));
      expect(find.text('Your team won · The crew caught the imposter.'), findsOneWidget);
      expect(find.text('Not ranked'), findsOneWidget);
    });

    testWidgets('a race nobody finished', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final m = party('race', const {}, status: MatchStatus.finished, draw: true, reason: 'time');
      expect(matchResultLine(l10n, m, 'me'), 'Time’s up. Nobody finished.');
    });
  });

  group('the start sheet', () {
    testWidgets('party games are live only, and say so', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(const StartGameSheet(isDm: true)));
      await tester.pump();
      expect(find.text('Party'), findsOneWidget);
      expect(find.text('Party games are played live, with everyone at once.'), findsOneWidget);
      await tester.tap(find.text('Live'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Party games are played live, with everyone at once.'), findsNothing);
      expect(find.text('2–6 players'), findsOneWidget);
      // A party game with options opens them in place; Start carries them.
      await tester.ensureVisible(find.byKey(const ValueKey('party_race')));
      await tester.tap(find.byKey(const ValueKey('party_race')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('party_start')), findsOneWidget);
      expect(find.text('Start Puzzle Race'), findsOneWidget);
    });
  });
}
