import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'calls/native_call_handler.dart';
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
  // Firebase is only needed for FCM on Android. iOS uses PushKit directly,
  // so we skip the Firebase init there to avoid pulling in an unused plist
  // dependency on Apple platforms.
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase.initializeApp failed: $e');
    }
  }
  // Initialize OneSignal early so notification taps can route into the app.
  // The onOpenRoom callback is resolved later by app.dart, which holds the
  // repo + api; PushManager just stashes the callback until then.
  await PushManager.instance.initialize();
  // CallKit / ConnectionService event subscription. Listens for accept /
  // decline / end events emitted by the native UI and dispatches into
  // CallService. Safe to start before login — events are no-ops until a
  // session is active.
  NativeCallHandler.instance.start();
  runApp(const MonkeyHubApp());
}
