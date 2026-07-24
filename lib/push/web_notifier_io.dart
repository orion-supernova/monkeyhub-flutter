/// Non-web no-op. On native platforms message alerts are delivered by the OS
/// (OneSignal push banners on mobile); this stub exists only so the conditional
/// export in `web_notifier.dart` resolves off-web.
class WebNotifier {
  const WebNotifier._();

  /// Non-web platforms use Flutter's app lifecycle for focus; this stub is
  /// never consulted off-web (MessageAlerts branches on `kIsWeb`).
  static bool get isFocused => true;

  /// No-op on non-web platforms.
  static void setOnOpenRoom(void Function(String roomId) cb) {}

  /// No-op on non-web platforms.
  static Future<void> requestPermission() async {}

  /// No-op on non-web platforms.
  static void showMessage({
    required String title,
    required String body,
    required String roomId,
  }) {}

  /// No-op on non-web platforms.
  static void showCall({required String title, required String body}) {}

  /// No-op on non-web platforms.
  static void dismissCall() {}
}
