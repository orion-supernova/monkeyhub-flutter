import 'dart:async' show StreamController, Timer, unawaited;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/settings_store.dart';
import '../media/storage/network_kind.dart';
import 'call_models.dart';

/// Shared media plumbing for both the 1:1 [CallService] and the group-call
/// mesh — capture constraints, encoder tuning, codec preference, and audio
/// session/routing. One place, so every call path behaves identically on
/// every platform.

/// Real mobile hardware, where flutter_webrtc's native `Helper` audio APIs
/// (setSpeakerphoneOn, switchCamera) exist. On web/desktop those channels
/// have no implementation and throw MissingPluginException — the browser/OS
/// manages audio routing itself, so we simply skip them there.
bool get isMobileCallPlatform =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// Resolution ceiling + encoder cap for one [VideoQualityTier]. No capability
/// probing backs this (nothing in this codebase enumerates camera formats) —
/// `min`/`ideal`/`max` constraints negotiate down on hardware that can't
/// reach a tier, same as the legacy-constraint fallback below already does
/// for the pre-existing 720p default.
class VideoQualityPreset {
  const VideoQualityPreset({
    required this.minWidth,
    required this.idealWidth,
    required this.maxWidth,
    required this.minHeight,
    required this.idealHeight,
    required this.maxHeight,
    required this.maxBitrate,
  });

  final int minWidth;
  final int idealWidth;
  final int maxWidth;
  final int minHeight;
  final int idealHeight;
  final int maxHeight;

  /// Passed to [configureVideoSenders]. Solo-call baseline — group calls
  /// scale it further down per peer via `meshVideoBitrate`.
  final int maxBitrate;
}

/// `auto` is byte-for-byte the constraint set this file used before video
/// quality tiers existed — selecting it is a strict no-op for every existing
/// call.
const Map<VideoQualityTier, VideoQualityPreset> videoQualityPresets = {
  VideoQualityTier.auto: VideoQualityPreset(
    minWidth: 480,
    idealWidth: 1280,
    maxWidth: 1280,
    minHeight: 360,
    idealHeight: 720,
    maxHeight: 720,
    maxBitrate: 1200000,
  ),
  VideoQualityTier.hd1080: VideoQualityPreset(
    minWidth: 640,
    idealWidth: 1920,
    maxWidth: 1920,
    minHeight: 480,
    idealHeight: 1080,
    maxHeight: 1080,
    maxBitrate: 2500000,
  ),
  VideoQualityTier.uhd4k: VideoQualityPreset(
    minWidth: 1280,
    idealWidth: 3840,
    maxWidth: 3840,
    minHeight: 720,
    idealHeight: 2160,
    maxHeight: 2160,
    maxBitrate: 8000000,
  ),
};

Map<String, dynamic> _videoConstraintsFor(
  VideoQualityTier tier, {
  bool back = false,
}) {
  final preset = videoQualityPresets[tier]!;
  return {
    'facingMode': back ? 'environment' : 'user',
    'width': {
      'min': preset.minWidth,
      'ideal': preset.idealWidth,
      'max': preset.maxWidth,
    },
    'height': {
      'min': preset.minHeight,
      'ideal': preset.idealHeight,
      'max': preset.maxHeight,
    },
    'frameRate': {'min': 15, 'ideal': 30, 'max': 30},
  };
}

/// Thrown by media attachment when the acquired stream resolved AFTER the
/// call it was meant for ended (or was replaced by a newer call). The
/// orphaned stream has already been stopped and disposed by the thrower;
/// callers treat this as "quietly abort my remaining setup", never as a
/// call failure — the call that superseded us owns all live state now.
class MediaSupersededException implements Exception {
  @override
  String toString() => 'MediaSupersededException';
}

/// Stop every track, then dispose the stream — with a per-track try/catch,
/// because a single throwing `stop()` (seen on some Android OEMs) must never
/// skip the remaining tracks or the dispose. A skipped audio-track stop is a
/// live microphone with no owner: the iOS orange-dot bug.
/// Every step is bounded on its own. `stream.dispose()` on Darwin defers its
/// answer until the video capturer's stop-completion fires (the plugin's
/// `streamDispose` sets `shouldCallResult = NO` and answers from inside the
/// completion), so a completion that never comes used to hang this await —
/// and with it everything a caller sequenced after it.
Future<void> stopAndDisposeStream(
  MediaStream stream, {
  Duration stepTimeout = const Duration(seconds: 3),
}) async {
  for (final t in stream.getTracks()) {
    try {
      await t.stop().timeout(stepTimeout);
    } catch (e) {
      debugPrint('stopAndDisposeStream: track ${t.id} stop failed: $e');
    }
  }
  try {
    await stream.dispose().timeout(stepTimeout);
  } catch (e) {
    debugPrint('stopAndDisposeStream: dispose failed: $e');
  }
}

