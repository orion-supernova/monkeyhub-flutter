// Throwaway: the five newer daily boards, mid-solve, plus the games strip.
// See preview_kit.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/games/daily_game_screens.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    final tmp = await Directory.systemTemp.createTemp('daily_boards_preview');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });
  final day = ((jsonDecode(File('test/fixtures/daily_games.json')
          .readAsStringSync()) as Map)['days'] as List)
      .first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final g in DailyGame.values) g.wire: (day[g.wire] as Map)['board'],
  };
  final boards = DailyBoards.fromJson(payload);
  List<int> answer(String g) => ((day[g] as Map)['answer'] as List).cast<int>();

  // Mid-solve saves, in each screen's own autosave shape.
  final flowPipes = flowPipesOf(boards.flow, answer('flow'));
  final flowSave = List<int>.filled(49, -1);
  for (var k = 0; k < flowPipes.length - 1; k++) {
    final pipe = k == flowPipes.length - 2
        ? flowPipes[k].sublist(0, flowPipes[k].length ~/ 2)
        : flowPipes[k];
    for (var p = 0; p < pipe.length; p++) {
      flowSave[pipe[p]] = k * 64 + p;
    }
  }
  final futo = answer('futoshiki');
  final futoSave = [
    for (var i = 0; i < 25; i++)
      boards.futoshiki.givens[i] != 0 ? 0 : (i < 12 ? futo[i] : 0),
  ];
  final nono = answer('nonogram');
  final nonoSave = [
    for (var i = 0; i < 100; i++)
      i < 55
          ? (nono[i] == 1 ? nonogramFilled : nonogramCrossed)
          : (i % 10 == 2 && nono[i] == 1 ? nonogramFilled : nonogramUnknown),
  ];
  final mines = answer('minesweeper');
  final numbers = minesweeperNumbers(mines, 9);
  final msSave = List<int>.filled(81, minesweeperHidden);
  for (final i in minesweeperFlood(
    msSave,
    mines,
    numbers,
    9,
    boards.minesweeper.start,
  )) {
    msSave[i] = numbers[i];
  }
  var flagged = 0;
  for (var i = 0; i < 81 && flagged < 2; i++) {
    if (mines[i] == 1) {
      msSave[i] = flagged == 0 ? minesweeperFlagged : minesweeperStruck;
      flagged++;
    }
  }
  final sb = answer('starbattle');
  final sbSave = [
    for (var i = 0; i < 100; i++)
      i < 50 ? (sb[i] == 1 ? 2 : (i % 3 == 0 ? 1 : 0)) : 0,
  ];
  final progress = {
    DailyGame.flow: flowSave,
    DailyGame.futoshiki: futoSave,
    DailyGame.nonogram: nonoSave,
    DailyGame.minesweeper: msSave,
    DailyGame.starbattle: sbSave,
  };

  for (final id in ['basic', 'basic_daylight']) {
    for (final game in progress.keys) {
      testWidgets('${game.wire} $id', (tester) async {
        GamesStore.instance.api = FakeGamesApi(payload, progress: progress);
        GamesStore.instance.clear();
        await tester.runAsync(() => GamesStore.instance.load('u1'));
        await snap(
          tester,
          previewApp(ThemeController.byId(id), dailyGameScreen(game, 'u1')),
          'board_${game.wire}_$id.png',
          act: () async {
            // A touch on the board starts the clock, as a player's would.
            await tester.pump(const Duration(milliseconds: 100));
          },
        );
        await tester.pumpWidget(const SizedBox());
        FeedStore.instance.stop();
        GamesStore.instance.clear();
      });
    }

    testWidgets('games strip all nine $id', (tester) async {
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
        'games_strip_nine_$id.png',
        size: const Size(2100, 420),
        dpr: 1.5,
      );
    });
  }
}
