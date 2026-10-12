import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/daily_game_screens.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/screens/games/queens_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// Every games screen, mounted for real underneath something already listening
/// to [GamesStore].
///
/// That last clause is the test. Every screen kicks `GamesStore.load` off
/// from `initState`, which runs inside the build that is mounting them — and
/// `FeedScreen` is listening from behind the route the whole time. A store that
/// notifies synchronously there marks a mounted widget dirty mid-build and
/// Flutter throws, which is exactly what happened on the first tap of a game
/// tile. `games_store_notify_test.dart` pins the guard; this pins that every
/// screen is actually covered by it, now and after the next one is added.
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
    ])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.clear();
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
    'the hub': LeaderboardScreen(
      feedApi: FeedApi(ConvexBackend.instance),
      userId: 'u1',
    ),
    // Every daily, through the same switch the Feed and the leaderboard open
    // them with — so a game added to the enum is mounted here without anyone
    // remembering to add it.
    for (final game in DailyGame.values) game.wire: dailyGameScreen(game, 'u1'),
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
    expect(find.text('Queens'), findsWidgets);
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