/// Darwin belt: stop the WebRTC audio-device module's capture outright.
///
/// flutter_webrtc 1.4 builds the macOS/iOS factory on the LiveKit CoreAudio
/// module (`initWithAudioDeviceModuleType:0` in FlutterWebRTCPlugin.m), and
/// on that module closing the last peer connection no longer stops recording
/// — `mediaStreamTrackStop` for an audio track is just `isEnabled = NO`, and
/// nothing else in the plugin ever calls the module's `stopRecording`.
/// Observed 2026-08-31 on macOS: a video call ended, the camera came down
/// (`video capturer stopped` in the plugin's own log), and Control Center
/// kept attributing the microphone to MonkeyHub for an hour, until the
/// process quit. The plugin does expose `stopRecording` as
/// `stopLocalRecording`; WebRTC restarts recording by itself the next time a
/// connection adds an audio sender, so this is safe after every teardown —
/// provided no OTHER call is still live in the process, which is the
/// caller's check ([CallService] and [GroupCallService] share one module).
Future<void> stopDarwinMicCapture() async {
  if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return;
  try {
    await NativeAudioManagement.stopLocalRecording()
        .timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('stopDarwinMicCapture failed: $e');
  }
}

/// getUserMedia with production constraints; falls back once to the legacy
/// `mandatory` form on devices that reject the ideal/min/max map.
Future<MediaStream> getCallUserMedia(
  CallMediaKind kind, {
  VideoQualityTier tier = VideoQualityTier.auto,
}) async {
  final constraints = <String, dynamic>{
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': kind == CallMediaKind.video
        ? _videoConstraintsFor(tier)
        : false,
  };
  try {
    return await navigator.mediaDevices.getUserMedia(constraints);
  } catch (e) {
    debugPrint(
      'getCallUserMedia: constraints rejected ($e) — retrying legacy form',
    );
    return await navigator.mediaDevices.getUserMedia({
      'audio': true,
      if (kind == CallMediaKind.video)
        'video': {
          'mandatory': {
            'minWidth': 640,
            'minHeight': 480,
            'minFrameRate': 24,
          },
          'facingMode': 'user',
          'optional': [],
        }
      else
        'video': false,
    });
  }
}

/// Re-acquire just the camera at a new [tier], for a mid-call quality switch
/// — deliberately video-only (`audio: false`) so it never touches the live
/// mic track the way a full [getCallUserMedia] call would. Caller is
/// expected to `RTCRtpSender.replaceTrack` the result onto the existing
/// video sender and stop the old track; no renegotiation needed.
///
/// [back] asks for the rear camera, so a camera the user flipped comes back
/// facing the same way after a restart or a quality switch.
Future<MediaStreamTrack> getCallVideoOnlyTrack(
  VideoQualityTier tier, {
  bool back = false,
}) async {
  final stream = await navigator.mediaDevices.getUserMedia({
    'audio': false,
    'video': _videoConstraintsFor(tier, back: back),
  });
  final track = stream.getVideoTracks().first;
  // Detach the track before disposing its wrapper stream — `dispose()`
  // would otherwise stop every track still inside it, including the one
  // the caller is about to hand off to `replaceTrack`.
  stream.removeTrack(track);
  await stream.dispose();
  return track;
}

/// Whether flutter_webrtc's Darwin plugin (iOS and macOS share it) is the
/// one behind the tracks.
bool get _darwinWebrtc => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

/// Takes a camera [track] out of the call's [stream] and releases the
/// camera behind it.
///
/// The order is the plugin's, per platform. On Darwin `trackDispose` stops
/// a track's capture session only when it still finds the track in a local
/// stream (FlutterWebRTCPlugin.m, `trackDispose`): a track taken out of the
/// stream natively first was disposed with its `AVCaptureSession` still
/// running. The camera light stayed on after "camera off", and that orphan
/// session restarts itself whenever the app becomes active and takes the
/// camera from the live one, which then sends nothing while the button
/// says on. So there the track is stopped while still in the stream (the
/// stop also removes it natively) and only the Dart list is edited.
/// Android's `trackDispose` stops the capturer by id but leaves the native
/// stream alone, so there the stream is edited natively, first, and a
/// renderer bound to it never picks the dead track.
Future<void> releaseCameraTrack(
  MediaStream stream,
  MediaStreamTrack track, {
  @visibleForTesting bool? darwin,
}) async {
  final apple = darwin ?? _darwinWebrtc;
  try {
    await stream.removeTrack(track, removeFromNative: !apple);
  } catch (e) {
    debugPrint('releaseCameraTrack: remove failed: $e');
  }
  try {
    await track.stop();
  } catch (e) {
    debugPrint('releaseCameraTrack: stop failed: $e');
  }
}

/// Releases a camera track that never made it into the call's stream (the
/// call ended while it warmed up). [getCallVideoOnlyTrack] hands it over
/// detached from any stream, and on Darwin a detached track's stop leaves
/// its capture session running (see [releaseCameraTrack]), so it is parked
/// in a throwaway stream first and stopped from there.
Future<void> discardCameraTrack(
  MediaStreamTrack track, {
  @visibleForTesting bool? darwin,
  @visibleForTesting Future<MediaStream> Function(String label)? createStream,
}) async {
  final apple = darwin ?? _darwinWebrtc;
  MediaStream? parked;
  if (apple) {
    try {
      parked = await (createStream ?? createLocalMediaStream)('cam-discard');
      await parked.addTrack(track);
    } catch (e) {
      debugPrint('discardCameraTrack: park failed: $e');
    }
  }
  try {
    await track.stop();
  } catch (e) {
    debugPrint('discardCameraTrack: stop failed: $e');
  }
  if (parked != null) {
    try {
      await parked.dispose();
    } catch (_) {}
  }
}

