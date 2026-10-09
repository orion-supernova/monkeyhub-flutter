import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/timeline_list_view.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/screens/room_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_bottom_inset.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/scroll_to_latest.dart';

/// A composer that grows must take its room from the transcript, not from the
/// conversation.
///
/// The liquid chat style floats its composer stack over a `Positioned.fill`
/// transcript — nothing in the layout holds the newest bubble clear of it, so
/// the transcript reserves that room by hand. The reservation was a constant,
/// which is right for exactly one composer: an empty one, on one line. A second
/// line grew the field UPWARD, over the conversation, and the last thing said
/// went behind the glass — permanently, because nothing gave it back.
///
/// This mounts the real screen and measures, because every cheaper version of
/// this test passes on the broken layout: the bubble is still in the tree, is
/// still "visible" to the finder, and still has a sane rect. The bug is only
/// ever a comparison between two rects.
///
/// The classic style is not covered here and needs no cover: its composer sits
/// in a real `Column` above an `Expanded` transcript, so the viewport shrinks by
/// the right amount without anyone doing anything.

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  final Map<String, void Function(dynamic)> sinks = {};
  @override
  Future<Subscription> subscribe(String name, Map<String, dynamic> args,
      {required void Function(dynamic) onData,
      void Function(Object error)? onError}) async {
    sinks[name] = onData;
    return _FakeSub();
  }

  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _OfflineApi extends Fake implements ChatApi {
  @override
  Future<List<ChatRoom>> listUserRooms(String u) async =>
      throw StateError('offline');
  @override
  Future<List<ChatUser>> listFriends(String u) async =>
      throw StateError('offline');
  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String u) async =>
      throw StateError('offline');
  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String u) async =>
      throw StateError('offline');
  @override
  Future<List<ChatMessage>> listMessages(
          {required String roomId, int limit = 100, String? viewerUserId}) async =>
      throw StateError('offline');
  @override
  Future<void> markRoomRead(
      {required String roomId,
      required String userId,
      DateTime? upTo}) async {}
  @override
  Future<void> clearTyping(
      {required String roomId, required String userId}) async {}
  @override
  Future<void> markRoomDelivered(
      {required String roomId,
      required String userId,
      DateTime? upTo}) async {}
  @override
  Future<void> setTyping(
      {required String roomId, required String userId}) async {}
}

final _t0 = DateTime(2026, 3, 1, 12, 0);

Map<String, dynamic> _roomWire() => {
      '_id': 'r1',
      'name': 'The Room',
      'createdBy': 'someone',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': false,
      'memberCount': 2,
      'participantIds': ['me', 'someone'],
      'isMember': true,
      'lastMessageTime': _t0.millisecondsSinceEpoch,
      'unreadCount': 0,
    };

