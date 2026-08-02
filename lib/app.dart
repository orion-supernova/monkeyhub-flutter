import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'backend/call_api.dart';
import 'backend/chat_api.dart';
import 'backend/connection_health.dart';
import 'backend/convex_client.dart';
import 'backend/group_call_api.dart';
import 'calls/active_call_pill.dart';
import 'calls/call_models.dart';
import 'calls/call_screen.dart';
import 'calls/call_service.dart';
import 'calls/group_call_screen.dart';
import 'calls/group_call_service.dart';
import 'calls/incoming_call_screen.dart';
import 'calls/incoming_group_call_screen.dart';
import 'calls/native_call_handler.dart';
import 'calls/signaling_subscriber.dart';
import 'data/chat_repository.dart';
import 'data/settings_store.dart';
import 'family/family_service.dart';
import 'env.dart';
import 'main.dart' show rootNavigatorKey;
import 'media/audio_file_cache.dart';
import 'media/file_url_cache.dart';
import 'media/media_aspect_cache.dart';
import 'audio/alert_sounds.dart';
import 'privacy/capture_protection.dart';
import 'push/android_call_reliability.dart';
import 'push/badge_manager.dart';
import 'push/device_identity.dart';
import 'push/message_alerts.dart';
import 'push/onesignal_web.dart';
import 'push/push_manager.dart';
import 'push/web_notifier.dart';
import 'push/web_presence.dart';
import 'data/ui_selection_store.dart';
import 'platform.dart';
import 'screens/home_shell.dart';
import 'screens/room_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/layout.dart';
import 'theme/theme_scope.dart';
import 'update/update_checker.dart';
import 'widgets/app_brand_mark.dart';
import 'widgets/capture_shield.dart';
import 'widgets/connection_banner.dart';

class MonkeyHubApp extends StatefulWidget {
  const MonkeyHubApp({super.key});
  @override
  State<MonkeyHubApp> createState() => _MonkeyHubAppState();
}

