/// Non-web no-op. On native platforms the badge is written through the
/// `monkeyhub/badge` method channel in [BadgeManager]; this stub exists only so
/// the conditional export in `web_badge.dart` resolves off-web.
class WebBadge {
  const WebBadge._();

  /// No-op on non-web platforms.
  static void set(int n) {}
}
