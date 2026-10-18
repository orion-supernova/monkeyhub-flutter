import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/bot_match_screen.dart';
import 'package:monkeyhub/chat_games/game_side_panel.dart';
import 'package:monkeyhub/chat_games/move_history.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/turn_games/bot.dart';
import 'package:monkeyhub/turn_games/chess.dart';
import 'package:monkeyhub/turn_games/registry.dart';

String _play(String game, List<String> moves) {
  final g = turnGameFor(game)!;
  var s = g.initialEncoded(2);
  for (final m in moves) {
    s = g.applyEncoded(s, m);
  }
  return s;
}

void main() {
  final l10n = AppLocalizationsEn();

  group('GameLine', () {
    test('chess writes SAN, castling and captures included', () {
      final line = GameLine.replay(
        l10n: l10n,
        game: 'chess',
        seats: 2,
        moves: const ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6',
          'b5c6', 'd7c6', 'e1g1'],
      );
      expect(line.entries.map((e) => e.label).toList(), [
        'e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Bxc6', 'dxc6', 'O-O',
      ]);
      expect(line.stateAt(0), turnGameFor('chess')!.initialEncoded(2));
      expect(line.stateAt(4), _play('chess', const ['e2e4', 'e7e5', 'g1f3', 'b8c6']));
      expect(line.moveAt(9), 'e1g1');
      expect(line.entries.map((e) => e.seat).take(3).toList(), [0, 1, 0]);
    });

    test('a token the rules refuse ends the replay there', () {
      final line = GameLine.replay(
        l10n: l10n,
        game: 'connectfour',
        seats: 2,
        moves: const ['3', '3', 'zz', '4'],
      );
      expect(line.length, 2);
      expect(line.entries.first.label, '4');
    });
  });

  test('chess material counts what each side took', () {
    final m = ChessMaterial.of(_play('chess', const [
      'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5c6', 'd7c6',
    ]))!;
    expect(m.taken[0], [chessKnight]);
    expect(m.taken[1], [chessBishop]);
    expect(m.advantage, 0);
  });

  test('stepPly walks the line and returns to the live position', () {
    expect(stepPly(null, 6, -1), 5);
    expect(stepPly(5, 6, 1), isNull);
    expect(stepPly(2, 6, TurnKeys.home), 0);
    expect(stepPly(0, 6, -1), 0);
    expect(stepPly(3, 6, TurnKeys.end), isNull);
  });

  test('takebacks per bot level', () {
    expect(botTakebacks(BotLevel.easy), 3);
    expect(botTakebacks(BotLevel.medium), 1);
    expect(botTakebacks(BotLevel.hard), 0);
  });

  group('the bot weighs a draw', () {
    // 1.e4 e5 2.Qh5 Qg5?? 3.Qxg5: white is a queen up.
    const blunder = ['e2e4', 'e7e5', 'd1h5', 'd8g5', 'h5g5'];
    test('a player a queen up is granted it', () async {
      final state = _play('chess', [...blunder, 'b8c6']); // white to move
      expect(
        await botAcceptsDraw(gameId: 'chess', state: state, level: BotLevel.easy, seed: 1),
        isTrue,
      );
    });
    test('a player a queen down is refused', () async {
      final state = _play('chess', blunder); // black to move, down a queen
      expect(
        await botAcceptsDraw(gameId: 'chess', state: state, level: BotLevel.easy, seed: 1),
        isFalse,
      );
    });
    test('tic-tac-toe from the start is a draw it takes', () async {
      expect(
        await botAcceptsDraw(
          gameId: 'tictactoe',
          state: turnGameFor('tictactoe')!.initialEncoded(2),
          level: BotLevel.hard,
          seed: 1,
        ),
        isTrue,
      );
    });
  });

  group('BotMatchScreen', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1;
      view.physicalSize = const Size(500, 1600);
    });
    tearDown(() =>
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

    Widget host(Widget child) => ThemeScope(
      controller: ThemeController(ThemeController.byId('basic')),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

    testWidgets('hard: no takeback tile, says so', (tester) async {
      await tester.pumpWidget(host(const BotMatchScreen(game: 'chess', level: BotLevel.hard)));
      await tester.pump();
      expect(find.text('Takeback'), findsNothing);
      expect(find.text('No takebacks against the hard bot'), findsOneWidget);
      expect(find.text('Resign'), findsOneWidget);
    });

    testWidgets('resign asks first, then ends the game', (tester) async {
      await tester.pumpWidget(host(const BotMatchScreen(game: 'tictactoe', level: BotLevel.easy)));
      await tester.pump();
      await tester.tap(find.text('Resign'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The confirm sheet's destructive action.
      expect(find.text('Resign this game?'), findsOneWidget);
      await tester.tap(find.text('Resign').last);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('You resigned'), findsOneWidget);
      final board = tester.widget<TurnBoard>(find.byType(TurnBoard));
      expect(board.enabled, isFalse);
    });

    testWidgets('easy: a takeback is spent and the move undone', (tester) async {
      await tester.pumpWidget(host(const BotMatchScreen(game: 'tictactoe', level: BotLevel.easy)));
      await tester.pump();
      expect(find.text('3 takebacks left'), findsOneWidget);
      tester.widget<TurnBoard>(find.byType(TurnBoard)).onMove!('4');
      await tester.pump();
      // Let the bot's isolate answer.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Takeback'));
      await tester.pump();
      expect(find.text('2 takebacks left'), findsOneWidget);
      final board = tester.widget<TurnBoard>(find.byType(TurnBoard));
      expect(board.state, turnGameFor('tictactoe')!.initialEncoded(2));
      expect(board.enabled, isTrue);
    });
  });
}
