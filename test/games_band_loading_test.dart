import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/cache_store.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_board_skeleton.dart';
import 'package:monkeyhub/widgets/game_tile.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

/// The games band before its boards arrive.
///
/// Two things used to be wrong here at once, and they compounded: the band
/// re-fetched the four boards on every cold start, and what it showed in the
/// meantime was a flat `surfaceSunken` square — `#070B11`, a black box. Four
/// black boxes for the length of a round trip, every launch, and permanently if
/// that one silent call happened to fail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;

  Map<String, dynamic> payloadFor(String dayKey) => <String, dynamic>{
    'dayKey': dayKey,
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
  late String today;

  setUpAll(() async {
    // CacheStore memoises the documents directory on first use, so the channel
    // has to answer before anything in this file touches it.
    tmp = await Directory.systemTemp.createTemp('games_band_loading');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  setUp(() async {
    GamesStore.boardRetries = const [Duration.zero, Duration.zero];
    FeedStore.instance.start();
    today = FeedStore.instance.dayKey;
    GamesStore.instance.clear();
    final f = File('${tmp.path}/cache/games_daily.json');
    if (await f.exists()) await f.delete();
  });

  tearDown(() {
    GamesStore.instance.clear();
    FeedStore.instance.stop();
  });

  group('the cache', () {
    test('a payload saved for today spares the band a round trip', () async {
      await CacheStore.instance.saveDailyBoards(today, payloadFor(today));
      final api = _FakeApi()..fail = true;
      GamesStore.instance.api = api;

      await GamesStore.instance.loadBoards();

      expect(GamesStore.instance.boards.ready, isTrue);
      // The one that matters: a cache hit is not a head start on the fetch,
      // it is the whole answer. `games:daily` reads no table and the boards
      // cannot change before midnight, so asking again is pure cost.
      expect(api.dailyCalls, 0);
    });

    test('a payload saved yesterday is not today\'s puzzle', () async {
      await CacheStore.instance.saveDailyBoards(
        '1999-12-31',
        payloadFor('1999-12-31'),
      );
      final api = _FakeApi()..payload = payloadFor(today);
      GamesStore.instance.api = api;

      await GamesStore.instance.loadBoards();

      expect(api.dailyCalls, 1);
      expect(GamesStore.instance.boards.dayKey, today);
    });

    test('a fetch fills it, so the next launch reads no network', () async {
      final api = _FakeApi()..payload = payloadFor(today);
      GamesStore.instance.api = api;
      await GamesStore.instance.loadBoards();
      expect(api.dailyCalls, 1);

      // A relaunch: the store forgets everything, the network is gone.
      GamesStore.instance.clear();
      final cold = _FakeApi()..fail = true;
      GamesStore.instance.api = cold;

      await GamesStore.instance.loadBoards();

      expect(GamesStore.instance.boards.ready, isTrue);
      expect(cold.dailyCalls, 0);
    });
  });

  group('the fetch', () {
    test('retries a call that failed on a socket still coming up', () async {
      // Which is where a cold start starts. Swallowing this left the band
      // showing placeholders until the player happened to switch tabs.
      final api = _FakeApi()
        ..payload = payloadFor(today)
        ..failTimes = 1;
      GamesStore.instance.api = api;

      await GamesStore.instance.loadBoards();

      expect(api.dailyCalls, 2);
      expect(GamesStore.instance.boards.ready, isTrue);
    });

    test('gives up rather than hammering a backend that is down', () async {
      final api = _FakeApi()..fail = true;
      GamesStore.instance.api = api;

      await GamesStore.instance.loadBoards();

      expect(api.dailyCalls, 3);
      expect(GamesStore.instance.boards.ready, isFalse);
    });
  });

  group('the placeholder', () {
    Widget host(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );

    // pump, never pumpAndSettle: the skeleton sweeps on a repeating controller
    // and there is no settled frame to wait for by design.
    testWidgets('is one per tile on the Feed band, not one for the row', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 340,
            child: GamesStrip(
              boards: const DailyBoards(),
              results: const {},
              onOpen: (_) {},
              puzzle: const PuzzleState(),
              onOpenPuzzle: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byType(GameBoardSkeleton),
        findsNWidgets(DailyGame.values.length),
      );
    });

    testWidgets('stands in for a hub tile too, and gives way to the board', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          GameTile(
            game: DailyGame.queens,
            boards: const DailyBoards(),
            width: 170,
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(GameBoardSkeleton), findsOneWidget);

      await tester.pumpWidget(
        host(
          GameTile(
            game: DailyGame.queens,
            boards: DailyBoards.fromJson(payloadFor(today)),
            width: 170,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GameBoardSkeleton), findsNothing);
    });
  });
}

/// Counts the boards call and can be told to fail it.
class _FakeApi implements GamesApi {
  Map<String, dynamic> payload = const {};
  int dailyCalls = 0;

  /// Fails every attempt.
  bool fail = false;

  /// Fails the first N attempts and then answers.
  int failTimes = 0;

  @override
  Future<dynamic> dailyRaw({required String dayKey}) async {
    dailyCalls++;
    if (fail || dailyCalls <= failTimes) throw const SocketException('down');
    return payload;
  }

  @override
  Future<DailyBoards> daily({required String dayKey}) async =>
      DailyBoards.fromJson(await dailyRaw(dayKey: dayKey));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not part of this');
}
