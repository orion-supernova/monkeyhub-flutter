import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../env.dart';

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

  bool get _supported => Platform.isIOS || Platform.isAndroid;

  /// Call once at app startup. Safe to call multiple times.
  Future<void> initialize({void Function(String roomId)? onOpenRoom}) async {
    _onOpenRoom = onOpenRoom;
    if (_initialized) return;
    if (!_supported) return;
    final appId = Env.oneSignalAppId;
    if (appId.isEmpty) return;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      OneSignal.initialize(appId);
      // Ask for permission lazily — we don't want a prompt at first launch
      // when the user hasn't yet signed in. Settings screen can offer a
      // dedicated trigger later; for now request after login.
      OneSignal.Notifications.addClickListener(_onClick);
      _initialized = true;
    } catch (e) {
      debugPrint('OneSignal init failed: $e');
    }
  }

  /// Bind this device to a Convex userId via `external_id`. Backend's
  /// `notifications.sendMessagePush` addresses pushes to external_id, so this
  /// is the link the server needs.
  Future<void> login(String userId) async {
    if (!_supported || !_initialized) return;
    try {
      await OneSignal.login(userId);
      // Now is a good time to prompt for permission (user has actively signed in).
      await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('OneSignal login failed: $e');
    }
  }

  Future<void> logout() async {
    if (!_supported || !_initialized) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logout failed: $e');
    }
  }

  Future<void> setBadge(int count) async {
    if (!_supported || !_initialized) return;
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
}
