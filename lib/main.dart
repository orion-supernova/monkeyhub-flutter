import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'calls/native_call_handler.dart';
import 'data/settings_store.dart';
import 'media/file_url_cache.dart';
import 'push/push_manager.dart';

/// Root navigator key — exposed so non-widget code (push handlers, native
/// callbacks) can push routes without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load env.local from the asset bundle. `isOptional` lets the app boot even
  // if the file is missing — Env.missing() will surface a clean error screen.
  await dotenv.load(fileName: 'env.local', isOptional: true);
  // Pre-load persisted settings so the first frame already renders under the
  // user's saved theme. Without this, MonkeyHubApp's `_themeController` would
  // briefly default to Midnight before bootstrap's async read replaces it —
  // visible as a flicker on hot restart.
  await SettingsStore.instance.load();
  // Pre-load the storageId → URL map for the same reason: without it the first
  // frame has no URL for any avatar and every one of them renders a shimmer
  // while a `files:getFileUrl` round trip lands. Reads one SharedPreferences
  // key, so it costs a single platform-channel hop.
  await FileUrlCache.instance.load();
  // Raise the ENTRY-count ceiling above its 1000 default, and leave the byte
  // ceiling at 100 MiB.
  //
  // Every image now decodes to the size it's painted at (see RemoteImage), so a
  // typical entry is tens of KB rather than the ~12 MiB a full-resolution photo
  // used to cost. That inverts which limit binds first: 1000 small entries is
  // nowhere near 100 MiB, so the count is what would start evicting on a busy
  // account holding avatars, room icons, link previews and photos across several
  // screens at once. The byte ceiling stays put as the real safety net.
  PaintingBinding.instance.imageCache.maximumSize = 1500;
  if (kIsWeb) {
    // Hand right-click to Flutter instead of the browser.
    //
    // On web the browser's context menu is enabled by default and Flutter's
    // are suppressed, so a right-click on a message bubble raised Chrome's own
    // menu and `onSecondaryTap` never fired. Disabling it flips both: the
    // bubble action menu works, and text fields switch from the browser's
    // cut/copy/paste menu to Flutter's AdaptiveTextSelectionToolbar — so that
    // still works, it's just Flutter-rendered.
    //
    // The trade-off is app-wide: browser affordances like "open link in new
    // tab" and "inspect" are gone from right-click. Standard for an app-like
    // web build, and the price of right-click doing anything of our own.
    await BrowserContextMenu.disableContextMenu();
  } else {
    // OneSignal (push) and flutter_callkit_incoming (native call UI) are
    // iOS/Android-only plugins backed by dart:io — touching them on web throws
    // and blanks the whole app before the first frame. Skip both on web; the
    // push/call paths already no-op there (see PushManager._pushSupported and
    // NativeCallHandler's kIsWeb guards). Web push, if ever wanted, needs
    // OneSignal's separate JS Web SDK, not this plugin.
    //
    // Initialize OneSignal early so notification taps can route into the app.
    // The onOpenRoom callback is resolved later by app.dart, which holds the
    // repo + api; PushManager just stashes the callback until then.
    await PushManager.instance.initialize();
    // CallKit / ConnectionService event subscription. Listens for accept /
    // decline / end events emitted by the native UI and dispatches into
    // CallService. Safe to start before login — events are no-ops until a
    // session is active.
    NativeCallHandler.instance.start();
  }
  runApp(const MonkeyHubApp());
}
