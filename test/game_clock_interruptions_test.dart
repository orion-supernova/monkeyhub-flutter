import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_play_controller.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/game_scaffold.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// A daily game's clock times the solve, not whatever took the player away
/// from it: the app leaving the foreground, a route pushed over the board, or
/// a phone call — including one answered from the banner, which never moves
/// the app out of `resumed` at all.
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

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('game_clock_interruptions');
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
    FeedStore.instance.start();
  });

  tearDown(() {
    GamesStore.instance.clear();
    FeedStore.instance.stop();
  });

  // A wall clock the test moves by hand, so "ten minutes on the phone" takes
  // no time at all.
  late DateTime wall;
  void advance(WidgetTester tester, Duration d) => wall = wall.add(d);

  Future<(GamePlayController, ValueNotifier<bool>)> started(
    WidgetTester tester,
  ) async {
    wall = DateTime(2026, 10, 13, 9);
    final calls = ValueNotifier(false);
    final play = GamePlayController(
      game: DailyGame.queens,
      userId: 'u1',
      calls: calls,
      now: () => wall,
    );
    await play.begin();
    play.startClock();
    advance(tester, const Duration(seconds: 30));
    expect(play.elapsed, const Duration(seconds: 30));
    return (play, calls);
  }

  // Disposed inside the test body: its ticker is a pending timer otherwise.
  void end(GamePlayController play, ValueNotifier<bool> calls) {
    play.dispose();
    calls.dispose();
  }

  void lifecycle(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.handleAppLifecycleStateChanged(state);

  testWidgets('a glance at notification centre stops the clock without '
      'putting the card up', (tester) async {
    final (play, calls) = await started(tester);

    lifecycle(tester, AppLifecycleState.inactive);
    advance(tester, const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(play.elapsed, const Duration(seconds: 30));
    expect(play.paused, isFalse);

    lifecycle(tester, AppLifecycleState.resumed);
    // Past the cover delay: the timer was cancelled, the card stays down.
    await tester.pump(GamePlayController.coverAfter);
    expect(play.paused, isFalse);
    advance(tester, const Duration(seconds: 5));
    expect(play.elapsed, const Duration(seconds: 35));

    end(play, calls);
  });

  testWidgets('a long inactive spell puts the card up, and resume carries on '
      'from the same time', (tester) async {
    final (play, calls) = await started(tester);

    lifecycle(tester, AppLifecycleState.inactive);
    advance(tester, const Duration(minutes: 4));
    await tester.pump(GamePlayController.coverAfter);
    expect(play.paused, isTrue);

    lifecycle(tester, AppLifecycleState.resumed);
    advance(tester, const Duration(seconds: 10));
    expect(play.paused, isTrue, reason: 'the player taps back in');
    expect(play.elapsed, const Duration(seconds: 30));

    play.resume();
    advance(tester, const Duration(seconds: 2));
    expect(play.elapsed, const Duration(seconds: 32));

    end(play, calls);
  });

  testWidgets('backgrounding pauses at once', (tester) async {
    final (play, calls) = await started(tester);

    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.paused);
    expect(play.paused, isTrue);
    advance(tester, const Duration(minutes: 12));

    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump(GamePlayController.coverAfter);
    expect(play.paused, isTrue);
    expect(play.elapsed, const Duration(seconds: 30));

    play.resume();
    advance(tester, const Duration(seconds: 3));
    expect(play.elapsed, const Duration(seconds: 33));

    end(play, calls);
  });

  testWidgets('a call answered without leaving the app pauses the clock',
      (tester) async {
    final (play, calls) = await started(tester);

    // The banner rings and is answered; the app never stops being resumed.
    calls.value = true;
    await tester.pump();
    expect(play.paused, isTrue);
    advance(tester, const Duration(minutes: 8));
    calls.value = false;
    await tester.pump();
    expect(play.elapsed, const Duration(seconds: 30));

    play.resume();
    advance(tester, const Duration(seconds: 4));
    expect(play.elapsed, const Duration(seconds: 34));

    end(play, calls);
  });

  testWidgets('a player who taps back in mid-call is timed', (tester) async {
    final (play, calls) = await started(tester);

    calls.value = true;
    await tester.pump();
    expect(play.paused, isTrue);

    // Still talking, but playing again: the card does not come back.
    play.resume();
    advance(tester, const Duration(seconds: 20));
    await tester.pump();
    expect(play.paused, isFalse);
    expect(play.elapsed, const Duration(seconds: 50));

    // Hang up, and the next call pauses again.
    calls.value = false;
    await tester.pump();
    calls.value = true;
    await tester.pump();
    expect(play.paused, isTrue);

    end(play, calls);
  });

  testWidgets('a call right after opening still pauses the board',
      (tester) async {
    wall = DateTime(2026, 10, 13, 9);
    final calls = ValueNotifier(false);
    final play = GamePlayController(
      game: DailyGame.queens,
      userId: 'u1',
      calls: calls,
      now: () => wall,
    );
    addTearDown(() {
      play.dispose();
      calls.dispose();
    });
    await play.begin();
    calls.value = true;
    await tester.pump();
    expect(play.paused, isTrue);
  });

  testWidgets('a route pushed over the board holds the clock, and the '
      'card goes up if it stays', (tester) async {
    wall = DateTime(2026, 10, 13, 9);
    final calls = ValueNotifier(false);
    final play = GamePlayController(
      game: DailyGame.queens,
      userId: 'u1',
      calls: calls,
      now: () => wall,
    );
    addTearDown(calls.dispose);
    await tester.runAsync(() => GamesStore.instance.load('u1'));
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: ListenableBuilder(
            listenable: play,
            builder: (context, _) => GameScaffold(
              controller: play,
              title: 'Queens',
              rule: 'One crown per row.',
              board: const ColoredBox(color: Colors.black),
              tools: const [],
              viewerId: 'u1',
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(play.begin);
    await tester.pump();
    play.startClock();
    advance(tester, const Duration(seconds: 30));

    // The call screen (or any other route) slides over the game.
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pump();
    advance(tester, const Duration(seconds: 1));
    expect(play.elapsed, const Duration(seconds: 30));
    expect(play.paused, isFalse);

    // Back within the grace: the clock simply carries on.
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    advance(tester, const Duration(seconds: 2));
    expect(play.paused, isFalse);
    expect(play.elapsed, const Duration(seconds: 32));

    // Pushed again and left there: the card goes up behind it.
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pump();
    advance(tester, const Duration(minutes: 5));
    await tester.pump(GamePlayController.coverAfter);
    expect(play.paused, isTrue);

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(play.paused, isTrue);
    expect(play.elapsed, const Duration(seconds: 32));

    play.resume();
    advance(tester, const Duration(seconds: 1));
    expect(play.elapsed, const Duration(seconds: 33));

    await tester.pumpWidget(const SizedBox());
    play.dispose();
  });

  testWidgets('going to the background saves the board once per trip, so a '
      'kill from there loses nothing', (tester) async {
    final (play, calls) = await started(tester);
    final api = GamesStore.instance.api as FakeGamesApi;
    var board = [1, 2, 3];
    play.snapshot = () => board;

    lifecycle(tester, AppLifecycleState.inactive);
    expect(api.saves, isEmpty, reason: 'a glance saves nothing');
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.paused);
    expect(api.saves, hasLength(1));
    expect(api.saves.single.progress, [1, 2, 3]);
    expect(api.saves.single.elapsedMs, 30000);

    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    board = [4];
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.hidden);
    expect(api.saves, hasLength(2));
    expect(api.saves.last.progress, [4]);

    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump(GamePlayController.coverAfter);
    end(play, calls);
  });
}
