import 'dart:js_interop';

/// Web push via the OneSignal Web SDK, reached through the tiny `window.mhOneSignal*`
/// bridge defined in web/index.html. Tagging the web subscription with
/// `external_id = userId` (via [login]) is the entire mechanism — the Convex
/// backend already targets that external_id on every message/call push, so no
/// backend change is needed for those pushes to reach a backgrounded/closed tab.
@JS('mhOneSignalLogin')
external void _jsLogin(JSString userId);

@JS('mhOneSignalLogout')
external void _jsLogout();

@JS('mhOneSignalPrompt')
external void _jsPrompt();

@JS('mhOneSignalOnClick')
external void _jsOnClick(JSFunction cb);

class OneSignalWeb {
  const OneSignalWeb._();

  static void Function(String roomId)? _onOpenRoom;
  static bool _clickWired = false;

  /// Route a push-banner click to the room (mirrors the native push tap and the
  /// in-page WebNotifier click). Wires the OneSignal click listener once.
  static void setOnOpenRoom(void Function(String roomId) cb) {
    _onOpenRoom = cb;
    if (_clickWired) return;
    _clickWired = true;
    try {
      _jsOnClick(
        ((JSString roomId, JSString type) {
          final r = roomId.toDart;
          if (r.isNotEmpty) _onOpenRoom?.call(r);
        }).toJS,
      );
    } catch (_) {}
  }

  /// Tag this web push subscription with external_id = userId. Idempotent.
  static void login(String userId) {
    try {
      _jsLogin(userId.toJS);
    } catch (_) {}
  }

  static void logout() {
    try {
      _jsLogout();
    } catch (_) {}
  }

  /// Ask for notification permission + subscribe. Must run from a user gesture.
  static void promptPermission() {
    try {
      _jsPrompt();
    } catch (_) {}
  }
}
