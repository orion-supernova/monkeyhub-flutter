// Web "update" indirection.
//
// Web has no store to send anyone to — the update is simply fetching the newly
// deployed build, which means touching window.location and the service worker.
// Neither exists off-web, so this resolves to the interop implementation on web
// and a no-op stub everywhere else. Mirror of the web_push / web_badge
// conditional-import pattern.
export 'web_reload_io.dart' if (dart.library.html) 'web_reload_web.dart';
