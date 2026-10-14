import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/games/patches_board_art.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/game_scaffold.dart';
import 'package:monkeyhub/screens/games/patches_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// Patches played for real, through its screen: a stroke corner to corner
/// lays a patch, an illegal one lays nothing, a landing patch lifts whatever
/// it covers, a tap (steady or not) lifts a patch, a hint lays a whole patch
/// or lifts a wrong one, and a board cut completely submits itself.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in DailyGame.values)
      game.wire: ((day[game.wire] as Map)['board'] as Map)
          .cast<String, dynamic>(),
  };
  final answer = ((day['patches'] as Map)['answer'] as List).cast<int>();

  late Directory tmp;
  late FakeGamesApi api;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('patches_play');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  tearDown(GamesStore.instance.clear);

  Future<void> mount(
    WidgetTester tester, {
    GameHint hint = const GameHint(index: -1, value: 0),
  }) async {
    api = FakeGamesApi(payload, hintAnswer: hint);
    GamesStore.instance.api = api;
    GamesStore.instance.clear();
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => GamesStore.instance.load('u1'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: const PatchesScreen(userId: 'u1'),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  GameBoardSurface surface(WidgetTester tester) =>
      tester.widget<GameBoardSurface>(find.byType(GameBoardSurface));

  PatchesBoardPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(GameBoardSurface),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as PatchesBoardPainter;

  PatchesBoard board() => GamesStore.instance.boards.patches;
  List<PatchRect?> answerPatches() => patchesFromLabels(board(), answer);

  /// A stroke from [from] to [to], through the squares between them in a
  /// straight run first along the row and then down the column, the way a
  /// finger crossing the board reports them.
  Future<void> stroke(WidgetTester tester, int from, int to) async {
    final n = board().size;
    final s = surface(tester);
    s.onDragStart!();
    var at = from;
    s.onDragTo!(at);
    while (at % n != to % n) {
      at += to % n > at % n ? 1 : -1;
      s.onDragTo!(at);
    }
    while (at ~/ n != to ~/ n) {
      at += to ~/ n > at ~/ n ? n : -n;
      s.onDragTo!(at);
    }
    await tester.pump(const Duration(milliseconds: 16));
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
  }

  int topLeft(PatchRect p) => p.top * board().size + p.left;
  int bottomRight(PatchRect p) => p.bottom * board().size + p.right;

  testWidgets('cutting every patch submits the server answer once', (
    tester,
  ) async {
    await mount(tester);
    final patches = answerPatches();
    // Odd patches drawn from the far corner back: either way round is a
    // stroke.
    for (var k = 0; k < patches.length; k++) {
      final p = patches[k]!;
      if (k.isOdd) {
        await stroke(tester, bottomRight(p), topLeft(p));
      } else {
        await stroke(tester, topLeft(p), bottomRight(p));
      }
    }
    await tester.pump(const Duration(seconds: 2));
    expect(api.submittedSolutions, [answer]);
    expect(api.submittedMistakes, [0]);
    await done(tester);
  });

  testWidgets('the stroke previews in colour or red, and only a legal one lands', (
    tester,
  ) async {
    await mount(tester);
    final n = board().size;
    final s = surface(tester);

    // The whole board: every clue inside, so red, and nothing lands.
    s.onDragStart!();
    s.onDragTo!(0);
    s.onDragTo!(n * n - 1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(painter(tester).preview, PatchRect(0, 0, n - 1, n - 1));
    expect(painter(tester).previewOk, isFalse);
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).preview, isNull);
    expect(painter(tester).patches.every((p) => p == null), isTrue);

    // A real patch: in its clue's colour while dragged, down once let go.
    final p = answerPatches().first!;
    s.onDragStart!();
    s.onDragTo!(topLeft(p));
    s.onDragTo!(bottomRight(p));
    await tester.pump(const Duration(milliseconds: 16));
    expect(painter(tester).previewOk, isTrue);
    expect(painter(tester).previewClue, 0);
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches.first, p);
    expect(api.submittedSolutions, isEmpty);
    await done(tester);
  });

  testWidgets('a patch landing on another lifts it, and undo puts it back', (
    tester,
  ) async {
    await mount(tester);
    final p0 = answerPatches()[0]!;
    await stroke(tester, topLeft(p0), bottomRight(p0));
    expect(painter(tester).patches[0], p0);

    // Any legal patch for another clue that overlaps p0, found by search.
    final n = board().size;
    PatchRect? rival;
    int? rivalClue;
    for (var a = 0; a < n * n && rival == null; a++) {
      for (var b = a; b < n * n && rival == null; b++) {
        final r = PatchRect.span(a, b, n);
        final judged = patchJudge(board(), r);
        if (judged.trouble == null && judged.clue != 0 && r.overlaps(p0)) {
          rival = r;
          rivalClue = judged.clue;
        }
      }
    }
    expect(rival, isNotNull, reason: 'no legal patch overlaps the first one');

    final s = surface(tester);
    s.onDragStart!();
    s.onDragTo!(topLeft(rival!));
    s.onDragTo!(bottomRight(rival));
    await tester.pump(const Duration(milliseconds: 16));
    // Faded while the finger is still down: this is what letting go costs.
    expect(painter(tester).lifting, contains(0));
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches[0], isNull);
    expect(painter(tester).patches[rivalClue!], rival);

    tester
        .widgetList<GameTool>(find.byType(GameTool))
        .first // Undo, Clear, Hint, Give up.
        .onTap!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches[0], p0);
    expect(painter(tester).patches[rivalClue], isNull);
    await done(tester);
  });

  testWidgets('a tap lifts a patch, and so does a tap with a wobble in it', (
    tester,
  ) async {
    await mount(tester);
    final patches = answerPatches();
    final big = patches.indexWhere((p) => p!.area > 1);
    final p = patches[big]!;

    await stroke(tester, topLeft(p), bottomRight(p));
    surface(tester).onTapCell!(bottomRight(p));
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches[big], isNull);

    await stroke(tester, topLeft(p), bottomRight(p));
    // Pressed and released on one square, but moved a pixel in between: the
    // board reports it as a one-square stroke.
    await stroke(tester, topLeft(p), topLeft(p));
    expect(painter(tester).patches[big], isNull);
    await done(tester);
  });

  testWidgets('a hint lays a whole patch, asked with the board as labels', (
    tester,
  ) async {
    final b = PatchesBoard.fromJson(
      (payload['patches'] as Map).cast<String, dynamic>(),
    );
    final patch = [
      for (var i = 0; i < answer.length; i++)
        if (answer[i] == 2) i,
    ];
    await mount(
      tester,
      hint: GameHint(
        index: b.clues[2].cell,
        value: 2,
        answer: 2,
        cell: b.clues[2].cell,
        kind: GameHintKind.step,
        reason: 'patches.only',
        cells: patch,
        area: patch,
      ),
    );
    tester.widgetList<GameTool>(find.byType(GameTool)).elementAt(2).onTap!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(painter(tester).patches[2], patchesFromLabels(b, answer)[2]);
    expect(api.hintBoards.single, List<int>.filled(b.size * b.size, -1));
    await done(tester);
  });

  testWidgets('a wrong-patch hint lifts it', (tester) async {
    final b = PatchesBoard.fromJson(
      (payload['patches'] as Map).cast<String, dynamic>(),
    );
    // Clue 0's patch as just the clue's own square only lands if that is
    // legal; any legal patch of clue 0 that is not the answer will do.
    final n = b.size;
    final right = patchesFromLabels(b, answer)[0]!;
    PatchRect? wrong;
    for (var a = 0; a < n * n && wrong == null; a++) {
      for (var c = a; c < n * n && wrong == null; c++) {
        final r = PatchRect.span(a, c, n);
        final judged = patchJudge(b, r);
        if (judged.clue == 0 && judged.trouble == null && r != right) wrong = r;
      }
    }
    expect(wrong, isNotNull, reason: 'clue 0 has only one legal patch');
    await mount(
      tester,
      hint: GameHint(
        index: b.clues[0].cell,
        value: 0,
        answer: 0,
        cell: b.clues[0].cell,
        kind: GameHintKind.wrong,
        reason: 'wrong',
        cells: wrong!.cells(n).toList(),
        area: wrong.cells(n).toList(),
      ),
    );
    await stroke(tester, topLeft(wrong), bottomRight(wrong));
    expect(painter(tester).patches[0], wrong);
    tester.widgetList<GameTool>(find.byType(GameTool)).elementAt(2).onTap!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(painter(tester).patches[0], isNull);
    await done(tester);
  });
}
