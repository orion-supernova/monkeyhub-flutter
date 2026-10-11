import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';
import 'package:monkeyhub/calls/draw/draw_canvas.dart';
import 'package:monkeyhub/calls/group_call_screen.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/screen_share.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_webrtc.dart';

/// A voice call looks like a voice call.
///
/// The group screen used to have one layout — the video grid — and a voice
/// call was that grid with every tile empty, your own tile blankest of all.
/// These pin the three layouts and the switches between them: faces in a
/// voice call (the ones still ringing dimmed beside them), the grid the
/// moment a camera comes on, faces again when it goes off, and the stage
/// with the drawing layer when a screen is shared.
class _FakeSubscription extends Fake implements Subscription {
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
  Future<void> leave({
    required String groupCallId,
    required String userId,
  }) async {}

  @override
  Future<String?> heartbeat({
    required String groupCallId,
    required String userId,
  }) async =>
      'ok';

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
  Future<void> consumeSignals({
    required List<String> signalIds,
    required String userId,
  }) async {}

  @override
  Future<Subscription> subscribeSignals({
    required String userId,
    String? deviceId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async {
    this.onSignals = onSignals;
    return _FakeSubscription();
  }

  @override
  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) async {
    roster = onRoster;
    return _FakeSubscription();
  }

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

int _sig = 0;

/// Real-time breathing room for the service's chained awaits; generous,
/// because a loaded test runner stretches them and the assertions that
/// follow read state the awaits produce.
Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void _deliver(_FakeGroupApi api, String from, String kind,
    Map<String, dynamic> payload) {
  api.onSignals!([
    {
      '_id': 's${_sig++}',
      'kind': kind,
      'fromUserId': from,
      'groupCallId': 'gc1',
      'payload': jsonEncode(payload),
    },
  ]);
}

/// A layout switch is a cross-fade: one frame to take the new stage, the
/// fade itself, and one more for the outgoing stage to leave the tree.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Widget _host(GroupCallService svc) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GroupCallScreen(service: svc),
      ),
    );

/// `a` on a voice call with `b` and `c` joined and `d` still ringing —
/// built with real async, since the service's link setup waits on the
/// plugin's missing channels.
Future<(GroupCallService, _FakeGroupApi, FakePeerConnection)> _call(
  WidgetTester tester,
) async {
  final api = _FakeGroupApi();
  final pcs = <FakePeerConnection>[];
  final svc = GroupCallService(api: api)
    ..leaveNotifyTimeout = const Duration(milliseconds: 20)
    ..nativeCardsEnabled = false;
  svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-a');
  svc.createPcFn = (config, constraints) async {
    final pc = FakePeerConnection();
    pcs.add(pc);
    return pc;
  };
  svc.ensurePermissionsFn = (_) async => true;
  svc.getVideoTrackFn = (_) async =>
      FakeMediaStreamTrack(kind: 'video', id: 'cam-a');
  svc.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
  svc.preferCodecFn = (_) async {};
  svc.attach(userId: 'a', deviceId: 'dev-a');
  await tester.runAsync(() async {
    await svc.joinCall('gc1');
    await _pump();
    api.roster!({
      'groupCallId': 'gc1',
      'status': 'active',
      'roomName': 'crew',
      'participants': [
        {'userId': 'a', 'status': 'joined', 'name': 'A'},
        {'userId': 'b', 'status': 'joined', 'name': 'Bea'},
        {'userId': 'c', 'status': 'joined', 'name': 'Cem'},
        {'userId': 'd', 'status': 'invited', 'name': 'Dua'},
      ],
    });
    await _pump();
  });
  expect(pcs, hasLength(2));
  return (svc, api, pcs.first);
}

