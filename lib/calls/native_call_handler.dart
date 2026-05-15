import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'call_models.dart';
import 'call_service.dart';

/// Bridges flutter_callkit_incoming (native iOS CallKit / Android
/// ConnectionService) into [CallService]. Single global subscription
/// installed at app start — events are coarse enough that we don't need
/// per-call wiring.
///
/// Event flow:
///   VoIP push lands → AppDelegate.swift (iOS) or the package's FCM hook
///   (Android) shows the native incoming UI → user taps accept/decline →
///   the package emits an event here → we call into CallService.
class NativeCallHandler {
  NativeCallHandler._();
  static final NativeCallHandler instance = NativeCallHandler._();

  bool _started = false;

  // CallKit (iOS) force-unwraps `UUID(uuidString: data.uuid)` in
  // CallManager.swift:26 — passing anything that isn't a proper RFC-4122
  // UUID crashes the app. Our Convex callIds are not UUIDs, so we mint a
  // UUIDv4 the first time we see each callId and reuse it across lifecycle
  // events (start → connected → end).
  final Map<String, String> _uuidByCallId = {};
  final Random _random = Random.secure();

  // When we ourselves call `FlutterCallkitIncoming.endAllCalls()` (driven
  // by WebRTC teardown), the package fires ACTION_CALL_ENDED back. We
  // rely on CallService.endCall() being idempotent — calling it again
  // after teardown is a no-op, so we don't need to dedup the echo.

  // iOS Simulator's CallKit is unreliable: it fires CXEndCallAction
  // spuriously right after CXStartCallAction, which our listener used to
  // interpret as "user ended the call" and cancel the outgoing call before
  // the callee could accept. Skipping CallKit on simulator avoids that —
  // the in-app call UI is sufficient for dev testing.
  //
  // Detection: env vars like SIMULATOR_DEVICE_NAME aren't exposed to the
  // Flutter runtime inside simulator app processes. But the resolved
  // executable always lives under `.../CoreSimulator/Devices/...` on
  // simulator and `.../var/containers/Bundle/Application/...` on real
  // hardware, so the path substring is reliable.
  late final bool _isIosSimulator = _detectIosSimulator();

  static bool _detectIosSimulator() {
    if (!Platform.isIOS) return false;
    return Platform.resolvedExecutable.contains('/CoreSimulator/');
  }

  String _uuidFor(String callId) =>
      _uuidByCallId.putIfAbsent(callId, _mintUuidV4);

  String _mintUuidV4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    String h(int i, int j) => b
        .sublist(i, j)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  void start() {
    if (_started) return;
    _started = true;
    FlutterCallkitIncoming.onEvent.listen(_onEvent);
  }

  Future<void> _onEvent(CallEvent? event) async {
    if (event == null) return;
    // CallKit on simulator is unreliable and we don't show its UI there —
    // ignore any stray events it fires to avoid hijacking the in-app flow.
    if (_isIosSimulator) return;
    final service = CallService.instance;
    debugPrint('NativeCallHandler: ${event.event} body=${event.body}');
    switch (event.event) {
      case Event.actionCallAccept:
        // Flag the service BEFORE awaiting acceptIncoming so:
        //   1. `_CallOverlay` skips the in-app IncomingCallScreen and
        //      routes the user straight to CallScreen.
        //   2. If the offer signal hasn't arrived yet (rare race when
        //      CallKit fires faster than the Convex realtime subscription),
        //      `_onRemoteOffer` will auto-fire acceptIncoming later.
        service.markAcceptedNatively();
        await service.acceptIncoming();
        break;
      case Event.actionCallDecline:
        await service.reject();
        break;
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        // service.endCall() is idempotent — if this is the echo of our
        // own endNative() call, the session is already null and this is
        // a harmless no-op.
        await service.endCall();
        break;
      case Event.actionCallToggleMute:
        await service.toggleMute();
        break;
      case Event.actionCallToggleHold:
        // Not implemented — we don't expose hold yet.
        break;
      default:
        // Ignore the lifecycle bookkeeping events (start, callback, etc.).
        break;
    }
  }

  /// Show the system "outgoing call" affordance (iOS green call indicator,
  /// Recents entry, Bluetooth/AirPods audio routing). Called by
  /// [CallService.initiate] right before sending the offer signal.
  Future<void> showOutgoing({
    required String callId,
    required String peerName,
    required CallMediaKind kind,
  }) async {
    if (_isIosSimulator) return;
    final params = CallKitParams(
      id: _uuidFor(callId),
      nameCaller: peerName,
      handle: peerName,
      type: kind == CallMediaKind.video ? 1 : 0,
      ios: const IOSParams(handleType: 'generic'),
    );
    try {
      await FlutterCallkitIncoming.startCall(params);
    } catch (e) {
      debugPrint('NativeCallHandler.showOutgoing failed: $e');
    }
  }

  /// Dismiss whichever native UI is currently showing. We use
  /// `endAllCalls()` instead of targeting by UUID because PushKit-driven
  /// incoming calls have their UUID minted in AppDelegate.swift and Dart
  /// never sees it — so a UUID-targeted dismiss would miss those.
  /// We only ever have one active call at a time, so clearing everything
  /// is the right behavior.
  Future<void> endNative(String callId) async {
    if (_isIosSimulator) return;
    _uuidByCallId.remove(callId);
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('NativeCallHandler.endNative failed: $e');
    }
  }

  /// Mirror the WebRTC "active" state to CallKit so the system call timer
  /// starts ticking and the audio session is correctly classified.
  Future<void> markConnected(String callId) async {
    if (_isIosSimulator) return;
    final uuid = _uuidByCallId[callId];
    if (uuid == null) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(uuid);
    } catch (e) {
      debugPrint('NativeCallHandler.markConnected failed: $e');
    }
  }
}