Map<String, dynamic> _msgWire(String id, DateTime at) => {
      '_id': id,
      'roomId': 'r1',
      'userId': 'someone',
      'content': 'msg $id',
      'type': 'text',
      'createdAt': at.millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late ChatRepository repo;

  setUp(() async {
    cv = _FakeCv();
    repo = ChatRepository(api: _OfflineApi(), cv: cv);
    await repo.attach('me');
  });

  Widget host() => MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: RoomScreen(
                roomId: 'r1', repo: repo, api: ChatApi(ConvexBackend.instance)),
          ),
        ),
      );

  /// Mounts the room with a short transcript and lets it settle.
  Future<void> openRoom(WidgetTester t, {int messages = 6}) async {
    await t.pumpWidget(host());
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    cv.sinks['rooms:listUserRooms']!([_roomWire()]);
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    cv.sinks['messages:list']!([
      for (var i = 0; i < messages; i++)
        _msgWire('m$i', _t0.add(Duration(minutes: i))),
    ]);
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  /// The newest bubble in the transcript.
  ///
  /// Matched through its text rather than by type because every row is a
  /// `MessageBubble` — and through a predicate rather than `find.text` because a
  /// bubble inlines its own timestamp into the span, so the plain text is
  /// `msg m5` plus an object-replacement character.
  Finder newestBubble() => find
      .ancestor(
        of: find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? w.textSpan?.toPlainText() ?? '').startsWith('msg m5')),
        matching: find.byType(MessageBubble),
      )
      .first;

  /// The top edge of the glass as it is actually PAINTED this frame.
  ///
  /// Not `ChatComposerLiquid`'s own rect: the composer stack is laid out at its
  /// destination height from the first frame of a growth and clipped to the
  /// animating box around it, so the widget's rect says where the glass is
  /// going, and this says where it is. The difference is the entire subject of
  /// the mid-animation test below.
  double glassTop(WidgetTester t) => t
      .getRect(find
          .ancestor(
            of: find.byType(ChatComposerLiquid),
            matching: find.byType(MeasureChatBottomInset),
          )
          .last)
      .top;

  /// The gap between the newest bubble and the top of the glass. Negative means
  /// the composer is sitting on the conversation.
  double clearance(WidgetTester t) =>
      glassTop(t) - t.getRect(newestBubble()).bottom;

  /// Types [lines] lines into the composer and settles the growth animation.
  Future<void> type(WidgetTester t, int lines) async {
    await t.enterText(
      find.byType(TextField).first,
      List.generate(lines, (i) => 'line $i').join('\n'),
    );
    // Longer than any theme's motionFast, plus the frame the measurement is
    // published on.
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
  }

  testWidgets('the newest message stays clear of a growing composer',
      (t) async {
    await openRoom(t);

    final atRest = clearance(t);
    expect(atRest, greaterThanOrEqualTo(0.0),
        reason: 'a one-line composer is the case the old constant got right');

    final composerAtRest = t.getRect(find.byType(ChatComposerLiquid)).height;

    for (final lines in [2, 3, 4]) {
      await type(t, lines);
      final grown = t.getRect(find.byType(ChatComposerLiquid)).height;
      expect(grown, greaterThan(composerAtRest),
          reason: '$lines lines should have grown the field at all');
      expect(
        clearance(t),
        greaterThanOrEqualTo(0.0),
        reason:
            'at $lines lines the composer grew over the transcript instead of '
            'pushing it up',
      );
    }
  });

  testWidgets('the transcript comes back down when the composer shrinks',
      (t) async {
    await openRoom(t);
    final atRest = t.getRect(newestBubble());

    await type(t, 4);
    final pushed = t.getRect(newestBubble());
    expect(pushed.bottom, lessThan(atRest.bottom - 8),
        reason: 'four lines of composer should have lifted the transcript');

    await type(t, 1);
    final settled = t.getRect(newestBubble());
    expect(
      (settled.bottom - atRest.bottom).abs(),
      lessThan(0.5),
      reason: 'a composer that shrinks has to give the room back exactly — a '
          'reservation that only ever grows is a permanent gap',
    );
  });

  testWidgets('the conversation is never behind the glass, on any frame',
      (t) async {
    await openRoom(t);

    /// Walks [frames] frames one at a time, failing on the first one where the
    /// glass is over the newest bubble.
    ///
    /// The settled assertions above cannot see this: a reservation that tracks
    /// only where the glass IS lands in exactly the right place and spends the
    /// whole animation a frame behind, and a reservation that tracks only where
    /// it is GOING lands in exactly the right place and drops the transcript
    /// under the glass all the way down. Both look perfect at rest.
    Future<void> walk(String phase, {int frames = 20}) async {
      for (var f = 0; f < frames; f++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(
          clearance(t),
          greaterThanOrEqualTo(0.0),
          reason: '$phase, frame $f: the glass crossed the newest bubble',
        );
      }
    }

    await t.enterText(find.byType(TextField).first, 'one\ntwo\nthree\nfour');
    await walk('growing');
    await t.enterText(find.byType(TextField).first, 'one');
    await walk('shrinking');
  });

  testWidgets('the jump-to-latest pills clear the composer too', (t) async {
    // Enough of a transcript to have somewhere to scroll away to.
    await openRoom(t, messages: 40);
    await type(t, 4);
    // Scroll away from the newest message so the pill is on screen.
    await t.drag(find.byType(TimelineListView), const Offset(0, 400));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    final pill = find.byType(ScrollToLatestPill);
    expect(pill, findsOneWidget,
        reason: 'scrolled away from the newest message, so the pill is up');
    final composer = t.getRect(find.byType(ChatComposerLiquid));
    expect(t.getRect(pill).bottom, lessThanOrEqualTo(composer.top),
        reason: 'the pill floats over the same stack the composer does');
  });
}
