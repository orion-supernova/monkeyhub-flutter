import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, AppLifecycleState;
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
  VoidCallback? _onOpenRequests;
  String? Function()? _activeRoomIdProvider;

  // iOS PushKit channel — installed in ios/Runner/AppDelegate.swift. Dart
  // calls `getToken` after login; the channel also pushes `onTokenUpdated`
  // when iOS rotates the token.
  static const MethodChannel _voipChannel = MethodChannel('monkeyhub/voip');
  // Android FCM channel — installed in MainActivity.kt. Mirrors the iOS
  // PushKit channel; Dart calls `getToken` after login. No rotation
  // callback — the next login picks up a refreshed token.
  static const MethodChannel _fcmChannel = MethodChannel('monkeyhub/fcm');
  // Local notification-shade control. The server can cancel a push only while
  // it's still queued; once a device has displayed it, removing it is
  // necessarily a client-side act. Installed in ios/Runner/AppDelegate.swift.
  static const MethodChannel _notifChannel =
      MethodChannel('monkeyhub/notifications');
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
  ///
  /// `kIsWeb` is a compile-time const, so on web the `&&` short-circuits
  /// before `Platform.*` (dart:io) is touched — evaluating it on web throws.
  bool get _pushSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Exposed so [CallService] can stamp the deviceId on accept/reject
  /// so the backend's `taken` signal includes a `byDeviceId` field —
  /// which lets the accepting device filter its own echo.
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  /// Call once at app startup. Safe to call multiple times.
  /// Bind a new room-open handler (call after the navigator is mounted).
  /// Safe to call any number of times — the latest wins.
  /// Where a friend-request / approval notification tap should land. Those
  /// pushes have no room to open, so without this a tap just raised the app
  /// and left the user wherever they were.
  void setOnOpenRequests(VoidCallback handler) {
    _onOpenRequests = handler;
  }

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
        await _maybeRequestNotificationPermission();
      } catch (e) {
        debugPrint('OneSignal login failed: $e');
      }
    }
    // Upload native call tokens. Failures here are non-fatal — OneSignal
    // remains as a fallback on iOS/Android, and other platforms still
    // register their device row via [_registerNoPushDevice] below.
    // kIsWeb first so Platform.* (dart:io) is never evaluated on web, where it
    // throws — web falls through to the no-push registration path.
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await refreshTokens();
    } else {
      // macOS / Windows / Linux / Web — register the device row so the
      // active-call subscription can label this device in the pill,
      // even though there's no native push wake path.
      await _registerNoPushDevice();
    }
  }

  /// Request the OS notification permission — but only when the app is
  /// actually in the foreground. With the pre-warmed engine, login() also
  /// runs during headless background launches (VoIP push cold start),
  /// where prompting is impossible/undesirable; the next foreground resume
  /// re-invokes this via [refreshTokens].
  ///
  /// `fallbackToSettings` is deliberately FALSE: passing true makes
  /// OneSignal pop its own "notifications are off — go to Settings" alert,
  /// which races the first-time OS prompt and appears even right after the
  /// user tapped Allow. A Settings redirect belongs behind an explicit
  /// re-enable button, never the first ask.
  ///
  /// ASKING IS ONE-SHOT, and that is load-bearing rather than tidiness.
  /// `requestPermission` is not a passive query: OneSignal's Android SDK
  /// early-returns only when the permission is already granted, and otherwise
  /// starts `com.onesignal.core.activities.PermissionsActivity`. Starting an
  /// activity pauses MainActivity, so Flutter reports `inactive`; the activity
  /// finishes (instantly, once Android has stopped showing the sheet for a
  /// twice-denied permission) and we get `resumed` — which is the very event
  /// [App.didChangeAppLifecycleState] answers by scheduling the foreground
  /// sync that calls [refreshTokens], which called this. That is a closed
  /// loop: a captured session on a Galaxy S24 shows ~30 resumed/inactive flips
  /// in 23 seconds, each one firing a `voipTokens:setFcmToken` write and a
  /// `family:getFamilyContext` read, forever, on battery.
  ///
  /// It only ever reproduced on "some Android devices" because the SDK's
  /// early return means a device that GRANTED notifications never enters the
  /// loop at all. Denial is what arms it — and denial is ordinary on Android
  /// 13+, where POST_NOTIFICATIONS is a runtime permission.
  ///
  /// So: ask at most once per process, and only when asking can still produce
  /// a sheet.
  bool _permissionSettled = false;

  Future<void> _maybeRequestNotificationPermission() async {
    if (_permissionSettled) return;
    // Not latched: a headless background launch (VoIP push cold start) can't
    // prompt, and must still be able to ask on a later real foreground.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    // Latched here, before the first await rather than next to the request:
    // every await below yields, and an unlatched window is the whole of what a
    // re-entrant caller needs to start a second prompt. The prompt itself
    // pauses and resumes the app, so that caller is not hypothetical.
    _permissionSettled = true;
    try {
      // Already granted — nothing to ask for, and the SDK would no-op anyway.
      if (OneSignal.Notifications.permission) return;
      // Permanently denied. The OS will not show the sheet again, so a request
      // buys nothing and costs the pause/resume churn described above.
      // Re-enabling from here is the Settings redirect that belongs behind an
      // explicit button, not an implicit resume.
      if (!await OneSignal.Notifications.canRequest()) return;
      await OneSignal.Notifications.requestPermission(false);
    } catch (e) {
      // The channel failed rather than the user answering, so nothing was
      // actually decided. Unlatch so a later foreground can try once more —
      // being permanently silent after one transient failure is the worse of
      // the two outcomes, and the resume throttle in [App] now caps a repeated
      // failure at one attempt per interval instead of a storm.
      _permissionSettled = false;
      debugPrint('PushManager: requestPermission failed: $e');
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
    if (!_pushSupported) return; // web/other: no VoIP/FCM tokens, no OneSignal
    if (_userId == null || _deviceId == null) return;
    // Covers the headless-login case: if the permission ask was skipped
    // because the app wasn't foregrounded, retry it now (resume path).
    // No-op once permission is determined — iOS shows the prompt only once.
    unawaited(_maybeRequestNotificationPermission());
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

  /// Pull this room's already-delivered notifications out of the shade.
  ///
  /// Called when the user opens/reads a room. The server also fires a silent
  /// dismiss push for the user's *other* devices, but this device doesn't need
  /// to wait for a round trip — and on iOS a silent push wouldn't arrive at
  /// all if the app had been force-quit.
  Future<void> dismissRoomNotifications(String roomId) async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        // Pairs with the `android_group` the backend stamps on every message
        // push. This is Android-only in the SDK and self-guards.
        await OneSignal.Notifications.removeGroupedNotifications(roomId);
        return;
      }
      await _notifChannel.invokeMethod('dismissRoom', {'roomId': roomId});
    } on MissingPluginException {
      // Platform not wired (macOS/Windows/Linux) — nothing to dismiss there.
    } catch (e) {
      debugPrint('dismissRoomNotifications failed: $e');
    }
  }

  /// Remove specific notifications by the identifier the server sent as
  /// `collapse_id` — which is the messageId. Used when a message is deleted.
  Future<void> dismissNotifications(List<String> ids) async {
    if (kIsWeb || ids.isEmpty) return;
    try {
      await _notifChannel.invokeMethod('dismiss', {'ids': ids});
    } on MissingPluginException {
      // Same as above.
    } catch (e) {
      debugPrint('dismissNotifications failed: $e');
    }
  }

  void _onClick(OSNotificationClickEvent e) {
    final data = e.notification.additionalData;
    final roomId = data?['roomId']?.toString();
    if (roomId != null && roomId.isNotEmpty) {
      _onOpenRoom?.call(roomId);
      return;
    }
    // Friend request / approval — no room, so route to the requests list.
    if (data?['kind']?.toString() == 'approval') {
      _onOpenRequests?.call();
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
