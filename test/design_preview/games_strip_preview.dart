// Throwaway: the Feed's games row, grouped by tier. See preview_kit.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

import 'preview_kit.dart';

void main() {
  setUpAll(loadPreviewFonts);
  final day = ((jsonDecode(File('test/fixtures/daily_games.json')
          .readAsStringSync()) as Map)['days'] as List)
      .first as Map<String, dynamic>;
  final boards = DailyBoards.fromJson({
    'dayKey': day['dayKey'],
    for (final g in [
      'queens',
      'tango',
      'zip',
      'sudoku',
      'flow',
      'futoshiki',
      'nonogram',
      'minesweeper',
      'starbattle',
    ])
      g: (day[g] as Map)['board'],
  });

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('games strip $id', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: GamesStrip(
                boards: boards,
                results: const {},
                onOpen: (_) {},
                puzzle: const PuzzleState(),
                onOpenPuzzle: () {},
                inset: 16,
              ),
            ),
          ),
        ),
        'games_strip_$id.png',
        size: const Size(1100, 420),
        dpr: 2,
      );
    });
  }
}
