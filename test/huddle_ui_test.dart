import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/huddle_outcome.dart';
import 'package:monkeyhub/calls/live_calls_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/huddle_history.dart';
import 'package:monkeyhub/models/message_preview.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_dock.dart';
import 'package:monkeyhub/widgets/huddle_bar.dart';
import 'package:monkeyhub/widgets/live_call_row.dart';
import 'package:monkeyhub/widgets/scheduled_pill.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

ChatUser u(String id, String name) =>
    ChatUser(id: id, username: id, name: name);

Widget wrap(Widget child, {double width = 400}) => MediaQuery(
      data: MediaQueryData(size: Size(width, 600)),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            backgroundColor: const Color(0xFF101418),
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      ),
    );

DockShelfItem scheduledItem() => DockShelfItem(
      id: 'scheduled',
      priority: DockShelfPriority.scheduled,
      expanded: (_) => ScheduledPill(
        scheduled: [
          ScheduledMessage(
            id: 's',
            roomId: 'r',
            content: 'hi',
            sendAt: DateTime(2030),
            createdAt: DateTime(2029),
            pending: true,
          ),
        ],
        onTap: () {},
      ),
      chip: (_) => DockShelfChip(
        icon: CupertinoIcons.clock,
        count: 1,
        semanticLabel: 'scheduled',
        onTap: () {},
      ),
    );

HuddleBar bar({
  VoidCallback? onLeave,
  VoidCallback? onMute,
  VoidCallback? onOpen,
  bool muted = false,
  bool alone = false,
}) =>
    HuddleBar(
      faces: [
        HuddleFace(user: u('me', 'Murat')),
        if (!alone) HuddleFace(user: u('z', 'Zeynep')),
      ],
      names: alone ? 'Nobody else here yet' : 'Zeynep',
      muted: muted,
      onToggleMute: onMute ?? () {},
      onLeave: onLeave ?? () {},
      onOpen: onOpen ?? () {},
    );

