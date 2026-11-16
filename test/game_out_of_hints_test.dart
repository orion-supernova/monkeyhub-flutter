import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_play_controller.dart';
import 'package:monkeyhub/models/daily_game.dart';

import 'fakes/fake_games_api.dart';

/// Refuses the first hint like the server does once the free ones are gone.
class _RefusingApi extends FakeGamesApi {
  _RefusingApi() : super(const {}, hintAnswer: const GameHint(index: 4, value: 2));
  int refusals = 1;

  @override
  Future<GameHint> hint({
    required String userId,
    required String dayKey,
    required DailyGame game,
    required List<int> board,
    required int seq,
  }) async {
    if (refusals > 0) {
      refusals--;
      throw Exception('ConvexError: OUT_OF_HINTS');
    }
    return super.hint(
      userId: userId,
      dayKey: dayKey,
      game: game,
      board: board,
      seq: seq,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RefusingApi api;

  setUp(() {
    api = _RefusingApi();
    GamesStore.instance.api = api;
    GamesStore.instance.clear();
    FeedStore.instance.start();
  });

  tearDown(() {
    GamesStore.instance.clear();
    FeedStore.instance.stop();
  });

  test('OUT_OF_HINTS opens the offer and a spent banana re-asks the hint',
      () async {
    final play = GamePlayController(game: DailyGame.sudoku, userId: 'u1');
    await play.begin();
    var offered = 0;
    play.onOutOfHints = () async {
      offered++;
      return true;
    };
    final hint = await play.hint(const [0, 0]);
    expect(offered, 1);
    expect(hint?.index, 4);
    expect(play.errorCode, isNull);
    expect(play.hintsUsed, 1);
    play.dispose();
  });

  test('declining the offer leaves no error and no hint', () async {
    final play = GamePlayController(game: DailyGame.sudoku, userId: 'u1');
    await play.begin();
    play.onOutOfHints = () async => false;
    expect(await play.hint(const [0, 0]), isNull);
    expect(play.errorCode, isNull);
    play.dispose();
  });

  test('without an offer hook the code surfaces as an error', () async {
    final play = GamePlayController(game: DailyGame.sudoku, userId: 'u1');
    await play.begin();
    expect(await play.hint(const [0, 0]), isNull);
    expect(play.errorCode, 'OUT_OF_HINTS');
    play.dispose();
  });
}
