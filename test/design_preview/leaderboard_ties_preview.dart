// Big ties on the leaderboard, rendered to PNG: ten people sharing first
// (the podium) and ten sharing fourth (the rows under it).
//
//   flutter test test/design_preview/leaderboard_ties_preview.dart
//
// Not a test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/models/game_record.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';
import 'ties_fixture.dart';

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in [
      'queens', 'tango', 'zip', 'sudoku', 'flow', 'futoshiki', 'nonogram',
      'minesweeper', 'starbattle',
    ])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  setUpAll(loadPreviewFonts);
  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload, standingsAnswer: tieStandings);
    RecordsStore.instance.api = FakeGamesApi(payload)
      ..records = RecordBoard(games: const {});
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
  });

  for (final (name, tab, swipe, themeId) in [
    ('today', 0, false, 'basic'),
    ('gold2_bronze10', 2, false, 'basic'),
    ('gold2_bronze10_swiping', 2, true, 'basic'),
    ('gold1_silver10', 3, false, 'basic'),
    ('gold12', 4, false, 'basic'),
    ('gold2_bronze10_light', 2, false, 'basic_daylight'),
    ('gold12_swiping_light', 4, true, 'basic_daylight'),
  ]) {
    testWidgets('lb ties: $name', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(themeId),
          LeaderboardScreen(
            feedApi: FeedApi(ConvexBackend.instance),
            userId: 'u1',
            initialTab: tab,
          ),
          locale: const Locale('tr'),
        ),
        'lb_ties_$name.png',
        size: const Size(393, 1400),
        settle: swipe ? Duration.zero : const Duration(seconds: 2),
        act: () async {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(seconds: 1));
          if (swipe) {
            // Mid-swipe on the first shared seat on screen: faces turning.
            final seat = find.byType(RepaintBoundary).evaluate().firstWhere(
              (e) => e.widget is RepaintBoundary &&
                  (e.widget as RepaintBoundary).child is GestureDetector,
            );
            final box = seat.renderObject! as RenderBox;
            final g = await tester.startGesture(
              box.localToGlobal(box.size.center(Offset.zero)),
            );
            for (var i = 0; i < 9; i++) {
              await g.moveBy(const Offset(-5, 0));
              await tester.pump(const Duration(milliseconds: 16));
            }
          }
        },
      );
      await tester.pumpWidget(const SizedBox());
      FeedStore.instance.stop();
    });
  }
}
