// Design review renders for the call surfaces: the in-call sheets, the two
// ringers, the 1:1 and group call screens, and the pills/banners that stand
// for a call behind whatever is on screen.
//
//   flutter test test/design_preview/calls_review_preview.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/active_call_pill.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_options_sheet.dart';
import 'package:monkeyhub/calls/call_screen.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';
import 'package:monkeyhub/calls/draw/draw_model.dart';
import 'package:monkeyhub/calls/group_call_banner.dart';
import 'package:monkeyhub/calls/group_call_screen.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/group_call_sheets.dart';
import 'package:monkeyhub/calls/in_call_pill.dart';
import 'package:monkeyhub/calls/incoming_call_screen.dart';
import 'package:monkeyhub/calls/incoming_group_call_screen.dart';
import 'package:monkeyhub/calls/screen_share.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../fakes/fake_webrtc.dart';
import 'preview_kit.dart';

// ---------------------------------------------------------------- fakes

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeGroupApi extends Fake implements GroupCallApi {
  void Function(List<Map<String, dynamic>> signals)? onSignals;
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
  }) async {
    this.onSignals = onSignals;
    return _FakeSub();
  }

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
  }) {
    onCall({
      'groupCallId': 'gc9',
      'type': 'video',
      'participants': [
        {'userId': 'b', 'status': 'joined', 'name': 'Bea Yılmaz', 'live': true},
        {'userId': 'c', 'status': 'joined', 'name': 'Cem Öztürk', 'live': true},
        {'userId': 'd', 'status': 'joined', 'name': 'Dua', 'live': true},
      ],
    });
    return Completer<Subscription>().future;
  }
}

class _FakeApi extends Fake implements ChatApi {
  @override
  Future<List<ChatUser>> getMembers(String roomId, {String? viewerUserId}) async => [
        for (final (id, n) in const [
          ('me', 'Me'),
          ('b', 'Bea Yılmaz'),
          ('c', 'Cem Öztürk'),
          ('d', 'Dua Karaosmanoğlu-Wilhelmina'),
          ('e', 'Ece'),
          ('f', 'Ferhat'),
        ])
          ChatUser(id: id, username: id, name: n),
      ];
}

/// Just enough of a CallService to draw the call screen and the pills.
class _FakeCall extends ChangeNotifier implements CallService {
  _FakeCall(this._session, {this.elsewhere, this.sharing = false});
  final CallSession? _session;
  final Map<String, dynamic>? elsewhere;
  final bool sharing;

