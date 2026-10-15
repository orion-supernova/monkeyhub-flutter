import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/challenges_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/challenge_bubble.dart';

/// "Beat my time": the card's "who played" line, the challenge-back target
/// it opens a board with, and the route scope that keeps a stale dare off a
/// board opened from anywhere else.

GameChallenge _challenge({required String id, bool isGroup = true}) =>
    GameChallenge(
      messageId: id,
      userId: 'zeynep',
      name: 'Zeynep',
      game: DailyGame.zip,
      // The Feed's day in a test is "", so the card reads as today's.
      dayKey: '',
      durationMs: 17_400,
      hintsUsed: 0,
      roomId: 'r_$id',
      isGroup: isGroup,
      roomName: isGroup ? 'Climbers' : null,
    );

Map<String, dynamic> _row(
  String userId,
  String name,
  int place, {
  int? ms,
  bool gaveUp = false,
}) => {
  'userId': userId,
  'name': name,
  'place': place,
  'game': 'zip',
  'solved': !gaveUp,
  'gaveUp': gaveUp,
  'durationMs': ?ms,
  'finishedAt': 1,
};

Widget _host(Widget child) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  ),
);

Widget _bubble(GameChallenge c, {String viewer = 'me'}) => Builder(
  builder: (context) => ChallengeBubble(
    theme: ThemeScope.of(context),
    message: ChatMessage(
      id: c.messageId,
      roomId: c.roomId,
      senderId: c.userId,
      senderName: c.name,
      content: 'Can you beat my 0:17 on Zip?',
      type: MessageType.challenge,
      createdAt: DateTime(2026, 10, 15),
    ),
    isMine: c.userId == viewer,
    width: 300,
    radius: BorderRadius.circular(18),
    currentUserId: viewer,
  ),
);

void main() {
  tearDown(ChallengesStore.instance.clear);

  test('room results parse rows, faces and counts', () {
    final r = RoomResults.fromJson({
      'isGroup': false,
      'played': 2,
      'rows': [
        {..._row('zeynep', 'Zeynep', 1, ms: 17_000), 'avatarStorageId': 'st1'},
        _row('me', '', 2, gaveUp: true),
      ],
    }, DailyGame.zip)!;
    expect(r.isGroup, isFalse);
    expect(r.rows.map((x) => x.userId), ['zeynep', 'me']);
    expect(r.rows[1].solved, isFalse);
    expect(r.rows[1].finished, isTrue);
    expect(r.avatars, {'zeynep': 'st1'});
  });

  test('a target carries where the dare came from', () {
    final c = GameChallenge.fromJson({
      'messageId': 'm1',
      'userId': 'zeynep',
      'name': 'Zeynep',
      'game': 'zip',
      'dayKey': '2026-10-15',
      'durationMs': 17_000,
      'hintsUsed': 0,
      'isGroup': false,
    })!;
    // An older server sends no roomId; the card's own room stands in.
    final t = ChallengeTarget.of(c, roomId: 'dm1');
    expect(t.roomId, 'dm1');
    expect(t.messageId, 'm1');
    expect(t.challengerId, 'zeynep');
    expect(t.isGroup, isFalse);
  });

  testWidgets('the target is scoped to the route that was opened with it', (
    tester,
  ) async {
    ChallengeTarget? seen;
    ChallengeTarget? bare;
    final target = ChallengeTarget.of(_challenge(id: 'm1'));
    await tester.pumpWidget(
      Column(
        children: [
          ChallengeScope(
            target: target,
            child: Builder(
              builder: (context) {
                seen = ChallengeScope.of(context);
                return const SizedBox();
              },
            ),
          ),
          Builder(
            builder: (context) {
              bare = ChallengeScope.of(context);
              return const SizedBox();
            },
          ),
        ],
      ),
    );
    expect(seen, same(target));
    expect(bare, isNull);
  });

  testWidgets('a DM card reads both times on one line', (tester) async {
    final c = _challenge(id: 'dm', isGroup: false);
    ChallengesStore.instance.debugSeed(
      challenge: c,
      results: RoomResults.fromJson({
        'isGroup': false,
          'played': 2,
        'rows': [
          _row('zeynep', 'Zeynep', 1, ms: 17_400),
          _row('me', '', 2, ms: 21_000),
        ],
      }, DailyGame.zip),
    );
    await tester.pumpWidget(_host(_bubble(c)));
    await tester.pump();
    expect(find.textContaining('Zeynep 0:17', findRichText: true), findsOneWidget);
    expect(find.textContaining('You 0:21', findRichText: true), findsOneWidget);
  });

  testWidgets('a group card shows who played, top three and the viewer', (
    tester,
  ) async {
    final c = _challenge(id: 'grp');
    ChallengesStore.instance.debugSeed(
      challenge: c,
      results: RoomResults.fromJson({
        'isGroup': true,
        'played': 5,
        'rows': [
          _row('ada', 'Ada', 1, ms: 12_000),
          _row('zeynep', 'Zeynep', 2, ms: 17_400),
          _row('bob', 'Bob', 3, ms: 19_000),
          _row('me', '', 4, ms: 25_000),
          _row('cat', 'Cat', 5, gaveUp: true),
        ],
      }, DailyGame.zip),
    );
    await tester.pumpWidget(_host(_bubble(c)));
    await tester.pump();
    expect(find.text('You and 4 friends played'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    // Pinned under the top three.
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Cat'), findsNothing);

    // The whole room's board, one tap away.
    await tester.tap(find.text('You and 4 friends played'));
    await tester.pumpAndSettle();
    expect(find.text('Cat'), findsOneWidget);
    // And says why the list may be shorter than the room.
    expect(
      find.text(
        'Only your friends show up here. Other people in this chat may have played too.',
      ),
      findsOneWidget,
    );
  });

  test('the who-played line counts friends and names the viewer apart', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    String line(List<Map<String, dynamic>> rows) => challengePlayedSummary(
      l10n,
      RoomResults.fromJson({'rows': rows}, DailyGame.zip)!,
      'me',
    );

    expect(line([]), 'None of your friends here have played yet');
    expect(line([_row('me', '', 1, ms: 9_000)]), 'Only you have played so far');
    expect(line([_row('ada', 'Ada', 1, ms: 9_000)]), '1 friend played');
    expect(
      line([_row('ada', 'Ada', 1, ms: 9_000), _row('me', '', 2, ms: 12_000)]),
      'You and 1 friend played',
    );
  });
}
