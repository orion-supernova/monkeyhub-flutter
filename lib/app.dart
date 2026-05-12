import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_scope.dart';
import 'screens/home_screen.dart';

class MonkeyHubApp extends StatefulWidget {
  const MonkeyHubApp({super.key});
  @override
  State<MonkeyHubApp> createState() => _MonkeyHubAppState();
}

class _MonkeyHubAppState extends State<MonkeyHubApp> {
  late final ThemeController _controller = ThemeController(ThemeController.all.first);

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final theme = _controller.theme;
          final isLight = theme.mood == ThemeMood.riso;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'monkeyhub',
            theme: ThemeData(
              brightness: isLight ? Brightness.light : Brightness.dark,
              scaffoldBackgroundColor: theme.background,
              textTheme: TextTheme(bodyMedium: theme.body),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              colorScheme: (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
                primary: theme.accent,
                secondary: theme.accent,
                surface: theme.surface,
                onSurface: theme.ink,
              ),
            ),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(key: ValueKey(theme.id), child: const HomeScreen()),
            ),
          );
        },
      ),
    );
  }
}
