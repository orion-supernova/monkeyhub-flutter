// Throwaway: the chat "Play a game" sheet (shelf and a game's page, DM and
// group) and the play-the-bot page, on Midnight and Daylight. See
// preview_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/bot_hub_screen.dart';
import 'package:monkeyhub/chat_games/game_start_sheet.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/widgets/games_strip.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

import 'preview_kit.dart';

void main() {
  setUpAll(loadPreviewFonts);

  Widget sheet(dynamic theme, Widget child, double h) => Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      height: h,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(color: sheetFill(theme), child: child),
      ),
    ),
  );

  for (final id in ['basic', 'basic_daylight']) {
    final theme = ThemeController.byId(id);
    testWidgets('feed strip end $id', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 2200,
              child: GamesStrip(
                boards: const DailyBoards(),
                results: const {},
                onOpen: (_) {},
                puzzle: const PuzzleState(),
                onOpenPuzzle: () {},
                onOpenBots: () {},
              ),
            ),
          ),
        ),
        'lobby_strip_$id.png',
        size: const Size(2200, 320),
        dpr: 1,
      );
    });
    for (final dm in [true, false]) {
      final where = dm ? 'dm' : 'group';
      testWidgets('shelf $where $id', (tester) async {
        await snap(
          tester,
          previewApp(theme, sheet(theme, StartGameSheet(isDm: dm), 1500)),
          'lobby_shelf_${where}_$id.png',
          size: const Size(393, 1540),
        );
      });
    }
    testWidgets('page dm connectfour $id', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          sheet(
            theme,
            const StartGameSheet(isDm: true, initialGame: 'connectfour'),
            760,
          ),
        ),
        'lobby_page_dm_connectfour_$id.png',
      );
    });
    testWidgets('page group imposter $id', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          sheet(
            theme,
            const StartGameSheet(isDm: false, initialGame: 'imposter'),
            700,
          ),
        ),
        'lobby_page_group_imposter_$id.png',
      );
    });
    testWidgets('bot hub $id', (tester) async {
      await snap(
        tester,
        previewApp(theme, const BotHubScreen()),
        'lobby_bot_hub_$id.png',
        size: const Size(393, 1300),
        act: () async {
          await tester.tap(find.byKey(const ValueKey('bot_level_hard')));
        },
      );
    });
  }
}
