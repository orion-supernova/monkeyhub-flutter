// Design review of the Feed area: the board, its sheets, its pushed pages,
// the moment viewer, the games and Discover — rendered under a dark, a light
// and a character theme, plus Turkish and a 1.3 text scale.
//
//   flutter test test/design_preview/feed_review_preview.dart
//
// Not a test. PNGs land in build/design_preview/fgr_*.png.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/models/game_record.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/screens/discover_lists.dart';
import 'package:monkeyhub/screens/discover_screen.dart';
import 'package:monkeyhub/screens/feed/archive_screen.dart';
import 'package:monkeyhub/screens/feed/moment_composer.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/screens/feed/point_composer.dart';
import 'package:monkeyhub/screens/feed/points_explainer.dart';
import 'package:monkeyhub/screens/feed/puzzle_screen.dart';
import 'package:monkeyhub/screens/feed_screen.dart';
import 'package:monkeyhub/screens/games/games_hub_screen.dart';
import 'package:monkeyhub/screens/games/tango_screen.dart';
import 'package:monkeyhub/screens/games/zip_screen.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_info_sheet.dart';
import 'package:monkeyhub/widgets/game_records.dart';
import 'package:monkeyhub/widgets/moment_reactor_sheet.dart';

import '../fakes/fake_games_api.dart';
import 'preview_kit.dart';

class _ChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FeedApi extends Fake implements FeedApi {
  _FeedApi(this.items);
  final List<Moment> items;
  @override
  Future<MomentPage> archive({
    required String userId,
    String? ofUserId,
    int? beforeTimestamp,
    int? limit,
  }) async => MomentPage(items: items, hasMore: false);
}

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
  bool get canSeePublicRooms => true;
  @override
  bool get canRequestContacts => true;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final _friends = [
  for (final n in ['Ece Yıldız', 'Deniz Kaya', 'Mom', 'Arda', 'Zeynep Çelik'])
    ChatUser(id: 'u_$n', username: n.toLowerCase().split(' ').first, name: n),
];

ChatRoom _room(String id, String name, int members) => ChatRoom(
      id: id,
      name: name,
      createdBy: 'x',
      createdAt: DateTime(2026),
      isPrivate: false,
      memberCount: members,
      description: 'Weekly picks, Sunday screenings, no spoilers.',
      participantIds: const [],
    );

class _Repo extends Fake implements ChatRepository {
  _Repo({this.empty = false});
  final bool empty;
  @override
  String? get userId => 'me';
  @override
  List<ChatUser> get friends => empty ? const [] : _friends;
  @override
  List<FriendRequest> get incomingRequests => empty
      ? const []
      : [
          FriendRequest(
            id: 'fr1',
            user: ChatUser(id: 'u_k', username: 'kerem', name: 'Kerem Aydın'),
            createdAt: DateTime(2026, 10, 3),
            roomType: RoomType.regular,
            messageCount: 1,
            initialMessage: 'hey! we met at the film club',
          ),
        ];
  @override
  List<FriendRequest> get outgoingRequests => const [];
  @override
  List<RoomInvitation> get roomInvitations => empty
      ? const []
      : [
          RoomInvitation(
            invitationId: 'i1',
            createdAt: DateTime(2026, 10, 3),
            roomId: 'r9',
            roomName: 'Weekend Crew',
            memberCount: 6,
            inviter: _friends[1],
          ),
        ];
  @override
  List<ChatRoom> get activeRooms => empty
      ? const []
      : [
          _room('r1', 'Istanbul Film Club', 248),
          _room('r2', 'Kadıköy Runners', 31),
          _room('r3', 'Board game night', 12),
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
}) =>
    Moment(
      id: id,
      userId: mine ? 'me' : 'u_$who',
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
      reactors: [
        for (final e in reactions.keys)
          MomentReactor(emoji: e, userId: 'u_Deniz', name: 'Deniz Kaya'),
      ],
    );

final _moments = <Moment>[
  _m('h1', media: 's1', caption: 'Sunset over the Bosphorus', minutesAgo: 20,
      reactions: const {'🔥': 3, '😍': 1}),
  _m('h2', who: 'Deniz Kaya', media: 's2', minutesAgo: 70),
  _m('h3', mine: true, media: 's3', caption: 'new desk', minutesAgo: 90),
  _m('h4', who: 'Zeynep Çelik', caption: 'Caption-only highlight, no photo',
      minutesAgo: 120),
  _m('p1', tag: MomentTag.jinx,
      caption: 'Washed the car, it rained at four.', minutesAgo: 15,
      reactions: const {'😂': 4}),
  _m('p2', who: 'Deniz Kaya', tag: MomentTag.fate,
      caption: 'Ran into my dentist in Lisbon', minutesAgo: 45),
  _m('p3', mine: true, tag: MomentTag.luck,
      caption: 'Found 50 lira in an old coat', minutesAgo: 60),
  _m('p4', who: 'Arda', tag: MomentTag.calledIt, media: 's4',
      caption: 'Told you the match would go to penalties', minutesAgo: 200),
  _m('p5', who: 'Mom', tag: MomentTag.npc,
      caption: 'Said "you too" to the waiter who said enjoy your meal',
      minutesAgo: 300),
];

