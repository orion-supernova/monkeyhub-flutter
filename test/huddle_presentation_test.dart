
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_permissions.dart';
import 'package:monkeyhub/app.dart' show GroupCallOverlay;
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_float.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/group_call_screen.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/in_call_pill.dart';
import 'package:monkeyhub/calls/live_calls_store.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart' show CallMinimizeButton;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/main.dart' show rootNavigatorKey;
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_webrtc.dart';

/// A huddle is a pill, not a screen: starting or joining one never raises the
/// full call screen, the pill opens it, minimizing a quiet huddle goes back
/// to the pill, and the global in-call banner takes you to the room.
class _Sub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _Api extends Fake implements GroupCallApi {
  _Api({this.joinKind});

  /// What the server says the joined call is ("huddle" or null).
  final String? joinKind;

  @override
  Future<({String groupCallId, bool existing})> start({
    required String roomId,
    required String userId,
    required String type,
    String? deviceId,
    List<String>? inviteeIds,
    String? kind,
  }) async =>
      (groupCallId: 'hg1', existing: false);

  @override
  Future<({String type, String roomId, String? kind})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async =>
      (type: 'audio', roomId: 'room1', kind: joinKind);

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
  Future<Subscription> subscribeSignals({
    required String userId,
    String? deviceId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async =>
      _Sub();

  @override
  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) async =>
      _Sub();

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async =>
      _Sub();
}

class _CallApi extends Fake implements CallApi {}

class _ChatApi extends Fake implements ChatApi {}

GroupCallService _service({String? joinKind}) {
  final s = GroupCallService(api: _Api(joinKind: joinKind))
    ..leaveNotifyTimeout = const Duration(milliseconds: 20)
    ..nativeCardsEnabled = false;
  s.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
  s.attach(userId: 'me', deviceId: 'd1');
  return s;
}

class _Pushes extends NavigatorObserver {
  int screens = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) {
    if (route.settings.name == 'protected-route') screens++;
  }
}

