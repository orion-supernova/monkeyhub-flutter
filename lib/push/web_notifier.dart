// Web notification indirection.
//
// On web this resolves to the real implementation (the browser Notification
// API); on every other platform to a no-op stub, so callers can invoke
// `WebNotifier.*` unconditionally without dragging web libraries
// (`dart:js_interop`, `package:web`) into mobile/desktop builds. Mirrors the
// pattern in `web_badge.dart`.
export 'web_notifier_io.dart' if (dart.library.html) 'web_notifier_web.dart';
