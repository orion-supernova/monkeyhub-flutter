import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../backend/chat_api.dart';
import '../calls/native_call_handler.dart';
import '../env.dart';
import 'device_identity.dart';

/// Wraps OneSignal init and login/logout. Mirrors v02 PushNotificationManager.
///
/// On notification tap, calls [onOpenRoom] with the `roomId` payload key if
/// present. Backend's `notifications.sendMessagePush` includes:
///   data: { roomId, messageId, senderId, senderName, type }
class PushManager {
  PushManager._();
  static final PushManager instance = PushManager._();

  bool _initialized = false;
  void Function(String roomId)? _onOpenRoom;
  String? Function()? _activeRoomIdProvider;

  // iOS PushKit channel — installed in ios/Runner/AppDelegate.swift. Dart
  // calls `getToken` after login; the channel also pushes `onTokenUpdated`
  // when iOS rotates the token.
  static const MethodChannel _voipChannel = MethodChannel('monkeyhub/voip');
  // Android FCM channel — installed in MainActivity.kt. Mirrors the iOS
  // PushKit channel; Dart calls `getToken` after login. No rotation
  // callback — the next login picks up a refreshed token.
  static const MethodChannel _fcmChannel = MethodChannel('monkeyhub/fcm');
  ChatApi? _api;
  String? _userId;
  String? _deviceId;
  String? _deviceName;
  // Most recent iOS PushKit token seen via the `onTokenUpdated` callback.
  // PushKit can hand us the token before the user logs in (it arrives at
  // launch), so we stash it here and flush it during [login] — otherwise a
  // cold-launch token would be dropped and the device would never register a
  // VoIP token, forcing the backend onto the OneSignal-only path.
  String? _pendingVoipToken;

  /// OneSignal + native push tokens are only available on iOS / Android.
  /// Other platforms still participate in the device registry (for the
  /// "Move call here" pill) but skip the OneSignal path entirely.
  bool get _pushSupported => Platform.isIOS || Platform.isAndroid;

  /// Exposed so [CallService] can stamp the deviceId on accept/reject
  /// so the backend's `taken` signal includes a `byDeviceId` field —
  /// which lets the accepting device filter its own echo.
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  /// Call once at app startup. Safe to call multiple times.
  /// Bind a new room-open handler (call after the navigator is mounted).
  /// Safe to call any number of times — the latest wins.
  void setOnOpenRoom(void Function(String roomId) handler) {
    _onOpenRoom = handler;
  }

  /// Wire the backend API so [login] can upload VoIP / FCM tokens. Called
  /// from app.dart once `ChatApi` is constructed.
  void attachApi(ChatApi api) {
    _api = api;
  }

  /// Provide a callback that returns the currently-open room id (or null).
  /// Used by the foreground-display handler to suppress notifications for
  /// the chat the user is already viewing. Safe to call multiple times —
  /// the latest provider wins.
  void setActiveRoomIdProvider(String? Function() provider) {
    _activeRoomIdProvider = provider;
  }

