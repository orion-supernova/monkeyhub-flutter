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
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_tile.dart';

import 'fakes/fake_games_api.dart';

/// Which game the hub puts first.
///
/// The code puzzle leads the four boards, and that is not a cosmetic
/// preference: the daily nudge names the code, so the tile somebody lands on
/// after tapping that notification has to be the one under their thumb rather
/// than the one they have to scan past. It also matches the Feed's own games
/// strip, which has always drawn the code first — the two shelves disagreeing
/// was the bug.
///
/// Asserted geometrically rather than by reading the widget list, because the
/// list order is not the question; where the tiles land on the glass is. A
/// future layout that reverses a `Wrap` or sorts by status would leave the code
/// tile first in the list and last on the screen, and this catches that.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;

  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in ['queens', 'tango', 'zip', 'sudoku'])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
  });
  tearDown(GamesStore.instance.clear);

  Widget host() => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: LeaderboardScreen(
        feedApi: FeedApi(ConvexBackend.instance),
        userId: 'u1',
      ),
    ),
  );

  /// Reading order: down first, then across.
  bool comesBefore(Offset a, Offset b) =>
      a.dy < b.dy - 1 || ((a.dy - b.dy).abs() <= 1 && a.dx < b.dx);

  testWidgets('the code puzzle is the first tile on the shelf', (tester) async {
    await tester.pumpWidget(host());
    // Three pumps rather than pumpAndSettle: the tiles enter on a staggered
    // TweenAnimationBuilder that never stops arriving under `pumpAndSettle`
    // while the boards are still loading.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CodePuzzleTile), findsOneWidget);
    expect(find.byType(GameTile), findsNWidgets(4));

    final code = tester.getTopLeft(find.byType(CodePuzzleTile));
    for (var i = 0; i < 4; i++) {
      final board = tester.getTopLeft(find.byType(GameTile).at(i));
      expect(
        comesBefore(code, board),
        isTrue,
        reason:
            'the code tile at $code must come before the board tile at $board',
      );
    }

    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  });
}
