// Throwaway: a daily board right after the Hint tool is tapped, on an empty
// board, a mostly-filled one and one with a mistake, light and dark.
// See preview_kit.dart.
//
// The hints in hint_scenarios.json are what `backend/convex/games/hints.ts`
// answers for exactly these boards (today's fixture day). Run with
// `--dart-define=HINT_PREVIEW=before` to replay the old reply instead (just
// `index`/`value`, which is all a server from before explained hints sent).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/daily_game_screens.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

const _mode = String.fromEnvironment('HINT_PREVIEW', defaultValue: 'after');

GameHint _hintOf(Map<String, dynamic> j) {
  List<int> ints(Object? v) => [
    for (final c in (v as List?) ?? const []) (c as num).toInt(),
  ];
  return GameHint(
    index: (j['index'] as num).toInt(),
    value: (j['value'] as num).toInt(),
    cells: ints(j['cells']),
    kind: GameHintKind.parse(j['kind'] as String?),
    cell: (j['cell'] as num?)?.toInt(),
    answer: (j['answer'] as num?)?.toInt(),
    reason: j['reason'] as String?,
    area: ints(j['area']),
    cause: ints(j['cause']),
    digit: (j['digit'] as num?)?.toInt(),
    more: (j['more'] as num?)?.toInt() ?? 0,
  );
}

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    final tmp = await Directory.systemTemp.createTemp('hints_preview');
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
  final scenarios = (jsonDecode(
    File('test/design_preview/hint_scenarios.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  for (final id in ['basic', 'basic_daylight']) {
    for (final s in scenarios) {
      final game = DailyGame.parse(s['game'] as String)!;
      final name = '${game.wire}_${s['scenario']}';
      testWidgets('$name $id $_mode', (tester) async {
        final hint = _mode == 'before'
            ? _hintOf((s['old'] as Map).cast<String, dynamic>())
            : _hintOf((s['hint'] as Map).cast<String, dynamic>());
        GamesStore.instance.api = FakeGamesApi(
          payload,
          progress: {game: (s['progress'] as List).cast<int>()},
          hintAnswer: hint,
        );
        GamesStore.instance.clear();
        await tester.runAsync(() => GamesStore.instance.load('u1'));
        await snap(
          tester,
          previewApp(ThemeController.byId(id), dailyGameScreen(game, 'u1')),
          'hint_${name}_${id}_$_mode.png',
          act: () async {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.tap(find.text('Hint'));
            await tester.pump();
          },
        );
        await tester.pumpWidget(const SizedBox());
        FeedStore.instance.stop();
        GamesStore.instance.clear();
      });
    }
  }
}
