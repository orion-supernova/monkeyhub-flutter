// Round 2 of the Feed area, rendered to PNG: the board's headers and the
// deduped activity, the point composer (with and without a keyboard), the
// rewritten game info sheets, the leaderboard, the highlight stories and the
// own-point trash.
//
//   flutter test test/design_preview/feed_r2_preview.dart
//
// Not a test. PNGs land in build/design_preview/r2f_*.png.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_comment.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/screens/feed/point_composer.dart';
import 'package:monkeyhub/screens/feed/puzzle_screen.dart';
import 'package:monkeyhub/screens/feed_screen.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_info_sheet.dart';
import 'package:monkeyhub/widgets/moment_comments_sheet.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

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
    ChatUser(id: 'u_e', username: 'ece', name: 'Ece Yıldız'),
  ];
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final _now = DateTime.now();

Moment _m(
  String id, {
  String who = 'Ece Yıldız',
  bool mine = false,
  MomentTag? tag,
  String? caption,
  String? media,
  int minutesAgo = 30,
  Map<String, int> reactions = const {},
  Set<String> my = const {},
  int comments = 0,
  List<MomentReactor> reactors = const [],
}) => Moment(
  id: id,
  userId: mine ? 'u1' : 'u_$who',
  dayKey: '2026-10-04',
  createdAt: _now.subtract(Duration(minutes: minutesAgo)),
  expiresAt: _now.add(const Duration(hours: 20)),
  authorName: mine ? 'Murat' : who,
  authorUsername: who.toLowerCase().split(' ').first,
  mine: mine,
  seen: true,
  tag: tag,
  caption: caption,
  mediaStorageId: media,
  mediaKind: media == null ? MomentMedia.none : MomentMedia.image,
  reactionCounts: reactions,
  myReactions: my,
  commentCount: comments,
  reactors: reactors,
);

final _moments = <Moment>[
  _m('h1', media: 's1', caption: 'Sunset over the Bosphorus', minutesAgo: 20,
      reactions: const {'🔥': 3, '😮': 1},
      my: const {'🔥'},
      comments: 12,
      reactors: const [
        MomentReactor(emoji: '🔥', userId: 'u1', name: 'Murat', username: 'murat'),
        MomentReactor(emoji: '🔥', userId: 'u_d', name: 'Deniz Kaya', username: 'deniz'),
        MomentReactor(emoji: '😮', userId: 'u_d', name: 'Deniz Kaya', username: 'deniz'),
        MomentReactor(emoji: '🔥', userId: 'u_a', name: 'Arda', username: 'arda'),
      ]),
  _m('h1b', media: 's1b', caption: 'and the ferry home', minutesAgo: 22),
  _m('h1c', media: 's1c', minutesAgo: 25),
  _m('h2', who: 'Deniz Kaya', media: 's2', minutesAgo: 70),
  _m('h3', mine: true, media: 's3', caption: 'new desk', minutesAgo: 90),
  _m('p1', tag: MomentTag.jinx,
      caption: 'Washed the car, it rained at four.', minutesAgo: 15,
      reactions: const {'😂': 4}),
  _m('p2', who: 'Deniz Kaya', tag: MomentTag.fate,
      caption: 'Ran into my dentist in Lisbon', minutesAgo: 45),
  _m('p3', mine: true, tag: MomentTag.luck,
      caption: 'Found 50 lira in an old coat', minutesAgo: 60),
];

GameResult _r(DailyGame g, String id, String name, int secs,
        {bool solved = true}) =>
    GameResult(
      game: g,
      solved: solved,
      gaveUp: !solved,
      finished: true,
      durationMs: solved ? secs * 1000 : null,
      userId: id,
      name: name,
    );

final _standings = GameStandings(
  boards: {
    DailyGame.queens: [
      _r(DailyGame.queens, 'u_e', 'Ece Yıldız', 61),
      _r(DailyGame.queens, 'u1', '', 74),
      _r(DailyGame.queens, 'u_d', 'Deniz Kaya', 102),
      _r(DailyGame.queens, 'u_a', 'Arda', 0, solved: false),
    ],
    DailyGame.tango: [
      _r(DailyGame.tango, 'u1', '', 48),
      _r(DailyGame.tango, 'u_e', 'Ece Yıldız', 55),
    ],
    DailyGame.zip: [
      _r(DailyGame.zip, 'u_e', 'Ece Yıldız', 33),
      _r(DailyGame.zip, 'u_d', 'Deniz Kaya', 41),
    ],
  },
);

PuzzleScore _code(String id, String name, int guesses) => PuzzleScore(
  userId: id,
  name: name,
  solved: true,
  guessCount: guesses,
  finishedAt: _now,
  feedback: const [],
);

final _puzzle = PuzzleState(
  scores: [_code('u1', '', 3), _code('u_d', 'Deniz Kaya', 4)],
  mine: const PuzzleAttempt(
    guesses: [
      [0, 1, 2, 3],
    ],
    feedback: [
      PuzzlePegs(
        exact: 1,
        present: 1,
        slots: [
          PuzzlePegSlot.exact,
          PuzzlePegSlot.present,
          PuzzlePegSlot.absent,
          PuzzlePegSlot.absent,
        ],
      ),
    ],
    solved: false,
    done: false,
  ),
);

