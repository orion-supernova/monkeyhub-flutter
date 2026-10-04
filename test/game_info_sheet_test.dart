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
import 'package:monkeyhub/widgets/sheet_kit.dart' show SheetHandle;
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

    expect(find.text('The rules'), findsOneWidget);
    expect(find.text('Eight crowns: one in each row, one in each column.'),
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
    await tester.tap(find.text('Tango'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('The rules'), findsNothing);
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
            puzzle: const PuzzleState(),
            onOpenPuzzle: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(GameInfoButton),
      findsNWidgets(DailyGame.values.length + 1),
    );

    // Zip's, so the sheet's contents prove it opened the right game's. +1:
    // the code puzzle's own tile is first in the strip.
    await tester.tap(find.byType(GameInfoButton).at(DailyGame.zip.index + 1));
    await tester.pumpAndSettle();

    expect(find.text('Start on 1 and finish on the last number.'),
        findsOneWidget);
    expect(opened, 0);
  });

  // The two below are the reason the ⓘ's tap box is a separate number from its
  // glyph. Both tap a point that is nowhere near the 26pt disc but well inside
  // the box around it — and, crucially, a point the old layout could not reach
  // at all: the box used to hang off its Stack, and a hit outside a Stack's
  // bounds is never offered to the child sitting there. The glyph looked like
  // the target; roughly a quarter of it actually was one.
  testWidgets('the hub ⓘ takes a tap short of the glyph', (tester) async {
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

    // Inside the button's box but clear of the disc — over the card's own
    // tap region, which would otherwise win this one and open the board.
    final box = tester.getRect(find.byType(GameInfoButton));
    await tester.tapAt(Offset(box.left + 3, box.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('The rules'), findsOneWidget);
    expect(opened, 0);
  });

  testWidgets('the Feed band ⓘ takes a tap short of the glyph', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 340,
          child: GamesStrip(
            boards: boards,
            results: const {},
            onOpen: (_) => opened++,
            puzzle: const PuzzleState(),
            onOpenPuzzle: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inside Zip's button box but clear of the disc, which hugs the box's
    // trailing edge — over the card's own tap region, which would otherwise
    // win this one and open the board. +1: the code puzzle's tile is first.
    final box = tester.getRect(
      find.byType(GameInfoButton).at(DailyGame.zip.index + 1),
    );
    await tester.tapAt(Offset(box.left + 3, box.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('Start on 1 and finish on the last number.'),
        findsOneWidget);
    expect(opened, 0);
  });

  final disc = find.descendant(
    of: find.byType(GameInfoButton),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );

  // The hub card is an Arcade-style card now: the ⓘ sits on its title line,
  // inside the card, beside the game's name — not over the board's corner,
  // where it covered a cell of today's puzzle.
  testWidgets('the hub ⓘ sits on the title line, inside its card', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        GameTile(
          game: DailyGame.queens,
          boards: boards,
          width: 170,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = tester.getRect(find.byType(GameTile));
    final glyph = tester.getRect(disc);

    // Wholly inside the card…
    expect(glyph.left, greaterThanOrEqualTo(tile.left));
    expect(glyph.right, lessThanOrEqualTo(tile.right));
    expect(glyph.bottom, lessThanOrEqualTo(tile.bottom));
    // …and below the board, which is square and as wide as the card.
    expect(glyph.top, greaterThan(tile.top + tile.width * 0.8));
    // Level with the game's name.
    final name = tester.getRect(find.text('Queens'));
    expect((glyph.center.dy - name.center.dy).abs(), lessThan(8));
  });

  // The disc used to hang 5pt off the corner, into the gutter between tiles,
  // then sat tucked inside the corner — on top of the board art, covering a
  // cell of today's puzzle. It rides beside the name now, the hub's pattern:
  // below the board, inside the tile, never spilling into the next one.
  testWidgets('the Feed band ⓘ sits beside the name, below the board', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 340,
          child: GamesStrip(
            boards: boards,
            results: const {},
            onOpen: (_) {},
            puzzle: const PuzzleState(),
            onOpenPuzzle: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final strip = find.byKey(const ValueKey('strip_zip'));
    final tile = tester.getRect(strip);
    final board = tester.getRect(
      find.descendant(of: strip, matching: find.byType(AspectRatio)),
    );
    // +1: the code puzzle's own tile is first in the strip.
    final glyph = tester.getRect(disc.at(DailyGame.zip.index + 1));

    // Wholly inside the tile…
    expect(glyph.left, greaterThanOrEqualTo(tile.left));
    expect(glyph.right, lessThanOrEqualTo(tile.right));
    // …clear of the board…
    expect(glyph.top, greaterThanOrEqualTo(board.bottom));
    // …and level with the name and status beside it.
    final name = tester.getRect(
      find.descendant(of: strip, matching: find.text('Zip')),
    );
    expect(glyph.left, greaterThan(name.left));
    expect(glyph.top, lessThan(name.bottom + 14));
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
      find.text('Scored by how few guesses it takes, not by the clock.'),
      findsOneWidget,
    );
    expect(find.textContaining('The clock runs'), findsNothing);
  });

  // The main button used to read GOT IT and only closed the sheet, which
  // sent a player who had just read the rules back to the tile to tap it
  // again. It is the way in now.
  Future<void> openSheet(WidgetTester tester, Widget tile) async {
    await tester.pumpWidget(host(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GameInfoButton));
    await tester.pumpAndSettle();
    expect(find.text('The rules'), findsOneWidget);
  }

  testWidgets('PLAY closes the sheet and opens the game', (tester) async {
    var opened = 0;
    await openSheet(
      tester,
      GameTile(
        game: DailyGame.sudoku,
        boards: boards,
        width: 170,
        onTap: () => opened++,
      ),
    );

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.text('The rules'), findsNothing);
    expect(opened, 1);
  });

  testWidgets('the X closes it without opening the game', (tester) async {
    var opened = 0;
    await openSheet(
      tester,
      GameTile(
        game: DailyGame.sudoku,
        boards: boards,
        width: 170,
        onTap: () => opened++,
      ),
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(find.text('The rules'), findsNothing);
    expect(opened, 0);
  });

  testWidgets('a swipe down closes it without opening the game',
      (tester) async {
    var opened = 0;
    await openSheet(
      tester,
      GameTile(
        game: DailyGame.queens,
        boards: boards,
        width: 170,
        onTap: () => opened++,
      ),
    );

    // From the grabber in the fixed header — the part of the sheet that never
    // scrolls, so the drag is the sheet's and not a scroll view's.
    final grabber = tester.getRect(find.byType(SheetHandle));
    await tester.flingFrom(
      Offset(grabber.center.dx, grabber.top + 2),
      const Offset(0, 500),
      1500,
    );
    await tester.pumpAndSettle();

    expect(find.text('The rules'), findsNothing);
    expect(opened, 0);
  });

  // Where the rules fit, the whole sheet is the handle, not just the grabber —
  // the scroll view holding them must not take a drag it has nothing to do
  // with.
  testWidgets('a swipe on the rules closes it too, when they fit',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openSheet(
      tester,
      GameTile(
        game: DailyGame.queens,
        boards: boards,
        width: 170,
        onTap: () {},
      ),
    );

    await tester.fling(find.text('The rules'), const Offset(0, 600), 1500);
    await tester.pumpAndSettle();

    expect(find.text('The rules'), findsNothing);
    // iOS, whose default physics are the ones most eager to take a drag.
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the button says where the player is with today\'s board',
      (tester) async {
    await openSheet(
      tester,
      GameTile(
        game: DailyGame.zip,
        boards: boards,
        width: 170,
        result: const GameResult(
          game: DailyGame.zip,
          solved: false,
          gaveUp: false,
          finished: false,
        ),
        onTap: () {},
      ),
    );
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    await openSheet(
      tester,
      GameTile(
        game: DailyGame.zip,
        boards: boards,
        width: 170,
        result: const GameResult(
          game: DailyGame.zip,
          solved: true,
          gaveUp: false,
          finished: true,
          durationMs: 42000,
        ),
        onTap: () {},
      ),
    );
    expect(find.text('See your result'), findsOneWidget);
  });

  testWidgets('the code puzzle offers the way in too', (tester) async {
    var opened = 0;
    await openSheet(
      tester,
      CodePuzzleTile(
        puzzle: const PuzzleState(),
        width: 170,
        onTap: () => opened++,
      ),
    );

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });
}
