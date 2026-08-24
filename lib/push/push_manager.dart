import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, AppLifecycleState;

import '../backend/chat_api.dart';
import '../calls/native_call_handler.dart';
import '../env.dart';
import 'device_identity.dart';
import 'permission_latch.dart';
import 'web_push.dart';

/// This device's side of push notifications.
///
/// There is no push SDK. The app registers directly with APNs (iOS) and FCM
/// (Android), uploads the resulting tokens to Convex, and the backend talks to
/// Apple and Google itself — see backend/convex/push.ts. Everything visible is
/// rendered by our own native code, which is what makes grouping, collapse and
/// per-room dismissal possible.
///
/// Three channels, all installed natively:
///   monkeyhub/notifications  the alert token, the permission prompt, the
///                            visible room, and dismissal (iOS + Android)
///   monkeyhub/voip           the PushKit token, iOS only
///   monkeyhub/fcm            the FCM token, Android only
///
/// The payload keys this file reads (`roomId`, `kind`) are a cross-language
/// contract with push.ts, AppDelegate.swift, ChatNotifications.kt and
/// web/mh-push-sw.js, pinned by test/push_payload_contract_test.dart.
class PushManager {
  PushManager._();
  static final PushManager instance = PushManager._();

  bool _initialized = false;
  void Function(String roomId)? _onOpenRoom;
  VoidCallback? _onOpenRequests;
  VoidCallback? _onOpenGames;
  String? Function()? _activeRoomIdProvider;

  /// The language the app SETTLED on, reported by app.dart's `MaterialApp`
  /// builder — which is the only place the answer exists, since neither the
  /// device language nor the user's override is it on its own.
  ///
  /// Held rather than read on demand because nothing outside a `BuildContext`
  /// can ask Flutter what it resolved.
  String? _appLocale;

  /// What [syncDeviceContext] last successfully wrote, so a resume that
  /// changed nothing costs no round trip. Null until the first upload.
  String? _syncedLocale;
  int? _syncedTzOffset;

  // iOS PushKit channel — installed in ios/Runner/AppDelegate.swift. Dart
  // calls `getToken` after login; the channel also pushes `onTokenUpdated`
  // when iOS rotates the token.
  static const MethodChannel _voipChannel = MethodChannel('monkeyhub/voip');
  // Android FCM channel — installed in MainActivity.kt. Mirrors the iOS
  // PushKit channel; Dart calls `getToken` after login. No rotation
  // callback — the next login picks up a refreshed token.
  static const MethodChannel _fcmChannel = MethodChannel('monkeyhub/fcm');
  // The alert-push channel: token, permission, active room, dismissal.
  // Installed in AppDelegate.swift and MainActivity.kt.
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
  // VoIP token, so the phone would never ring.
  String? _pendingVoipToken;
  // Same story for the ordinary APNs token: iOS issues it moments after
  // launch, long before anyone signs in.
  String? _pendingApnsToken;

  /// Push tokens are only available on iOS / Android. Other platforms still
  /// participate in the device registry (for the "Move call here" pill) but
  /// have no wake-up path — desktop relies on the live subscription, and web
  /// registers a Web Push subscription separately (see lib/push/web_push.dart).
  ///
  /// `kIsWeb` is a compile-time const, so on web the `&&` short-circuits
  /// before `Platform.*` (dart:io) is touched — evaluating it on web throws.
  bool get _pushSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Exposed so [CallService] can stamp the deviceId on accept/reject
  /// so the backend's `taken` signal includes a `byDeviceId` field —
  /// which lets the accepting device filter its own echo.
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  /// Where a friend-request / approval notification tap should land. Those
  /// pushes have no room to open, so without this a tap just raised the app
  /// and left the user wherever they were.
  void setOnOpenRequests(VoidCallback handler) {
    _onOpenRequests = handler;
  }

  /// Where a daily-games nudge tap should land: the Feed, with the games shelf
  /// open. Same shape as [setOnOpenRequests] — the push carries no room, so
  /// without this a tap merely raises the app.
  void setOnOpenGames(VoidCallback handler) {
    _onOpenGames = handler;
  }

  /// Bind a new room-open handler (call after the navigator is mounted).
  /// Safe to call any number of times — the latest wins.
  void setOnOpenRoom(void Function(String roomId) handler) {
    _onOpenRoom = handler;
  }

  /// Wire the backend API so [login] can upload push tokens. Called from
  /// app.dart once `ChatApi` is constructed.
  void attachApi(ChatApi api) {
    _api = api;
  }

