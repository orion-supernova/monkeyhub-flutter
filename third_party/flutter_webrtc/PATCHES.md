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

Android and Dart are byte-identical to pub.dev 1.4.1.
