/// Non-web no-op. On native platforms the app lifecycle ('detached'/'paused')
/// and the presence heartbeat handle going offline; this stub exists only so
/// the conditional export in `web_presence.dart` resolves off-web.
class WebPresence {
  const WebPresence._();

  /// No-op on non-web platforms.
  static void registerOffline(void Function() onUnload) {}
}
