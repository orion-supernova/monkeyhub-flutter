import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

/// Reshaping a patch that is already down, LinkedIn style: grab a side and
/// that side follows the finger, grab a corner and the far corner stays put.
/// A legal new shape replaces the patch in one undo step; an illegal one
/// leaves it as it was; a press that never moves is still a tap.
void main() {
  group('PatchGrip', () {
    const n = 7;
    // Rows 1..3, columns 2..5: a 3x4 patch.
    const rect = PatchRect(1, 2, 3, 5);
    int cell(int r, int c) => r * n + c;

    test('a corner pins the far corner', () {
      final g = PatchGrip.at(0, rect, cell(1, 2), n)!;
      expect(g.reshape(cell(0, 0), n), const PatchRect(0, 0, 3, 5));
      expect(g.reshape(cell(3, 5), n), const PatchRect(3, 5, 3, 5));
      expect(g.cursor, SystemMouseCursors.resizeUpLeftDownRight);
      final other = PatchGrip.at(0, rect, cell(1, 5), n)!;
      expect(other.cursor, SystemMouseCursors.resizeUpRightDownLeft);
    });

    test('a side moves only that side', () {
      final g = PatchGrip.at(0, rect, cell(3, 3), n)!; // bottom side
      expect(g.reshape(cell(5, 0), n), const PatchRect(1, 2, 5, 5));
      expect(g.reshape(cell(0, 6), n), const PatchRect(0, 2, 1, 5));
      expect(g.cursor, SystemMouseCursors.resizeUpDown);
      final left = PatchGrip.at(0, rect, cell(2, 2), n)!;
      expect(left.reshape(cell(6, 0), n), const PatchRect(1, 0, 3, 5));
      expect(left.cursor, SystemMouseCursors.resizeLeftRight);
    });

    test('a strip pulls out either way along its short side', () {
      const strip = PatchRect(2, 1, 2, 4);
      final g = PatchGrip.at(0, strip, cell(2, 2), n)!;
      expect(g.reshape(cell(0, 2), n), const PatchRect(0, 1, 2, 4));
      expect(g.reshape(cell(4, 6), n), const PatchRect(2, 1, 4, 4));
    });

    test('the inside of a big patch grips nothing', () {
      expect(PatchGrip.at(0, rect, cell(2, 3), n), isNull);
    });
  });

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

  /// A legal patch for some clue and a second legal patch for the same clue
  /// that [ok] accepts as a reshape of the first.
  (int, PatchRect, PatchRect)? pairWhere(
    bool Function(PatchRect a, PatchRect b) ok,
  ) {
    final b = board();
    final n = b.size;
    final legal = <int, List<PatchRect>>{};
    for (var x = 0; x < n * n; x++) {
      for (var y = x; y < n * n; y++) {
        final r = PatchRect.span(x, y, n);
        final j = patchJudge(b, r);
        if (j.trouble == null && j.clue >= 0) {
          (legal[j.clue] ??= []).add(r);
        }
      }
    }
    for (final e in legal.entries) {
      for (final a in e.value) {
        for (final c in e.value) {
          if (a != c && ok(a, c)) return (e.key, a, c);
        }
      }
    }
    return null;
  }

  Future<void> drag(WidgetTester tester, List<int> cells) async {
    final s = surface(tester);
    s.onDragStart!();
    for (final c in cells) {
      s.onDragTo!(c);
    }
    await tester.pump(const Duration(milliseconds: 16));
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
  }

  GameTool undoTool(WidgetTester tester) =>
      tester.widgetList<GameTool>(find.byType(GameTool)).first;

  testWidgets('grabbing a side moves just that side', (tester) async {
    await mount(tester);
    // Same clue, one side moved, and a square on that side that is not a
    // corner, so the press is a side grip and not a corner one.
    final found = pairWhere(
      (a, b) =>
          a.top == b.top &&
          a.left == b.left &&
          a.right == b.right &&
          a.bottom != b.bottom &&
          a.cols >= 3,
    );
    expect(found, isNotNull, reason: 'no clue can grow along one side');
    final (k, a, b) = found!;
    final n = board().size;
    await drag(tester, [a.top * n + a.left, a.bottom * n + a.right]);
    expect(painter(tester).patches[k], a);

    // The middle of the bottom side, dragged to b's bottom row, and sideways
    // too: the columns hold.
    final grab = a.bottom * n + a.left + 1;
    final s = surface(tester);
    s.onDragStart!();
    s.onDragTo!(grab);
    s.onDragTo!(b.bottom * n + (a.left == 0 ? n - 1 : 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(painter(tester).preview, b);
    expect(painter(tester).previewOk, isTrue);
    expect(painter(tester).lifting, contains(k));
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches[k], b);

    // One undo step brings the old shape back.
    undoTool(tester).onTap!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches[k], a);
    await done(tester);
  });

  testWidgets('grabbing a corner pins the far corner', (tester) async {
    await mount(tester);
    final found = pairWhere(
      (a, b) => a.top == b.top && a.left == b.left && a.area > 1,
    );
    expect(found, isNotNull, reason: 'no clue can be dragged out by a corner');
    final (k, a, b) = found!;
    final n = board().size;
    await drag(tester, [a.top * n + a.left, a.bottom * n + a.right]);
    expect(painter(tester).patches[k], a);

    await drag(tester, [
      a.bottom * n + a.right,
      b.bottom * n + b.right,
    ]);
    expect(painter(tester).patches[k], b);
    await done(tester);
  });

  testWidgets('an illegal new shape leaves the patch as it was', (
    tester,
  ) async {
    await mount(tester);
    final patches = answerPatches();
    final k = patches.indexWhere((p) => p!.area > 1);
    final p = patches[k]!;
    final n = board().size;
    await drag(tester, [p.top * n + p.left, p.bottom * n + p.right]);
    expect(painter(tester).patches[k], p);

    // Pulled from its bottom-right corner to whichever board corner is
    // farthest: that takes in every other clue in the way, so it is red.
    final s = surface(tester);
    final far = (p.top < n - 1 - p.bottom ? n - 1 : 0) * n +
        (p.left < n - 1 - p.right ? n - 1 : 0);
    final grabCell = p.bottom * n + p.right;
    final grip = PatchGrip.at(k, p, grabCell, n)!;
    final target = grip.reshape(far, n);
    expect(patchJudge(board(), target).trouble, isNotNull);
    s.onDragStart!();
    s.onDragTo!(grabCell);
    s.onDragTo!(far);
    await tester.pump(const Duration(milliseconds: 16));
    expect(painter(tester).previewOk, isFalse);
    // The patch in hand fades under the red outline.
    expect(painter(tester).lifting, contains(k));
    s.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).preview, isNull);
    expect(painter(tester).patches[k], p);
    expect(painter(tester).lifting, isEmpty);

    // Nothing changed, so undo still takes back the first stroke only.
    undoTool(tester).onTap!();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painter(tester).patches[k], isNull);
    await done(tester);
  });

  testWidgets('a press on a side that never moves is a tap, and lifts it', (
    tester,
  ) async {
    await mount(tester);
    final patches = answerPatches();
    final k = patches.indexWhere((p) => p!.area > 1);
    final p = patches[k]!;
    final n = board().size;
    await drag(tester, [p.top * n + p.left, p.bottom * n + p.right]);
    await drag(tester, [p.bottom * n + p.right]);
    expect(painter(tester).patches[k], isNull);

    // And a fresh stroke from bare board still lays a patch.
    await drag(tester, [p.top * n + p.left, p.bottom * n + p.right]);
    expect(painter(tester).patches[k], p);
    await done(tester);
  });

  testWidgets('a mouse over a patch corner shows a resize arrow', (
    tester,
  ) async {
    await mount(tester);
    final patches = answerPatches();
    final k = patches.indexWhere((p) => p!.rows > 1 && p.cols > 1);
    final p = patches[k]!;
    final n = board().size;
    await drag(tester, [p.top * n + p.left, p.bottom * n + p.right]);

    final box = tester.getRect(find.byType(GameBoardSurface));
    final cell = box.shortestSide / n;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      box.topLeft + Offset((p.left + 0.5) * cell, (p.top + 0.5) * cell),
    );
    await tester.pump();
    final region = tester.widget<MouseRegion>(
      find
          .ancestor(
            of: find.byType(GameBoardSurface),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.resizeUpLeftDownRight);
    await done(tester);
  });
}
