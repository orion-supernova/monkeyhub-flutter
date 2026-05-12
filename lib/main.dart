import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load env.local from the asset bundle. `isOptional` lets the app boot even
  // if the file is missing — Env.missing() will surface a clean error screen.
  await dotenv.load(fileName: 'env.local', isOptional: true);
  runApp(const MonkeyHubApp());
}
