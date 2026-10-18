@TestOn('browser')
library;

// The vendored web RTCVideoView (third_party/flutter_webrtc, PATCH W4) must
// follow the renderer its widget names. The 1:1 call screen hands its
// full-bleed slot the local renderer before the peer's video lands and the
// peer's renderer after, under one key; upstream kept painting the first
// one, so a web caller saw their own camera in both tiles.
//
// Run with: flutter test --platform chrome test/web_rtc_video_view_swap_test.dart

import 'dart:js_interop';

// ignore: depend_on_referenced_packages
import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// The web implementations by name: the package's own export picks them
// only under js_interop, and the analyzer resolves it for the VM.
// ignore: implementation_imports
import 'package:flutter_webrtc/src/web/rtc_video_renderer_impl.dart';
// ignore: implementation_imports
import 'package:flutter_webrtc/src/web/rtc_video_view_impl.dart';
import 'package:web/web.dart' as web;

/// A live camera stand-in: a canvas of [w]x[h] painted every frame.
MediaStreamWeb _canvasStream(int w, int h) {
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
  var n = 0;
  void paint(JSNumber _) {
    ctx.fillStyle = ((n++).isEven ? '#ff0000' : '#00ff00').toJS;
    ctx.fillRect(0, 0, w, h);
    web.window.requestAnimationFrame(paint.toJS);
  }

  web.window.requestAnimationFrame(paint.toJS);
  return MediaStreamWeb(canvas.captureStream(30), 'local');
}

Widget _slot(RTCVideoRenderer r) => Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(
    width: 200,
    height: 200,
    child: RTCVideoView(r, key: const ValueKey('feed')),
  ),
);

/// Real time passes (the video element decodes on the browser's clock)
/// while the test pumps, until [done] or a few seconds.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

void main() {
  testWidgets('a slot handed a new renderer paints the new renderer', (
    tester,
  ) async {
    final local = RTCVideoRenderer();
    final remote = RTCVideoRenderer();
    await tester.runAsync(() async {
      await local.initialize();
      await remote.initialize();
    });
    // Different shapes, so the captured frame says whose it is.
    local.srcObject = _canvasStream(320, 180);
    remote.srcObject = _canvasStream(180, 320);

    await tester.pumpWidget(_slot(local));
    final state = tester.state<RTCVideoViewState>(find.byType(RTCVideoView));
    expect(state.videoElement?.id, 'video_${local.viewType}');
    await _until(tester, () => state.capturedFrame != null);
    expect(state.capturedFrame?.width, 320);

    await tester.pumpWidget(_slot(remote));
    // Same State, new renderer.
    expect(
      identical(
        tester.state<RTCVideoViewState>(find.byType(RTCVideoView)),
        state,
      ),
      isTrue,
    );
    expect(state.videoElement?.id, 'video_${remote.viewType}');
    await _until(tester, () => state.capturedFrame?.width == 180);
    expect(state.capturedFrame?.width, 180);
    expect(state.capturedFrame?.height, 320);

    // The listener moved with it.
    // ignore: invalid_use_of_protected_member
    expect(local.hasListeners, isFalse);
    // ignore: invalid_use_of_protected_member
    expect(remote.hasListeners, isTrue);

    await tester.pumpWidget(const SizedBox());
    // ignore: invalid_use_of_protected_member
    expect(remote.hasListeners, isFalse);

    await tester.runAsync(() async {
      await local.dispose();
      await remote.dispose();
    });
  });
}
