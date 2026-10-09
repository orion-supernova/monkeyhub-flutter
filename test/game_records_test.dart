import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/game_record.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_records.dart';

import 'fakes/fake_games_api.dart';

/// All-time records on the client: the wire shape, the reader's own reaction
/// going on and coming off without a round trip, and the two surfaces.
///
/// The reaction is the part worth pinning. It is optimistic — the chip moves
/// the instant it is tapped — which is only acceptable if a refusal puts the
/// board back exactly as it was, and if the count a reader SEES agrees with
/// the one the server will send on the next open.
GameRecordRow _row({
  String id = 'r1',
  String userId = 'ada',
  String name = 'Ada',
  int rank = 1,
  int best = 61000,
  List<RecordReaction> reactions = const [],
  String? mine,
}) =>
    GameRecordRow(
      recordId: id,
      userId: userId,
      name: name,
      rank: rank,
      best: best,
      dayKey: '2026-09-12',
      achievedAt: DateTime(2026, 9, 12),
      solves: 7,
      reactions: reactions,
      mine: mine,
    );

Widget _host(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  late FakeGamesApi api;

  setUp(() {
    api = FakeGamesApi(const {});
    RecordsStore.instance.api = api;
    RecordsStore.instance.clear();
  });
  tearDown(() => RecordsStore.instance.clear());

  group('the wire', () {
    test('decodes every game, skips one it does not know', () {
      final board = RecordBoard.fromJson({
        'games': {
          'queens': [
            {
              'recordId': 'r1',
              'userId': 'ada',
              'name': 'Ada',
              'rank': 1,
              'best': 61000,
              'dayKey': '2026-09-12',
              'achievedAt': 1,
              'solves': 7,
              'reactions': [
                {'emoji': '🔥', 'count': 2},
              ],
              'reactors': [
                {'name': 'Lin', 'emoji': '🔥'},
              ],
              'mine': '🔥',
            },
          ],
          'code': <dynamic>[],
          'crossword': [
            {'recordId': 'x'},
          ],
        },
        'palette': ['🔥', '👏'],
      });
      final queens = board.holderOf(RecordGame.queens)!;
      expect(queens.best, 61000);
      expect(queens.reactionCount, 2);
      expect(queens.reactors.single.name, 'Lin');
      expect(queens.mine, '🔥');
      expect(board.rowsFor(RecordGame.code), isEmpty);
      expect(board.palette, ['🔥', '👏']);
    });

    test('a best reads as a clock for a daily and as guesses for the code', () {
      expect(RecordGame.zip.formatBest(61000), '1:01');
      expect(RecordGame.code.formatBest(3), '3/6');
    });
  });

  group('reacting', () {
    Future<void> seed(GameRecordRow row) async {
      api.records = RecordBoard(games: {RecordGame.queens: [row]});
      await RecordsStore.instance.load('me');
    }

    GameRecordRow current() =>
        RecordsStore.instance.board.holderOf(RecordGame.queens)!;

    test('adds, swaps, and takes back — counts moving with it', () async {
      await seed(_row(reactions: const [RecordReaction(emoji: '👏', count: 1)]));

      await RecordsStore.instance.toggleReaction(current(), '🔥');
      expect(current().mine, '🔥');
      expect(
        {for (final r in current().reactions) r.emoji: r.count},
        {'👏': 1, '🔥': 1},
      );

      await RecordsStore.instance.toggleReaction(current(), '👏');
      expect(current().mine, '👏');
      expect({for (final r in current().reactions) r.emoji: r.count}, {'👏': 2});

      await RecordsStore.instance.toggleReaction(current(), '👏');
      expect(current().mine, isNull);
      expect({for (final r in current().reactions) r.emoji: r.count}, {'👏': 1});

      expect(api.reactions, ['r1:🔥', 'r1:👏', 'r1:-']);
    });

    test('a refusal puts the board back exactly', () async {
      await seed(_row());
      api.reactError = StateError('NOT_FRIENDS');

      final error = await RecordsStore.instance.toggleReaction(current(), '🔥');

      expect(error, isNotNull);
      expect(current().mine, isNull);
      expect(current().reactions, isEmpty);
    });
  });

  group('the hub section', () {
    testWidgets('holds a skeleton until the server answers', (t) async {
      await t.pumpWidget(_host(const RecordsSection(viewerId: 'me')));
      expect(find.text('Solve any game and your best lands here.'),
          findsNothing);
    });

    testWidgets('an answered, empty board says how to get on it', (t) async {
      await RecordsStore.instance.load('me');
      await t.pumpWidget(_host(const RecordsSection(viewerId: 'me')));
      await t.pumpAndSettle();
      expect(find.text('Solve any game and your best lands here.'),
          findsOneWidget);
    });

    testWidgets('names the holder and, under it, your own best', (t) async {
      api.records = RecordBoard(games: {
        RecordGame.queens: [
          _row(),
          _row(id: 'r2', userId: 'me', name: '', rank: 2, best: 75000),
        ],
      });
      await RecordsStore.instance.load('me');
      await t.pumpWidget(_host(const RecordsSection(viewerId: 'me')));
      await t.pumpAndSettle();

      // Holder and your own best on one line: the gap worth chasing.
      expect(find.text('Ada · Yours 1:15'), findsOneWidget);
      expect(find.text('1:01'), findsOneWidget);
      // Every game has a row, solved or not.
      expect(find.text('Nobody yet'), findsNWidgets(RecordGame.values.length - 1));
    });
  });

  group('the sheet', () {
    testWidgets('a friend is cheered from their row', (t) async {
      t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      api.records = RecordBoard(games: {
        RecordGame.queens: [
          _row(),
          _row(id: 'r2', userId: 'me', name: '', rank: 2, best: 75000),
        ],
      });
      await t.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () => showRecordsSheet(
            context,
            game: RecordGame.queens,
            viewerId: 'me',
          ),
          child: const Text('open'),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      // Nothing sends on a stray touch: the emoji wait behind "Cheer".
      expect(find.text('🔥'), findsNothing);
      await t.tap(find.text('Cheer'));
      await t.pumpAndSettle();
      // The holder's six; your own row (second) offers none.
      expect(find.text('🔥'), findsOneWidget);
      await t.tap(find.text('🔥'));
      await t.pumpAndSettle();

      expect(api.reactions, ['r1:🔥']);
      // Chosen, so the disc wears it and a second tap would take it back.
      expect(
        RecordsStore.instance.board.rowsFor(RecordGame.queens).first.mine,
        '🔥',
      );
    });

    testWidgets('a friend further down is cheered from their button', (t) async {
      t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      api.records = RecordBoard(games: {
        RecordGame.queens: [
          _row(userId: 'me', name: ''),
          _row(id: 'r2', userId: 'lin', name: 'Lin', rank: 2, best: 75000),
        ],
      });
      await t.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () => showRecordsSheet(
            context,
            game: RecordGame.queens,
            viewerId: 'me',
          ),
          child: const Text('open'),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      // Your own record has no Cheer; Lin's row shows only its button.
      expect(find.text('Cheer'), findsNothing);
      expect(find.text('🔥'), findsNothing);
      await t.tap(find.byIcon(CupertinoIcons.smiley));
      await t.pumpAndSettle();
      await t.tap(find.text('🔥'));
      await t.pumpAndSettle();
      expect(api.reactions, ['r2:🔥']);
    });
  });
}
