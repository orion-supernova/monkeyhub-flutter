// Feed's inner screens and the Games area, rendered to PNG.
//
//   flutter test test/design_preview/feed_games_preview.dart
//
// Not a test. Uses the same fake games API the mount test does, so the hub and
// the boards show today's real fixture puzzles.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/games/game_play_controller.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/feed/points_explainer.dart';
import 'package:monkeyhub/screens/feed/puzzle_screen.dart';
import 'package:monkeyhub/screens/games/game_scaffold.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/screens/games/queens_screen.dart';
import 'package:monkeyhub/screens/games/sudoku_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

/// A board the player has just solved, for the result card.
class _SolvedController extends GamePlayController {
  _SolvedController() : super(game: DailyGame.queens, userId: 'u1');
  @override
  bool get ready => true;
  @override
  bool get finished => true;
  @override
  bool get solved => true;
  @override
  int? get durationMs => 94000;
  @override
  int get mistakes => 1;
}

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

  setUpAll(loadPreviewFonts);
  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
  });

  final screens = <String, Widget Function()>{
    'hub': () => LeaderboardScreen(
          feedApi: FeedApi(ConvexBackend.instance),
          userId: 'u1',
        ),
    'queens': () => const QueensScreen(userId: 'u1'),
    'sudoku': () => const SudokuScreen(userId: 'u1'),
    'solved': () => GameScaffold(
          controller: _SolvedController(),
          title: 'Queens',
          rule: 'One queen per row, column and colour.',
          board: const ColoredBox(color: Color(0x22888888)),
          tools: const [],
          viewerId: 'u1',
          onShare: () {},
          onTellFriends: () {},
        ),
    'code': () => PuzzleScreen(
          feedApi: FeedApi(ConvexBackend.instance),
          userId: 'u1',
        ),
    'points': () => const PointsExplainerScreen(),
  };

  // Mid-burst, so the celebration itself can be judged.
  testWidgets('fg preview: burst', (tester) async {
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), screens['solved']!()),
      'fg_burst_basic.png',
      settle: const Duration(milliseconds: 520),
    );
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  });

  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    for (final e in screens.entries) {
      testWidgets('fg preview: ${e.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), e.value()),
          'fg_${e.key}_$id.png',
          // The celebration has to have finished landing to be judged.
          settle: const Duration(seconds: 3),
        );
        await tester.pumpWidget(const SizedBox());
        FeedStore.instance.stop();
      });
    }
  }
}
