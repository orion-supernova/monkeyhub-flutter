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

/// The code puzzle's TELL FRIENDS — the one game on the shelf that could not
/// tell anybody how it went.
class _FakeFeedApi extends Fake implements FeedApi {
  final List<String> shared = [];

  @override
  Future<void> sharePuzzleResult({
    required String userId,
    required String dayKey,
  }) async {
    shared.add(dayKey);
  }
}

PuzzleAttempt _solved() => const PuzzleAttempt(
      guesses: [
        [0, 1, 2, 3],
      ],
      feedback: [PuzzlePegs(exact: 4, present: 0)],
      solved: true,
      done: true,
    );

void main() {
  setUp(() {
    RecordsStore.instance.api = FakeGamesApi(const {});
    RecordsStore.instance.clear();
  });
  tearDown(() {
    FeedStore.instance.detach();
    RecordsStore.instance.clear();
  });

  Future<_FakeFeedApi> open(WidgetTester t) async {
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    // The attempt is stamped with the store's day, so the day has to exist
    // first — the screen reads it back against the same key.
    FeedStore.instance.start();
    FeedStore.instance.applyPuzzleAttempt(_solved());
    final api = _FakeFeedApi();
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

  /// The store's midnight timer has to be gone before the test ends, and a
  /// tearDown runs too late for the binding's pending-timer check.
  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  testWidgets('a finished code can be told to friends, once', (t) async {
    final api = await open(t);

    await t.tap(find.text('TELL FRIENDS'));
    await t.pumpAndSettle();
    await t.tap(find.text('SEND IT'));
    await t.pumpAndSettle();

    expect(api.shared, hasLength(1));
    // Retired the moment the server said yes — not a board round trip later.
    expect(find.text('TELL FRIENDS'), findsNothing);
    expect(find.text('friends told'), findsOneWidget);

    await t.pump(const Duration(seconds: 8));
    await t.pumpAndSettle();
    await close(t);
  });

  testWidgets('NOT NOW sends nothing', (t) async {
    final api = await open(t);

    await t.tap(find.text('TELL FRIENDS'));
    await t.pumpAndSettle();
    await t.tap(find.text('NOT NOW'));
    await t.pumpAndSettle();

    expect(api.shared, isEmpty);
    expect(find.text('TELL FRIENDS'), findsOneWidget);
    await close(t);
  });
}
