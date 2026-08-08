import 'dart:js_interop';

/// Web Push (RFC 8030) through the `window.mhPush*` bridge in web/index.html.
///
/// A browser subscription is three values — an endpoint URL and two keys — and
/// the backend encrypts each payload for them itself (backend/convex/webPush.ts).
/// There is no SDK on either side.
///
/// The subscription is bound to (origin, service worker, VAPID public key), so
/// it only exists once the tab has been opened at least once after this shipped.
@JS('mhPushSubscribe')
external JSPromise<JSAny?> _jsSubscribe(JSString vapidPublicKey);

/// The `{endpoint, p256dh, auth}` object `mhPushSubscribe` resolves to.
///
/// Typed rather than read with dynamic property access so a rename on the JS
/// side of the bridge is a compile error here.
extension type _JsSubscription._(JSObject _) implements JSObject {
  external String? get endpoint;
  external String? get p256dh;
  external String? get auth;
}

@JS('mhPushPermission')
external void _jsPrompt();

@JS('mhPushOnOpenRoom')
external void _jsOnOpenRoom(JSFunction cb);

@JS('mhPushUnregisterLegacy')
external void _jsUnregisterLegacy();

class WebPush {
  const WebPush._();

  static void Function(String roomId)? _onOpenRoom;
  static bool _clickWired = false;

  /// Route a notification click to the room. The service worker posts the
  /// message to whichever tab it focuses; this wires the listener once.
  static void setOnOpenRoom(void Function(String roomId) cb) {
    _onOpenRoom = cb;
    if (_clickWired) return;
    _clickWired = true;
    try {
      _jsOnOpenRoom(
        ((JSString roomId) {
          final r = roomId.toDart;
          if (r.isNotEmpty) _onOpenRoom?.call(r);
        }).toJS,
      );
    } catch (_) {}
  }

  /// Register the service worker and subscribe, returning what the backend
  /// needs to reach this browser. Null when the browser refuses, the user has
  /// not granted permission, or no VAPID key is configured.
  ///
  /// Safe to call repeatedly: `pushManager.subscribe` returns the existing
  /// subscription when the applicationServerKey matches.
  static Future<WebPushSubscription?> subscribe(String vapidPublicKey) async {
    if (vapidPublicKey.isEmpty) return null;
    try {
      final result = await _jsSubscribe(vapidPublicKey.toJS).toDart;
      if (result == null) return null;
      final sub = _JsSubscription._(result as JSObject);
      final endpoint = sub.endpoint;
      final p256dh = sub.p256dh;
      final auth = sub.auth;
      if (endpoint == null || p256dh == null || auth == null) return null;
      if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) return null;
      return WebPushSubscription(
        endpoint: endpoint,
        p256dh: p256dh,
        auth: auth,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ask for notification permission. Must run from a user gesture.
  static void promptPermission() {
    try {
      _jsPrompt();
    } catch (_) {}
  }

  /// Unregister the service worker left behind by the previous push SDK.
  ///
  /// A worker outlives the script tag that installed it, and it keeps a live
  /// push subscription — so without this a browser could keep receiving
  /// notifications from the old vendor, or show two for one message.
  static void unregisterLegacy() {
    try {
      _jsUnregisterLegacy();
    } catch (_) {}
  }
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