  Future<void> initialize({
    void Function(String roomId)? onOpenRoom,
    ChatApi? api,
  }) async {
    if (onOpenRoom != null) _onOpenRoom = onOpenRoom;
    if (api != null) _api = api;
    if (_initialized) return;
    if (!_pushSupported) {
      _initialized = true; // mark so we don't re-run; OneSignal is a no-op here
      return;
    }
    final appId = Env.oneSignalAppId;
    if (appId.isEmpty) return;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      OneSignal.initialize(appId);
      // Ask for permission lazily — we don't want a prompt at first launch
      // when the user hasn't yet signed in. Settings screen can offer a
      // dedicated trigger later; for now request after login.
      OneSignal.Notifications.addClickListener(_onClick);
      OneSignal.Notifications.addForegroundWillDisplayListener(_onWillDisplay);
      // Watch for iOS PushKit token rotation. Forward the new token to the
      // backend if a user is currently logged in.
      _voipChannel.setMethodCallHandler((call) async {
        if (call.method == 'onTokenUpdated') {
          final args = (call.arguments as Map?) ?? const {};
          final token = args['token'] as String?;
          // Always remember the latest token, even if no user is logged in
          // yet — [login] flushes it. _uploadVoipToken is a no-op until a
          // user/deviceId exist, so this is the only thing that keeps a
          // pre-login token from being lost.
          if (token != null && token.isNotEmpty) _pendingVoipToken = token;
          await _uploadVoipToken(token);
          return null;
        }
        // Answer/decline on AppDelegate's fallback CallKit card (shown when
        // the flutter_callkit_incoming plugin wasn't registered in time to
        // handle a VoIP push) — bridge into the normal call flow. Events
        // that fired before this handler existed are drained separately via
        // `takePendingEvents` in NativeCallHandler.
        if (call.method == 'onFallbackAnswer' ||
            call.method == 'onFallbackDecline') {
          final args = (call.arguments as Map?) ?? const {};
          final callId = args['callId']?.toString();
          if (callId != null && callId.isNotEmpty) {
            if (call.method == 'onFallbackAnswer') {
              await NativeCallHandler.instance.handleFallbackAnswer(callId);
            } else {
              await NativeCallHandler.instance.handleFallbackDecline(callId);
            }
          }
          return null;
        }
        return null;
      });
      _initialized = true;
    } catch (e) {
      debugPrint('OneSignal init failed: $e');
    }
  }

  /// Bind this device to a Convex userId via `external_id`. Backend's
  /// `notifications.sendMessagePush` addresses pushes to external_id, so this
  /// is the link the server needs.
  Future<void> login(String userId) async {
    _userId = userId;
    _deviceId = await DeviceIdentity.ensure();
    _deviceName = await DeviceIdentity.displayName();
    if (_pushSupported && _initialized) {
      try {
        await OneSignal.login(userId);
        // Good time to prompt for permission (user has actively signed in).
        await OneSignal.Notifications.requestPermission(true);
      } catch (e) {
        debugPrint('OneSignal login failed: $e');
      }
    }
    // Upload native call tokens. Failures here are non-fatal — OneSignal
    // remains as a fallback on iOS/Android, and other platforms still
    // register their device row via [_registerNoPushDevice] below.
    if (Platform.isIOS || Platform.isAndroid) {
      await refreshTokens();
    } else {
      // macOS / Windows / Linux / Web — register the device row so the
      // active-call subscription can label this device in the pill,
      // even though there's no native push wake path.
      await _registerNoPushDevice();
    }
  }

  Future<void> _registerNoPushDevice() async {
    final userId = _userId;
    final api = _api;
    final deviceId = _deviceId;
    if (userId == null || api == null || deviceId == null) return;
    try {
      await api.registerDevice(
        userId: userId,
        deviceId: deviceId,
        platform: DeviceIdentity.platformTag(),
        deviceName: _deviceName,
      );
    } catch (e) {
      debugPrint('PushManager: registerDevice failed: $e');
    }
  }

  Future<void> _uploadVoipToken(String? token) async {
    final userId = _userId;
    final api = _api;
    final deviceId = _deviceId;
    if (userId == null ||
        api == null ||
        deviceId == null ||
        token == null ||
        token.isEmpty) {
      return;
    }
    try {
      await api.setVoipToken(
        userId: userId,
        deviceId: deviceId,
        platform: DeviceIdentity.platformTag(),
        token: token,
        deviceName: _deviceName,
        // The token's real APNs environment is fixed by the embedded
        // provisioning profile, not the Dart build mode — a development-
        // profiled Release build issues a *sandbox* token that kDebugMode
        // would mis-tag as production (→ APNs 400 → token cleared). Ask the
        // native side for the authoritative value; fall back to the build-
        // mode heuristic only if it's unavailable (e.g. App Store build).
        apnsEnv: await _resolveApnsEnv(),
      );
    } catch (e) {
      debugPrint('PushManager: setVoipToken failed: $e');
    }
  }

  /// Authoritative APNs environment from the embedded provisioning profile
  /// (via AppDelegate), falling back to the build-mode heuristic.
  Future<String> _resolveApnsEnv() async {
    try {
      final native =
          await _voipChannel.invokeMethod<String>('getApnsEnvironment');
      if (native == 'sandbox' || native == 'production') return native!;
    } catch (e) {
      debugPrint('PushManager: getApnsEnvironment failed: $e');
    }
    return kDebugMode ? 'sandbox' : 'production';
  }

  /// Re-fetch and re-upload native push tokens for the current session.
  /// Idempotent and safe to call any time — no-ops until a user/deviceId
  /// exist. Called on app resume so a token the backend cleared (e.g. after
  /// a transient APNs error) is restored without waiting for a cold login.
  Future<void> refreshTokens() async {
    if (_userId == null || _deviceId == null) return;
    if (Platform.isIOS) {
      try {
        final token = await _voipChannel.invokeMethod<String>('getToken') ??
            _pendingVoipToken;
        await _uploadVoipToken(token);
      } catch (e) {
        debugPrint('PushManager.refreshTokens: VoIP fetch failed: $e');
        if (_pendingVoipToken != null) {
          await _uploadVoipToken(_pendingVoipToken);
        }
      }
    } else if (Platform.isAndroid) {
      try {
        final token = await _fcmChannel.invokeMethod<String>('getToken');
        await _uploadFcmToken(token);
      } catch (e) {
        debugPrint('PushManager.refreshTokens: FCM fetch failed: $e');
      }
    }
  }

  Future<void> _uploadFcmToken(String? token) async {
    final userId = _userId;
    final api = _api;
    final deviceId = _deviceId;
    if (userId == null ||
        api == null ||
        deviceId == null ||
        token == null ||
        token.isEmpty) {
      return;
    }
    try {
      await api.setFcmToken(
        userId: userId,
        deviceId: deviceId,
        platform: DeviceIdentity.platformTag(),
        token: token,
        deviceName: _deviceName,
      );
    } catch (e) {
      debugPrint('PushManager: setFcmToken failed: $e');
    }
  }

  Future<void> logout() async {
    final userId = _userId;
    final deviceId = _deviceId;
    final api = _api;
    // Always clear the device row, regardless of platform — every
    // platform writes one at login (push-supported via set*Token,
    // others via registerDevice).
    if (userId != null && deviceId != null && api != null) {
      try {
        await api.clearDeviceToken(userId: userId, deviceId: deviceId);
      } catch (e) {
        debugPrint('PushManager.logout: clearDeviceToken failed: $e');
      }
    }
    _userId = null;
    if (_pushSupported && _initialized) {
      try {
        await OneSignal.logout();
      } catch (e) {
        debugPrint('OneSignal logout failed: $e');
      }
    }
  }

  /// Opt this device IN to receiving pushes. Call when user toggles
  /// notifications ON in settings.
  Future<void> optIn() async {
    if (!_pushSupported || !_initialized) return;
    try {
      OneSignal.User.pushSubscription.optIn();
    } catch (e) {
      debugPrint('OneSignal optIn failed: $e');
    }
  }

  /// Opt this device OUT of receiving pushes — does NOT delete the alias, so
  /// re-enabling later restores immediately.
  Future<void> optOut() async {
    if (!_pushSupported || !_initialized) return;
    try {
      OneSignal.User.pushSubscription.optOut();
    } catch (e) {
      debugPrint('OneSignal optOut failed: $e');
    }
  }

  Future<void> setBadge(int count) async {
    if (!_pushSupported || !_initialized) return;
    try {
      // OneSignal SDK manages badge via notification payload; setting from
      // client requires platform channels. No-op for now — let server push
      // payload include `ios_badgeType` / `ios_badgeCount`.
    } catch (_) {}
  }

  void _onClick(OSNotificationClickEvent e) {
    final data = e.notification.additionalData;
    final roomId = data?['roomId']?.toString();
    if (roomId != null && roomId.isNotEmpty) {
      _onOpenRoom?.call(roomId);
    }
  }

  void _onWillDisplay(OSNotificationWillDisplayEvent e) {
    final data = e.notification.additionalData;
    final roomId = data?['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    final active = _activeRoomIdProvider?.call();
    if (active == roomId) {
      // User is already inside this room — suppress the banner/heads-up.
      // The in-room subscription will deliver the message live.
      e.preventDefault();
    }
  }
}
