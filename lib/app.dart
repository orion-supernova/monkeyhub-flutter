import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_service.dart';
import 'backend/call_api.dart';
import 'backend/chat_api.dart';
import 'backend/connection_health.dart';
import 'backend/convex_client.dart';
import 'backend/feed_api.dart';
import 'backend/group_call_api.dart';
import 'backend/server_directory.dart';
import 'backend/server_endpoint.dart';
import 'backend/server_store.dart';
import 'backend/server_switch.dart';
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
import 'data/feed_store.dart';
import 'data/games_store.dart';
import 'data/settings_store.dart';
import 'diagnostics/device_report.dart';
import 'diagnostics/diag_buffer.dart';
import 'diagnostics/diag_log.dart';
import 'diagnostics/metrics_watch.dart';
import 'diagnostics/route_tracker.dart';
import 'family/family_service.dart';
import 'env.dart';
import 'auth/recovery_gate.dart';
import 'l10n/generated/app_localizations.dart';
import 'invites/deep_link_service.dart';
import 'invites/invite_link.dart';
import 'main.dart' show rootNavigatorKey;
import 'screens/join_by_invite_screen.dart';
import 'screens/navigation/route_return.dart' show appRoutes;
import 'media/audio_file_cache.dart';
import 'media/video_file_cache.dart';
import 'media/file_url_cache.dart';
import 'media/media_aspect_cache.dart';
import 'audio/alert_sounds.dart';
import 'privacy/capture_protection.dart';
import 'push/badge_manager.dart';
import 'push/device_identity.dart';
import 'push/message_alerts.dart';
import 'push/web_push.dart';
import 'push/push_manager.dart';
import 'push/web_notifier.dart';
import 'push/web_presence.dart';
import 'data/ui_selection_store.dart';
import 'platform.dart';
import 'screens/home_shell.dart';
import 'screens/room_screen.dart';
import 'screens/login_screen.dart';
import 'screens/server_screen.dart';
import 'theme/app_theme.dart';
import 'theme/layout.dart';
import 'theme/theme_scope.dart';
import 'update/update_checker.dart';
import 'widgets/app_brand_mark.dart';
import 'widgets/capture_shield.dart';
import 'widgets/connection_banner.dart';
import 'widgets/self_host_badge.dart';
import 'widgets/shake_to_report.dart';

/// The presence status a lifecycle state implies, or null for "says nothing —
/// don't write".
///
/// Only two states carry real information about whether a person is reachable.
/// The other two used to write anyway, and that is what made Android users flap
/// between `online` and `away` about once a second:
///
///  * `inactive` is NOT backgrounded. The app is still running with live timers
///    and a live socket; the platform fires it for a notification-shade pull, an
///    app-switcher peek, a permission dialog, a Control Centre swipe — and, on
///    Android, for every single window-focus change. [ConnectionHealth] has
///    always counted it as foreground (see `setForeground` directly above the
///    caller); presence disagreeing with that was an inconsistency inside one
///    method, not a considered decision. Anything that makes the window lose
///    focus repeatedly therefore turned into two `users` writes per second,
///    each invalidating every subscription that had read that row.
///
///  * `detached` does NOT mean the app died. `MainActivity.shouldDestroyEngineWithHost()`
///    returns false, so the Dart isolate outlives any single Activity and
///    `detached` only means the engine lost its host — routinely, when a call is
///    answered through flutter_callkit_incoming's relaunch. Reporting that as
///    `offline` claims something we cannot know. A client that genuinely went
///    away stops heartbeating, and the server's staleness sweep
///    (`PRESENCE_OFFLINE_MS`, backend/convex/presence.ts) is the honest detector
///    for that — it does not depend on us getting one last write out through a
///    radio that is usually already gone.
///
///  * `hidden` is the same story as `inactive`, but on WEB only. Flutter web
///    fires it for a plain window blur — clicking the address bar, alt-tabbing,
///    opening devtools — not just for a tab that actually went away. So the
///    Android flap this mapping was written to stop reappeared on web one state
///    over: a captured session writes `away`/`online` six times in 84 seconds
///    while the person is sitting there reading the screen, and each write
///    invalidates every subscription that had read that row. On mobile `hidden`
///    still means what it says, so the demotion is web-only.
///
///    Nothing is lost by staying quiet: a tab that genuinely goes away stops
///    heartbeating, and the server's staleness sweep (`PRESENCE_OFFLINE_MS`,
///    backend/convex/presence.ts) is the honest detector for that — the same
///    argument already made for `detached` above.
///
/// Kept top-level and pure so the mapping can be tested without a widget tree;
/// see test/presence_lifecycle_test.dart.
String? presenceStatusFor(AppLifecycleState state) => switch (state) {
  AppLifecycleState.resumed => 'online',
  AppLifecycleState.hidden => kIsWeb ? null : 'away',
  AppLifecycleState.paused => 'away',
  AppLifecycleState.inactive || AppLifecycleState.detached => null,
};

