import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/feed/puzzle_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// A guess sent into a dead network is one try, however many times it is sent.
///
/// The bug this pins: a guess that timed out handed the keypad back, the player
/// kept typing and tapping GUESS, and every tap queued another try in the
/// native client — which resent them all on reconnect, ending the game on
/// OUT_OF_GUESSES in front of them.
class _FlakyFeedApi extends Fake implements FeedApi {
  /// Calls to fail with a timeout before the network "comes back".
  int failures = 1;

  /// Every send, as `attempt:guess`.
  final List<String> sends = [];

  @override
  Future<PuzzleAttempt> guess({
    required String userId,
    required String dayKey,
    required List<int> guess,
    required int attempt,
  }) async {
    sends.add('$attempt:${guess.join()}');
    if (failures > 0) {
      failures--;
      throw Exception('MutationTimeout');
    }
    return PuzzleAttempt(
      guesses: [guess],
      feedback: const [PuzzlePegs(exact: 1, present: 1)],
      solved: false,
      done: false,
    );
  }
}

void main() {
  setUp(() {
    RecordsStore.instance.api = FakeGamesApi(const {});
    RecordsStore.instance.clear();
  });
  tearDown(() {
    FeedStore.instance.detach();
    RecordsStore.instance.clear();
  });

  Future<_FlakyFeedApi> open(WidgetTester t) async {
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    FeedStore.instance.start();
    final api = _FlakyFeedApi();
    await t.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PuzzleScreen(feedApi: api, userId: 'me'),
      ),
    ));
    await t.pumpAndSettle();
    return api;
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  Future<void> type(WidgetTester t, List<int> symbols) async {
    for (final s in symbols) {
      await t.tap(find.byKey(ValueKey('key_$s')));
      await t.pump();
    }
  }

  testWidgets('a timed-out guess locks the board and resends the same try',
      (t) async {
    final api = await open(t);
    await type(t, [0, 1, 2, 3]);
    await t.tap(find.text('Guess'));
    await t.pumpAndSettle();

    // Kept, said so, and the keypad will not start another try.
    expect(api.sends, ['0:0123']);
    expect(find.textContaining('No connection'), findsOneWidget);
    await t.tap(find.text('Guess'));
    await type(t, [4, 5]);
    await t.pumpAndSettle();
    expect(api.sends, ['0:0123']);

    // The retry sends the SAME try, and its answer unlocks the board.
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(api.sends, ['0:0123', '0:0123']);
    expect(find.textContaining('No connection'), findsNothing);
    expect(FeedStore.instance.puzzle.mine?.guesses, hasLength(1));

    // Unlocked: the next try is numbered after it.
    await type(t, [3, 2, 1, 0]);
    await t.tap(find.text('Guess'));
    await t.pumpAndSettle();
    expect(api.sends.last, '1:3210');
    await close(t);
  });

  testWidgets('the banner retries at once', (t) async {
    final api = await open(t);
    await type(t, [0, 1, 2, 3]);
    await t.tap(find.text('Guess'));
    await t.pumpAndSettle();
    expect(api.sends, hasLength(1));

    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(api.sends, ['0:0123', '0:0123']);
    expect(find.textContaining('No connection'), findsNothing);
    await close(t);
  });
}
