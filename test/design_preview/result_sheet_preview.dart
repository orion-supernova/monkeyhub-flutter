// Throwaway: the leaderboard result sheet, opened on a friend's row and on a
// surrender, so it can be looked at. See preview_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/result_sheet.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'preview_kit.dart';

void main() {
  setUpAll(loadPreviewFonts);

  final rows = {
    'friend': const GameResult(
      game: DailyGame.queens,
      solved: true,
      gaveUp: false,
      finished: true,
      durationMs: 161000,
      hintsUsed: 1,
      mistakes: 2,
      userId: 'u2',
      name: 'Selin',
    ),
    'gaveup': const GameResult(
      game: DailyGame.tango,
      solved: false,
      gaveUp: true,
      finished: true,
      mistakes: 4,
      userId: 'u3',
      name: 'Deniz',
    ),
  };

  for (final id in ['basic', 'basic_daylight']) {
    for (final e in rows.entries) {
      testWidgets('result sheet ${e.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () =>
                      showResultSheet(context, row: e.value, viewerId: 'u1'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          'result_sheet_${e.key}_$id.png',
          act: () async {
            await tester.tap(find.text('open'));
          },
        );
      });
    }
  }
}
