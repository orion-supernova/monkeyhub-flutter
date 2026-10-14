// The Feed's Activity list, rendered to PNG: a single game with its stats, a
// friend's several games folded into one row (shut and opened), a give-up.
//
//   flutter test test/design_preview/activity_preview.dart
//
// Not a test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_play.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_activity.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

final _now = DateTime.now();

GamePlay _p(
  String id,
  String name,
  DailyGame? game,
  int secs, {
  int ago = 5,
  bool solved = true,
  int mistakes = 0,
  int hints = 0,
}) =>
    GamePlay(
      userId: id,
      name: name,
      game: game,
      solved: solved,
      result: game == null
          ? (solved ? '3/6' : 'X/6')
          : (solved ? formatGameTime(secs * 1000) : ''),
      durationMs: solved && game != null ? secs * 1000 : null,
      mistakes: mistakes,
      hintsUsed: hints,
      finishedAt: _now.subtract(Duration(minutes: ago)),
    );

Moment _m(String id, String caption, int ago, {bool seen = true}) => Moment(
  id: id,
  userId: 'u_a',
  dayKey: '2026-10-14',
  createdAt: _now.subtract(Duration(minutes: ago)),
  expiresAt: _now.add(const Duration(hours: 20)),
  authorName: 'Alperen Subaşı',
  authorUsername: 'alperen',
  mine: false,
  seen: seen,
  caption: caption,
  mediaStorageId: 'img_$id',
  mediaKind: MomentMedia.image,
);

// The screenshot's day: Alperen's two highlights back to back, a long-named
// friend's games in between, then Alperen again, so the run splits.
final _moments = [
  _m('a1', 'Atıştırmaya devamm', 120, seen: false),
  _m('a2', 'Kütüpe mola verdik, parkta ufak bir yürüyüş', 130),
  _m('a3', 'Kütüpe gidiyom ders çalışmaya, akşama görüşürüz', 300),
];

final _plays = [
  _p('u_j', 'Johnathan Coachella', DailyGame.zip, 30, ago: 240),
  // Bilgekaan's ten: the names scroll rather than ellipsize.
  for (final (i, g) in DailyGame.values.indexed)
    _p('u_b', 'Bilgekaan Sevim', g, 60 + i * 7, ago: 400 + i, mistakes: i % 3),
  _p('u_b', 'Bilgekaan Sevim', null, 0, ago: 420),
  _p('u_j', 'Johnathan Coachella', null, 0, ago: 250),
  _p('u_e', 'Ece Yıldız', DailyGame.queens, 102, ago: 3, mistakes: 2, hints: 1),
  _p('u_d', 'Deniz Kaya', DailyGame.zip, 41, ago: 12),
  _p('u_d', 'Deniz Kaya', DailyGame.tango, 55, ago: 20, mistakes: 1),
  _p('u_d', 'Deniz Kaya', null, 0, ago: 31),
  _p('u_d', 'Deniz Kaya', DailyGame.sudoku, 0, ago: 40, solved: false),
  _p('u_m', 'Mert', DailyGame.flow, 0, ago: 50, solved: false),
];

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in [
      'queens', 'tango', 'zip', 'sudoku', 'flow', 'futoshiki', 'nonogram',
      'minesweeper', 'starbattle', 'patches',
    ])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  setUpAll(loadPreviewFonts);
  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    GamesStore.instance.clear();
  });

  for (final open in [false, true]) {
    testWidgets('activity preview open=$open', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId('basic'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: MomentActivity(
                  moments: _moments,
                  plays: _plays,
                  viewerId: 'u1',
                  api: ChatApi(ConvexBackend.instance),
                  onOpen: (_, _) {},
                  onOpenPlay: (_) {},
                ),
              ),
            ),
          ),
        ),
        'activity_${open ? 'open' : 'shut'}.png',
        size: const Size(393, 1300),
        act: () async {
          await tester.runAsync(GamesStore.instance.loadBoards);
          await tester.pump(const Duration(milliseconds: 100));
          if (open) {
            await tester.tap(find.textContaining('Deniz Kaya'));
            await tester.tap(find.textContaining('posted 2'));
          }
        },
      );
    });
  }
}
