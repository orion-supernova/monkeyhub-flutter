// The Feed tab's badge and the Activity board's "new" marks: friends' finished
// results newer than a local watermark, cleared only once the board has been on
// screen (or a result notification landed on it). Everything is computed from
// the board the app already subscribes to; these pin the counting, the clearing
// rule and the spoken label.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/data/ui_selection_store.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_play.dart';
import 'package:monkeyhub/screens/feed_screen.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

class _ChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FeedApi extends Fake implements FeedApi {}

class _Auth extends Fake implements AuthService {
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _Family extends Fake implements FamilyService {
  @override
  bool get hasContext => true;
  @override
  bool get isChild => false;
  @override
  bool get canSendMedia => true;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _Repo extends Fake implements ChatRepository {
  @override
  String? get userId => 'u1';
  @override
  ChatUser? userById(String id) => null;
  @override
  List<ChatUser> get friends => [
    ChatUser(id: 'u_e', username: 'ece', name: 'Ece'),
  ];
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// Each test gets results finished after every earlier test's watermark: the
/// settings singleton only ever moves forward, like the real one.
DateTime _epoch = DateTime.now().add(const Duration(days: 30));

GamePlay _play(String userId, DailyGame game, DateTime at) => GamePlay(
  userId: userId,
  name: userId == 'u_e' ? 'Ece' : 'Ali',
  game: game,
  solved: true,
  result: '1:02',
  durationMs: 62000,
  finishedAt: at,
);

void _board(List<GamePlay> plays) => FeedStore.instance.applyBoard(
  FeedBoard(
    moments: const [],
    serverNow: DateTime.now(),
    plays: plays,
  ),
);

void main() {
  final store = FeedStore.instance;

  setUp(() async {
    await store.detach();
    store.start();
    _epoch = _epoch.add(const Duration(days: 1));
  });

  tearDown(() async {
    await store.detach();
  });

  group('counting', () {
    test('only results newer than the watermark are new', () {
      final t = _epoch;
      _board([
        _play('u_e', DailyGame.queens, t),
        _play('u_a', DailyGame.zip, t.add(const Duration(minutes: 5))),
      ]);
      final base = t.millisecondsSinceEpoch;
      expect(store.newPlayCount(0), 2);
      expect(store.newPlayCount(base - 1), 2);
      expect(store.newPlayCount(base), 1);
      expect(store.newPlayCount(store.newestFriendPlayAt), 0);
    });

    test('the watermark is the newest result on the board, not the clock', () {
      final t = _epoch;
      _board([_play('u_e', DailyGame.queens, t)]);
      expect(store.newestFriendPlayAt, t.millisecondsSinceEpoch);
      _board(const []);
      expect(store.newestFriendPlayAt, 0);
    });

    test('markFeedActivitySeen only moves forward', () async {
      final s = SettingsStore.instance;
      final t = _epoch.millisecondsSinceEpoch;
      await s.markFeedActivitySeen(t);
      expect(s.feedActivitySeenAt, t);
      await s.markFeedActivitySeen(t - 1000);
      expect(s.feedActivitySeenAt, t);
    });
  });

  group('nav badge label', () {
    testWidgets('the Feed says what it counts; other tabs stay bare', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              l10n = AppLocalizations.of(c);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(navBadgeSemantics(l10n, HomeSection.feed, 3), '3 new from friends');
      expect(navBadgeSemantics(l10n, HomeSection.feed, 1), '1 new from friends');
      expect(navBadgeSemantics(l10n, HomeSection.chat, 3), isNull);
    });
  });

  group('Activity board', () {
    late AppLocalizations l10n;

    Future<void> pumpFeed(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(ThemeController.byId('basic')),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) {
                l10n = AppLocalizations.of(c);
                return FeedScreen(
                  repo: _Repo(),
                  api: _ChatApi(),
                  feedApi: _FeedApi(),
                  auth: _Auth(),
                  family: _Family(),
                );
              },
            ),
          ),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
      store.stop();
    }

    double pillOpacity(WidgetTester tester, String text) {
      final fade = find.ancestor(
        of: find.text(text),
        matching: find.byType(AnimatedOpacity),
      );
      return tester.widget<AnimatedOpacity>(fade.first).opacity;
    }

    testWidgets('new results show "N new", and it clears once seen', (
      tester,
    ) async {
      final t = _epoch;
      _board([
        _play('u_e', DailyGame.queens, t),
        _play('u_e', DailyGame.zip, t.add(const Duration(minutes: 1))),
        _play('u1', DailyGame.tango, t.add(const Duration(minutes: 2))),
      ]);
      await pumpFeed(tester);

      // Three results; the store has no session in a test, so it cannot tell
      // which is the viewer's own (it skips those once attached).
      expect(find.text(l10n.feedActivityNewPill(3)), findsOneWidget);
      expect(pillOpacity(tester, l10n.feedActivityNewPill(3)), 1);

      // Not yet: a flick past is not a look. (The stagger above took ~1s,
      // under the dwell.)
      expect(
        SettingsStore.instance.feedActivitySeenAt,
        lessThan(t.millisecondsSinceEpoch),
      );

      // The board has now been in view long enough.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        SettingsStore.instance.feedActivitySeenAt,
        store.newestFriendPlayAt,
      );
      // ...and the pill left by fading, keeping its last number meanwhile.
      expect(pillOpacity(tester, l10n.feedActivityNewPill(3)), 0);

      await unmount(tester);
    });

    testWidgets('a result notification lands on the board and counts at once', (
      tester,
    ) async {
      final t = _epoch;
      _board([_play('u_e', DailyGame.queens, t)]);
      UiSelectionStore.instance.requestActivityView();
      await pumpFeed(tester);
      expect(UiSelectionStore.instance.activityViewPending, isFalse);
      // Well inside the dwell: the tap itself was the look.
      expect(
        SettingsStore.instance.feedActivitySeenAt,
        store.newestFriendPlayAt,
      );
      await unmount(tester);
    });
  });
}
