import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/huddle_outcome.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/privacy/capture_protection.dart';
import 'package:monkeyhub/screens/room_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_stamp.dart' show StampSpacer;
import 'package:monkeyhub/widgets/progress_ring.dart';

/// Vanish mode inside an open room: the capture scope, the one subscription,
/// what `markRoomRead` claims, the sealed bubble on a platform that cannot
/// block screenshots, the hidden-seen card and the ring.
///
/// The harness is `room_unread_divider_widget_test.dart`'s: a real RoomScreen
/// over a real repository, with a fake socket the test feeds by hand.

class _FakeSub extends Fake implements Subscription {
  _FakeSub(this.name, this.onCancel);
  final String name;
  final void Function() onCancel;
  @override
  void cancel() => onCancel();
}

class _FakeCv extends Fake implements ConvexBackend {
  final Map<String, void Function(dynamic)> sinks = {};
  final Map<String, int> opened = {};
  final Map<String, int> live = {};
  @override
  Future<Subscription> subscribe(String name, Map<String, dynamic> args,
      {required void Function(dynamic) onData,
      void Function(Object error)? onError}) async {
    sinks[name] = onData;
    opened[name] = (opened[name] ?? 0) + 1;
    live[name] = (live[name] ?? 0) + 1;
    return _FakeSub(name, () => live[name] = (live[name] ?? 1) - 1);
  }

  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _Api extends Fake implements ChatApi {
  final List<DateTime?> plainReads = [];
  final List<({bool counts, DateTime? upTo})> vanishReads = [];
  final List<bool> shares = [];
  @override
  Future<List<ChatRoom>> listUserRooms(String u) async => throw StateError('offline');
  @override
  Future<List<ChatUser>> listFriends(String u) async => throw StateError('offline');
  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String u) async => throw StateError('offline');
  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String u) async => throw StateError('offline');
  @override
  Future<List<ChatMessage>> listMessages({required String roomId, int limit = 100, String? viewerUserId}) async =>
      throw StateError('offline');
  @override
  Future<void> markRoomRead({required String roomId, required String userId, DateTime? upTo}) async {
    plainReads.add(upTo);
  }

  @override
  Future<void> markVanishRoomRead({
    required String roomId,
    required String userId,
    required bool vanishCounts,
    DateTime? upTo,
  }) async {
    vanishReads.add((counts: vanishCounts, upTo: upTo));
  }

  @override
  Future<void> setVanishShareReads(String roomId, bool share) async {
    shares.add(share);
  }

  @override
  Future<void> clearTyping({required String roomId, required String userId}) async {}
  @override
  Future<void> markRoomDelivered({required String roomId, required String userId, DateTime? upTo}) async {}
}

final t0 = DateTime.fromMillisecondsSinceEpoch(
    DateTime(2026, 11, 6, 12, 0).millisecondsSinceEpoch);

Map<String, dynamic> roomWire({bool vanish = false}) => {
      '_id': 'r1',
      'name': 'The Room',
      'createdBy': 'someone',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': false,
      'memberCount': 3,
      'participantIds': ['me', 'someone', 'else'],
      'isMember': true,
      'lastReadAt': t0.millisecondsSinceEpoch,
      'lastMessageTime': t0.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
      'unreadCount': 0,
      if (vanish) 'vanishMode': true,
      if (vanish) 'vanishAfterSeen': 10,
    };

