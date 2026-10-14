// The leaderboard, rendered to PNG: streaks, the podium, the rows.
//
//   flutter test test/design_preview/leaderboard_preview.dart
//
// Not a test. Tall frames, so the whole page is one picture.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_record.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/screens/games/streak_card.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

GameResult _r(DailyGame g, String id, String name, int secs, {bool solved = true}) =>
    GameResult(
      game: g,
      solved: solved,
      gaveUp: !solved,
      finished: true,
      durationMs: solved ? secs * 1000 : null,
      userId: id,
      name: name,
    );

final _standings = GameStandings(
  boards: {
    DailyGame.queens: [
      _r(DailyGame.queens, 'u_e', 'Ece Yıldız', 61),
      _r(DailyGame.queens, 'u1', '', 74),
      _r(DailyGame.queens, 'u_d', 'Deniz Kaya', 102),
      // A dead heat with the leader, to the second: two golds.
      _r(DailyGame.queens, 'u_m', 'Mert', 61),
      _r(DailyGame.queens, 'u_a', 'Arda', 0, solved: false),
    ],
    DailyGame.tango: [
      _r(DailyGame.tango, 'u1', '', 48),
      _r(DailyGame.tango, 'u_e', 'Ece Yıldız', 55),
      _r(DailyGame.tango, 'u_s', 'Selin', 90),
    ],
    DailyGame.zip: [
      _r(DailyGame.zip, 'u_e', 'Ece Yıldız', 33),
      _r(DailyGame.zip, 'u_d', 'Deniz Kaya', 41),
      _r(DailyGame.zip, 'u_m', 'Mert', 52),
    ],
    DailyGame.sudoku: [
      _r(DailyGame.sudoku, 'u_s', 'Selin', 120),
    ],
  },
  streaks: {
    'u_e': {DailyGame.queens: 12, DailyGame.zip: 4},
    'u1': {DailyGame.tango: 7, DailyGame.queens: 3},
    'u_d': {DailyGame.zip: 2},
    'u_s': {DailyGame.sudoku: 5},
  },
  names: const {
    'u_e': 'Ece Yıldız',
    'u_d': 'Deniz Kaya',
    'u_s': 'Selin',
  },
  myStreaks: {
    null: const GameStreak(current: 0, best: 9, today: false),
    DailyGame.queens: const GameStreak(current: 3, best: 3, today: true),
    DailyGame.tango: const GameStreak(current: 7, best: 11, today: true),
    DailyGame.zip: const GameStreak(current: 4, best: 6, today: false),
  },
);

GameRecordRow _rec(
  String id,
  String user,
  String name,
  int rank,
  int best, {
  List<RecordReaction> reactions = const [],
  List<({String userId, String name, String emoji})> reactors = const [],
  String? mine,
}) =>
    GameRecordRow(
      recordId: id,
      userId: user,
      name: name,
      rank: rank,
      best: best,
      dayKey: '2026-10-03',
      achievedAt: DateTime(2026, 10, 3),
      solves: 12,
      reactions: reactions,
      reactors: reactors,
      mine: mine,
    );

final _records = RecordBoard(games: {
  RecordGame.code: [_rec('c1', 'u_e', 'Ece Yıldız', 1, 2)],
  RecordGame.queens: [
    _rec('q1', 'u_e', 'Ece Yıldız', 1, 72000,
        reactions: const [
          RecordReaction(emoji: '🔥', count: 3),
          RecordReaction(emoji: '👏', count: 2),
          RecordReaction(emoji: '🐐', count: 1),
        ],
        reactors: const [
          (userId: 'u_m', name: 'Mert', emoji: '🔥'),
          (userId: 'u_s', name: 'Selin', emoji: '👏'),
          (userId: 'u_d', name: 'Deniz Kaya', emoji: '🔥'),
          (userId: 'u_a', name: 'Arda', emoji: '🐐'),
        ]),
    _rec('q2', 'u_m', 'Mert', 2, 80000,
        reactions: const [RecordReaction(emoji: '🔥', count: 2)]),
    _rec('q3', 'u_s', 'Selin', 3, 91000),
    _rec('q4', 'u1', '', 4, 90000),
    _rec('q5', 'u_d', 'Deniz Kaya', 5, 104000),
  ],
  RecordGame.tango: [_rec('t1', 'u1', '', 1, 48000)],
  // A shared record: same best to the second, both rank 1.
  RecordGame.zip: [
    _rec('z1', 'u_e', 'Ece Yıldız', 1, 33200),
    _rec('z2', 'u_d', 'Deniz Kaya', 1, 33900),
    _rec('z3', 'u1', '', 3, 41000),
  ],
});

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
    GamesStore.instance.api = FakeGamesApi(payload, standingsAnswer: _standings);
    RecordsStore.instance.api = FakeGamesApi(payload)..records = _records;
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
  });

  testWidgets('lb preview: streak sheet', (tester) async {
    await snap(
      tester,
      previewApp(
        ThemeController.byId('basic'),
        LeaderboardScreen(
          feedApi: FeedApi(ConvexBackend.instance),
          userId: 'u1',
        ),
      ),
      'lb_streaks_basic.png',
      act: () async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.descendant(
          of: find.byType(StreakCard),
          matching: find.text('Zip'),
        ));
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
    );
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  });

  for (final id in ['basic', 'risograph_pop']) {
    testWidgets('lb preview: records sheet $id', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          LeaderboardScreen(
            feedApi: FeedApi(ConvexBackend.instance),
            userId: 'u1',
            initialTab: 2,
          ),
        ),
        'lb_sheet_$id.png',
        act: () async {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.ensureVisible(find.text('See all'));
          await tester.pump();
          await tester.tap(find.text('See all'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          // The palette, opened from its button.
          await tester.tap(find.text('Cheer'));
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        },
      );
      await tester.pumpWidget(const SizedBox());
      FeedStore.instance.stop();
    });
  }

  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    for (final (name, tab) in [('today', 0), ('queens', 2), ('sudoku', 5)]) {
      testWidgets('lb preview: $name $id', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            LeaderboardScreen(
              feedApi: FeedApi(ConvexBackend.instance),
              userId: 'u1',
              initialTab: tab,
            ),
          ),
          'lb_${name}_$id.png',
          size: const Size(393, 2600),
          // The fake answers land after the first pump; let the podium's
          // entrance finish after them.
          act: () async {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(seconds: 1));
          },
        );
        await tester.pumpWidget(const SizedBox());
        FeedStore.instance.stop();
      });
    }
  }
}
