// Web Push indirection.
//
// The browser half of push: a service worker registration and a VAPID
// subscription, reached through the small `window.mhPush*` bridge in
// web/index.html. On web this resolves to the interop implementation; on every
// other platform to a no-op stub, since native platforms use PushManager and
// APNs/FCM. Mirror of the web_notifier / web_badge conditional-import pattern.
export 'web_push_io.dart' if (dart.library.html) 'web_push_web.dart';