/// Cap the video encoder so it can't starve the link. [maxBitrate] defaults
/// to ~1.2 Mbps (comfortable 720p30); group-call meshes pass a lower cap
/// since each phone runs one encoder per peer. MAINTAIN_FRAMERATE makes
/// congestion shed resolution (soft image, recovers fast) instead of frames
/// (stutter, reads as a broken call).
Future<void> configureVideoSenders(
  RTCPeerConnection pc, {
  int maxBitrate = 1200000,
}) async {
  // Use Less Data for Calls (Data and Storage) caps every path here, 1:1 and
  // group alike, because every path tunes its senders through this function.
  final saving = callsSaveData;
  try {
    final senders = await pc.getSenders();
    for (final sender in senders) {
      final kind = sender.track?.kind;
      if (kind == 'audio' && saving) {
        // Opus stays intelligible well below this; it is what a voice call
        // on a weak cellular link negotiates down to anyway.
        final params = sender.parameters;
        var encodings = params.encodings;
        if (encodings == null || encodings.isEmpty) {
          encodings = [RTCRtpEncoding()];
        }
        for (final e in encodings) {
          e.maxBitrate = kDataSaverAudioBitrate;
        }
        params.encodings = encodings;
        await sender.setParameters(params);
        continue;
      }
      if (kind != 'video') continue;
      final params = sender.parameters;
      var encodings = params.encodings;
      if (encodings == null || encodings.isEmpty) {
        encodings = [RTCRtpEncoding()];
      }
      for (final e in encodings) {
        e.maxBitrate = saving
            ? math.min(maxBitrate, kDataSaverVideoBitrate)
            : maxBitrate;
        e.maxFramerate = saving ? 20 : 30;
      }
      params.encodings = encodings;
      params.degradationPreference =
          RTCDegradationPreference.MAINTAIN_FRAMERATE;
      final ok = await sender.setParameters(params);
      if (!ok) debugPrint('configureVideoSenders: setParameters rejected');
    }
  } catch (e) {
    debugPrint('configureVideoSenders skipped: $e');
  }
}

/// Video ceiling while the calls data saver applies: enough for a clear face
/// at 360p, roughly a fifth of what the default tier spends.
const int kDataSaverVideoBitrate = 280000;

/// Audio ceiling while the calls data saver applies.
const int kDataSaverAudioBitrate = 24000;

/// Whether calls should spend less data right now, from the user's rule and
/// the network the device is on.
bool get callsSaveData => SettingsStore.instance.dataPrefs
    .callsSaveData(NetworkKindMonitor.instance.current);

/// Reorder video codecs to prefer H.264 — hardware encode/decode on both
/// iOS (VideoToolbox) and most Android chipsets, far cooler than software
/// VP8 at 720p30. Reorders, never filters, so peers without hardware H.264
/// still negotiate down to VP8, and rtx/red/ulpfec stay available.
Future<void> preferH264Codec(RTCPeerConnection pc) async {
  try {
    final caps = await getRtpSenderCapabilities('video');
    final codecs = caps.codecs ?? [];
    bool isH264(RTCRtpCodecCapability c) =>
        c.mimeType.toLowerCase() == 'video/h264';
    if (!codecs.any(isH264)) return;
    final ordered = [
      ...codecs.where(isH264),
      ...codecs.where((c) => !isH264(c)),
    ];
    for (final t in await pc.getTransceivers()) {
      if (t.sender.track?.kind == 'video') {
        await t.setCodecPreferences(ordered);
      }
    }
  } catch (e) {
    debugPrint('preferH264Codec skipped: $e');
  }
}

/// Classify the AVAudioSession for calling BEFORE the callkit plugin's
/// generic playAndRecord/.default config wins: voiceChat/videoChat modes
/// enable the right signal processing, and (when [speakerOn]) defaultToSpeaker
/// makes video calls come up on the loudspeaker like every mainstream calling
/// app.
///
/// [speakerOn] gates `defaultToSpeaker`, not [kind] alone — this function is
/// re-invoked on every CallKit audio-session (re)activation, not just once at
/// attach, and `defaultToSpeaker` is written into flutter_webrtc's
/// PROCESS-WIDE `RTCAudioSessionConfiguration.webRTCConfiguration` singleton.
/// `Helper.setSpeakerphoneOn` (the actual route toggle) never clears that bit
/// — it only overrides the CURRENT output port — so a stale `kind ==
/// video`-only check here re-added `defaultToSpeaker` on every later
/// reactivation regardless of whether the user had switched to the earpiece,
/// and the next activation silently routed back to the loudspeaker even
/// though `speakerOn` (and the UI toggle) still correctly read false.
///
/// The MODE is gated on [speakerOn] for the same reason, and this is the
/// subtler half of the bug: `AVAudioSessionModeVideoChat` carries a DOCUMENTED
/// side effect — it force-sets `AVAudioSessionCategoryOptionDefaultToSpeaker`
/// (and `allowBluetoothHFP`) on its own, regardless of the category options
/// passed above. `setAppleAudioConfiguration` applies the mode LAST, so a
/// `kind == video`-only mode re-added the speaker bit that the option-gating
/// had just cleared — a video call could therefore NEVER reach the earpiece,
/// no matter what the toggle said. `voiceChat` mode has no such side effect
/// and is route-compatible with the receiver, so use it whenever the earpiece
/// is wanted. Voice calls were always `voiceChat`; only video-on-earpiece
/// changes. (`videoChat` stays for video-on-speaker, where the speaker is
/// exactly the route we want.)
Future<void> applyIosCallAudioConfig(
  CallMediaKind kind, {
  required bool speakerOn,
}) async {
  if (kIsWeb || !Platform.isIOS) return;
  try {
    await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
      appleAudioCategory: AppleAudioCategory.playAndRecord,
      appleAudioCategoryOptions: {
        AppleAudioCategoryOption.allowBluetooth,
        AppleAudioCategoryOption.allowBluetoothA2DP,
        if (speakerOn) AppleAudioCategoryOption.defaultToSpeaker,
      },
      appleAudioMode: (kind == CallMediaKind.video && speakerOn)
          ? AppleAudioMode.videoChat
          : AppleAudioMode.voiceChat,
    ));
  } catch (e) {
    debugPrint('setAppleAudioConfiguration failed: $e');
  }
}

