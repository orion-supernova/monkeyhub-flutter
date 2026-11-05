import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/game_start_sheet.dart';
import 'package:monkeyhub/chat_games/match_copy.dart';
import 'package:monkeyhub/chat_games/play_style.dart';
import 'package:monkeyhub/fight/view/fight_online_screen.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/party_games/party_views.dart';
import 'package:monkeyhub/screens/games/match_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Jungle Fist in the chat: where it is offered, what its cards say, and that
/// every way of opening one lands in the fight screen.
ChatMatch fight({
  MatchStatus status = MatchStatus.finished,
  int? winner,
  bool draw = false,
  String? reason,
  String phase = 'over',
}) => ChatMatch(
  id: 'f1',
  roomId: 'r1',
  messageId: 'msg-f1',
  game: 'fight',
  mode: MatchMode.live,
  status: status,
  seats: const [
    MatchSeat(userId: 'me', name: 'Ada'),
    MatchSeat(userId: 'bob', name: 'Bob'),
  ],
  state: jsonEncode({
    'game': 'fight',
    'phase': phase,
    'startedAt': 0,
    'deadline': null,
    'reported': [true, true],
    'left': [false, false],
    'winner': winner,
    'reason': reason,
  }),
  seq: 1,
  turnSeat: null,
  createdBy: 'me',
  createdAt: DateTime(2026, 11, 5),
  winner: winner,
  draw: draw,
  reason: reason,
  party: true,
);

Widget host(Widget child) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
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

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('fight is a live, two seat party game', () {
    expect(isPartyGame('fight'), isTrue);
    expect(maxSeatsOf('fight'), 2);
    expect(minSeatsOf('fight'), 2);
    expect(partyGamesFor(isDm: true), contains('fight'));
    expect(partyGamesFor(isDm: false), contains('fight'));
    expect(playStylesOf('fight', isDm: true), [PlayStyle.live]);
  });

  test('name and description', () {
    expect(chatGameName(l10n, 'fight'), 'Jungle Fist');
    expect(chatGameDescription(l10n, 'fight'), isNotEmpty);
    expect(chatGamePlayers(l10n, 'fight'), l10n.chatGamePlayersRange(2, 2));
  });

  test('the public view parses', () {
    final v = partyViewOf(fight(status: MatchStatus.active, phase: 'fighting'));
    expect(v, isA<FightView>());
    expect((v! as FightView).reported, [true, true]);
    expect(v.over, isFalse);
  });

  group('result lines', () {
    String line(ChatMatch m, [String viewer = 'me']) => matchResultLine(l10n, m, viewer);

    test('a win', () {
      expect(line(fight(winner: 0, reason: 'win')), l10n.chatGameYouWon);
      expect(line(fight(winner: 1, reason: 'win')), l10n.chatGameWonBy('Bob'));
    });

    test('only the winner reported: still a win', () {
      expect(line(fight(winner: 0, reason: 'unconfirmed')), l10n.chatGameYouWon);
    });

    test('a draw', () {
      expect(line(fight(draw: true, reason: 'draw')), l10n.chatGameDraw);
    });

    test('the phones disagreed: a draw, said so', () {
      expect(line(fight(draw: true, reason: 'disputed')), l10n.chatGameFightDisputed);
      expect(l10n.chatGameFightDisputed, contains('draw'));
    });

    test('someone left', () {
      expect(
        line(fight(winner: 0, reason: 'left')),
        '${l10n.chatGameYouWon} · ${l10n.chatGameReasonLeft('Bob')}',
      );
    });

    test('nobody reported', () {
      expect(line(fight(draw: true, reason: 'abandoned')), l10n.chatGameNobodyWon);
    });
  });

  testWidgets('the start sheet offers fight, live only, with no options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ChatGameDraft? draft;
    await tester.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async => draft = await showGameStartSheet(context, isDm: true),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game_fight')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game_fight')));
    await tester.pumpAndSettle();
    // One way to play: no choice offered, and no puzzle picker.
    expect(find.byKey(const ValueKey('mode_turns')), findsNothing);
    expect(find.byKey(const ValueKey('party_voice')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('game_start')));
    await tester.pumpAndSettle();
    expect(draft?.game, 'fight');
    expect(draft?.matchMode, MatchMode.live);
  });

  testWidgets('openMatchScreen routes a fight to the fight screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    unawaited(openMatchScreen(ctx, match: fight(status: MatchStatus.active, phase: 'fighting'), userId: 'me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FightOnlineScreen), findsOneWidget);
    expect(find.byType(MatchScreen), findsNothing);
  });
}

void unawaited(Future<void> f) {}
