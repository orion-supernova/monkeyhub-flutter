import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
