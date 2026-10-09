/// Non-web no-op. A native window has no document to title and no address bar
/// to have been opened on; this stub exists only so the conditional export in
/// `web_document.dart` resolves off-web.
abstract final class WebDocument {
  static String? takeInitialRoute() => null;

  static void setTitle(String title) {}
}
