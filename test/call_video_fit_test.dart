import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/widgets/call_video_fit.dart';

void main() {
  const phone = Size(390, 844);
  const laptopWindow = Size(1440, 900);
  const laptopCam = Size(1280, 720);
  const phoneCam = Size(720, 1280);

  group('callFeedFit', () {
    test('same shape fills the screen', () {
      expect(callFeedFit(phoneCam, phone), BoxFit.cover);
      expect(callFeedFit(laptopCam, laptopWindow), BoxFit.cover);
    });

    test('a laptop camera on a portrait phone is shown whole', () {
      // Cover here kept about a quarter of the picture's width: the
      // "they see me really close" report.
      expect(callFeedFit(laptopCam, phone), BoxFit.contain);
    });

    test('a portrait phone camera in a landscape window is shown whole', () {
      expect(callFeedFit(phoneCam, laptopWindow), BoxFit.contain);
    });

    test('no frame yet, or a square on either side, keeps cover', () {
      expect(callFeedFit(Size.zero, phone), BoxFit.cover);
      expect(callFeedFit(laptopCam, Size.zero), BoxFit.cover);
      expect(callFeedFit(const Size(480, 480), phone), BoxFit.cover);
      expect(callFeedFit(laptopCam, const Size(500, 500)), BoxFit.cover);
    });
  });

  test('displayedVideoSize swaps sides for a quarter-turn frame', () {
    const raw = RTCVideoValue(width: 1280, height: 720, renderVideo: true);
    expect(displayedVideoSize(raw), laptopCam);
    expect(displayedVideoSize(raw.copyWith(rotation: 90)), phoneCam);
    expect(displayedVideoSize(raw.copyWith(rotation: 270)), phoneCam);
    expect(displayedVideoSize(raw.copyWith(rotation: 180)), laptopCam);
  });
}