Map<String, dynamic> msgWire(String id, String sender, DateTime at,
        {bool vanishing = false, String type = 'text', String? content}) =>
    {
      '_id': id,
      'roomId': 'r1',
      'userId': sender,
      'content': content ?? 'msg $id',
      'type': type,
      'createdAt': at.millisecondsSinceEpoch,
      if (vanishing)
        'vanishUntil': at.add(const Duration(hours: 24)).millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _Api api;
  late ChatRepository repo;

  Widget host() => MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: RoomScreen(roomId: 'r1', repo: repo, api: ChatApi(ConvexBackend.instance)),
          ),
        ),
      );

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump();
  }

  Future<void> open(WidgetTester t, {bool vanish = true, List<Map<String, dynamic>>? messages}) async {
    await t.pumpWidget(host());
    await settle(t);
    cv.sinks['rooms:listUserRooms']!([roomWire(vanish: vanish)]);
    await settle(t);
    await settle(t);
    cv.sinks['messages:list']!(messages ?? [msgWire('m0', 'someone', t0)]);
    await settle(t);
    await t.pump(const Duration(milliseconds: 300));
  }

  /// Leaves the room and lets the repository's own debounce timers run out.
  Future<void> leave(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  }

  void prefs({String seen = 'friends', bool global = false, bool? perChat}) {
    cv.sinks['vanish:myVanishPrefs']!({
      'seen': seen,
      'global': global,
      'perChat': perChat,
      'counts': perChat == true || global || seen != 'nobody',
    });
  }

  setUp(() async {
    cv = _FakeCv();
    api = _Api();
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
    CaptureProtection.debugPlatformProtectsOverride = null;
  });

  tearDown(() {
    CaptureProtection.debugPlatformProtectsOverride = null;
  });

  testWidgets('an open vanish room pushes a capture scope and pops it on leaving',
      (t) async {
    expect(CaptureProtection.instance.scopeActive, isFalse);
    await open(t);
    expect(CaptureProtection.instance.scopeActive, isTrue);
    await leave(t);
    expect(CaptureProtection.instance.scopeActive, isFalse);
  });

  testWidgets('an empty huddle leaves a local-only line that never moves the read cursor',
      (t) async {
    final at = DateTime.now().add(const Duration(minutes: 5));
    LocalHuddleNotes.instance.addAlone(
        roomId: 'r1', groupCallId: 'gc-alone', userId: 'me', at: at);
    await open(t, vanish: false);
    expect(find.text('You wanted to talk · Nobody joined'), findsOneWidget);
    // Reads come from the server's list only: none may claim the local row's
    // later time.
    expect(api.plainReads.where((r) => r != null && !r.isBefore(at)), isEmpty);
    await leave(t);
  });

  testWidgets('an ordinary room has no scope, no vanish subscription, plain reads',
      (t) async {
    await open(t, vanish: false);
    expect(CaptureProtection.instance.scopeActive, isFalse);
    expect(cv.opened['vanish:stateForRoom'], isNull);
    expect(cv.opened['vanish:myVanishPrefs'], isNull);
    expect(api.plainReads, isNotEmpty);
    expect(api.vanishReads, isEmpty);
    expect(find.text('vanish on'), findsNothing);
    await leave(t);
  });

  testWidgets('ONE stateForRoom subscription for the open room', (t) async {
    await open(t);
    expect(cv.opened['vanish:stateForRoom'], 1);
    // Rebuilds from new messages and state never open another.
    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', t0.add(const Duration(minutes: 1)), vanishing: true),
    ]);
    cv.sinks['vanish:stateForRoom']!({
      'active': true,
      'afterSeen': 10,
      'burnAt': null,
      'burnUpTo': null,
      'mineUpTo': null,
    });
    await settle(t);
    expect(cv.opened['vanish:stateForRoom'], 1);
    expect(cv.opened['vanish:myVanishPrefs'], 1);
    await leave(t);
    expect(cv.live['vanish:stateForRoom'], 0, reason: 'closing the room cancels it');
  });

  testWidgets('theming: header says vanish on, field says keep it short',
      (t) async {
    await open(t);
    expect(find.text('vanish on'), findsOneWidget);
    expect(find.text('Vanishing message · keep it short'), findsOneWidget);
    await leave(t);
  });

  testWidgets('a read counts when seen is shared, not when it is hidden',
      (t) async {
    await open(t);
    prefs(seen: 'friends');
    await settle(t);
    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', t0.add(const Duration(minutes: 1)), vanishing: true),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    expect(api.vanishReads, isNotEmpty);
    expect(api.vanishReads.last.counts, isTrue);
    expect(api.plainReads, isEmpty);
    await leave(t);
  });

  testWidgets('hidden seen: reads are sent but do not count', (t) async {
    await open(t);
    prefs(seen: 'nobody');
    await settle(t);
    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', t0.add(const Duration(minutes: 1)), vanishing: true),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    expect(api.vanishReads, isNotEmpty);
    expect(api.vanishReads.every((r) => !r.counts), isTrue);
    await leave(t);
  });

  testWidgets('web override: sealed bubble, read never counts or passes it',
      (t) async {
    CaptureProtection.debugPlatformProtectsOverride = false;
    final sealedAt = t0.add(const Duration(minutes: 1));
    await open(t, messages: [
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', sealedAt, vanishing: true, content: 'secret words'),
      msgWire('m2', 'someone', t0.add(const Duration(minutes: 2))),
    ]);
    prefs(seen: 'public');
    await settle(t);
    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', sealedAt, vanishing: true, content: 'secret words'),
      msgWire('m2', 'someone', t0.add(const Duration(minutes: 2))),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    expect(find.textContaining('secret words', findRichText: true), findsNothing,
        reason: 'the words are never drawn where a screenshot cannot be blocked');
    expect(find.text('Opens in the app'), findsOneWidget);
    expect(find.textContaining('msg m0', findRichText: true), findsOneWidget,
        reason: 'older ordinary messages still read');
    final reads = [...api.vanishReads, ...api.plainReads.map((u) => (counts: false, upTo: u))];
    expect(reads, isNotEmpty);
    for (final r in reads) {
      expect(r.counts, isFalse);
      expect(r.upTo!.isBefore(sealedAt), isTrue,
          reason: 'the cursor stops before the oldest sealed message');
    }
    await leave(t);
  });

  testWidgets('the hidden-seen card shows, answers, and turns into a note',
      (t) async {
    await open(t);
    prefs(seen: 'nobody');
    await settle(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Share my reads here'), findsOneWidget);
    expect(find.text("Don't share here"), findsOneWidget);
    expect(find.textContaining('last 24 hours'), findsOneWidget);
    expect(find.text('You can change this anytime in Settings › Privacy.'),
        findsOneWidget);

    await t.tap(find.text('Share my reads here'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(api.shares, [true]);
    expect(find.text('Share my reads here'), findsNothing);
    expect(find.textContaining('You can change this anytime in Settings › Privacy.'),
        findsOneWidget);
    await leave(t);
  });

  testWidgets('the card stays away once an answer exists or reads are shared',
      (t) async {
    await open(t);
    prefs(seen: 'nobody', perChat: false);
    await settle(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Share my reads here'), findsNothing);
    prefs(seen: 'nobody', global: true);
    await settle(t);
    expect(find.text('Share my reads here'), findsNothing);
    await leave(t);
  });

  testWidgets('Dont share here answers no', (t) async {
    await open(t);
    prefs(seen: 'nobody');
    await settle(t);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text("Don't share here"));
    await t.pump();
    expect(api.shares, [false]);
    await leave(t);
  });

  testWidgets('ring for a counted message, 24h clock for the rest, no Seen tick',
      (t) async {
    final m1 = t0.add(const Duration(minutes: 1));
    final m2 = t0.add(const Duration(minutes: 3));
    await open(t, messages: [
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', m1, vanishing: true),
      msgWire('m2', 'someone', m2, vanishing: true),
    ]);
    prefs(seen: 'friends');
    cv.sinks['vanish:stateForRoom']!({
      'active': true,
      'afterSeen': 10,
      'burnAt': DateTime.now().add(const Duration(seconds: 7)).millisecondsSinceEpoch,
      'burnUpTo': m1.millisecondsSinceEpoch,
      'mineUpTo': null,
    });
    await settle(t);
    await t.pump(const Duration(milliseconds: 200));
    // Each stamp has an invisible twin that reserves its room (StampSpacer),
    // with its tickers off; only the visible ones count.
    Finder visible(Finder f) => find.descendant(
          of: find.byWidgetPredicate((w) => true),
          matching: f,
        );
    int count(Finder f) =>
        f.evaluate().where((e) {
          var twin = false;
          e.visitAncestorElements((a) {
            if (a.widget is StampSpacer) {
              twin = true;
              return false;
            }
            return true;
          });
          return !twin;
        }).length;
    expect(visible(find.byType(ProgressRing)), findsWidgets);
    expect(count(find.byType(ProgressRing)), 1,
        reason: 'only the message at or below burnUpTo has a ring');
    expect(count(find.text('24h')), 1,
        reason: 'the one past burnUpTo waits on the 24 hour clock');
    await leave(t);
  });
}