/// The call's whole audio setup, category, mode and output route, in one
/// step. Use this, not the two helpers around it.
///
/// iOS goes to `AppDelegate.applyCallAudio` over the voip channel. It runs
/// off the main thread, which on iOS is also the thread Flutter draws on, so
/// a speaker tap or a reassert no longer drops frames on the call screen. It
/// also skips the category rewrite when nothing changed, and its speaker
/// override actually works; flutter_webrtc's `setSpeakerphoneOn(true)` passes
/// a property ID where the port belongs. A build without that method falls
/// back to the two flutter_webrtc calls. Android has only the route (see
/// [applyAndroidCallRoute]); web and desktop route themselves.
Future<void> applyCallAudio(
  CallMediaKind kind, {
  required bool speakerOn,
}) async {
  if (!isMobileCallPlatform) return;
  if (Platform.isAndroid) {
    await applyAndroidCallRoute(
      speakerOn: speakerOn,
      video: kind == CallMediaKind.video,
    );
    return;
  }
  if (Platform.isIOS) {
    try {
      await _voipChannel.invokeMethod<void>('applyCallAudio', {
        'video': kind == CallMediaKind.video,
        'speaker': speakerOn,
      });
      return;
    } on MissingPluginException {
      // Older native build: the flutter_webrtc pair below.
    } catch (e) {
      debugPrint('applyCallAudio (native) failed: $e');
      return;
    }
    // `defaultToSpeaker` in the config is the whole route here. Never
    // flutter_webrtc 1.4.1's `setSpeakerphoneOn` on iOS: it passes a
    // property ID where the port belongs, so its override always fails.
    await applyIosCallAudioConfig(kind, speakerOn: speakerOn);
    return;
  }
  await applyCallAudioRoute(speaker: speakerOn);
}

const _voipChannel = MethodChannel('monkeyhub/voip');

/// [applyCallAudio], answering the speaker side that actually took: on iOS
/// a connected headset wins over a speaker that is only a default
/// ([headsetWins]), and the call's flag must follow so the button shows the
/// sound. Null where nothing native decides (Android, web, desktop, an old
/// native build): keep the flag as asked.
///
/// [headsetWins] is false only for an explicit tap on the speaker button,
/// which reaches the loudspeaker even with AirPods in, the way FaceTime's
/// does. The kind's default (video on the speaker) and the camera coming on
/// are defaults, and a headset beats them.
///
/// [callId] names the call this audio is for (the 1:1 callId or the
/// groupCallId). iOS remembers it, so a teardown belt of an EARLIER call
/// (see `NativeCallHandler.deactivateIosAudioSessionSettled`) landing after
/// this apply leaves this call's session alone.
Future<bool?> applyCallAudioResolved(
  CallMediaKind kind, {
  required bool speakerOn,
  required bool headsetWins,
  String? callId,
}) async {
  if (!kIsWeb && Platform.isAndroid) {
    await applyAndroidCallRoute(
      speakerOn: speakerOn,
      video: kind == CallMediaKind.video,
      headsetWins: headsetWins,
    );
    return null;
  }
  if (kIsWeb || !Platform.isIOS) {
    await applyCallAudio(kind, speakerOn: speakerOn);
    return null;
  }
  _listenForCallAudioRoutes();
  try {
    return await _voipChannel.invokeMethod<bool>('applyCallAudio', {
      'video': kind == CallMediaKind.video,
      'speaker': speakerOn,
      'headsetWins': headsetWins,
      'callId': ?callId,
    });
  } on MissingPluginException {
    await applyCallAudio(kind, speakerOn: speakerOn);
  } catch (e) {
    debugPrint('applyCallAudio (native) failed: $e');
  }
  return null;
}

/// Why the route moved, as iOS reports it (`AVAudioSession.RouteChangeReason`).
enum CallAudioRouteReason {
  /// A headset, AirPods, a car connected.
  newDevice,

  /// One went away.
  oldDevice,

  /// Something rewrote the category. Ours, or another writer's.
  category,

  /// The output was overridden: the CallKit or Control Center speaker
  /// button, or a route picked in the system menu.
  override,

  /// The route was reconfigured; with [CallAudioRoute.echo] false, by the
  /// system on the user's behalf.
  routeConfiguration,
  other,
}

/// The call's real output, pushed by `CallAudioRouter` in AppDelegate.swift
/// on every iOS route change while a call holds the audio session.
@immutable
class CallAudioRoute {
  const CallAudioRoute({
    required this.speaker,
    required this.headset,
    required this.output,
    required this.reason,
    this.echo = false,
    this.portName,
    this.input,
    this.routes = const [],
  });

