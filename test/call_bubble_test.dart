import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/live_calls_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/call_history.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/room_items.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/bubble_shape.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/call_bubble.dart';

const _otherPlatform = 'ios';

String wire(
  String s, {
  String id = 'c1',
  String t = 'video',
  String k = 'd',
  int? a,
  int? d,
  String? o,
  String? q,
  int? n,
}) =>
    'call:{"v":1,"k":"$k","id":"$id","t":"$t","s":"$s"'
    '${a != null ? ',"a":$a' : ''}'
    '${d != null ? ',"d":$d' : ''}'
    '${n != null ? ',"n":$n' : ''}'
    '${o != null ? ',"o":"$o"' : ''}'
    '${q != null ? ',"q":"$q"' : ''}}';

ChatMessage msg(String content, {String id = 'm1', String sender = 'them'}) =>
    ChatMessage(
      id: id,
      roomId: 'room',
      senderId: sender,
      senderName: sender,
      content: content,
      createdAt: DateTime(2026, 11, 6, 9, 30),
      type: MessageType.system,
    );

Widget host(
  Widget Function(AppTheme) build, {
  bool dark = true,
}) {
  final theme = dark ? BasicTheme.midnight() : BasicTheme.daylight();
  return MediaQuery(
    data: const MediaQueryData(size: Size(400, 800)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(theme),
        child: Scaffold(
          body: Builder(
            builder: (c) => Align(
              alignment: Alignment.topLeft,
              child: build(ThemeScope.of(c)),
            ),
          ),
        ),
      ),
    ),
  );
}

CallBubble bubble(
  AppTheme theme,
  ChatMessage m, {
  required bool mine,
  List<ChatMessage> run = const [],
  void Function(CallEvent)? onTap,
}) =>
    CallBubble(
      key: ValueKey('b-${m.id}'),
      message: m,
      event: CallEvent.parse(m.content)!,
      isMine: mine,
      theme: theme,
      decorate: (f, l) => theme.bubbleDecoration(
        isMine: mine,
        ephemeral: false,
        style: BubbleStyle.tailed,
        firstInRun: f,
        lastInRun: l,
      ),
      run: run,
      onTap: onTap,
      ownPlatform: _otherPlatform,
    );