class _MonkeyHubAppState extends State<MonkeyHubApp>
    with WidgetsBindingObserver {
  // Seed the controller from the already-loaded SettingsStore (preloaded in
  // main.dart). Falls back to system-brightness-aware defaults on first
  // launch. Doing this synchronously means the first paint already uses the
  // user's saved theme — no Midnight flash on hot restart.
  final ThemeController _themeController = ThemeController(_initialTheme());
  final ConvexBackend _cv = ConvexBackend.instance;
  late final ChatApi _api = ChatApi(_cv);
  late final CallApi _callApi = CallApi(_cv);
  late final ChatRepository _repo = ChatRepository(api: _api, cv: _cv);
  late final AuthService _auth = AuthService(_api);
  late final FamilyService _family = FamilyService.ensure(_api);
  late final CallService _callService = CallService.ensure(_callApi);
  late final SignalingSubscriber _signaling = SignalingSubscriber(
    api: _callApi,
    service: _callService,
  );
  late final GroupCallApi _groupCallApi = GroupCallApi(_cv);
  // Group calls mint the same time-limited TURN credentials via
  // calls:getIceConfig, so both stacks share the coturn deployment.
  late final GroupCallService _groupCallService =
      GroupCallService.ensure(_groupCallApi)
        ..iceConfigFetcher = _callApi.getIceConfig;
  // Cached merged listenable. Created exactly once so AnimatedBuilder's
  // listener subscription on _auth / _themeController is never re-bound
  // across parent rebuilds (each fresh Listenable.merge call would force
  // AnimatedBuilder.didUpdateWidget into a remove-then-add cycle, which has
  // been observed to drop the subscription after a sign-out → sign-in
  // toggle and leave the LoginScreen → HomeShell swap stranded).
  late final Listenable _appListenable = Listenable.merge([
    _themeController,
    _auth,
  ]);

  bool _bootstrapped = false;
  Object? _bootError;
  // When a notification fires before auth / navigator are ready (cold start
  // from a tap), stash the target room here and consume it once the app
  // finishes booting and a signed-in session exists.
  String? _pendingPushRoomId;

  // Last presence status successfully handed to the server, so a lifecycle
  // sequence that resolves to the same value twice doesn't write twice. Null
  // means "unknown" — on sign-out, or after a failed write — and always sends.
  String? _lastSentStatus;

  // Alert sounds and the web Notification permission both require a user
  // gesture to activate (browser autoplay policy / Notification.requestPermission
  // being ignored outside a gesture). Prime once, on the first pointer down.
  bool _alertsPrimed = false;

  /// Whether web/desktop alert sounds + web banners apply on this platform.
  /// Mobile is served by OneSignal, so we don't prime anything there.
  static bool get _alertsEnabled => isWebOrDesktop;

  void _primeAlerts() {
    if (_alertsPrimed || !_alertsEnabled) return;
    _alertsPrimed = true;
    AlertSounds.instance.unlock();
    WebNotifier.requestPermission();
    // Subscribe to OneSignal Web Push (asks permission from this gesture) so a
    // backgrounded/closed tab still gets message/call banners. No-op off web.
    OneSignalWeb.promptPermission();
  }

  // Presence keepalive. Stamps `lastSeen` every 30s while signed in so the
  // server can treat a client that stopped heartbeating (closed browser tab,
  // killed app) as offline — the robust cross-platform fix for "still shows
  // online after closing". See backend presence.ts / users:heartbeat.
  Timer? _presenceHeartbeat;

  /// Deliberately still 30s, even though each beat used to patch the caller's
  /// `users` row and Convex invalidates every subscription that read that
  /// document — one beat recomputed the room list and friend list of everyone
  /// sharing a room or friendship with that user. That storm is real, but the
  /// fix belongs on the write, not the round-trip: `users.heartbeat` now skips
  /// the patch while `lastSeen` is still fresh, so most beats are pure reads.
  ///
  /// Slowing this down instead would have cost detection latency for no gain —
  /// [_beat] is also the connectivity canary, and at [heartbeatFailureThreshold]
  /// consecutive failures a 60s period would take over two minutes to notice a
  /// socket that froze while still reporting `connected`.
  static const _heartbeatPeriod = Duration(seconds: 30);

  void _startPresenceHeartbeat(String userId) {
    _presenceHeartbeat?.cancel();
    _beat(userId);
    _presenceHeartbeat = Timer.periodic(_heartbeatPeriod, (_) {
      final s = _auth.session;
      if (s == null) {
        _stopPresenceHeartbeat();
        return;
      }
      _beat(s.userId);
    });
  }

  /// The heartbeat doubles as a connectivity canary: it's already a real server
  /// round-trip every 30s, so its outcome reveals a socket that has frozen while
  /// still reporting `connected` — the one failure mode with no other detector
  /// while the app stays foreground (no stream event, no resume event).
  void _beat(String userId) {
    _api
        .heartbeat(userId: userId)
        // Comfortably above ConnectionHealth.probeTimeout. A canary stricter
        // than the probe it triggers just manufactures outages: it would call
        // a merely-slow server dead, start a healing episode, and hand it to a
        // probe willing to wait longer than the beat that raised the alarm.
        // Still well inside the 30s period, so beats can't overlap.
        .timeout(const Duration(seconds: 12))
        .then((_) => _health.noteRoundTrip(ok: true))
        .catchError((_) => _health.noteRoundTrip(ok: false));
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    // Next session starts with no assumption about the stored status.
    _lastSentStatus = null;
  }

  // ───────── connection healing ─────────
  //
  // [ConnectionHealth] owns detection and recovery (see its class doc for the
  // failure modes and the guarantees). This class only supplies the two things
  // it can't know: how to re-register subscriptions, and whether there's a
  // session worth healing for.
  late final ConnectionHealth _health = ConnectionHealth(
    backend: _cv,
    onReconnected: _resubscribeAll.call,
    isActive: () => _auth.session != null,
  );

  /// Put the app back together after a verified reconnect. Wrapped in
  /// [CoalescingJob] so overlapping reconnects collapse into a re-run instead
  /// of being dropped.
  ///
  /// Subscriptions are NOT this method's job any more, on either platform:
  ///
  ///  * Native replays its own query set across convex-rs reconnects
  ///    (`resend_ongoing_queries_mutations`), and `ConvexBackend`'s
  ///    `SubscriptionRegistry` re-registers after a forced rebuild — the one
  ///    case convex-rs cannot cover, because the client is brand new.
  ///  * The vendored web client replays `_subscriptions` into every new socket
  ///    (`_replaySubscriptions` in `onopen`).
  ///
  /// Both were already true; this method was doing the work a second time. On
  /// web it kept a genuine job — its explicit replay was the only one — right
  /// up until that patch landed, and nobody came back to delete it. The cost
  /// was the whole felt latency of a reconnect: twelve subscriptions torn down
  /// and rebuilt, five REST round-trips, a serial pending flush, and a
  /// signaling stop/start whose `stop()` clears the dedupe set, so every
  /// reconnect re-dispatched call signals the app had already handled — an
  /// incoming call could be offered twice for one caller.
  ///
  /// What genuinely needs doing is the work no transport can replay: a
  /// subscription whose `subscribe()` threw instead of queueing — the transport
  /// never had it, so it has nothing to replay — and sends that failed while
  /// the socket was down.
  late final CoalescingJob _resubscribeAll = CoalescingJob(() async {
    final s = _auth.session;
    if (s == null) return;
    try {
      await _cv.repairSubscriptions();
      await _repo.flushPending();
    } catch (e) {
      debugPrint('_resubscribeAll: $e');
    }
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_onAuthChange);
    _auth.addListener(
      () => debugPrint(
        '[app] auth listener fired, isSignedIn=${_auth.isSignedIn}',
      ),
    );
    _family.addListener(_syncAccountType);
    PushManager.instance.setOnOpenRoom(_openRoomFromPush);
    PushManager.instance.setOnOpenRequests(_openRequestsFromPush);
    PushManager.instance.attachApi(_api);
    PushManager.instance.setActiveRoomIdProvider(() => _repo.activeRoomId);
    // Web message-banner clicks open the room, same as a push tap.
    MessageAlerts.instance.setOnOpenRoom(_openRoomFromPush);
    // OneSignal Web Push banner clicks (background/closed tab) open the room too.
    OneSignalWeb.setOnOpenRoom(_openRoomFromPush);
    // Web only: a closing tab flips us offline immediately (best-effort; the
    // server staleness sweep is the backstop). No-op off web.
    WebPresence.registerOffline(() {
      final s = _auth.session;
      if (s != null) {
        _api
            .updateStatus(userId: s.userId, status: 'offline')
            .catchError((_) {});
      }
    });
    _bootstrap();
  }

  /// Land a friend-request / approval notification tap on the Friends tab.
  ///
  /// Unlike [_openRoomFromPush] there's nothing to stash for a cold start:
  /// [UiSelectionStore] holds the request until a [HomeScreen] mounts and
  /// consumes it, which covers the launch-from-notification case for free.
  void _openRequestsFromPush() {
    UiSelectionStore.instance.requestHomeTab('friends');
    SettingsStore.instance.setSection(HomeSection.chat);
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
  }

  void _openRoomFromPush(String roomId) {
    // On a cold start from a notification tap, OneSignal's click handler can
    // fire before _bootstrap finishes restoring auth and before the root
    // navigator's state is mounted. Stash the roomId and let
    // [_consumePendingPushRoom] flush it once both are ready.
    if (_auth.session == null || rootNavigatorKey.currentState == null) {
      _pendingPushRoomId = roomId;
      return;
    }
    final nav = rootNavigatorKey.currentState!;
    // Both branches want the same selection: expanded renders the detail pane
    // straight off it, and compact needs it as the resize breadcrumb that
    // `_reconcileNavigatorForExpanded` lands on — same reasoning as
    // screens/navigation/open_room.dart, which every list tap goes through.
    // This path used to be the one exception, so a push tap on phone left the
    // selection pointing at the PREVIOUS room until the outgoing screen's
    // dispose nulled it, and a later resize popped the user out to the
    // empty-room hint.
    //
    // Set BEFORE the pop: the outgoing RoomScreen's dispose clears this store
    // too, and its identity guard only holds off when it finds a NEWER roomId
    // already in place.
    UiSelectionStore.instance.selectRoom(roomId);
    // Pop any nested route first so we always land cleanly on the shell.
    nav.popUntil((r) => r.isFirst);
    if (gLastWindowClass == WindowClass.expanded) {
      // Desktop: fill the chat detail pane instead of pushing a full screen.
      SettingsStore.instance.setSection(HomeSection.chat);
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(roomId: roomId, repo: _repo, api: _api),
      ),
    );
  }

  void _consumePendingPushRoom() {
    final pending = _pendingPushRoomId;
    if (pending == null) return;
    if (_auth.session == null) return;
    // The navigator state may still be one frame away on first boot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pendingPushRoomId != pending) return;
      _pendingPushRoomId = null;
      _openRoomFromPush(pending);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Above the session check on purpose: connection health must keep tracking
    // foreground/background across a signed-out window, so a sign-in that lands
    // right after a resume doesn't inherit a parked recovery loop.
    //
    // `inactive` counts as foreground: the app is still running with live timers
    // and a live socket, and iOS fires it for every Control Centre swipe and
    // app-switcher peek. Parking there would stall recovery mid-outage and burn
    // a probe on the way back for something that never interrupted anything.
    _health.setForeground(
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive,
    );
    final session = _auth.session;
    if (session == null) return;
    final next = switch (state) {
      AppLifecycleState.resumed => 'online',
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden => 'away',
      AppLifecycleState.detached => 'offline',
    };
    // Only write on an actual change. A single lock/unlock walks through
    // inactive → hidden → inactive → resumed, and three of those four map to
    // the same 'away' — so the unguarded version fired a burst of mutations at
    // the exact moment the radio is least able to carry them, at a deployment
    // where this one-document patch has been seen exceeding Convex's 1s
    // function limit.
    if (next != _lastSentStatus) {
      _lastSentStatus = next;
      // Fire-and-forget — network may be unavailable; status reconciles next foreground.
      _api.updateStatus(userId: session.userId, status: next).catchError((_) {
        // Unknown server state now, so don't let the guard above suppress the
        // next attempt at the same value.
        _lastSentStatus = null;
      });
    }
    if (state == AppLifecycleState.resumed) {
      // No retry kicked from here. [setForeground] above already did it, and it
      // is the better-informed of the two: it knows how long we were away, and
      // past a threshold that means "rebuild the socket" rather than "probe it".
      // Two triggers per resume only ever meant the second one interrupting the
      // first one's probe.

      // Stagger auxiliary background checks by 500ms so probeConnection gets
      // first access to the waking network socket without request contention.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        BadgeManager.instance.sync();
        PushManager.instance.refreshTokens();
        _family.refresh();
      });
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
    await CaptureProtection.instance.setUserEnabled(
      SettingsStore.instance.captureProtection,
    );
    await CaptureProtection.instance.ensureListening();
    final initErr = await _cv.initialize();
    if (initErr == null) _health.start();
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
    } catch (_) {
      /* secure storage may not be available in test harness */
    }

    // Set _bootstrapped true immediately so the UI mounts in <150ms from local cache.
    if (mounted) setState(() => _bootstrapped = true);

    final s = _auth.session;
    if (s != null) {
      // Background attach & service setup — runs asynchronously so screen rendering is instant.
      _asyncSessionAttach(s);
    }

    _consumePendingPushRoom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.session != null) AndroidCallReliability.instance.ensure();
      UpdateChecker.instance.ensure(_api);
    });
  }

  void _asyncSessionAttach(Session s) async {
    try {
      await _repo.attach(s.userId);
      _family.attach(s.userId);
      await PushManager.instance.login(s.userId);
      OneSignalWeb.login(s.userId);
      if (!SettingsStore.instance.pushEnabled) {
        await PushManager.instance.optOut();
      }
      BadgeManager.instance.bind(_repo);
      MessageAlerts.instance.bind(_repo);
      _startPresenceHeartbeat(s.userId);
      final deviceId = await DeviceIdentity.ensure();
      _callService.attach(
        userId: s.userId,
        displayName: s.name,
        deviceId: deviceId,
      );
      _groupCallService.attach(userId: s.userId, deviceId: deviceId);
      await _signaling.start(s.userId, deviceId: deviceId);
      await NativeCallHandler.instance.replayColdStartCalls();
    } catch (e) {
      debugPrint('_asyncSessionAttach error: $e');
    }
  }

  /// Keeps the persisted session's account type in step with the live family
  /// context, which is the only place a graduation reaches this handset — the
  /// guardian performs it on their own phone.
  ///
  /// Waits for [FamilyService.hasContext]: the placeholder context reads as an
  /// adult, so acting before the first emission would graduate every child on
  /// every cold start. The resulting `notifyListeners` re-enters
  /// [_onAuthChange], which no-ops — the user id hasn't changed.
  void _syncAccountType() {
    if (!_family.hasContext) return;
    _auth.applyAccountType(_family.context.accountType);
  }

  void _onAuthChange() async {
    final s = _auth.session;
    try {
      if (s != null && _repo.userId != s.userId) {
        await _repo.attach(s.userId);
        _family.attach(s.userId);
        await PushManager.instance.login(s.userId);
        OneSignalWeb.login(s.userId); // web push external_id; no-op off web
        // Mark online on first attach.
        _api
            .updateStatus(userId: s.userId, status: 'online')
            .catchError((_) {});
        BadgeManager.instance.bind(_repo);
        MessageAlerts.instance.bind(_repo);
        _startPresenceHeartbeat(s.userId);
        final deviceId = await DeviceIdentity.ensure();
        _callService.attach(
          userId: s.userId,
          displayName: s.name,
          deviceId: deviceId,
        );
        _groupCallService.attach(userId: s.userId, deviceId: deviceId);
        await _signaling.start(s.userId, deviceId: deviceId);
        await NativeCallHandler.instance.replayColdStartCalls();
        _consumePendingPushRoom();
        AndroidCallReliability.instance.ensure();
        // A session now exists, so ConnectionHealth has something worth healing
        // for. Its recovery loop parks while signed out and nothing else wakes
        // it: the socket's `connected` edge has usually already been spent
        // during the park, so without this nudge the phase could only be
        // cleared by luck (a connectivity change, or a background round trip).
        unawaited(_health.retryNow());
      } else if (s == null) {
        _stopPresenceHeartbeat();
        BadgeManager.instance.unbind();
        MessageAlerts.instance.unbind();
        _family.detach();
        await _repo.detach();
        await PushManager.instance.logout();
        OneSignalWeb.logout(); // drop web push external_id; no-op off web
        // Storage URLs aren't secret, but the next account shouldn't inherit
        // the previous one's working set — and a stale entry pointing at a file
        // that got GC'd would just render a broken tile.
        await FileUrlCache.instance.clear();
        await MediaAspectCache.instance.clear();
        // Cached voice notes aren't secret either, but unlike the two above
        // they occupy real disk, and a signed-out account shouldn't leave
        // someone else's audio on the device.
        await AudioFileCache.instance.clear();
        await _signaling.stop();
        await _callService.endCall();
        _callService.detachWatch();
        await _groupCallService.leaveCall();
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
    _stopPresenceHeartbeat();
    _health.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuthChange);
    _family.removeListener(_syncAccountType);
    _signaling.stop();
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
          debugPrint(
            '[app] AnimatedBuilder rebuild, isSignedIn=${_auth.isSignedIn}, bootstrapped=$_bootstrapped, bootError=${_bootError != null}',
          );
          final theme = _themeController.theme;
          final isLight = theme.mood == ThemeMood.riso;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            title: 'MonkeyHub',
            builder: (context, child) {
              // _WindowClassProvider hosts the single app-wide LayoutBuilder
              // ABOVE the root navigator, so every route — the shell and any
              // full-screen push (profile, search, room, …) — reads the same
              // WindowClass via context. The `child` (navigator) is captured,
              // so a drag-resize only rebuilds the LayoutScope wrapper, never
              // this Stack.
              return Listener(
                // Observe (never consume) the first pointer-down to unlock
                // audio + request notification permission within a user gesture.
                onPointerDown: _alertsPrimed ? null : (_) => _primeAlerts(),
                child: _WindowClassProvider(
                  child: Stack(
                    children: [
                      ?child,
                      // One top slot, stacked vertically. These used to be two
                      // separate Positioned(top: 0) layers that overlapped
                      // whenever both were showing — which would have buried the
                      // connection banner's retry target under the call pill.
                      // Both children collapse to zero height when hidden.
                      if (_bootstrapped && _bootError == null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConnectionBanner(health: _health),
                              // Global "Move call here" pill — shows when an
                              // active call exists on another of my devices.
                              // Tap to handoff.
                              ActiveCallPill(service: _callService),
                            ],
                          ),
                        ),
                      // Pushes call screens onto the root navigator the moment
                      // the call service transitions to a non-idle state.
                      // Invisible.
                      _CallOverlay(service: _callService, api: _api),
                      // Same job for group calls: pushes GroupCallScreen /
                      // the group invite ringer. Invisible.
                      _GroupCallOverlay(
                        service: _groupCallService,
                        api: _api,
                      ),
                      // Sits above every other layer so it covers banners +
                      // overlays during a screen recording.
                      const CaptureShield(),
                    ],
                  ),
                ),
              );
            },
            theme: ThemeData(
              brightness: isLight ? Brightness.light : Brightness.dark,
              scaffoldBackgroundColor: theme.background,
              textTheme: TextTheme(bodyMedium: theme.body),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              colorScheme:
                  (isLight
                          ? const ColorScheme.light()
                          : const ColorScheme.dark())
                      .copyWith(
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
              family: _family,
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

/// Hosts the app's single [LayoutBuilder], above the root navigator, and
/// publishes the current [WindowClass] to the whole tree via [LayoutScope].
/// The [child] (the navigator + overlays) is captured, so continuous window
/// resize only re-runs this builder and swaps the cheap [LayoutScope] wrapper —
/// the navigator subtree is not rebuilt. [LayoutScope.updateShouldNotify]
/// further gates dependents so they rebuild only when the class actually flips.
class _WindowClassProvider extends StatelessWidget {
  const _WindowClassProvider({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wc = Breakpoints.classOf(constraints.maxWidth);
        // Previous class, read before we overwrite the mirror below — the
        // only signal available here for detecting a live crossing, since
        // this LayoutBuilder reruns on every resize frame, not just on a
        // class flip (unlike LayoutScope's dependents).
        final prev = gLastWindowClass;
        // Mirror for code with no descendant context (push/call-overlay
        // routing in this file).
        gLastWindowClass = wc;
        if (prev != WindowClass.expanded && wc == WindowClass.expanded) {
          _reconcileNavigatorForExpanded();
        }
        return LayoutScope(
          windowClass: wc,
          width: constraints.maxWidth,
          child: child,
        );
      },
    );
  }
}

/// Route name marking a root-navigator push that must survive
/// [_reconcileNavigatorForExpanded] — i.e. it stays in front of [HomeShell] no
/// matter what window class the app is in. Used for the active-call
/// full-screen routes: losing an in-progress call to a live resize would be
/// far worse than leaving a stale compact-only screen behind it unreconciled
/// for one more resize.
const String kProtectedRouteName = 'protected-route';

/// Growing the window past [Breakpoints.expanded] while a compact-only screen
/// is pushed on the root navigator (a room, a settings sub-screen, a
/// profile, …) would otherwise leave it stranded on top of [HomeShell]
/// forever: the shell flips to its route-free desktop layout underneath, but
/// nothing ever pops the stale push to reveal it. This mirrors the cold-start
/// reconciliation `_openRoomFromPush` (below, in `_MonkeyHubAppState`) already
/// does for a push-notification tap, but triggered by a live resize instead.
///
/// Pops everything down to the shell except a route tagged
/// [kProtectedRouteName] (an active call/group-call screen), which must never
/// be yanked out from under the user by an incidental resize.
void _reconcileNavigatorForExpanded() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    // A pending room selection means the stale push we're about to clear was
    // (or led to) a room — land the desktop two-pane on Chat so it's already
    // showing by the time the pop reveals it, exactly like the expanded
    // branches of `openRoom`/`_openRoomFromPush` already do.
    if (UiSelectionStore.instance.roomId != null) {
      SettingsStore.instance.setSection(HomeSection.chat);
    }
    nav.popUntil(
      (route) => route.isFirst || route.settings.name == kProtectedRouteName,
    );
  });
}