  factory CallAudioRoute.fromMap(Map<Object?, Object?> m) {
    final reason = m['reason']?.toString();
    return CallAudioRoute(
      speaker: m['speaker'] == true,
      headset: m['headset'] == true,
      output: m['output']?.toString() ?? 'none',
      reason: CallAudioRouteReason.values.firstWhere(
        (r) => r.name == reason,
        orElse: () => CallAudioRouteReason.other,
      ),
      echo: m['echo'] == true,
      portName: m['portName']?.toString(),
      input: m['input']?.toString(),
      routes: [
        for (final r in (m['routes'] as List?) ?? const [])
          if (r is Map) r,
      ],
    );
  }

  /// The loudspeaker is the output.
  final bool speaker;

  /// A headset is connected, even if the speaker override hides it.
  final bool headset;

  /// `receiver`, `speaker`, `bluetooth`, `headphones`, `car`, `airplay`,
  /// `other` or `none` (no route: the session isn't live).
  final String output;
  final CallAudioRouteReason reason;

  /// Within half a second of a native write of ours: most likely that write
  /// echoing back, not a user's choice.
  final bool echo;

  /// The output's own name ("Murat's AirPods Pro", "Headphones"), when the
  /// native side sends one. Display only; the policy never reads it.
  final String? portName;

  /// Where the voice is picked up: `builtIn`, `headset`, `bluetooth`,
  /// `car`, `other` or `none`. Null from an older native build.
  final String? input;

  /// Every route the user could pick right now, raw from the native side
  /// (`kind`, `uid`, `name`, `selected`), parsed by `CallAudioDevices`.
  /// Empty from an older native build: the speaker button stays a toggle.
  final List<Map<Object?, Object?>> routes;

  @override
  String toString() => 'CallAudioRoute(output: $output, speaker: $speaker, '
      'headset: $headset, reason: ${reason.name}${echo ? ', echo' : ''})';
}

/// What a call does with a [CallAudioRoute]: the speaker flag to adopt
/// (null keeps it), whether that side was the user's own choice, and
/// whether to re-apply the call's audio.
typedef CallAudioRouteDecision = ({
  bool? speakerOn,
  bool userChosen,
  bool resync,
});

/// The route policy, shared by the 1:1 and group calls. Pure, so it is
/// tested without a phone. The product rules (FaceTime/iMessage):
///   - A headset connecting takes the sound, whatever the speaker said.
///   - The last headset going away: the loudspeaker if the camera is on,
///     the earpiece if not (unplugging in a voice call never blasts the
///     speaker). A device dropping while the sound was already on the
///     speaker changes nothing.
///   - The user moving the route outside the app (the CallKit or Control
///     Center speaker button, the system route menu) is adopted, so the
///     in-app button shows what they picked, and later reasserts keep it.
///   - A category rewrite that left the route off our side (another writer,
///     a WebRTC restart) is undone by re-applying ours.
///   - Anything else, including our own writes echoing back, changes nothing.
/// Turning the camera OFF deliberately isn't here: it leaves the route
/// alone, so nobody is yanked back to the earpiece mid-sentence.
CallAudioRouteDecision decideCallAudioRoute({
  required bool speakerOn,
  required bool cameraOn,
  required CallAudioRoute route,
}) {
  const keep = (speakerOn: null, userChosen: false, resync: false);
  if (route.output == 'none') return keep;
  switch (route.reason) {
    case CallAudioRouteReason.newDevice:
      if (!route.headset) return keep;
      return (speakerOn: false, userChosen: false, resync: true);
    case CallAudioRouteReason.oldDevice:
      // Another headset still connected, or the sound was on the speaker
      // already (a Bluetooth device dropping must not pull it off).
      if (route.headset || speakerOn) return keep;
      if (!cameraOn) return keep; // iOS lands on the earpiece by itself.
      return (speakerOn: true, userChosen: false, resync: true);
    case CallAudioRouteReason.category:
      if (route.speaker == speakerOn) return keep;
      return (speakerOn: null, userChosen: false, resync: true);
    case CallAudioRouteReason.override:
    case CallAudioRouteReason.routeConfiguration:
      if (route.echo) {
        if (route.speaker == speakerOn) return keep;
        return (speakerOn: null, userChosen: false, resync: true);
      }
      if (route.speaker == speakerOn) return keep;
      return (speakerOn: route.speaker, userChosen: true, resync: true);
    case CallAudioRouteReason.other:
      return keep;
  }
}

final StreamController<CallAudioRoute> _callAudioRoutes =
    StreamController<CallAudioRoute>.broadcast();

/// Every route change the native side reports while a call holds the
/// session. iOS only; silent elsewhere.
Stream<CallAudioRoute> get callAudioRouteChanges => _callAudioRoutes.stream;

bool _routeListenerInstalled = false;

/// Installs the iOS route listener without an apply, for the route picker,
/// which can open before the call's first apply. Idempotent.
void ensureCallAudioRouteListener() => _listenForCallAudioRoutes();

void _listenForCallAudioRoutes() {
  if (_routeListenerInstalled) return;
  _routeListenerInstalled = true;
  const MethodChannel('monkeyhub/call_audio').setMethodCallHandler((call) async {
    if (call.method != 'routeChanged') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final route = CallAudioRoute.fromMap(args);
    debugPrint('call audio route: $route');
    _callAudioRoutes.add(route);
    return null;
  });
}