void main() {
  setUp(() {
    GroupCallScreen.rendererFactory = FakeVideoRenderer.new;
    ScreenShare.invokeFn = (m, [a]) async => null;
    // The mic belt `leaveCall` runs reaches the plugin's log channel, which
    // has no implementation under test; the belt catches its own failure,
    // but the channel's activation error is reported to FlutterError, where
    // a widget test would count it. It is not what these tests are about.
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      prev?.call(details);
    };
    addTearDown(() => FlutterError.onError = prev);
    // The same plugin's event stream, answered rather than filtered: the
    // handler above is replaced by each `testWidgets` before its body runs,
    // so a `listen` that lost the race landed in whichever test was running
    // — under a parallel run, reliably the roster test.
    const events = EventChannel('FlutterWebRTC.Event');
    final messenger =
        TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() => messenger.setMockStreamHandler(events, null));
  });

  testWidgets('the system bars go only once the slide has finished, as on '
      'the 1:1 screen', (tester) async {
    final hides = <int>[];
    var frame = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          hides.add(frame);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (svc, _, _) = await _call(tester);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        navigatorKey: nav,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox(),
      ),
    ));
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => GroupCallScreen(service: svc),
    );
    nav.currentState!.push(route);
    for (frame = 1; frame <= 3; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Mid-slide: hiding the bars here relaid out every screen in the app on
    // the frames the slide most needed.
    expect(route.animation!.isCompleted, isFalse);
    expect(hides, isEmpty);
    await _settle(tester);
    expect(hides, isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });

  testWidgets('a voice call is faces, not empty tiles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (svc, _, _) = await _call(tester);
    await tester.pumpWidget(_host(svc));
    await _settle(tester);

    // Me, Bea, Cem, and Dua still ringing.
    expect(find.byType(ParticipantOrb), findsNWidgets(4));
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Ringing…'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(RTCVideoView), findsNothing);
    // The camera is offered in a voice call — that is how it becomes a video
    // call — and every control is genuinely tappable (FocusableTap adds no
    // recognizer; the GestureDetector inside is what does).
    expect(find.text('Camera on'), findsOneWidget);
    for (final control in find.byType(CallControlButton).evaluate()) {
      expect(
        find.descendant(
          of: find.byWidget(control.widget),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });

  testWidgets('the header counts the roster, and the tray offers More',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (svc, api, _) = await _call(tester);
    await tester.pumpWidget(_host(svc));
    await _settle(tester);

    // Me plus Bea and Cem joined; Dua is being rung, and says so.
    // One line when it fits beside the title, else the halves stacked.
    expect(
      find.text('3 in call · 1 ringing').evaluate().length +
          (find.text('3 in call').evaluate().isNotEmpty &&
                  find.text('1 ringing').evaluate().isNotEmpty
              ? 1
              : 0),
      1,
    );
    // The 1:1 tray's "More", right before Hide.
    final labels = [
      for (final e in find.byType(CallControlButton).evaluate())
        (e.widget as CallControlButton).label,
    ];
    expect(labels.indexOf('More'), labels.indexOf('Hide') - 1);

    // A peer whose link is down is still on the call — the roster says so —
    // and the count must not dip while it comes back.
    svc.peers['b']!.reconnecting = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    svc.notifyListeners();
    await _settle(tester);
    // One line when it fits beside the title, else the halves stacked.
    expect(
      find.text('3 in call · 1 ringing').evaluate().length +
          (find.text('3 in call').evaluate().isNotEmpty &&
                  find.text('1 ringing').evaluate().isNotEmpty
              ? 1
              : 0),
      1,
    );

    // Alone is "Just you", not "1 in call".
    await tester.runAsync(() async {
      api.roster!({
        'groupCallId': 'gc1',
        'status': 'active',
        'roomName': 'crew',
        'participants': [
          {'userId': 'a', 'status': 'joined', 'name': 'A'},
        ],
      });
      await _pump();
    });
    await _settle(tester);
    expect(find.text('Just you'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });

  test('stats lines leave out what the sample does not know', () {
    expect(statsDownLine(null), isNull);
    expect(
      statsDownLine(const CallQualitySnapshot(
        quality: CallQuality.good,
        inKbps: 1234,
        rttMs: 48.4,
        lossPercent: 0.25,
      )),
      '↓ 1.2 Mb/s · 48 ms · 0.3%',
    );
    expect(
      statsDownLine(const CallQualitySnapshot(
        quality: CallQuality.good,
        rttMs: 120,
      )),
      '120 ms',
    );
    expect(statsUpLine(2400), '↑ 2.4 Mb/s');
    expect(statsUpLine(null), isNull);
  });

  testWidgets('a camera coming on makes it a video call, and off again',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (svc, _, _) = await _call(tester);
    await tester.pumpWidget(_host(svc));
    await _settle(tester);
    expect(find.byType(GridView), findsNothing);

    await tester.runAsync(() async {
      await svc.toggleVideo();
      await _pump();
    });
    await _settle(tester);
    expect(svc.hasAnyVideo, isTrue);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ParticipantOrb), findsNothing);
    expect(find.text('Camera off'), findsOneWidget);

    await tester.runAsync(() async {
      await svc.toggleVideo();
      await _pump();
    });
    await _settle(tester);
    expect(svc.hasAnyVideo, isFalse);
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ParticipantOrb), findsNWidgets(4));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });

  testWidgets("a peer's camera is a grid; their screen is a stage",
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (svc, api, pc) = await _call(tester);
    await tester.pumpWidget(_host(svc));
    await _settle(tester);

    final cam = FakeMediaStream(
      [
        FakeMediaStreamTrack(kind: 'audio', id: 'b-mic'),
        FakeMediaStreamTrack(kind: 'video', id: 'b-cam'),
      ],
      id: 'ls-b',
    );
    await tester.runAsync(() async {
      _deliver(api, 'b', 'state', {
        'videoOff': false,
        'camStreamId': 'ls-b',
        'ts': 1,
      });
      await _pump();
      pc.onTrack!(RTCTrackEvent(
        streams: [cam],
        track: cam.getVideoTracks().single,
      ));
      await _pump();
    });
    await _settle(tester);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(RTCVideoView), findsOneWidget);

    final screen = FakeMediaStream(
      [FakeMediaStreamTrack(kind: 'video', id: 'b-scr')],
      id: 'screen-b',
    );
    await tester.runAsync(() async {
      _deliver(api, 'b', 'state', {
        'videoOff': false,
        'screenSharing': true,
        'camStreamId': 'ls-b',
        'screenStreamId': 'screen-b',
        'ts': 2,
      });
      await _pump();
      pc.onTrack!(RTCTrackEvent(
        streams: [screen],
        track: screen.getVideoTracks().single,
      ));
      await _pump();
    });
    await _settle(tester);
    expect(find.byType(ShareSurface), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Bea is sharing their screen'), findsOneWidget);
    // The pen appears with the stage.
    expect(find.text('Draw'), findsOneWidget);

    await tester.runAsync(() async {
      _deliver(api, 'b', 'state', {
        'videoOff': true,
        'screenSharing': false,
        'camStreamId': 'ls-b',
        'ts': 3,
      });
      await _pump();
    });
    await _settle(tester);
    expect(find.byType(ShareSurface), findsNothing);
    expect(find.byType(ParticipantOrb), findsNWidgets(4));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(svc.leaveCall);
  });
}