/// Watches [CallService] and pushes the right call screen onto the root
/// navigator whenever a fresh non-idle call session appears. Renders nothing
/// itself. A single _CallOverlay lives inside the MaterialApp.builder so it
/// can navigate above whatever screen the user is currently on.
class _CallOverlay extends StatefulWidget {
  const _CallOverlay({required this.service, required this.api});
  final CallService service;
  final ChatApi api;
  @override
  State<_CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<_CallOverlay> {
  String? _activeCallId;
  String? _enrichedCallId;
  // The call we're currently ringing for. Driven straight from the CallService
  // listener (below) rather than IncomingCallScreen.initState, because on a
  // backgrounded web tab the frame loop is paused — so the post-frame push of
  // that screen never runs and its initState never fires. This listener runs on
  // the WS-driven state change regardless of rendering, so the ring (and the
  // call banner) work whether the tab is foreground or background.
  String? _ringingCallId;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    super.dispose();
  }

  /// Whether this platform rings via the NATIVE UI (CallKit /
  /// ConnectionService). On these platforms the in-app IncomingCallScreen
  /// must never appear — WhatsApp model: the OS ringer is the incoming UI,
  /// the app UI appears only once the call is accepted. The in-app ringer
  /// remains for platforms without a native ringer: iOS simulator and
  /// desktop.
  bool get _nativeRinger {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    if (p == TargetPlatform.android) return true;
    if (p == TargetPlatform.iOS) {
      return !NativeCallHandler.instance.isIosSimulator;
    }
    return false;
  }