/// Logs the iOS audio session as a tone about to play into it sees it:
/// category, mode, route, volume. Diagnostics only, for the one question a
/// silent ringback leaves (was the session the call's, and where did the
/// sound go?). A no-op anywhere else.
Future<void> logCallAudioState(String why) async {
  if (kIsWeb || !Platform.isIOS) return;
  try {
    final state = await _voipChannel.invokeMethod<Object?>('callAudioState');
    debugPrint('call audio [$why]: $state');
  } catch (_) {}
}

/// What the Android branch of [applyCallAudio] asks flutter_webrtc's
/// AudioSwitch for. Every one of them puts a connected Bluetooth or wired
/// headset first except [forceSpeaker], which is the loudspeaker the user
/// chose over it.
enum AndroidCallRoute {
  /// `setSpeakerphoneOn(false)`: headset, else the earpiece.
  earpiece,

  /// `setSpeakerphoneOnButPreferBluetooth()`: headset, else the
  /// loudspeaker. A video call's default.
  speakerUnlessHeadset,

  /// `setSpeakerphoneOn(true)`: the loudspeaker, headset or not.
  forceSpeaker,
}

/// The route [applyCallAudio] wants on Android for [speakerOn], given what it
/// asked for last in this call ([previous], null before the first ask).
///
/// The callers cannot say whether a `speakerOn: true` is a default or a
/// choice: both services re-assert the route from the same flag on connect,
/// on reconnect and on every toggle. The history can. Only a switch from the
/// earpiece to the speaker is a person asking for the loudspeaker, so only
/// that forces it, and a forced speaker stays forced through the re-asserts
/// that follow. Every other `true` is the video default, which a headset
/// beats, as it does in every other calling app; `setSpeakerphoneOn(true)`
/// used to send a video call to the loudspeaker with earbuds in.
///
/// [headsetWins], when the caller knows it, settles the question instead:
/// false is a tap on the speaker button (force it), true is a default (a
/// headset beats it). The camera coming on in a voice call flips the flag
/// from earpiece to speaker without being a choice, which the history
/// alone would read as one.
@visibleForTesting
AndroidCallRoute androidCallRouteFor({
  required bool speakerOn,
  required AndroidCallRoute? previous,
  bool? headsetWins,
}) {
  if (!speakerOn) return AndroidCallRoute.earpiece;
  if (headsetWins != null) {
    return headsetWins
        ? AndroidCallRoute.speakerUnlessHeadset
        : AndroidCallRoute.forceSpeaker;
  }
  return switch (previous) {
    AndroidCallRoute.earpiece ||
    AndroidCallRoute.forceSpeaker => AndroidCallRoute.forceSpeaker,
    AndroidCallRoute.speakerUnlessHeadset ||
    null => AndroidCallRoute.speakerUnlessHeadset,
  };
}

AndroidCallRoute? _androidRoute;

/// The AudioSwitch device (its type name: `earpiece`, `bluetooth`,
/// `wired-headset`) the user picked in the in-call route sheet, or null for
/// AudioSwitch's own choice. Only the non-speaker side is pinned: on that
/// side [applyAndroidCallRoute]'s `setSpeakerphoneOn(false)` picks the
/// FIRST headset it finds, so "the phone, not my earbuds" needs the pick
/// re-asserted after every re-apply. Cleared with the call.
String? _androidPinnedOutput;

/// The pinned Android output, null when AudioSwitch chooses.
String? get androidPinnedCallOutput => _androidPinnedOutput;

/// Pins (or with null, unpins) the Android output the route sheet chose.
/// Takes effect at the next [applyAndroidCallRoute], which the caller
/// triggers by setting the speaker side.
void pinAndroidCallOutput(String? typeName) {
  _androidPinnedOutput = typeName;
  debugPrint('[MHCallAudio] android output pinned: ${typeName ?? 'none'}');
}

/// flutter_webrtc's AudioSwitch device selection, swappable for tests.
@visibleForTesting
Future<void> Function(String typeName) androidSelectAudioOutput =
    Helper.selectAudioOutput;

/// The Android route last asked for in the current call. Tests only.
@visibleForTesting
AndroidCallRoute? get debugAndroidCallRoute => _androidRoute;

/// The flutter_webrtc calls [applyAndroidCallRoute] makes, swappable so the
/// sequencing is testable without a platform channel.
@visibleForTesting
Future<void> Function(bool enable) androidSetSpeakerphoneOn =
    Helper.setSpeakerphoneOn;
@visibleForTesting
Future<void> Function() androidSetSpeakerphoneButPreferHeadset =
    Helper.setSpeakerphoneOnButPreferBluetooth;