/// The presence status to assert when a session first attaches.
///
/// Deliberately NOT [presenceStatusFor]. That mapping answers "what does this
/// transition tell me, given I already asserted the previous state", so its
/// `null` means *stay quiet, nothing changed*. An attach has no previous
/// assertion to lean on, and it runs in a state nobody had in mind when the
/// `online` write was put there:
///
/// `AppDelegate.didFinishLaunchingWithOptions` calls `engine.run()` on EVERY
/// iOS launch, including the background one an incoming VoIP push triggers —
/// that is exactly what lets Dart restore auth and attach signaling so an
/// answered call connects (see the comment on that method). So a phone that
/// merely RANG runs this path, headless, with nobody looking at it. Hardcoding
/// `online` here meant being called marked you as present: the callee lit up
/// green in the caller's UI having never opened the app, and stayed green
/// because [_startPresenceHeartbeat] then kept `lastSeen` fresh underneath it.
///
/// That is also why every non-foreground state must write `away` rather than
/// stay quiet. Silence leaves the STORED status untouched — very often a stale
/// `online` from the last real session — while the heartbeat refreshes
/// `lastSeen` under it, and `users.heartbeat` only refuses to resurrect
/// `offline`. Saying nothing would not fix the lie; it would preserve it.
///
/// A hand-launched app can therefore write `away` and then `online` a few
/// frames later once the first `resumed` lands. That costs one extra write per
/// cold start and buys an honest answer during the moment we genuinely do not
/// know yet. It cannot bring back the Android focus-flap the mapping above
/// exists to prevent: this runs once per attach, not per lifecycle event.
///
/// Kept top-level and pure so it can be tested without a widget tree; see
/// test/presence_lifecycle_test.dart.
String presenceStatusOnAttach(AppLifecycleState? state) =>
    state == AppLifecycleState.resumed ? 'online' : 'away';

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
  late final FeedApi _feedApi = FeedApi(_cv);
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
  late final GroupCallService _groupCallService = GroupCallService.ensure(
    _groupCallApi,
  )..iceConfigFetcher = _callApi.getIceConfig;
  // Cached merged listenable. Created exactly once so AnimatedBuilder's
  // listener subscription on _auth / _themeController is never re-bound
  // across parent rebuilds (each fresh Listenable.merge call would force
  // AnimatedBuilder.didUpdateWidget into a remove-then-add cycle, which has
  // been observed to drop the subscription after a sign-out → sign-in
  // toggle and leave the LoginScreen → HomeShell swap stranded).
  // SettingsStore is included so a language change (see LanguageScreen)
  // takes effect immediately — MaterialApp.locale reads it directly below —
  // instead of waiting for the next screen that happens to rebuild.
  late final Listenable _appListenable = Listenable.merge([
    _themeController,
    _auth,
    SettingsStore.instance,
    // The self-host bar takes height out of the ROOT layout and changes which
    // status-glyph brightness the app asks for, so the whole builder has to
    // re-run when the server changes — not just the widget that draws it.
    ServerStore.instance,
  ]);

  /// Created once so the observer list handed to MaterialApp is stable across
  /// the AnimatedBuilder rebuilds — a fresh observer each build would detach
  /// and reattach on every theme change and lose the route stack.
  final DiagRouteTracker _diagRoutes = DiagRouteTracker();

  bool _bootstrapped = false;
  Object? _bootError;

  /// No deployment to connect to at all — `env.local` carries no `CONVEX_URL`
  /// and no server has been chosen. Its own flag rather than a [_bootError],
  /// because it is not an error: nothing is broken, the app simply has not been
  /// told where to go. The screen it deserves is the one that can answer that,
  /// not a red box whose RETRY would fail identically every time.
  bool _needsServer = false;

  // When a notification fires before auth / navigator are ready (cold start
  // from a tap), stash the target room here and consume it once the app
  // finishes booting and a signed-in session exists.
  String? _pendingPushRoomId;

  /// An invite link that arrived before the app could act on it.
  ///
  /// Same problem and same shape as [_pendingPushRoomId], and it bites harder
  /// here: a cold start from a tapped link delivers the URL through
  /// `getInitialLink` exactly once, with no session restored and no navigator
  /// mounted yet. Dropped, the tap silently does nothing and the user is
  /// looking at a chat list wondering what happened to the invite.
  ///
  /// Unlike a push room this is also held across SIGN-IN. Tapping a group
  /// invite is a perfectly ordinary reason to install the app, and the invite
  /// has to survive the whole account-creation detour to be worth anything.
  InviteLink? _pendingInvite;

  /// Last invite acted on, for the two-deliveries dedupe in [_openInvite].
  String? _lastInviteCode;
  DateTime? _lastInviteAt;

  // Last presence status successfully handed to the server, so a lifecycle
  // sequence that resolves to the same value twice doesn't write twice. Null
  // means "unknown" — on sign-out, or after a failed write — and always sends.
  String? _lastSentStatus;

  // Alert sounds and the web Notification permission both require a user
  // gesture to activate (browser autoplay policy / Notification.requestPermission
  // being ignored outside a gesture). Prime once, on the first pointer down.
  bool _alertsPrimed = false;

  /// Whether web/desktop alert sounds + web banners apply on this platform.
  /// Mobile gets OS notifications from APNs/FCM and needs none of this.
  static bool get _alertsEnabled => isWebOrDesktop;

  void _primeAlerts() {
    if (_alertsPrimed || !_alertsEnabled) return;
    _alertsPrimed = true;
    AlertSounds.instance.unlock();
    WebNotifier.requestPermission();
    // Ask for notification permission from THIS gesture — browsers ignore the
    // request otherwise — then claim a Web Push subscription so a
    // backgrounded/closed tab still gets banners. No-op off web.
    WebPush.promptPermission();
    unawaited(PushManager.instance.registerWebPushAfterPermission());
  }

  // Presence keepalive. Stamps `lastSeen` every 30s while signed in so the
  // server can treat a client that stopped heartbeating (closed browser tab,
  // killed app) as offline — the robust cross-platform fix for "still shows
  // online after closing". See backend presence.ts / users:heartbeat.
  Timer? _presenceHeartbeat;

  /// Debounce timer for the auxiliary foreground sync scheduled on `resumed`,
  /// and the floor between two of those syncs actually running.
  ///
  /// 30s is far below any interval at which the work matters — it re-checks a
  /// push token and the family context — and far above the ~1.2s at which a
  /// self-re-arming notification prompt used to drive it. See the scheduling
  /// site in [didChangeAppLifecycleState].
  Timer? _resumeSyncTimer;
  DateTime? _lastResumeSync;
  static const _resumeSyncMinInterval = Duration(seconds: 30);

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
    _family.addListener(_syncAccountType);
    PushManager.instance.setOnOpenRoom(_openRoomFromPush);
    PushManager.instance.setOnOpenRequests(_openRequestsFromPush);
    PushManager.instance.attachApi(_api);
    PushManager.instance.setActiveRoomIdProvider(() => _repo.activeRoomId);
    // Web message-banner clicks open the room, same as a push tap.
    MessageAlerts.instance.setOnOpenRoom(_openRoomFromPush);
    // Web Push banner clicks (background/closed tab) open the room too — the
    // service worker posts the roomId to whichever tab it focuses.
    WebPush.setOnOpenRoom(_openRoomFromPush);
    // Inbound universal links / App Links. Reported here rather than acted on:
    // `_openInvite` decides whether the app is ready and stashes if not.
    DeepLinkService.instance.onInvite = _openInvite;
    unawaited(DeepLinkService.instance.start());
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
    // Everything a server switch needs that only this class holds: the session
    // to unwind, the transition to wait on, and the health monitor to restart.
    // [ServerSwitch] owns the ordering; this hands it the three verbs.
    ServerSwitch.instance.install(
      detach: _detachForServerSwitch,
      onRebound: _onServerRebound,
      canSwitch: () => !_auth.isChild,
    );
    _bootstrap();
  }

  /// Unwind this device from the deployment it is leaving, while that
  /// deployment is still reachable.
  ///
  /// Sign-out already does every piece of this — deleting the push row so
  /// nothing addressed to the old account can reach the handset again,
  /// cancelling every subscription, ending calls, clearing the media caches —
  /// so this method's whole job is to run it and, crucially, to WAIT for it.
  ///
  /// [AuthService.signOut] returns as soon as the local session is gone; the
  /// teardown it kicks off runs inside [_onAuthChange], which is a listener
  /// callback nobody can await. [_authTransition] exists for exactly this: it
  /// is the handle on that work, and skipping it would tear the socket down
  /// mid-`PushManager.logout` and leave a device row on the old server pointed
  /// at a handset that has moved on.
  Future<void> _detachForServerSwitch() async {
    if (_auth.session != null) await _auth.signOut();
    await _authTransition;
  }

  /// Ask the deployment we are pointed at where clients should be, and move if
  /// it says somewhere else.
  ///
  /// Runs at two moments, and both matter:
  ///
  ///  * **Before the first connect**, so the app opens its socket against the
  ///    right backend rather than connecting, learning, and reconnecting.
  ///  * **On resume**, throttled by [ServerDirectory.recheckInterval], so a
  ///    phone that has been in a pocket since before the move catches up
  ///    without being relaunched. Piggybacks on the resume sync that already
  ///    exists, so it inherits its debounce as well as its own floor.
  ///
  /// [live] separates the two: before the client exists there is nothing to
  /// tear down, so the answer is simply written to the store and picked up by
  /// the initialize that follows. Once the app is running, moving means
  /// rebuilding the socket — and that goes through [ServerSwitch.follow],
  /// which keeps the session because the two deployments hold the same data.
  Future<void> _followServerDirective({bool live = false}) async {
    final askUrl = ServerStore.instance.deploymentUrl;
    if (askUrl.isEmpty) return;
    final target = await ServerDirectory.instance.check(askUrl: askUrl);
    if (target == null || !mounted) return;
    if (!live) {
      // Straight to the store: `_bootstrap` initializes the client on the very
      // next line, so this is the cheapest possible way to land on the right
      // deployment — no socket has been built to throw away yet.
      if (target.deploymentUrl == ServerStore.instance.bundledUrl) {
        await ServerStore.instance.useBundled();
      } else {
        await ServerStore.instance.use(target);
      }
      return;
    }
    await ServerSwitch.instance.follow(target);
  }

  /// The directive changed under a running app.
  ///
  /// Says so before doing it. The move itself is a brief reconnect — the two
  /// deployments are replicated, so nothing is lost and nobody is signed out —
  /// but it is still the app quietly changing which machine holds the
  /// conversation somebody is in the middle of, and that is not something to do
  /// silently. The bar appearing (or going) is the durable half of the answer;
  /// this is the moment it happens.
  void _onLiveRedirect(ServerEndpoint target) {
    if (ServerSwitch.instance.busy) return;
    _toastServerChange();
    unawaited(ServerSwitch.instance.follow(target));
  }

  void _toastServerChange() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(ctx).serverDirectiveChangedToast),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// A new transport exists. Clear whatever boot state was standing in the way
  /// and start watching the new socket.
  ///
  /// Deliberately does NOT call `_auth.restore()`. The stored session — if the
  /// keychain still held one — was minted by the deployment we just left, and
  /// presenting its userId to a different backend is precisely the thing this
  /// whole sequence exists to prevent.
  void _onServerRebound() {
    if (!mounted) return;
    setState(() {
      _bootError = null;
      _needsServer = false;
      _bootstrapped = true;
    });
    _health.start();
    // Re-attached, not merely left alone. A follow keeps the query set and
    // re-binds it, but an `apply` (a self-hosting switch) abandons it — and
    // either way the answer to "am I allowed to be watching this at all"
    // changes with the deployment. [ServerDirectory.watch] is idempotent and
    // declines on a self-hosted install.
    unawaited(ServerDirectory.instance.watch(_cv, onRedirect: _onLiveRedirect));
  }

  /// Land a friend-request / approval notification tap on the requests list.
  ///
  /// Unlike [_openRoomFromPush] there's nothing to stash for a cold start:
  /// [UiSelectionStore] holds the request until [DiscoverScreen] mounts and
  /// consumes it, which covers the launch-from-notification case for free.
  ///
  /// Requests moved out of the chat list into Discover, so this steers the
  /// shell there — but with `persist: false`. A notification tap should decide
  /// where you land *now*, not quietly rewrite which section the app opens on
  /// for good. (That was invisible before only because this always set Chat,
  /// which is the default anyway.)
  void _openRequestsFromPush() {
    UiSelectionStore.instance.requestRequestsView();
    SettingsStore.instance.setSection(HomeSection.discover, persist: false);
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
  }

  void _openRoomFromPush(String roomId) {
    // On a cold start from a notification tap, the platform's tap event can
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

  /// An invite link was tapped. Show the join screen — never join anything.
  ///
  /// Held back in exactly two states, and they are different waits:
  ///
  ///  * **No navigator yet** — a cold start. One post-frame hop and it exists.
  ///  * **Signed out** — could be a long wait. The user has to make an account
  ///    or sign in first, and the invite must still be there when they do,
  ///    which is why [_pendingInvite] is flushed from the auth listener rather
  ///    than only at boot.
  ///
  /// Pushes onto the ROOT navigator on every window class. This is not an
  /// `openRoom`-style two-pane decision: the user is not yet in the room and
  /// there is nothing to select — the join screen is a full-screen gate on
  /// desktop too, and it hands off to the pane itself once the join lands.
  void _openInvite(InviteLink invite) {
    // One tap, two deliveries: the binding observer above and the `app_links`
    // stream both report a warm link. Without this the second one pops the
    // join screen the first one pushed and pushes an identical replacement —
    // visible as a flicker, and a wasted preview query.
    //
    // Time-boxed rather than remembering forever: pasting the same code again
    // a minute later is a real thing to do and must still work.
    final now = DateTime.now();
    if (invite.code == _lastInviteCode &&
        _lastInviteAt != null &&
        now.difference(_lastInviteAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastInviteCode = invite.code;
    _lastInviteAt = now;

    if (_auth.session == null || rootNavigatorKey.currentState == null) {
      _pendingInvite = invite;
      return;
    }
    _pendingInvite = null;
    final nav = rootNavigatorKey.currentState!;
    // Land cleanly on the shell first. Without this, a link tapped while a
    // room, a sheet or a settings sub-screen is open buries the join screen
    // under whatever was there and leaves a back stack nobody expects.
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute(
        builder: (_) => JoinByInviteScreen(
          repo: _repo,
          api: _api,
          code: invite.code,
          serverUrl: invite.serverUrl,
        ),
      ),
    );
  }

  /// Claim inbound URLs before `WidgetsApp` tries to route them.
  ///
  /// **This is a crash fix, not an optimisation.** `_WidgetsAppState` also
  /// observes route information, and with a Navigator-1.0 app (`home:`, no
  /// router) its response is `pushNamed(location)` — which for a tapped invite
  /// means `pushNamed('/j/Q294FR4R07')`, a route no generator produces:
  ///
  ///   Could not find a generator for route RouteSettings("/j/…")
  ///
  /// `WidgetsBinding` walks its observers in registration order and STOPS at
  /// the first that returns true. This state registers itself in `initState`,
  /// which runs before `MaterialApp` is ever built, so returning true here
  /// means `WidgetsApp` never sees the URL.
  ///
  /// Returning FALSE for anything that is not an invite is deliberate: this is
  /// not a router, and swallowing unknown routes would hide a real
  /// misconfiguration behind silence.
  ///
  /// `app_links` still exists and is still the only thing that catches a COLD
  /// start, where the URL is waiting in `getInitialLink()` before any observer
  /// is listening. Warm links now arrive through both, which is why
  /// [_openInvite] ignores a repeat of the same code.
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final invite = parseInviteLink(routeInformation.uri.toString());
    if (invite == null) return false;
    _openInvite(invite);
    return true;
  }

  void _consumePendingInvite() {
    final pending = _pendingInvite;
    if (pending == null) return;
    if (_auth.session == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A newer link landing while this one waited wins; replaying the stale
      // one on top of it would open the wrong room's invite.
      if (_pendingInvite != pending) return;
      _openInvite(pending);
    });
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

  /// Window metrics changed — padding, insets, scale.
  ///
  /// Nothing in this app implemented this before; it exists purely as a
  /// detector. Every `SafeArea` in the app moves with these values, so a window
  /// whose insets keep changing produces exactly the reported symptoms — the UI
  /// strobing, the bottom nav sliding out from under a finger between
  /// pointer-down and pointer-up, and the IME closing a frame after it opens.
  /// [MetricsWatch] emits only on real change and collapses a storm into one
  /// warning, so this cannot flood the buffer it is trying to fill.
  @override
  void didChangeMetrics() {
    MetricsWatch.instance.onMetricsChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The RAW state, before any of the interpretation below. The whole reason
    // presence churn was misread once already is that only the derived value
    // was visible; logging both is what makes the derivation checkable from a
    // log file rather than from re-reading this method.
    DiagLog.lifecycle(
      '$state → presence=${presenceStatusFor(state) ?? 'none'} '
      '(last sent ${_lastSentStatus ?? 'none'})',
    );
    // A backgrounding is the last chance to get the tail of the log onto disk.
    if (state != AppLifecycleState.resumed) {
      unawaited(DiagBuffer.instance.flush());
    }
    // Above the session check on purpose: connection health must keep tracking
    // foreground/background across a signed-out window, so a sign-in that lands
    // right after a resume doesn't inherit a parked recovery loop.
    //
    // `inactive` counts as foreground: the app is still running with live timers
    // and a live socket, and iOS fires it for every Control Centre swipe and
    // app-switcher peek. Parking there would stall recovery mid-outage and burn
    // a probe on the way back for something that never interrupted anything.
    //
    // On web the whole park/rebuild mechanism is switched off, because the
    // premise it rests on is a mobile one. `backgroundRebuildThreshold` exists
    // for a socket whose NAT binding expired or whose interface changed while
    // the *device* slept — something neither end notices, so the gap length is
    // the only evidence available. A browser tab that loses focus is not that:
    // the tab keeps running, and the WebSocket stays open and healthy. And in
    // the case where the browser really does freeze the tab, the socket is
    // closed for us and `onclose` schedules the reconnect — evidence, not
    // inference.
    //
    // Meanwhile the events themselves are near-meaningless here. Flutter web
    // fires `hidden` for a window blur, not just a tab hide, so alt-tabbing or
    // clicking the address bar produces one. A captured session shows four
    // park/resume cycles in 84 seconds — "resumed after 22s", "after 6s",
    // "after 5s" — each one clearing the backoff and forcing a full socket
    // teardown and rebuild on a connection that had nothing wrong with it. That
    // is the same reasoning that already makes `inactive` count as foreground
    // above; web just needs it applied one state further.
    _health.setForeground(
      kIsWeb ||
          state == AppLifecycleState.resumed ||
          state == AppLifecycleState.inactive,
    );
    // The publisher's power tier, driven from here rather than from the room
    // screen because a live share outlives the screen that started it: walking
    // out of the chat, or opening Settings, must not look like backgrounding.
    //
    // `inactive` counts as visible for the same reason it counts as foreground
    // above — iOS fires it for every Control Centre swipe — and here the cost of
    // getting it wrong is concrete: each mode change tears down and reopens the
    // OS position stream, so a share would rebuild it twice per app-switcher
    // peek. Web is excluded because there is no background mode to switch to.
    if (!kIsWeb) {
      _repo.liveLocation.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      );
    }
    final session = _auth.session;
    if (session == null) return;
    final next = presenceStatusFor(state);
    // Null means "this state says nothing about presence" — see
    // [presenceStatusFor]. Leaves _lastSentStatus untouched, so the next state
    // that DOES mean something is still compared against what the server holds.
    if (next == null) return;
    // Only write on an actual change. A single lock/unlock walks through
    // inactive → hidden → inactive → resumed, and three of those four map to
    // the same 'away' — so the unguarded version fired a burst of mutations at
    // the exact moment the radio is least able to carry them, at a deployment
    // where this one-document patch has been seen exceeding Convex's 1s
    // function limit.
    //
    // Note this guard only suppresses REPEATS, never alternation: an
    // online→away→online→away sequence writes every single time, on this side
    // and on the server's (`users:updateStatus` dedupes on the same value too).
    // That is why [presenceStatusFor] refusing to react to `inactive` matters
    // so much more than the guard does.
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
      //
      // Cancelled and rescheduled rather than stacked: an app that flips
      // foreground repeatedly used to leave one live timer per flip, all of
      // them still due to fire.
      _resumeSyncTimer?.cancel();
      _resumeSyncTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        // None of this is per-resume work in any real sense — it re-checks a
        // token the backend may have cleared and re-reads the family context.
        // Throttling it decouples "how often the OS says we came back" from
        // "how much traffic we generate", so a focus flicker from ANY source
        // — a permission activity, a heads-up notification, the call UI —
        // can't turn into a mutation storm the way it did on Android when the
        // notification prompt re-armed itself every 1.2 seconds.
        final now = DateTime.now();
        final last = _lastResumeSync;
        if (last != null && now.difference(last) < _resumeSyncMinInterval) {
          return;
        }
        _lastResumeSync = now;
        // The device is unlocked by definition once we are resumed, so this is
        // the moment a keychain read that failed on a locked cold start can
        // finally succeed. Without it a single `-25308` left calls dead until
        // the next relaunch — [_attachCallStack] has the full account. No-ops
        // once attached.
        final resumeSession = _auth.session;
        if (resumeSession != null && !_callStackAttached) {
          unawaited(_attachCallStack(resumeSession));
        }
        BadgeManager.instance.sync();
        PushManager.instance.refreshTokens();
        _family.refresh();
        // Catches a handset that was in a pocket when the deployment moved.
        // Its own floor on top of this block's 30s debounce — see
        // [ServerDirectory.recheckInterval] — because a resume is common and a
        // migration is not.
        if (ServerDirectory.instance.dueForRecheck) {
          unawaited(_followServerDirective(live: true));
        }
        // Reconcile native CallKit/ConnectionService cards against backend
        // truth on every resume, not just cold start (app.dart used to call
        // this once at session-attach only) — a call that ended while we
        // were backgrounded, but whose native-clear push we missed, gets
        // swept here instead of staying stuck until the next full relaunch.
        unawaited(NativeCallHandler.instance.replayColdStartCalls());
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

    // Before anything touches the client: is there a server at all? A build
    // whose `env.local` carries no CONVEX_URL, on a device that has not chosen
    // one, has nothing to connect to and nothing to apologise for. Sending it
    // through `initialize()` would produce a red boot error offering a RETRY
    // that cannot succeed; the server screen can actually fix it.
    if (ServerStore.instance.deploymentUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _needsServer = true;
          _bootstrapped = true;
        });
      }
      return;
    }

    // Ask where clients should be BEFORE opening a socket, so a device that
    // has to move never connects to the deployment it is leaving. Bounded by
    // [ServerDirectory.launchTimeout] — this sits in front of the first frame
    // of real content, and silence means "carry on", never "wait longer".
    //
    // Cheap to get wrong in only one direction, which is why it is safe here:
    // every failure path returns null and the app proceeds on the deployment
    // it already had. That includes a backend with no `serverDirectory`
    // function, which is what every deployment looks like until it is deployed.
    await _followServerDirective();

    final initErr = await _cv.initialize();
    if (initErr == null) {
      _health.start();
      // Now that a socket exists, stop asking and start listening. The launch
      // check above covers the moment before there is anything to listen on;
      // this covers every moment after, so a deployment that moves while
      // somebody is mid-conversation moves them too, rather than waiting for
      // them to close the app.
      unawaited(
        ServerDirectory.instance.watch(_cv, onRedirect: _onLiveRedirect),
      );
    }
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
    } catch (e, st) {
      // Still non-fatal — secure storage may genuinely be absent in a test
      // harness — but no longer silent. On a real handset this catch also
      // absorbs a keychain `-25308` (the device has not been unlocked since
      // boot, so not even `first_unlock_this_device` can be read), and it
      // turned "keychain locked" into "signed out" with no trace at all: the
      // user is dropped at the login screen and the diagnostics file offers
      // nothing to explain why.
      DiagLog.error('session restore failed', e, stack: st);
      debugPrint('_auth.restore failed: $e\n$st');
    }

    // Set _bootstrapped true immediately so the UI mounts in <150ms from local cache.
    if (mounted) setState(() => _bootstrapped = true);

    // No attach here on purpose. [AuthService.restore] above notifies
    // unconditionally, and [_onAuthChange] — subscribed in initState, before
    // this runs — has already started the attach by the time restore's future
    // completes. Doing it again from here is what put TWO of every repo
    // subscription on the wire for a restored session: both callers passed
    // their re-attach guard (this one never had one), and because
    // [ChatRepository.attach] awaits between cancelling the old handles and
    // assigning the new ones, the second attach found every handle still null,
    // cancelled nothing, and overwrote them — leaving the first attach's
    // rooms/friends/requests/typing subscriptions live with no handle to close
    // them. Every update arrived and was parsed twice for the rest of the
    // session. Captured on a Galaxy S24: r=37 AND r=39 for `listUserRooms`,
    // r=40 AND r=41 for `listFriends`, and so on down the group.
    _consumePendingPushRoom();
    _consumePendingInvite();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.instance.ensure();
      // Keeps the Settings badge honest after launch: an app that is never
      // force-quit would otherwise never learn about a release published
      // while it was running.
      unawaited(UpdateChecker.instance.watch());
      // Puts the primary adaptive icon back on Android for anyone an earlier
      // build left on a theme alias. A no-op on every launch after the first
      // one that repairs it, and on iOS where the selection is honoured.
      SettingsStore.instance.reconcileLauncherIcon();
      // Covers the cold-start-restore case: an account signed in on a previous
      // launch that still has no recovery phrase. Fire-and-forget, and it
      // queries only after the shell is already on screen.
      if (_auth.session != null) {
        unawaited(RecoveryGate.instance.ensure(_auth, _api));
      }
    });
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

  /// Whether [_attachCallStack] has completed for the current session.
  ///
  /// Its own guard, because [_onAuthChange]'s (`_repo.userId != s.userId`) is
  /// no use here: `_repo.attach` runs immediately after the attach and sets
  /// that id whether the attach succeeded or threw, so from then on every
  /// `notifyListeners` no-ops the whole block. A single failed attach was
  /// therefore permanent for the process — see [_attachCallStack].
  bool _callStackAttached = false;

  /// Attach the calling stack: CallService, group calls, and the signaling
  /// socket. Kept on its own failure boundary and idempotent, so the resume
  /// handler can re-run it.
  ///
  /// The retry is not theoretical. Every one of these needs a device id, and
  /// [DeviceIdentity.ensure] reads the keychain — which throws
  /// `errSecInteractionNotAllowed (-25308)` when the phone is locked. A VoIP
  /// push cold-starting a locked handset therefore lands here, throws on the
  /// very first line, and skips the entire calling stack: CallKit rings from
  /// native, Dart has nothing to answer with, and the call vanishes. Calls
  /// then stay dead for the whole process — which is what the retry fixes.
  /// (The accessibility class that caused it is fixed in [DeviceIdentity]; this
  /// covers the residue, including a device that has not been unlocked at all
  /// since boot, where no accessibility class can help.)
  Future<void> _attachCallStack(Session s) async {
    if (_callStackAttached) return;
    try {
      final deviceId = await DeviceIdentity.ensure();
      _callService.attach(
        userId: s.userId,
        displayName: s.name,
        deviceId: deviceId,
      );
      _groupCallService.attach(userId: s.userId, deviceId: deviceId);
      // The audio-session deactivation belt must know about group calls —
      // they raise no CallKit card, so the native no-op-while-a-card-is-
      // alive guard can't see them. Without this, canceling a 1:1 ring
      // DURING a group call would cut the group call's live audio.
      NativeCallHandler.groupCallActiveProbe = () => _groupCallService.inCall;
      await _signaling.start(s.userId, deviceId: deviceId);
      _callStackAttached = true;
      // Fire-and-forget: reconciling stale native cards must never be
      // able to delay the live signaling path that was just opened.
      unawaited(NativeCallHandler.instance.replayColdStartCalls());
    } catch (e, st) {
      // Never silent — an unattached call stack is invisible otherwise,
      // which is exactly how this went unnoticed.
      DiagLog.error('call attach failed', e, stack: st);
      debugPrint('CRITICAL: call stack attach failed: $e\n$st');
    }
  }

  /// The in-flight attach or teardown kicked off by the last auth change.
  ///
  /// [AuthService] notifies synchronously and the work below is asynchronous,
  /// so between the two there was nothing anyone could wait on — fine while the
  /// only caller was the framework, wrong the moment a server switch needed to
  /// know that sign-out had finished unwinding before the socket went away.
  /// See [_detachForServerSwitch].
  Future<void>? _authTransition;

  void _onAuthChange() {
    _authTransition = _applyAuthChange();
  }

  Future<void> _applyAuthChange() async {
    final s = _auth.session;
    try {
      if (s != null && _repo.userId != s.userId) {
        // ─────────── recovery is armed FIRST, above every await below ──
        //
        // A session now exists, so ConnectionHealth has something worth healing
        // for (`isActive` reads `_auth.session`). Its recovery loop parks while
        // signed out, and nothing else wakes it: `_health.start()` runs BEFORE
        // `_auth.restore()`, so the loop parks at boot, and a socket `down`
        // edge deliberately does not wake a parked loop.
        //
        // These two lines used to sit at the END of this block, behind
        // `await _repo.attach(...)` — which awaits subscriptions that are
        // unbounded at every layer (no `.timeout` in `NativeConvexClient
        // .subscribe`, none in the Rust `internal_subscribe`). On a socket that
        // never completes its handshake that await simply never returns, so the
        // one line that starts recovery was unreachable in exactly the case
        // recovery exists for. A capture of a locked-phone cold start shows the
        // result: zero probes issued in the first eighteen minutes, and the
        // `attach … → presence=` line below never printed at all.
        //
        // The heartbeat moves for the same reason — `noteRoundTrip` is the only
        // path back online that does not depend on the probe loop, and it never
        // got to start either. Neither call needs the repo.
        unawaited(_health.retryNow());
        _startPresenceHeartbeat(s.userId);

        // ─────────── calling attaches next, on its own failure boundary ──
        // This block used to sit at the END of this method, behind
        // `await _repo.attach(...)` and `await PushManager.login(...)`, all
        // inside the single swallow-everything catch below. Two ways that
        // silently killed every incoming call on this device:
        //   1. `PushManager.login` awaits OneSignal login AND the
        //      notification-permission prompt. On a cold start woken by a
        //      VoIP push, that can hang indefinitely — and everything after
        //      it, including the entire call stack, never runs.
        //   2. Anything above throwing lands in the shared `catch (_) {}`,
        //      which logs nothing at all.
        // Either way `CallService` stayed unattached and
        // `calls:signalsForUser` was never subscribed, so an incoming call
        // rang the native CallKit UI (PushKit is native and needs none of
        // this) while Dart had no session to answer with — the call was
        // dead on arrival and simply vanished a moment later.
        await _attachCallStack(s);

        await _repo.attach(s.userId);
        _family.attach(s.userId);
        unawaited(FeedStore.instance.attach(_feedApi, s.userId));
        // Deliberately NOT awaited — see the note above. Push registration is
        // a best-effort background concern; nothing in this method may block
        // on it. The opt-out still has to follow the login that would
        // otherwise re-enable notifications, so the two stay chained to each
        // other rather than to us.
        unawaited(() async {
          try {
            await PushManager.instance.login(s.userId);
            // [PushManager.login] registers this device for push
            // unconditionally, so an account that turned notifications OFF
            // has to be opted back out straight afterwards or a cold start
            // silently re-enables them.
            if (!SettingsStore.instance.pushEnabled) {
              await PushManager.instance.optOut();
            }
          } catch (e, st) {
            DiagLog.error('push login failed', e, stack: st);
          }
        }());
        // Report presence on first attach — from the ACTUAL lifecycle state,
        // never a hardcoded 'online'. This method also runs on the headless
        // background launch an incoming VoIP push triggers, where assuming
        // foreground turned "their phone rang" into "they are online"; see
        // [presenceStatusOnAttach] for the full account.
        //
        // Recorded in _lastSentStatus like every other write: without that the
        // dedupe guard in didChangeAppLifecycleState starts each session
        // holding a stale value (usually null), so the first `resumed` after
        // sign-in wrote 'online' a second time for no reason.
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        final attachStatus = presenceStatusOnAttach(lifecycle);
        // Both halves, for the same reason didChangeAppLifecycleState logs
        // both: the derived value alone can't tell you whether a surprising
        // presence write came from a bad mapping or from a lifecycle state we
        // didn't expect to attach in. This is the line that shows a background
        // VoIP launch reporting something other than `resumed`.
        DiagLog.lifecycle(
          'attach ${lifecycle ?? 'unknown'} → presence=$attachStatus',
        );
        _lastSentStatus = attachStatus;
        _api.updateStatus(userId: s.userId, status: attachStatus).catchError((
          _,
        ) {
          _lastSentStatus = null;
        });
        BadgeManager.instance.bind(_repo);
        MessageAlerts.instance.bind(_repo);
        _consumePendingPushRoom();
        // The sign-in that a tapped invite sent someone through. This is the
        // flush that matters most: on a fresh install the link arrives long
        // before there is an account to join with.
        _consumePendingInvite();
        // Covers the fresh-sign-in case, including the rotation owed after a
        // password reset — the reset signs the user in, which disposes the
        // LoginScreen that would otherwise have pushed the gate.
        unawaited(RecoveryGate.instance.ensure(_auth, _api));
      } else if (s == null) {
        // Drop the per-account latch so signing in as someone else re-checks.
        RecoveryGate.instance.reset();
        // Same for the attach latch — the next account needs its own attach.
        _callStackAttached = false;
        _stopPresenceHeartbeat();
        BadgeManager.instance.unbind();
        MessageAlerts.instance.unbind();
        _family.detach();
        await _repo.detach();
        // Drops the cached board as well as the subscription — those moments
        // are another account's data and must not flash on screen for whoever
        // signs in next on a shared handset.
        await FeedStore.instance.detach();
        // Same rule for the daily games: the standings carry friends' names.
        GamesStore.instance.clear();
        // Deletes this device's row, which takes every push credential with it
        // — including the browser's Web Push subscription. Nothing addressed to
        // the account that just signed out can reach this device again.
        await PushManager.instance.logout();
        // Storage URLs aren't secret, but the next account shouldn't inherit
        // the previous one's working set — and a stale entry pointing at a file
        // that got GC'd would just render a broken tile.
        await FileUrlCache.instance.clear();
        await MediaAspectCache.instance.clear();
        // Cached voice notes aren't secret either, but unlike the two above
        // they occupy real disk, and a signed-out account shouldn't leave
        // someone else's audio on the device. Watched videos are the same
        // argument at a hundred times the size.
        await AudioFileCache.instance.clear();
        await VideoFileCache.instance.clear();
        // End the calls BEFORE stopping the signaling subscription: endCall
        // still wants its terminal mutation on the wire, and stop() first
        // used to leave a window where a peer's bye/cancel arrived with
        // nobody listening.
        await _callService.endCall();
        await _groupCallService.leaveCall();
        await _signaling.stop();
        _callService.detachWatch();
        // Reset landing tab so the next sign-in starts on Chat instead of
        // wherever the previous session left off (e.g. Settings, which is
        // where Sign Out is reached from).
        await SettingsStore.instance.setSection(HomeSection.chat);
      }
    } catch (e, st) {
      // Don't crash the listener pipeline — the UI (AnimatedBuilder) is on a
      // separate listener slot and must stay reactive even if repo setup
      // throws. But never swallow silently: this catch hid a dead call stack
      // for as long as it existed. The calling attach above has its own
      // boundary, so a failure here no longer takes calls down with it.
      DiagLog.error('auth attach failed', e, stack: st);
      debugPrint('_onAuthChange failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    ServerDirectory.instance.unwatch();
    _stopPresenceHeartbeat();
    _resumeSyncTimer?.cancel();
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
          final theme = _themeController.theme;
          final isLight = theme.mood == ThemeMood.riso;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            // Root navigator only. Screen attribution turns a flat list of
            // function names into something you can reason about, and the
            // push/pop events are their own signal — a route that opens and
            // closes repeatedly is a bug shape worth seeing next to the layout
            // events it interleaves with.
            navigatorObservers: [_diagRoutes, appRoutes],
            title: 'MonkeyHub',
            // Null follows the system language, resolved against
            // supportedLocales by Flutter's default algorithm (falls back to
            // the first entry — English — when the device locale isn't
            // supported). A saved SettingsStore.localeCode pins the app to
            // that language regardless of the device. See LanguageScreen.
            //
            // A code may carry a region ('pt_BR', to pick Brazilian
            // Portuguese apart from European) — Locale(languageCode,
            // countryCode) needs those passed separately, not concatenated
            // into one string, so split on the underscore.
            locale: () {
              final code = SettingsStore.instance.localeCode;
              if (code == null) return null;
              final parts = code.split('_');
              return parts.length > 1
                  ? Locale(parts[0], parts[1])
                  : Locale(parts[0]);
            }(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              // The language the app SETTLED on, which is not knowable from
              // either of the two things that produce it: `locale:` above is
              // null whenever the user has not overridden anything, and the
              // device locale may not be supported at all. This builder sits
              // below WidgetsApp's Localizations, so it is the first place the
              // resolved answer exists — recorded for the diagnostics header
              // and the problem report, both of which are context-free.
              // Idempotent, and rerun on every language change.
              DeviceReport.appLocaleTag = Localizations.localeOf(
                context,
              ).toLanguageTag();

              // _WindowClassProvider hosts the single app-wide LayoutBuilder
              // ABOVE the root navigator, so every route — the shell and any
              // full-screen push (profile, search, room, …) — reads the same
              // WindowClass via context. The `child` (navigator) is captured,
              // so a drag-resize only rebuilds the LayoutScope wrapper, never
              // this Stack.
              //
              // The AnnotatedRegion is the other half of the edge-to-edge fix
              // in main(): with no style declared, Android 15+ re-derives the
              // bar appearance on every window resize — including the resize
              // the soft keyboard causes — which is the visible strobe at the
              // top of the screen. Pinning it here rather than calling
              // SystemChrome imperatively keeps it correct across theme
              // switches for free, since this builder reruns on the same
              // listenable the theme does.
              //
              // Contrast enforcement is off on purpose. That scrim is drawn by
              // the SYSTEM behind each bar and re-evaluated against whatever
              // currently sits underneath, so on any scrolling or animating
              // screen it pulses by design — leaving it on would keep a milder
              // version of the same flicker after the inset fix lands.
              //
              // Safe to govern the whole app from one region: `grep AppBar(`
              // returns zero hits in lib/, so nothing deeper annotates a
              // competing style the way a Material AppBar would.
              // While the self-host bar is up it, not the theme, is what sits
              // behind the status glyphs — and it is dark under every theme.
              // Without this the light (riso) themes asked for dark glyphs and
              // painted them on a near-black strip.
              final serverBar = SelfHostBar.consumesTopInset;
              final darkStatusSurface = !isLight || serverBar;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                  systemStatusBarContrastEnforced: false,
                  systemNavigationBarContrastEnforced: false,
                  // Glyphs contrast AGAINST the surface behind them: dark
                  // icons on the light (riso) themes, light icons elsewhere.
                  statusBarIconBrightness: darkStatusSurface
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarIconBrightness: isLight
                      ? Brightness.dark
                      : Brightness.light,
                  // iOS reads this one instead, and it is inverted from the
                  // pair above: it names the BAR's brightness, not the glyphs'.
                  statusBarBrightness: darkStatusSurface
                      ? Brightness.dark
                      : Brightness.light,
                ),
                child: Listener(
                  // Observe (never consume) the first pointer-down to unlock
                  // audio + request notification permission within a user gesture.
                  onPointerDown: _alertsPrimed ? null : (_) => _primeAlerts(),
                  child: _WindowClassProvider(
                    child: Stack(
                      children: [
                        // The self-host bar is the one piece of app-wide chrome
                        // that participates in LAYOUT rather than floating over
                        // it: everything else shifts down by its height. Three
                        // overlay shapes were tried first and each collided with
                        // something — the status glyphs, a route's close button,
                        // the dynamic island. A bar collides with nothing
                        // because it overlaps nothing.
                        //
                        // `removeTop` is the other half of that bargain. The bar
                        // has already covered the status-bar inset, so leaving
                        // `padding.top` in place below it would have every
                        // SafeArea in the app inset a second time. The condition
                        // is [SelfHostBar.consumesTopInset] on both sides
                        // precisely so the two cannot disagree.
                        Column(
                          children: [
                            const SelfHostBar(),
                            Expanded(
                              child: MediaQuery.removePadding(
                                context: context,
                                removeTop: serverBar,
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
                                            ActiveCallPill(
                                              service: _callService,
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Pushes call screens onto the root navigator the moment
                                    // the call service transitions to a non-idle state.
                                    // Invisible.
                                    _CallOverlay(
                                      service: _callService,
                                      api: _api,
                                    ),
                                    // Same job for group calls: pushes GroupCallScreen /
                                    // the group invite ringer. Invisible.
                                    _GroupCallOverlay(
                                      service: _groupCallService,
                                      api: _api,
                                    ),
                                    // Listens for a deliberate shake and OFFERS the report
                                    // screen. Invisible; mounted here only so the sensor
                                    // subscription's lifetime matches the app's. Gated on
                                    // bootstrap so a shake during the splash cannot open a
                                    // form over a half-built tree.
                                    if (_bootstrapped && _bootError == null)
                                      ShakeToReport(auth: _auth, api: _api),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Above EVERYTHING, the server bar included, so a screen
                        // recording cannot capture any of it.
                        const CaptureShield(),
                      ],
                    ),
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
              feedApi: _feedApi,
              family: _family,
              themeController: _themeController,
              bootstrapped: _bootstrapped,
              bootError: _bootError,
              needsServer: _needsServer,
              onRetryBoot: () {
                setState(() {
                  _bootError = null;
                  _bootstrapped = false;
                });
                _bootstrap();
              },
              // Pushed on the root navigator rather than swapped into `home`,
              // so BACK returns to the boot error if the user changes their
              // mind. `_onServerRebound` clears `_bootError` on success, and
              // `_AppHome` rebuilds under the pushed route — which is why the
              // screen pops itself once the switch lands.
              onChangeServer: () {
                rootNavigatorKey.currentState?.push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const ServerScreen(),
                  ),
                );
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
    final incomingRinging =
        s != null &&
        s.status == CallStatus.incomingRinging &&
        !s.isCaller &&
        !_nativeRinger &&
        !widget.service.acceptedNatively;
    // Caller-side ringback: no platform provides one natively (CallKit's own
    // UI is silent while the callee's phone rings), so — unlike the incoming
    // case above — this plays on every platform, real phones included. Gated
    // on [localStream] rather than the bare status transition:
    // `CallService.initiate` sets `outgoingRinging` BEFORE `_attachLocalMedia`
    // reclassifies the shared AVAudioSession, so starting playback at the
    // raw status change risks racing that reclassification.
    final outgoingRinging =
        s != null &&
        s.status == CallStatus.outgoingRinging &&
        s.isCaller &&
        widget.service.localStream != null;
    final ringing = incomingRinging || outgoingRinging;
    if (ringing) {
      if (_ringingCallId == s.callId) return;
      _ringingCallId = s.callId;
      AlertSounds.instance.startRingtone();
      // When the tab isn't focused the in-app ringer never mounts (no frames),
      // so surface a persistent OS banner. No-op off web / when focused.
      // Incoming-call only — the caller already knows they're dialing.
      if (incomingRinging && !WebNotifier.isFocused) {
        final l10n = AppLocalizations.of(context);
        WebNotifier.showCall(
          title: l10n.incomingCallNotificationTitle,
          body: s.peerName.isNotEmpty
              ? s.peerName
              : l10n.incomingCallFallbackCaller,
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
                  AppLocalizations.of(context).splashBrand,
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

/// The screen a failed [ConvexBackend.initialize] lands on.
///
/// Carries a route to the server screen as well as a RETRY, and that second
/// button is not a convenience — it is what keeps a self-hosted install from
/// bricking itself. Every other way into the server settings sits behind a
/// signed-in shell or a login screen, and neither is reachable when the client
/// cannot build a socket. Without this, one typo'd address plus one uninstall
/// would be the whole recovery procedure.
class _BootError extends StatelessWidget {
  const _BootError({
    required this.error,
    required this.onRetry,
    required this.onChangeServer,
  });
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onChangeServer;
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
                        AppLocalizations.of(context).bootErrorTitle,
                        style: theme.label.copyWith(
                          color: theme.danger,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.of(context).bootErrorBody,
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: onRetry,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 22,
                              ),
                              decoration: BoxDecoration(
                                color: theme.accent,
                                borderRadius: BorderRadius.circular(
                                  theme.radiusMd,
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context).bootErrorRetry,
                                style: theme.label.copyWith(
                                  color: theme.accentInk,
                                  letterSpacing: 2.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Quieter than RETRY on purpose: a transient outage is
                          // the likelier cause, and this button signs the user
                          // out. It has to be here, but it should not be the
                          // first thing a hand reaches for.
                          Expanded(
                            child: GestureDetector(
                              onTap: onChangeServer,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.divider),
                                  borderRadius: BorderRadius.circular(
                                    theme.radiusMd,
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).serverChangeCta,
                                  style: theme.label.copyWith(
                                    color: theme.inkSoft,
                                    letterSpacing: 2.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // The one fact that turns "can't reach server" from a
                      // shrug into something actionable, and the only place it
                      // appears when the app cannot get past this screen.
                      Text(
                        ServerStore.instance.host,
                        style: theme.monoTiny.copyWith(color: theme.inkMuted),
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
    required this.feedApi,
    required this.family,
    required this.themeController,
    required this.bootstrapped,
    required this.bootError,
    required this.needsServer,
    required this.onRetryBoot,
    required this.onChangeServer,
  });

  final AuthService auth;
  final ChatRepository repo;
  final ChatApi api;
  final FeedApi feedApi;
  final FamilyService family;
  final ThemeController themeController;
  final bool bootstrapped;
  final Object? bootError;

  /// No deployment configured at all — see `_MonkeyHubAppState._needsServer`.
  final bool needsServer;
  final VoidCallback onRetryBoot;
  final VoidCallback onChangeServer;

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
    if (!widget.bootstrapped) return const _Splash();
    // Ahead of the error branch: "nowhere to connect" is a state the server
    // screen resolves outright, and dressing it as a failure first would make
    // the app look broken on a build that is merely unconfigured.
    if (widget.needsServer) return const ServerScreen(onboarding: true);
    if (widget.bootError != null) {
      return _BootError(
        error: widget.bootError!,
        onRetry: widget.onRetryBoot,
        onChangeServer: widget.onChangeServer,
      );
    }
    final theme = widget.themeController.theme;
    final signedIn = widget.auth.isSignedIn;
    return signedIn
        ? HomeShell(
            key: ValueKey('home_${theme.id}'),
            repo: widget.repo,
            api: widget.api,
            feedApi: widget.feedApi,
            auth: widget.auth,
            family: widget.family,
          )
        : LoginScreen(key: ValueKey('login_${theme.id}'), auth: widget.auth);
  }
}
