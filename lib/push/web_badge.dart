// Web badge indirection.
//
// On web this resolves to the real implementation (tab title + favicon bubble
// + `navigator.setAppBadge`); on every other platform to a no-op stub, so
// BadgeManager can call `WebBadge.set` unconditionally without dragging web
// libraries (`dart:js_interop`, `package:web`) into mobile/desktop builds.
export 'web_badge_io.dart' if (dart.library.html) 'web_badge_web.dart';
