import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_info_sheet.dart';
import 'package:monkeyhub/widgets/game_tile.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

/// The ⓘ on a game tile, and the sheet behind it.
///
/// The behaviour worth pinning is the one that is easy to get wrong: the ⓘ sits
/// *inside* the tile's own tap region, so it has to take the tap without the
/// tile also opening the board underneath the sheet. Everything else about
/// these tiles is a rendering question; this one is a hit-testing question, and
/// it fails silently — you get the sheet AND the game.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;

  final boards = DailyBoards.fromJson({
    'dayKey': day['dayKey'],
    for (final game in ['queens', 'tango', 'zip', 'sudoku'])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  });

  // ThemeScope wraps the MaterialApp rather than sitting inside `home`,
  // matching `app.dart`. A sheet is built by the Navigator's overlay, so a
  // scope below the Navigator is not an ancestor of it — the sheet would throw
  // "called with no ThemeScope ancestor" in the test and nowhere else.
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

  testWidgets('the hub tile opens the sheet, and not the game', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        GameTile(
          game: DailyGame.queens,
          boards: boards,
          width: 170,
          onTap: () => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GameInfoButton));
    await tester.pumpAndSettle();

    expect(find.text('THE RULES'), findsOneWidget);
    expect(find.text('eight crowns: one in each row, one in each column.'),
        findsOneWidget);
    // The whole point of the separate target: the board must not have opened
    // behind the sheet.
    expect(opened, 0);
  });

  testWidgets('the tile itself still opens the game', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        GameTile(
          game: DailyGame.tango,
          boards: boards,
          width: 170,
          onTap: () => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The name, which is as far from the ⓘ in the corner as the tile gets.
    await tester.tap(find.text('tango'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('THE RULES'), findsNothing);
  });

  testWidgets('the Feed band carries one too', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 340,
          child: GamesStrip(
            boards: boards,
            results: const {},
            onOpen: (_) => opened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GameInfoButton), findsNWidgets(DailyGame.values.length));

    // Zip's, so the sheet's contents prove it opened the right game's.
    await tester.tap(find.byType(GameInfoButton).at(DailyGame.zip.index));
    await tester.pumpAndSettle();

    expect(find.text('start on 1 and finish on the last number.'),
        findsOneWidget);
    expect(opened, 0);
  });

  testWidgets('the code puzzle explains its own scoring', (tester) async {
    await tester.pumpWidget(
      host(
        CodePuzzleTile(
          puzzle: const PuzzleState(),
          width: 170,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GameInfoButton));
    await tester.pumpAndSettle();

    // It shares the hub with four timed boards but is ranked by guesses, and
    // saying so is the reason the scoring line is per-game rather than shared.
    expect(
      find.text('scored by how few guesses it takes, not by the clock.'),
      findsOneWidget,
    );
    expect(find.textContaining('the clock runs'), findsNothing);
  });

  testWidgets('GOT IT closes it', (tester) async {
    await tester.pumpWidget(
      host(
        GameTile(
          game: DailyGame.sudoku,
          boards: boards,
          width: 170,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GameInfoButton));
    await tester.pumpAndSettle();
    expect(find.text('THE RULES'), findsOneWidget);

    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();

    expect(find.text('THE RULES'), findsNothing);
  });
}
