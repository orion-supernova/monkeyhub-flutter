import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_tile.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

import 'fakes/fake_games_api.dart';

/// Which game the Feed's games row puts first, and where the shelf lives.
///
/// The code puzzle leads the timed boards, and that is not a cosmetic
/// preference: the daily nudge names the code, so the tile somebody lands on
/// after tapping that notification has to be the one under their thumb rather
/// than the one they have to scan past.
///
/// Asserted geometrically rather than by reading the widget list, because the
/// list order is not the question; where the tiles land on the glass is. A
/// future layout that reverses the row or sorts by status would leave the code
/// tile first in the list and last on the screen, and this catches that.
///
/// The games live on the Feed only. The leaderboard used to carry the same
/// five tiles one tap away, which read as a repeat; it is standings only now.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;

  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in [
      'queens',
      'tango',
      'zip',
      'sudoku',
      'flow',
      'futoshiki',
      'nonogram',
      'minesweeper',
      'starbattle',
      'patches',
    ])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
  });
  tearDown(GamesStore.instance.clear);

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: child),
    ),
  );

  Widget strip() => app(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 358,
        child: GamesStrip(
          boards: const DailyBoards(),
          results: const {},
          onOpen: (_) {},
          puzzle: const PuzzleState(),
          onOpenPuzzle: () {},
        ),
      ),
    ),
  );

  testWidgets('the code puzzle is the first tile, on one row', (tester) async {
    await tester.pumpWidget(strip());
    await tester.pump();

    expect(find.byType(CodePuzzleTile), findsOneWidget);
    expect(find.byType(GameTile), findsNWidgets(DailyGame.values.length));
    // Every tier has a game now, Star Battle holding Hard, so no tile is a
    // placeholder.
    expect(find.byType(ComingSoonTile), findsNothing);

    final code = tester.getTopLeft(find.byType(CodePuzzleTile));
    for (var i = 0; i < DailyGame.values.length; i++) {
      final board = tester.getTopLeft(find.byType(GameTile).at(i));
      // One row: a second row is what pushed the rest of the Feed down.
      expect((board.dy - code.dy).abs(), lessThan(1), reason: 'tile $i');
      expect(board.dx, greaterThan(code.dx), reason: 'tile $i');
    }
  });

  testWidgets('on a phone the row runs past the edge and scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(strip());
    await tester.pump();

    // The third tile is cut by the edge: that is the swipe affordance.
    final third = tester.getRect(find.byType(GameTile).at(1));
    expect(third.left, lessThan(358));
    expect(third.right, greaterThan(358));

    // The hard group closes the row, so Star Battle is the last tile.
    final last = find.byKey(ValueKey('strip_${DailyGame.starbattle.wire}'));
    final before = tester.getTopLeft(last).dx;
    await tester.drag(find.byType(CodePuzzleTile), const Offset(-400, 0));
    // Fixed pumps: the boards are still loading, and their skeleton shimmers
    // forever, so pumpAndSettle never would.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(last).dx, lessThan(before));
  });

  testWidgets('the leaderboard holds standings, not a second shelf', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        LeaderboardScreen(
          feedApi: FeedApi(ConvexBackend.instance),
          userId: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CodePuzzleTile), findsNothing);
    expect(find.byType(GameTile), findsNothing);

    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  });
}
