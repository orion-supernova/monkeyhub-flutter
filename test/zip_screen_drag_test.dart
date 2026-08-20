import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/games/zip_board_art.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/games/zip_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// Zip, drawn on the way it is on a phone: the real screen, the real scroll
/// view it lives in, and a finger that reports every few pixels.
///
/// `game_board_drag_test.dart` pins the gesture in isolation. This one pins
/// that the screen actually turns it on — the board only claims its drags
/// while there is a line left to draw, and that condition is a line of code
/// away from being wrong in a way no unit test would notice and every player
/// would.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in ['queens', 'tango', 'zip', 'sudoku'])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };
  final size = ((day['zip'] as Map)['board'] as Map)['size'] as int;

  late Directory tmp;

  setUpAll(() async {
    // CacheStore memoises the documents directory on first use, and the store
    // fills the cache on the way through `load` — without an answer here the
    // boot chain the board's readiness hangs off never finishes.
    tmp = await Directory.systemTemp.createTemp('zip_screen_drag');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    GamesStore.instance.clear();
  });

  tearDown(GamesStore.instance.clear);

  testWidgets('a downward stroke from ① draws the line instead of scrolling '
      'the screen', (tester) async {
    // A phone, and a short one: the screen has to be taller than the window
    // for the scroll view under the board to be the real competition it is in
    // the app.
    tester.view.physicalSize = const Size(1200, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    // The store's boot chain writes today's boards to disk on the way through,
    // and real file I/O never completes inside a widget test's fake-async
    // zone. Paying for it up front leaves the screen's own load on its
    // already-loaded fast path, which is also what the second visit of a real
    // session takes.
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
          child: const ZipScreen(userId: 'u1'),
        ),
      ),
    );
    // Boards, then the session the board waits on before it accepts anything.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final rect = tester.getRect(find.byType(GameBoardSurface));
    final cell = rect.shortestSide / size;
    Offset centerOf(int index) =>
        rect.topLeft +
        Offset(
          (index % size) * cell + cell / 2,
          (index ~/ size) * cell + cell / 2,
        );

    // ① and whichever square directly above or below it the rules will take.
    // The line has to start on ①, so that is the shortest stroke this board
    // accepts — and it is vertical, which is precisely the direction the page
    // used to take for itself.
    final zip = GamesStore.instance.boards.zip;
    final first = zip.checkpoints.first;
    final next = [first + size, first - size].firstWhere(
      (c) => c >= 0 && c < size * size && zipCanEnter(zip, [first], c),
    );
    final start = centerOf(first);
    final end = centerOf(next);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    // Otherwise the page had nothing to scroll and never entered the arena,
    // which would make the rest of this pass on its own.
    expect(position.maxScrollExtent, greaterThan(0));

    final gesture = await tester.startGesture(start);
    final steps = ((end - start).distance / 5).ceil();
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    final painter =
        tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .firstWhere((w) => w.painter is ZipBoardPainter)
                .painter
            as ZipBoardPainter;
    expect(painter.path, [first, next]);
    expect(position.pixels, 0);

    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  });
}
