import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/matches_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/party_games/imposter_table.dart';
import 'package:monkeyhub/party_games/party_table.dart';
import 'package:monkeyhub/party_games/party_views.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_matches_api.dart';

/// Party games on the desktop stage and the rules their tables mirror: the
/// Perudo price of a bid on 1s, the keys that bid, call and vote, and the
/// split of a table into the stage's board and panel.
ChatMatch party(
  String game,
  Map<String, dynamic> view, {
  int seats = 3,
  int? turnSeat,
  int seq = 1,
}) =>
    ChatMatch(
      id: 'p1',
      roomId: 'r1',
      messageId: 'msg-p1',
      game: game,
      mode: MatchMode.live,
      status: MatchStatus.active,
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
      party: true,
    );

Map<String, dynamic> diceView({Map<String, dynamic>? bid, int turn = 0}) => {
  'phase': 'bidding',
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

Map<String, dynamic> voteView() => {
  'phase': 'vote',
  'deadline': DateTime.now().millisecondsSinceEpoch + 30000,
  'voice': false,
  'order': [0, 1, 2, 3],
  'turn': null,
  'clues': [
    {'seat': 0, 'text': 'sand'},
    {'seat': 1, 'text': 'waves'},
    {'seat': 2, 'text': 'towel'},
    {'seat': 3, 'text': 'sun'},
  ],
  'seen': [true, true, true, true],
  'voted': [false, false, false, false],
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
};

Widget host(Widget child, {Size size = const Size(1000, 900)}) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: SizedBox.fromSize(size: size, child: child)),
    ),
  ),
);

void main() {
  group('a bid on 1s, the Perudo way', () {
    DiceBid b(int qty, int face) => DiceBid(seat: 1, qty: qty, face: face);

    test('half as many onto them, rounded up', () {
      expect(b(5, 4).raisedBy(3, 1), isTrue);
      expect(b(5, 4).raisedBy(2, 1), isFalse);
      expect(b(6, 6).raisedBy(3, 1), isTrue);
    });

    test('more of them from 1s to 1s, double plus one off them', () {
      expect(b(3, 1).raisedBy(4, 1), isTrue);
      expect(b(3, 1).raisedBy(3, 1), isFalse);
      expect(b(3, 1).raisedBy(7, 2), isTrue);
      expect(b(3, 1).raisedBy(6, 6), isFalse);
    });

    test('plain faces as before', () {
      expect(b(3, 4).raisedBy(3, 5), isTrue);
      expect(b(3, 4).raisedBy(3, 4), isFalse);
      expect(b(3, 4).raisedBy(2, 6), isFalse);
      expect(b(3, 4).raisedBy(4, 2), isTrue);
    });

    test('the fewest dice any raise can name', () {
      expect(b(5, 4).minRaiseQty, 3);
      expect(b(3, 6).minRaiseQty, 2);
      expect(b(3, 1).minRaiseQty, 4);
    });
  });

  test('vote keys number everyone still in, the voter skipped', () {
    expect(imposterVoteKeys([0, 1, 2, 3], 1), {1: 0, 2: 2, 3: 3});
    expect(imposterVoteKeys([0, 2, 3], 2), {1: 0, 2: 3});
  });

  group('on the desktop stage', () {
    late FakeMatchesApi api;

    setUp(() {
      api = FakeMatchesApi();
      MatchesStore.instance
        ..detach()
        ..api = api;
    });

    Future<MatchController> controllerFor(ChatMatch m) async {
      final c = MatchController(matchId: 'p1', userId: 'me');
      await c.start();
      api.push(m);
      return c;
    }

    Future<void> pumpStage(WidgetTester tester, MatchController c) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final stage = partyStageFor(
        match: c.match!,
        controller: c,
        viewerId: 'me',
      );
      await tester.pumpWidget(host(Row(
        children: [
          Expanded(child: stage.board),
          SizedBox(width: 340, child: stage.panel),
        ],
      )));
      await tester.pump();
    }

    testWidgets('Liar\'s Dice: arrows, digits and Enter bid; L calls', (
      tester,
    ) async {
      final c = await controllerFor(party(
        'liarsdice',
        diceView(bid: {'seat': 1, 'qty': 3, 'face': 4}),
        seats: 2,
        turnSeat: 0,
      ));
      await pumpStage(tester, c);
      // The smallest raise of 3 × 4 is 3 × 5; ↑ makes it 4, 2 picks the face.
      expect(find.text('Bid  3 × 5'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(find.text('Bid  4 × 2'), findsOneWidget);
      // ↓ back to 3: 3 × 2 is no raise, so the face moves up to one that is.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('Bid  3 × 5'), findsOneWidget);
      // And down to 2, where only 1s raise 3 × 4.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('Bid  2 × 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(api.actions, ['bid:2:1']);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Liar\'s Dice: L calls the standing bid', (tester) async {
      final c = await controllerFor(party(
        'liarsdice',
        diceView(bid: {'seat': 1, 'qty': 3, 'face': 4}),
        seats: 2,
        turnSeat: 0,
      ));
      await pumpStage(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(api.actions, ['liar']);
      // The panel carries the faces and the round's bids.
      expect(find.text('3 ×'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Imposter: the number on a face votes, 0 skips', (tester) async {
      final c = await controllerFor(party('imposter', voteView(), seats: 4));
      await pumpStage(tester, c);
      // Seat 0 is the viewer: 1 is Bob, 2 is Cem.
      expect(find.text('2'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(api.actions, ['vote:2']);
      // One action at a time: the next key waits for the echo.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      expect(api.actions, ['vote:2']);
      api.push(party('imposter', voteView(), seats: 4, seq: 2));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      expect(api.actions.last, 'vote:skip');
      // Every clue sits in the panel beside the vote.
      expect(find.text('towel'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
