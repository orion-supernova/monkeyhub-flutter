import 'theme/low_power.dart';
import 'theme/glass_page_transitions.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_service.dart';
import 'auth/session_guard.dart';
import 'backend/call_api.dart';
import 'backend/chat_api.dart';
import 'backend/connection_health.dart';
import 'backend/convex_client.dart';
import 'backend/feed_api.dart';
import 'backend/group_call_api.dart';
import 'backend/presence_api.dart';
import 'backend/server_directory.dart';
import 'backend/server_endpoint.dart';
import 'backend/server_store.dart';
import 'backend/server_switch.dart';
import 'calls/active_call_pill.dart';
import 'calls/draw/screen_share_overlay.dart';
import 'calls/in_call_pill.dart';
import 'calls/live_calls_store.dart';
import 'calls/screen_share.dart';
import 'calls/call_media.dart' show logCallAudioState;
import 'calls/call_models.dart';
import 'calls/call_notification_sync.dart';
import 'calls/call_float.dart';
import 'calls/call_pip.dart';
import 'calls/call_screen.dart';
import 'calls/widgets/call_float_window.dart';
import 'calls/widgets/system_pip_view.dart';
import 'calls/call_service.dart';
import 'calls/group_call_screen.dart';
import 'calls/group_call_service.dart';
import 'calls/incoming_call_screen.dart';
import 'calls/incoming_group_call_screen.dart';
import 'calls/native_call_handler.dart';
import 'calls/phone_call_activity.dart';
import 'calls/signaling_subscriber.dart';
import 'data/chat_repository.dart';
import 'data/feed_store.dart';
import 'data/profile_cache.dart';
import 'data/profile_scope.dart';
import 'expressions/expression_store.dart';
import 'data/games_store.dart';
import 'data/challenges_store.dart';
import 'data/matches_store.dart';
import 'data/records_store.dart';
import 'data/settings_store.dart';
import 'diagnostics/device_report.dart';
import 'diagnostics/diag_buffer.dart';
import 'diagnostics/diag_log.dart';
import 'diagnostics/metrics_watch.dart';
import 'diagnostics/route_tracker.dart';
import 'family/family_service.dart';
import 'companions/brain_manager.dart';
import 'env.dart';
import 'keyboard/desktop_tab_traversal.dart';
import 'keyboard/escape_to_pop.dart';
import 'theme/density.dart';
import 'keyboard/shortcut_host.dart';
import 'auth/recovery_gate.dart';
import 'l10n/generated/app_localizations.dart';
import 'invites/deep_link_service.dart';
import 'invites/invite_link.dart';
import 'main.dart' show rootNavigatorKey;
import 'services/link_opener.dart';
import 'screens/device_login_scan_screen.dart';
import 'screens/join_by_invite_screen.dart';
import 'screens/navigation/route_return.dart' show appRoutes;
import 'share/share_intake.dart';
import 'share/share_targets.dart';
import 'share/shared_payload.dart';
import 'media/audio_file_cache.dart';
import 'media/video_file_cache.dart';
import 'media/file_url_cache.dart';
import 'media/media_aspect_cache.dart';
import 'media/document_file_cache.dart';
import 'media/storage/data_usage_store.dart';
import 'media/storage/media_image_cache.dart';
import 'media/storage/media_ledger.dart';
import 'media/storage/storage_kinds.dart';
import 'media/storage/storage_service.dart';
import 'audio/alert_sounds.dart';
import 'privacy/capture_protection.dart';
import 'push/badge_manager.dart';
import 'push/device_identity.dart';
import 'push/message_alerts.dart';
import 'push/web_push.dart';
import 'push/linux_notifier.dart';
import 'push/push_manager.dart';
import 'push/web_notifier.dart';
import 'push/web_presence.dart';
import 'data/ui_selection_store.dart';
import 'drop/drop_controller.dart';
import 'widgets/drop/drop_chrome.dart';
import 'platform.dart';
import 'screens/home_shell.dart';
import 'screens/games/match_screen.dart';
import 'screens/room_screen.dart';
import 'screens/login_screen.dart';
import 'screens/server_screen.dart';
import 'screens/theme_onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'theme/layout.dart';
import 'theme/theme_preference.dart';
import 'theme/theme_scope.dart';
import 'update/update_checker.dart';
import 'widgets/app_brand_mark.dart';
import 'widgets/app_toast.dart';
import 'widgets/capture_shield.dart';
import 'widgets/desktop_scroll.dart';
import 'widgets/companion_download_banner.dart';
import 'widgets/connection_banner.dart';
import 'widgets/self_host_badge.dart';
import 'widgets/share_target_sheet.dart';
import 'widgets/shake_to_report.dart';
import 'widgets/ios_kit.dart' show groupedFill, groupedMetaStyle, groupedRadius;
import 'widgets/sheet_kit.dart' show SheetActionButton;
import 'web/web_tab_title.dart';
import 'web/web_url_sync.dart';
import 'widgets/route_depth.dart';

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