Widget _app(
  AppTheme theme,
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) =>
    ThemeScope(
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

/// A host page that opens something on its first frame.
class _Opener extends StatefulWidget {
  const _Opener({required this.open, this.under});
  final void Function(BuildContext context) open;
  final Widget? under;
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
    return widget.under ??
        Scaffold(
          backgroundColor: theme.background,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
            children: [
              Text('Feed', style: theme.displayLarge),
              for (var i = 0; i < 9; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 26, backgroundColor: theme.surfaceRaised),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Row $i', style: theme.bodyEmph)),
                  ]),
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
  Future<void> Function()? act,
  Size size = kIphone16Pro,
}) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  final pad = FakeViewPadding(
    top: kIphoneTopInset * dpr,
    bottom: kIphoneBottomInset * dpr,
  );
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
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
    for (var i = 0; i < 90; i++) {
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

FeedScreen _feed({bool empty = false}) => FeedScreen(
      repo: _Repo(empty: empty),
      api: _ChatApi(),
      feedApi: _FeedApi(const []),
      auth: _Auth(),
      family: _Family(),
    );

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

  final recordsApi = FakeGamesApi(payload)
    ..records = RecordBoard(games: {
      RecordGame.queens: [
        for (var i = 0; i < 4; i++)
          GameRecordRow(
            recordId: 'r$i',
            userId: i == 1 ? 'u1' : 'x$i',
            name: ['Ece Yıldız', 'Murat', 'Deniz Kaya', 'Zeynep Çelik'][i],
            rank: i + 1,
            best: 61000 + i * 17000,
            dayKey: '2026-10-0${i + 1}',
            achievedAt: DateTime(2026, 10, i + 1),
            solves: 12 - i,
            reactions: i == 0
                ? const [RecordReaction(emoji: '🔥', count: 3)]
                : const [],
          ),
      ],
    });

  setUpAll(loadPreviewFonts);
  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    RecordsStore.instance.api = recordsApi;
    RecordsStore.instance.clear();
    GamesStore.instance.clear();
    FeedStore.instance.applyBoard(
      FeedBoard(moments: _moments, serverNow: DateTime.now()),
    );
  });
  tearDown(() => FeedStore.instance.stop());

  final sheets = <String, void Function(BuildContext)>{
    'point': (c) => showPointComposer(c,
        api: _ChatApi(), feedApi: _FeedApi(const []), userId: 'me'),
    'point_tagged': (c) => showPointComposer(c,
        api: _ChatApi(),
        feedApi: _FeedApi(const []),
        userId: 'me',
        initialTag: MomentTag.jinx),
    'moment': (c) => showMomentComposer(c,
        api: _ChatApi(), feedApi: _FeedApi(const []), userId: 'me'),
    'reactor': (c) => showMomentReactorSheet(c,
        emoji: '🔥', names: const ['Ece Yıldız', 'Deniz Kaya', 'Mom', 'Arda']),
    'gameinfo': (c) => showGameInfo(c, DailyGame.queens,
        entry: GameInfoEntry.play, onPlay: () {}),
    'codeinfo': (c) =>
        showCodePuzzleInfo(c, entry: GameInfoEntry.play, onPlay: () {}),
    'records': (c) =>
        showRecordsSheet(c, game: RecordGame.queens, viewerId: 'u1'),
    'viewer_card': (c) => showMomentViewer(c,
        moment: _moments[4],
        api: _ChatApi(),
        feedApi: _FeedApi(const []),
        userId: 'me',
        siblings: _moments),
    'viewer_card_mine': (c) => showMomentViewer(c,
        moment: _moments[6],
        api: _ChatApi(),
        feedApi: _FeedApi(const []),
        userId: 'me'),
    'viewer_stage': (c) => showMomentViewer(c,
        moment: _moments[0],
        api: _ChatApi(),
        feedApi: _FeedApi(const []),
        userId: 'me',
        siblings: _moments),
    'viewer_stage_mine': (c) => showMomentViewer(c,
        moment: _moments[2],
        api: _ChatApi(),
        feedApi: _FeedApi(const []),
        userId: 'me'),
  };

  final pages = <String, Widget Function()>{
    'feed': () => _feed(),
    'feed_empty': () => _feed(empty: true),
    'archive': () => ArchiveScreen(
        api: _ChatApi(), feedApi: _FeedApi(_moments), userId: 'me'),
    'archive_empty': () => ArchiveScreen(
        api: _ChatApi(), feedApi: _FeedApi(const []), userId: 'me'),
    'explainer': () => const PointsExplainerScreen(),
    'puzzle': () => PuzzleScreen(feedApi: _FeedApi(const []), userId: 'u1'),
    'hub': () => GamesHubScreen(feedApi: _FeedApi(const []), userId: 'u1'),
    'tango': () => const TangoScreen(userId: 'u1'),
    'zip': () => const ZipScreen(userId: 'u1'),
    'discover': () =>
        DiscoverScreen(repo: _Repo(), api: _ChatApi(), family: _Family()),
    'discover_empty': () => DiscoverScreen(
        repo: _Repo(empty: true), api: _ChatApi(), family: _Family()),
    'people_list': () => PeopleListScreen(repo: _Repo(), api: _ChatApi()),
    'rooms_list': () => RoomsListScreen(repo: _Repo(), api: _ChatApi()),
  };

  const themes = ['basic', 'basic_daylight', 'neon_night', 'risograph_pop'];

  for (final id in themes) {
    for (final e in pages.entries) {
      testWidgets('page ${e.key} $id', (tester) async {
        await _shoot(
            tester, _app(ThemeController.byId(id), e.value()), 'fgr_${e.key}_$id.png');
      });
    }
    for (final e in sheets.entries) {
      testWidgets('sheet ${e.key} $id', (tester) async {
        await _shoot(
          tester,
          _app(ThemeController.byId(id), _Opener(open: e.value)),
          'fgr_${e.key}_$id.png',
        );
      });
    }
    // The feed scrolled to standings + activity.
    testWidgets('feed scrolled $id', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id), _feed()),
        'fgr_feed_scrolled_$id.png',
        act: () async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
        },
      );
    });
  }

  // Turkish + 1.3 text scale on the surfaces most likely to truncate.
  for (final key in ['point_tagged', 'moment', 'gameinfo', 'records', 'viewer_card_mine']) {
    testWidgets('sheet $key tr', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId('basic'), _Opener(open: sheets[key]!),
            locale: const Locale('tr'), scale: 1.3),
        'fgr_${key}_tr13.png',
      );
    });
  }
  for (final key in ['feed', 'explainer', 'hub', 'discover', 'archive', 'puzzle']) {
    testWidgets('page $key tr', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId('basic'), pages[key]!(),
            locale: const Locale('tr'), scale: 1.3),
        'fgr_${key}_tr13.png',
      );
    });
  }
  // The feed pulled back to the top, where the games band sits. The page's
  // scroll memory outlives a test, so the plain `feed` renders after a
  // `feed scrolled` one open mid-list; a drag back down undoes that.
  for (final (id, locale, scale) in [
    ('risograph_pop', const Locale('en'), 1.0),
    ('basic', const Locale('tr'), 1.3),
  ]) {
    testWidgets('feed top $id ${locale.languageCode}', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id), _feed(), locale: locale, scale: scale),
        'fgr_feed_top_${id}_${locale.languageCode}.png',
        act: () async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        },
      );
    });
  }
  for (final key in ['people_list', 'rooms_list', 'discover_empty']) {
    testWidgets('page $key tr', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId('basic'), pages[key]!(),
            locale: const Locale('tr'), scale: 1.3),
        'fgr_${key}_tr13.png',
      );
    });
  }
  // Discover with no people, scrolled to the room doors at the foot.
  for (final (id, locale, scale) in [
    ('basic_daylight', const Locale('en'), 1.0),
    ('basic', const Locale('tr'), 1.3),
  ]) {
    testWidgets('discover doors $id ${locale.languageCode}', (tester) async {
      await _shoot(
        tester,
        _app(ThemeController.byId(id), pages['discover_empty']!(),
            locale: locale, scale: scale),
        'fgr_discover_doors_${id}_${locale.languageCode}.png',
        act: () async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
        },
      );
    });
  }
  testWidgets('feed scrolled tr', (tester) async {
    await _shoot(
      tester,
      _app(ThemeController.byId('basic'), _feed(),
          locale: const Locale('tr'), scale: 1.3),
      'fgr_feed_scrolled_tr13.png',
      act: () async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      },
    );
  });
}
