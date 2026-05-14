import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'backend/chat_api.dart';
import 'backend/convex_client.dart';
import 'data/chat_repository.dart';
import 'data/settings_store.dart';
import 'env.dart';
import 'main.dart' show rootNavigatorKey;
import 'privacy/capture_protection.dart';
import 'push/badge_manager.dart';
import 'push/push_manager.dart';
import 'screens/home_shell.dart';
import 'screens/room_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_scope.dart';
import 'widgets/app_brand_mark.dart';
import 'widgets/capture_shield.dart';
import 'widgets/connection_banner.dart';

class MonkeyHubApp extends StatefulWidget {
  const MonkeyHubApp({super.key});
  @override
  State<MonkeyHubApp> createState() => _MonkeyHubAppState();
}

class _MonkeyHubAppState extends State<MonkeyHubApp> with WidgetsBindingObserver {
  // Seed the controller from the already-loaded SettingsStore (preloaded in
  // main.dart). Falls back to system-brightness-aware defaults on first
  // launch. Doing this synchronously means the first paint already uses the
  // user's saved theme — no Midnight flash on hot restart.
  final ThemeController _themeController = ThemeController(_initialTheme());
  final ConvexBackend _cv = ConvexBackend.instance;
  late final ChatApi _api = ChatApi(_cv);
  late final ChatRepository _repo = ChatRepository(api: _api, cv: _cv);
  late final AuthService _auth = AuthService(_api);
  // Cached merged listenable. Created exactly once so AnimatedBuilder's
  // listener subscription on _auth / _themeController is never re-bound
  // across parent rebuilds (each fresh Listenable.merge call would force
  // AnimatedBuilder.didUpdateWidget into a remove-then-add cycle, which has
  // been observed to drop the subscription after a sign-out → sign-in
  // toggle and leave the LoginScreen → HomeShell swap stranded).
  late final Listenable _appListenable =
      Listenable.merge([_themeController, _auth]);

  bool _bootstrapped = false;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_onAuthChange);
    _auth.addListener(() => debugPrint('[app] auth listener fired, isSignedIn=${_auth.isSignedIn}'));
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
    // SettingsStore was preloaded in main.dart and the theme controller was
    // seeded with the right starting theme synchronously (`_initialTheme()`
    // below). Nothing left to reconcile here.
    // Apply screen-capture protection setting on boot: Android enables
    // FLAG_SECURE immediately; iOS just primes the event stream.
    await CaptureProtection.instance.setUserEnabled(SettingsStore.instance.captureProtection);
    await CaptureProtection.instance.ensureListening();
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
          // Respect the user's last notification preference.
          if (!SettingsStore.instance.pushEnabled) {
            await PushManager.instance.optOut();
          }
          BadgeManager.instance.bind(_repo);
        } catch (_) {/* offline boot — reconcile on reconnect */}
      }
    } catch (_) {/* secure storage may not be available in test harness */}
    if (mounted) setState(() => _bootstrapped = true);
  }

  void _onAuthChange() async {
    final s = _auth.session;
    try {
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
        // Reset landing tab so the next sign-in starts on Chat instead of
        // wherever the previous session left off (e.g. Settings, which is
        // where Sign Out is reached from).
        await SettingsStore.instance.setSection(HomeSection.chat);
      }
    } catch (_) {
      // Swallow: post-auth attach failures shouldn't crash the listener
      // pipeline. The UI (AnimatedBuilder) is on a separate listener slot
      // and must stay reactive even if repo/push setup throws.
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
        animation: _appListenable,
        builder: (context, _) {
          debugPrint('[app] AnimatedBuilder rebuild, isSignedIn=${_auth.isSignedIn}, bootstrapped=$_bootstrapped, bootError=${_bootError != null}');
          final theme = _themeController.theme;
          final isLight = theme.mood == ThemeMood.riso;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            title: 'MonkeyHub',
            builder: (context, child) {
              return Stack(
                children: [
                  ?child,
                  if (_bootstrapped && _bootError == null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ConnectionBanner(cv: _cv),
                    ),
                  // Sits above every other layer so it covers banners +
                  // overlays during a screen recording.
                  const CaptureShield(),
                ],
              );
            },
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
            // MaterialApp.home is a stable widget (_AppHome). Its identity
            // never changes across rebuilds, so the Navigator's initial route
            // content is fixed and reconciliation works normally. _AppHome
            // listens to AuthService internally and swaps its child between
            // _Splash / _BootError / LoginScreen / HomeShell via setState —
            // a normal subtree rebuild that Flutter mounts/unmounts correctly.
            //
            // Previously this slot was an AnimatedSwitcher rebuilt on every
            // AnimatedBuilder pass, which meant MaterialApp.home was a new
            // widget instance each time. The Navigator did not propagate
            // those home changes into the existing route content, so the
            // LoginScreen → HomeShell swap never happened in-session (the
            // home widget was effectively frozen on the first mount).
            home: _AppHome(
              auth: _auth,
              repo: _repo,
              api: _api,
              themeController: _themeController,
              bootstrapped: _bootstrapped,
              bootError: _bootError,
              onRetryBoot: () {
                setState(() {
                  _bootError = null;
                  _bootstrapped = false;
                });
                _bootstrap();
              },
            ),
          );
        },
      ),
    );
  }

  /// Resolves the starting theme synchronously from preloaded settings:
  ///   1. If the user has a saved themeId, use that.
  ///   2. Otherwise default by the device's current system brightness —
  ///      Dark → Midnight, Light → Daylight.
  /// `SettingsStore.load()` MUST have been awaited before `runApp` for this
  /// to return the right value on first frame (see `main.dart`).
  static AppTheme _initialTheme() {
    final saved = SettingsStore.instance.themeId;
    if (saved != null) return ThemeController.byId(saved);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return ThemeController.byId(
      brightness == Brightness.light ? 'basic_daylight' : 'basic',
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
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
                const AppBrandMark(size: 56),
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
  const _BootError({required this.error, required this.onRetry});
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

/// Stable child of MaterialApp.home. Listens to AuthService internally so the
/// LoginScreen → HomeShell swap happens via setState on a subtree we own,
/// rather than by replacing MaterialApp.home (which the Navigator caches).
class _AppHome extends StatefulWidget {
  const _AppHome({
    required this.auth,
    required this.repo,
    required this.api,
    required this.themeController,
    required this.bootstrapped,
    required this.bootError,
    required this.onRetryBoot,
  });

  final AuthService auth;
  final ChatRepository repo;
  final ChatApi api;
  final ThemeController themeController;
  final bool bootstrapped;
  final Object? bootError;
  final VoidCallback onRetryBoot;

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
  }

  @override
  void didUpdateWidget(covariant _AppHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      oldWidget.auth.removeListener(_onAuth);
      widget.auth.addListener(_onAuth);
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[app_home] build, isSignedIn=${widget.auth.isSignedIn}, bootstrapped=${widget.bootstrapped}, bootError=${widget.bootError != null}');
    if (!widget.bootstrapped) return const _Splash();
    if (widget.bootError != null) {
      return _BootError(error: widget.bootError!, onRetry: widget.onRetryBoot);
    }
    final theme = widget.themeController.theme;
    final signedIn = widget.auth.isSignedIn;
    debugPrint('[app_home] selecting child: ${signedIn ? "HomeShell" : "LoginScreen"}');
    return signedIn
        ? HomeShell(
            key: ValueKey('home_${theme.id}'),
            repo: widget.repo,
            api: widget.api,
            auth: widget.auth,
          )
        : LoginScreen(
            key: ValueKey('login_${theme.id}'),
            auth: widget.auth,
          );
  }
}