  /// Provide a callback that returns the currently-open room id (or null).
  ///
  /// Retained for the in-app callers that still ask. Foreground suppression
  /// itself no longer reads this: the native side needs the answer inside a
  /// completion handler it must not block, so [setActiveRoom] pushes the value
  /// down instead of the platform pulling it back up.
  void setActiveRoomIdProvider(String? Function() provider) {
    _activeRoomIdProvider = provider;
  }

  /// Tell the platform which room is on screen, so a push for a conversation
  /// the user is already reading doesn't produce a banner on top of it.
  ///
  /// Pass null when leaving a room. Cheap enough to call on every open/close.
  Future<void> setActiveRoom(String? roomId) async {
    if (kIsWeb) return;
    try {
      await _notifChannel.invokeMethod('setActiveRoom', {'roomId': roomId});
    } on MissingPluginException {
      // Desktop — no notification surface to suppress.
    } catch (e) {
      debugPrint('PushManager.setActiveRoom failed: $e');
    }
  }

  Future<void> initialize({
    void Function(String roomId)? onOpenRoom,
    ChatApi? api,
  }) async {
    if (onOpenRoom != null) _onOpenRoom = onOpenRoom;
    if (api != null) _api = api;
    if (_initialized) return;
    if (!_pushSupported) {
      _initialized = true; // nothing native to wire up on desktop/web
      // Retire the previous vendor's service worker, which would otherwise
      // keep its own live subscription and deliver alongside ours. No-op
      // everywhere but the browser.
      WebPush.unregisterLegacy();
      return;
    }
    try {
      _notifChannel.setMethodCallHandler(_handleNotifCall);
      // Drain anything that fired before this handler existed — the APNs token
      // arrives at launch, and a tap can BE the launch. Calling in also flips
      // the native side to direct delivery from here on.
      await _drainPendingNotifEvents();

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
        if (call.method == 'onProviderReset') {
          // The system reset AppDelegate's fallback CXProvider — every
          // native card is gone; tear any live call fully down so the
          // WebRTC session (and mic) doesn't survive headless.
          await NativeCallHandler.instance.handleProviderReset();
          return null;
        }
        return null;
      });
      _initialized = true;
    } catch (e) {
      debugPrint('PushManager init failed: $e');
    }
  }

  /// Handles the notification channel's calls from native: the alert token
  /// and the two tap destinations.
  Future<dynamic> _handleNotifCall(MethodCall call) async {
    switch (call.method) {
      case 'onApnsTokenUpdated':
        final args = (call.arguments as Map?) ?? const {};
        final token = args['token'] as String?;
        if (token != null && token.isNotEmpty) _pendingApnsToken = token;
        await _uploadApnsToken(token);
        return null;
      case 'onOpenRoom':
        final args = (call.arguments as Map?) ?? const {};
        final roomId = args['roomId']?.toString();
        if (roomId != null && roomId.isNotEmpty) _onOpenRoom?.call(roomId);
        return null;
      case 'onOpenRequests':
        _onOpenRequests?.call();
        return null;
      case 'onOpenGames':
        _onOpenGames?.call();
        return null;
    }
    return null;
  }

  /// Replay events the platform queued before Dart had a handler. Each entry
  /// is the original argument map plus a `method` key.
  Future<void> _drainPendingNotifEvents() async {
    try {
      final events =
          await _notifChannel.invokeMethod<List<dynamic>>('takePendingEvents');
      for (final raw in events ?? const []) {
        final map = (raw as Map).cast<dynamic, dynamic>();
        final method = map['method']?.toString();
        if (method == null) continue;
        await _handleNotifCall(MethodCall(method, map));
      }
    } on MissingPluginException {
      // Desktop — the channel isn't installed there.
    } catch (e) {
      debugPrint('PushManager: takePendingEvents failed: $e');
    }
  }

  /// Bind this device's push tokens to a Convex userId.
  Future<void> login(String userId) async {
    _userId = userId;
    _deviceId = await DeviceIdentity.ensure();
    _deviceName = await DeviceIdentity.displayName();
    // FIRST, ahead of the permission prompt and the token fetch, because both
    // of those can block for as long as they like — the prompt waits on a human
    // and has been seen to never return at all on a headless cold start (see
    // app.dart's note on this method). This was the LAST line of the method,
    // which made the one fact the daily nudge cannot work without the first
    // thing a slow login dropped. It creates the device row on its own, so
    // nothing below depends on having run first.
    await syncDeviceContext(force: true);
    if (_pushSupported && _initialized) {
      await _maybeRequestNotificationPermission();
    }
    // Upload push tokens. Failures here are non-fatal — the app still works,
    // it just won't be woken; the next resume retries.
    // kIsWeb first so Platform.* (dart:io) is never evaluated on web, where it
    // throws — web falls through to the no-push registration path.
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await refreshTokens();
    } else {
      // macOS / Windows / Linux / Web — register the device row so the
      // active-call subscription can label this device in the pill,
      // even though there's no native push wake path.
      await _registerNoPushDevice();
      // …and on web, additionally claim a Web Push subscription so a closed
      // tab still gets banners.
      await _registerWebPush();
    }
  }

  /// Subscribe this browser to Web Push and hand the backend what it needs to
  /// encrypt for it.
  ///
  /// Silently does nothing when the user hasn't granted notification
  /// permission — [WebPush.subscribe] refuses rather than prompting, because a
  /// permission prompt belongs to a user gesture (see `App._primeAlerts`), not
  /// to sign-in. The next login or gesture picks it up.
  Future<void> _registerWebPush() async {
    if (!kIsWeb) return;
    final userId = _userId;
    final api = _api;
    final deviceId = _deviceId;
    if (userId == null || api == null || deviceId == null) return;
    final key = Env.vapidPublicKey;
    if (key.isEmpty) {
      debugPrint('PushManager: VAPID_PUBLIC_KEY unset — web push disabled');
      return;
    }
    try {
      final sub = await WebPush.subscribe(key);
      if (sub == null) return;
      await api.setWebPushSubscription(
        userId: userId,
        deviceId: deviceId,
        endpoint: sub.endpoint,
        p256dh: sub.p256dh,
        auth: sub.auth,
        deviceName: _deviceName,
      );
    } catch (e) {
      debugPrint('PushManager: web push registration failed: $e');
    }
  }

  /// Re-attempt the web subscription after the user grants permission from a
  /// gesture. No-op off web, and idempotent — the browser hands back the same
  /// subscription when the key matches.
  Future<void> registerWebPushAfterPermission() => _registerWebPush();

  /// Asks for the OS notification permission at most once per process, and
  /// only when asking can still produce a prompt. The rule, and the
  /// battery-draining loop it exists to prevent, are documented on
  /// [PermissionLatch] — it lives in its own file because that invariant
  /// deserves a test, and this one is unreachable from a unit test.
  ///
  /// The native side refuses independently once
  /// `shouldShowRequestPermissionRationale` says an ask would be pointless;
  /// this is the belt to that pair of braces.
  late final PermissionLatch _permission = PermissionLatch(
    readStatus: () =>
        _notifChannel.invokeMethod<String>('authorizationStatus'),
    request: () => _notifChannel.invokeMethod<bool>('requestAuthorization'),
    // With the pre-warmed engine, login() also runs during headless background
    // launches (a VoIP-push cold start), where prompting is impossible; the
    // next foreground resume re-invokes this via [refreshTokens].
    isForeground: () {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return lifecycle == null || lifecycle == AppLifecycleState.resumed;
    },
  );

  Future<void> _maybeRequestNotificationPermission() => _permission.maybeAsk();

  /// This device's UTC offset, right now, in minutes.
  ///
  /// Read at the moment of use rather than cached: it moves under us on a
  /// flight and twice a year for daylight saving, and the whole value of
  /// sending it with a token is that the token's row is never the stale one.
  int get _tzOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

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
        // Stamped with the token, and duplicated from [syncDeviceContext] on
        // purpose — see the note there. A row with a credential and no time
        // zone is one the daily nudge can push to and cannot find.
        locale: _appLocale,
        tzOffsetMinutes: _tzOffsetMinutes,
      );
    } catch (e) {
      debugPrint('PushManager: setVoipToken failed: $e');
    }
  }

  /// The ordinary APNs token — banners, badges and the silent dismiss. A
  /// different token from the PushKit one above, on a different topic, and
  /// they must never be swapped: the backend would get a 400 and clear the
  /// good one.
  Future<void> _uploadApnsToken(String? token) async {
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
      await api.setApnsToken(
        userId: userId,
        deviceId: deviceId,
        platform: DeviceIdentity.platformTag(),
        token: token,
        deviceName: _deviceName,
        apnsEnv: await _resolveApnsEnv(),
        locale: _appLocale,
        tzOffsetMinutes: _tzOffsetMinutes,
      );
    } catch (e) {
      debugPrint('PushManager: setApnsToken failed: $e');
    }
  }

  /// Authoritative APNs environment from the embedded provisioning profile
  /// (via AppDelegate), falling back to the build-mode heuristic. Both iOS
  /// tokens are minted under the same profile, so one answer covers both.
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

  /// Re-fetch and re-upload push tokens for the current session.
  /// Idempotent and safe to call any time — no-ops until a user/deviceId
  /// exist. Called on app resume so a token the backend cleared (e.g. after
  /// a transient APNs error) is restored without waiting for a cold login.
  Future<void> refreshTokens() async {
    if (!_pushSupported) return; // web/desktop have no native token
    if (_userId == null) return;
    // Repair a device id that [login] never got. It reads the keychain, which
    // throws `errSecInteractionNotAllowed (-25308)` on a locked phone — the
    // ordinary state during the headless VoIP cold start this method's own
    // doc describes. `_deviceId` then stayed null for the process lifetime and
    // every upload path below early-returned on it, so tokens were never
    // registered at all and the resume that was supposed to fix it bailed on
    // the same null. We are foreground here, so the read succeeds.
    if (_deviceId == null) {
      try {
        _deviceId = await DeviceIdentity.ensure();
        _deviceName ??= await DeviceIdentity.displayName();
      } catch (e) {
        debugPrint('PushManager.refreshTokens: device id still unavailable: $e');
        return;
      }
    }
    // Covers the headless-login case: if the permission ask was skipped
    // because the app wasn't foregrounded, retry it now (resume path).
    // No-op once permission is determined — the OS shows the prompt only once.
    unawaited(_maybeRequestNotificationPermission());
    if (Platform.isIOS) {
      // Two independent tokens. A failure to read one must not skip the other:
      // losing the alert token silences chat, losing the PushKit token stops
      // the phone ringing, and they fail for different reasons.
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
      try {
        final token =
            await _notifChannel.invokeMethod<String>('getApnsToken') ??
                _pendingApnsToken;
        await _uploadApnsToken(token);
      } catch (e) {
        debugPrint('PushManager.refreshTokens: APNs fetch failed: $e');
        if (_pendingApnsToken != null) {
          await _uploadApnsToken(_pendingApnsToken);
        }
      }
    } else if (Platform.isAndroid) {
      // One token covers both ringing and banners on Android.
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
        locale: _appLocale,
        tzOffsetMinutes: _tzOffsetMinutes,
      );
    } catch (e) {
      debugPrint('PushManager: setFcmToken failed: $e');
    }
  }

  Future<void> logout() async {
    final userId = _userId;
    final deviceId = _deviceId;
    final api = _api;
    // Deleting the device row is the whole logout: it takes every credential
    // with it, so nothing addressed to this user can reach this device again.
    // Every platform writes one at login (push-capable via set*Token, others
    // via registerDevice).
    if (userId != null && deviceId != null && api != null) {
      try {
        await api.clearDeviceToken(userId: userId, deviceId: deviceId);
      } catch (e) {
        debugPrint('PushManager.logout: clearDeviceToken failed: $e');
      }
    }
    _userId = null;
    // Forget what was uploaded, not what was resolved: the language is still
    // whatever this app is running in, but the row it was written to is gone,
    // so the next account must write its own rather than being deduped against
    // the previous one's.
    _syncedLocale = null;
    _syncedTzOffset = null;
    await setActiveRoom(null);
  }

  /// Opt this device IN to receiving pushes. Call when the user toggles
  /// notifications ON in settings.
  ///
  /// A stored preference rather than discarding the token: the token stays
  /// valid, so turning it back on is instant instead of waiting for the OS to
  /// mint a new one. Calls still ring either way — muting chat is not
  /// consenting to miss the phone.
  Future<void> optIn() => _setPushEnabled(true);

  /// Opt this device OUT of alert pushes.
  Future<void> optOut() => _setPushEnabled(false);

  Future<void> _setPushEnabled(bool enabled) async {
    final userId = _userId;
    final api = _api;
    final deviceId = _deviceId;
    if (userId == null || api == null || deviceId == null) return;
    try {
      await api.setPushEnabled(
        userId: userId,
        deviceId: deviceId,
        enabled: enabled,
      );
    } catch (e) {
      debugPrint('PushManager: setPushEnabled($enabled) failed: $e');
    }
  }

  /// The daily-games reminder switch, per device.
  ///
  /// Its own upload rather than a flag on [optIn]/[optOut] because it means
  /// something narrower: stop the once-a-day nudge, keep everything else.
  Future<void> setGameReminders(bool enabled) async {
    final userId = _userId;
    final api = _api;
    final deviceId = _deviceId;
    if (userId == null || api == null || deviceId == null) return;
    try {
      await api.setGameReminders(
        userId: userId,
        deviceId: deviceId,
        enabled: enabled,
      );
    } catch (e) {
      debugPrint('PushManager: setGameReminders($enabled) failed: $e');
    }
  }

  /// Record the language the app resolved, and upload it if it moved.
  ///
  /// Called from app.dart's `MaterialApp` builder, which reruns on every
  /// language change — an in-app override from the language screen AND a system
  /// language the user changed in Settings, since either one rebuilds it. That
  /// is why this is a push from the widget tree rather than a read out of
  /// [SettingsStore]: the stored override is null for most people, and the
  /// device language may not be one the app ships at all.
  void noteAppLocale(String tag) {
    if (_appLocale == tag) return;
    _appLocale = tag;
    unawaited(syncDeviceContext());
  }

  /// Upload this device's language and UTC offset, if either has changed.
  ///
  /// The backend writes the daily nudge itself, so both are its inputs: the
  /// language decides what the notification says, the offset decides when noon
  /// is here (see backend/convex/dailyNudge.ts).
  ///
  /// Called on login, on every resume, when the day rolls over, and whenever
  /// the resolved language changes — deliberately more often than necessary,
  /// because the two facts move for unrelated reasons and each has a failure
  /// mode the other cannot cover. A language change without a resume is
  /// ordinary. A time-zone change without a language change is a flight, and
  /// the resume as the phone comes off airplane mode is exactly when we learn
  /// about it. Daylight saving is the same shape, twice a year.
  ///
  /// Cheap enough to call that freely because it compares against what it last
  /// wrote and returns without a round trip when nothing moved — which is the
  /// overwhelmingly common case.
  ///
  /// The two values are always read fresh and sent together, so neither can
  /// carry the other's staleness: changing language never re-stamps an old
  /// offset, and landing in a new zone never rewrites the language.
  ///
  /// Every token upload stamps the same two values as well ([ChatApi
  /// .setApnsToken] and friends), which is not redundancy for its own sake.
  /// This method is what keeps the offset CURRENT — it is the only thing that
  /// re-runs when a plane lands or the clocks go back. The token setters are
  /// what keep it PRESENT: the daily nudge finds its audience through
  /// `userDevices.by_tz_offset`, so a row with a live token and no offset is
  /// one the backend can push to and cannot see, and the only call that could
  /// have filled it in is this one — which a login that hung, or an app build
  /// older than the feature, never made.
  ///
  /// [_appLocale] can still be null the first time this runs at cold start, on
  /// a login that beats the first frame. That is fine and deliberate: an absent
  /// locale is not written, the notification falls back to English for that one
  /// day, and `noteAppLocale` sends the real answer as soon as the widget tree
  /// resolves it. The offset — the value that decides whether this device is
  /// reachable at all — never depends on the frame.
  Future<void> syncDeviceContext({bool force = false}) async {
    final userId = _userId;
    final api = _api;
    if (userId == null || api == null) return;
    var deviceId = _deviceId;
    if (deviceId == null) {
      // Same repair as [refreshTokens]: a locked-phone keychain read at cold
      // start can leave this null for the process lifetime otherwise.
      try {
        deviceId = _deviceId = await DeviceIdentity.ensure();
        _deviceName ??= await DeviceIdentity.displayName();
      } catch (e) {
        debugPrint('PushManager.syncDeviceContext: no device id: $e');
        return;
      }
    }
    final locale = _appLocale;
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    if (!force && locale == _syncedLocale && tz == _syncedTzOffset) return;
    try {
      await api.setDeviceContext(
        userId: userId,
        deviceId: deviceId,
        platform: DeviceIdentity.platformTag(),
        deviceName: _deviceName,
        locale: locale,
        tzOffsetMinutes: tz,
      );
      _syncedLocale = locale;
      _syncedTzOffset = tz;
    } catch (e) {
      // Left unrecorded on failure, so the next resume retries rather than
      // believing a value the server never received.
      debugPrint('PushManager: setDeviceContext failed: $e');
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
      await _notifChannel.invokeMethod('dismissRoom', {'roomId': roomId});
    } on MissingPluginException {
      // Platform not wired (macOS/Windows/Linux) — nothing to dismiss there.
    } catch (e) {
      debugPrint('dismissRoomNotifications failed: $e');
    }
  }

  /// Remove specific notifications by the identifier the server used as the
  /// collapse id — which is the messageId. Used when a message is deleted.
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

  /// The room the app believes is on screen, per the provider app.dart
  /// installed. Kept for callers that want to reason about it in Dart; the
  /// native suppression path uses [setActiveRoom] instead.
  String? get activeRoomId => _activeRoomIdProvider?.call();
}