void main() {
  setUp(() {
    CallBubble.wobbled.clear();
    CallBubble.openedRuns.clear();
  });

  // (status, mine) -> title, per the perspective table.
  final titles = <(String, bool), String>{
    ('ringing', true): 'Calling…',
    ('ringing', false): 'Incoming video call',
    ('active', true): 'Video call',
    ('active', false): 'Video call',
    ('ended', true): 'Video call',
    ('ended', false): 'Video call',
    ('missed', true): 'No answer',
    ('missed', false): 'Missed video call',
    ('cancelled', true): 'Cancelled video call',
    ('cancelled', false): 'Missed video call',
    ('declined', true): 'Declined video call',
    ('declined', false): 'Declined video call',
  };
  for (final entry in titles.entries) {
    final (status, mine) = entry.key;
    testWidgets('$status as ${mine ? 'caller' : 'callee'} says ${entry.value}',
        (tester) async {
      final a = DateTime.now().millisecondsSinceEpoch;
      final content = wire(status,
          a: status == 'active' || status == 'ended' ? a : null,
          d: status == 'ended' ? 761000 : null);
      await tester.pumpWidget(host(
          (t) => bubble(t, msg(content), mine: mine, onTap: (_) {})));
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      if (status == 'ended') {
        expect(find.text(mine ? 'Outgoing · 12:41' : 'Incoming · 12:41'),
            findsOneWidget);
      }
      // Let wobble/loops finish, then drop the tree so nothing is pending.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a missed call offers to call back; the tap carries the event',
      (tester) async {
    CallEvent? tapped;
    await tester.pumpWidget(host((t) =>
        bubble(t, msg(wire('missed')), mine: false, onTap: (e) => tapped = e)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tap to call back'), findsOneWidget);
    await tester.tap(find.text('Missed video call'));
    await tester.pump();
    expect(tapped?.id, 'c1');
    expect(tapped?.isVideo, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no tap handler (calling off) means no call-back affordance',
      (tester) async {
    await tester.pumpWidget(
        host((t) => bubble(t, msg(wire('missed')), mine: false)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tap to call back'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quality chip only for fair or poor; answered-on only elsewhere',
      (tester) async {
    for (final (q, shown) in [('good', false), ('fair', true), ('poor', true)]) {
      await tester.pumpWidget(host((t) => bubble(
          t,
          msg(wire('ended', a: 1, d: 60000, q: q, o: 'macos')),
          mine: true)));
      await tester.pump();
      expect(find.text('Fair connection'), q == 'fair' ? findsOneWidget : findsNothing);
      expect(find.text('Poor connection'), q == 'poor' ? findsOneWidget : findsNothing);
      expect(shown, q != 'good');
      expect(find.textContaining('Answered on Mac'), findsOneWidget);
    }
    // Same platform as the viewer: nothing to say.
    await tester.pumpWidget(host((t) => bubble(
        t, msg(wire('ended', a: 1, d: 60000, o: 'ios')),
        mine: true)));
    await tester.pump();
    expect(find.textContaining('Answered on'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live ticks, then settles in place when the same message ends',
      (tester) async {
    var nowMs = DateTime(2026, 11, 6, 10).millisecondsSinceEpoch;
    CallBubble.clock = () => DateTime.fromMillisecondsSinceEpoch(nowMs);
    addTearDown(() => CallBubble.clock = DateTime.now);
    final started = DateTime.fromMillisecondsSinceEpoch(nowMs - 65000);
    final live = wire('active', a: started.millisecondsSinceEpoch);
    late StateSetter set;
    String content = live;
    await tester.pumpWidget(host((t) => StatefulBuilder(builder: (c, s) {
          set = s;
          return bubble(t, msg(content), mine: true);
        })));
    await tester.pump();
    expect(find.text('1:05'), findsOneWidget);
    final stateBefore = tester.state(find.byType(CallBubble));
    nowMs += 2000;
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1:07'), findsOneWidget);

    set(() => content = wire('ended',
        a: started.millisecondsSinceEpoch, d: 67000));
    await tester.pump();
    // Same State object: it settled in place rather than being replaced.
    expect(identical(tester.state(find.byType(CallBubble)), stateBefore), isTrue);
    expect(find.text('Outgoing · 1:07'), findsOneWidget);
    // Frozen: time passing changes nothing.
    nowMs += 3000;
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Outgoing · 1:07'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a missed call wobbles on first build only', (tester) async {
    double angle() {
      var worst = 0.0;
      for (final w in tester.widgetList<Transform>(find.descendant(
          of: find.byType(CallBubble), matching: find.byType(Transform)))) {
        final r = w.transform.getRotation();
        // A rotation about z: |sin| from the off-diagonal.
        final a = r.entry(0, 1).abs();
        if (a > worst) worst = a;
      }
      return worst;
    }

    final m = msg(wire('missed'), id: 'wobble');
    await tester.pumpWidget(host((t) => bubble(t, m, mine: false)));
    await tester.pump(); // first frame is the settled bubble, wobble queued
    await tester.pump(const Duration(milliseconds: 90));
    expect(angle(), greaterThan(0.01));
    await tester.pump(const Duration(seconds: 1));
    expect(angle(), lessThan(0.001));

    // Scroll away and back: a fresh State, same message. No second wobble.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host((t) => bubble(t, m, mine: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(angle(), lessThan(0.001));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('declined: the handset is tipped, the camera is not',
      (tester) async {
    await tester.pumpWidget(host((t) => bubble(
        t, msg(wire('declined', t: 'audio')), mine: false)));
    await tester.pump();
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CallGlyphPainter>()
        .single;
    expect(painter.tip, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('group Join pill appears only while the store says it is live',
      (tester) async {
    final store = LiveCallsStore.instance;
    List<Map<String, dynamic>>? emit;
    await store.attachWith((ids, onCalls, onError) async {
      emit = null;
      onCalls([
        {
          'roomId': 'room',
          'groupCallId': 'g1',
          'type': 'video',
          'joinedUserIds': ['them'],
        }
      ]);
      return () {};
    }, 'me');
    store.syncRooms(['room']);
    await tester.pump();
    CallEvent? tapped;
    await tester.pumpWidget(host((t) => bubble(
        t, msg(wire('active', id: 'g1', k: 'g', a: 1, n: 2)),
        mine: false, onTap: (e) => tapped = e)));
    await tester.pump();
    expect(find.text('Join'), findsOneWidget);
    expect(find.text('2 people'), findsNothing); // timer line carries it
    await tester.tap(find.text('Join'));
    expect(tapped?.id, 'g1');
    // An ended group call has no pill.
    await tester.pumpWidget(host((t) => bubble(
        t, msg(wire('ended', id: 'g1', k: 'g', a: 1, d: 5000, n: 2)),
        mine: false, onTap: (_) {})));
    await tester.pump();
    expect(find.text('Join'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.detach();
    expect(emit, isNull);
  });

  group('collapse', () {
    List<RoomItem> rows(List<ChatMessage> ms) =>
        [for (final m in ms) MessageItem(m)];

    test('consecutive missed calls from one caller become one row', () {
      final out = collapseMissedCalls(rows([
        msg(wire('missed', id: 'a'), id: '1'),
        msg(wire('cancelled', id: 'b'), id: '2'),
        msg(wire('missed', id: 'c'), id: '3'),
      ]));
      expect(out, hasLength(1));
      final row = out.single as MessageItem;
      expect(row.message.id, '3');
      expect([for (final m in row.callRun) m.id], ['1', '2', '3']);
    });

    test('anything between, another caller, or another type breaks the run',
        () {
      final text = ChatMessage(
          id: 'x',
          roomId: 'room',
          senderId: 'them',
          senderName: 'them',
          content: 'hi',
          createdAt: DateTime(2026));
      final out = collapseMissedCalls(rows([
        msg(wire('missed', id: 'a'), id: '1'),
        text,
        msg(wire('missed', id: 'b'), id: '2'),
        msg(wire('missed', id: 'c'), id: '3', sender: 'other'),
        msg(wire('missed', id: 'd', t: 'audio'), id: '4', sender: 'other'),
        msg(wire('ended', id: 'e', a: 1, d: 1000), id: '5', sender: 'other'),
      ]));
      expect(out, hasLength(6));
      expect(out.whereType<MessageItem>().every((r) => r.callRun.isEmpty),
          isTrue);
    });

    test('a divider row between them keeps them apart', () {
      final out = collapseMissedCalls([
        MessageItem(msg(wire('missed', id: 'a'), id: '1')),
        DateDividerItem('Today'),
        MessageItem(msg(wire('missed', id: 'b'), id: '2')),
      ]);
      expect(out, hasLength(3));
    });

    testWidgets('x3 badge springs open into the individual bubbles',
        (tester) async {
      final ms = [
        msg(wire('missed', id: 'a'), id: '1'),
        msg(wire('missed', id: 'b'), id: '2'),
        msg(wire('missed', id: 'c'), id: '3'),
      ];
      await tester.pumpWidget(host(
          (t) => bubble(t, ms.last, mine: false, run: ms, onTap: (_) {})));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('Missed video call'), findsOneWidget);
      expect(find.text('Tap to call back'), findsOneWidget);
      await tester.tap(find.text('×3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Missed video call'), findsNWidgets(3));
      expect(find.text('×3'), findsNothing);
      expect(find.text('Show less'), findsOneWidget);
      await tester.tap(find.text('Show less'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('×3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('previews are told from the viewer side, never the raw code',
      (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(host((t) => Builder(builder: (c) {
          l = AppLocalizations.of(c);
          return const SizedBox();
        })));
    String p(String content, bool mine) =>
        callPreviewForContent(l, content, mine: mine)!;
    expect(p(wire('ended', a: 1, d: 761000), true), 'Outgoing video call · 12:41');
    expect(p(wire('ended', a: 1, d: 761000), false), 'Incoming video call · 12:41');
    expect(p(wire('missed'), false), 'Missed video call');
    expect(p(wire('missed'), true), 'No answer');
    expect(p('call:{garbled', false), isNot(contains('{')));
    expect(callPreviewForContent(l, 'hello', mine: true), isNull);
  });
}
