import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

Map<String, dynamic> _videoConstraintsFor(VideoQualityTier tier) {
  final preset = videoQualityPresets[tier]!;
  return {
    'facingMode': 'user',
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
Future<MediaStreamTrack> getCallVideoOnlyTrack(VideoQualityTier tier) async {
  final stream = await navigator.mediaDevices.getUserMedia({
    'audio': false,
    'video': _videoConstraintsFor(tier),
  });
  final track = stream.getVideoTracks().first;
  // Detach the track before disposing its wrapper stream — `dispose()`
  // would otherwise stop every track still inside it, including the one
  // the caller is about to hand off to `replaceTrack`.
  stream.removeTrack(track);
  await stream.dispose();
  return track;
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
