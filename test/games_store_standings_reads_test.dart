import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_record.dart';

import 'fakes/fake_games_api.dart';

/// `games:standings` is the expensive read (a row set per friend), and one
/// finished game used to cost four of them: the hub opening, the board's boot,
/// the post-finish refresh and the hub again on the way back, the last two
/// overlapping. These pin the store sharing one read where one will do, and
/// still re-reading after a finish.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in DailyGame.values)
      if (day[game.wire] is Map)
        game.wire: ((day[game.wire] as Map)['board'] as Map)
            .cast<String, dynamic>(),
  };

  late Directory tmp;
  late DateTime clock;
  late _CountingApi api;
  final store = GamesStore.instance;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('games_store_reads');
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
    clock = DateTime(2026, 10, 14, 12);
    GamesStore.now = () => clock;
    RecordsStore.now = () => clock;
    FeedStore.instance.start();
    store.clear();
    RecordsStore.instance.clear();
    api = _CountingApi(payload);
    store.api = api;
    RecordsStore.instance.api = api;
    // The hub opening: boards and standings together.
    await store.load('u1');
    expect(store.boards.ready, isTrue);
    expect(api.standingsCalls, 1);
  });

  tearDown(() {
    store.clear();
    RecordsStore.instance.clear();
    GamesStore.now = DateTime.now;
    RecordsStore.now = DateTime.now;
    FeedStore.instance.stop();
  });

  test('a board booting right after the hub reads nothing', () async {
    clock = clock.add(const Duration(seconds: 5));
    await store.load('u1');
    expect(api.standingsCalls, 1);
  });

  test('a held copy past the TTL is re-read', () async {
    clock = clock.add(GamesStore.standingsTtl + const Duration(seconds: 1));
    await store.load('u1');
    expect(api.standingsCalls, 2);
  });

  test('loads landing together share one read', () async {
    clock = clock.add(GamesStore.standingsTtl + const Duration(seconds: 1));
    api.gate = Completer<void>();
    final a = store.load('u1');
    final b = store.load('u1');
    final c = store.load('u1');
    api.gate!.complete();
    await Future.wait([a, b, c]);
    expect(api.standingsCalls, 2);
  });

  test('a finish re-reads even with a fresh copy held', () async {
    await store.refreshStandings();
    expect(api.standingsCalls, 2);
    // …and the hub on the way back finds that read fresh.
    await store.load('u1');
    expect(api.standingsCalls, 2);
  });

  test('the hub returning mid post-finish read joins it', () async {
    api.gate = Completer<void>();
    final refresh = store.refreshStandings();
    final back = store.load('u1');
    api.gate!.complete();
    await Future.wait([refresh, back]);
    expect(api.standingsCalls, 2);
  });

  test('a finish during an older read queues exactly one more', () async {
    clock = clock.add(GamesStore.standingsTtl + const Duration(seconds: 1));
    api.gate = Completer<void>();
    final boot = store.load('u1'); // issued before the result existed
    final r1 = store.refreshStandings();
    final r2 = store.refreshStandings();
    final back = store.load('u1');
    expect(api.standingsCalls, 2);
    final gate = api.gate!;
    api.gate = null;
    gate.complete();
    await Future.wait([boot, r1, r2, back]);
    expect(api.standingsCalls, 3);
  });

  test('the older read does not overwrite the optimistic row', () async {
    clock = clock.add(GamesStore.standingsTtl + const Duration(seconds: 1));
    api.gate = Completer<void>();
    final boot = store.load('u1');
    const result = GameResult(
      game: DailyGame.queens,
      solved: true,
      gaveUp: false,
      finished: true,
      durationMs: 1000,
    );
    store.noteFinished(DailyGame.queens, result);
    final refresh = store.refreshStandings();
    final gate = api.gate!;
    // The follow-up answers with the result in it; the stale one without.
    api.gate = null;
    api.answer = const GameStandings(mine: {DailyGame.queens: result});
    final seen = <bool>[];
    void watch() => seen.add(store.standings.mine.containsKey(DailyGame.queens));
    store.addListener(watch);
    gate.complete();
    await Future.wait([boot, refresh]);
    store.removeListener(watch);
    expect(seen, isNot(contains(false)));
    expect(store.standings.mine[DailyGame.queens]?.solved, isTrue);
  });

  group('records', () {
    test('a plain load inside the TTL reads nothing', () async {
      await RecordsStore.instance.load('u1');
      await RecordsStore.instance.load('u1');
      expect(api.recordCalls, 1);
    });

    test('a finish since the last read makes it stale', () async {
      await RecordsStore.instance.load('u1');
      store.noteFinished(
        DailyGame.tango,
        const GameResult(
          game: DailyGame.tango,
          solved: true,
          gaveUp: false,
          finished: true,
          durationMs: 1000,
        ),
      );
      await RecordsStore.instance.load('u1');
      expect(api.recordCalls, 2);
    });

    test('plain loads landing together share one read', () async {
      api.gate = Completer<void>();
      final a = RecordsStore.instance.load('u1');
      final b = RecordsStore.instance.load('u1');
      api.gate!.complete();
      await Future.wait([a, b]);
      expect(api.recordCalls, 1);
    });
  });
}

class _CountingApi extends FakeGamesApi {
  _CountingApi(super.payload);

  int standingsCalls = 0;
  int recordCalls = 0;
  Completer<void>? gate;
  GameStandings answer = const GameStandings();

  @override
  Future<GameStandings> standings({
    required String userId,
    required String dayKey,
  }) async {
    standingsCalls++;
    // What the server knew when asked, not when it answered.
    final now = answer;
    final g = gate;
    if (g != null) await g.future;
    return now;
  }

  @override
  Future<RecordBoard> recordBoard({required String userId}) async {
    recordCalls++;
    final g = gate;
    if (g != null) await g.future;
    return const RecordBoard();
  }
}
