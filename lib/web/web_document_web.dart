import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Set by the boot script in web/index.html: the `#/c/<id>`-style route the
/// page was loaded on, moved out of the address bar before Flutter starts.
@JS('mhInitialRoute')
external JSString? get _initialRoute;

@JS('mhInitialRoute')
external set _initialRoute(JSString? value);

abstract final class WebDocument {
  /// The route the page was opened on (`/c/<id>`, `/feed`…), once.
  ///
  /// Why it is stashed rather than read from the URL: with `home:` and no
  /// router, `WidgetsApp` would try to build `/c/<id>` as a named route at
  /// startup and, finding none, report "Could not navigate to initial route" —
  /// an error in every debug reload of a chat. index.html moves the hash aside
  /// so the framework starts on `/`, and [WebUrlSync] opens the chat itself
  /// once there is an account and a room list to check it against.
  static String? takeInitialRoute() {
    final route = _initialRoute?.toDart;
    if (route != null) _initialRoute = null;
    return route;
  }

  /// Straight to `document.title`, NOT `SystemChrome.setApplicationSwitcherDescription`:
  /// that one also rewrites the `theme-color` meta, and it is already being
  /// called by `MaterialApp`'s own `Title` with the theme's colour. Writing the
  /// title alone leaves that one to it.
  static void setTitle(String title) {
    web.document.title = title;
  }
}
