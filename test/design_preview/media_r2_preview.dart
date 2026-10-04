// Round-2 §J/§K3 after-state: the chat gallery pager (date subtitle, bottom
// toolbar, 40pt filmstrip), the room-info media grid (month sections, edge to
// edge, selection bottom-right), and the group call header + "More" sheet.
//
//   flutter test test/design_preview/media_r2_preview.dart
//
// Not a test. PNGs land in build/design_preview/r2_*.png.
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/group_call_screen.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/screen_share.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_bookmark.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/models/room_content_item.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/screens/room_content_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/widgets/segmented_control.dart';

import '../fakes/fake_webrtc.dart';
import 'preview_kit.dart';

// ---------------------------------------------------------------- fakes

final _now = DateTime.now();

ChatMessage _m(
  String id, {
  MessageType type = MessageType.image,
  int? dur,
  String sender = 'u1',
  DateTime? at,
}) =>
    ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: sender,
      senderName: sender == 'me' ? '' : 'Ece Yıldız',
      content: '',
      createdAt: at ?? DateTime(_now.year, _now.month, _now.day, 14, 32),
      type: type,
      mediaStorageId: 'stor_$id',
      mediaWidth: 1200,
      mediaHeight: 1600,
      mediaDurationMs: dur,
    );

/// Three months of a room's media, newest first: this month, last month, and
/// one further back — with a few videos and a few of the reader's own.
List<ChatMessage> _roomMedia() {
  final out = <ChatMessage>[];
  void month(int back, int n, String tag) {
    for (var i = 0; i < n; i++) {
      final video = i % 5 == 2;
      out.add(_m(
        '$tag$i',
        type: video ? MessageType.video : MessageType.image,
        dur: video ? 42000 + i * 9000 : null,
        sender: i % 3 == 0 ? 'me' : 'u1',
        at: DateTime(_now.year, _now.month - back, 3, 12, 59 - i),
      ));
    }
  }

  month(0, 8, 'a');
  month(1, 11, 'b');
  month(3, 7, 'c');
  return out;
}

class _ChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;

  @override
  Future<RoomContentPage> listRoomContent({
    required String roomId,
    required String userId,
    required String bucket,
    DateTime? before,
    int limit = 30,
  }) async =>
      RoomContentPage(
        items: bucket == 'media' ? _roomMedia() : const [],
        hasMore: false,
      );

  @override
  Future<Map<String, RoomContentCount>> roomContentCounts({
    required String roomId,
    required String userId,
  }) async =>
      const {};
}

class _Repo extends Fake implements ChatRepository {
  @override
  String? get userId => 'me';

  @override
  List<MessageBookmark> savedFor(String roomId) => const [];

  @override
  List<ChatMessage> messagesFor(String roomId) => const [];

  @override
  ChatRoom? roomById(String id) => ChatRoom(
        id: id,
        name: 'Weekend crew',
        createdBy: 'u0',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 4,
        participantIds: const ['me', 'u1'],
      );

