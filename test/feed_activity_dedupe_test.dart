// A point is a tagged moment and a highlight is an untagged one, but both are
// rows in the same table — and for a while the Feed drew every point twice,
// once in Life points and again in Activity. Activity is highlights only now;
// these pin that, and the "hide when empty but you have friends" rule, so a
// later refactor that feeds Activity `moments` again fails here instead of in
// someone's feed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_play.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/feed_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_activity.dart';

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
  List<ChatUser> get friends => [
    ChatUser(id: 'u_e', username: 'ece', name: 'Ece'),
  ];
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final _now = DateTime.now();

Moment _m(String id, {MomentTag? tag, String? media}) => Moment(
  id: id,
  userId: 'u_e',
  dayKey: '2026-10-04',
  createdAt: _now.subtract(const Duration(minutes: 10)),
  expiresAt: _now.add(const Duration(hours: 20)),
  authorName: 'Ece',
  authorUsername: 'ece',
  mine: false,
  seen: true,
  tag: tag,
  caption: 'caption $id',
  mediaStorageId: media,
  mediaKind: media == null ? MomentMedia.none : MomentMedia.image,
);

void main() {
  late AppLocalizations l10n;

  Future<void> pumpFeed(
    WidgetTester tester,
    List<Moment> moments, {
    List<GamePlay> plays = const [],
    PuzzleState puzzle = const PuzzleState(),
  }) async {
    // Tall enough that Activity — the last section — is laid out without
    // scrolling; the list is lazy and would otherwise never build it.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 4000);
    addTearDown(tester.view.reset);
    FeedStore.instance.applyBoard(
      FeedBoard(
        moments: moments,
        serverNow: DateTime.now(),
        plays: plays,
        puzzle: puzzle,
      ),
    );
    final theme = ThemeController.byId('basic');
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(theme),
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
    // The sections stagger in; let the entrance finish.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    FeedStore.instance.stop();
  }

  testWidgets('Activity lists highlights only — 3 points, 2 highlights', (
    tester,
  ) async {
    await pumpFeed(tester, [
      _m('p1', tag: MomentTag.jinx),
      _m('p2', tag: MomentTag.fate),
      _m('p3', tag: MomentTag.luck),
      _m('h1', media: 's1'),
      _m('h2', media: 's2'),
    ]);

    expect(find.text(l10n.feedBoardActivityLabel), findsOneWidget);
    final activity = find.byType(MomentActivity);
    expect(activity, findsOneWidget);
    // Rows are keyed `act_<id>` — exactly the two highlights, no point.
    for (final id in ['h1', 'h2']) {
      expect(
        find.descendant(of: activity, matching: find.byKey(ValueKey('act_$id'))),
        findsOneWidget,
      );
    }
    for (final id in ['p1', 'p2', 'p3']) {
      expect(
        find.descendant(of: activity, matching: find.byKey(ValueKey('act_$id'))),
        findsNothing,
      );
    }
    expect(
      tester.widget<MomentActivity>(activity).moments.map((m) => m.id),
      ['h1', 'h2'],
    );

    await unmount(tester);
  });

  testWidgets('Activity hides when there are no highlights and you have friends', (
    tester,
  ) async {
    await pumpFeed(tester, [
      _m('p1', tag: MomentTag.jinx),
      _m('p2', tag: MomentTag.fate),
    ]);

    expect(find.text(l10n.feedBoardActivityLabel), findsNothing);
    expect(find.byType(MomentActivity), findsNothing);

    await unmount(tester);
  });

  GamePlay play(String userId, DailyGame game, int ms, {int agoMin = 5}) =>
      GamePlay(
        userId: userId,
        name: userId == 'u1' ? '' : 'Ece',
        game: game,
        solved: true,
        result: formatGameTime(ms),
        durationMs: ms,
        finishedAt: _now.subtract(Duration(minutes: agoMin)),
      );

  testWidgets('a finished game lands in Activity, even with no highlights', (
    tester,
  ) async {
    await pumpFeed(
      tester,
      [_m('p1', tag: MomentTag.jinx)],
      plays: [play('u_e', DailyGame.queens, 102000)],
      puzzle: PuzzleState(
        scores: [
          PuzzleScore(
            userId: 'u_e',
            name: 'Ece',
            solved: true,
            guessCount: 3,
            finishedAt: _now.subtract(const Duration(minutes: 2)),
            feedback: const [],
          ),
        ],
      ),
    );

    expect(find.text(l10n.feedBoardActivityLabel), findsOneWidget);
    expect(
      find.text(l10n.momentActivityGameSolved(l10n.gameQueensName, 'Ece')),
      findsOneWidget,
    );
    expect(find.text('1:42'), findsOneWidget);
    // The code comes off the puzzle scoreboard, with its guess count.
    expect(
      find.text(l10n.momentActivityCodeSolved('Ece')),
      findsOneWidget,
    );
    expect(find.text('3/6'), findsOneWidget);

    await unmount(tester);
  });

  test('a game rank needs somebody to rank against', () {
    FeedStore.instance.applyBoard(
      FeedBoard(
        moments: const [],
        serverNow: DateTime.now(),
        plays: [play('u1', DailyGame.zip, 90000)],
      ),
    );
    expect(FeedStore.instance.gameRank(DailyGame.zip, 'u1'), isNull);

    FeedStore.instance.applyBoard(
      FeedBoard(
        moments: const [],
        serverNow: DateTime.now(),
        plays: [
          play('u1', DailyGame.zip, 90000),
          play('u_e', DailyGame.zip, 60000),
          play('u_e', DailyGame.tango, 30000),
        ],
      ),
    );
    // Fastest first, and other games do not count.
    expect(FeedStore.instance.gameRank(DailyGame.zip, 'u1'), 2);
    expect(FeedStore.instance.gameRank(DailyGame.zip, 'u_e'), 1);
    expect(FeedStore.instance.gameRank(DailyGame.queens, 'u1'), isNull);
    FeedStore.instance.stop();
  });
}