  @override
  CallSession? get session => _session;
  @override
  Map<String, dynamic>? get activeCallElsewhere => elsewhere;
  @override
  bool get inCall => _session != null;
  @override
  bool get localCamActive => false;
  @override
  bool get hasAnyVideo => false;
  @override
  MediaStream? get localStream => null;
  @override
  MediaStream? get remoteStream => null;
  @override
  MediaStream? get remoteScreenStream => null;
  @override
  MediaStream? get screenStream => null;
  @override
  int get localStreamTick => 0;
  @override
  int get remoteStreamTick => 0;
  @override
  int get remoteScreenStreamTick => 0;
  @override
  int localScreenStreamTick = 0;
  @override
  bool get localScreenSharing => sharing;
  @override
  bool get screenSharePending => false;
  @override
  final ValueNotifier<bool> drawArmed = ValueNotifier(false);
  @override
  final ValueNotifier<int> reopenTick = ValueNotifier(0);
  @override
  final ValueNotifier<CallQualitySnapshot?> callQuality = ValueNotifier(null);
  @override
  final DrawModel drawModel = DrawModel();
  @override
  String? get userId => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CallSession _session({
  required CallStatus status,
  CallMediaKind kind = CallMediaKind.audio,
  String name = 'Ece Yıldız',
  bool peerMuted = false,
}) =>
    CallSession(
      callId: 'c1',
      roomId: 'r1',
      peerUserId: 'u_ece',
      peerName: name,
      mediaKind: kind,
      isCaller: false,
      status: status,
      peerState: PeerMediaState(audioMuted: peerMuted),
      speakerOn: false,
      startedAt: DateTime.now().subtract(const Duration(minutes: 4, seconds: 12)),
      connectedAt: DateTime.now().subtract(const Duration(minutes: 4, seconds: 12)),
    );

// ---------------------------------------------------------------- hosts

/// A page with something on it, so a sheet's dim and edge read; opens the
/// sheet a frame after it mounts.
class _Page extends StatefulWidget {
  const _Page({this.open, this.top});
  final void Function(BuildContext context)? open;
  final Widget? top;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Column(
        children: [
          ?widget.top,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              children: [
                Text('Chats', style: theme.displayLarge),
                for (var i = 0; i < 9; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      CircleAvatar(radius: 26, backgroundColor: theme.surfaceRaised),
                      const SizedBox(width: 14),
                      Expanded(child: Text('Conversation $i', style: theme.bodyEmph)),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _themes = ['basic', 'basic_daylight', 'risograph_pop'];

/// Opens the page's sheet from inside snap's `act`, so the capture is taken
/// after the rise has finished rather than on its first frame.
Future<void> Function() _opener(WidgetTester tester) => () async {
      final st = tester.state<_PageState>(find.byType(_Page));
      st.widget.open!(st.context);
      await tester.pump();
    };

Future<GroupCallService> _groupVoiceCall(WidgetTester tester) async {
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
        {'userId': 'b', 'status': 'joined', 'name': 'Bea Yılmaz'},
        {'userId': 'c', 'status': 'joined', 'name': 'Cem Öztürk'},
        {'userId': 'd', 'status': 'invited', 'name': 'Dua'},
      ],
    });
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  return svc;
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    CallScreen.rendererFactory = FakeVideoRenderer.new;
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

  final locales = {'en': const Locale('en'), 'tr': const Locale('tr')};

  // ------------------------------------------------------------ sheets
  for (final id in _themes) {
    for (final lc in ['en', 'tr']) {
      testWidgets('calls: options sheet $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            _Page(
              open: (c) => showAdaptiveSheet<void>(
                c,
                builder: (_) => CallOptionsSheet(
                  service: _FakeCall(null),
                  showVideoQuality: true,
                ),
              ),
            ),
            locale: locales[lc]!,
          ),
          'calls_options_${id}_$lc.png',
          act: _opener(tester),
        );
      });
      testWidgets('calls: start group sheet $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            _Page(
              open: (c) => showStartGroupCallSheet(
                c,
                service: GroupCallService(api: _FakeGroupApi()),
                api: _FakeApi(),
                roomId: 'r1',
                myUserId: 'me',
              ),
            ),
            locale: locales[lc]!,
          ),
          'calls_start_group_${id}_$lc.png',
          act: _opener(tester),
        );
      });
    }
    testWidgets('calls: member picker $id', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          _Page(
            open: (c) => showStartGroupCallSheet(
              c,
              service: GroupCallService(api: _FakeGroupApi()),
              api: _FakeApi(),
              roomId: 'r1',
              myUserId: 'me',
            ),
          ),
        ),
        'calls_pick_members_$id.png',
        act: () async {
          await _opener(tester)();
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.tap(find.text('Choose people'), warnIfMissed: false);
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (find.text('Bea Yılmaz').evaluate().isNotEmpty) {
            await tester.tap(find.text('Bea Yılmaz'));
            await tester.tap(find.text('Ece'));
          }
        },
      );
    });
  }

  // ------------------------------------------------------------ ringers
  for (final id in _themes) {
    for (final lc in ['en', 'tr']) {
      testWidgets('calls: incoming 1:1 $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            IncomingCallScreen(
              service: _FakeCall(_session(
                status: CallStatus.incomingRinging,
                kind: lc == 'en' ? CallMediaKind.audio : CallMediaKind.video,
              )),
            ),
            locale: locales[lc]!,
          ),
          'calls_incoming_${id}_$lc.png',
        );
      });
      testWidgets('calls: incoming group $id $lc', (tester) async {
        final svc = GroupCallService(api: _FakeGroupApi())
          ..pendingInvite = {
            'groupCallId': 'gc1',
            'roomName': 'Weekend crew',
            'starterName': 'Bea Yılmaz',
            'starterUserId': 'b',
            'type': 'video',
            'joinedCount': 3,
          };
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            IncomingGroupCallScreen(service: svc),
            locale: locales[lc]!,
          ),
          'calls_incoming_group_${id}_$lc.png',
        );
      });
    }
  }

  // ------------------------------------------------------------ call screens
  for (final id in _themes) {
    for (final lc in ['en', 'tr']) {
      testWidgets('calls: 1:1 voice call $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            CallScreen(
              service: _FakeCall(
                _session(status: CallStatus.active, peerMuted: true),
              ),
            ),
            locale: locales[lc]!,
          ),
          'calls_voice_${id}_$lc.png',
        );
      });
    }
    testWidgets('calls: group voice call $id', (tester) async {
      final svc = await _groupVoiceCall(tester);
      await snap(
        tester,
        previewApp(ThemeController.byId(id), GroupCallScreen(service: svc)),
        'calls_group_voice_$id.png',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(svc.leaveCall);
    });
  }
  testWidgets('calls: group voice call tr', (tester) async {
    final svc = await _groupVoiceCall(tester);
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), GroupCallScreen(service: svc),
          locale: const Locale('tr')),
      'calls_group_voice_basic_tr.png',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });

  // ------------------------------------------------------------ pills
  for (final id in _themes) {
    for (final lc in ['en', 'tr']) {
      testWidgets('calls: pills $id $lc', (tester) async {
        final call = _FakeCall(
          _session(status: CallStatus.active),
          sharing: true,
        );
        final elsewhere = _FakeCall(null, elsewhere: {
          '_id': 'x',
          'peerName': 'Ece Yıldız',
          'acceptingPlatform': 'macos',
          'type': 'video',
        });
        final group = GroupCallService(api: _FakeGroupApi());
        await snap(
          tester,
          previewApp(
            ThemeController.byId(id),
            _Page(
              top: Column(
                children: [
                  InCallPill(
                    call: call,
                    group: group,
                    callScreenUp: ValueNotifier(false),
                  ),
                  ActiveCallPill(service: elsewhere),
                  GroupCallBanner(
                    api: _FakeGroupApi(),
                    service: group,
                    roomId: 'r1',
                    userId: 'me',
                  ),
                ],
              ),
            ),
            locale: locales[lc]!,
          ),
          'calls_pills_${id}_$lc.png',
        );
      });
    }
  }

  // Larger text: the tray labels and the ringer.
  testWidgets('calls: voice call text 1.3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await snap(
      tester,
      previewApp(
        ThemeController.byId('basic'),
        CallScreen(service: _FakeCall(_session(status: CallStatus.active))),
        locale: const Locale('tr'),
      ),
      'calls_voice_basic_tr_x13.png',
    );
  });
  testWidgets('calls: incoming text 1.3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await snap(
      tester,
      previewApp(
        ThemeController.byId('basic'),
        IncomingCallScreen(
          service: _FakeCall(_session(
            status: CallStatus.incomingRinging,
            name: 'Dua Karaosmanoğlu-Wilhelmina',
          )),
        ),
        locale: const Locale('tr'),
      ),
      'calls_incoming_basic_tr_x13.png',
    );
  });
}
