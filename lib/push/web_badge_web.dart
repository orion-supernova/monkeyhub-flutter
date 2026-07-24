import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Web app-badge. A browser tab has no OS icon badge, so the unread count is
/// surfaced three ways, best-effort and independent:
///   1. Tab title    — `(3) MonkeyHub`
///   2. Favicon      — a red count bubble drawn over the base favicon
///   3. Installed PWA — `navigator.setAppBadge(n)` when the API exists
class WebBadge {
  const WebBadge._();

  static const String _baseTitle = 'MonkeyHub';

  /// The original favicon href, captured the first time we touch it so we can
  /// restore it when the count returns to zero.
  static String? _baseFaviconHref;

  static void set(int n) {
    _setTitle(n);
    _setAppBadge(n);
    _setFavicon(n);
  }

  static void _setTitle(int n) {
    web.document.title = n > 0 ? '($n) $_baseTitle' : _baseTitle;
  }

  /// Installed-PWA badge. Absent in normal tabs / unsupported browsers, so
  /// feature-detect and swallow anything the call throws.
  static void _setAppBadge(int n) {
    try {
      final nav = web.window.navigator as JSObject;
      if (n > 0) {
        if (nav.has('setAppBadge')) {
          nav.callMethod('setAppBadge'.toJS, n.toJS);
        }
      } else if (nav.has('clearAppBadge')) {
        nav.callMethod('clearAppBadge'.toJS);
      }
    } catch (_) {
      // Badging API not available outside an installed PWA — ignore.
    }
  }

  static web.HTMLLinkElement _faviconLink() {
    final existing =
        web.document.querySelector("link[rel~='icon']") as web.HTMLLinkElement?;
    if (existing != null) return existing;
    final link =
        web.document.createElement('link') as web.HTMLLinkElement;
    link.rel = 'icon';
    web.document.head?.appendChild(link);
    return link;
  }

  static void _setFavicon(int n) {
    final link = _faviconLink();
    _baseFaviconHref ??=
        link.href.isNotEmpty ? link.href : 'favicon.png';

    if (n <= 0) {
      link.href = _baseFaviconHref!;
      return;
    }

    // Draw the base favicon, then a red bubble with the count, onto a canvas
    // and swap the <link rel="icon"> to the resulting data URL.
    final img = web.HTMLImageElement();
    img.addEventListener(
      'load',
      (web.Event _) {
        const size = 64;
        final canvas = web.HTMLCanvasElement()
          ..width = size
          ..height = size;
        final ctx =
            canvas.getContext('2d') as web.CanvasRenderingContext2D?;
        if (ctx == null) return;

        ctx.drawImage(img, 0, 0, size.toDouble(), size.toDouble());

        final label = n > 99 ? '99+' : '$n';
        const r = 22.0;
        final cx = size - r + 2;
        final cy = r - 2;

        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 6.283185307179586); // 2π
        ctx.fillStyle = '#E53935'.toJS;
        ctx.fill();

        ctx.fillStyle = '#FFFFFF'.toJS;
        ctx.font = 'bold ${label.length > 2 ? 24 : 34}px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(label, cx, cy + 1);

        link.href = canvas.toDataURL('image/png');
      }.toJS,
    );
    // Same-origin favicon → canvas stays untainted, toDataURL() works.
    img.src = _baseFaviconHref!;
  }
}
