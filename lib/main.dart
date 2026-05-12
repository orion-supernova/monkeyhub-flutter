import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'data/settings_store.dart';
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
  // Initialize OneSignal early so notification taps can route into the app.
  // The onOpenRoom callback is resolved later by app.dart, which holds the
  // repo + api; PushManager just stashes the callback until then.
  await PushManager.instance.initialize();
  runApp(const MonkeyHubApp());
}