  @override
  RoomCapabilities capabilitiesFor(ChatRoom room) => RoomCapabilities.group;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeGroupApi extends Fake implements GroupCallApi {
  void Function(Map<String, dynamic>? roster)? roster;

  @override
  Future<({String type, String roomId})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async =>
      (type: 'audio', roomId: 'room1');
  @override
  Future<void> leave({required String groupCallId, required String userId}) async {}
  @override
  Future<String?> heartbeat({required String groupCallId, required String userId}) async => 'ok';
  @override
  Future<void> sendSignal({
    required String groupCallId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {}
  @override
  Future<void> consumeSignals({required List<String> signalIds, required String userId}) async {}
  @override
  Future<Subscription> subscribeSignals({
    required String userId,
    String? deviceId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async =>
      _FakeSub();
  @override
  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) async {
    roster = onRoster;
    return _FakeSub();
  }

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async =>
      _FakeSub();

  @override
  Future<Subscription> subscribeActiveForRoom({
    required String roomId,
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSub();
}

Future<GroupCallService> _groupVoiceCall(
  WidgetTester tester, {
  bool alone = false,
}) async {
  final api = _FakeGroupApi();
  final svc = GroupCallService(api: api)
    ..leaveNotifyTimeout = const Duration(milliseconds: 20)
    ..nativeCardsEnabled = false;
  svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-a');
  svc.createPcFn = (config, constraints) async => FakePeerConnection();
  svc.ensurePermissionsFn = (_) async => true;
  svc.getVideoTrackFn = (_) async => FakeMediaStreamTrack(kind: 'video', id: 'cam-a');
  svc.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
  svc.preferCodecFn = (_) async {};
  svc.attach(userId: 'a', deviceId: 'dev-a');
  await tester.runAsync(() async {
    await svc.joinCall('gc1');
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    api.roster!({
      'groupCallId': 'gc1',
      'status': 'active',
      'roomName': 'Weekend crew',
      'participants': [
        {'userId': 'a', 'status': 'joined', 'name': 'A'},
        if (!alone) ...[
          {'userId': 'b', 'status': 'joined', 'name': 'Bea Yılmaz'},
          {'userId': 'c', 'status': 'joined', 'name': 'Cem Öztürk'},
          {'userId': 'd', 'status': 'invited', 'name': 'Dua'},
        ],
      ],
    });
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  return svc;
}

// ---------------------------------------------------------------- scenes

MediaPagerActions _actions() => MediaPagerActions(
      currentUserId: 'me',
      onShare: (_) async => true,
      onSave: (_) async => true,
      onForward: (_, _) async => 1,
      onDelete: (_) async => true,
    );

Widget _pager({bool mine = false, bool video = false}) => MediaPagerScreen(
      items: [
        for (var i = 0; i < 8; i++)
          _m(
            'p$i',
            sender: mine ? 'me' : 'u1',
            type: video && i == 2 ? MessageType.video : MessageType.image,
            dur: video && i == 2 ? 83000 : null,
          ),
      ],
      initialIndex: 2,
      api: _ChatApi(),
      onShowInChat: (_) {},
      actions: _actions(),
    );

Widget _roomScreen() => RoomContentScreen(
      roomId: 'r1',
      repo: _Repo(),
      api: _ChatApi(),
    );

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    GroupCallScreen.rendererFactory = FakeVideoRenderer.new;
    ScreenShare.invokeFn = (m, [a]) async => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      prev?.call(details);
    };
    addTearDown(() => FlutterError.onError = prev);
  });

  // (theme id, locale, text scale, file suffix)
  final variants = [
    ('basic', const Locale('en'), 1.0, 'basic'),
    ('basic_daylight', const Locale('en'), 1.0, 'basic_daylight'),
    ('risograph_pop', const Locale('en'), 1.0, 'risograph_pop'),
    ('basic', const Locale('tr'), 1.3, 'tr13'),
  ];

  for (final (id, locale, scale, suffix) in variants) {
    Future<void> shot(WidgetTester tester, Widget w, String name,
        {Future<void> Function()? act}) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await snap(
        tester,
        previewApp(ThemeController.byId(id), w, locale: locale),
        name,
        act: act,
      );
    }

    testWidgets('r2 pager $suffix', (tester) async {
      await shot(tester, _pager(), 'r2_pager_$suffix.png');
    });
    testWidgets('r2 segments badge $suffix', (tester) async {
      // The room-content tabs with the Saved dot lit, on their own: the
      // grid shot above has no unseen saves to light it.
      await shot(
        tester,
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: IosSegmentedControl<int>(
                    value: 0,
                    onChanged: (_) {},
                    segments: [
                      IosSegment(value: 0, label: l10n.roomContentTabLabelMedia),
                      IosSegment(value: 1, label: l10n.roomContentTabLabelFiles),
                      IosSegment(value: 2, label: l10n.roomContentTabLabelVoice),
                      IosSegment(value: 3, label: l10n.roomContentTabLabelLinks),
                      IosSegment(
                        value: 4,
                        label: l10n.roomContentTabLabelSaved,
                        badge: true,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        'r2_segments_badge_$suffix.png',
      );
    });
    testWidgets('r2 room media grid $suffix', (tester) async {
      await shot(tester, _roomScreen(), 'r2_roommedia_grid_$suffix.png');
    });
    testWidgets('r2 room media selecting $suffix', (tester) async {
      await shot(
        tester,
        _roomScreen(),
        'r2_roommedia_selecting_$suffix.png',
        act: () async {
          // The bar's "Select", then a few tiles.
          final select = find.text(suffix == 'tr13' ? 'Seç' : 'Select');
          if (select.evaluate().isNotEmpty) await tester.tap(select);
          await tester.pump(const Duration(milliseconds: 50));
          final tiles = find.byKey(const ValueKey('a1'));
          if (tiles.evaluate().isNotEmpty) await tester.tap(tiles);
          final t2 = find.byKey(const ValueKey('a2'));
          if (t2.evaluate().isNotEmpty) await tester.tap(t2);
          await tester.pump();
        },
      );
    });
  }

  testWidgets('r2 pager mine basic', (tester) async {
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), _pager(mine: true)),
      'r2_pager_mine_basic.png',
    );
  });
  testWidgets('r2 pager video basic', (tester) async {
    // Pushed for real (in `act`, so the capture waits out the flight), so the
    // route lands and the play disc and the duration badge come in the way
    // they do in the app.
    final pager = _pager(video: true) as MediaPagerScreen;
    final anchor = GlobalKey();
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), SizedBox.expand(key: anchor)),
      'r2_pager_video_basic.png',
      act: () async {
        MediaPagerScreen.open(
          anchor.currentContext!,
          items: pager.items,
          initialIndex: pager.initialIndex,
          api: pager.api,
          onShowInChat: pager.onShowInChat,
          actions: pager.actions,
        );
        await tester.pump();
      },
    );
  });
  testWidgets('r2 pager chrome hidden basic', (tester) async {
    // Tap to hide, then the glass must not be fading on screen: the capture
    // shows the empty picture.
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), _pager()),
      'r2_pager_hidden_basic.png',
      act: () async {
        await tester.tapAt(const Offset(200, 420));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });

  for (final (alone, name) in [(false, 'r2_groupcall_voice_basic'), (true, 'r2_groupcall_alone_basic')]) {
    testWidgets(name, (tester) async {
      final svc = await _groupVoiceCall(tester, alone: alone);
      await snap(
        tester,
        previewApp(ThemeController.byId('basic'), GroupCallScreen(service: svc)),
        '$name.png',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(svc.leaveCall);
    });
  }
  testWidgets('r2 group call more sheet basic', (tester) async {
    final svc = await _groupVoiceCall(tester);
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), GroupCallScreen(service: svc)),
      'r2_groupcall_more_basic.png',
      act: () async {
        await tester.tap(find.byIcon(CupertinoIcons.ellipsis).first,
            warnIfMissed: false);
        await tester.pump();
      },
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });
  testWidgets('r2 group call tr13', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final svc = await _groupVoiceCall(tester);
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), GroupCallScreen(service: svc),
          locale: const Locale('tr')),
      'r2_groupcall_voice_tr13.png',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });
}
