// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_screen.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/incoming_call_screen.dart';
import 'package:monkeyhub/calls/screen_share.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_webrtc.dart';

/// The call screen comes and goes without leaving anything behind.
///
/// "The call sheet stutters, and worse after a few calls" is what a leak
/// across call cycles looks like: a listener, a ticker or a renderer kept
/// by a screen that is gone, multiplying with every call/cancel/redial. These
/// run the screens through many cycles (with the speaker toggled on each)
/// and pin that the service's listeners, the frame scheduler and the
/// renderers all come back to where they started; and that the screen's
/// layout is final on its first frame, not one frame into the slide.
class _FakeCallApi extends Fake implements CallApi {}

class _FakeCallService extends CallService {
  _FakeCallService() : super(api: _FakeCallApi());

  CallSession? fake;
  int listeners = 0;

  @override
  CallSession? get session => fake;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }

  void set(CallSession? s) {
    fake = s;
    notifyListeners();
  }

  @override
  Future<void> toggleSpeaker() async {
    final s = fake;
    if (s == null) return;
    set(s.copyWith(speakerOn: !s.speakerOn));
  }
}

CallSession _session(
  String id, {
  CallMediaKind kind = CallMediaKind.audio,
  CallStatus status = CallStatus.outgoingRinging,
  bool isCaller = true,
}) =>
    CallSession(
      callId: id,
      roomId: 'room1',
      peerUserId: 'peer',
      peerName: 'Zeynep',
      mediaKind: kind,
      isCaller: isCaller,
      status: status,
      speakerOn: kind == CallMediaKind.video,
      startedAt: DateTime(2026),
    );

void main() {
  late _FakeCallService service;
  late GlobalKey<NavigatorState> nav;
  final renderers = <FakeVideoRenderer>[];

  setUp(() {
    service = _FakeCallService();
    nav = GlobalKey<NavigatorState>();
    renderers.clear();
    CallScreen.rendererFactory = () {
      final r = FakeVideoRenderer();
      renderers.add(r);
      return r;
    };
    ScreenShare.invokeFn = (m, [a]) async => null;
  });

  Widget host() => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          navigatorKey: nav,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

  /// What a screen holds on the service: its own notifier and the two
  /// side channels the call screen listens to.
  ({int service, bool draw, bool quality}) held() => (
        service: service.listeners,
        draw: service.drawArmed.hasListeners,
        quality: service.callQuality.hasListeners,
      );

  Future<void> slide(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// One call: the screen slides up, the speaker flips twice, the call
  /// ends and the screen takes itself down.
  Future<void> oneCall(
    WidgetTester tester,
    String id, {
    CallMediaKind kind = CallMediaKind.audio,
  }) async {
    service.set(_session(id, kind: kind));
    nav.currentState!.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CallScreen(service: service),
    ));
    await slide(tester);
    expect(find.byType(CallScreen), findsOneWidget);
    service.toggleSpeaker();
    await tester.pump(const Duration(milliseconds: 250));
    service.toggleSpeaker();
    await tester.pump(const Duration(milliseconds: 250));
    service.set(service.fake!.copyWith(status: CallStatus.ended));
    // The screen holds "ended" for a beat, then slides away.
    await tester.pump(const Duration(milliseconds: 600));
    service.set(null);
    await slide(tester);
    expect(find.byType(CallScreen), findsNothing);
  }

  testWidgets('twenty voice calls leave no listener, ticker or route behind',
      (tester) async {
    await tester.pumpWidget(host());
    final before = held();

    for (var i = 0; i < 20; i++) {
      await oneCall(tester, 'call$i');
    }

    expect(held(), before);
    // Nothing is still animating: no orphaned pulse, spring or fade.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(PulseRings), findsNothing);
  });

  testWidgets('every video call releases the renderers it made',
      (tester) async {
    await tester.pumpWidget(host());
    final before = held();

    for (var i = 0; i < 10; i++) {
      await oneCall(tester, 'video$i', kind: CallMediaKind.video);
    }

    expect(held(), before);
    final made = renderers.where((r) => r.initialized).toList();
    // One set per call, each disposed with its screen.
    expect(made, hasLength(10 * 4));
    expect(made.where((r) => !r.disposed), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a video call makes no renderer while the screen slides up',
      (tester) async {
    await tester.pumpWidget(host());
    service.set(_session('v', kind: CallMediaKind.video));
    nav.currentState!.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CallScreen(service: service),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(renderers.where((r) => r.initialized), isEmpty);

    await slide(tester);
    expect(renderers.where((r) => r.initialized), hasLength(4));

    service.set(null);
    await slide(tester);
  });

  testWidgets('the status bar stays up through the call, drawn light',
      (tester) async {
    // WhatsApp and Telegram keep the clock and signal over a call. Hiding
    // them also changed the window's insets, a relayout of every screen.
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
    await tester.pumpWidget(host());
    service.set(_session('c'));
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CallScreen(service: service),
    );
    nav.currentState!.push(route);
    for (frame = 1; frame <= 3; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(route.animation!.isCompleted, isFalse);
    expect(hides, isEmpty);
    await slide(tester);
    expect(hides, isEmpty);
    expect(
      find.byWidgetPredicate((w) =>
          w is AnnotatedRegion<SystemUiOverlayStyle> &&
          w.value == kCallStatusBarStyle),
      findsOneWidget,
    );

    service.set(null);
    await slide(tester);
  });

  testWidgets('a call that ends mid-slide never makes its renderers',
      (tester) async {
    await tester.pumpWidget(host());
    service.set(_session('v', kind: CallMediaKind.video));
    nav.currentState!.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CallScreen(service: service),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    service.set(null);
    await tester.pump(const Duration(milliseconds: 600));
    await slide(tester);
    expect(find.byType(CallScreen), findsNothing);
    expect(renderers.where((r) => r.initialized), isEmpty);
    expect(held().service, 0);
  });

  testWidgets('the tray is laid out on the first frame of the slide',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());
    service.set(_session('c'));
    nav.currentState!.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CallScreen(service: service),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    int controls() => find.byType(CallControlButton).evaluate().length;
    final first = controls();
    Rect face() => tester.getRect(find.byType(PulseRings));
    final firstFace = face().size;
    final firstTop = face().top - tester.getRect(find.byType(CallScreen)).top;

    await slide(tester);
    // Same controls, same face, same place in the screen: nothing grew in
    // after the slide began.
    expect(controls(), first);
    expect(face().size, firstFace);
    expect(face().top - tester.getRect(find.byType(CallScreen)).top,
        moreOrLessEquals(firstTop, epsilon: 0.5));

    service.set(null);
    await slide(tester);
  });

  testWidgets('the in-app ringer comes and goes cleanly, call after call',
      (tester) async {
    await tester.pumpWidget(host());
    final before = held();
    for (var i = 0; i < 10; i++) {
      service.set(_session(
        'in$i',
        status: CallStatus.incomingRinging,
        isCaller: false,
      ));
      nav.currentState!.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(service: service),
      ));
      await slide(tester);
      expect(find.byType(IncomingCallScreen), findsOneWidget);
      // The caller hangs up.
      service.set(null);
      await slide(tester);
      expect(find.byType(IncomingCallScreen), findsNothing);
    }
    expect(held(), before);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
