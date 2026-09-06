/// Non-web no-op. Native platforms get their notifications through
/// [PushManager] and APNs/FCM; this stub exists only so the conditional export
/// in `web_push.dart` resolves off-web.
class WebPush {
  const WebPush._();

  static void setOnOpenRoom(void Function(String roomId) cb) {}
  static void setOnOpenTarget({
    required void Function(String momentId) onMoment,
    required void Function() onGames,
  }) {}
  static Future<WebPushSubscription?> subscribe(String vapidPublicKey) async =>
      null;
  static void promptPermission() {}
  static void unregisterLegacy() {}
}

/// What the browser hands back for a push subscription: where to send, and the
/// two keys the payload encryption needs.
class WebPushSubscription {
  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}