/// Runs [write] until it completes, retrying failures, for at most [budget].
/// Returns whether it was acknowledged.
///
/// This is how a backgrounding gets its `away` out. iOS keeps the process
/// awake only for the few seconds AppDelegate's `presence-away` background
/// task buys, and the socket is at its least reliable right then: the radio
/// may be dropping, and a mutation that is merely queued when the app
/// suspends never leaves. One fire-and-forget attempt is what used to leave a
/// locked phone reading `online` for minutes. Stops early once [stillWanted]
/// says the answer no longer matters (the app came back to the foreground and
/// wrote `online` itself).
///
/// Re-sending is safe: `users:updateStatus` drops a repeat of the stored
/// value. Kept top-level and pure so it can be tested under fake time; see
/// test/presence_lifecycle_test.dart.
Future<bool> deliverPresenceWithin(
  Future<void> Function() write, {
  required Duration budget,
  Duration attemptTimeout = const Duration(seconds: 2),
  Duration retryDelay = const Duration(milliseconds: 500),
  bool Function()? stillWanted,
}) async {
  var expired = false;
  final deadline = Timer(budget, () => expired = true);
  try {
    while (!expired && (stillWanted?.call() ?? true)) {
      try {
        await write().timeout(attemptTimeout);
        return true;
      } catch (_) {
        // Retried below while the budget lasts.
      }
      if (expired) break;
      await Future<void>.delayed(retryDelay);
    }
    return false;
  } finally {
    deadline.cancel();
  }
}

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
  late final PresenceApi _presenceApi = PresenceApi(_cv);

  /// True once a presence write was answered "function not found": an older
  /// server, so the legacy `users` calls are used straight away instead of
  /// trying (and failing) first on every beat. Reset with the session.
  bool _presenceApiMissing = false;
  Timer? _storagePolicy;
  late final ChatApi _api = ChatApi(_cv);
  late final FeedApi _feedApi = FeedApi(_cv);
  late final CallApi _callApi = CallApi(_cv);
  late final ChatRepository _repo = ChatRepository(api: _api, cv: _cv);
  late final AuthService _auth = AuthService(_api);
  late final FamilyService _family = FamilyService.ensure(_api);
  /// Whether a call screen is the top route — see [_CallOverlay.screenUp].
  final ValueNotifier<bool> _callScreenUp = ValueNotifier<bool>(false);

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
    // Same argument, same slot: the companion download strip is a layout
    // participant, and `removeTop` below is computed from whether it is
    // showing. The strip listens for itself and would redraw regardless; what
    // needs this is the padding decision around it.
    BrainManager.instance,
  ]);

  /// Created once so the observer list handed to MaterialApp is stable across
  /// the AnimatedBuilder rebuilds — a fresh observer each build would detach
  /// and reattach on every theme change and lose the route stack.
  final DiagRouteTracker _diagRoutes = DiagRouteTracker();
  final RouteDepthObserver _routeDepth = RouteDepthObserver();

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

  /// The game a push named alongside [_pendingPushRoomId] (`focus: game:<id>`),
  /// opened over the room once the room is.
  String? _pendingPushMatchId;

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

  /// True while the chat picker for an incoming share is on screen.
  ///
  /// The share sheet can deliver the same payload twice on iOS — the URL that
  /// wakes us also arrives as a scene-activation option — and a second picker
  /// stacked on the first is both wrong and un-dismissable. The payload itself
  /// waits in [ShareIntake] rather than in a field here, because it has to
  /// survive the picker AND the route push into the room, neither of which
  /// this State is guaranteed to outlive across a server switch.
  bool _shareInFlight = false;

  /// Publishes the chat list to the OS as share-sheet suggestions. Created on
  /// the first sign-in and disposed with this State.
  ShareTargetsSync? _shareTargetsSync;

  // Last presence status successfully handed to the server, so a lifecycle
  // sequence that resolves to the same value twice doesn't write twice. Null
  // means "unknown" — on sign-out, or after a failed write — and always sends.
  String? _lastSentStatus;

  // The status the server last ACKNOWLEDGED, as opposed to the one merely
  // handed over above. Null while a write is in flight or after a failure.
  // [_holdAwayInBackground] reads it to skip a backgrounding whose `away`
  // already landed.
  String? _ackedStatus;

  /// Every presence write goes through here, so [_lastSentStatus] and
  /// [_ackedStatus] stay honest. Rethrows, so a caller can retry.
  Future<void> _sendStatus(String userId, String status) async {
    _lastSentStatus = status;
    _ackedStatus = null;
    try {
      await _writeStatus(userId, status);
      if (_lastSentStatus == status) _ackedStatus = status;
    } catch (_) {
      // Unknown server state now, so don't let the dedupe guard in
      // didChangeAppLifecycleState suppress the next attempt at the same value.
      _lastSentStatus = null;
      rethrow;
    }
  }

  void _syncLiveCallRooms() => LiveCallsStore.instance.syncRooms(_repo.roomIds);

  /// `presenceApi:setStatus` first; the old `users:updateStatus` only when the
  /// server has no such function.
  Future<void> _writeStatus(String userId, String status) async {
    if (!_presenceApiMissing) {
      try {
        await _presenceApi.setStatus(status: status);
        return;
      } catch (e) {
        if (!PresenceApi.isMissing(e)) rethrow;
        _presenceApiMissing = true;
      }
    }
    await _api.updateStatus(userId: userId, status: status);
  }

  /// `presenceApi:beat` first, carrying what the app is doing right now; the
  /// old `users:heartbeat` only when the server has no such function.
  Future<void> _writeBeat(String userId) async {
    if (!_presenceApiMissing) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      // Inactive (and web's hidden) map to null: keep whatever was last said.
      final status =
          (lifecycle == null ? null : presenceStatusFor(lifecycle)) ??
          (_lastSentStatus == 'away' ? 'away' : 'online');
      try {
        await _presenceApi.beat(status: status);
        return;
      } catch (e) {
        if (!PresenceApi.isMissing(e)) rethrow;
        _presenceApiMissing = true;
      }
    }
    await _api.heartbeat(userId: userId);
  }

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

  /// iOS asks here, from `applicationWillTerminate`, before the process goes.
  static const _presenceChannel = MethodChannel('monkeyhub/presence');

  /// The app was swiped away in the app switcher. It sat there `inactive`,
  /// which says nothing about presence ([presenceStatusFor]), and iOS
  /// terminates it straight from there: no `paused`, so no `away`, and the
  /// stored `online` from the session held until the staleness sweep caught
  /// up, minutes later. The person read as online with the app closed.
  /// AppDelegate waits (briefly) for this to answer, so the write gets out
  /// while the socket is still up. `away` rather than `offline`, the same as
  /// a backgrounding: presence is per user, and another of their devices may
  /// still be open.
  Future<void> _awayOnTerminate() async {
    final session = _auth.session;
    if (session == null || _lastSentStatus == 'away') return;
    try {
      await _sendStatus(
        session.userId,
        'away',
      ).timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
  }

  /// iOS backgrounded the app and is holding it awake until this returns
  /// (AppDelegate's `_holdPresenceAway`). The `away` from
  /// [didChangeAppLifecycleState] may already be in flight, or not sent yet
  /// (the notification can beat the lifecycle event); either way, nothing is
  /// done until the server has acknowledged `away`. A lock used to suspend
  /// the app with that write still queued, and the person read as online with
  /// the phone locked until the staleness sweep caught up, minutes later.
  Future<void> _holdAwayInBackground() async {
    final session = _auth.session;
    if (session == null || _ackedStatus == 'away') return;
    final ok = await deliverPresenceWithin(
      () => _sendStatus(session.userId, 'away'),
      // Inside AppDelegate's 8s cap, with an attempt's timeout to spare.
      budget: const Duration(seconds: 5),
      // Back in the foreground: `resumed` writes `online` on its own, and an
      // `away` retried after it would undo that.
      stillWanted: () =>
          _auth.session?.userId == session.userId &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed,
    );
    DiagLog.lifecycle('background hold → away ${ok ? 'acked' : 'not acked'}');
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
    _writeBeat(userId)
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
    _presenceApiMissing = false;
    // Next session starts with no assumption about the stored status.
    _lastSentStatus = null;
    _ackedStatus = null;
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
    // A call signals over this socket and the OS keeps us running for it, so
    // recovery must not park behind a locked screen mid-call.
    healInBackground: () => _callService.inCall || _groupCallService.inCall,
    // Desynchronise a fleet that lost the (single, small) server at once.
    backoffJitter: 0.2,
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
    unawaited(LowPowerMode.instance.refresh());
    _presenceChannel.setMethodCallHandler((call) async {
      if (call.method == 'willTerminate') await _awayOnTerminate();
      if (call.method == 'didEnterBackground') await _holdAwayInBackground();
      return true;
    });
    _auth.addListener(_onAuthChange);
    // Every appearance change lands in SettingsStore — the settings screen,
    // the first-launch picker, a keychain that became readable late — and this
    // is the one place that turns it into the theme on screen.
    SettingsStore.instance.addListener(_syncTheme);
    _family.addListener(_syncAccountType);
    PushManager.instance.setOnOpenRoom(_openRoomFromPush);
    PushManager.instance.setOnOpenRequests(_openRequestsFromPush);
    PushManager.instance.setOnOpenGames(_openGamesFromPush);
    PushManager.instance.setOnOpenMoment(_openMomentFromPush);
    // Midnight passed with the app open. Daylight saving moves at 3am, when
    // nobody resumes anything, so without this a phone left on a nightstand
    // would keep reporting yesterday's offset until it was next picked up —
    // and be nudged an hour off in the meantime.
    FeedStore.instance.onDayRollover =
        () => unawaited(PushManager.instance.syncDeviceContext());
    PushManager.instance.attachApi(_api);
    PushManager.instance.setActiveRoomIdProvider(() => _repo.activeRoomId);
    // What kind of chat a room is, for every Data and Storage rule: auto-
    // download, save to Photos and auto-remove are all written per kind.
    // Saved Messages is where people keep things on purpose, so auto-remove
    // never touches it.
    MediaLedger.instance
      ..roomClassifier = (roomId) {
        final room = _repo.roomById(roomId);
        if (room == null) return null;
        if (room.isDm) return ChatClass.privateChats;
        return room.isPublic ? ChatClass.publicRooms : ChatClass.groups;
      }
      // Parenthesised: an arrow body would swallow the next cascade step.
      ..isKeptRoom =
          ((roomId) => _repo.roomById(roomId)?.isSavedMessages ?? false)
      ..selfId = (() => _repo.userId)
      ..loadedMessages = (() sync* {
        for (final room in _repo.rooms) {
          yield* _repo.messagesFor(room.id);
        }
      });
    // Auto-remove and the cache ceiling, once the launch has settled. Rate-
    // limited inside, so the resume hook below can call it freely.
    // A Timer, not a Future.delayed, so dispose can call it off.
    _storagePolicy = Timer(const Duration(seconds: 20),
        () => StorageService.instance.enforcePolicy());
    // Web message-banner clicks open the room, same as a push tap.
    MessageAlerts.instance.setOnOpenRoom(_openRoomFromPush);
    // Web Push banner clicks (background/closed tab) open the room too — the
    // service worker posts the roomId to whichever tab it focuses.
    WebPush.setOnOpenRoom(_openRoomFromPush);
    // …and friend activity, which has no room to open: a highlight or point
    // goes to its own card, a shared game result to the games shelf.
    WebPush.setOnOpenTarget(
      onMoment: _openMomentFromPush,
      onGames: _openGamesFromPush,
    );
    // Web: the address bar follows the open chat and section, Back/Forward
    // walk them, and a reload or pasted `#/c/<id>` reopens the chat through
    // the same door a notification tap uses. No-op off web.
    if (kIsWeb) {
      WebUrlSync.instance.attach(
        navigatorKey: rootNavigatorKey,
        repo: _repo,
        auth: _auth,
        signedIn: () => _auth.session != null,
        openRoom: _openRoomFromPush,
        savedMessagesTitle: () => _loc()?.savedMessagesTitle,
      );
    }
    // Inbound universal links / App Links. Reported here rather than acted on:
    // `_openInvite` decides whether the app is ready and stashes if not.
    // A revoked or unknown token means this device is no longer signed in —
    // someone hit "remove all other devices", or the account is gone. Wired
    // here, above the navigator, because the shell has to be torn down from
    // outside whatever screen happened to be showing when it happened.
    SessionGuard.instance.onSessionLost = () {
      unawaited(_auth.forceSignOut());
    };
    DeepLinkService.instance.onInvite = _openInvite;
    // The desktop/web sign-in QR, scanned with the phone's own Camera app.
    DeepLinkService.instance.onDeviceLogin = _openDeviceLogin;
    unawaited(DeepLinkService.instance.start());
    // The system share sheet. Same arrangement as the invite above — reported
    // here, placed by `_openShare`, which stashes when the app isn't ready.
    // `start` also drains whatever the platform queued before Dart existed,
    // which on this path is the common case rather than the edge one: the
    // share sheet is very often what launched the process.
    ShareIntake.instance.onShare = _openShare;
    unawaited(ShareIntake.instance.start());
    // Desktop drag-and-drop. macOS and web only; a no-op everywhere else, and
    // the native half registers nothing until this call reaches it — see
    // `DropChannel`. Started here rather than from a widget so a file dragged
    // onto the window during the splash finds a listener rather than a window
    // that shows the copy cursor and swallows it.
    unawaited(DropController.instance.start());
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
        // Not pinned — this is the app being sent, not a person choosing. See
        // [ServerStore.isPinned]; the same distinction [ServerSwitch.follow]
        // makes on the live path.
        await ServerStore.instance.use(target, pinned: false);
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
    showAppToast(
      ctx,
      AppLocalizations.of(ctx).serverDirectiveChangedToast,
      duration: const Duration(seconds: 4),
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

  /// A tapped daily-games nudge or shared result: the Feed, scrolled to its
  /// Games band (see `FeedScreen._consumePendingGames`). Same three moves as the requests tap above, and for the same reasons —
  /// the section is steered without persisting (a notification is not a
  /// preference), and whatever was pushed over the shell is popped first so the
  /// tab the user is being sent to is actually the thing they see.
  void _openGamesFromPush() {
    UiSelectionStore.instance.requestGamesView();
    SettingsStore.instance.setSection(HomeSection.feed, persist: false);
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
  }

  /// A tapped friend-activity notification: the Feed, with that moment's
  /// viewer open over it.
  ///
  /// The same three moves as the two taps above — and, like them, nothing is
  /// stashed for a cold start. [UiSelectionStore] holds the id until
  /// [FeedScreen] mounts and consumes it, which covers launch-from-notification
  /// for free; that is exactly why the id lives there rather than in a field
  /// here the way `_pendingPushRoomId` does. (A room has to be stashed locally
  /// because its destination is a `Navigator.push` this widget performs; the
  /// Feed's viewer is opened by the Feed, inside its own nested navigator.)
  ///
  /// [comments] is a comment or reply push: the card opens with its
  /// conversation already up, because the comment is what the banner said.
  void _openMomentFromPush(String momentId, {bool comments = false}) {
    UiSelectionStore.instance.requestMoment(momentId, comments: comments);
    SettingsStore.instance.setSection(HomeSection.feed, persist: false);
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
  }

  /// [focus] is the optional "and then show this" hint a push can carry —
  /// `data.focus`, forwarded by both native handlers beside the roomId. Only
  /// `"roomChanges"` exists today: a member suggested a new group name,
  /// description or picture, and the admin tapping the banner should land on
  /// approve/reject rather than in the transcript with no sign of why.
  ///
  /// Recorded in [UiSelectionStore] rather than acted on here, for the reason
  /// the games and moment taps are: the destination is opened by the ROOM
  /// screen, which exists on both window classes and knows its own navigator,
  /// where this method has two different ways of getting a room on screen and
  /// neither of them can push a second route onto the right one.
  ///
  /// An unrecognised value is ignored rather than guessed at, so a newer
  /// server's hint degrades to "opens the room" — which is still correct.
  void _openRoomFromPush(String roomId, {String? focus}) {
    if (focus == 'roomChanges') {
      UiSelectionStore.instance.requestRoomChangeReview(roomId);
    }
    // A reaction push: "message:<id>" names the bubble that was reacted to,
    // and the room jumps to it once it is open.
    if (focus != null && focus.startsWith('message:')) {
      final messageId = focus.substring('message:'.length);
      if (messageId.isNotEmpty) {
        UiSelectionStore.instance.requestMessageFocus(roomId, messageId);
      }
    }
    // On a cold start from a notification tap, the platform's tap event can
    // fire before _bootstrap finishes restoring auth and before the root
    // navigator's state is mounted. Stash the roomId and let
    // [_consumePendingPushRoom] flush it once both are ready. The focus
    // request above survives that wait on its own — it is one-shot state on
    // the store, consumed by whichever RoomScreen eventually mounts.
    // A game push ("your move", a nudge): the room, then the game over it.
    final matchId = focus != null && focus.startsWith('game:')
        ? focus.substring('game:'.length)
        : null;
    if (_auth.session == null || rootNavigatorKey.currentState == null) {
      _pendingPushRoomId = roomId;
      _pendingPushMatchId = matchId;
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
    final me = _repo.userId;
    void openGame() {
      if (matchId == null || matchId.isEmpty || me == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => MatchScreen(matchId: matchId, userId: me),
        ),
      );
    }

    if (gLastSplitShell) {
      // Desktop: fill the chat detail pane instead of pushing a full screen.
      SettingsStore.instance.setSection(HomeSection.chat);
      openGame();
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(roomId: roomId, repo: _repo, api: _api),
      ),
    );
    openGame();
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

    // The user followed an "open in app" button from a page we put in front of
    // them. Honour it: the browser surface is a platform view the navigator
    // cannot pop, so it otherwise stays up and the join screen opens behind a
    // browser they have to dismiss by hand. Before the readiness check below,
    // because a link that arrives too early still came from that same tap.
    unawaited(LinkOpener.dismiss());

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

  /// Approve (or refuse) a sign-in on another device, from its QR.
  ///
  /// Deliberately NOT stashed when the app isn't ready, which is the one place
  /// this differs from [_openInvite]. An invite keeps its meaning indefinitely;
  /// a device-login request is a short-lived secret that a signed-out phone
  /// cannot act on at all, and replaying one after a later sign-in would open a
  /// confirmation for a request that expired long ago. Dropping it costs the
  /// user one rescan and keeps the flow honest about what it is approving.
  void _openDeviceLogin(String requestId) {
    final session = _auth.session;
    if (session == null || rootNavigatorKey.currentState == null) {
      debugPrint('device login link dropped: no session to approve with');
      return;
    }
    // A supervised device has no business handing out full account sessions —
    // the same rule `profile_screen.dart` applies to the entry point it owns.
    if (_auth.isChild) return;
    // Same reasoning as `_openInvite`: a QR can be scanned from a page open in
    // the tab, and the confirmation must not appear behind it.
    unawaited(LinkOpener.dismiss());
    final nav = rootNavigatorKey.currentState!;
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute(
        builder: (_) => DeviceLoginScanScreen(
          auth: _auth,
          initialRequestId: requestId,
        ),
      ),
    );
  }

  // ─────────────────────────── the system share sheet ──────────────────────
  //
  // Two doors, and they are deliberately different lengths:
  //
  //   * A **suggestion** in the sheet's top row already named a chat, so the
  //     share goes straight there. That is the whole point of donating them.
  //   * The **app icon** names nothing, so the picker asks — and only then.
  //
  // Neither door sends anything by itself. The payload is staged in
  // [ShareIntake] and the room's own screen delivers it, which is what keeps
  // the composer, the editor, the room's capabilities and the size cap in one
  // place instead of two.

  /// A share arrived from the OS.
  void _openShare(SharedPayload payload) {
    // Held back in the same two states an invite is, for the same two reasons:
    // a cold start has no navigator for one frame, and a signed-out install has
    // to get through login first. `flushPending` replays from both places.
    if (_auth.session == null || rootNavigatorKey.currentState == null) {
      ShareIntake.instance.hold(payload);
      return;
    }
    // A second share while the picker is still up. Held rather than dropped —
    // the platform has already copied somebody's photo onto their disk, and
    // silently forgetting it leaves the file behind AND loses the share. The
    // picker's `finally` flushes it.
    if (_shareInFlight) {
      ShareIntake.instance.hold(payload);
      return;
    }

    final target = payload.targetRoomId;
    if (target != null && _repo.roomById(target) != null) {
      _deliverShare(target, payload);
      return;
    }
    // A suggestion whose room has since been left or deleted falls through to
    // the picker rather than failing — the OS caches shortcuts for days and
    // will happily offer one for a chat that is gone.
    unawaited(_askShareTarget(payload));
  }

  Future<void> _askShareTarget(SharedPayload payload) async {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    _shareInFlight = true;
    try {
      // Land on the shell first. A share tapped while a room or a settings
      // sub-screen was open would otherwise ask its question from under
      // whatever was there, and answering it would push a room onto a stack
      // nobody expects to come back to.
      nav.popUntil((r) => r.isFirst);
      final ctx = nav.context;
      final choice = await showShareTargetSheet(
        ctx,
        repo: _repo,
        api: _api,
        payload: payload,
      );
      if (choice == null) {
        // Dismissed. The staged copies are ours and nothing else will collect
        // them — see `ShareIntake.disposeItems`.
        ShareIntake.instance.disposeItems(payload.items);
        return;
      }
      final String roomId;
      switch (choice) {
        case ShareToRoom(:final room):
          roomId = room.id;
        case ShareToFriend(:final friend):
          // No DM yet. Opening one is a mutation, so it runs here rather than
          // under the sheet — and a failure leaves the user on the chat list
          // with their share intact rather than in a room that doesn't exist.
          try {
            roomId = await _repo.openDmWith(friend);
          } catch (e) {
            debugPrint('share: could not open DM with ${friend.id}: $e');
            ShareIntake.instance.disposeItems(payload.items);
            return;
          }
      }
      if (!mounted) return;
      _deliverShare(roomId, payload);
    } finally {
      _shareInFlight = false;
      // Whatever arrived while this one was on screen, in order.
      ShareIntake.instance.flushPending();
    }
  }

  /// Stages [payload] for [roomId] and puts that room on screen.
  ///
  /// Routing is [_openRoomFromPush]'s, unchanged: it already knows that a
  /// desktop pane wants a selection and a phone wants a push, and that both
  /// want the nested routes popped first.
  void _deliverShare(String roomId, SharedPayload payload) {
    ShareIntake.instance.stageFor(roomId, payload.withTarget(roomId));
    _openRoomFromPush(roomId);
  }

  /// The app's strings, from outside the widget tree.
  ///
  /// [ShareTargetsSync] publishes titles the OS renders in its own share
  /// sheet, and those have to be in the user's language — but it runs off a
  /// repository listener, not a build, so there is no `BuildContext` in hand.
  /// `Localizations.of` is the nullable form on purpose: this is called during
  /// sign-in, which can complete before the first frame, and an assert there
  /// would crash the launch over a shortcut label. A null answer publishes an
  /// empty title for the two fallbacks, which the row then renders from the
  /// room's own name.
  AppLocalizations? _loc() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return null;
    return Localizations.of<AppLocalizations>(ctx, AppLocalizations);
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
    // Web history steps (`/c/<id>`, `/feed`…) first: the invite parser would
    // read a bare `/feed` as the code FEED. `/j/…` and real URLs fall through.
    if (kIsWeb &&
        WebUrlSync.instance.handleBrowserNavigation(routeInformation.uri)) {
      return true;
    }
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
      final match = _pendingPushMatchId;
      _pendingPushMatchId = null;
      _openRoomFromPush(pending, focus: match == null ? null : 'game:$match');
    });
  }

  /// Re-seeds what launch copied out of [SettingsStore] once the stored
  /// preferences are actually readable. Free on every resume but the one after
  /// a locked launch — see [SettingsStore.retryIfUnread].
  Future<void> _retrySettings() async {
    // The theme re-resolves through [_syncTheme], which the retry's own
    // notification already reaches; nothing else is copied out at launch.
    await SettingsStore.instance.retryIfUnread();
  }

  /// Puts the theme the preferences call for on screen, if it is not already.
  ///
  /// Cheap on the notifications that change nothing — nearly all of them,
  /// since SettingsStore notifies for every preference: one id comparison, and
  /// the theme is only looked up when it actually moves.
  void _syncTheme() {
    final id = SettingsStore.instance.themeIdFor(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    if (id == _themeController.theme.id) return;
    _themeController.theme = ThemeController.byId(id);
  }

  /// The device switched between light and dark — at dusk on a schedule, from
  /// Control Centre, or with the ambient light. Under
  /// [AppearanceMode.system] the app goes with it, live, without a relaunch.
  @override
  void didChangePlatformBrightness() => _syncTheme();

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
      // And the last moment the app icon's number is ours. Every push carries
      // an absolute `ios_badgeCount` that APNs applies while we are away, so
      // from here on "the total hasn't changed" no longer implies "the icon
      // already shows it" — see [BadgeManager.invalidatePlatformBadge].
      BadgeManager.instance.invalidatePlatformBadge();
    }
    // A launch on a locked phone can leave the preferences unread; the first
    // resume is the first moment the keychain will certainly answer. Above the
    // session check, because the login screen wears the theme too.
    if (state == AppLifecycleState.resumed) unawaited(_retrySettings());
    // Low Power Mode is toggled where the app is backgrounded (Control Centre).
    if (state == AppLifecycleState.resumed) unawaited(LowPowerMode.instance.refresh());
    if (state == AppLifecycleState.resumed) {
      unawaited(StorageService.instance.enforcePolicy());
    } else {
      // The ledger and the usage counters write behind a debounce; a
      // backgrounding is the last safe moment to land them.
      unawaited(MediaLedger.instance.flush());
      unawaited(DataUsageStore.instance.flush());
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
    //
    // Desktop is switched off for the same reason, and now has to be. Closing
    // the window on macOS no longer quits the app — it hides it
    // (macos/Runner/MainFlutterWindow.swift), because macOS has no push and
    // this process IS the delivery path. Flutter reports that as `hidden`, so
    // the old mapping parked the recovery loop for exactly the hours the app is
    // most on its own: a socket that wedges while the window is away would then
    // sit unrepaired until the person came back and looked — which is the
    // silent-missed-messages failure this whole change exists to remove. The
    // premise doesn't hold here anyway: a hidden Mac window is not a suspended
    // process, its timers keep running and its socket stays open.
    //
    // Machine sleep is still covered. `setForeground(true)` with no transition
    // falls through to the tick-gap check, which measures a freeze from our own
    // timer rather than from anything the OS says — see [setForeground].
    _health.setForeground(
      isWebOrDesktop ||
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
      // Fire-and-forget — network may be unavailable; status reconciles next
      // foreground. On iOS a backgrounding's `away` is also seen through by
      // [_holdAwayInBackground], which retries until it is acknowledged.
      unawaited(_sendStatus(session.userId, next).catchError((_) {}));
    }
    if (state == AppLifecycleState.resumed) {
      // Immediately, and deliberately NOT behind the 500 ms stagger below: a
      // message that arrived while we were away is already on the device, in
      // the notification handler's inbox, and this is a disk read with no
      // network in it. Coming back to a room that is already open should show
      // it now rather than after the socket has finished waking up.
      unawaited(_repo.takePushedMessages());

      // Same immediacy, same reason: the open room's messages are already on
      // screen, so coming back to the app IS reading them. This takes the read
      // cursor that was held back while nobody was looking — see
      // [ChatRepository.flushDeferredRead] — which is also what drops the app
      // icon's badge on the way in.
      _repo.flushDeferredRead();

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
        // A resume is when travel and daylight saving become visible to us —
        // the phone comes off airplane mode in a new zone and this is the first
        // code that runs. No-ops when nothing moved. See [syncDeviceContext].
        unawaited(PushManager.instance.syncDeviceContext());
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
    // Capture protection has no preference: it is on exactly while an
    // ephemeral room (or a view-once photo) is on screen. Boot only primes
    // the iOS capture-state stream.
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

    // Confirm with the server who this token actually belongs to, and repair
    // the keychain if it disagrees. UNAWAITED on purpose: the restored session
    // is good enough to render with, this only corrects the NAME on it, and
    // blocking the first frame on a round trip would trade a rare wrong label
    // for a launch stall everyone feels. The screen updates when it lands.
    unawaited(_auth.reconcile());

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
    // Same replay for a share the platform handed over during boot.
    ShareIntake.instance.flushPending();
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
      // The video call's Picture in Picture window, which is also what lets
      // iOS keep our camera running once the app leaves the screen.
      CallPip.instance.attach(call: _callService, group: _groupCallService);
      // The same picture, floating over the app while the call screen is
      // minimized; "Return" is the in-call bar's.
      CallFloat.instance.attach(
        screenUp: _callScreenUp,
        reopen: () {
          if (_callService.inCall) {
            _callService.reopenTick.value++;
          } else {
            _groupCallService.reopenTick.value++;
          }
        },
      );
      // Android: the ongoing-call notification's Mute action and its
      // foreground service's camera type follow the 1:1 call.
      CallNotificationSync.instance.attach(_callService);
      // Asked now, so a call screen knows whether it has a share button
      // on its first frame (see ScreenShare.likelySupported).
      unawaited(ScreenShare.supported());
      // The audio-session deactivation belt must know about group calls —
      // they raise no CallKit card, so the native no-op-while-a-card-is-
      // alive guard can't see them. Without this, canceling a 1:1 ring
      // DURING a group call would cut the group call's live audio.
      NativeCallHandler.groupCallActiveProbe = () => _groupCallService.inCall;
      // And the mirror, for the group path's mic belt (same shared module).
      NativeCallHandler.dmCallActiveProbe = () => _callService.inCall;
      // A call of ours stops a daily game's clock, as any phone call does.
      PhoneCallActivity.instance.attachAppCalls(
        [_callService, _groupCallService],
        () => _callService.inCall || _groupCallService.inCall,
      );
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
      // Somebody with a session has, by definition, been past the login
      // screen the first-launch appearance picker sits in front of — an
      // install from before it existed must not be shown it after a sign-out.
      if (s != null) unawaited(SettingsStore.instance.markThemeOnboarded());
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
        //   1. `PushManager.login` awaits token registration AND the
        //      notification-permission prompt. On a cold start woken by a
        //      VoIP push, that can hang indefinitely — and everything after
        //      it, including the entire call stack, never runs. (It awaited
        //      the push VENDOR's login when this was written; the vendor is
        //      gone and the hazard is not.)
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
        // In-chat games: faces from the repository's caches, and the
        // "your move" set for the chat list.
        MatchesStore.instance.resolveUser = (roomId, userId) {
          for (final u in _repo.membersFor(roomId)) {
            if (u.id == userId) return u;
          }
          return _repo.userById(userId);
        };
        unawaited(MatchesStore.instance.attach(s.userId));
        // The chat list's "call going on here" rows.
        unawaited(LiveCallsStore.instance.attach(_groupCallApi, s.userId));
        // Which rooms to look in: the chat list's, re-announced only when the
        // set changes.
        _repo.removeListener(_syncLiveCallRooms);
        _repo.addListener(_syncLiveCallRooms);
        _syncLiveCallRooms();
        ChallengesStore.instance.repo = _repo;
        unawaited(FeedStore.instance.attach(_feedApi, s.userId));
        // Sticker packs, recents/favourites and the KLIPY config, ready before
        // anyone opens the composer's expression panel.
        unawaited(ExpressionStore.instance.attach(_api, s.userId));
        // Deliberately NOT awaited — see the note above. Push registration is
        // a best-effort background concern; nothing in this method may block
        // on it. The opt-out still has to follow the login that would
        // otherwise re-enable notifications, so the two stay chained to each
        // other rather than to us.
        unawaited(() async {
          try {
            await PushManager.instance.login(s.userId);
            // Only once the switches below are the user's, not the defaults
            // standing in for them while a locked launch keeps the keychain
            // shut. Every default is "on", so reading them here would skip the
            // opt-outs and leave a freshly created device row notifying about
            // exactly what the user had switched off.
            await SettingsStore.instance.ready;
            // [PushManager.login] registers this device for push
            // unconditionally, so an account that turned notifications OFF
            // has to be opted back out straight afterwards or a cold start
            // silently re-enables them.
            if (!SettingsStore.instance.pushEnabled) {
              await PushManager.instance.optOut();
            }
            // Same story for the daily games reminder, one field down on the
            // same row: a device row is created fresh on every login and starts
            // with the field absent, which the sender reads as "enabled". A
            // person who switched the nudge off and then signed in again would
            // otherwise start getting it back.
            if (!SettingsStore.instance.gameReminders) {
              await PushManager.instance.setGameReminders(false);
            }
            // And once more for friend activity, one field further along the
            // same row and lost on login for the same reason.
            if (!SettingsStore.instance.friendActivity) {
              await PushManager.instance.setFriendActivity(false);
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
        unawaited(_sendStatus(s.userId, attachStatus).catchError((_) {}));
        // The family service is bound too: a guardian's pending approvals are
        // part of the app-icon number the backend now stamps into every push,
        // and a client that re-asserted without them would wipe it on resume.
        BadgeManager.instance.bind(_repo, family: _family);
        MessageAlerts.instance.bind(_repo);
        _consumePendingPushRoom();
        // The sign-in that a tapped invite sent someone through. This is the
        // flush that matters most: on a fresh install the link arrives long
        // before there is an account to join with.
        _consumePendingInvite();
        // And the share that sent someone through it. A share sheet can raise
        // a signed-out install exactly like an invite link can.
        ShareIntake.instance.flushPending();
        // Suggestions describe THIS account's chats, so they are published on
        // sign-in and dropped on sign-out — never carried between accounts on
        // a shared handset.
        _shareTargetsSync ??= ShareTargetsSync(
          repo: _repo,
          theme: () => _themeController.theme,
          savedMessagesTitle: () => _loc()?.savedMessagesTitle ?? '',
          directMessageFallbackTitle: () =>
              _loc()?.approvalsScreenForwardDirectMessageFallback ?? '',
          // Sent as `senderName` on a message composed inside the iOS Share
          // Extension, so a push from one reads like every other one rather
          // than arriving from nobody.
          senderName: () => _auth.session?.name,
        );
        _shareTargetsSync!.publishNow();
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
        // Recents, favourites and a personal sticker pack are this account's,
        // and the two subscriptions behind them must not outlive its session.
        await ExpressionStore.instance.detach();
        // Same rule for the daily games: the standings carry friends' names.
        GamesStore.instance.clear();
        RecordsStore.instance.clear();
        // Chat games name people too.
        MatchesStore.instance.detach();
        _repo.removeListener(_syncLiveCallRooms);
        LiveCallsStore.instance.detach();
        ChallengesStore.instance.clear();
        // And for the share-sheet suggestions, which name people and live
        // OUTSIDE the app — in the system's shortcut store and in Siri's
        // donation history. Left behind, the next account on this handset
        // would be offered the previous one's chats by the OS itself.
        _shareTargetsSync?.dispose();
        _shareTargetsSync = null;
        unawaited(ShareTargets.instance.clear());
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
        await DocumentFileCache.instance.clear();
        await MediaImageCache.clear();
        // The index of what was cached, and for which chats. Data usage is
        // the device's, not the account's, and stays.
        await MediaLedger.instance.clear();
        // End the calls BEFORE stopping the signaling subscription: endCall
        // still wants its terminal mutation on the wire, and stop() first
        // used to leave a window where a peer's bye/cancel arrived with
        // nobody listening.
        await _callService.endCall();
        await _groupCallService.leaveCall();
        await _signaling.stop();
        _callService.detachWatch();
        // AFTER leaveCall, which still wants the roster and its leave mutation.
        // This is the account-level half — the two subscriptions that used to
        // outlive the session and, at the next sign-in, undo it. See
        // `GroupCallService.detach`.
        _groupCallService.detach();
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
    _storagePolicy?.cancel();
    ServerDirectory.instance.unwatch();
    _stopPresenceHeartbeat();
    _repo.removeListener(_syncLiveCallRooms);
    _resumeSyncTimer?.cancel();
    _health.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuthChange);
    SettingsStore.instance.removeListener(_syncTheme);
    _family.removeListener(_syncAccountType);
    _shareTargetsSync?.dispose();
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
          final isLight = theme.isLight;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            // Thin auto-hiding scrollbars on desktop; phones untouched.
            scrollBehavior: const DesktopScrollBehavior(),
            // Root navigator only. Screen attribution turns a flat list of
            // function names into something you can reason about, and the
            // push/pop events are their own signal — a route that opens and
            // closes repeatedly is a bug shape worth seeing next to the layout
            // events it interleaves with.
            navigatorObservers: [
              _diagRoutes,
              appRoutes,
              _routeDepth,
              if (kIsWeb) WebUrlSync.instance.routes,
            ],
            // On web the live tab title — `(3) MonkeyHub`, a chat's name — so
            // the `Title` widget's rewrite of document.title on every app
            // rebuild repeats it instead of resetting it.
            title: kIsWeb ? WebTabTitle.instance.current : 'MonkeyHub',
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
              // Low Power Mode / Battery Saver calms the motion app-wide.
              final Widget? calmed = child == null
                  ? null
                  : LowPowerCalm(child: child);
              child = calmed == null
                  ? null
                  : ProfileScope(cache: ProfileCache.instance, child: calmed);
              // The language the app SETTLED on, which is not knowable from
              // either of the two things that produce it: `locale:` above is
              // null whenever the user has not overridden anything, and the
              // device locale may not be supported at all. This builder sits
              // below WidgetsApp's Localizations, so it is the first place the
              // resolved answer exists — recorded for the diagnostics header
              // and the problem report, both of which are context-free.
              // Idempotent, and rerun on every language change.
              final resolvedLocale = Localizations.localeOf(
                context,
              ).toLanguageTag();
              DeviceReport.appLocaleTag = resolvedLocale;
              // The same answer, for a different consumer: the backend composes
              // the daily games nudge and has to know which language to write
              // it in. Reported from here because this builder reruns on every
              // language change from EITHER source — the in-app override and a
              // system language changed in the OS settings — and because the
              // resolved value is the only correct one: an override is null for
              // most people, and a device language may be one this app does not
              // ship. No-ops unless it actually moved.
              PushManager.instance.noteAppLocale(resolvedLocale);
              // The Linux tray menu is native and built before any of this
              // exists; same trigger, so it follows a language change too.
              final l10n = AppLocalizations.of(context);
              LinuxNotifier.instance.setTrayLabels(
                open: l10n.linuxTrayOpen,
                quit: l10n.linuxTrayQuit,
              );

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
              // Gated on boot for the same reason the server strip used to
              // be: nothing has asked the disk what is installed yet, so there
              // is nothing truthful to report and no height to take.
              final companionBar = _bootstrapped &&
                  _bootError == null &&
                  CompanionDownloadBanner.isShowing;
              // Only the companion bar can sit behind the status glyphs now.
              // The server mark became a corner ribbon that takes no height and
              // covers nothing — see [ServerMarkBanner] — so it no longer has
              // any say in what the glyphs are drawn against.
              final darkStatusSurface = !isLight || companionBar;
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
                // Above the navigator so every route inherits it, and inside
                // `builder` so it outranks WidgetsApp's own Tab binding — which
                // on macOS leaks the key to AppKit and types a tab character
                // into the field focus just landed on. See the widget's doc.
                // Every keyboard shortcut is heard here, after the screen has had
                // its chance at the key. See the widget's doc.
                child: ShortcutHost(
                  navigatorKey: rootNavigatorKey,
                  repo: _repo,
                  onOpenRoom: (id) => _openRoomFromPush(id),
                  child: DesktopTabTraversal(
                    // Esc goes back from any pushed route. Same placement rule as
                    // the Tab fix: above the navigator, inside `builder`.
                    child: EscapeToPop(
                      navigatorKey: rootNavigatorKey,
                      child: Listener(
                        // Observe (never consume) the first pointer-down to unlock
                        // audio + request notification permission within a user gesture.
                        onPointerDown: _alertsPrimed ? null : (_) => _primeAlerts(),
                        // Row and chrome-button density, read by the widget kit.
                        child: DensityScope(child: _WindowClassProvider(
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
                              // Painted over the whole app — the shell, every
                              // pushed route, and the full-screen media viewers
                              // that are the reason this is a ribbon and not a
                              // bar — and painted as a FOREGROUND layer, so it
                              // takes no height from any of them and is not
                              // hit-testable. Taps fall straight through to
                              // whatever is under it, which is what makes it safe
                              // to land in the one corner a full-screen route is
                              // likely to have put a control in.
                              //
                              // Inside this Stack rather than around it, so the
                              // CaptureShield below still covers it.
                              ServerMarkBanner(
                                child: Column(
                                children: [
                                  // The self-host BAR used to sit here and take
                                  // its own height, which is what put every screen
                                  // in the app 26pt plus a status inset below the
                                  // top of the display. That was invisible on a
                                  // chat list and wrong on every screen whose
                                  // design is that the content is the screen — it
                                  // is what pillarboxed a screenshot in the photo
                                  // send-preview. It is a corner ribbon now, drawn
                                  // over the whole app at the bottom of this
                                  // method, taking no height from anything.
                                  //
                                  // The companion bar stays a bar: it reports a
                                  // download that runs for minutes, and chrome
                                  // that sits on top of a room header for twenty
                                  // minutes is not chrome. Its neighbours below
                                  // stay floating — a connection blip is
                                  // transient, and shoving the whole app down and
                                  // back for one would be worse than briefly
                                  // overlapping something.
                                  if (_bootstrapped && _bootError == null)
                                    const CompanionDownloadBanner(),
                                  Expanded(
                                    child: MediaQuery.removePadding(
                                      context: context,
                                      // The companion bar covers the status-bar
                                      // strip itself, so leaving `padding.top` in
                                      // place below would have every SafeArea in
                                      // the app inset a second time. Nothing else
                                      // covers it any more: the server mark is a
                                      // ribbon over the top-right corner, which
                                      // neither fills the strip nor is owed an
                                      // inset for it.
                                      removeTop: companionBar,
                                      child: Stack(
                                        children: [
                                          ?child,
                                          // One FLOATING top slot, stacked vertically. These used to
                                          // be two separate Positioned(top: 0) layers that overlapped
                                          // whenever both were showing — which would have buried the
                                          // connection banner's retry target under the call pill.
                                          // Both children collapse to zero height when hidden.
                                          //
                                          // Only the transient chrome belongs here. The companion
                                          // download strip moved up into the Column above, because it
                                          // is neither transient nor small enough to float over a
                                          // header for the length of a download.
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
                                                  // The way back into a call whose
                                                  // screen was put away; the pen
                                                  // over a shared screen.
                                                  InCallPill(
                                                    call: _callService,
                                                    group: _groupCallService,
                                                    callScreenUp: _callScreenUp,
                                                    floating: CallFloat
                                                        .instance.wanted,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          // Strokes over the app while THIS device
                                          // shares its screen — above every route,
                                          // inert unless the pen is armed.
                                          ScreenShareOverlay(
                                            call: _callService,
                                            group: _groupCallService,
                                          ),
                                          // Pushes call screens onto the root navigator the moment
                                          // the call service transitions to a non-idle state.
                                          // Invisible.
                                          _CallOverlay(
                                            service: _callService,
                                            api: _api,
                                            screenUp: _callScreenUp,
                                          ),
                                          // Same job for group calls: pushes GroupCallScreen /
                                          // the group invite ringer. Invisible.
                                          _GroupCallOverlay(
                                            service: _groupCallService,
                                            api: _api,
                                            screenUp: _callScreenUp,
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
                              ),
                              // Drag-and-drop chrome: the cards that trail the
                              // pointer and the verdict chip under them. Above
                              // every route, because a drag is not part of any of
                              // them — it belongs to the WINDOW, and the aura it
                              // paints is what says so. Below the capture shield,
                              // like everything else. Inert (and free) on every
                              // platform without a desktop drag.
                              const DropChrome(),
                              // A minimized call's floating window, over
                              // every route. Nothing while there is none.
                              const CallFloatWindow(),
                              // Android's call Picture in Picture window: the
                              // call's picture over every route while the
                              // activity is shrunk into it. An empty box
                              // otherwise. See SystemPipView.
                              const SystemPipView(),
                              // Above EVERYTHING, the server mark included, so a
                              // screen recording cannot capture any of it.
                              const CaptureShield(),
                            ],
                          ),
                        )),
                      ),
                    ),
                  ),
                ),
              );
            },
            theme: ThemeData(
              brightness: isLight ? Brightness.light : Brightness.dark,
              scaffoldBackgroundColor: theme.background,
              pageTransitionsTheme: glassPageTransitionsTheme,
              textTheme: TextTheme(bodyMedium: theme.body),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              // Material controls that remain in the tree are dressed as
              // their iOS counterparts here, once, so no screen can miss it:
              // a thin rounded slider with a white thumb and no halo, thin
              // round-capped progress rings, an accent cursor.
              sliderTheme: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: theme.accent,
                inactiveTrackColor: theme.ink.withValues(alpha: 0.14),
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 13,
                  elevation: 3,
                  pressedElevation: 4,
                ),
                trackShape: const RoundedRectSliderTrackShape(),
                showValueIndicator: ShowValueIndicator.never,
              ),
              progressIndicatorTheme: ProgressIndicatorThemeData(
                color: theme.accent,
                circularTrackColor: Colors.transparent,
                strokeCap: StrokeCap.round,
                strokeWidth: 2.5,
              ),
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: theme.accent,
                selectionColor: theme.accent.withValues(alpha: 0.28),
                selectionHandleColor: theme.accent,
              ),
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

  /// Resolves the starting theme synchronously from preloaded settings: the
  /// fixed theme, or the half of the device-following pair that matches the
  /// device right now (Daylight and Midnight until somebody picks others).
  /// `SettingsStore.load()` MUST have been awaited before `runApp` for this to
  /// return the right value on the first frame (see `main.dart`).
  static AppTheme _initialTheme() => ThemeController.byId(
        SettingsStore.instance.themeIdFor(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        ),
      );
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
        // Previous shell, read before we overwrite the mirror below — the
        // only signal available here for detecting a live crossing, since
        // this LayoutBuilder reruns on every resize frame, not just on a
        // class flip (unlike LayoutScope's dependents).
        final split = Breakpoints.splitShellFor(constraints.maxWidth);
        final prevSplit = gLastSplitShell;
        // Mirror for code with no descendant context (push/call-overlay
        // routing in this file).
        gLastWindowClass = wc;
        gLastSplitShell = split;
        // Keyed off the SHELL, not the class: on a desktop the split shell
        // (with its route-free chat pane) arrives at medium already, and
        // that is the moment a phone-style push is left stranded over it.
        if (!prevSplit && split) {
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
  const _CallOverlay({
    required this.service,
    required this.api,
    required this.screenUp,
  });
  final CallService service;
  final ChatApi api;

  /// Whether a call screen (1:1 or group) is the top route. Written by the
  /// overlays that push them, read by the in-call pill.
  final ValueNotifier<bool> screenUp;
  @override
  State<_CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<_CallOverlay> {
  /// [_activeCallId] while the screen is up for [CallService.dialing], the
  /// call that has no id yet.
  static const _dialingLatch = '\u0000dialing';

  String? _activeCallId;
  String? _enrichedCallId;
  // The call we're currently ringing for. Driven straight from the CallService
  // listener (below) rather than IncomingCallScreen.initState, because on a
  // backgrounded web tab the frame loop is paused — so the post-frame push of
  // that screen never runs and its initState never fires. This listener runs on
  // the WS-driven state change regardless of rendering, so the ring (and the
  // call banner) work whether the tab is foreground or background.
  String? _ringingCallId;

  /// What [_ringingCallId] is ringing with: the ringtone (incoming) or the
  /// ringback (outgoing).
  AlertSound? _ringingSound;

  /// The outgoing call this device saw ringing and has not heard answered
  /// yet. See [_syncAnswered].
  String? _dialedCallId;

  /// The last call screen [_pushCallScreen] pushed, while it is up.
  Route<void>? _screenRoute;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
    widget.service.reopenTick.addListener(_reopen);
    widget.service.callAudioActivations.addListener(_onCallAudioActivated);
  }

  /// The call's session was (re)activated under a ringback already playing:
  /// start it again in the session it has now, rather than trust a player
  /// that began in the one it replaced.
  void _onCallAudioActivated() {
    if (_ringingSound != AlertSound.ringback) return;
    unawaited(AlertSounds.instance.play(AlertSound.ringback));
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    widget.service.reopenTick.removeListener(_reopen);
    widget.service.callAudioActivations.removeListener(_onCallAudioActivated);
    super.dispose();
  }

  /// The in-call pill asked for the screen back: forget that it was
  /// pushed, and let the normal routing push it again.
  void _reopen() {
    if (widget.screenUp.value) return;
    _activeCallId = null;
    _onChanged();
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
    // case above — this plays on every platform, real phones included. Only
    // once the callee's ringer is actually up ([CallSession.peerRinging]):
    // before that the call is "calling", and a ringback would claim a ring
    // that may never happen. Also gated
    // on [localStream] rather than the bare status transition:
    // `CallService.initiate` sets `outgoingRinging` BEFORE `_attachLocalMedia`
    // reclassifies the shared AVAudioSession, so starting playback at the
    // raw status change risks racing that reclassification.
    //
    // And only once the call's audio session is live
    // ([CallService.callAudioLive]): on an iPhone CallKit hands the session
    // over at `didActivate`, and a ringback started before it is not
    // guaranteed to be heard.
    final outgoingRinging =
        s != null &&
        s.status == CallStatus.outgoingRinging &&
        s.isCaller &&
        s.peerRinging &&
        widget.service.localStream != null &&
        widget.service.callAudioLive;
    final ringing = incomingRinging || outgoingRinging;
    if (ringing) {
      if (_ringingCallId == s.callId) return;
      _ringingCallId = s.callId;
      // The caller hears the plain ringback every phone network plays, not
      // the incoming ringtone: that one means "pick up", this "waiting".
      final sound = outgoingRinging ? AlertSound.ringback : AlertSound.ringtone;
      _ringingSound = sound;
      AlertSounds.instance.play(sound);
      if (outgoingRinging) unawaited(logCallAudioState('ringback'));
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
      final sound = _ringingSound;
      _ringingSound = null;
      if (sound != null) AlertSounds.instance.stop(sound);
      WebNotifier.dismissCall();
    }
  }

  /// The caller's "they picked up": a short chime and a tap, once, when a
  /// call this device dialed first connects. Keyed to the dial, not to the
  /// status, so an ICE-restart recovery (active again) or a call moved here
  /// from another device (switching to active) stays quiet, and the callee,
  /// who answered it themselves, never hears it.
  void _syncAnswered(CallSession? s) {
    if (s == null) {
      _dialedCallId = null;
      return;
    }
    if (!s.isCaller) return;
    if (s.status == CallStatus.outgoingRinging) {
      _dialedCallId = s.callId;
      return;
    }
    if (s.status != CallStatus.active || _dialedCallId != s.callId) return;
    _dialedCallId = null;
    AlertSounds.instance.play(AlertSound.connected);
    HapticFeedback.mediumImpact();
  }

  void _onChanged() {
    final s = widget.service.session;
    _syncRingtone(s);
    _syncAnswered(s);
    if (s == null) {
      _enrichedCallId = null;
      // A tap's dial: the screen goes up now, not a backend round trip
      // later. It already renders the dial, and stays up when the session
      // takes over (latched below).
      if (widget.service.dialing != null) {
        if (_activeCallId == _dialingLatch) return;
        _activeCallId = _dialingLatch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Failed or hung up before the frame: nothing left to show.
          final svc = widget.service;
          if (svc.dialing == null && svc.session == null) return;
          // Load the caller's tones once the screen is up, so the ringback
          // opens on its first beat and the answer chime is instant. Not
          // during the slide: the players are built on the platform thread,
          // which is the thread that draws Flutter's frames, and the first
          // call after a launch dropped frames at the start of the slide.
          // The ringback waits for the callee's ringer anyway, seconds out.
          _pushCallScreen()?.whenComplete(() => unawaited(AlertSounds.instance
              .prepare(const [AlertSound.ringback, AlertSound.connected])));
        });
        return;
      }
      _activeCallId = null;
      return;
    }
    final terminal =
        s.status == CallStatus.ended ||
        s.status == CallStatus.failed ||
        s.status == CallStatus.handedOff;
    if (terminal) return;
    _maybeEnrichPeerIdentity(s);
    if (_activeCallId == s.callId) return; // already showing
    if (_activeCallId == _dialingLatch && s.isCaller) {
      // The dial's own screen, now with a callId.
      _activeCallId = s.callId;
      return;
    }
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
        _pushCallScreen();
      } else {
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            settings: const RouteSettings(name: kProtectedRouteName),
            builder: (_) => IncomingCallScreen(
              service: widget.service,
              api: widget.api,
              screenUp: widget.screenUp,
              routeName: kProtectedRouteName,
            ),
          ),
        );
      }
    });
  }

  /// Pushes the 1:1 call screen; completes when its slide has settled
  /// (null when there is no navigator to push onto).
  Future<void>? _pushCallScreen() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return null;
    widget.screenUp.value = true;
    final route = CallScreenRoute<void>(
      // Back from the floating window, which already fills the screen.
      instant: CallFloat.instance.takeInstantPush(),
      settings: const RouteSettings(name: kProtectedRouteName),
      builder: (_) => CallScreen(service: widget.service, api: widget.api),
    );
    _screenRoute = route;
    nav.push(route).whenComplete(() {
      // Only the screen still up lowers the flag: an ended call's screen
      // taken out from under the next call's (see dismissCallRoute) must
      // not raise the in-call pill over the live one.
      if (!identical(_screenRoute, route)) return;
      _screenRoute = null;
      widget.screenUp.value = false;
    });
    final settled = _settled(route);
    // A dial's native setup waits for the slide; see
    // [CallService.screenSettled].
    if (widget.service.session == null && widget.service.dialing != null) {
      widget.service.screenSettled = settled;
    }
    return settled;
  }

  /// Completes when [route] stops moving in: finished, or turned back.
  ///
  /// Asked after the frame, never right after the push: the navigator
  /// holds a pushed page offstage for one frame (heroes measure it), and an
  /// offstage route's animation reads as complete (see `RouteLanding`).
  /// Read at the push, as it was, this completed at once, so a dial's
  /// CallKit, audio session, camera and peer connection all started on the
  /// slide's first frames: the very stutter the wait exists to prevent.
  static Future<void> _settled(ModalRoute<void> route) {
    final done = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = route.animation;
      if (a == null || a.status != AnimationStatus.forward) {
        done.complete();
        return;
      }
      void onStatus(AnimationStatus st) {
        if (st == AnimationStatus.forward) return;
        a.removeStatusListener(onStatus);
        if (!done.isCompleted) done.complete();
      }

      a.addStatusListener(onStatus);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    return done.future;
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
                // The brand's own spelling, set like an iOS launch title — the
                // stored string is the old tracked-capitals wordmark.
                Text(
                  'MonkeyHub',
                  style: theme.bodyEmph.copyWith(
                    fontSize: 20,
                    color: theme.ink,
                    letterSpacing: -0.2,
                  ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.wifi_exclamationmark,
                        size: 40,
                        color: theme.danger,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.of(context).bootErrorTitle,
                        style: theme.displayLarge.copyWith(letterSpacing: 0.37),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(context).bootErrorBody,
                        style: theme.bodySoft.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: groupedFill(theme),
                          borderRadius: BorderRadius.circular(
                            groupedRadius(theme),
                          ),
                        ),
                        child: Text(
                          error.toString(),
                          style: theme.mono.copyWith(color: theme.inkSoft),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // RETRY filled; changing server tinted beneath it.
                      // Quieter on purpose: a transient outage is the likelier
                      // cause, and that button signs the user out. It has to
                      // be here, but it should not be the first thing a hand
                      // reaches for.
                      SheetActionButton(
                        label: AppLocalizations.of(context).bootErrorRetry,
                        onTap: onRetry,
                      ),
                      const SizedBox(height: 10),
                      SheetActionButton(
                        label: AppLocalizations.of(context).serverChangeCta,
                        tonal: true,
                        onTap: onChangeServer,
                      ),
                      const SizedBox(height: 14),
                      // The one fact that turns "can't reach server" from a
                      // shrug into something actionable, and the only place it
                      // appears when the app cannot get past this screen.
                      Text(
                        ServerStore.instance.host,
                        style: groupedMetaStyle(theme),
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
  const _GroupCallOverlay({
    required this.service,
    required this.api,
    required this.screenUp,
  });
  final GroupCallService service;
  final ChatApi api;

  /// See [_CallOverlay.screenUp].
  final ValueNotifier<bool> screenUp;
  @override
  State<_GroupCallOverlay> createState() => _GroupCallOverlayState();
}

class _GroupCallOverlayState extends State<_GroupCallOverlay> {
  String? _pushedCallId;
  bool _ringerUp = false;

  /// Whether this platform rings a group invite through the OS. Deliberately
  /// the same predicate — and the same reasoning — as
  /// [_CallOverlayState._nativeRinger]: a group call is a call, and a device
  /// that shows CallKit for one and an in-app sheet for the other is a device
  /// whose user cannot learn what answering a call looks like.
  bool get _nativeRinger {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    if (p == TargetPlatform.android) return true;
    if (p == TargetPlatform.iOS) {
      return !NativeCallHandler.instance.isIosSimulator;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
    widget.service.reopenTick.addListener(_reopen);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    widget.service.reopenTick.removeListener(_reopen);
    super.dispose();
  }

  /// The in-call pill asked for the screen back.
  void _reopen() {
    if (widget.screenUp.value) return;
    _pushedCallId = null;
    _onChanged();
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
        widget.screenUp.value = true;
        nav
            .push(
              CallScreenRoute<void>(
                instant: CallFloat.instance.takeInstantPush(),
                settings: const RouteSettings(name: kProtectedRouteName),
                builder: (_) =>
                    GroupCallScreen(service: widget.service, api: widget.api),
              ),
            )
            .whenComplete(() => widget.screenUp.value = false);
      });
      return;
    }
    if (!svc.inCall) _pushedCallId = null;
    // Ring for a fresh invite — never over an active 1:1 or group call
    // (the room banner remains as the quiet join surface).
    final busyOneToOne = CallService.maybeInstance?.inCall ?? false;
    final invite = svc.pendingInvite;
    final invitedCallId = invite?['groupCallId']?.toString();
    if (invite != null &&
        invitedCallId != null &&
        invitedCallId.isNotEmpty &&
        !svc.inCall &&
        !busyOneToOne &&
        _nativeRinger) {
      // This device rings through the OS, so the in-app screen must not
      // appear — the same WhatsApp-model rule [_CallOverlay._nativeRinger]
      // states for 1:1 calls, and for the same reason: two ringers for one
      // call is worse than either.
      //
      // On Android the card is raised HERE when the app is alive, because
      // CallFcmService deliberately skips a foreground invite (it would
      // double-ring against exactly this path). On iOS this is a no-op —
      // `showIncoming` returns early off-Android — because the PushKit card
      // is already up: iOS delivers a VoIP push in the foreground too, and
      // CallKit is required to report it.
      //
      // Both paths derive the card's native id from the same groupCallId, so
      // a push that lands beside this call addresses the same card rather
      // than stacking a second one.
      //
      // The cost, taken deliberately and shared with the 1:1 path: on an
      // iPhone whose VoIP token is dead, the invite still arrives over the
      // subscription but nothing rings — the backend's banner rescue is all
      // there is. Checking `activeCalls()` first and falling back to the
      // in-app sheet is the obvious repair and it is worse: the PushKit card
      // routinely lands a beat AFTER the subscription does, so the check
      // would usually find nothing and raise a sheet that CallKit then
      // appears on top of. A silent rare case beats a double ringer in the
      // common one.
      unawaited(NativeCallHandler.instance.showIncoming(
        callId: invitedCallId,
        groupCallId: invitedCallId,
        // Who, and where — the same line the killed-app path's push titles
        // its card with (`voipPush.sendGroupVoip`), so the card reads the
        // same whichever of the two raised it. The starter's face is
        // already lensed for this viewer by `pendingInviteForUser`.
        callerName: _groupCardTitle(invite),
        kind: CallMediaKindWire.parse(invite['type']?.toString() ?? 'audio'),
        avatarUrl: invite['starterAvatarUrl']?.toString(),
      ));
      return;
    }
    if (invite != null &&
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
            builder: (_) => IncomingGroupCallScreen(
              service: widget.service,
              api: widget.api,
            ),
          ),
        );
        _ringerUp = false;
      });
    }
  }

  /// "Ayşe · Design Crew": the starter, then the room. Either alone when the
  /// other is missing; the generic label only when both are.
  static String _groupCardTitle(Map<String, dynamic> invite) {
    final starter = invite['starterName']?.toString() ?? '';
    final room = invite['roomName']?.toString() ?? '';
    if (starter.isNotEmpty && room.isNotEmpty) return '$starter · $room';
    if (room.isNotEmpty) return room;
    if (starter.isNotEmpty) return starter;
    return 'Group call';
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
    if (signedIn) {
      return HomeShell(
        key: ValueKey('home_${theme.id}'),
        repo: widget.repo,
        api: widget.api,
        feedApi: widget.feedApi,
        auth: widget.auth,
        family: widget.family,
      );
    }
    // A new install is asked how the app should look before it is asked who
    // it is — see [ThemeOnboardingScreen]. Crossfaded, keyed on which of the
    // two is showing and nothing else: the login screen's own theme key still
    // remounts it on a theme change exactly as before, without this switcher
    // fading one login screen into another.
    final onboarding = !SettingsStore.instance.themeOnboarded;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(onboarding ? 'theme_onboarding' : 'login'),
        child: onboarding
            ? const ThemeOnboardingScreen()
            : LoginScreen(key: ValueKey('login_${theme.id}'), auth: widget.auth),
      ),
    );
  }
}
