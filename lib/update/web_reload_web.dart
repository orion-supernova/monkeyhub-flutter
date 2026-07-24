import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web "update": fetch the new build.
///
/// There's no store to hand off to — the deployed files under /web already ARE
/// the new version, the tab is just still running the old one.
class WebReload {
  const WebReload._();

  static Future<void> toVersion(String version) async {
    // A plain location.reload() is not enough. Flutter web installs a service
    // worker that serves the previous build's index.html and
    // flutter_bootstrap.js straight from its cache, so the reload can land the
    // user right back on the version they're trying to leave. Drop the worker
    // first, then reload past the HTTP cache with a version-stamped query.
    try {
      final regs =
          (await web.window.navigator.serviceWorker.getRegistrations().toDart)
              .toDart;
      for (final reg in regs) {
        await reg.unregister().toDart;
      }
    } catch (_) {
      // No service worker registered, or the browser refused — the version
      // stamp below still handles the ordinary HTTP-cache case.
    }
    final loc = web.window.location;
    loc.replace('${loc.origin}${loc.pathname}?v=$version');
  }
}