void main() {
  final en = AppLocalizationsEn();

  group('history line', () {
    test('parses the wire form and rejects anything else', () {
      final h = HuddleHistory.parse('huddle:ended:720000:3')!;
      expect(h.duration, const Duration(minutes: 12));
      expect(h.people, 3);
      expect(HuddleHistory.parse('hello'), isNull);
      expect(HuddleHistory.parse('huddle:ended:x:3'), isNull);
      expect(HuddleHistory.parse('huddle:ended:5'), isNull);
      expect(HuddleHistory.parse(h.content)!.people, 3);
    });

    test('formats "Huddle · 12 min · 3 people" and the edge durations', () {
      expect(HuddleHistoryLine.textFor(en, 'huddle:ended:720000:3'),
          'Huddle · 12 min · 3 people');
      expect(HuddleHistoryLine.textFor(en, 'huddle:ended:30000:2'),
          'Huddle · under a minute · 2 people');
      expect(HuddleHistoryLine.textFor(en, 'huddle:ended:3900000:2'),
          'Huddle · 1 h 05 min · 2 people');
      expect(HuddleHistoryLine.textFor(en, HuddleHistory.aloneContent),
          'You wanted to talk · Nobody joined');
      expect(HuddleHistoryLine.textFor(en, 'just words'), isNull);
    });

    test('the chat-list preview never shows the wire code', () {
      final m = LocalHuddleNotes.instance;
      m.clear();
      m.addAlone(roomId: 'r', groupCallId: 'g', userId: 'me');
      expect(messagePreviewLine(m.forRoom('r').single), 'huddle');
    });

    testWidgets('renders as a centred line', (t) async {
      await t.pumpWidget(
          wrap(const HuddleHistoryLine(content: 'huddle:ended:720000:3')));
      expect(find.text('Huddle · 12 min · 3 people'), findsOneWidget);
    });
  });

  group('local-only empty huddle row', () {
    setUp(LocalHuddleNotes.instance.clear);

    test('is a non-persisted system row, once per huddle, newest only', () {
      final notes = LocalHuddleNotes.instance;
      var pings = 0;
      notes.addListener(() => pings++);
      notes.addAlone(roomId: 'r1', groupCallId: 'g1', userId: 'me');
      notes.addAlone(roomId: 'r1', groupCallId: 'g1', userId: 'me');
      notes.addAlone(roomId: 'r1', groupCallId: 'g2', userId: 'me');
      final rows = notes.forRoom('r1');
      // g2 replaced g1: three empty huddles must not stack three rows.
      expect(rows, hasLength(1));
      expect(rows.single.id, 'local:huddle:g2');
      expect(rows.first.type, MessageType.system);
      expect(rows.first.content, HuddleHistory.aloneContent);
      expect(rows.first.id, startsWith('local:'));
      expect(pings, 2);
      expect(notes.forRoom('other'), isEmpty);
    });
  });

  group('shelf mode', () {
    LiveRoomCall live({bool mine = false, String? kind = 'huddle'}) =>
        LiveRoomCall(
          roomId: 'r',
          video: false,
          count: 2,
          mine: mine,
          groupCallId: 'g',
          kind: kind,
          joinedUserIds: const ['a', 'b'],
        );

    test('join only for a huddle you are not in', () {
      HuddleShelfMode m(LiveRoomCall? l) =>
          huddleShelfModeFor(roomId: 'r', service: null, live: l);
      expect(m(live()), HuddleShelfMode.join);
      expect(m(live(kind: null)), HuddleShelfMode.none);
      expect(m(live(mine: true)), HuddleShelfMode.none);
      expect(m(null), HuddleShelfMode.none);
    });
  });

  group('shelf priority', () {
    testWidgets('huddle bar outranks scheduled, which collapses to a chip',
        (t) async {
      await t.pumpWidget(wrap(ChatDock(
        field: const SizedBox(height: 52),
        shelf: [
          scheduledItem(),
          DockShelfItem(
            id: 'huddle',
            priority: DockShelfPriority.huddle,
            expanded: (_) => bar(),
            chip: (_) => HuddleChip(onTap: () {}),
          ),
        ],
      )));
      expect(find.byType(HuddleBar), findsOneWidget);
      expect(find.byType(ScheduledPill), findsNothing);
      expect(find.byType(DockShelfChip), findsOneWidget);
    });

    testWidgets('Join pill outranks scheduled; both stay on the shelf row',
        (t) async {
      final items = huddleShelfItems(
        roomId: 'r',
        service: null,
        live: const LiveRoomCall(
          roomId: 'r',
          video: false,
          count: 1,
          mine: false,
          groupCallId: 'g',
          kind: 'huddle',
          joinedUserIds: ['z'],
        ),
        members: {'z': u('z', 'Zeynep')},
        myUserId: 'me',
        api: null,
        onJoin: () async {},
      );
      expect(items.single.priority, DockShelfPriority.join);
      await t.pumpWidget(wrap(ChatDock(
        field: const SizedBox(height: 52),
        shelf: [scheduledItem(), ...items],
      )));
      expect(find.byType(HuddleJoinPill), findsOneWidget);
      expect(find.byType(DockShelfChip), findsOneWidget);
      // One row, as tall as the pill's own row: the chip is centred in it.
      expect(t.getSize(find.byType(ChatDock)).height,
          kHuddlePillRowHeight + 52);
      expect(
        (t.getCenter(find.byType(HuddleJoinPill)).dy -
                t.getCenter(find.byType(DockShelfChip)).dy)
            .abs(),
        lessThan(1),
      );
    });

    testWidgets('a collapsed huddle is a live waveform chip', (t) async {
      await t.pumpWidget(wrap(HuddleChip(onTap: () {})));
      expect(find.byType(HuddleWaveGlyph), findsOneWidget);
    });
  });

  group('join pill', () {
    testWidgets('shows up to three real avatars and joins on tap', (t) async {
      var joined = 0;
      await t.pumpWidget(wrap(HuddleJoinPill(
        users: [
          u('a', 'Ada'),
          u('b', 'Bo'),
          u('c', 'Cy'),
          u('d', 'Di'),
        ],
        onJoin: () async => joined++,
      )));
      await t.pumpAndSettle();
      expect(find.byType(UserAvatar), findsNWidgets(3));
      expect(find.bySemanticsLabel('Ada and 3 others'), findsOneWidget);
      await t.tap(find.text('Join'));
      await t.pump();
      expect(joined, 1);
    });

    testWidgets('a failed join is toasted, not thrown', (t) async {
      await t.pumpWidget(wrap(HuddleJoinPill(
        users: [u('a', 'Ada')],
        onJoin: () async => throw StateError('CALL_FULL'),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('Join'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('That huddle is full.'), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 6));
    });
  });

  group('bar', () {
    testWidgets('leave, mute and open each fire their own callback',
        (t) async {
      var left = 0, muted = 0, opened = 0;
      await t.pumpWidget(wrap(bar(
        onLeave: () => left++,
        onMute: () => muted++,
        onOpen: () => opened++,
      )));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Leave'));
      await t.tap(find.bySemanticsLabel('Mute'));
      await t.tap(find.text('Zeynep'));
      await t.pump();
      expect([left, muted, opened], [1, 1, 1]);
    });

    testWidgets('alone says so', (t) async {
      await t.pumpWidget(wrap(bar(alone: true)));
      await t.pumpAndSettle();
      expect(find.text('Nobody else here yet'), findsOneWidget);
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('landing animation settles with no pending frames',
        (t) async {
      await t.pumpWidget(wrap(HuddleBar(
        faces: [HuddleFace(user: u('me', 'Murat'))],
        names: 'Nobody else here yet',
        muted: false,
        playRings: true,
        onToggleMute: () {},
        onLeave: () {},
        onOpen: () {},
      )));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
    });
  });

  group('chat list', () {
    LiveRoomCall call({String? kind}) => LiveRoomCall(
          roomId: 'r',
          video: false,
          count: 2,
          mine: false,
          groupCallId: 'g',
          kind: kind,
          joinedUserIds: const ['a', 'b'],
        );

    int halos(WidgetTester t) => t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((c) => c.painter.runtimeType.toString() == '_HaloPainter')
        .length;

    testWidgets('a huddle shows the waveform badge but no call halo',
        (t) async {
      await t.pumpWidget(wrap(LiveCallHalo(
        call: call(kind: 'huddle'),
        size: 48,
        child: const SizedBox.square(dimension: 48),
      )));
      expect(halos(t), 0);
      await t.pumpWidget(wrap(LiveCallHalo(
        call: call(),
        size: 48,
        child: const SizedBox.square(dimension: 48),
      )));
      await t.pump(const Duration(milliseconds: 500));
      expect(halos(t), 1);
    });

    testWidgets('the row label says Huddle, with the live waveform',
        (t) async {
      await t.pumpWidget(wrap(
        SizedBox(width: 300, child: LiveCallChip(call: call(kind: 'huddle'))),
      ));
      expect(find.text('Huddle'), findsOneWidget);
      expect(find.byType(HuddleWaveGlyph), findsOneWidget);
      expect(find.text('Voice call'), findsNothing);
    });
  });
}