Widget _app(
  AppTheme theme,
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => ThemeScope(
  controller: ThemeController(theme),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      brightness: theme.background.computeLuminance() < 0.4
          ? Brightness.dark
          : Brightness.light,
      scaffoldBackgroundColor: theme.background,
    ),
    builder: (c, nav) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: nav!,
    ),
    home: ColoredBox(
      color: theme.background,
      child: DefaultTextStyle(style: theme.body, child: child),
    ),
  ),
);

class _Opener extends StatefulWidget {
  const _Opener({required this.open});
  final void Function(BuildContext context) open;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
        children: [
          Text('Feed', style: theme.displayLarge),
          for (var i = 0; i < 9; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Row $i', style: theme.bodyEmph),
            ),
        ],
      ),
    );
  }
}

Future<void> _shoot(
  WidgetTester tester,
  Widget widget,
  String name, {
  int frames = 90,
  double keyboard = 0,
  Future<void> Function()? act,
}) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = kIphone16Pro * dpr;
  final pad = FakeViewPadding(
    top: kIphoneTopInset * dpr,
    bottom: kIphoneBottomInset * dpr,
  );
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  if (keyboard > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
  }
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: widget));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (act != null) {
    await act();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final out = File('$kPreviewDir/$name');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!);
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  FeedStore.instance.stop();
}

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in ['queens', 'tango', 'zip', 'sudoku'])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  setUpAll(loadPreviewFonts);
  void board({bool empty = false}) {
    GamesStore.instance.api = FakeGamesApi(
      payload,
      standingsAnswer: empty ? const GameStandings() : _standings,
    );
    RecordsStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
    FeedStore.instance.applyBoard(
      FeedBoard(
        moments: _moments,
        serverNow: DateTime.now(),
        puzzle: empty ? const PuzzleState() : _puzzle,
      ),
    );
  }

  setUp(board);
  tearDown(() {
    FeedStore.instance.stop();
    debugStoryAssumeLoaded = false;
  });

  FeedScreen feed() => FeedScreen(
    repo: _Repo(),
    api: _ChatApi(),
    feedApi: _FeedApi(),
    auth: _Auth(),
    family: _Family(),
  );

  final sheets = <String, void Function(BuildContext)>{
    'point': (c) => showPointComposer(c,
        api: _ChatApi(), feedApi: _FeedApi(), userId: 'u1'),
    'point_tagged': (c) => showPointComposer(c,
        api: _ChatApi(),
        feedApi: _FeedApi(),
        userId: 'u1',
        initialTag: MomentTag.jinx),
    'gameinfo': (c) => showGameInfo(c, DailyGame.queens,
        entry: GameInfoEntry.play, onPlay: () {}),
    'zipinfo': (c) =>
        showGameInfo(c, DailyGame.zip, entry: GameInfoEntry.play, onPlay: () {}),
    'codeinfo': (c) =>
        showCodePuzzleInfo(c, entry: GameInfoEntry.play, onPlay: () {}),
    'card_mine': (c) => showMomentViewer(c,
        moment: _moments[7],
        api: _ChatApi(),
        feedApi: _FeedApi(),
        userId: 'u1'),
  };

  const themes = ['basic', 'basic_daylight', 'risograph_pop'];
  for (final id in themes) {
    for (final e in sheets.entries) {
      testWidgets('sheet ${e.key} $id', (tester) async {
        await _shoot(
          tester,
          _app(ThemeController.byId(id), _Opener(open: e.value)),
          'r2f_${e.key}_$id.png',
        );
      });
    }
    testWidgets('point keyboard $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id), _Opener(open: sheets['point_tagged']!)),
        'r2f_point_kb_$id.png',
        keyboard: 336,
      );
    });
    testWidgets('feed $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id), feed()),
        'r2f_feed_$id.png',
        act: () async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        },
      );
    });
    testWidgets('feed scrolled $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id), feed()),
        'r2f_feed_scrolled_$id.png',
        act: () async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
        },
      );
    });
    testWidgets('leaderboard today $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id),
            LeaderboardScreen(feedApi: _FeedApi(), userId: 'u1')),
        'r2f_leaderboard_today_$id.png',
      );
    });
    testWidgets('leaderboard queens $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id),
            LeaderboardScreen(feedApi: _FeedApi(), userId: 'u1')),
        'r2f_leaderboard_queens_$id.png',
        act: () async {
          await tester.tap(find.byKey(const ValueKey('capsule_2')));
        },
      );
    });
    testWidgets('leaderboard empty $id', (tester) async {
      board(empty: true);
      await _shoot(
        tester,
        _app(ThemeController.byId(id),
            LeaderboardScreen(feedApi: _FeedApi(), userId: 'u1')),
        'r2f_leaderboard_empty_$id.png',
      );
    });
    testWidgets('puzzle $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id),
            PuzzleScreen(feedApi: _FeedApi(), userId: 'u1')),
        'r2f_puzzle_$id.png',
      );
    });
  }

  // Stories: start (clock just running), mid (≈60%), and held.
  for (final (name, frames, hold) in [
    ('start', 40, false),
    ('mid', 400, false),
    ('hold', 120, true),
  ]) {
    testWidgets('story $name', (tester) async {
      debugStoryAssumeLoaded = true;
      await _shoot(
        tester,
        _app(
          ThemeController.byId('basic'),
          _Opener(
            open: (c) => showMomentViewer(c,
                moment: _moments[0],
                api: _ChatApi(),
                feedApi: _FeedApi(),
                userId: 'u1',
                siblings: _moments),
          ),
        ),
        'r2f_story_${name}_basic.png',
        frames: frames,
        act: hold
            ? () async {
                await tester.startGesture(const Offset(200, 420));
                await tester.pump(const Duration(milliseconds: 300));
              }
            : null,
      );
    });
  }
  // The swipe-up panel: reactions drawn big over the conversation and the
  // composer, opened the way a comment notification opens it.
  testWidgets('story panel', (tester) async {
    debugStoryAssumeLoaded = true;
    final now = DateTime.now();
    MomentComment c(String id, String name, String text,
            {String? parent, bool author = false, Map<String, int> counts = const {}}) =>
        MomentComment(
          id: id,
          userId: name,
          userName: name,
          createdAt: now.subtract(const Duration(minutes: 9)),
          isAuthor: author,
          mine: false,
          canDelete: false,
          parentId: parent,
          text: text,
          reactionCounts: counts,
          reactors: [
            for (final e in counts.entries)
              for (var i = 0; i < e.value; i++)
                MomentReactor(emoji: e.key, userId: '$name$i', name: 'x'),
          ],
        );
    MomentConversation.debugComments = [
      c('a', 'Ece', 'the light in this one, where was this?', counts: {'❤️': 3}),
      c('b', 'Deniz', 'Kaş, last night', parent: 'a', author: true),
      c('d', 'Can', 'ok this is wallpaper material'),
    ];
    addTearDown(() => MomentConversation.debugComments = null);
    await _shoot(
      tester,
      _app(
        ThemeController.byId('basic'),
        _Opener(
          open: (c) => showMomentViewer(c,
              moment: _moments[1],
              api: _ChatApi(),
              feedApi: _FeedApi(),
              userId: 'u1',
              siblings: _moments,
              openComments: true),
        ),
      ),
      'r2f_story_panel_basic.png',
      frames: 80,
    );
  });
  // The reply mode: the story dims, the reactions float big, the composer
  // sits at the bottom. Opened from the comment bar.
  testWidgets('story reply', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugStoryAssumeLoaded = true;
    await _shoot(
      tester,
      _app(
        ThemeController.byId('basic'),
        _Opener(
          open: (c) => showMomentViewer(c,
              moment: _moments[0],
              api: _ChatApi(),
              feedApi: _FeedApi(),
              userId: 'u1',
              siblings: _moments),
        ),
      ),
      'r2f_story_reply_basic.png',
      frames: 60,
      act: () async {
        await tester.tap(find.text('Add a comment…'));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
    );
  });
  testWidgets('story mine', (tester) async {
    debugStoryAssumeLoaded = true;
    await _shoot(
      tester,
      _app(
        ThemeController.byId('basic_daylight'),
        _Opener(
          open: (c) => showMomentViewer(c,
              moment: _moments[4],
              api: _ChatApi(),
              feedApi: _FeedApi(),
              userId: 'u1'),
        ),
      ),
      'r2f_story_mine_basic_daylight.png',
    );
  });

  // Turkish at 1.3× on everything that can truncate.
  for (final key in ['point_tagged', 'gameinfo', 'codeinfo', 'zipinfo', 'card_mine']) {
    testWidgets('sheet $key tr', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId('basic'), _Opener(open: sheets[key]!),
            locale: const Locale('tr'), scale: 1.3),
        'r2f_${key}_tr13.png',
      );
    });
  }
  testWidgets('point keyboard tr', (tester) async {
    await _shoot(
      tester,
      _app(ThemeController.byId('basic'), _Opener(open: sheets['point_tagged']!),
          locale: const Locale('tr'), scale: 1.3),
      'r2f_point_kb_tr13.png',
      keyboard: 336,
    );
  });
  testWidgets('feed tr', (tester) async {
    await _shoot(
      tester,
      _app(ThemeController.byId('basic'), feed(),
          locale: const Locale('tr'), scale: 1.3),
      'r2f_feed_tr13.png',
      act: () async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      },
    );
  });
  testWidgets('leaderboard tr', (tester) async {
    await _shoot(
      tester,
      _app(ThemeController.byId('basic'),
          LeaderboardScreen(feedApi: _FeedApi(), userId: 'u1'),
          locale: const Locale('tr'), scale: 1.3),
      'r2f_leaderboard_today_tr13.png',
    );
  });
}
