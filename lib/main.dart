import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'calls/native_call_handler.dart';
import 'data/settings_store.dart';
import 'media/file_url_cache.dart';
import 'media/media_aspect_cache.dart';
import 'push/push_manager.dart';

/// Root navigator key — exposed so non-widget code (push handlers, native
/// callbacks) can push routes without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never fetch a typeface over the network. Every family the themes use is
  // bundled under assets/google_fonts (see pubspec.yaml), so this costs nothing
  // visually — it just turns "prefer the bundled file" into a guarantee.
  //
  // The point is privacy, not startup time: left enabled, google_fonts contacts
  // Google's font CDN on launch and hands them every user's IP address. That is
  // a third-party data flow this app otherwise does not have — it ships no
  // analytics, no ads and no attribution SDK — and it would be flatly
  // disallowed under the Kids-category rules.
  //
  // If a font ever renders as a plain system face, the cause is a MISSING or
  // MISNAMED asset, not this line. google_fonts wants exactly
  // `<Family>-<Variant>.ttf`; fix the asset rather than re-enabling fetching.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Pre-load persisted settings, env, and disk caches in parallel so the first
  // frame renders immediately under the user's saved theme and avatar URLs,
  // costing a single platform-channel hop time instead of 4 sequential ones.
  await Future.wait([
    dotenv.load(fileName: 'env.local', isOptional: true),
    SettingsStore.instance.load(),
    FileUrlCache.instance.load(),
    MediaAspectCache.instance.load(),
  ]);

  PaintingBinding.instance.imageCache.maximumSize = 1500;

  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  } else {
    // Initialize push and native call handler asynchronously without delaying runApp.
    PushManager.instance.initialize().then((_) {
      NativeCallHandler.instance.start();
    }).catchError((Object e) {
      debugPrint('PushManager.initialize: $e');
    });
  }

  runApp(const MonkeyHubApp());
}
