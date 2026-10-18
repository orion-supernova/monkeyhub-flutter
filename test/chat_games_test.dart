import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart' show SheetBackCloseButton;
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
import 'package:monkeyhub/models/game_move.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/widgets/game_bubble.dart';
import 'package:monkeyhub/widgets/game_move_bubble.dart';

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

  group('a turn by turn move', () {
    test('is staged on the board, never sent until Send', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game(mode: MatchMode.async));
      c.stage('4');
      expect(c.stagedMove, '4');
      expect(c.match!.state, '....X..../1');
      // Staged is not your move any more: the board is locked until Undo.
      expect(c.match!.isTurnOf('me'), isFalse);
      expect(api.calls.where((x) => x.startsWith('move')), isEmpty);
      c.unstage();
      expect(c.stagedMove, isNull);
      expect(c.match!.state, '........./0');
      c.stage('0');
      expect(await c.sendStaged(), isTrue);
      expect(api.calls.where((x) => x.startsWith('move')), ['move:0']);
      expect(c.stagedMove, isNull);
      c.dispose();
    });

    test('a refused send reports it and leaves nothing staged', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game(mode: MatchMode.async));
      c.stage('4');
      api.failNextMove = 'STALE';
      expect(await c.sendStaged(), isFalse);
      expect(c.lastRejection, MoveRejection.stale);
      expect(c.stagedMove, isNull);
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

  group('the move bubble', () {
    Widget bubble({required String viewer, required bool mine}) => Builder(
      builder: (context) => GameMoveBubble(
        theme: ThemeScope.of(context),
        message: ChatMessage(
          id: 'mv1',
          roomId: 'r1',
          senderId: 'me',
          senderName: 'Ada',
          content: 'Tic-tac-toe · move 1',
          type: MessageType.gameMove,
          createdAt: DateTime(2026, 10, 13),
          gameMove: const GameMoveSnapshot(
            matchId: 'm1',
            game: 'tictactoe',
            seq: 1,
            seat: 0,
            move: '4',
            state: '....X..../1',
          ),
        ),
        isMine: mine,
        width: 300,
        radius: BorderRadius.circular(18),
        currentUserId: viewer,
      ),
    );

    testWidgets('the newest move asks its answerer to play', (tester) async {
      MatchesStore.instance.note(game(
        mode: MatchMode.async,
        state: '....X..../1',
        seq: 1,
        turnSeat: 1,
      ));
      await tester.pumpWidget(host(bubble(viewer: 'bob', mine: false)));
      expect(find.text('Ada played'), findsOneWidget);
      expect(find.textContaining('Move 1'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('its sender waits, and an older move says so', (tester) async {
      MatchesStore.instance.note(game(
        mode: MatchMode.async,
        state: '....X..../1',
        seq: 1,
        turnSeat: 1,
      ));
      await tester.pumpWidget(host(bubble(viewer: 'me', mine: true)));
      expect(find.text('You played'), findsOneWidget);
      expect(find.text('Waiting for Bob'), findsOneWidget);
      MatchesStore.instance.note(game(
        mode: MatchMode.async,
        state: 'O...X..../0',
        seq: 2,
        turnSeat: 0,
      ));
      await tester.pump();
      expect(find.text('Earlier move'), findsOneWidget);
    });
  });

  group('the room banner', () {
    final store = MatchesStore.instance;

    test('a game missing from the room list is evicted, a finished one kept', () async {
      await store.watchRoom('me', 'r1');
      api.pushRoom('r1', [
        game(id: 'a'),
        game(id: 'b'),
        game(id: 'old', status: MatchStatus.finished),
      ]);
      expect(store.openIn('r1').map((m) => m.id), unorderedEquals(['a', 'b']));
      // Card 'b' expired, which erased its game: the next delivery lacks it,
      // and the finished one has slid out of the list's window.
      api.pushRoom('r1', [game(id: 'a')]);
      expect(store.openIn('r1').map((m) => m.id), ['a']);
      expect(store.forMessage('msg-b'), isNull);
      expect(store.forMessage('msg-old'), isNotNull);
      api.pushRoom('r1', const []);
      expect(store.openIn('r1'), isEmpty);
      store.unwatchRoom('r1');
    });

    test('a just-created game survives a delivery read before it existed', () async {
      await store.watchRoom('me', 'r1');
      store.note(game(id: 'new'));
      api.pushRoom('r1', const []);
      expect(store.openIn('r1').map((m) => m.id), ['new']);
      store.unwatchRoom('r1');
    });

    test('a screen that finds its game gone drops it from the banner', () async {
      store.note(game(id: 'm1'));
      expect(store.openIn('r1'), hasLength(1));
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(null, matchId: 'm1');
      expect(c.gone, isTrue);
      expect(store.openIn('r1'), isEmpty);
      c.dispose();
    });

    test('a move refused with NO_MATCH drops it too', () async {
      final c = MatchController(matchId: 'm1', userId: 'me');
      await c.start();
      api.push(game());
      store.note(game());
      api.failNextMove = 'NO_MATCH';
      await c.play('4');
      expect(store.openIn('r1'), isEmpty);
      c.dispose();
    });
  });

  group('a turn by turn game before it exists', () {
    const seats = [
      MatchSeat(userId: 'me', name: 'Ada'),
      MatchSeat(userId: 'bob', name: 'Bob'),
    ];
    const draft = TurnDraft(roomId: 'r1', game: 'tictactoe', seats: seats);

    test('draws the opening board locally and tells the server nothing', () async {
      final c = MatchController.draft(draft: draft, userId: 'me');
      await c.start();
      expect(c.isDraft, isTrue);
      expect(c.matchId, isEmpty);
      expect(c.match!.state, '........./0');
      expect(c.match!.isTurnOf('me'), isTrue);
      c.stage('4');
      expect(c.match!.state, '....X..../1');
      c.unstage();
      // Backing out: nothing was ever sent, nothing watched.
      c.dispose();
      expect(api.calls, isEmpty);
    });

    test('Send creates the game with the move, then watches it', () async {
      final c = MatchController.draft(draft: draft, userId: 'me');
      await c.start();
      c.stage('4');
      // Only through Send: a bare play on a draft goes nowhere.
      expect(await c.play('0'), isFalse);
      expect(await c.sendStaged(), isTrue);
      expect(api.calls, ['startTurns:tictactoe:4', 'watch']);
      expect(c.isDraft, isFalse);
      expect(c.matchId, 'm-turns');
      // The sent board stays up until the game's first delivery.
      expect(c.match!.state, '....X..../1');
      expect(c.sending, isTrue);
      api.push(game(
        id: 'm-turns',
        mode: MatchMode.async,
        state: '....X..../1',
        seq: 1,
        turnSeat: 1,
      ));
      expect(c.sending, isFalse);
      expect(c.match!.seq, 1);
      expect(api.calls.where((x) => x.startsWith('move')), isEmpty);
      c.dispose();
    });

    test('a refused first move creates nothing and says why', () async {
      final c = MatchController.draft(draft: draft, userId: 'me');
      await c.start();
      c.stage('4');
      api.failNextStart = 'TOO_MANY_GAMES';
      expect(await c.sendStaged(), isFalse);
      expect(c.lastRejection, MoveRejection.tooManyGames);
      expect(c.isDraft, isTrue);
      expect(c.match!.state, '........./0');
      expect(api.calls.where((x) => x == 'watch'), isEmpty);
      c.dispose();
    });

    test('the store shows a card-less game in the banner and drops it when gone', () async {
      final store = MatchesStore.instance;
      await store.watchRoom('me', 'r1');
      final cardless = ChatMatch(
        id: 'm-turns',
        roomId: 'r1',
        messageId: '',
        game: 'tictactoe',
        mode: MatchMode.async,
        status: MatchStatus.active,
        seats: seats,
        state: '....X..../1',
        seq: 1,
        turnSeat: 1,
        createdBy: 'me',
        createdAt: DateTime(2026, 10, 13),
      );
      api.pushRoom('r1', [cardless, game(id: 'carded')]);
      expect(
        store.openIn('r1').map((m) => m.id),
        unorderedEquals(['m-turns', 'carded']),
      );
      expect(store.forMatch('m-turns'), isNotNull);
      expect(store.forMessage('msg-carded')?.id, 'carded');
      expect(store.forMessage(''), isNull);
      api.pushRoom('r1', [game(id: 'carded')]);
      expect(store.openIn('r1').map((m) => m.id), ['carded']);
      store.note(cardless);
      expect(store.openIn('r1'), hasLength(2));
      store.forget('m-turns');
      expect(store.forMatch('m-turns'), isNull);
      store.unwatchRoom('r1');
    });

    testWidgets('the screen opens on the local board and Send creates the game', (tester) async {
      tester.view
        ..physicalSize = const Size(420, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(
        const MatchScreen(matchId: '', userId: 'me', draft: draft),
      ));
      await tester.pump();
      expect(find.byType(TurnBoard), findsOneWidget);
      expect(api.calls, isEmpty);
      tester.widget<TurnBoard>(find.byType(TurnBoard)).onMove!('4');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Send move'), findsOneWidget);
      expect(api.calls, isEmpty);
      await tester.tap(find.text('Send move'));
      await tester.pump();
      expect(api.calls.first, 'startTurns:tictactoe:4');
      expect(api.calls.where((x) => x.startsWith('move')), isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the screen', () {
    testWidgets('a turn by turn move waits for Send', (tester) async {
      // The VIEW, not `setSurfaceSize`: that grows the render surface but
      // leaves the 800x600 view hit testing uses, so a tap below 600 misses.
      tester.view
        ..physicalSize = const Size(420, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const MatchScreen(matchId: 'm1', userId: 'me')));
      await tester.pump();
      api.push(game(mode: MatchMode.async));
      await tester.pump();
      expect(find.text('Make your move, then send it. No rush.'), findsOneWidget);
      tester.widget<TurnBoard>(find.byType(TurnBoard)).onMove!('4');
      // Frame by frame: the panel grows into its staged face (AnimatedSize),
      // and one long pump is a single frame that leaves it clipped short.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Send move'), findsOneWidget);
      expect(api.calls.where((x) => x.startsWith('move')), isEmpty);
      await tester.tap(find.text('Send move'));
      await tester.pump();
      expect(api.calls.where((x) => x.startsWith('move')), ['move:4']);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });


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
      // Fewer dice is a raise only on 1s, which take half (Perudo): the
      // face moves to the one face that still raises.
      await tester.tap(find.byKey(const ValueKey('ld_qty_minus')));
      await tester.pump();
      expect(find.text('Bid  2 × 1'), findsOneWidget);
      // And no lower than that.
      await tester.tap(find.byKey(const ValueKey('ld_qty_minus')));
      await tester.pump();
      expect(find.text('Bid  2 × 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ld_qty_plus')));
      await tester.pump();
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
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('a DM lists only what two people can play', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(const StartGameSheet(isDm: true)));
      await settle(tester);
      expect(find.byKey(const ValueKey('game_imposter')), findsNothing);
      expect(find.byKey(const ValueKey('game_liarsdice')), findsOneWidget);
      expect(find.byKey(const ValueKey('game_race')), findsOneWidget);
      expect(find.byKey(const ValueKey('game_chess')), findsOneWidget);
      // Board games carry both badges here; party games only Live.
      expect(find.text('Turns'), findsNWidgets(kChatGames.length));
      expect(find.text('Vs bot'), findsNothing);
    });

    testWidgets('a group lists Imposter, and nothing takes turns',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(const StartGameSheet(isDm: false)));
      await settle(tester);
      expect(find.byKey(const ValueKey('game_imposter')), findsOneWidget);
      expect(find.text('Turns'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('game_tictactoe')));
      await settle(tester);
      // One way to play: explained, not offered as a choice.
      expect(find.byKey(const ValueKey('mode_live')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_turns')), findsNothing);
      expect(find.text('How do you want to play?'), findsNothing);
    });

    testWidgets('a group too small for Imposter greys it out', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(const StartGameSheet(isDm: false, memberCount: 2)),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('game_imposter')), findsOneWidget);
      expect(find.text('Needs 3+ people'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game_imposter')));
      await settle(tester);
      expect(find.text('Start Imposter'), findsNothing);
      // Two people still get every two-player game.
      await tester.tap(find.byKey(const ValueKey('game_liarsdice')));
      await settle(tester);
      expect(find.byKey(const ValueKey('game_start')), findsOneWidget);
    });

    testWidgets('a group big enough for Imposter opens it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(const StartGameSheet(isDm: false, memberCount: 3)),
      );
      await settle(tester);
      expect(find.text('Needs 3+ people'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('game_imposter')));
      await settle(tester);
      expect(find.byKey(const ValueKey('game_start')), findsOneWidget);
    });

    testWidgets('a DM board game defaults to taking turns, and can go live',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ChatGameDraft? draft;
      await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              draft = await showGameStartSheet(context, isDm: true),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game_connectfour')));
      await tester.pumpAndSettle();
      expect(find.text('How do you want to play?'), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_turns')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_live')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mode_live')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game_start')));
      await tester.pumpAndSettle();
      expect(draft?.game, 'connectfour');
      expect(draft?.matchMode, MatchMode.live);
    });

    testWidgets('back returns from a game page to the shelf',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(const StartGameSheet(isDm: false)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('game_race')));
      await settle(tester);
      expect(find.text('Start Puzzle Race'), findsOneWidget);
      await tester.tap(find.byType(SheetBackCloseButton));
      await settle(tester);
      expect(find.byKey(const ValueKey('game_race')), findsOneWidget);
      expect(find.text('Start Puzzle Race'), findsNothing);
    });
  });
}