/// The Android half of [applyCallAudio]: the output route, and nothing else.
///
/// The mode (MODE_IN_COMMUNICATION) and the audio focus belong to
/// flutter_webrtc's AudioSwitch, which takes both when the first mic or
/// remote audio track appears and gives both back when the last peer
/// connection is DISPOSED, never merely closed. See [releasePeerConnection],
/// which is what makes that happen.
///
/// Everything here is a few-microsecond AudioSwitch call posted to the main
/// looper; there is no session to configure as on iOS.
///
/// It also sets the call's screen (see [androidCallWindowFor]): kept on for
/// the call, and handed to the proximity sensor while a voice call is at
/// the ear.
Future<void> applyAndroidCallRoute({
  required bool speakerOn,
  bool video = false,
  bool? headsetWins,
}) async {
  final previous = _androidRoute;
  final route = androidCallRouteFor(
    speakerOn: speakerOn,
    previous: previous,
    headsetWins: headsetWins,
  );
  _androidRoute = route;
  debugPrint(
    '[MHCallAudio] android route ${previous?.name ?? 'none'} -> ${route.name}',
  );
  unawaited(_setAndroidCallWindow(androidCallWindowFor(route, video: video)));
  try {
    switch (route) {
      case AndroidCallRoute.earpiece:
        await androidSetSpeakerphoneOn(false);
      case AndroidCallRoute.forceSpeaker:
        await androidSetSpeakerphoneOn(true);
      case AndroidCallRoute.speakerUnlessHeadset:
        // First ask of the call: `setSpeakerphoneOn(true)` once, for the
        // side effect alone. It reorders AudioSwitch's preference list to
        // put the speaker before the earpiece, so pulling the earbuds out
        // mid-call lands a video call on the loudspeaker rather than at the
        // ear. Nothing is playing yet at the first ask, so the speaker it
        // selects for that instant is never heard. A re-assert skips it: a
        // speaker hop and back mid-call would tear the Bluetooth link down
        // and up, a second of silence.
        if (previous == null) await androidSetSpeakerphoneOn(true);
        await androidSetSpeakerphoneButPreferHeadset();
    }
    // The route sheet's pick, on the side it was made for. Posted to the
    // same AudioSwitch handler after the call above, so it lands last.
    final pin = _androidPinnedOutput;
    if (pin != null && route == AndroidCallRoute.earpiece) {
      await androidSelectAudioOutput(pin);
    }
  } catch (e) {
    debugPrint('[MHCallAudio] android route ${route.name} failed: $e');
  }
}

/// Forget the current call's Android route, so the next call starts from
/// its own default, and give the screen back. Called when a call (1:1 or
/// group) is torn down.
void resetAndroidCallRoute() {
  final hadCall = _androidRoute != null;
  _androidRoute = null;
  _androidPinnedOutput = null;
  if (hadCall) {
    unawaited(_setAndroidCallWindow(
      (keepScreenOn: false, proximity: false),
    ));
  }
}

/// What a call does to the Android screen: kept on for the whole call, and
/// switched off by the proximity sensor only for a VOICE call routed to the
/// earpiece, the one case where the phone is held to a face. Not for video
/// (the person is looking at it), not on the speaker. On a headset the
/// earpiece route is nominal, and the sensor only matters if the phone does
/// go to the ear.
@visibleForTesting
({bool keepScreenOn, bool proximity}) androidCallWindowFor(
  AndroidCallRoute route, {
  required bool video,
}) =>
    (
      keepScreenOn: true,
      proximity: !video && route == AndroidCallRoute.earpiece,
    );

/// The last state sent to `monkeyhub/call_window`, so a re-assert that
/// changes nothing costs no platform hop.
({bool keepScreenOn, bool proximity})? _androidWindow;

/// Sends [state] to `CallWindowBridge`, swappable for tests.
@visibleForTesting
Future<void> Function(({bool keepScreenOn, bool proximity}) state)
    androidCallWindowSink = (state) {
  _listenForCallWindowReset();
  return _callWindowChannel.invokeMethod<void>(
    'set',
    {'keepScreenOn': state.keepScreenOn, 'proximity': state.proximity},
  );
};

const _callWindowChannel = MethodChannel('monkeyhub/call_window');

bool _callWindowResetListening = false;

/// `CallWindowBridge`'s watchdog dropped the screen state on its own (it
/// saw no call audio for a while: a teardown that never reached it). Forget
/// the last state sent, or the de-dup above would swallow the next call's
/// identical one and that call would get no keep-on and no proximity.
void _listenForCallWindowReset() {
  if (_callWindowResetListening) return;
  _callWindowResetListening = true;
  _callWindowChannel.setMethodCallHandler((call) async {
    if (call.method == 'reset') {
      debugPrint('[MHCallAudio] call window reset by the native watchdog');
      _androidWindow = null;
    }
  });
}

Future<void> _setAndroidCallWindow(
  ({bool keepScreenOn, bool proximity}) state,
) async {
  if (_androidWindow == state) return;
  _androidWindow = state;
  try {
    await androidCallWindowSink(state);
  } catch (e) {
    // An older native build without the bridge: the screen behaves as before.
    debugPrint('[MHCallAudio] call window not set: $e');
  }
}

/// Whether [releasePeerConnection] disposes. Tests only.
@visibleForTesting
bool? debugReleasePeerConnectionsOverride;

