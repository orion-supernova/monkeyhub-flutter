import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../diagnostics/device_report.dart';
import '../l10n/generated/app_localizations.dart';
import 'call_models.dart';
import 'call_service.dart';

/// What the 1:1 call tells Android's ongoing-call notification, as a value:
/// the native side hears only what changes.
@immutable
class CallNotificationState {
  const CallNotificationState({
    required this.callId,
    required this.connected,
    required this.muted,
    required this.camera,
  });

  final String callId;
  final bool connected;
  final bool muted;

  /// The camera is on: the call's foreground service must carry the camera
  /// type, or Android cuts the camera when the app leaves the screen.
  final bool camera;

  @override
  bool operator ==(Object other) =>
      other is CallNotificationState &&
      other.callId == callId &&
      other.connected == connected &&
      other.muted == muted &&
      other.camera == camera;

  @override
  int get hashCode => Object.hash(callId, connected, muted, camera);
}

/// The state for [session], or null once there is no live call to show.
@visibleForTesting
CallNotificationState? callNotificationStateFor({
  required CallSession? session,
  required bool localCamActive,
}) {
  final s = session;
  if (s == null) return null;
  switch (s.status) {
    case CallStatus.outgoingRinging:
    case CallStatus.connecting:
    case CallStatus.active:
    case CallStatus.switching:
      return CallNotificationState(
        callId: s.callId,
        connected: s.status == CallStatus.active ||
            s.status == CallStatus.switching,
        muted: s.localMuted,
        camera: localCamActive,
      );
    case CallStatus.idle:
    case CallStatus.incomingRinging:
    case CallStatus.handedOff:
    case CallStatus.ended:
    case CallStatus.failed:
      return null;
  }
}

/// The channel calls that take the native side from [prev] to [next].
@visibleForTesting
List<(String, Map<String, Object?>?)> callNotificationOps(
  CallNotificationState? prev,
  CallNotificationState? next, {
  required String mute,
  required String unmute,
}) {
  if (next == null) {
    return prev == null ? const [] : [('clear', null)];
  }
  final ops = <(String, Map<String, Object?>?)>[];
  final sameCall = prev?.callId == next.callId;
  if (!sameCall || prev!.muted != next.muted || prev.connected != next.connected) {
    ops.add((
      'setMuted',
      {
        'callId': next.callId,
        'muted': next.muted,
        'mute': mute,
        'unmute': unmute,
        'connected': next.connected,
      },
    ));
  }
  // Widening only ever adds the camera; turning it off again leaves the
  // service as it is (the type costs nothing unused, and dropping it would
  // need the app in front again for the next camera tap anyway).
  if (next.camera && (!sameCall || !prev!.camera)) {
    ops.add((
      'ensureCamera',
      {'callId': next.callId, 'connected': next.connected},
    ));
  }
  return ops;
}

/// Keeps Android's ongoing 1:1 call notification and its foreground service
/// in step with the call (see `CallNotificationBridge.kt`): the Mute/Unmute
/// action reads the mic's real state, and a camera turned on in a call that
/// rang as voice gets the camera added to the foreground service, without
/// which Android stops the camera as soon as the app leaves the screen.
///
/// The notification's Mute button reaches Dart as the plugin's
/// toggle-mute event (NativeCallHandler calls `toggleMute`); the new state
/// comes back through here.
class CallNotificationSync {
  CallNotificationSync._();

  static final CallNotificationSync instance = CallNotificationSync._();

  static const MethodChannel _channel =
      MethodChannel('monkeyhub/call_notification');

  CallService? _call;
  CallNotificationState? _sent;

  void attach(CallService call) {
    if (kIsWeb || !Platform.isAndroid) return;
    if (identical(_call, call)) return;
    _call?.removeListener(_sync);
    _call = call..addListener(_sync);
    _sync();
  }

  void _sync() {
    final call = _call;
    if (call == null) return;
    final next = callNotificationStateFor(
      session: call.session,
      localCamActive: call.localCamActive,
    );
    if (next == _sent) return;
    final prev = _sent;
    _sent = next;
    final l10n = _labels();
    for (final (method, args) in callNotificationOps(
      prev,
      next,
      mute: l10n.callScreenControlMute,
      unmute: l10n.callScreenControlUnmute,
    )) {
      unawaited(_channel.invokeMethod<Object?>(method, args).catchError(
        (Object e) {
          debugPrint('CallNotificationSync.$method: $e');
          return null;
        },
      ));
    }
  }

  /// The app's settled language (recorded by the root builder), English
  /// when it is not known yet.
  static AppLocalizations _labels() {
    final tag = DeviceReport.appLocaleTag;
    if (tag != null) {
      final parts = tag.split('-');
      String? script;
      String? country;
      for (final p in parts.skip(1)) {
        if (p.length == 4) {
          script = p;
        } else {
          country = p;
        }
      }
      try {
        return lookupAppLocalizations(Locale.fromSubtags(
          languageCode: parts.first,
          scriptCode: script,
          countryCode: country,
        ));
      } catch (_) {}
    }
    return lookupAppLocalizations(const Locale('en'));
  }
}