  /// Start/stop the in-app ringtone (and, on web, the call banner) from the
  /// call-state change directly, so it works even when a backgrounded web tab
  /// has stopped producing frames. See `_ringingCallId`.
  void _syncRingtone(CallSession? s) {
    final ringing =
        s != null &&
        s.status == CallStatus.incomingRinging &&
        !s.isCaller &&
        !_nativeRinger &&
        !widget.service.acceptedNatively;
    if (ringing) {
      if (_ringingCallId == s.callId) return;
      _ringingCallId = s.callId;
      AlertSounds.instance.startRingtone();
      // When the tab isn't focused the in-app ringer never mounts (no frames),
      // so surface a persistent OS banner. No-op off web / when focused.
      if (!WebNotifier.isFocused) {
        WebNotifier.showCall(
          title: 'Incoming call',
          body: s.peerName.isNotEmpty ? s.peerName : 'Someone is calling',
        );
      }
    } else {
      if (_ringingCallId == null) return;
      _ringingCallId = null;
      AlertSounds.instance.stopRingtone();
      WebNotifier.dismissCall();
    }
  }

  void _onChanged() {
    final s = widget.service.session;
    _syncRingtone(s);
    if (s == null) {
      _activeCallId = null;
      _enrichedCallId = null;
      return;
    }
    final terminal =
        s.status == CallStatus.ended ||
        s.status == CallStatus.failed ||
        s.status == CallStatus.handedOff;
    if (terminal) return;
    _maybeEnrichPeerIdentity(s);
    if (_activeCallId == s.callId) return; // already showing
    // Routes from here:
    //   - Outgoing caller → CallScreen (the live in-call UI).
    //   - Callee, accepted via native CallKit → straight to CallScreen.
    //   - Handoff "Move call here" tap → already past accept, status
    //     is `switching` → CallScreen with brief switching indicator.
    //   - Callee still ringing → the NATIVE ringer owns the UI on phones
    //     (don't latch _activeCallId — a later accept must still route);
    //     in-app IncomingCallScreen only on simulator/desktop.
    final goCallScreen =
        s.isCaller ||
        widget.service.acceptedNatively ||
        s.status != CallStatus.incomingRinging;
    if (!goCallScreen && _nativeRinger) return;
    _activeCallId = s.callId;
    // Defer to the next frame so we don't navigate during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;
      if (goCallScreen) {
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            settings: const RouteSettings(name: kProtectedRouteName),
            builder: (_) =>
                CallScreen(service: widget.service, api: widget.api),
          ),
        );
      } else {
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            settings: const RouteSettings(name: kProtectedRouteName),
            builder: (_) =>
                IncomingCallScreen(service: widget.service, api: widget.api),
          ),
        );
      }
    });
  }

  /// One profile lookup per call: fills in the real display name (the
  /// offer-created path shows 'Calling…') and the avatar when the invite
  /// payload didn't carry one (older backend, caller side).
  void _maybeEnrichPeerIdentity(CallSession s) {
    if (_enrichedCallId == s.callId) return;
    final needsName = s.peerName.isEmpty || s.peerName == 'Calling…';
    final needsAvatar = s.peerAvatarStorageId == null;
    if (!needsName && !needsAvatar) {
      _enrichedCallId = s.callId;
      return;
    }
    _enrichedCallId = s.callId;
    widget.api
        .getProfile(s.peerUserId, viewerUserId: widget.service.userId)
        .then((profile) {
          if (profile == null) return;
          final current = widget.service.session;
          if (current == null || current.callId != s.callId) return;
          widget.service.updatePeerIdentity(
            peerName: needsName ? profile.name : null,
            avatarStorageId: profile.avatarStorageId,
          );
        })
        .catchError((Object e) {
          debugPrint('_CallOverlay: profile enrichment failed: $e');
        });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
                Text(
                  'MONKEYHUB',
                  style: theme.label.copyWith(letterSpacing: 4),
                ),
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
                      Text(
                        'CAN’T REACH SERVER',
                        style: theme.label.copyWith(
                          color: theme.danger,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Convex didn’t initialize.',
                        style: theme.displayLarge,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.surfaceSunken,
                          border: Border(
                            left: BorderSide(color: theme.danger, width: 2),
                          ),
                          borderRadius: BorderRadius.circular(theme.radiusMd),
                        ),
                        child: Text(
                          error.toString(),
                          style: theme.mono.copyWith(color: theme.inkSoft),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 22,
                          ),
                          decoration: BoxDecoration(
                            color: theme.accent,
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                          ),
                          child: Text(
                            'RETRY',
                            style: theme.label.copyWith(
                              color: theme.accentInk,
                              letterSpacing: 2.4,
                            ),
                          ),
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
/// Watches [GroupCallService] and drives the two group-call navigations:
/// pushes [GroupCallScreen] the moment this device enters a call (started,
/// joined from a banner, or joined from the ringer), and raises
/// [IncomingGroupCallScreen] while a fresh invite is pending. Renders
/// nothing itself — same pattern as [_CallOverlay] above.
class _GroupCallOverlay extends StatefulWidget {
  const _GroupCallOverlay({required this.service, required this.api});
  final GroupCallService service;
  final ChatApi api;
  @override
  State<_GroupCallOverlay> createState() => _GroupCallOverlayState();
}

class _GroupCallOverlayState extends State<_GroupCallOverlay> {
  String? _pushedCallId;
  bool _ringerUp = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final svc = widget.service;
    if (svc.inCall && _pushedCallId != svc.groupCallId) {
      _pushedCallId = svc.groupCallId;
      // This overlay sits ABOVE the navigator (MaterialApp.builder), so
      // Navigator.of(context) finds nothing — route through the root
      // navigator key, same as _CallOverlay.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = rootNavigatorKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            settings: const RouteSettings(name: kProtectedRouteName),
            builder: (_) =>
                GroupCallScreen(service: widget.service, api: widget.api),
          ),
        );
      });
      return;
    }
    if (!svc.inCall) _pushedCallId = null;
    // Ring for a fresh invite — never over an active 1:1 or group call
    // (the room banner remains as the quiet join surface).
    final busyOneToOne = CallService.maybeInstance?.inCall ?? false;
    if (svc.pendingInvite != null &&
        !svc.inCall &&
        !busyOneToOne &&
        !_ringerUp) {
      _ringerUp = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final nav = rootNavigatorKey.currentState;
        if (nav == null) {
          _ringerUp = false;
          return;
        }
        await nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            settings: const RouteSettings(name: kProtectedRouteName),
            builder: (_) => IncomingGroupCallScreen(service: widget.service),
          ),
        );
        _ringerUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _AppHome extends StatefulWidget {
  const _AppHome({
    required this.auth,
    required this.repo,
    required this.api,
    required this.family,
    required this.themeController,
    required this.bootstrapped,
    required this.bootError,
    required this.onRetryBoot,
  });

  final AuthService auth;
  final ChatRepository repo;
  final ChatApi api;
  final FamilyService family;
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
    debugPrint(
      '[app_home] build, isSignedIn=${widget.auth.isSignedIn}, bootstrapped=${widget.bootstrapped}, bootError=${widget.bootError != null}',
    );
    if (!widget.bootstrapped) return const _Splash();
    if (widget.bootError != null) {
      return _BootError(error: widget.bootError!, onRetry: widget.onRetryBoot);
    }
    final theme = widget.themeController.theme;
    final signedIn = widget.auth.isSignedIn;
    debugPrint(
      '[app_home] selecting child: ${signedIn ? "HomeShell" : "LoginScreen"}',
    );
    return signedIn
        ? HomeShell(
            key: ValueKey('home_${theme.id}'),
            repo: widget.repo,
            api: widget.api,
            auth: widget.auth,
            family: widget.family,
          )
        : LoginScreen(key: ValueKey('login_${theme.id}'), auth: widget.auth);
  }
}