bool get _releasesPeerConnections =>
    debugReleasePeerConnectionsOverride ??
    (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

/// How long [releasePeerConnection] lets the screen settle before it
/// disposes.
@visibleForTesting
Duration releasePeerConnectionDelay = const Duration(milliseconds: 600);

/// Dispose an already CLOSED [pc]: on Android so the phone leaves call mode,
/// on Apple platforms so the connection is freed at all.
///
/// Every call path closed its peer connections and none ever disposed one.
/// On Android the difference is the whole audio state: flutter_webrtc's
/// AudioSwitch restores the audio mode to MODE_NORMAL, abandons the voice
/// call audio focus and puts the speakerphone back only in
/// `peerConnectionDispose`, and only once no peer connection is left
/// registered (MethodCallHandlerImpl.peerConnectionDispose). A closed one
/// stays registered. So after the first call the phone stayed in
/// MODE_IN_COMMUNICATION with focus held until the process died: media
/// ducked or silent, notification sounds through the call path, the next
/// call starting from the last one's route. And each call leaked its native
/// peer connection.
///
/// Fire-and-forget and deliberately late: the dispose runs on the platform
/// thread, which Flutter now shares with Dart, so it waits out the call
/// screen's exit instead of landing in it. A redial inside that window is
/// safe: its own connection keeps AudioSwitch active, because the stop only
/// happens when the registry empties.
///
/// iOS and macOS: flutter_webrtc's event channel kept every peer connection
/// alive for the life of the process, close or no close. The vendored copy
/// (third_party/flutter_webrtc, PATCH W3) lets dispose release it, and its
/// dispose leaves the audio session alone, which on iOS is CallKit's and
/// AppDelegate's CallAudioRouter's to manage.
///
/// The late dispose is tracked, not fire-and-forget: a new call that brings
/// its mic up before it has a peer connection of its own would otherwise
/// have the old one's dispose empty the registry under it, stopping
/// AudioSwitch mid-call. Every media start calls
/// [flushPeerConnectionReleases] first, so the stop always precedes the
/// start.
void releasePeerConnection(RTCPeerConnection pc) {
  if (!_releasesPeerConnections) return;
  if (_pendingReleases.containsKey(pc) || _inflightReleases.containsKey(pc)) {
    return;
  }
  _pendingReleases[pc] = Timer(releasePeerConnectionDelay, () {
    _pendingReleases.remove(pc);
    unawaited(_disposeReleased(pc));
  });
}

/// Peer connections [releasePeerConnection] is waiting out the screen for.
final Map<RTCPeerConnection, Timer> _pendingReleases = {};

/// Disposes that have started and not yet finished.
final Map<RTCPeerConnection, Future<void>> _inflightReleases = {};

/// Peer connections released and not yet disposed. Tests only.
@visibleForTesting
int get debugPendingPeerConnectionReleases =>
    _pendingReleases.length + _inflightReleases.length;

Future<void> _disposeReleased(RTCPeerConnection pc) {
  final running = _inflightReleases[pc];
  if (running != null) return running;
  final f = () async {
    try {
      await pc.dispose().timeout(const Duration(seconds: 3));
      debugPrint('[MHCallAudio] peer connection released');
    } catch (e) {
      debugPrint('[MHCallAudio] peer connection release failed: $e');
    } finally {
      _inflightReleases.remove(pc);
    }
  }();
  _inflightReleases[pc] = f;
  return f;
}

/// Disposes every peer connection [releasePeerConnection] still holds, now,
/// and waits for them. Called right before a call acquires its mic, so the
/// AudioSwitch stop the last dispose triggers lands before the new call's
/// start instead of in the middle of the new call.
Future<void> flushPeerConnectionReleases() async {
  if (_pendingReleases.isEmpty && _inflightReleases.isEmpty) return;
  final due = _pendingReleases.keys.toList();
  for (final t in _pendingReleases.values) {
    t.cancel();
  }
  _pendingReleases.clear();
  debugPrint('[MHCallAudio] flushing ${due.length} peer connection release(s)');
  await Future.wait([
    for (final pc in due) _disposeReleased(pc),
    ..._inflightReleases.values,
  ]);
}

/// Loudspeaker/earpiece toggle — mobile only (web/desktop route themselves).
Future<void> applyCallAudioRoute({required bool speaker}) async {
  if (!isMobileCallPlatform) return;
  try {
    await Helper.setSpeakerphoneOn(speaker);
  } catch (e) {
    debugPrint('setSpeakerphoneOn failed: $e');
  }
}

/// Encoder cap for a SCREEN sender — a different animal from the camera's.
///
/// [configureVideoSenders] tunes every video sender for a face: a bitrate a
/// phone can sustain per peer and `MAINTAIN_FRAMERATE`, so congestion softens
/// the picture rather than stuttering it. Point that at a shared screen and
/// the text on it turns to soup, because text is exactly what a resolution
/// drop destroys. So the screen sender is re-tuned after every camera pass:
/// more bits, fewer frames (a screen barely moves; 15 fps halves the encode
/// cost), and `MAINTAIN_RESOLUTION` so a bad link drops frames and keeps the
/// words legible. In a mesh the cap still shrinks with the peer count — one
/// encoder per link — but never below what a document stays readable at.
Future<void> configureScreenSender(
  RTCRtpSender sender, {
  int remotePeerCount = 1,
}) async {
  const solo = 2500000;
  const floor = 800000;
  final cap = remotePeerCount <= 1
      ? solo
      : (solo / remotePeerCount).round().clamp(floor, solo);
  try {
    final params = sender.parameters;
    var encodings = params.encodings;
    if (encodings == null || encodings.isEmpty) {
      encodings = [RTCRtpEncoding()];
    }
    for (final e in encodings) {
      e.maxBitrate = cap;
      e.maxFramerate = 15;
    }
    params.encodings = encodings;
    params.degradationPreference =
        RTCDegradationPreference.MAINTAIN_RESOLUTION;
    final ok = await sender.setParameters(params);
    if (!ok) debugPrint('configureScreenSender: setParameters rejected');
  } catch (e) {
    debugPrint('configureScreenSender skipped: $e');
  }
}
