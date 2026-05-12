import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'backend/chat_api.dart';
import 'backend/convex_client.dart';
import 'data/chat_repository.dart';
import 'data/settings_store.dart';
import 'env.dart';
import 'main.dart' show rootNavigatorKey;
import 'push/badge_manager.dart';
import 'push/push_manager.dart';
import 'screens/home_shell.dart';
import 'screens/room_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_scope.dart';

class MonkeyHubApp extends StatefulWidget {
  const MonkeyHubApp({super.key});
  @override
  State<MonkeyHubApp> createState() => _MonkeyHubAppState();
}

class _MonkeyHubAppState extends State<MonkeyHubApp> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_onAuthChange);
    PushManager.instance.setOnOpenRoom(_openRoomFromPush);
    _bootstrap();
  }

  void _openRoomFromPush(String roomId) {
    // Ignore when no session — push could fire just before signOut clears auth.
    if (_auth.session == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    // Pop any nested route first so we always land cleanly on the room.
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute(
      builder: (_) => RoomScreen(roomId: roomId, repo: _repo, api: _api),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _auth.session;
    if (session == null) return;
    final next = switch (state) {
      AppLifecycleState.resumed => 'online',
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden =>
        'away',
      AppLifecycleState.detached => 'offline',
    };
    // Fire-and-forget — network may be unavailable; status reconciles next foreground.
    _api.updateStatus(userId: session.userId, status: next).catchError((_) {});
    if (state == AppLifecycleState.resumed) {
      // Clear platform badge on foreground; OneSignal won't auto-clear on iOS.
      BadgeManager.instance.clear();
    }
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
    // Load persisted settings (theme/layout/nav) BEFORE rendering so the
    // first frame already reflects the user's choice.
    await SettingsStore.instance.load();
    final savedThemeId = SettingsStore.instance.themeId;
    if (savedThemeId != null) {
      _themeController.theme = ThemeController.byId(savedThemeId);
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
          await PushManager.instance.login(s.userId);
          BadgeManager.instance.bind(_repo);
        } catch (_) {/* offline boot — reconcile on reconnect */}
      }
    } catch (_) {/* secure storage may not be available in test harness */}
    if (mounted) setState(() => _bootstrapped = true);
  }

  void _onAuthChange() async {
    final s = _auth.session;
    if (s != null && _repo.userId != s.userId) {
      await _repo.attach(s.userId);
      await PushManager.instance.login(s.userId);
      // Mark online on first attach.
      _api.updateStatus(userId: s.userId, status: 'online').catchError((_) {});
      BadgeManager.instance.bind(_repo);
    } else if (s == null) {
      BadgeManager.instance.unbind();
      await _repo.detach();
      await PushManager.instance.logout();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            navigatorKey: rootNavigatorKey,
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
                          ? HomeShell(
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
