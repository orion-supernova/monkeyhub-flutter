import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'backend/chat_api.dart';
import 'backend/convex_client.dart';
import 'data/chat_repository.dart';
import 'env.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_scope.dart';

class MonkeyHubApp extends StatefulWidget {
  const MonkeyHubApp({super.key});
  @override
  State<MonkeyHubApp> createState() => _MonkeyHubAppState();
}

class _MonkeyHubAppState extends State<MonkeyHubApp> {
  final ThemeController _themeController =
      ThemeController(ThemeController.all.first);
  final ConvexBackend _cv = ConvexBackend.instance;
  late final ChatApi _api = ChatApi(_cv);
  late final ChatRepository _repo = ChatRepository(api: _api, cv: _cv);
  late final AuthService _auth = AuthService(_api);

  bool _bootstrapped = false;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChange);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final missing = Env.missing();
    if (missing.isNotEmpty) {
      if (mounted) {
        setState(() {
          _bootError = EnvMissingError(missing);
          _bootstrapped = true;
        });
      }
      return;
    }
    final initErr = await _cv.initialize();
    if (initErr != null) {
      // Convex couldn't initialize. Surface to the UI so the user sees
      // the real reason instead of a downstream "not initialized" error.
      debugPrint('CONVEX INIT FAILED: $initErr');
      if (mounted) {
        setState(() {
          _bootError = initErr;
          _bootstrapped = true;
        });
      }
      return;
    }
    try {
      await _auth.restore();
      final s = _auth.session;
      if (s != null) {
        try {
          await _repo.attach(s.userId);
        } catch (_) {/* offline boot — reconcile on reconnect */}
      }
    } catch (_) {/* secure storage may not be available in test harness */}
    if (mounted) setState(() => _bootstrapped = true);
  }

  void _onAuthChange() async {
    final s = _auth.session;
    if (s != null && _repo.userId != s.userId) {
      await _repo.attach(s.userId);
    } else if (s == null) {
      await _repo.detach();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChange);
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: Listenable.merge([_themeController, _auth]),
        builder: (context, _) {
          final theme = _themeController.theme;
          final isLight = theme.mood == ThemeMood.riso;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'MonkeyHub',
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
              child: !_bootstrapped
                  ? const _Splash(key: ValueKey('splash'))
                  : (_bootError != null
                      ? _BootError(key: const ValueKey('boot_error'), error: _bootError!, onRetry: () {
                          setState(() {
                            _bootError = null;
                            _bootstrapped = false;
                          });
                          _bootstrap();
                        })
                      : (_auth.isSignedIn
                          ? HomeScreen(
                              key: ValueKey('home_${theme.id}'),
                              repo: _repo,
                              api: _api,
                              auth: _auth,
                            )
                          : LoginScreen(key: ValueKey('login_${theme.id}'), auth: _auth))),
            ),
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                theme.brandMark(size: 56),
                const SizedBox(height: 18),
                Text('MONKEYHUB', style: theme.label.copyWith(letterSpacing: 4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CAN’T REACH SERVER', style: theme.label.copyWith(color: theme.danger, letterSpacing: 2.4)),
                      const SizedBox(height: 14),
                      Text('Convex didn’t initialize.', style: theme.displayLarge),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.surfaceSunken,
                          border: Border(left: BorderSide(color: theme.danger, width: 2)),
                          borderRadius: BorderRadius.circular(theme.radiusMd),
                        ),
                        child: Text(error.toString(), style: theme.mono.copyWith(color: theme.inkSoft)),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                          decoration: BoxDecoration(
                            color: theme.accent,
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                          ),
                          child: Text('RETRY', style: theme.label.copyWith(color: theme.accentInk, letterSpacing: 2.4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
