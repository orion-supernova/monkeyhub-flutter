import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/call_float.dart';
import 'package:monkeyhub/calls/call_pip.dart';
import 'package:monkeyhub/calls/widgets/call_float_window.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_webrtc.dart';

/// A minimized call floats.
///
/// "Hide" used to take the call screen away entirely, leaving only the bar
/// at the top. These pin the floating window that replaced it: there only
/// when there is a picture to float (never for a voice call, never over a
/// share of this device's own screen), one renderer that exists only while
/// the window is up and the app is on screen, flung off the side to go back
/// to the bar, and grown back into the call screen on a tap.
void main() {
  final pip = CallPip.instance;
  late List<FakeVideoRenderer> renderers;
  late ValueNotifier<bool> screenUp;
  late int reopened;
  late CallFloat float;

  final cam = FakeMediaStream(
    [FakeMediaStreamTrack(kind: 'video', id: 'v1')],
    id: 'ls-b',
  );
  final face = CallPipSpec(
    title: 'Ada',
    stream: cam,
    trackId: 'v1',
    videoOff: false,
  );

  setUp(() {
    pip.debugReset();
    renderers = [];
    CallFloat.rendererFactory = () {
      final r = FakeVideoRenderer();
      renderers.add(r);
      return r;
    };
    screenUp = ValueNotifier<bool>(true);
    reopened = 0;
    float = CallFloat.forTest()
      ..attach(screenUp: screenUp, reopen: () => reopened++, pip: pip);
  });

  tearDown(() {
    float.debugReset();
    pip.debugReset();
    CallFloat.rendererFactory = RTCVideoRenderer.new;
  });

  /// Lets the renderer's async initialize land.
  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The picture's first frame, as flutter_webrtc reports it.
  void firstFrame({double w = 720, double h = 1280}) {
    renderers.last.value = RTCVideoValue(width: w, height: h, renderVideo: true);
  }

  group('CallFloat', () {
    test('no picture, no window: a voice call goes to the bar', () async {
      expect(float.wanted.value, isFalse);
      expect(await float.minimize(), isFalse);
      expect(renderers, isEmpty);
    });

    test('nothing decodes for it while the call screen is up', () async {
      pip.spec.value = face;
      await settle();
      expect(float.wanted.value, isTrue);
      expect(float.visible, isFalse);
      expect(renderers, isEmpty);
    });

    test('minimize floats the picture once it has a frame, and the screen '
        'going decodes into the one renderer', () async {
      pip.spec.value = face;
      final done = float.minimize(from: const Rect.fromLTWH(0, 0, 390, 844));
      await settle();
      expect(renderers, hasLength(1));
      expect(renderers.single.srcObject, same(cam));
      // Not over the screen until the picture is there to cover it with.
      expect(float.visible, isFalse);
      firstFrame();
      expect(await done, isTrue);
      expect(float.visible, isTrue);
      expect(float.takeLaunchFrom(), const Rect.fromLTWH(0, 0, 390, 844));
      expect(float.takeLaunchFrom(), isNull, reason: 'taken once');

      screenUp.value = false;
      expect(float.visible, isTrue);
      expect(float.minimizing, isFalse);
      expect(renderers, hasLength(1));
      expect(float.videoSize, const Size(720, 1280));
    });

    test('off screen it lets the picture go, and takes it back on return',
        () async {
      pip.spec.value = face;
      screenUp.value = false;
      await settle();
      expect(renderers, hasLength(1));

      float.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(renderers.single.disposed, isTrue);
      expect(float.renderer, isNull);

      float.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(renderers, hasLength(2));
      expect(renderers.last.srcObject, same(cam));
    });

    test('a name card holds no stream', () async {
      pip.spec.value = const CallPipSpec(title: 'crew');
      screenUp.value = false;
      await settle();
      expect(float.visible, isTrue);
      expect(renderers, isEmpty);
    });

    test('a share of this device, or Android in PiP: no window', () async {
      // CallPip drops the spec while this device shares its own screen.
      pip.spec.value = null;
      screenUp.value = false;
      expect(float.wanted.value, isFalse);

      pip.spec.value = face;
      expect(float.wanted.value, isTrue);
      pip.inPip.value = true;
      expect(float.wanted.value, isFalse);
      expect(float.visible, isFalse);
      await settle();
      expect(renderers.where((r) => !r.disposed), isEmpty);
    });

    test('flung away, the call is in the bar until its screen next opens',
        () async {
      pip.spec.value = face;
      screenUp.value = false;
      await settle();
      float.tuck();
      expect(float.wanted.value, isFalse);
      expect(float.visible, isFalse);
      expect(renderers.single.disposed, isTrue);

      screenUp.value = true;
      expect(float.tucked, isFalse);
      expect(float.wanted.value, isTrue);
    });

    test('expand asks for the screen back without its slide, once', () async {
      pip.spec.value = face;
      screenUp.value = false;
      await settle();
      float.expand();
      expect(reopened, 1);
      expect(float.visible, isTrue, reason: 'holds until the screen draws');
      expect(float.takeInstantPush(), isTrue);
      expect(float.takeInstantPush(), isFalse);
      screenUp.value = true;
      // The screen has no feed of this stream here: a beat, then it lands.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(float.handoffLanded, isTrue);
      float.endHandoff();
      expect(float.visible, isFalse);
      expect(renderers.single.disposed, isTrue);
    });
  });

  group('CallFloatWindow', () {
    const area = Size(390, 844);
    const pad = EdgeInsets.only(top: 59, bottom: 34);

    Widget host({bool calm = false}) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MediaQuery(
          data: MediaQueryData(
            size: area,
            padding: pad,
            disableAnimations: calm,
          ),
          child: Localizations(
            locale: const Locale('en'),
            delegates: AppLocalizations.localizationsDelegates,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  const SizedBox.expand(),
                  CallFloatWindow(float: float),
                ],
              ),
            ),
          ),
        ),
      );

    Finder window() => find.byType(GestureDetector);

    Rect rectOf(WidgetTester tester) => tester.getRect(
          find
              .ancestor(of: window(), matching: find.byType(Positioned))
              .first,
        );

    testWidgets('flies out of the screen into the top-right corner, under '
        "the page's bar", (tester) async {
      await tester.binding.setSurfaceSize(area);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      pip.spec.value = const CallPipSpec(title: 'Ada');
      await tester.pumpWidget(host());
      await tester.runAsync(() async {
        await float.minimize(from: Offset.zero & area);
      });
      await tester.pump();
      // First frame of the flight: the whole screen.
      expect(rectOf(tester).width, closeTo(area.width, 1));
      await tester.pump(const Duration(milliseconds: 600));
      screenUp.value = false;
      await tester.pumpAndSettle();
      final r = rectOf(tester);
      final size = CallFloatWindow.sizeFor(area, 3 / 4);
      expect(r.width, closeTo(size.width, 0.01));
      expect(r.height, closeTo(size.height, 0.01));
      expect(r.right, closeTo(area.width - 12, 0.5));
      expect(r.top, closeTo(pad.top + 56, 0.5));
    });

    testWidgets('a drag springs to the corner it is heading for',
        (tester) async {
      await tester.binding.setSurfaceSize(area);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      pip.spec.value = const CallPipSpec(title: 'Ada');
      screenUp.value = false;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final start = rectOf(tester);
      // Slow and short of the edge: a move, not a throw off the side.
      expect(start.left, greaterThan(area.width / 2));
      await tester.timedDrag(
        find.text('Ada'),
        Offset(-area.width / 2, area.height / 2),
        const Duration(milliseconds: 900),
      );
      await tester.pumpAndSettle();
      final r = rectOf(tester);
      expect(r.left, closeTo(12, 0.5));
      expect(r.bottom, closeTo(area.height - (pad.bottom + 76), 0.5));
    });

    testWidgets('flung off the side, it goes to the bar', (tester) async {
      await tester.binding.setSurfaceSize(area);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      pip.spec.value = const CallPipSpec(title: 'Ada');
      screenUp.value = false;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.fling(find.text('Ada'), const Offset(260, 0), 2400);
      await tester.pumpAndSettle();
      expect(float.tucked, isTrue);
      expect(float.wanted.value, isFalse);
      expect(window(), findsNothing);
    });

    testWidgets('a tap grows it into the screen, which it then hands to',
        (tester) async {
      await tester.binding.setSurfaceSize(area);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      pip.spec.value = const CallPipSpec(title: 'Ada');
      screenUp.value = false;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(rectOf(tester), Offset.zero & area);
      expect(reopened, 1);
      screenUp.value = true;
      // The screen here has no feed of the stream: it lands after a beat.
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(window(), findsNothing);
      expect(float.visible, isFalse);
    });

    testWidgets('calm motion snaps', (tester) async {
      await tester.binding.setSurfaceSize(area);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      pip.spec.value = const CallPipSpec(title: 'Ada');
      screenUp.value = false;
      await tester.pumpWidget(host(calm: true));
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(rectOf(tester).width,
          closeTo(CallFloatWindow.sizeFor(area, 3 / 4).width, 0.01));
    });
  });

  test('every shape is about the same size', () {
    const phone = Size(390, 844);
    final portrait = CallFloatWindow.sizeFor(phone, 9 / 16);
    final landscape = CallFloatWindow.sizeFor(phone, 16 / 9);
    expect(portrait.width * portrait.height,
        closeTo(landscape.width * landscape.height, 1));
    expect(landscape.width, greaterThan(landscape.height));
    // Never thinner than 9:16.
    expect(CallFloatWindow.sizeFor(phone, 0.2).aspectRatio,
        closeTo(9 / 16, 0.001));
  });
}
