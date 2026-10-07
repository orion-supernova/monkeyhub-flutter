import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_play_controller.dart';
import 'package:monkeyhub/models/daily_game.dart';

import 'fakes/fake_games_api.dart';

/// A solved board that cannot reach the server is held, not handed back.
///
/// The native client resends a timed-out mutation when the socket returns, so
/// a submit that "failed" may still land. Reopening the board on a timeout
/// let the player play on — unsolving it, with the clock running — until the
/// reconnect finished the game under them.
void main() {
  late FakeGamesApi api;

  setUp(() {
    api = FakeGamesApi(const {});
    GamesStore.instance.api = api;
    GamesStore.instance.clear();
    FeedStore.instance.start();
  });

  tearDown(() {
    GamesStore.instance.clear();
    FeedStore.instance.stop();
  });

  testWidgets('a submit through a dead network stays locked and resends',
      (tester) async {
    final play = GamePlayController(game: DailyGame.tango, userId: 'u1');
    await play.begin();
    play.startClock();
    await tester.pump(const Duration(seconds: 3));

    api.submitFailures = 2;
    var landed = false;
    final result = play.submit(const [1, 2]).then((ok) => landed = ok);
    await tester.pump();

    expect(play.stalled, isTrue);
    expect(play.busy, isTrue, reason: 'the board stays inert');
    expect(play.finished, isFalse);
    final frozen = play.elapsed;

    // A long outage: the clock does not move, and the retries carry the time
    // the board was solved at.
    await tester.pump(const Duration(seconds: 5));
    expect(play.stalled, isTrue);
    expect(play.elapsed, frozen);

    // Network back; the manual retry lands it.
    play.retryNow();
    await tester.pump();
    await result;
    expect(landed, isTrue);
    expect(play.finished, isTrue);
    expect(play.stalled, isFalse);
    expect(api.submitted, hasLength(3));
    expect(api.submitted.toSet(), hasLength(1));

    play.dispose();
  });

  testWidgets('leaving the screen stops the retries', (tester) async {
    final play = GamePlayController(game: DailyGame.tango, userId: 'u1');
    await play.begin();
    api.submitFailures = 100;
    final result = play.submit(const [1, 2]);
    await tester.pump();
    expect(play.stalled, isTrue);

    play.dispose();
    expect(await result, isFalse);
    final sent = api.submitted.length;
    await tester.pump(const Duration(seconds: 30));
    expect(api.submitted, hasLength(sent));
  });
}
