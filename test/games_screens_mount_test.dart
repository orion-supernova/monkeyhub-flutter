import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/games_hub_screen.dart';
import 'package:monkeyhub/screens/games/queens_screen.dart';
import 'package:monkeyhub/screens/games/sudoku_screen.dart';
import 'package:monkeyhub/screens/games/tango_screen.dart';
import 'package:monkeyhub/screens/games/zip_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Every games screen, mounted for real underneath something already listening
/// to [GamesStore].
///
/// That last clause is the test. All five screens kick `GamesStore.load` off
/// from `initState`, which runs inside the build that is mounting them — and
/// `FeedScreen` is listening from behind the route the whole time. A store that
/// notifies synchronously there marks a mounted widget dirty mid-build and
/// Flutter throws, which is exactly what happened on the first tap of a game
/// tile. `games_store_notify_test.dart` pins the guard; this pins that all five
/// screens are actually covered by it, now and after the sixth one is added.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;

  final boards = DailyBoards.fromJson({
    'dayKey': day['dayKey'],
    for (final game in ['queens', 'tango', 'zip', 'sudoku'])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  });

  setUp(() {
    GamesStore.instance.api = _StubGamesApi(boards);
    GamesStore.instance.clear();
  });

  tearDown(GamesStore.instance.clear);

  /// Unmounts, and stops the clocks the screens started.
  ///
  /// Both have to happen inside the test body rather than in `tearDown`: the
  /// framework checks for leaked timers as soon as the body returns, and
  /// `FeedStore` arms a midnight timer the moment anything asks it what day it
  /// is — which `GamesStore.load` does on the way to fetching the boards.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  Widget host(Widget screen) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: _StoreListener(child: screen),
    ),
  );

  final screens = <String, Widget>{
    'the hub': GamesHubScreen(
      feedApi: FeedApi(ConvexBackend.instance),
      userId: 'u1',
    ),
    'queens': const QueensScreen(userId: 'u1'),
    'tango': const TangoScreen(userId: 'u1'),
    'zip': const ZipScreen(userId: 'u1'),
    'mini sudoku': const SudokuScreen(userId: 'u1'),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} mounts under a listener without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(host(entry.value));
      // Two pumps: the first mounts and fires the store's deferred
      // notification, the second lets the listener rebuild on it.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      await settle(tester);
    });
  }

  testWidgets('a board reaches the point where it can be played', (
    tester,
  ) async {
    await tester.pumpWidget(host(const QueensScreen(userId: 'u1')));
    await tester.pump();
    await tester.pump();

    // The board is only inert until `start` lands; if it stayed that way the
    // screen would look fine and refuse every tap.
    expect(find.text('queens'), findsWidgets);
    expect(find.text('0:00'), findsOneWidget);
    await settle(tester);
  });
}

/// Stands in for `FeedScreen`, which is listening to the store from behind the
/// route the whole time a game screen is mounting.
class _StoreListener extends StatefulWidget {
  const _StoreListener({required this.child});

  final Widget child;

  @override
  State<_StoreListener> createState() => _StoreListenerState();
}

class _StoreListenerState extends State<_StoreListener> {
  @override
  void initState() {
    super.initState();
    GamesStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    GamesStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Answers every call instantly with today's real boards and nobody's times.
class _StubGamesApi implements GamesApi {
  _StubGamesApi(this.boards);

  final DailyBoards boards;

  @override
  Future<DailyBoards> daily({required String dayKey}) async => boards;

  @override
  Future<GameStandings> standings({
    required String userId,
    required String dayKey,
  }) async => const GameStandings();

  @override
  Future<GameSession> start({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async => GameSession(
    startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    progress: const [],
    elapsedMs: 0,
    hintsUsed: 0,
    mistakes: 0,
    finished: false,
  );

  @override
  Future<void> saveProgress({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> progress,
    required int elapsedMs,
    int mistakes = 0,
  }) async {}

  @override
  Future<GameHint> hint({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> board,
  }) async => const GameHint(index: -1, value: 0);

  @override
  Future<GameOutcome> submit({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> solution,
    required int elapsedMs,
    int hintsUsed = 0,
    int mistakes = 0,
  }) async => const GameOutcome(solved: true, durationMs: 1000, replay: false);

  @override
  Future<List<int>> reveal({
    required String userId,
    required String dayKey,
    required DailyGame game,
  }) async => const [];
}
