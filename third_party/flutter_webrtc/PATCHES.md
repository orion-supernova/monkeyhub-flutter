# flutter_webrtc 1.4.1, vendored

pub.dev flutter_webrtc 1.4.1 (WebRTC-SDK 144.7559.01) with the `example/`
folder dropped. Every change is marked `MONKEYHUB PATCH Wn` in source. The
Darwin sources exist three times (`common/darwin/Classes`, `ios/Classes`,
`macos/Classes`, plain copies, not symlinks): patch `common` and copy the
file to the other two.

## Why not upgrade instead

1.5.x and 1.6.x force the AVAudioEngine audio device module on real iPhones
with no CallKit handoff and no opt-out from Dart (`FlutterWebRTCPlugin.m`
~422 in 1.6.2). Upstream issues #1996 and #2095 (CallKit audio) are still
open. Re-evaluate when PR #2197 ("expose the audio session management switch
to Dart") ships. A bump must re-apply every patch below.

## Patches

- **W1, renderer leak** (upstream #2167, #2172).
  `FlutterRTCVideoRenderer.m` `dispose`: release the event channel's stream
  handler. The binary messenger held every renderer ever created.
- **W2, first-frame block** (upstream #2190).
  `FlutterRTCVideoRenderer.m` `renderFrame:`: queue the "first frame" main
  thread block only until the first frame, not for every frame (30-60/s per
  renderer on the thread iOS draws Flutter on), and never dereference a nil
  weak self. Required once W1 lets renderers die.
- **W3, peer connection leak** (after upstream #2167).
  `FlutterWebRTCPlugin.m` `peerConnectionClose`/`peerConnectionDispose`:
  close parks the connection's and its data channels' event channels;
  dispose (sent by Dart after it cancels its subscription) releases their
  stream handlers, which were the only thing keeping each closed
  `webrtc::PeerConnection` alive. Dispose skips `deactiveRtcAudioSession`:
  the call's audio session belongs to CallKit and AppDelegate's
  `CallAudioRouter`, and a dispose landing during a quick redial must not
  switch the new call's session off. Close keeps its old behaviour.
  The app disposes every closed connection through `releasePeerConnection`
  in `lib/calls/call_media.dart`.

- **W4, web view keeps its first renderer** (unchanged upstream in 1.5.2).
  `lib/src/web/rtc_video_view_impl.dart` (the default, non
  `WEBRTC_USE_HTML_ELEMENT_VIEW` path): the State looked the hidden
  `<video>` up once in `initState`, so a parent that hands one slot a
  different renderer (the 1:1 call screen's full-bleed slot: local camera
  before the peer's video, then the peer; every PiP swap) kept painting the
  first renderer. On web the caller saw their own camera in both tiles.
  `didUpdateWidget` now moves the listener, the element and the frame loop
  to the new renderer; `dispose` removes the listener and ends the loop
  (it used to keep decoding a frame per video frame into images nobody
  disposed); `shouldRepaint` compares the frame (it returned false, so a
  new frame only reached the screen when something else repainted), and
  the frame sits behind its own `RepaintBoundary`.

- **W5, camera in Picture in Picture** (iOS only).
  `FlutterRTCMediaStream.m` `getUserVideo`: right after the
  `RTCCameraVideoCapturer` is created, and before its session starts
  running, set `AVCaptureSession.multitaskingCameraAccessEnabled` when the
  session reports it supported. Without it iOS interrupts the camera
  (`videoDeviceNotAvailableInBackground`) the moment the app leaves the
  screen, and the peer's picture of us freezes. Support is reported on
  iPhone for apps linked against the iOS 18 SDK that declare the `voip`
  background mode (Info.plist does), and the camera then runs only while a
  video-call PiP is up (`ios/Runner/CallPip.swift`, `DrawPip.swift`).
  Guarded by `TARGET_OS_IOS`, so the macOS copy compiles it out.

Android and the rest of Dart are byte-identical to pub.dev 1.4.1.
