import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

/// getUserMedia with production constraints; falls back once to the legacy
/// `mandatory` form on devices that reject the ideal/min/max map.
Future<MediaStream> getCallUserMedia(CallMediaKind kind) async {
  final constraints = <String, dynamic>{
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    if (kind == CallMediaKind.video)
      'video': {
        'facingMode': 'user',
        'width': {'min': 480, 'ideal': 1280, 'max': 1280},
        'height': {'min': 360, 'ideal': 720, 'max': 720},
        'frameRate': {'min': 15, 'ideal': 30, 'max': 30},
      }
    else
      'video': false,
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

/// Cap the video encoder so it can't starve the link. [maxBitrate] defaults
/// to ~1.2 Mbps (comfortable 720p30); group-call meshes pass a lower cap
/// since each phone runs one encoder per peer. MAINTAIN_FRAMERATE makes
/// congestion shed resolution (soft image, recovers fast) instead of frames
/// (stutter, reads as a broken call).
Future<void> configureVideoSenders(
  RTCPeerConnection pc, {
  int maxBitrate = 1200000,
}) async {
  try {
    final senders = await pc.getSenders();
    for (final sender in senders) {
      if (sender.track?.kind != 'video') continue;
      final params = sender.parameters;
      var encodings = params.encodings;
      if (encodings == null || encodings.isEmpty) {
        encodings = [RTCRtpEncoding()];
      }
      for (final e in encodings) {
        e.maxBitrate = maxBitrate;
        e.maxFramerate = 30;
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
/// enable the right signal processing, and defaultToSpeaker makes video
/// calls come up on the loudspeaker like every mainstream calling app.
Future<void> applyIosCallAudioConfig(CallMediaKind kind) async {
  if (kIsWeb || !Platform.isIOS) return;
  try {
    await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
      appleAudioCategory: AppleAudioCategory.playAndRecord,
      appleAudioCategoryOptions: {
        AppleAudioCategoryOption.allowBluetooth,
        AppleAudioCategoryOption.allowBluetoothA2DP,
        if (kind == CallMediaKind.video)
          AppleAudioCategoryOption.defaultToSpeaker,
      },
      appleAudioMode: kind == CallMediaKind.video
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
