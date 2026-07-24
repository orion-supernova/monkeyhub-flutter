// OneSignal Web Push indirection.
//
// The onesignal_flutter plugin is android/ios-only, so web push is wired via
// the OneSignal Web JS SDK (loaded in web/index.html) and a small JS bridge
// (window.mhOneSignal*). On web this resolves to the interop implementation; on
// every other platform to a no-op stub (native uses the flutter plugin). Mirror
// of the web_notifier / web_badge conditional-import pattern.
export 'onesignal_web_io.dart' if (dart.library.html) 'onesignal_web_web.dart';