void main() {
  // flutter_test defaults to Android; keep the permission pre-flight (an
  // Android-only channel call) out of these desktop-shaped tests.
  setUp(() => CallPermissions.debugForceApplies = false);
  tearDown(() => CallPermissions.debugForceApplies = null);

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => LiveCallsStore.instance.debugShow(const []));

  group('service', () {
    test('a started huddle is a huddle at once, before the live store knows',
        () async {
      final s = _service();
      await s.startHuddle(roomId: 'room1');
      expect(s.inCall, isTrue);
      expect(s.isHuddle, isTrue);
      expect(s.presentsAsHuddle, isTrue);
      await s.leaveCall();
      expect(s.isHuddle, isFalse);
    });

    test('a joined huddle is read off the live store', () async {
      LiveCallsStore.instance.debugShow(const [
        LiveRoomCall(
          roomId: 'room1',
          video: false,
          count: 2,
          mine: false,
          groupCallId: 'hg1',
          kind: 'huddle',
        ),
      ]);
      final s = _service();
      await s.joinCall('hg1');
      expect(s.isHuddle, isTrue);
      await s.leaveCall();
    });

    test('a huddle joined before the live store knows it stays a huddle '
        '(the server says so)', () async {
      LiveCallsStore.instance.debugShow(const []);
      final s = _service(joinKind: 'huddle');
      await s.joinCall('hg1');
      expect(s.isHuddle, isTrue);
      expect(s.presentsAsHuddle, isTrue);
      await s.leaveCall();
    });

    test('a plain call is not a huddle', () async {
      final s = _service();
      await s.startCall(roomId: 'room1', kind: CallMediaKind.audio);
      expect(s.isHuddle, isFalse);
      expect(s.presentsAsHuddle, isFalse);
      await s.leaveCall();
    });

    test('own screen share turns a huddle into a presenting call', () async {
      final s = _service();
      await s.startHuddle(roomId: 'room1');
      s.localScreenSharing = true;
      expect(s.presentsAsHuddle, isFalse);
      s.localScreenSharing = false;
      expect(s.presentsAsHuddle, isTrue);
      await s.leaveCall();
    });
  });

  group('overlay', () {
    Future<_Pushes> pumpOverlay(WidgetTester tester, GroupCallService s) async {
      final obs = _Pushes();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [obs],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox()),
          builder: (context, child) => ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: Stack(children: [
              ?child,
              GroupCallOverlay(
                service: s,
                api: _ChatApi(),
                screenUp: ValueNotifier(false),
              ),
            ]),
          ),
        ),
      );
      return obs;
    }

    testWidgets('starting a huddle does not push the call screen',
        (tester) async {
      final s = _service();
      final obs = await pumpOverlay(tester, s);
      await tester.runAsync(() => s.startHuddle(roomId: 'room1'));
      await tester.pump();
      await tester.pump();
      expect(s.inCall, isTrue);
      expect(obs.screens, 0);
      expect(find.byType(GroupCallScreen), findsNothing);
      await tester.runAsync(s.leaveCall);
    });

    testWidgets('a plain call still pushes the call screen', (tester) async {
      final s = _service();
      final obs = await pumpOverlay(tester, s);
      await tester.runAsync(
        () => s.startCall(roomId: 'room1', kind: CallMediaKind.audio),
      );
      await tester.pump();
      await tester.pump();
      expect(obs.screens, 1);
      await tester.runAsync(s.leaveCall);
    });

    testWidgets('opening the huddle bar (reopenTick) pushes the screen',
        (tester) async {
      final s = _service();
      final obs = await pumpOverlay(tester, s);
      await tester.runAsync(() => s.startHuddle(roomId: 'room1'));
      await tester.pump();
      expect(obs.screens, 0);
      s.reopenTick.value++;
      await tester.pump();
      await tester.pump();
      expect(obs.screens, 1);
      await tester.runAsync(s.leaveCall);
    });
  });

  group('minimize', () {
    testWidgets('a quiet huddle pops back to the pill (no float)',
        (tester) async {
      final s = _service();
      final obs = _Pushes();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [obs],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox()),
        builder: (context, child) => ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Stack(children: [
            ?child,
            GroupCallOverlay(
              service: s,
              api: _ChatApi(),
              screenUp: ValueNotifier(false),
            ),
          ]),
        ),
      ));
      await tester.runAsync(() => s.startHuddle(roomId: 'room1'));
      s.reopenTick.value++;
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(GroupCallScreen), findsOneWidget);

      await tester.tap(find.byType(CallMinimizeButton));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(GroupCallScreen), findsNothing);
      expect(CallFloat.instance.wanted.value, isFalse);
      expect(s.inCall, isTrue);
      await tester.runAsync(s.leaveCall);
    });
  });

  group('in-call pill', () {
    Future<void> pumpPill(
      WidgetTester tester,
      GroupCallService s, {
      String? activeRoom,
      void Function(String)? onOpenRoom,
    }) =>
        tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: Scaffold(
              body: InCallPill(
                call: CallService(api: _CallApi()),
                group: s,
                callScreenUp: ValueNotifier(false),
                activeRoomId: () => activeRoom,
                onOpenRoom: onOpenRoom,
              ),
            ),
          ),
        ));

    testWidgets('Return opens the room for a huddle, not the call screen',
        (tester) async {
      final s = _service();
      await tester.runAsync(() => s.startHuddle(roomId: 'room1'));
      final opened = <String>[];
      await pumpPill(tester, s, onOpenRoom: opened.add);
      await tester.pump();
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      expect(opened, ['room1']);
      expect(s.reopenTick.value, 0);
      await tester.runAsync(s.leaveCall);
    });

    testWidgets('stands down inside the huddle room, where the bar is',
        (tester) async {
      final s = _service();
      await tester.runAsync(() => s.startHuddle(roomId: 'room1'));
      await pumpPill(tester, s, activeRoom: 'room1');
      await tester.pump();
      expect(tester.getSize(find.byType(InCallPill)).height, 0);
      await tester.runAsync(s.leaveCall);
    });
  });
}
