/// Non-web no-op. Native platforms update through a store or a download page,
/// never by reloading; this stub exists only so the conditional export in
/// `web_reload.dart` resolves off-web.
class WebReload {
  const WebReload._();

  static Future<void> toVersion(String version) async {}
}
