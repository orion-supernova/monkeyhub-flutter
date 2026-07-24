/// Non-web no-op. Native platforms use the onesignal_flutter plugin
/// (PushManager); this stub exists only so the conditional export in
/// `onesignal_web.dart` resolves off-web.
class OneSignalWeb {
  const OneSignalWeb._();

  static void setOnOpenRoom(void Function(String roomId) cb) {}
  static void login(String userId) {}
  static void logout() {}
  static void promptPermission() {}
}
