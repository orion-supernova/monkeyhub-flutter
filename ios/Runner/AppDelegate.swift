import Flutter
import UIKit
import UserNotifications
import PushKit
import CallKit
import CryptoKit
import AVKit
import AVFoundation
import CoreLocation
import Intents
import flutter_callkit_incoming
import WebRTC

@main
// UNUserNotificationCenterDelegate is NOT listed here: FlutterAppDelegate
// already conforms to it via FlutterAppLifeCycleProvider, and it implements
// both delegate methods — which is why the two below are `override`s rather
// than fresh declarations.
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CXProviderDelegate {
  // Pre-warmed Flutter engine, created and run at process launch —
  // INCLUDING cold background launches triggered by a VoIP push, where no
  // UI scene ever connects. The previous implicit-engine setup only
  // initialized Flutter when a scene attached a FlutterViewController, so
  // a killed+locked phone receiving a call had no engine, no registered
  // plugins, and therefore no CallKit ring. SceneDelegate attaches the UI
  // to this same engine when a scene does connect.
  var flutterEngine: FlutterEngine!

  // Event sink for screen-capture state changes pushed to Dart.
  fileprivate var captureEventSink: FlutterEventSink?

  // Background live-location sharing. Retained for the app's whole lifetime for
  // the same reason `voipRegistry` is: it owns a CLLocationManager whose
  // delegate callbacks — the Always answer, and the significant-change wake —
  // arrive minutes or hours after the call that started them, and a manager
  // that has been deallocated simply never calls back.
  private let liveLocation = LiveLocationBridge()

  // PushKit registry — must be retained by the app delegate for the whole
  // lifetime, otherwise iOS never delivers VoIP pushes. Token is read by Dart
  // via the `monkeyhub/voip` method channel after registration completes.
  private var voipRegistry: PKPushRegistry?
  private var cachedVoipToken: String?
  private var voipChannel: FlutterMethodChannel?
  // monkeyhub/screen_share, kept so the Broadcast Upload Extension's
  // lifecycle (see installBroadcastObservers) can be pushed to Dart.
  private var screenShareChannel: FlutterMethodChannel?
  // Maps Convex callId → CallKit UUID minted when we reported an incoming
  // call to flutter_callkit_incoming. Required so a follow-up "taken"
  // PushKit payload can end *that specific call* with
  // `.answeredElsewhere`. Cleared after a call ends.
  private var callKitUuidByCallId: [String: UUID] = [:]
  // Fallback-provider bookkeeping (see showIncomingWithRetry): when the
  // flutter_callkit_incoming plugin isn't registered in time we ring on
  // `foregroundReportProvider` instead. Maps that card's UUID → Convex
  // callId so answer/decline can be bridged to Dart and "taken" pushes can
  // dismiss the right card.
  private var fallbackCallIdByUuid: [UUID: String] = [:]
  // The fallback cards the user answered: the call itself now, never a
  // "ringing card" for `endRingingCards` / `hasRingingCard` to end.
  private var fallbackAnswered: Set<UUID> = []
  // monkeyhub/presence: lets `applicationWillTerminate` and a backgrounding
  // get the person's `away` out before the process stops. See there and
  // `_holdPresenceAway`.
  private var presenceChannel: FlutterMethodChannel?
  // The background-time grant `_holdPresenceAway` holds open while Dart's
  // `away` write is in flight. `.invalid` when none is.
  private var presenceHold: UIBackgroundTaskIdentifier = .invalid
  // voip-channel calls that fired before Dart was listening (cold
  // background launch). Dart drains them via `takePendingEvents` once its
  // handler is installed, so a fallback-card answer/decline isn't lost.
  private var pendingVoipEvents: [(method: String, args: [String: Any])] = []
  // True once Dart has called into the voip channel — only then is a
  // direct invokeMethod guaranteed to find a handler on the other side.
  private var voipDartReady = false

  // UserDefaults keys persisting the last invite's callId → CallKit UUID
  // mapping. The in-memory `callKitUuidByCallId` dies with the process, but
  // a "taken" push can arrive in a NEW process (app killed between invite
  // and taken) and must still dismiss the right card. Only one call rings
  // at a time, so a single persisted pair suffices.
  private static let lastInviteCallIdKey = "voip.lastInvite.callId"
  private static let lastInviteUuidKey = "voip.lastInvite.uuid"

  // ── Ghost-ring guards ────────────────────────────────────────────────────
  //
  // A cancelled call must not leave this phone ringing, in any app state, and
  // the Dart side cannot promise that on its own: it may not be running (a
  // process PushKit launched), and it can only ack "no card" for the moment
  // it looked — an invite push APNs holds past the cancel then raises a card
  // nothing is left to end (the backend skips the `taken` push for a device
  // that acked). So native keeps three things of its own:
  //
  //   - `voip.deadCalls`: 1:1 callIds this device knows are over (Dart's
  //     `callOver`, or the ring report's answer). An invite for one of them
  //     is reported-and-ended on the spot instead of ringing. Persisted, so a
  //     process killed in between still honours it. Pruned by age.
  //   - `invitesInFlight`: callIds whose invite push is between arrival and
  //     the card's report, so `cardLive` never answers "gone" in that window.
  //   - the native ring watch (`ringWatches`): while a push-raised card rings
  //     un-answered, re-ask the backend with the push's signed ring proof
  //     every `ringWatchInterval` and end the card the moment the call is no
  //     longer ringing. No Dart, no session.
  private static let deadCallsKey = "voip.deadCalls"
  private static let deadCallTtl: TimeInterval = 120
  private var invitesInFlight: Set<String> = []
  private struct RingWatch {
    let timer: Timer
    let startedAt: Date
    var task: UIBackgroundTaskIdentifier
    var probing: Bool
  }
  private var ringWatches: [String: RingWatch] = [:]
  private static let ringWatchInterval: TimeInterval = 2
  // The backend gives up at 30s; the plugin's own card timeout is 30s too.
  private static let ringWatchCeiling: TimeInterval = 45
  private lazy var callObserver = CXCallObserver()

  // monkeyhub/phone_call — whether any call is up on the phone (see
  // PhoneCallActivity below). Retained for the process: the observer only
  // calls back while something holds it.
  private let phoneCallActivity = PhoneCallActivity()

  // ── Ordinary (alert) push ────────────────────────────────────────────────
  //
  // A DIFFERENT token from `cachedVoipToken`, on a different APNs topic: this
  // one is the bare bundle id, PushKit's is `<bundle>.voip`. Every banner,
  // badge and silent dismiss goes here; only ringing goes there. Sending one
  // on the other's topic is rejected, and the backend's dead-token sweep would
  // then clear a perfectly good token — so they are kept scrupulously apart on
  // this side too.
  private var cachedApnsToken: String?
  private var notifChannel: FlutterMethodChannel?
  // Same queue-until-Dart-exists contract as the voip channel below: a tap
  // that cold-launches the app fires `didReceive response` long before any
  // Dart handler is installed, and a bare invokeMethod would be dropped.
  private var pendingNotifEvents: [(method: String, args: [String: Any])] = []
  private var notifDartReady = false

  // ── The system share sheet ───────────────────────────────────────────────
  //
  // The Share Extension cannot talk to this process directly — it is a
  // separate binary in a separate sandbox — so it writes into the App Group
  // container and asks iOS to open us. [ShareInbox] reads the container; this
  // channel carries the result to Dart.
  private var shareChannel: FlutterMethodChannel?
  // Same queue-until-Dart-exists contract as the two channels above, and here
  // it is the ORDINARY case rather than the edge one: a share is very often
  // what launched the process.
  private var pendingShares: [[String: Any]] = []
  private var shareDartReady = false
  // The room the user is currently looking at, pushed down from Dart on every
  // open and close. Read in `willPresent` to suppress a banner for a
  // conversation that is already on screen.
  //
  // Cached rather than asked for: `willPresent` hands iOS a completion handler
  // it expects promptly, and a round trip into an isolate that may be mid-GC
  // is a good way to hang it.
  private var activeRoomId: String?

  fileprivate func setCaptureEventSink(_ sink: FlutterEventSink?) {
    captureEventSink = sink
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Debug-only: pins `derivedCallUuid` to the vector
    // test/call_native_uuid_test.dart pins for the Dart and Kotlin
    // derivations. A drift here would not crash anything — a `taken` push
    // would just silently stop finding outbound cards again.
    assert(
      Self.derivedCallUuid("hello").uuidString == "5D41402A-BC4B-3A76-B971-9D911017C592",
      "derivedCallUuid drifted from NativeCallHandler.derivedUuid"
    )
    // Start Dart immediately, headless if need be. On a background VoIP
    // launch this is what makes flutter_callkit_incoming register (its
    // sharedInstance is set inside GeneratedPluginRegistrant.register) so
    // the CallKit ringer can show, and lets the app restore auth + attach
    // signaling so an answered call actually connects.
    let engine = FlutterEngine(name: "main")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    registerAppChannels(on: engine)
    liveLocation.register(on: engine)
    flutterEngine = engine

    // Before anything else touches launchOptions. An app relaunched by a
    // significant location change must re-register for them here, in this
    // method — the registration does not survive the relaunch, so waiting for
    // Dart to ask would buy exactly one more wake and then silence. See
    // [LiveLocationBridge].
    //
    // This runs on every launch, including ordinary ones, and does nothing
    // unless the location key is present.
    liveLocation.handleLaunch(options: launchOptions)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_capturedDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    // The notification, not `applicationDidEnterBackground`, for the same
    // reason as `didBecomeActiveNotification` below: under the UIScene
    // lifecycle the delegate callback is never called.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_holdPresenceAway),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    // Shares are collected from the App Group container, not from a URL.
    //
    // The Share Extension's only documented way to wake us is
    // `extensionContext.open`, which is allowed to fail and on some releases
    // simply does — so nothing may depend on that URL arriving. Draining on
    // every foreground makes the container the delivery mechanism and the URL
    // a mere optimisation, at the cost of one listing of a usually-empty
    // directory.
    //
    // `didBecomeActiveNotification` rather than `applicationDidBecomeActive`:
    // this app runs the UIScene lifecycle (see SceneDelegate), under which the
    // app delegate's own lifecycle callbacks are never called. The notification
    // is posted either way.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_drainShareInbox),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    // A cold launch FROM a share: the extension has already written the
    // container by the time we get here, and the first `didBecomeActive` is
    // still several runloop turns away.
    _drainShareInbox()
    // Anything a previous run never collected. Day-bounded — see ShareInbox.sweep.
    DispatchQueue.global(qos: .utility).async { ShareInbox.sweep() }

    // Register for VoIP pushes. The callback flow:
    //   PKPushRegistry → didUpdate pushCredentials → Dart picks up token via
    //   `monkeyhub/voip#getToken` → Convex stores it on the user record.
    // When a push arrives:
    //   didReceiveIncomingPushWith → flutter_callkit_incoming shows the
    //   system call UI; Dart-side listeners hook accept/decline.
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    // Ordinary APNs. FlutterAppDelegate *conforms* to
    // UNUserNotificationCenterDelegate (which is why the two handlers below
    // are overrides) but never assigns itself here — so without this line no
    // banner tap and no foreground presentation would ever reach us.
    UNUserNotificationCenter.current().delegate = self
    // Does NOT prompt. Since iOS 8 a device token is issued regardless of
    // notification authorization, because silent/background pushes need one —
    // which is exactly how the `kind=dismiss` badge sync keeps working for
    // someone who declined banners. Asking is a separate, later, Dart-driven
    // act; see PushManager._maybeRequestNotificationPermission.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - APNs (alert) registration

  // `Foundation.Data`, spelled out: flutter_callkit_incoming exports a class
  // called `Data` (the call-payload type used all over this file), so the bare
  // name is ambiguous here.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    cachedApnsToken = token
    NSLog("[apns] alert token: \(token)")
    invokeNotifOrQueue("onApnsTokenUpdated", args: ["token": token])
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // Expected on a Simulator without a paired push environment, and on a
    // device with no network at launch. Dart re-asks on every resume, so this
    // is informational rather than a failure to recover from.
    NSLog("[apns] registration failed: \(error.localizedDescription)")
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Whether to show a notification that arrived while the app is frontmost.
  ///
  /// Deliberately does NOT call super. The completion handler may be invoked
  /// exactly once — calling it here and letting the superclass's plugin chain
  /// call it again crashes — and nothing in this app's plugin set presents a
  /// foreground notification. (flutter_callkit_incoming ships a willPresent
  /// helper, but it is a manual one the host chooses to call, not a registered
  /// lifecycle delegate; its answer is the same "show it" we default to.)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let info = notification.request.content.userInfo
    if let roomId = info["roomId"] as? String,
       !roomId.isEmpty,
       roomId == activeRoomId {
      // They are already reading this conversation — the live subscription
      // put the message on screen before the push arrived.
      completionHandler([])
      return
    }
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  /// A notification was tapped. Routes to the same two destinations the
  /// in-app handler uses; `app.dart` stashes the roomId if the navigator
  /// isn't mounted yet (cold start from a lock-screen tap).
  ///
  /// Anything that isn't ours goes to super — flutter_callkit_incoming's
  /// missed-call notification carries a "Call back" action, and swallowing the
  /// response here would make that button do nothing. Exactly one branch may
  /// resolve the completion handler, so ours returns before reaching super.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // First, because it is matched on the ACTION identifier rather than on the
    // payload and would otherwise fall through to the room branch below — the
    // live-share notification carries no roomId, but a future one might, and a
    // STOP press that merely opened the chat would be the worst possible
    // outcome for a button whose entire job is to stop a tracker.
    if liveLocation.handleNotificationResponse(response) {
      completionHandler()
      return
    }
    let info = response.notification.request.content.userInfo
    if let roomId = info["roomId"] as? String, !roomId.isEmpty {
      // `focus` rides alongside: what to show ON TOP of the room once it is
      // open. Only `roomChanges` sends it today — a member suggested a new
      // group name, description or picture and the admin tapping this should
      // land on approve/reject. Forwarded verbatim and empty when absent, so
      // Dart owns the whole vocabulary and a value this build has never heard
      // of simply opens the room.
      let focus = info["focus"] as? String ?? ""
      invokeNotifOrQueue("onOpenRoom", args: ["roomId": roomId, "focus": focus])
      completionHandler()
      return
    }
    if (info["kind"] as? String) == "approval" {
      invokeNotifOrQueue("onOpenRequests", args: [:])
      completionHandler()
      return
    }
    // The once-a-day games nudge. Carries no roomId by construction, so it
    // reaches here rather than the branch above, and lands on the Feed with
    // today's games open. See backend/convex/dailyNudge.ts.
    if (info["kind"] as? String) == "daily_games" {
      invokeNotifOrQueue("onOpenGames", args: [:])
      completionHandler()
      return
    }
    // A friend posted a highlight or scored a point. Carries the moment's own
    // id, so the tap opens THAT card rather than merely landing on today's
    // board and leaving the person to find the thing they were told about.
    // See backend/convex/socialPush.ts.
    if (info["kind"] as? String) == "friend_moment",
       let momentId = info["momentId"] as? String, !momentId.isEmpty {
      // `focus` as for a room: "comments" on a comment or reply push, which
      // opens the card with its conversation up. Empty when absent.
      let focus = info["focus"] as? String ?? ""
      invokeNotifOrQueue("onOpenMoment", args: ["momentId": momentId, "focus": focus])
      completionHandler()
      return
    }
    // A friend shared a game result. Lands on the games shelf, where the
    // standings they are now on top of live — the same destination as the
    // nudge, because there is no per-result screen to open.
    if (info["kind"] as? String) == "game_result" {
      invokeNotifOrQueue("onOpenGames", args: [:])
      completionHandler()
      return
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  // MARK: - Broadcast Upload Extension lifecycle

  // The extension (ios/BroadcastExtension/SampleHandler.swift) posts two
  // Darwin notifications: `iOS_BroadcastStarted` from `broadcastStarted` and
  // `iOS_BroadcastStopped` from `broadcastFinished`. flutter_webrtc's
  // capturer relays neither — the track it hands Dart is "live" from the
  // moment the system picker is presented, and when the user ends the
  // broadcast from the red status-bar pill the socket simply goes quiet.
  // Dart needs both moments: the first to announce the share to peers only
  // once frames can flow (and to roll back a share whose picker was
  // dismissed), the second to end a share the app did not end itself.
  // Darwin notifications are system-wide and carry no payload, but iOS runs
  // at most one broadcast at a time, so while this app has a share pending
  // or live the one that fires is ours; Dart ignores them otherwise.
  private static let broadcastStartedName = "iOS_BroadcastStarted"
  private static let broadcastStoppedName = "iOS_BroadcastStopped"
  // The other direction: the app asks the extension to end the broadcast.
  private static let broadcastStopRequestName = "iOS_BroadcastStopRequested"
  private var broadcastObserversInstalled = false

  private func installBroadcastObservers() {
    if broadcastObserversInstalled { return }
    broadcastObserversInstalled = true
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = Unmanaged.passUnretained(self).toOpaque()
    // A C callback: it may capture nothing, so the delegate rides in as
    // the observer pointer (retained for the process lifetime anyway).
    let callback: CFNotificationCallback = { _, observer, name, _, _ in
      guard let observer = observer, let name = name else { return }
      let me = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
      me.onBroadcastNotification(name.rawValue as String)
    }
    for name in [Self.broadcastStartedName, Self.broadcastStoppedName] {
      CFNotificationCenterAddObserver(
        center,
        observer,
        callback,
        name as CFString,
        nil,
        .deliverImmediately
      )
    }
  }

  private func onBroadcastNotification(_ name: String) {
    let method: String
    if name == Self.broadcastStartedName {
      method = "onBroadcastStarted"
    } else if name == Self.broadcastStoppedName {
      method = "onBroadcastStopped"
    } else {
      return
    }
    NSLog("[screen_share] \(method)")
    DispatchQueue.main.async { [weak self] in
      self?.screenShareChannel?.invokeMethod(method, arguments: nil)
    }
  }

  // MARK: - PKPushRegistryDelegate

  // Swiped away in the app switcher. The app was `inactive` there, a state
  // that writes no presence, and nothing else runs before the process goes:
  // the stored `online` used to outlive the app by the staleness window plus
  // the sweep, minutes of a closed app reading as online. Dart writes `away`
  // (`_awayOnTerminate` in app.dart); spinning the run loop here is what lets
  // the channel call and its reply move while iOS waits on this method.
  // Bounded well inside the few seconds iOS allows.
  override func applicationWillTerminate(_ application: UIApplication) {
    if let channel = presenceChannel {
      var answered = false
      channel.invokeMethod("willTerminate", arguments: nil) { _ in answered = true }
      let deadline = Date().addingTimeInterval(1.5)
      while !answered && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
      }
    }
    super.applicationWillTerminate(application)
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    cachedVoipToken = token
    NSLog("[voip] PushKit token: \(token)")
    // Queue-until-Dart-ready like every other voip event — a raw invoke
    // that raced Dart's setMethodCallHandler was silently dropped (Dart's
    // getToken-on-resume papered over it, but rotation mid-session lost).
    invokeVoipOrQueue("onTokenUpdated", args: ["token": token])
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    cachedVoipToken = nil
    invokeVoipOrQueue("onTokenUpdated", args: ["token": NSNull()])
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else { completion(); return }

    // Required on iOS 13+: we MUST report an incoming call to CallKit before
    // returning from this method, or the system kills the app. Hand off to
    // flutter_callkit_incoming, which talks to CXProvider and exposes the
    // accept/decline events back to Dart.
    let dict = payload.dictionaryPayload
    let kind = (dict["kind"] as? String) ?? "invite"
    // A group call's identity is its groupCallId. Everything downstream —
    // the CallKit UUID, the `extra` Dart reads, the card a later dismissal
    // has to find — keys off this one string, exactly as the 1:1 path keys
    // off the callId, which is why they share a variable rather than
    // branching twice.
    let isGroup = kind == "group_invite" || kind == "group_taken"
    let convexCallId = isGroup
      ? ((dict["groupCallId"] as? String) ?? "")
      : ((dict["callId"] as? String) ?? "")

    // "taken" push: a sibling device accepted/rejected this call.
    // Dismiss CallKit with `.answeredElsewhere` so the system shows the
    // correct dismissal animation instead of a silent kill. We still must
    // satisfy Apple's "every push reports an incoming call" contract —
    // reportCallEndedElsewhere does that via the foregroundReportProvider.
    //
    // A group's dismissal lands here too, and needs no branch of its own:
    // its card was shown under `derivedCallUuid(groupCallId)`, which is
    // precisely the id the "card this device placed itself" branch inside
    // reportCallEndedElsewhere already looks for.
    if kind == "taken" || kind == "group_taken" {
      let reason = (dict["reason"] as? String) ?? "?"
      NSLog("[voip] \(kind) push — id=\(convexCallId) reason=\(reason)")
      if kind == "taken" {
        // Over for this device whatever the reason; an invite APNs still
        // holds for it must not ring after this.
        stopRingWatch(convexCallId, why: "taken push (\(reason))")
        markCallDead(convexCallId)
      }
      reportCallEndedElsewhere(convexCallId: convexCallId)
      completion()
      return
    }

    // Convex callIds are NOT RFC-4122 UUIDs. flutter_callkit_incoming
    // force-unwraps `UUID(uuidString:)` on `data.uuid` at line 286 of
    // SwiftFlutterCallkitIncomingPlugin.swift, so passing our callId
    // crashes the app. Mint a proper UUID for CallKit and preserve the
    // Convex callId in `extra` for Dart-side diagnostics.
    //
    // A GROUP invite is the exception: its id is DERIVED from the
    // groupCallId, not minted. The 1:1 scheme works because the process that
    // mints the id also records it (in memory and in UserDefaults) for the
    // one "taken" that may follow — but a group call can be left, joined
    // elsewhere, declined or simply end, from any of several devices, and
    // whichever process has to take the card down is not reliably the one
    // that raised it. Deriving means every side computes the same id from
    // the same string with no state to carry: `uuidForCallId` in
    // CallFcmService.kt and `derivedUuid` in native_call_handler.dart are
    // the same function, pinned against this one by
    // test/call_native_uuid_test.dart.
    let callerName = (dict["callerName"] as? String) ?? "Incoming call"
    let callerHandle = (dict["callerHandle"] as? String) ?? callerName
    let callType = ((dict["callType"] as? String) == "video") ? 1 : 0

    // An invite for a call this device already knows is over: APNs held it
    // past the cancel, or it is a duplicate delivery of one whose card we
    // already took down. PushKit still demands a report, but it must not
    // ring — report and end in one turn, exactly like a `taken` with
    // nothing to end. Without this the card rang until the plugin's own 30s
    // timeout: the device had acked "no card" before the push landed, so
    // the backend's `taken` push skipped it.
    if !isGroup && !convexCallId.isEmpty && isCallDead(convexCallId) {
      NSLog("[voip] invite push for \(convexCallId) — call already over here; report-and-end, no ring")
      reportAndEndCall(callerName: callerName)
      completion()
      return
    }
    // A second invite push for a call this device already holds a card for
    // (the transport retry, a duplicate delivery) never mints a new card.
    //
    // Answered (or this device's own outgoing card): the call is live here.
    // Reporting it again would ring a second card over the live call, and
    // the writes below would repoint the map, the persisted pair and the
    // plugin's `data` at that ghost. PushKit still wants a report: the
    // compliant report-and-end, which never rings.
    //
    // Still ringing: reuse that card's id, so CallKit refuses the report as
    // a duplicate instead of raising a second card under a fresh random id
    // that nothing would know to end. The map and the pair already name it.
    let existingCards = convexCallId.isEmpty ? [] : trackedCards(for: convexCallId)
    if existingCards.contains(where: { $0.accepted }) {
      NSLog("[voip] invite push for \(convexCallId) — call already answered here; report-and-end, no ring")
      reportAndEndCall(callerName: callerName)
      completion()
      return
    }
    let existingUuid = isGroup ? nil : existingCards.first?.uuid
    if let existingUuid = existingUuid {
      NSLog("[voip] invite push for \(convexCallId) — card \(existingUuid.uuidString) already up; reusing its id")
    }
    let callUuid = isGroup && !convexCallId.isEmpty
      ? Self.derivedCallUuid(convexCallId)
      : (existingUuid ?? UUID())
    NSLog("[voip] invite push for \(convexCallId.isEmpty ? "?" : convexCallId) — ringing card \(callUuid.uuidString)")

    // WhatsApp-style: the receiver ALWAYS gets the native CallKit UI —
    // foreground included. (The in-app ringer screen is reserved for
    // platforms without CallKit: iOS simulator and desktop.) The Dart
    // side creates its session silently from the realtime invite signal
    // and only navigates once CallKit reports the accept.

    // Stash the CallKit UUID so a follow-up "taken" push can end this
    // specific call with `.answeredElsewhere`. Persisted too, because the
    // "taken" may land in a fresh process after this one is killed.
    //
    // Skipped entirely for a group, whose id is derived rather than minted:
    // there is nothing to remember, and writing the two UserDefaults keys
    // would CLOBBER the pair a 1:1 invite left there — a group invite landing
    // between a 1:1 invite and its "taken" would cost that call its dismissal.
    if !convexCallId.isEmpty && !isGroup && existingUuid == nil {
      // Prune before insert: entries used to be removed ONLY when a "taken"
      // push consumed them, so normal answer/decline/timeout left them
      // forever — unbounded growth plus stale mappings for later lookups.
      // Anything not in the plugin's live call list is a dead card.
      if callKitUuidByCallId.count > 4 {
        let live = Set(
          (SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? [])
            .compactMap { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) }
        )
        callKitUuidByCallId = callKitUuidByCallId.filter { live.contains($0.value) }
      }
      callKitUuidByCallId[convexCallId] = callUuid
      UserDefaults.standard.set(convexCallId, forKey: Self.lastInviteCallIdKey)
      UserDefaults.standard.set(callUuid.uuidString, forKey: Self.lastInviteUuidKey)
    }

    // Use the fully-qualified module path so Swift doesn't pick Foundation.Data.
    let callData = flutter_callkit_incoming.Data(
      id: callUuid.uuidString,
      nameCaller: callerName,
      handle: callerHandle,
      type: callType
    )
    // `groupCallId` is what tells Dart which of the two accept paths this is
    // (`GroupCallService.joinCall` vs `CallService.acceptIncoming`) — see
    // `NativeCallHandler._groupCallIdFromParams`. Absent for a 1:1, which is
    // the discriminant rather than a missing field.
    var extra: [String: Any] = [
      "callId": convexCallId,
      "callerName": callerName,
      "callType": callType,
      "rawPayload": dict,
    ]
    if isGroup {
      extra["groupCallId"] = convexCallId
      extra["roomId"] = (dict["roomId"] as? String) ?? ""
    }
    callData.extra = extra as NSDictionary
    // Classify the CallKit audio session correctly so the plugin's own
    // configureAudioSession (which runs at ring/answer/didActivate) sets a
    // call-appropriate mode instead of .default — .videoChat also biases
    // the default route toward the loudspeaker.
    callData.supportsVideo = callType == 1
    callData.audioSessionMode = callType == 1 ? "videoChat" : "voiceChat"

    // Until the card is reported, `cardLive` must not call it gone: Dart
    // asking in this window would ack a card about to ring.
    if !isGroup && !convexCallId.isEmpty { invitesInFlight.insert(convexCallId) }
    showIncomingWithRetry(callData, convexCallId: convexCallId) { [weak self] in
      completion()
      // The report's completion is CallKit's queue, not necessarily main;
      // everything the ghost-ring guards touch lives on main.
      DispatchQueue.main.async {
        if !isGroup && !convexCallId.isEmpty { self?.invitesInFlight.remove(convexCallId) }
        // A group ring has no caller waiting on "ringing"; its push carries
        // no proof and this is a no-op for it.
        self?.reportRinging(dict, callUuid: callUuid)
      }
    }
  }

  /// Tells the caller's server this phone is ringing: the ring proof the
  /// invite push carries (`ringUrl`/`ringUser`/`ringSig`, signed in
  /// backend/convex/receiptToken.ts) posted back once the card is really up.
  /// The caller's screen goes from "calling" to "ringing" and the ringback
  /// starts. No session and no Dart: the signature is the authentication,
  /// and it only says what this phone is in a position to say.
  ///
  /// Only for a card that exists: the plugin calls the report's completion on
  /// an error too (Focus, a refused report), and a phone that is not ringing
  /// must not say it is. Fire-and-forget under a background task, so a push
  /// that launched the process still gets the post out. The Android twin is
  /// `reportRinging` in CallFcmService.kt.
  ///
  /// The answer carries the call's status, and this is where a card raised
  /// for a call that is already over comes down (an invite APNs delivered
  /// after the cancel). A call still ringing arms the native ring watch.
  private func reportRinging(_ dict: [AnyHashable: Any], callUuid: UUID) {
    guard let proof = RingProof(dict) else { return }
    let card = trackedCards(for: proof.callId).contains { $0.uuid == callUuid }
    guard card || fallbackCallIdByUuid[callUuid] != nil else {
      NSLog("[voip] no card up for \(proof.callId) — not reporting ringing")
      return
    }
    postRingProof(proof, probe: false) { [weak self] status in
      self?.onRingStatus(status, proof: proof)
    }
  }

  /// The signed ring proof an invite push carries, enough to ask the backend
  /// about this one call as its callee without a session.
  private struct RingProof {
    let url: URL
    let callId: String
    let userId: String
    let sig: String

    init?(_ dict: [AnyHashable: Any]) {
      guard
        let raw = dict["ringUrl"] as? String,
        let url = URL(string: raw),
        let callId = dict["callId"] as? String,
        !callId.isEmpty,
        let userId = dict["ringUser"] as? String,
        let sig = dict["ringSig"] as? String
      else { return nil }
      self.url = url
      self.callId = callId
      self.userId = userId
      self.sig = sig
    }
  }

  /// POST the ring proof; `probe` reads the status without reporting a ring.
  /// Completes on the main queue with the call's status ("ringing",
  /// "cancelled", … "gone"), or nil when there was no usable answer (offline,
  /// an older backend that answers 204) — which decides nothing.
  private func postRingProof(
    _ proof: RingProof,
    probe: Bool,
    completion: @escaping (String?) -> Void
  ) {
    var fields: [String: Any] = [
      "callId": proof.callId,
      "userId": proof.userId,
      "sig": proof.sig,
    ]
    if probe { fields["probe"] = true }
    guard let body = try? JSONSerialization.data(withJSONObject: fields) else {
      completion(nil)
      return
    }
    var request = URLRequest(url: proof.url)
    request.httpMethod = "POST"
    request.timeoutInterval = 8
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    var task: UIBackgroundTaskIdentifier = .invalid
    task = UIApplication.shared.beginBackgroundTask(withName: "ring-report") {
      UIApplication.shared.endBackgroundTask(task)
      task = .invalid
    }
    URLSession.shared.dataTask(with: request) { data, response, error in
      var status: String?
      if let error = error {
        NSLog("[voip] ring \(probe ? "probe" : "report") not sent: \(error.localizedDescription)")
      } else if (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        status = json["status"] as? String
      }
      DispatchQueue.main.async {
        if task != .invalid {
          UIApplication.shared.endBackgroundTask(task)
          task = .invalid
        }
        completion(status)
      }
    }.resume()
  }

  /// Act on what the backend says about a call this phone rings for.
  private func onRingStatus(_ status: String?, proof: RingProof) {
    let callId = proof.callId
    switch status {
    case nil, "unknown":
      // No answer is no decision; the watch (or Dart, or `taken`) decides.
      armRingWatch(proof)
    case "ringing":
      armRingWatch(proof)
    case "active":
      // Answered — on another device, or right here (whose card is accepted
      // and so untouched below). Either way this ring is over.
      stopRingWatch(callId, why: "call answered")
      let ended = endRingingCards(callId: callId, reason: 4, includeFallback: true)
      NSLog("[voip] ring status active for \(callId) — ended \(ended) ringing card(s) as answered elsewhere")
    default:
      // cancelled / missed / rejected / ended / failed / gone: over for good.
      stopRingWatch(callId, why: "call \(status ?? "?")")
      markCallDead(callId)
      let ended = endRingingCards(callId: callId, reason: 2, includeFallback: true)
      NSLog("[voip] ring status \(status ?? "?") for \(callId) — ended \(ended) dead card(s)")
    }
  }

  /// The native ring watch: re-ask every `ringWatchInterval` while this
  /// call's card rings un-answered. Bounded by the card itself, an answer,
  /// `ringWatchCeiling`, and the background time iOS grants.
  private func armRingWatch(_ proof: RingProof) {
    let callId = proof.callId
    guard ringWatches[callId] == nil else { return }
    var bgTask: UIBackgroundTaskIdentifier = .invalid
    bgTask = UIApplication.shared.beginBackgroundTask(withName: "ring-watch") { [weak self] in
      self?.stopRingWatch(callId, why: "background time expired")
    }
    let timer = Timer(timeInterval: Self.ringWatchInterval, repeats: true) { [weak self] _ in
      self?.ringWatchTick(proof)
    }
    RunLoop.main.add(timer, forMode: .common)
    ringWatches[callId] = RingWatch(timer: timer, startedAt: Date(), task: bgTask, probing: false)
    NSLog("[voip] ring watch armed for \(callId)")
  }

  private func ringWatchTick(_ proof: RingProof) {
    let callId = proof.callId
    guard let watch = ringWatches[callId] else { return }
    guard hasRingingCard(callId) else {
      stopRingWatch(callId, why: "card no longer ringing")
      return
    }
    if Date().timeIntervalSince(watch.startedAt) > Self.ringWatchCeiling {
      stopRingWatch(callId, why: "ceiling reached")
      return
    }
    if watch.probing { return }
    ringWatches[callId]?.probing = true
    postRingProof(proof, probe: true) { [weak self] status in
      guard let self = self, self.ringWatches[callId] != nil else { return }
      self.ringWatches[callId]?.probing = false
      if status != "ringing" {
        NSLog("[voip] ring watch probe for \(callId) — status \(status ?? "no answer")")
      }
      // Only a definite answer acts; "no answer" leaves the watch running.
      if let status = status, status != "unknown", status != "ringing" {
        self.onRingStatus(status, proof: proof)
      }
    }
  }

  private func stopRingWatch(_ callId: String, why: String) {
    guard let watch = ringWatches.removeValue(forKey: callId) else { return }
    watch.timer.invalidate()
    if watch.task != .invalid { UIApplication.shared.endBackgroundTask(watch.task) }
    NSLog("[voip] ring watch stopped for \(callId): \(why)")
  }

  // ── Cards, by the plugin's own record and their real UUIDs ──

  /// Every card the plugin holds for [callId]: a push-raised incoming card
  /// (its `extra.callId`, or the id this process minted for it), a group
  /// card (`extra.groupCallId`), or this device's own outgoing card (the
  /// derived id). `accepted` is answered-or-outgoing.
  private func trackedCards(for callId: String) -> [(uuid: UUID, accepted: Bool)] {
    guard !callId.isEmpty,
          let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance
    else { return [] }
    let minted = callKitUuidByCallId[callId]
    let derived = Self.derivedCallUuid(callId)
    return plugin.trackedCalls().compactMap { item in
      guard let uuid = (item["id"] as? String).flatMap(UUID.init(uuidString:)) else {
        return nil
      }
      let extra = item["extra"] as? NSDictionary
      let matches = (extra?["callId"] as? String) == callId
        || (extra?["groupCallId"] as? String) == callId
        || uuid == minted
        || uuid == derived
      guard matches else { return nil }
      return (uuid: uuid, accepted: (item["accepted"] as? Bool) ?? false)
    }
  }

  /// Whether CallKit has already ended [uuid]. A call the observer has not
  /// heard of yet (it learns of a fresh report a beat late) is NOT ended.
  private func observerSaysEnded(_ uuid: UUID) -> Bool {
    callObserver.calls.first(where: { $0.uuid == uuid })?.hasEnded ?? false
  }

  /// Is any card for [callId] still up on this device — the only honest
  /// basis for a dismissal ack (Dart's `cardGone`). An invite still being
  /// reported counts as up.
  private func cardLive(_ callId: String) -> Bool {
    if invitesInFlight.contains(callId) { return true }
    if trackedCards(for: callId).contains(where: { !observerSaysEnded($0.uuid) }) {
      return true
    }
    return fallbackCallIdByUuid.values.contains(callId)
  }

  private func hasRingingCard(_ callId: String) -> Bool {
    if trackedCards(for: callId).contains(where: { !$0.accepted && !observerSaysEnded($0.uuid) }) {
      return true
    }
    return fallbackCallIdByUuid.contains { $0.value == callId && !fallbackAnswered.contains($0.key) }
  }

  /// End every UN-ANSWERED card for [callId] by its real UUID, reporting it
  /// ended (`saveEndCall`: no CXEndCallAction, so no DECLINE echo for Dart
  /// to mistake for the user). An answered or outgoing card is never
  /// touched here; those end through the call's own teardown. Reasons are
  /// the plugin's: 2 remote ended, 4 answered elsewhere. [includeFallback]
  /// also ends the fallback provider's un-answered cards for the call.
  @discardableResult
  private func endRingingCards(callId: String, reason: Int, includeFallback: Bool) -> Int {
    var ended = 0
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      for card in trackedCards(for: callId) where !card.accepted {
        NSLog("[voip] ending ringing card \(card.uuid.uuidString) for \(callId) (reason \(reason))")
        plugin.saveEndCall(card.uuid.uuidString, reason)
        ended += 1
      }
    }
    if includeFallback {
      for (uuid, id) in fallbackCallIdByUuid where id == callId && !fallbackAnswered.contains(uuid) {
        NSLog("[voip] ending fallback card \(uuid.uuidString) for \(callId)")
        fallbackCallIdByUuid.removeValue(forKey: uuid)
        foregroundReportProvider.reportCall(
          with: uuid,
          endedAt: Date(),
          reason: reason == 4 ? .answeredElsewhere : .remoteEnded
        )
        ended += 1
      }
    }
    return ended
  }

  // ── Calls this device knows are over (see `deadCallsKey`) ──

  private func deadCalls() -> [String: Double] {
    let now = Date().timeIntervalSince1970
    let raw = UserDefaults.standard.dictionary(forKey: Self.deadCallsKey) as? [String: Double] ?? [:]
    return raw.filter { now - $0.value < Self.deadCallTtl }
  }

  private func markCallDead(_ callId: String) {
    guard !callId.isEmpty else { return }
    var dead = deadCalls()
    dead[callId] = Date().timeIntervalSince1970
    UserDefaults.standard.set(dead, forKey: Self.deadCallsKey)
  }

  private func isCallDead(_ callId: String) -> Bool {
    deadCalls()[callId] != nil
  }

  // Shows the CallKit ringer for an invite push, handling two failure modes
  // that used to silently drop calls (and accrue PushKit penalty — iOS
  // progressively stops delivering VoIP pushes to an app that doesn't
  // report a call for every push, which is exactly "locked phone never
  // rings"):
  //
  //   1. The old code called the plugin's 2-arg showCallkitIncoming and
  //      fired PushKit's completion() immediately, before
  //      reportNewIncomingCall had run. Use the completion-taking overload
  //      so iOS sees a fully reported call before we signal done.
  //   2. On a cold background launch (app killed + locked), this push
  //      handler can run BEFORE the implicit Flutter engine registers
  //      plugins — `sharedInstance` is nil and the old optional-chained
  //      call did nothing at all. Retry briefly; if the plugin never
  //      appears, ring on our own CXProvider so the phone still rings and
  //      the PushKit contract is honored.
  private func showIncomingWithRetry(
    _ callData: flutter_callkit_incoming.Data,
    convexCallId: String,
    attempt: Int = 0,
    pushCompletion: @escaping () -> Void
  ) {
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.showCallkitIncoming(callData, fromPushKit: true, completion: pushCompletion)
      return
    }
    // Plugin registration lands within a few hundred ms of process launch;
    // budget ~2s of retries, well inside PushKit's ~5s reporting deadline.
    if attempt < 20 {
      NSLog("[voip] plugin not registered yet — retry \(attempt)")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.showIncomingWithRetry(
          callData,
          convexCallId: convexCallId,
          attempt: attempt + 1,
          pushCompletion: pushCompletion
        )
      }
      return
    }
    // Last resort: a real ringing call on our own provider. Answer/decline
    // is bridged to Dart via the voip channel (see CXProviderDelegate).
    NSLog("[voip] plugin never registered — fallback provider ring")
    let uuid = UUID(uuidString: callData.uuid) ?? UUID()
    if !convexCallId.isEmpty {
      fallbackCallIdByUuid[uuid] = convexCallId
    }
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: callData.handle)
    update.localizedCallerName = callData.nameCaller
    update.hasVideo = callData.type > 0
    foregroundReportProvider.reportNewIncomingCall(with: uuid, update: update) { error in
      if let error = error {
        NSLog("[voip] fallback report failed: \(error.localizedDescription)")
      }
      pushCompletion()
    }
  }

  // Dismiss the CallKit session previously shown for this Convex callId
  // with `.answeredElsewhere`. The flutter_callkit_incoming plugin owns
  // the CXProvider that's actually showing the UI, so we go through
  // `saveEndCall(uuid, 4)` — reason 4 maps to .answeredElsewhere in
  // SwiftFlutterCallkitIncomingPlugin.saveEndCall.
  //
  // Apple's PushKit contract requires `reportNewIncomingCall` on every
  // push, so if we don't have a CallKit UUID for this callId yet (race:
  // taken push arrives before invite push processed), fall back to the
  // report-and-end escape hatch so iOS still sees a compliant report.
  private func reportCallEndedElsewhere(convexCallId: String) {
    // Resolve the CallKit UUID: in-memory map first, then the persisted
    // last-invite pair (this process may have been launched by the "taken"
    // push itself, after the invite's process died).
    var uuid = callKitUuidByCallId.removeValue(forKey: convexCallId)
    if uuid == nil,
       !convexCallId.isEmpty,
       UserDefaults.standard.string(forKey: Self.lastInviteCallIdKey) == convexCallId,
       let stored = UserDefaults.standard.string(forKey: Self.lastInviteUuidKey) {
      uuid = UUID(uuidString: stored)
    }
    if UserDefaults.standard.string(forKey: Self.lastInviteCallIdKey) == convexCallId {
      UserDefaults.standard.removeObject(forKey: Self.lastInviteCallIdKey)
      UserDefaults.standard.removeObject(forKey: Self.lastInviteUuidKey)
    }
    // The plugin's saveEndCall silently no-ops when its lazily-created
    // provider is nil (fresh process that never showed a call), which would
    // swallow this push without a compliant report. Only take that path
    // when the plugin is up AND still tracking this exact call.
    if let uuid = uuid,
       let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance,
       plugin.activeCalls().contains(where: {
         ($0["id"] as? String)?.uppercased() == uuid.uuidString.uppercased()
       }) {
      plugin.saveEndCall(uuid.uuidString, 4)
      return
    }
    // The card this device placed ITSELF. An outbound call never gets an
    // invite push, so it is never in `callKitUuidByCallId`; Dart showed it
    // under the id it derives from the callId (see derivedCallUuid). Without
    // this branch a `taken` for a live outgoing call fell through to the
    // escape hatch below and flashed a phantom incoming "Call" over the real
    // card. `.remoteEnded` (reason 2): the other side hung up on us.
    if !convexCallId.isEmpty,
       let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      let derived = Self.derivedCallUuid(convexCallId).uuidString
      if plugin.activeCalls().contains(where: {
        ($0["id"] as? String)?.uppercased() == derived.uppercased()
      }) {
        NSLog("[voip] taken push — ending outbound card \(derived) for \(convexCallId)")
        plugin.saveEndCall(derived, 2)
        return
      }
    }
    // A fallback-provider card may be ringing for this call instead.
    if let entry = fallbackCallIdByUuid.first(where: { $0.value == convexCallId }) {
      fallbackCallIdByUuid.removeValue(forKey: entry.key)
      fallbackAnswered.remove(entry.key)
      foregroundReportProvider.reportCall(
        with: entry.key,
        endedAt: Date(),
        reason: .answeredElsewhere
      )
      return
    }
    // No CallKit session to target — Apple still wants a compliant
    // report-and-end for this push. Use the existing escape hatch. NOTE:
    // this is NOT invisible. On current iOS the placeholder call shows as a
    // one-second incoming "Call" that rings and vanishes, so the backend
    // only sends a PushKit `taken` where a card may sit in a killed process
    // (`calls.endCallImpl`, `iosVoip`) — reaching here should be rare.
    NSLog("[voip] taken push — no card for \(convexCallId); report-and-end placeholder")
    reportAndEndCall(callerName: "Call")
  }

  // The native id Dart mints for a call it shows itself —
  // `NativeCallHandler.derivedUuid`, a port of
  // `java.util.UUID.nameUUIDFromBytes` (MD5 of the callId with the
  // version-3 and IETF-variant bits patched in), which
  // `CallFcmService.uuidForCallId` computes on Android. On iOS that is the
  // OUTBOUND card (`showOutgoing`); invite pushes mint a random UUID and
  // record it in `callKitUuidByCallId` instead. test/call_native_uuid_test.dart
  // pins the vectors all three derivations must agree on; the sanity check
  // in `application(_:didFinishLaunchingWithOptions:)` asserts this one in
  // debug builds.
  static func derivedCallUuid(_ callId: String) -> UUID {
    var b = Array(Insecure.MD5.hash(data: Data(callId.utf8)))
    b[6] = (b[6] & 0x0f) | 0x30 // version 3 (name-based, MD5)
    b[8] = (b[8] & 0x3f) | 0x80 // IETF variant
    return UUID(uuid: (
      b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
      b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
    ))
  }

  // PushKit contract escape hatch: when we don't want to show CallKit
  // (e.g., app is already foregrounded and showing its own UI), we MUST
  // still report a call to a CXProvider and then immediately end it,
  // otherwise iOS terminates the process and can revoke the VoIP token.
  //
  // A single long-lived provider with a delegate set is what Apple's
  // CallKit programming guide requires. We previously used short-lived
  // providers with no delegate, which Apple appears to count as invalid
  // reports — after a handful of foreground pushes Apple revokes the
  // token and silently drops future VoIP pushes.
  private lazy var foregroundReportProvider: CXProvider = {
    let config = CXProviderConfiguration(localizedName: "Monkeyhub")
    // This provider does double duty: silent report-and-end (PushKit
    // compliance) AND the last-resort fallback RINGER in
    // showIncomingWithRetry. supportedHandleTypes defaults to an EMPTY
    // set, and reportNewIncomingCall with a .generic handle not in the
    // set errors out — which silently killed every fallback ring.
    config.supportedHandleTypes = [.generic]
    config.supportsVideo = true
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    let provider = CXProvider(configuration: config)
    provider.setDelegate(self, queue: nil)
    return provider
  }()

  private func reportAndEndCall(callerName: String) {
    let uuid = UUID()
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: callerName)
    foregroundReportProvider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      if let error = error {
        NSLog("[voip] reportAndEndCall: report failed: \(error.localizedDescription)")
      }
      // Safety-net end in case the synchronous end below raced the report
      // registering. Idempotent — ending an already-ended call is a no-op.
      self?.foregroundReportProvider.reportCall(
        with: uuid,
        endedAt: Date(),
        reason: .answeredElsewhere
      )
    }
    // End the call SYNCHRONOUSLY, in the same run-loop turn as the report,
    // so CallKit never actually presents a (nameless) incoming card. The
    // PushKit contract is satisfied — we did report an incoming call — but
    // the user sees nothing because it's already over. Marked
    // `.answeredElsewhere` with a real timestamp so iOS treats the VoIP push
    // as successfully handled and shows no missed-call notification.
    foregroundReportProvider.reportCall(
      with: uuid,
      endedAt: Date(),
      reason: .answeredElsewhere
    )
  }

  // Reads `aps-environment` ("development" | "production") from the embedded
  // provisioning profile and maps it to the APNs host Dart should tag the
  // PushKit token with ("sandbox" | "production"). This is the authoritative
  // source — a Release build signed with a development profile still issues a
  // *sandbox* token, which `kDebugMode` alone can't detect. Returns nil if the
  // profile is absent (e.g. App Store builds strip embedded.mobileprovision);
  // Dart then falls back to its build-mode heuristic.
  private func apnsEnvironment() -> String? {
    guard
      let url = Bundle.main.url(
        forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      let raw = String(data: data, encoding: .ascii)
    else {
      return nil
    }
    // The profile is CMS/PKCS7-wrapped; the embedded plist is plain XML in the
    // middle. Slice from <plist to </plist> and parse just that.
    guard
      let start = raw.range(of: "<plist"),
      let end = raw.range(of: "</plist>")
    else {
      return nil
    }
    let plistXml = String(raw[start.lowerBound..<end.upperBound])
    guard
      let plistData = plistXml.data(using: .utf8),
      let plist = try? PropertyListSerialization.propertyList(
        from: plistData, options: [], format: nil) as? [String: Any],
      let entitlements = plist["Entitlements"] as? [String: Any],
      let apsEnv = entitlements["aps-environment"] as? String
    else {
      return nil
    }
    return apsEnv == "production" ? "production" : "sandbox"
  }

  // MARK: - CXProviderDelegate
  // Apple requires a delegate on every CXProvider. This provider normally
  // only does report-and-end (no user interaction possible), but it also
  // hosts the last-resort fallback ringer from showIncomingWithRetry — so
  // answer/end must be honored and bridged to Dart.
  //
  // NOTE: the old code had `provider(_:perform action: CXAction)`, which is
  // NOT a CXProviderDelegate method — CallKit never called it. The
  // per-action methods below are the real ones.

  func providerDidReset(_ provider: CXProvider) {
    fallbackCallIdByUuid.removeAll()
    fallbackAnswered.removeAll()
    // A provider reset means the system tore down every call UI — without
    // telling Dart, the WebRTC session (and the microphone) lived on
    // headless. Dart answers with a full local teardown.
    invokeVoipOrQueue("onProviderReset", args: [:])
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    if let callId = fallbackCallIdByUuid[action.callUUID] {
      NSLog("[voip] fallback card answered callId=\(callId)")
      fallbackAnswered.insert(action.callUUID)
      CallAudioRouter.shared.markLive()
      invokeVoipOrQueue("onFallbackAnswer", args: ["callId": callId])
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    fallbackAnswered.remove(action.callUUID)
    if let callId = fallbackCallIdByUuid.removeValue(forKey: action.callUUID) {
      NSLog("[voip] fallback card declined/ended callId=\(callId)")
      invokeVoipOrQueue("onFallbackDecline", args: ["callId": callId])
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    action.fulfill()
  }

  // The fallback ringer's answer activates the session through THIS
  // provider, which the callkit plugin never sees. Re-apply the call's
  // audio here so its category/route match what the plugin path gets.
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    CallAudioRouter.shared.reassert(isVideo: nil)
  }

  // Delivers a voip-channel call to Dart, or queues it until Dart's handler
  // is provably installed — a fallback-card answer on a cold background
  // launch fires before any Dart exists and must not be lost. (Merely
  // having `voipChannel` set isn't enough: an invokeMethod that races
  // Dart's setMethodCallHandler is silently dropped.)
  private func invokeVoipOrQueue(_ method: String, args: [String: Any]) {
    if voipDartReady, let channel = voipChannel {
      channel.invokeMethod(method, arguments: args)
    } else {
      pendingVoipEvents.append((method: method, args: args))
    }
  }

  // Same contract for the notifications channel. The token arrives moments
  // after launch and a lock-screen tap can BE the launch, both of them well
  // before Dart has a handler.
  private func invokeNotifOrQueue(_ method: String, args: [String: Any]) {
    if notifDartReady, let channel = notifChannel {
      channel.invokeMethod(method, arguments: args)
    } else {
      pendingNotifEvents.append((method: method, args: args))
    }
  }

  /// Keeps the process awake until Dart's `away` write is acknowledged.
  ///
  /// Locking the phone backgrounds the app and iOS suspends it moments later.
  /// Dart's `away` went out fire-and-forget from the lifecycle change, and on
  /// a lock it routinely did not make it: the socket froze with the mutation
  /// still queued, the stored status stayed `online`, and the person read as
  /// online until the staleness sweep caught up, up to about four minutes
  /// with the phone locked on a charger. A background task is what buys the
  /// round-trip; Dart answers `didEnterBackground` once the server has acked
  /// (or its own deadline passes), and that reply ends the task.
  ///
  /// Started here, synchronously in the notification, rather than asked for
  /// by Dart: by the time a channel call from Dart arrived the suspension it
  /// exists to postpone may already be under way. The 8s cap is a backstop
  /// for a reply that never comes; Dart gives up well before it.
  @objc private func _holdPresenceAway() {
    guard let channel = presenceChannel else { return }
    endPresenceHold()
    presenceHold = UIApplication.shared.beginBackgroundTask(withName: "presence-away") {
      [weak self] in self?.endPresenceHold()
    }
    let hold = presenceHold
    channel.invokeMethod("didEnterBackground", arguments: nil) { [weak self] _ in
      if self?.presenceHold == hold { self?.endPresenceHold() }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
      if self?.presenceHold == hold { self?.endPresenceHold() }
    }
  }

  private func endPresenceHold() {
    guard presenceHold != .invalid else { return }
    UIApplication.shared.endBackgroundTask(presenceHold)
    presenceHold = .invalid
  }

  /// Collects whatever the Share Extension has staged and hands it to Dart.
  ///
  /// Called at launch and on every return to the foreground. Cheap when there
  /// is nothing there, which is almost always.
  @objc private func _drainShareInbox() {
    let payloads = ShareInbox.drain()
    guard !payloads.isEmpty else { return }
    if shareDartReady, let channel = shareChannel {
      // One at a time. Placing a share opens a chat, and Dart cannot be in two
      // at once; the rest wait for the next `takePendingShare`.
      channel.invokeMethod("onShare", arguments: payloads[0])
      pendingShares.append(contentsOf: payloads.dropFirst())
    } else {
      pendingShares.append(contentsOf: payloads)
    }
  }

  /// Tells iOS the user just messaged this chat.
  ///
  /// A donated `INSendMessageIntent` is how a conversation earns its place in
  /// the share sheet's top row: iOS keeps the history and ranks by recency and
  /// frequency, so this is called on every send rather than on a schedule.
  ///
  /// `conversationIdentifier` is the load-bearing field. It is the room id, and
  /// it is what comes back on `extensionContext.intent` when the suggestion is
  /// tapped — the only reason a share can arrive already knowing where it is
  /// going. See ShareViewController.
  ///
  /// Three things must agree or no suggestion ever appears, and not one of them
  /// fails loudly: this donation, `IntentsSupported` in the extension's
  /// Info.plist, and `NSUserActivityTypes` in this app's.
  private func donateSendMessage(_ args: [String: Any]) {
    guard let roomId = args["id"] as? String, !roomId.isEmpty else { return }
    let title = (args["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? roomId
    let isGroup = (args["isGroup"] as? Bool) == true
    let image = shareTargetImage(args)

    let recipient = INPerson(
      personHandle: INPersonHandle(value: roomId, type: .unknown),
      nameComponents: nil,
      displayName: title,
      image: image,
      contactIdentifier: nil,
      // Ties every send to this room to one identity. Without a stable
      // identifier iOS treats each send as a new person and ranks none of them
      // highly enough to offer.
      customIdentifier: roomId
    )

    let intent = INSendMessageIntent(
      recipients: [recipient],
      outgoingMessageType: .outgoingMessageText,
      content: nil,
      speakableGroupName: isGroup ? INSpeakableString(spokenPhrase: title) : nil,
      conversationIdentifier: roomId,
      serviceName: nil,
      sender: nil,
      attachments: nil
    )
    // A group has no single person to draw, so the picture hangs off the group
    // name instead. Setting it on a 1:1 intent would be ignored — there the
    // recipient's own INImage above is what gets rendered.
    if isGroup, let image {
      intent.setImage(image, forParameterNamed: \.speakableGroupName)
    }

    let interaction = INInteraction(intent: intent, response: nil)
    // Groups every send to this room under one identity, so a re-donation
    // updates the existing suggestion (new name, new avatar) rather than
    // stacking a second one beside it.
    interaction.groupIdentifier = roomId
    interaction.direction = .outgoing
    interaction.donate { error in
      if let error {
        NSLog("[share] donation failed: \(error.localizedDescription)")
      }
    }
  }

  /// The avatar for a donated conversation.
  ///
  /// `INImage(url:)` is lazy: the read happens when the system renders the
  /// suggestion, which is where that work belongs and not on a send. A missing
  /// or unreachable URL yields nil and iOS draws its own initial — the same
  /// fallback the app's own avatars use.
  private func shareTargetImage(_ args: [String: Any]) -> INImage? {
    guard
      let raw = args["avatarUrl"] as? String,
      !raw.isEmpty,
      let url = URL(string: raw)
    else { return nil }
    return INImage(url: url)
  }

  @objc private func _capturedDidChange() {
    captureEventSink?(UIScreen.main.isCaptured)
  }

  /// Kept alive for the process. `QLPreviewController` holds its data source
  /// weakly, so a previewer that is only referenced by the controller is one
  /// that shows an empty document as soon as ARC gets to it.
  private var documentPreview: DocumentPreview?

  // Registers the app's custom method channels on the pre-warmed engine.
  // Called from didFinishLaunchingWithOptions right after
  // GeneratedPluginRegistrant (which registers the third-party plugins).
  /// The user's brightness while the video-note flash holds it at full.
  private var brightnessBeforeFlash: CGFloat?

  private func allowHapticsWhileRecording() {
    do {
      try AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
    } catch {
      NSLog("[haptics] allowHapticsAndSystemSoundsDuringRecording failed: \(error)")
    }
  }

  private func registerAppChannels(on engine: FlutterEngine) {
    // monkeyhub/phone_call — any call ringing or live on this phone, ours or
    // the carrier's. A daily game's clock stops on it.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubPhoneCallPlugin") {
      phoneCallActivity.attach(
        FlutterMethodChannel(
          name: "monkeyhub/phone_call",
          binaryMessenger: registrar.messenger()
        )
      )
    }

    // monkeyhub/haptics — iOS mutes the Taptic Engine while the microphone
    // records unless the session opts in, so every haptic of a voice or video
    // note (lock, slide-to-cancel, send) went silent. Opted in at launch, and
    // again by Dart once a recorder has started: the record and camera plugins
    // reconfigure the shared session when they start.
    allowHapticsWhileRecording()
    if let hapticsRegistrar = engine.registrar(forPlugin: "MonkeyHubHapticsPlugin") {
      FlutterMethodChannel(
        name: "monkeyhub/haptics",
        binaryMessenger: hapticsRegistrar.messenger()
      ).setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "allowDuringRecording":
          self?.allowHapticsWhileRecording()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/screen — the front camera's "flash" for a video note is the
    // screen itself, white; it only lights a face at full brightness. The
    // user's own brightness is remembered and handed back when it goes off.
    if let screenRegistrar = engine.registrar(forPlugin: "MonkeyHubScreenPlugin") {
      FlutterMethodChannel(
        name: "monkeyhub/screen",
        binaryMessenger: screenRegistrar.messenger()
      ).setMethodCallHandler { [weak self] call, result in
        guard call.method == "setFlashBrightness" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let on = ((call.arguments as? [String: Any])?["on"] as? Bool) ?? false
        DispatchQueue.main.async {
          if on {
            if self?.brightnessBeforeFlash == nil {
              self?.brightnessBeforeFlash = UIScreen.main.brightness
            }
            UIScreen.main.brightness = 1.0
          } else if let before = self?.brightnessBeforeFlash {
            UIScreen.main.brightness = before
            self?.brightnessBeforeFlash = nil
          }
          result(nil)
        }
      }
    }

    // monkeyhub/capture — screen-capture/mirroring observation.
    if let captureRegistrar = engine.registrar(forPlugin: "MonkeyHubCapturePlugin") {
      // Method channel: returns current isCaptured state on demand.
      let captureMethods = FlutterMethodChannel(
        name: "monkeyhub/capture",
        binaryMessenger: captureRegistrar.messenger()
      )
      captureMethods.setMethodCallHandler { call, result in
        switch call.method {
        case "isCaptured":
          result(UIScreen.main.isCaptured)
        case "setEnabled":
          // The secure-field layer (CaptureGuard in SceneDelegate.swift)
          // blanks the window in screenshots, recordings and mirroring. The
          // event channel below still drives the recording overlay, for an
          // iOS where the guard could not install.
          let enabled = ((call.arguments as? [String: Any])?["enabled"] as? Bool) ?? false
          CaptureGuard.shared.setEnabled(enabled)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      // Event channel: pushes a bool every time UIScreen.isCaptured changes.
      let captureEvents = FlutterEventChannel(
        name: "monkeyhub/capture/events",
        binaryMessenger: captureRegistrar.messenger()
      )
      captureEvents.setStreamHandler(_CaptureStreamHandler(appDelegate: self))
    }

    // monkeyhub/screen_share — whether this build can share the screen: the
    // Broadcast Upload Extension flutter_webrtc's capturer hands the system
    // picker must actually be in the bundle, or the picker offers nothing and
    // the share button would be a button that does nothing. Android's half of
    // this channel starts a foreground service; iOS needs none.
    if let shareRegistrar = engine.registrar(forPlugin: "MonkeyHubScreenSharePlugin") {
      let shareChannel = FlutterMethodChannel(
        name: "monkeyhub/screen_share",
        binaryMessenger: shareRegistrar.messenger()
      )
      screenShareChannel = shareChannel
      installBroadcastObservers()
      shareChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "isSupported":
          #if targetEnvironment(simulator)
          // The Simulator never presents the broadcast picker: a Share
          // button there sat on "Starting…" until the start wait ran out.
          result(false)
          return
          #endif
          guard let ext = Bundle.main.object(forInfoDictionaryKey: "RTCScreenSharingExtension") as? String,
                !ext.isEmpty,
                let plugins = Bundle.main.builtInPlugInsURL,
                let contents = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)
          else {
            result(false)
            return
          }
          let present = contents.contains { url in
            Bundle(url: url)?.bundleIdentifier == ext
          }
          result(present)
        case "start", "stop":
          // Android's foreground service; nothing to do here.
          result(nil)
        case "endBroadcast":
          // The extension observes this and ends the broadcast at once
          // (SampleHandler.swift), so the red status-bar pill goes the
          // moment the user stops sharing in the app.
          CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(Self.broadcastStopRequestName as CFString),
            nil, nil, true
          )
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/draw_mirror — the strokes over our shared screen, carried
    // into a Picture in Picture board once the app leaves the screen. See
    // DrawPip.swift.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubDrawMirrorPlugin") {
      DrawPip.shared.register(messenger: registrar.messenger())
    }

    // monkeyhub/call_pip — the video call's Picture in Picture window, which
    // is also what lets the camera keep running once the app leaves the
    // screen. See CallPip.swift.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubCallPipPlugin") {
      CallPip.shared.register(messenger: registrar.messenger())
    }

    // monkeyhub/launcher_icon — swap the home-screen launcher icon at runtime.
    // Backs LauncherIconService in Dart. We talk to UIApplication directly
    // here because flutter_dynamic_icon_plus's Swift wrapper (SwiftTryCatch)
    // collides with Swift's reserved `try` keyword under modern compilers.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubLauncherIconPlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/launcher_icon",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "supportsAlternateIcons":
          if #available(iOS 10.3, *) {
            result(UIApplication.shared.supportsAlternateIcons)
          } else {
            result(false)
          }
        case "getAlternateIconName":
          if #available(iOS 10.3, *) {
            result(UIApplication.shared.alternateIconName)
          } else {
            result(nil)
          }
        case "setAlternateIconName":
          guard #available(iOS 10.3, *) else {
            result(nil)
            return
          }
          let args = call.arguments as? [String: Any] ?? [:]
          let iconName = args["iconName"] as? String  // nil → primary icon
          DispatchQueue.main.async {
            NSLog("[launcher_icon] setAlternateIconName(\(iconName ?? "<nil/primary>")) — supportsAlternateIcons=\(UIApplication.shared.supportsAlternateIcons)")
            UIApplication.shared.setAlternateIconName(iconName) { error in
              if let error = error as NSError? {
                NSLog("[launcher_icon] FAIL name=\(iconName ?? "<nil>") domain=\(error.domain) code=\(error.code) msg=\(error.localizedDescription) userInfo=\(error.userInfo)")
                result(FlutterError(
                  code: "set_failed",
                  message: "\(error.domain)#\(error.code): \(error.localizedDescription)",
                  details: ["userInfo": "\(error.userInfo)"]
                ))
              } else {
                NSLog("[launcher_icon] OK name=\(iconName ?? "<nil/primary>")")
                result(nil)
              }
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let registrar = engine.registrar(forPlugin: "MonkeyHubPresencePlugin") {
      presenceChannel = FlutterMethodChannel(
        name: "monkeyhub/presence",
        binaryMessenger: registrar.messenger()
      )
    }

    // monkeyhub/device — exposes a human-readable name for this physical
    // device. Dart uploads it alongside push tokens so the active-call
    // pill on sibling devices can render "On Bob's iPhone".
    if let registrar = engine.registrar(forPlugin: "MonkeyHubDevicePlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/device",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getDisplayName":
          // iOS 16+ returns the model name ("iPhone") rather than the
          // user-set device name for privacy. Pre-16 still returns the
          // user's name. Either way, this is the best handle we have
          // server-side without entitlements.
          result(UIDevice.current.name)
        case "getBuildInfo":
          // The iOS half of the diagnostics header, mirroring the Android
          // handler's keys so `DeviceReport` needs no per-platform branch.
          // Read once per launch; never on a hot path.
          //
          // Before this existed the header rendered "Device: — · —" and
          // "System: ios —" on every iPhone, because `release`, `model` and
          // `manufacturer` were only ever produced by the Android side.
          var info: [String: Any?] = [:]
          info["manufacturer"] = "Apple"
          info["release"] = UIDevice.current.systemVersion
          // "iOS" or "iPadOS" — more specific than Dart's
          // `Platform.operatingSystem`, which says "ios" for both.
          info["osName"] = UIDevice.current.systemName
          // The machine identifier ("iPhone15,3"), not a marketing name. A
          // triager wants the identifier — it names one SoC and one panel,
          // and unlike a lookup table of marketing names it cannot go stale.
          // On the simulator `utsname` reports the host arch, so the real
          // identifier comes from the environment instead.
          info["model"] = {
            if let simulated = ProcessInfo.processInfo
              .environment["SIMULATOR_MODEL_IDENTIFIER"] {
              return "\(simulated) (simulator)"
            }
            var system = utsname()
            uname(&system)
            let machine = withUnsafePointer(to: &system.machine) {
              $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
              }
            }
            return machine.isEmpty ? UIDevice.current.model : machine
          }()
          // Same standing suspects as the Android side: a throttled process
          // and a variable-refresh panel look identical from Dart.
          info["powerSaveMode"] = ProcessInfo.processInfo.isLowPowerModeEnabled
          info["refreshRate"] = UIScreen.main.maximumFramesPerSecond
          result(info)
        case "getDiskSpace":
          // For Data and Storage's "uses N% of your free space". The
          // important-usage figure is what iOS Settings shows as available:
          // it counts space the system would purge for a user-initiated save.
          let home = URL(fileURLWithPath: NSHomeDirectory())
          let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
          ])
          result([
            "free": NSNumber(value: values?.volumeAvailableCapacityForImportantUsage ?? 0),
            "total": NSNumber(value: values?.volumeTotalCapacity ?? 0),
          ])
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/call_audio — native to Dart only: the call's REAL output
    // route, pushed on every AVAudioSession route change while a call holds
    // the session (headphones in/out, AirPods, the CallKit or Control Center
    // speaker button), so the speaker button follows the sound. Installing
    // the router here also takes over the callkit plugin's own
    // configureAudioSession (vendored PATCH A), before any VoIP push can ring.
    if let callAudioRegistrar = engine.registrar(forPlugin: "MonkeyHubCallAudioPlugin") {
      CallAudioRouter.shared.install(
        channel: FlutterMethodChannel(
          name: "monkeyhub/call_audio",
          binaryMessenger: callAudioRegistrar.messenger()
        )
      )
    }

    // monkeyhub/voip — exposes the PushKit VoIP token to Dart. Dart calls
    // `getToken` after PushManager.login(userId) and uploads the result to
    // Convex's setVoipToken mutation. We also push token updates over the
    // same channel via `onTokenUpdated` so token rotation propagates.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubVoipPlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/voip",
        binaryMessenger: registrar.messenger()
      )
      voipChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getToken":
          result(self?.cachedVoipToken)
        case "takePendingEvents":
          // Dart's handler is installed (it just called us) — hand over any
          // fallback-card actions queued before it existed, and switch to
          // direct delivery for future ones.
          if let self = self {
            self.voipDartReady = true
            let events = self.pendingVoipEvents.map { event -> [String: Any] in
              var e = event.args
              e["method"] = event.method
              return e
            }
            self.pendingVoipEvents.removeAll()
            result(events)
          } else {
            result([])
          }
        case "callOver":
          // Dart learned this 1:1 call is over (a terminal signal, the ring
          // watch, a teardown). Remember it, so an invite push that lands
          // later reports-and-ends instead of ringing, and end its ringing
          // card here by the card's real UUID: the PushKit card's id is
          // minted in this file, and Dart only ever had a guess at it.
          // Answers how many cards it ended. Answered/outgoing cards are left
          // to the plugin's endCall, which Dart still issues.
          let args = call.arguments as? [String: Any] ?? [:]
          guard let self = self,
                let callId = args["callId"] as? String,
                !callId.isEmpty
          else {
            result(0)
            return
          }
          self.markCallDead(callId)
          self.stopRingWatch(callId, why: "Dart says call over")
          let ended = self.endRingingCards(callId: callId, reason: 2, includeFallback: true)
          NSLog("[voip] callOver \(callId) — ended \(ended) ringing card(s)")
          result(ended)
        case "cardLive":
          // The basis of Dart's dismissal ack: is any card for this call (1:1
          // or group) still up here, by the plugin's own record and the
          // cards' real UUIDs, an invite mid-report counting as up.
          let args = call.arguments as? [String: Any] ?? [:]
          guard let self = self,
                let callId = args["callId"] as? String,
                !callId.isEmpty
          else {
            result(true)
            return
          }
          let live = self.cardLive(callId)
          NSLog("[voip] cardLive \(callId) = \(live)")
          result(live)
        case "endFallbackCalls":
          // Dart-side call teardown: dismiss any card still ringing on the
          // fallback provider (the plugin's endAllCalls can't reach it).
          if let self = self {
            for (uuid, _) in self.fallbackCallIdByUuid {
              self.foregroundReportProvider.reportCall(
                with: uuid,
                endedAt: Date(),
                reason: .remoteEnded
              )
            }
            self.fallbackCallIdByUuid.removeAll()
            self.fallbackAnswered.removeAll()
          }
          result(nil)
        case "applyCallAudio":
          // One native pass for the call's audio category, mode and output
          // route, off the main thread. Answers the speaker side it actually
          // applied (a connected headset can win). See [CallAudioRouter].
          let args = call.arguments as? [String: Any] ?? [:]
          CallAudioRouter.shared.apply(
            video: args["video"] as? Bool ?? false,
            speaker: args["speaker"] as? Bool ?? false,
            headsetWins: args["headsetWins"] as? Bool ?? false,
            callId: args["callId"] as? String
          ) { applied in result(applied) }
        case "callAudioRoutes":
          // The in-call route sheet's opening state: the same map
          // `routeChanged` pushes (output, portName, routes), read on the
          // router's queue since listing the inputs can block.
          CallAudioRouter.shared.currentRoutes { state in result(state) }
        case "selectCallAudioInput":
          // The route sheet picked AirPods, a wired headset, a car or the
          // phone itself: that port's mic as the preferred input, which
          // takes the output with it during a call. Nil/empty: the
          // system's own choice. The speaker side goes through
          // applyCallAudio first. Answers whether the port was found.
          let args = call.arguments as? [String: Any] ?? [:]
          let uid = (args["uid"] as? String).flatMap { $0.isEmpty ? nil : $0 }
          CallAudioRouter.shared.selectInput(uid: uid) { ok in result(ok) }
        case "callAudioState":
          // Diagnostics: the session as a tone about to play into it sees
          // it. Logged by Dart at ringback start.
          let session = AVAudioSession.sharedInstance()
          result([
            "category": session.category.rawValue,
            "mode": session.mode.rawValue,
            "options": session.categoryOptions.rawValue,
            "outputs": session.currentRoute.outputs.map { $0.portType.rawValue },
            "volume": session.outputVolume,
            "otherAudio": session.isOtherAudioPlaying,
            "silenceHint": session.secondaryAudioShouldBeSilencedHint,
            "calls": (SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []).count,
          ])
        case "deactivateAudioSession":
          // Belt to the vendored plugin's deactivate-on-end (PATCH 1 in
          // third_party/flutter_callkit_incoming): Dart calls this after
          // every local teardown. Strictly a no-op while ANY call UI is
          // alive — the plugin's cards or our fallback provider's — so it
          // can never yank the session out from under a real call. Covers
          // the activation orderings the plugin can't see (e.g. WebRTC
          // activated the raw session before any CallKit call existed, as
          // in group calls, which never raise a card at all).
          //
          // Also where the call gives the session back: [CallAudioRouter.release]
          // drops the speaker override and returns the category to
          // `.soloAmbient`, so other apps' audio resumes and this app's own
          // media playback isn't left stuck in `.playAndRecord`. Serialized
          // with the route writes on the router's queue.
          guard let self = self else {
            result(nil)
            return
          }
          let pluginBusy =
            !(SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []).isEmpty
          let args = call.arguments as? [String: Any] ?? [:]
          CallAudioRouter.shared.release(
            idle: !pluginBusy && self.fallbackCallIdByUuid.isEmpty,
            callId: args["callId"] as? String
          ) { result(nil) }
        case "getApnsEnvironment":
          // The PushKit token's environment is fixed by the embedded
          // provisioning profile's `aps-environment`, NOT by the Dart build
          // mode. Reading it here lets Dart tag the token correctly so the
          // backend rings the matching APNs host — a development-profiled
          // Release build (sandbox token) is no longer mis-tagged production.
          result(self?.apnsEnvironment())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/preview — QuickLook for a received document. Registered
    // through a plugin registrar for the same reason the badge below is: it
    // only needs a messenger, not the root view controller.
    if let previewRegistrar = engine.registrar(forPlugin: "MonkeyHubPreviewPlugin") {
      // Held for the process's life: the previewer is its own data source and
      // AppKit/UIKit keep only a weak reference to that.
      documentPreview = DocumentPreview.register(with: previewRegistrar.messenger())
    }

    // monkeyhub/cutout — lifts a photo's subject out for "make a sticker".
    if let cutoutRegistrar = engine.registrar(forPlugin: "MonkeyHubCutoutPlugin") {
      SubjectCutout.register(with: cutoutRegistrar.messenger())
    }

    // monkeyhub/video_shrink — re-encodes a video over the upload cap.
    if let shrinkRegistrar = engine.registrar(forPlugin: "MonkeyHubVideoShrinkPlugin") {
      VideoShrink.register(with: shrinkRegistrar.messenger())
    }

    // monkeyhub/installer — the App Store side of the update check: the
    // storefront to look the version up in, and the store page as a sheet.
    if let installerRegistrar = engine.registrar(forPlugin: "MonkeyHubInstallerPlugin") {
      InstallerEnvironment.register(with: installerRegistrar.messenger())
    }

    // monkeyhub/media_compose — joins and trims the segments of a paused
    // voice or video note.
    if let composeRegistrar = engine.registrar(forPlugin: "MonkeyHubMediaComposePlugin") {
      MediaCompose.register(with: composeRegistrar.messenger())
    }

    // monkeyhub/badge — set or clear the app icon badge count.
    // Register the channel via a plugin registrar so we get a binaryMessenger
    // without depending on the rootViewController being a FlutterViewController.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubBadgePlugin") {
      let badgeChannel = FlutterMethodChannel(
        name: "monkeyhub/badge",
        binaryMessenger: registrar.messenger()
      )
      badgeChannel.setMethodCallHandler { call, result in
        guard call.method == "set" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any] ?? [:]
        let count = (args["count"] as? Int) ?? 0
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
          DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
          }
        }
        result(nil)
      }
    }

    // monkeyhub/notifications — the whole alert-push surface Dart talks to:
    // the APNs token, the authorization prompt, which room is on screen, and
    // pulling already-delivered notifications back out of Notification Center.
    //
    // A delivered notification can only be removed from here. No server and no
    // provider can recall one once APNs has handed it over, which is why the
    // backend sends a silent push carrying the identifiers instead — matched
    // against what it set as `apns-collapse-id` (= messageId) and
    // `aps.thread-id` (= roomId).
    if let registrar = engine.registrar(forPlugin: "MonkeyHubNotificationsPlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/notifications",
        binaryMessenger: registrar.messenger()
      )
      notifChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        let args = call.arguments as? [String: Any] ?? [:]
        let center = UNUserNotificationCenter.current()
        switch call.method {
        case "dismiss":
          let ids = (args["ids"] as? [String]) ?? []
          if !ids.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: ids)
          }
          result(nil)
        case "dismissRoom":
          guard let roomId = args["roomId"] as? String else {
            result(nil)
            return
          }
          center.getDeliveredNotifications { delivered in
            let ids = delivered
              .filter { $0.request.content.threadIdentifier == roomId }
              .map { $0.request.identifier }
            if !ids.isEmpty {
              center.removeDeliveredNotifications(withIdentifiers: ids)
            }
            // getDeliveredNotifications answers off the main thread; hop back
            // before touching the Flutter channel.
            DispatchQueue.main.async { result(nil) }
          }

        case "getApnsToken":
          result(self?.cachedApnsToken)

        case "authorizationStatus":
          center.getNotificationSettings { settings in
            let value: String
            switch settings.authorizationStatus {
            case .notDetermined: value = "notDetermined"
            case .denied: value = "denied"
            case .provisional: value = "provisional"
            default: value = "granted"
            }
            DispatchQueue.main.async { result(value) }
          }

        case "requestAuthorization":
          center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
              NSLog("[apns] requestAuthorization failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { result(granted) }
          }

        case "setActiveRoom":
          // Pushed from Dart on room open/close so `willPresent` can decide
          // synchronously. Nil clears it.
          self?.activeRoomId = args["roomId"] as? String
          result(nil)

        case "takePendingEvents":
          // Dart's handler is installed (it just called us) — hand over the
          // token and any taps that fired before it existed, then switch to
          // direct delivery.
          if let self {
            self.notifDartReady = true
            let events = self.pendingNotifEvents.map { event -> [String: Any] in
              var e = event.args
              e["method"] = event.method
              return e
            }
            self.pendingNotifEvents.removeAll()
            result(events)
          } else {
            result([])
          }

        // The raw `data` maps of chat pushes the Notification Service
        // Extension has parked in the App Group, so a room can open already
        // showing the message rather than asking the network for something the
        // phone was just told. Written by a different process, possibly while
        // this one did not exist — see ShareGroup.stagePush.
        case "takePushInbox":
          result(ShareGroup.takePushInbox())

        case "clearPushInbox":
          ShareGroup.clearPushInbox()
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/share — the system share sheet, both directions.
    //
    // INBOUND: what the Share Extension staged in the App Group container. The
    // files are already on disk by the time anything crosses this channel, so
    // what travels is paths, never bytes.
    //
    // OUTBOUND: `touchTarget`, which donates an INSendMessageIntent — the whole
    // mechanism behind MonkeyHub's chats appearing in the sheet's top row. iOS
    // ranks the suggestions itself, by how recently and how often each
    // conversation was donated. There is no list to publish and no single
    // suggestion to remove, which is why `publishTargets` is a no-op here and
    // does all the work on Android.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubSharePlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/share",
        binaryMessenger: registrar.messenger()
      )
      shareChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "takePendingShare":
          guard let self else { result(nil); return }
          // Dart's handler is installed (it just called us), so everything
          // after this is delivered live.
          self.shareDartReady = true
          // One more drain first: a share can land between launch and the
          // moment the isolate is ready to hear about it.
          self.pendingShares.append(contentsOf: ShareInbox.drain())
          let next = self.pendingShares.isEmpty ? nil : self.pendingShares.removeFirst()
          result(next)

        case "touchTarget":
          self?.donateSendMessage(call.arguments as? [String: Any] ?? [:])
          result(nil)

        case "publishTargets":
          // iOS has no publishable suggestion list — the top row comes from
          // donations. But the same payload is exactly what the Share
          // Extension needs to send WITHOUT the app: the deployment URL, the
          // user id (which is this backend's whole credential — see
          // ConvexHTTP.swift) and the chats to offer. Stored in the App Group,
          // which is the only channel between the two binaries.
          ShareCache.store(call.arguments as? [String: Any] ?? [:])
          result(nil)

        case "clearTargets":
          // Signing out. The donations name people, so they cannot outlive the
          // session that could see them: this deletes every interaction this
          // app has donated, which is what stops the previous account's chats
          // being suggested to whoever signs in next on a shared handset.
          INInteraction.deleteAll { error in
            if let error {
              NSLog("[share] could not delete donations: \(error.localizedDescription)")
            }
          }
          // And the extension's copy, which is the one that could still SEND.
          // A chat list left behind is a privacy problem; a user id left behind
          // is an account somebody else could post as from the share sheet.
          ShareCache.clear()
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/video — play a video in AVPlayerViewController, the same
    // player Photos and Messages use, instead of re-inventing a transport bar
    // in Dart on top of a bare `video_player` texture. Backs NativeVideoPlayer.
    if let registrar = engine.registrar(forPlugin: "MonkeyHubVideoPlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/video",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "presentGallery" {
          self?.presentMediaGallery(call, channel: channel, result: result)
          return
        }
        guard call.method == "present" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any] ?? [:]
        guard let raw = args["url"] as? String, let url = URL(string: raw) else {
          result(false)
          return
        }
        let secure = (args["secure"] as? Bool) ?? false
        let shieldTitle = args["shieldTitle"] as? String
        let shieldBody = args["shieldBody"] as? String
        // Presentation is main-thread-only, and the channel handler is already
        // on it — the hop is for the case where it isn't (a background
        // isolate's messenger), not ceremony.
        DispatchQueue.main.async {
          guard let host = self?.topViewController() else {
            result(false)
            return
          }
          self?.prepareAudioSessionForPlayback()
          let controller = _VideoPlayerViewController()
          controller.player = AVPlayer(url: url)
          controller.modalPresentationStyle = .fullScreen
          // Set before presentation so a recording that is ALREADY running when
          // the video opens is caught by the initial check in viewDidLoad. The
          // notification only fires on a change, so a player presented into an
          // in-progress capture would otherwise start unshielded.
          controller.shieldsAgainstCapture = secure
          controller.shieldTitle = shieldTitle
          controller.shieldBody = shieldBody
          // The chat is already showing this video's poster; a second entrance
          // animation on top of the Flutter route's own fade reads as a stutter.
          host.present(controller, animated: false) {
            controller.player?.play()
            // Answered on presentation, not dismissal: Dart's only remaining
            // job is to pop the placeholder route underneath, and this view
            // controller outlives it.
            result(true)
          }
        }
      }
    }
  }

  /// monkeyhub/video `presentGallery`: the swipeable native gallery, every
  /// video in the system player's own page, photos as zoomable pages. Answers
  /// once it is on screen, like `present`, and reports the page it closed on
  /// back over the same channel (`galleryClosed`), so the Flutter screen
  /// underneath can land there too. Backs NativeVideoPlayer.presentGallery.
  private func presentMediaGallery(
    _ call: FlutterMethodCall,
    channel: FlutterMethodChannel,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any] ?? [:]
    let raw = args["items"] as? [[String: Any]] ?? []
    let items: [MediaGalleryItem] = raw.compactMap { m in
      guard let s = m["url"] as? String, let url = URL(string: s) else { return nil }
      let poster = (m["poster"] as? String).flatMap { URL(string: $0) }
      return MediaGalleryItem(isVideo: (m["kind"] as? String) == "video", url: url, poster: poster)
    }
    guard !items.isEmpty else {
      result(false)
      return
    }
    let start = min(max((args["index"] as? Int) ?? 0, 0), items.count - 1)
    DispatchQueue.main.async {
      guard let host = self.topViewController() else {
        result(false)
        return
      }
      self.prepareAudioSessionForPlayback()
      let gallery = MediaGalleryController(
        items: items, index: start, closeLabel: args["closeLabel"] as? String
      )
      gallery.onClose = { index in
        channel.invokeMethod("galleryClosed", arguments: index)
      }
      // No entrance animation, for the reason `present` gives: the Flutter
      // route underneath already faded the poster in.
      host.present(gallery, animated: false) {
        result(true)
      }
    }
  }

  /// The view controller anything modal has to be presented from — the deepest
  /// one currently on screen. Walks from the key window's root rather than
  /// `self.window`, which is nil in this app: a UIScene owns the window (see
  /// SceneDelegate), so UIApplicationDelegate never gets one.
  private func topViewController() -> UIViewController? {
    var root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
    if root == nil { root = window?.rootViewController }
    var top = root
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// Makes video audio audible through the ringer switch, the way Photos plays
  /// back — but ONLY when nothing is already holding the session for recording.
  ///
  /// That guard is the whole point. flutter_webrtc puts the session in
  /// `.playAndRecord` for the duration of a call, and stamping `.playback` over
  /// it kills the microphone for a call still in progress. A user who taps a
  /// video mid-call gets the silent-switch behaviour instead, which is a far
  /// cheaper thing to be wrong about than a one-way call. Once a call ends,
  /// [CallAudioRouter.release] hands the session back as `.soloAmbient`, so
  /// this guard only ever holds DURING a call.
  private func prepareAudioSessionForPlayback() {
    let session = AVAudioSession.sharedInstance()
    guard session.category != .playAndRecord else { return }
    do {
      try session.setCategory(.playback, mode: .moviePlayback)
      try session.setActive(true)
    } catch {
      // Non-fatal: the video still plays, just under whatever category the
      // session already had.
      NSLog("monkeyhub/video: audio session setup failed: \(error)")
    }
  }

  /// Silent-push entry point for server-driven notification removal.
  ///
  /// The backend sends `content_available: true` with no `contents` when a
  /// message is deleted or a room is read on another device, carrying the
  /// identifiers to pull. Nothing is displayed for these.
  ///
  /// Caveat worth knowing: iOS does not deliver silent pushes to a
  /// force-quit app, so a notification can outlive its message until the
  /// next launch. No API on any platform changes that.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Our custom keys arrive FLAT, as siblings of `aps` — the re-key to
    // [String: Any] is only because userInfo is typed [AnyHashable: Any].
    // APNs payload keys are always strings, so the cast holds; an empty
    // dictionary just falls through to super below.
    let data = (userInfo as? [String: Any]) ?? [:]

    guard (data["kind"] as? String) == "dismiss" else {
      super.application(
        application,
        didReceiveRemoteNotification: userInfo,
        fetchCompletionHandler: completionHandler
      )
      return
    }

    let center = UNUserNotificationCenter.current()
    // A JSON string rather than an array: FCM v1 only carries string values,
    // and one wire format across the platforms beats two. See
    // notifications.dismissAndSync.
    var ids: [String] = []
    if let raw = data["dismissIds"] as? String,
       let bytes = raw.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: bytes) as? [String] {
      ids = parsed
    }
    let roomId = (data["roomId"] as? String).flatMap { $0.isEmpty ? nil : $0 }

    // The badge rides as data on this push, because a background push may not
    // carry `aps.badge`. Applying it here keeps the icon honest even when the
    // dismissal itself can't be acted on.
    if let rawBadge = data["badge"], let count = Int("\(rawBadge)") {
      if #available(iOS 16.0, *) {
        center.setBadgeCount(count) { _ in }
      } else {
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = count
        }
      }
    }

    // Fast path: APNs makes `apns-collapse-id` the delivered notification's
    // identifier, so removing by messageId usually just works.
    if !ids.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // …and then the same job again the hard way, because "usually" is doing a
    // lot of work in that sentence. The identifier is assigned by iOS from a
    // header we set; it is not a value we control, and if the mapping ever
    // fails to hold the removal above silently no-ops — a deleted message's
    // banner just sits there. The messageId inside the payload IS ours and
    // cannot drift, so sweeping on it is immune to that.
    //
    // One enumeration covers both this and the room-level sweep (sent when the
    // user reads the room on another device). getDeliveredNotifications is
    // asynchronous, so the completion handler is resolved inside it — resolve
    // it earlier and iOS can suspend us mid-removal.
    let wanted = Set(ids)
    center.getDeliveredNotifications { delivered in
      var doomed: [String] = []
      for n in delivered {
        let info = n.request.content.userInfo
        if let mid = info["messageId"] as? String, wanted.contains(mid) {
          doomed.append(n.request.identifier)
          continue
        }
        if wanted.isEmpty,
           let roomId,
           n.request.content.threadIdentifier == roomId {
          doomed.append(n.request.identifier)
        }
      }
      if !doomed.isEmpty {
        center.removeDeliveredNotifications(withIdentifiers: doomed)
      }
      // Deliberately left in. This handler runs in the background where no
      // debugger is attached, and "did the dismiss push arrive at all" is
      // otherwise unanswerable from a device.
      NSLog(
        "[apns] dismiss: ids=\(ids.count) room=\(roomId ?? "-") delivered=\(delivered.count) removed=\(doomed.count)"
      )
      completionHandler(.newData)
    }
  }
}

/// The one writer of a call's AVAudioSession: category, mode, output route,
/// and handing the session back when the call is over.
///
/// Three things used to write the session during a call, and they fought:
///   - Dart, through `applyCallAudio` (lib/calls/call_media.dart).
///   - The callkit plugin's `configureAudioSession`, at ring, dial, answer,
///     1.2 s after answer, and at every CallKit `didActivate`: playAndRecord
///     with NO `defaultToSpeaker`, the per-call mode (`videoChat` for video,
///     which force-sets `defaultToSpeaker`), and a 44.1 kHz preferred sample
///     rate. Changing the category drops any speaker override, so each pass
///     moved the sound (speaker to earpiece, or a video call's earpiece back
///     to the speaker) until Dart's reassert arrived a round trip later, and
///     the sample-rate write made WebRTC restart its audio unit.
///   - WebRTC, which re-applies `RTCAudioSessionConfiguration.webRTC()`
///     whenever its audio unit starts.
///   - flutter_webrtc 1.4.1's `ensureAudioSession` (getUserMedia, addTrack,
///     a remote audio track): when the category isn't playAndRecord yet it
///     rewrites WebRTC's configuration WITHOUT `defaultToSpeaker`, and the
///     audio unit then starts on it. Dart applies before getUserMedia, so
///     the category already is playAndRecord there; and as the backstop
///     this router listens as an `RTCAudioSessionDelegate` and re-applies
///     ours whenever WebRTC's audio unit starts.
/// Now the plugin calls [reassert] instead (vendored PATCH A), WebRTC's
/// configuration is kept equal to ours, and Dart's requests land here.
///
/// Product rules (iMessage/FaceTime): voice on the earpiece, video on the
/// loudspeaker, and a connected headset (AirPods, Bluetooth, wired, car)
/// wins over the kind's default. Only an explicit tap on the speaker button
/// overrides a headset. The real route is pushed to Dart on every route
/// change ([routeChanged]) so the speaker button follows the sound, whoever
/// moved it. Logs are prefixed `[call-audio]`.
///
/// Also owns the two screen behaviours a call needs: the idle timer is off
/// while a call holds the session, and the proximity sensor blanks the
/// screen only while the sound is on the earpiece (held to the ear), never
/// on the speaker or a headset.
///
/// Why not WebRTC's manual-audio CallKit mode (`useManualAudio`, enabling
/// audio only in `didActivate`): calls without a CallKit card (group calls
/// joined in-app, the simulator, the fallback ringer's answer) would need
/// their own enable on every path, and a missed one is a silent call. The
/// plugin's interruption-ended post at `didActivate` plus Dart's mic
/// re-prime already restart the unit against the activated session.
final class CallAudioRouter: NSObject, RTCAudioSessionDelegate {
  static let shared = CallAudioRouter()

  /// Serial, so session writes land in order, off the main thread (Flutter
  /// draws there; a live voice unit can block a write for tens of ms).
  private let queue = DispatchQueue(label: "monkeyhub.call-audio", qos: .userInitiated)

  /// Guards the desired state below. Never held across a session write, so
  /// the main thread (CallKit callbacks) only ever waits microseconds.
  private let lock = NSLock()
  /// A call holds the session: Dart applied, or a CallKit ring/dial seeded it.
  private var claimed = false
  /// Dart applied and has not released yet.
  private var dartClaimed = false
  /// Dart released while a CallKit card was still up; restore when it goes.
  private var releasePending = false
  /// The call is really live here: Dart applied, or a card was answered or
  /// a dial began. Only then does the screen act like a call (idle timer
  /// off, proximity sensor): a phone that is only ringing keeps its normal
  /// screen. Cleared by [restore].
  private var live = false
  private var video = false
  private var speaker = false
  /// Bumped by every claim: an apply, a seed, an answer or a dial. A
  /// release or an idle hook captures it when it is ASKED, and [restore]
  /// aborts if it moved by the time the queue runs it: a newer call's claim
  /// landed in between, and that call's session is not this teardown's.
  private var claimGen: UInt64 = 0
  /// The call Dart last applied for (1:1 callId or groupCallId), nil when
  /// Dart holds nothing or an older Dart sent no id. A release naming a
  /// different call is a previous call's teardown belt landing on a redial.
  private var owner: String?
  /// When Dart last applied. Only for a release with no call id (an older
  /// Dart): one inside [staleReleaseWindow] of an apply is taken for a
  /// previous call's teardown belt landing on a redial.
  private var lastApply = Date.distantPast
  private static let staleReleaseWindow: TimeInterval = 2.5
  /// When this router last wrote the session. A route change within
  /// [echoWindow] of it is most likely our own write echoing back.
  private var lastWrite = Date.distantPast
  private static let echoWindow: TimeInterval = 0.5
  /// The input port the in-app route sheet picked (its UID), nil for the
  /// system's choice. During a call iOS moves a Bluetooth or wired
  /// headset's output with its mic, so the preferred input IS the route
  /// pick: AirPods, a car, or the phone's own mic for "iPhone" with AirPods
  /// still connected. The speaker side stays the override's
  /// ([speaker]), so this coexists with headset-wins: a headset that
  /// connects later clears it ([routeChanged]), as does the call ending.
  private var preferredInputUID: String?
  /// The pick is the phone's own mic ("iPhone" with a headset still
  /// connected). The category then leaves out `.allowBluetoothA2DP`: with
  /// it, iOS keeps the OUTPUT on the headset's A2DP side once its HFP mic
  /// is let go, so the sound stayed in the AirPods, the mic moved to the
  /// phone, and the AirPods row stayed checked with no way back. Without
  /// A2DP the only Bluetooth route is HFP, which moves both directions
  /// together, so the phone's mic brings the earpiece with it.
  private var phonePinned = false
  /// The headset inputs present when the pick was made. A `newDevice`
  /// route change clears the pick only for a headset NOT among them: one
  /// that really connected after it. A pick's own hand-over (the AirPods'
  /// profile re-registering as the route leaves them) reported as
  /// `newDevice` used to clear it and put the sound straight back.
  private var pickInputs: Set<String> = []

  /// Main-thread only.
  private var channel: FlutterMethodChannel?
  private var installed = false

  private override init() { super.init() }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  /// Called once from AppDelegate at launch, before any VoIP push rings.
  func install(channel: FlutterMethodChannel) {
    self.channel = channel
    guard !installed else { return }
    installed = true
    // UIKit, so read here on main once; [routes] runs on the queue.
    Self.receiverName =
      UIDevice.current.userInterfaceIdiom == .phone ? UIDevice.current.model : nil
    let center = NotificationCenter.default
    center.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil
    ) { [weak self] note in
      let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
      self?.routeChanged(AVAudioSession.RouteChangeReason(rawValue: raw) ?? .unknown)
    }
    // mediaserverd restarted: every session setting is gone.
    center.addObserver(
      forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil
    ) { [weak self] _ in
      self?.reassert(isVideo: nil)
    }
    RTCAudioSession.sharedInstance().add(self)
    SwiftFlutterCallkitIncomingPlugin.callAudioConfigurator = { [weak self] isVideo in
      guard let self = self else { return false }
      self.reassert(isVideo: isVideo)
      return true
    }
    SwiftFlutterCallkitIncomingPlugin.audioSessionIdleHandler = { [weak self] in
      self?.restoreIfReleased()
    }
    SwiftFlutterCallkitIncomingPlugin.callAudioLive = { [weak self] in
      self?.markLive()
    }
  }

  /// A card was answered or a dial began (the plugin's, or the fallback
  /// provider's answer): the call is live, and a claim of its own. The
  /// configure that follows writes the session and turns the screen's call
  /// behaviour on.
  func markLive() {
    let wasClaimed: Bool = locked {
      self.live = true
      self.claimGen &+= 1
      return self.claimed
    }
    NSLog("[call-audio] live (claimed=\(wasClaimed))")
    guard wasClaimed else { return }
    queue.async {
      self.updateScreen(inCall: true, earpiece: Self.onEarpiece(AVAudioSession.sharedInstance()))
    }
  }

  /// Dart's request. [headsetWins] is true when [speaker] is only the call
  /// kind's default (or the camera's): a connected headset then keeps the
  /// sound. False for an explicit tap, which overrides even AirPods, the way
  /// FaceTime's speaker button does. Completes on main with the speaker side
  /// actually applied.
  ///
  /// [callId] is the call this is for (1:1 callId or groupCallId); a later
  /// [release] for any other call leaves this one alone. Nil from an older
  /// Dart.
  func apply(
    video: Bool,
    speaker: Bool,
    headsetWins: Bool,
    callId: String?,
    completion: @escaping (Bool) -> Void
  ) {
    // Claimed when ASKED, so a release asked after this (and queued before
    // it ran) can't count as this call's.
    locked { self.claimGen &+= 1 }
    queue.async {
      let session = AVAudioSession.sharedInstance()
      let applied = speaker && !(headsetWins && Self.headsetConnected(session))
      self.locked {
        self.claimed = true
        self.dartClaimed = true
        self.live = true
        self.releasePending = false
        self.owner = callId
        self.lastApply = Date()
        self.video = video
        self.speaker = applied
      }
      self.write()
      NSLog(
        "[call-audio] apply call=\(callId ?? "?") video=\(video) speaker=\(speaker) headsetWins=\(headsetWins) -> speaker=\(applied) route=\(Self.describe(session))"
      )
      DispatchQueue.main.async { completion(applied) }
    }
  }

  /// The route sheet's pick of an input port ([uid]; nil for the system's
  /// choice). Completes on main with whether the port was there to take.
  func selectInput(uid: String?, completion: @escaping (Bool) -> Void) {
    queue.async {
      let session = AVAudioSession.sharedInstance()
      let inputs = session.availableInputs ?? []
      let port = uid.flatMap { uid in inputs.first(where: { $0.uid == uid }) }
      let headsets = Set(inputs.filter { Self.headsetPorts.contains($0.portType) }.map { $0.uid })
      self.locked {
        self.preferredInputUID = port?.uid
        self.phonePinned = port?.portType == .builtInMic
        self.pickInputs = headsets
      }
      // The category first (the A2DP bit follows [phonePinned]); it puts
      // the pick on the session too. Then the pick, nil included.
      self.write()
      let ok = (uid == nil || port != nil) && self.applyPreferredInput(force: true)
      NSLog(
        "[call-audio] select input \(uid ?? "system") -> \(ok) route=\(Self.describe(AVAudioSession.sharedInstance()))"
      )
      DispatchQueue.main.async { completion(ok) }
    }
  }

  /// [snapshot] for Dart's route sheet, on [queue]; completes on main.
  func currentRoutes(completion: @escaping ([String: Any]) -> Void) {
    queue.async {
      var state = Self.snapshot(AVAudioSession.sharedInstance())
      state["reason"] = "other"
      DispatchQueue.main.async { completion(state) }
    }
  }

  /// On [queue]. Puts [preferredInputUID] on the session if it is not
  /// already there. [force] also applies a nil (hand the choice back to
  /// the system); otherwise nil means there is nothing of ours to keep.
  /// A port that is gone clears the pick. Cheap when nothing changes: the
  /// inputs are listed only while a pick is held.
  @discardableResult
  private func applyPreferredInput(force: Bool = false) -> Bool {
    let (isClaimed, uid) = locked { (self.claimed, self.preferredInputUID) }
    guard isClaimed else { return false }
    if uid == nil && !force { return true }
    let session = AVAudioSession.sharedInstance()
    var port: AVAudioSessionPortDescription?
    if let uid = uid {
      guard let found = (session.availableInputs ?? []).first(where: { $0.uid == uid }) else {
        // Only a headset can go (the phone's own mic never does), so this
        // is never a phone pin and the category needs no rewrite.
        locked {
          self.preferredInputUID = nil
          self.phonePinned = false
          self.pickInputs = []
        }
        NSLog("[call-audio] preferred input \(uid) is gone; system choice")
        return false
      }
      port = found
    }
    if session.preferredInput?.uid == port?.uid { return true }
    let rtc = RTCAudioSession.sharedInstance()
    rtc.lockForConfiguration()
    defer { rtc.unlockForConfiguration() }
    do {
      try session.setPreferredInput(port)
      lastWrite = Date()
      return true
    } catch {
      NSLog("[call-audio] setPreferredInput failed: \(error)")
      return false
    }
  }

  /// Re-applies the call's audio at a moment something else may have reset
  /// it: the plugin's configureAudioSession (ring, dial, answer,
  /// didActivate), the fallback provider's didActivate, a media services
  /// reset. With no call claimed yet, a ring or a dial seeds the kind's
  /// default ([isVideo]); nil leaves an unclaimed session alone.
  ///
  /// Returns at once: WebRTC's configuration (which its audio unit reads
  /// when it restarts) is updated here, the session write is queued.
  func reassert(isVideo: Bool?) {
    let state: (video: Bool, speaker: Bool, a2dp: Bool)? = locked {
      if !self.claimed {
        guard let isVideo = isVideo else { return nil }
        self.video = isVideo
        // Only the outputs: reading `availableInputs` can block.
        self.speaker = isVideo && !Self.headsetOutput(AVAudioSession.sharedInstance())
        self.claimed = true
        self.claimGen &+= 1
      }
      return (self.video, self.speaker, !self.phonePinned)
    }
    guard let state = state else { return }
    Self.configureWebRTC(video: state.video, speaker: state.speaker, a2dp: state.a2dp)
    queue.async {
      self.write()
      NSLog(
        "[call-audio] reassert video=\(state.video) speaker=\(state.speaker) route=\(Self.describe(AVAudioSession.sharedInstance()))"
      )
    }
  }

  /// Dart's teardown of [callId] (1:1 callId or groupCallId; nil from an
  /// older Dart). [idle] means no CallKit card (plugin or fallback) is
  /// alive, so the session can be handed back now; otherwise the plugin's
  /// idle hook does it once the last card goes.
  ///
  /// Dart repeats this for seconds after a teardown (its settled belt), so
  /// it routinely lands on the NEXT call: a release naming another call
  /// than the one Dart last applied for is ignored, and one whose restore
  /// finds a newer claim than when it was asked restores nothing.
  func release(idle: Bool, callId: String?, completion: @escaping () -> Void) {
    let askedGen = locked { claimGen }
    let id = (callId?.isEmpty ?? true) ? nil : callId
    queue.async {
      let restoreNow: Bool = self.locked {
        if let id = id {
          if let owner = self.owner, owner != id {
            NSLog("[call-audio] release for \(id) ignored: session is \(owner)'s")
            return false
          }
        } else if Date().timeIntervalSince(self.lastApply) < Self.staleReleaseWindow {
          return false
        }
        self.dartClaimed = false
        self.owner = nil
        if idle { return true }
        self.releasePending = true
        return false
      }
      if restoreNow { self.restore(ifGen: askedGen) }
      DispatchQueue.main.async(execute: completion)
    }
  }

  /// The plugin's last CallKit call went away. Restore unless a call Dart
  /// still runs holds the session (a group call raises no card at all).
  /// The claim is read NOW, when the card went, not when the queue gets to
  /// it: a reassert or an apply for the next call can land in between.
  private func restoreIfReleased() {
    let askedGen = locked { claimGen }
    queue.async {
      let go = self.locked { !self.dartClaimed || self.releasePending }
      if go { self.restore(ifGen: askedGen) }
    }
  }

  /// On [queue]. Hands the session back: no override, inactive (other apps'
  /// audio resumes), and the default `.soloAmbient` category, so the app's
  /// own media playback isn't left in a call category with its quiet
  /// earpiece-biased levels. WebRTC's configuration goes back to plain
  /// voice-chat so the next call can't come up on a stale speaker bit.
  ///
  /// Only for the claim [gen] names: a newer claim (an apply, a ring or dial
  /// seed, an answer) means the session now belongs to another call, and
  /// deactivating it would stop that call's audio.
  private func restore(ifGen gen: UInt64) {
    let current: Bool = locked {
      guard claimGen == gen else { return false }
      claimed = false
      dartClaimed = false
      releasePending = false
      live = false
      owner = nil
      video = false
      speaker = false
      preferredInputUID = nil
      phonePinned = false
      pickInputs = []
      return true
    }
    guard current else {
      NSLog("[call-audio] restore skipped: a newer call claimed the session")
      return
    }
    Self.configureWebRTC(video: false, speaker: false, a2dp: true)
    updateScreen(inCall: false, earpiece: false)
    let rtc = RTCAudioSession.sharedInstance()
    let session = AVAudioSession.sharedInstance()
    rtc.lockForConfiguration()
    defer { rtc.unlockForConfiguration() }
    try? session.overrideOutputAudioPort(.none)
    if session.preferredInput != nil { try? session.setPreferredInput(nil) }
    do {
      try session.setActive(false, options: [.notifyOthersOnDeactivation])
    } catch let error as NSError
      where error.code == AVAudioSession.ErrorCode.isBusy.rawValue {
      // Busy is NOT a refusal: iOS stopped the running I/O and deactivated
      // the session anyway (which is why the claim check above matters).
      // The session is down, so carry on to the category.
      NSLog("[call-audio] restore: deactivated over running I/O (busy)")
    } catch {
      NSLog("[call-audio] restore: setActive(false) failed: \(error)")
      return
    }
    // A claim that landed while this ran (the plugin's configure runs
    // setActive(true) on the main thread, not this queue) just lost its
    // session: give it back. Its own write is queued behind this one.
    if locked({ claimGen != gen && claimed }) {
      NSLog("[call-audio] restore: a call claimed the session mid-restore; reactivating")
      do {
        try session.setActive(true)
      } catch {
        NSLog("[call-audio] restore: reactivate failed: \(error)")
      }
      return
    }
    if session.category != .soloAmbient {
      do {
        try session.setCategory(.soloAmbient, mode: .default, options: [])
      } catch {
        NSLog("[call-audio] restore: setCategory failed: \(error)")
      }
    }
    NSLog("[call-audio] restored")
  }

  /// [a2dp] is false only while the phone is pinned ([phonePinned]).
  private static func options(speaker: Bool, a2dp: Bool) -> AVAudioSession.CategoryOptions {
    var options: AVAudioSession.CategoryOptions = [.allowBluetoothHFP]
    if a2dp { options.insert(.allowBluetoothA2DP) }
    if speaker { options.insert(.defaultToSpeaker) }
    return options
  }

  /// `videoChat` force-sets `defaultToSpeaker`, so it is only for video on
  /// the speaker; video on the earpiece or a headset is `voiceChat`.
  private static func mode(video: Bool, speaker: Bool) -> AVAudioSession.Mode {
    (video && speaker) ? .videoChat : .voiceChat
  }

  /// WebRTC re-applies this whenever its audio unit (re)starts; left stale,
  /// the route would snap back at connect or after an interruption.
  private static func configureWebRTC(video: Bool, speaker: Bool, a2dp: Bool) {
    let config = RTCAudioSessionConfiguration.webRTC()
    config.category = AVAudioSession.Category.playAndRecord.rawValue
    config.categoryOptions = options(speaker: speaker, a2dp: a2dp)
    config.mode = mode(video: video, speaker: speaker).rawValue
  }

  /// On [queue]. Writes the LATEST desired state (so a queued write can
  /// never put back a side the user already left): category and mode only
  /// when they differ, the port override every time (cheap, and it is what
  /// an outside category change drops).
  private func write() {
    let state: (video: Bool, speaker: Bool, a2dp: Bool)? = locked {
      self.claimed ? (self.video, self.speaker, !self.phonePinned) : nil
    }
    guard let (video, speaker, a2dp) = state else { return }
    let options = Self.options(speaker: speaker, a2dp: a2dp)
    let mode = Self.mode(video: video, speaker: speaker)
    Self.configureWebRTC(video: video, speaker: speaker, a2dp: a2dp)

    let rtc = RTCAudioSession.sharedInstance()
    let session = AVAudioSession.sharedInstance()
    rtc.lockForConfiguration()
    do {
      // `videoChat` adds bits of its own, so compare what this call asks
      // for (each option present, the speaker and A2DP bits exactly)
      // instead of equality, which would rewrite video-on-speaker on every
      // reassert.
      let current = session.categoryOptions
      if session.category != .playAndRecord
        || session.mode != mode
        || !current.isSuperset(of: options)
        || current.contains(.defaultToSpeaker) != speaker
        || current.contains(.allowBluetoothA2DP) != a2dp {
        try rtc.setCategory(.playAndRecord, mode: mode, options: options)
      }
    } catch {
      NSLog("[call-audio] setCategory failed: \(error)")
    }
    do {
      try rtc.overrideOutputAudioPort(speaker ? .speaker : .none)
    } catch {
      NSLog("[call-audio] overrideOutputAudioPort failed: \(error)")
    }
    rtc.unlockForConfiguration()
    lastWrite = Date()
    // A category write can drop the preferred input; put the sheet's pick
    // back (a no-op without one). Outside the lock above, which it takes
    // itself.
    applyPreferredInput()
    if locked({ live }) { updateScreen(inCall: true, earpiece: Self.onEarpiece(session)) }
  }

  /// Idle timer off for the call; proximity sensor on only while the sound
  /// is on the earpiece. UIKit, so on main.
  private func updateScreen(inCall: Bool, earpiece: Bool) {
    DispatchQueue.main.async {
      let app = UIApplication.shared
      if app.isIdleTimerDisabled != inCall { app.isIdleTimerDisabled = inCall }
      let device = UIDevice.current
      let proximity = inCall && earpiece
      if device.isProximityMonitoringEnabled != proximity {
        device.isProximityMonitoringEnabled = proximity
      }
    }
  }

  // RTCAudioSessionDelegate. WebRTC's audio unit just started, after
  // configuring the session from `RTCAudioSessionConfiguration.webRTC()`,
  // which flutter_webrtc's `ensureAudioSession` may have rewritten without
  // the speaker bit. Put ours back. Called on a WebRTC thread.
  func audioSessionDidStartPlayOrRecord(_ session: RTCAudioSession) {
    guard locked({ claimed }) else { return }
    queue.async {
      self.write()
      NSLog("[call-audio] audio unit started -> \(Self.describe(AVAudioSession.sharedInstance()))")
    }
  }

  /// Pushes the real route to Dart while a call holds the session. Dart
  /// decides what it means (lib/calls/call_media.dart, `decideCallAudioRoute`).
  /// A change by the user from outside the app (CallKit's speaker button,
  /// Control Center) is adopted here too, so a reassert before Dart answers
  /// can't put the old side back.
  private func routeChanged(_ reason: AVAudioSession.RouteChangeReason) {
    queue.async {
      guard self.locked({ self.claimed }) else { return }
      let session = AVAudioSession.sharedInstance()
      // A headset connecting takes the sound (the product rule Dart's
      // policy follows), over an earlier pick in the route sheet.
      // Only a headset that was not there when the pick was made: the
      // pick's own hand-over can be reported as `newDevice` too.
      if reason == .newDeviceAvailable, self.locked({ self.preferredInputUID != nil }) {
        let known = self.locked { self.pickInputs }
        let arrived = (session.availableInputs ?? []).contains {
          Self.headsetPorts.contains($0.portType) && !known.contains($0.uid)
        }
        if arrived {
          let wasPhone: Bool = self.locked {
            let was = self.phonePinned
            self.preferredInputUID = nil
            self.phonePinned = false
            self.pickInputs = []
            return was
          }
          // A2DP back in the category before the pick is let go.
          if wasPhone { self.write() }
          self.applyPreferredInput(force: true)
        }
      }
      var state = Self.snapshot(session)
      let echo = Date().timeIntervalSince(self.lastWrite) < Self.echoWindow
      let name = Self.reasonName(reason)
      state["reason"] = name
      state["echo"] = echo
      if !echo && (name == "override" || name == "routeConfiguration"),
        let actual = state["speaker"] as? Bool {
        self.locked { self.speaker = actual }
      }
      if self.locked({ self.live }) {
        self.updateScreen(inCall: true, earpiece: Self.onEarpiece(session))
      }
      NSLog("[call-audio] route \(name)\(echo ? " (echo)" : "") -> \(Self.describe(session))")
      DispatchQueue.main.async {
        self.channel?.invokeMethod("routeChanged", arguments: state)
      }
    }
  }

  private static let headsetPorts: Set<AVAudioSession.Port> = [
    .headphones, .headsetMic, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
    .carAudio, .usbAudio,
  ]

  private static func headsetOutput(_ session: AVAudioSession) -> Bool {
    session.currentRoute.outputs.contains { headsetPorts.contains($0.portType) }
  }

  /// A headset is connected, even while the speaker override hides it from
  /// the outputs (its microphone still shows among the inputs).
  static func headsetConnected(_ session: AVAudioSession) -> Bool {
    headsetOutput(session)
      || (session.availableInputs ?? []).contains { headsetPorts.contains($0.portType) }
  }

  private static func onEarpiece(_ session: AVAudioSession) -> Bool {
    session.currentRoute.outputs.contains { $0.portType == .builtInReceiver }
  }

  static func snapshot(_ session: AVAudioSession) -> [String: Any] {
    let outputs = session.currentRoute.outputs.map { $0.portType }
    return [
      "speaker": outputs.contains(.builtInSpeaker),
      "headset": headsetConnected(session),
      "output": outputName(outputs.first),
      "portName": session.currentRoute.outputs.first?.portName ?? "",
      "input": inputName(session.currentRoute.inputs.first?.portType),
      "routes": routes(session),
    ]
  }

  /// Where the call's voice is picked up: `builtIn` (the phone's own mic),
  /// `headset` (a wired set's, USB), `bluetooth`, `car`, or `none`. The mic
  /// button wears a headset badge when it is anything but the phone.
  private static func inputName(_ port: AVAudioSession.Port?) -> String {
    guard let port = port else { return "none" }
    switch port {
    case .builtInMic: return "builtIn"
    case .headsetMic, .usbAudio: return "headset"
    case .bluetoothHFP, .bluetoothLE: return "bluetooth"
    case .carAudio: return "car"
    default: return "other"
    }
  }

  /// The phone's own name for its earpiece route ("iPhone"); nil on a
  /// device without an earpiece. Set at [install].
  private static var receiverName: String?

  /// Every route the in-app sheet can offer, in FaceTime's order: the
  /// phone (iPhone only; selected by its built-in mic), the speaker, then
  /// each headset by its mic port, and the current output when it is a
  /// headset with no mic of its own (A2DP-only, plain headphones, AirPlay).
  /// `uid` is what `selectCallAudioInput` takes; empty selects no port.
  static func routes(_ session: AVAudioSession) -> [[String: Any]] {
    let current = session.currentRoute.outputs.first
    let currentKind = outputName(current?.portType)
    let currentInput = session.currentRoute.inputs.first
    let inputs = session.availableInputs ?? []
    var list: [[String: Any]] = []
    if let receiverName = receiverName,
      let mic = inputs.first(where: { $0.portType == .builtInMic }) {
      list.append([
        "kind": "receiver", "uid": mic.uid, "name": receiverName,
        "selected": currentKind == "receiver",
      ])
    }
    list.append(["kind": "speaker", "uid": "", "selected": currentKind == "speaker"])
    var matched = false
    for input in inputs where headsetPorts.contains(input.portType) {
      let kind: String
      switch input.portType {
      case .carAudio: kind = "car"
      case .headsetMic, .usbAudio: kind = "headphones"
      default: kind = "bluetooth"
      }
      // Wired: the output is "Headphones", the mic "Headset Microphone",
      // so the kind alone matches; wireless sets share a name across both.
      let soundHere = currentKind == kind
        && (kind == "headphones" || current?.portName == input.portName)
      if soundHere { matched = true }
      // Checked only with the mic here too. The sound on a headset's A2DP
      // side with the phone's mic is no one route: nothing is checked, and
      // a tap on the headset takes both back.
      let selected = soundHere && currentInput?.uid == input.uid
      list.append([
        "kind": kind, "uid": input.uid, "name": input.portName, "selected": selected,
      ])
    }
    if !matched, let current = current,
      !["receiver", "speaker", "none"].contains(currentKind) {
      list.append([
        "kind": currentKind, "uid": "", "name": current.portName, "selected": true,
      ])
    }
    return list
  }

  private static func outputName(_ port: AVAudioSession.Port?) -> String {
    guard let port = port else { return "none" }
    switch port {
    case .builtInReceiver: return "receiver"
    case .builtInSpeaker: return "speaker"
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE: return "bluetooth"
    case .headphones, .usbAudio: return "headphones"
    case .carAudio: return "car"
    case .airPlay: return "airplay"
    default: return "other"
    }
  }

  private static func reasonName(_ reason: AVAudioSession.RouteChangeReason) -> String {
    switch reason {
    case .newDeviceAvailable: return "newDevice"
    case .oldDeviceUnavailable: return "oldDevice"
    case .categoryChange: return "category"
    case .override: return "override"
    case .routeConfigurationChange: return "routeConfiguration"
    default: return "other"
    }
  }

  private static func describe(_ session: AVAudioSession) -> String {
    let outs = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
    return "[\(outs)] mode=\(session.mode.rawValue) opts=\(session.categoryOptions.rawValue)"
  }
}

/// AVPlayerViewController that actually lets go of its player.
///
/// Presented modally it dismisses itself from its own Done button, and Flutter
/// has already popped the route that asked for it by then — so nothing else is
/// left holding a reference. Without this the AVPlayer survives the dismissal
/// and keeps the audio session (and its decoder) alive, which is audible: back
/// out of a video and it goes on playing over the transcript.
private class _VideoPlayerViewController: AVPlayerViewController {
  /// Whether this player covers itself while the screen is being recorded or
  /// mirrored. Set from the `secure` channel argument.
  ///
  /// iOS has no FLAG_SECURE, so this cannot *prevent* a capture the way Android
  /// does — it detects one and hides the content, which is the same bargain the
  /// Dart `CaptureShield` strikes for the rest of the app. Worth being honest
  /// about the gap: frames between the capture starting and the notification
  /// arriving are not recoverable, and nothing on this platform closes that.
  var shieldsAgainstCapture = false

  /// Localized copy for the cover, handed down from Dart (see NativeVideoPlayer).
  var shieldTitle: String?
  var shieldBody: String?

  private var shield: UIView?
  private var resumeAfterShield = false

  override func viewDidLoad() {
    super.viewDidLoad()
    guard shieldsAgainstCapture else { return }
    // Two ways the video walks out from behind the shield. Picture-in-Picture
    // floats it into a system window this controller does not own and cannot
    // cover; external playback hands the stream to an AirPlay receiver without
    // ever setting `isCaptured`, so the shield would not even know to raise.
    // Neither is worth keeping while protection is on.
    allowsPictureInPicturePlayback = false
    player?.allowsExternalPlayback = false
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_capturedDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    // The notification fires on a CHANGE, so a capture already in progress when
    // this player opens would never announce itself. Ask once, up front.
    _applyCaptureState()
  }

  @objc private func _capturedDidChange() {
    _applyCaptureState()
  }

  private func _applyCaptureState() {
    UIScreen.main.isCaptured ? _raiseShield() : _dropShield()
  }

  private func _raiseShield() {
    guard shield == nil, isViewLoaded else { return }
    // Pause AND cover, because either alone leaks. A covered player keeps
    // sending audio to the recording; a paused one still shows the frame it
    // stopped on.
    resumeAfterShield = player?.timeControlStatus != .paused
    player?.pause()
    // The controls come off rather than being covered: the scrubber renders
    // preview thumbnails of the video above the content overlay, and a
    // filmstrip of the frames is precisely what must not survive the shield.
    showsPlaybackControls = false

    let cover = UIView(frame: view.bounds)
    cover.backgroundColor = .black
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let icon = UIImageView(image: UIImage(systemName: "eye.slash"))
    icon.tintColor = .white
    icon.contentMode = .scaleAspectFit

    let stack = UIStackView(arrangedSubviews: [icon])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false

    if let text = shieldTitle, !text.isEmpty {
      let label = UILabel()
      // Matches the letter-spacing the Dart shield gives the same word, so the
      // two protected states read as one design rather than two.
      label.attributedText = NSAttributedString(
        string: text,
        attributes: [.kern: 2.4, .foregroundColor: UIColor.white]
      )
      label.font = .systemFont(ofSize: 13, weight: .semibold)
      stack.addArrangedSubview(label)
    }
    if let text = shieldBody, !text.isEmpty {
      let label = UILabel()
      label.text = text
      label.font = .systemFont(ofSize: 15)
      label.textColor = UIColor.white.withAlphaComponent(0.7)
      label.textAlignment = .center
      label.numberOfLines = 0
      stack.addArrangedSubview(label)
    }

    cover.addSubview(stack)
    // Added to `view` rather than `contentOverlayView`, which is the sanctioned
    // place for custom content but sits UNDER anything AVKit draws. A shield
    // that something can be drawn on top of is not a shield.
    view.addSubview(cover)
    NSLayoutConstraint.activate([
      icon.heightAnchor.constraint(equalToConstant: 32),
      stack.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
      stack.leadingAnchor.constraint(
        greaterThanOrEqualTo: cover.leadingAnchor, constant: 32),
      stack.trailingAnchor.constraint(
        lessThanOrEqualTo: cover.trailingAnchor, constant: -32),
    ])
    shield = cover
  }

  private func _dropShield() {
    guard let cover = shield else { return }
    cover.removeFromSuperview()
    shield = nil
    showsPlaybackControls = true
    // Only resume what the shield actually interrupted — a video the user had
    // already paused should stay paused when they stop recording.
    if resumeAfterShield { player?.play() }
    resumeAfterShield = false
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Only on a real dismissal — a Picture-in-Picture handoff or a pushed
    // child also fires this, and tearing the player down there would stop the
    // playback the user just asked to keep.
    guard isBeingDismissed || isMovingFromParent else { return }
    player?.pause()
    player = nil
  }
}

/// The iOS half of background live-location sharing: everything `geolocator`
/// does not expose.
///
/// Lives in this file rather than in its own because every Swift source has to
/// be listed by hand in `Runner.xcodeproj/project.pbxproj`, and a new file that
/// somebody forgets to add compiles perfectly and simply is not there. Swift is
/// happy with several types per file; a silently-missing bridge is a much worse
/// trade than a longer AppDelegate.
///
/// ## What geolocator already does, and why this is not that
///
/// Continuous background updates are the plugin's job and it does them well:
/// `AppleSettings(allowBackgroundLocationUpdates:showBackgroundLocationIndicator:
/// pauseLocationUpdatesAutomatically:)` sets exactly the three CLLocationManager
/// properties that matter, and needs nothing here. Three things it cannot do:
///
///  1. **Ask for Always.** `geolocator`'s `requestPermission` calls
///     `requestWhenInUseAuthorization` whenever `NSLocationWhenInUseUsageDescription`
///     exists, and returns early without prompting once the status is anything
///     but `notDetermined`. The Always escalation is by definition a second
///     prompt after When-In-Use was granted, so it needs its own call.
///  2. **Significant-change monitoring.** Not exposed at all, and the only iOS
///     API that can relaunch a terminated app.
///  3. **A notification with a STOP action.** iOS has no equivalent of Android's
///     foreground-service notification, so this posts an ordinary local one.
///
/// ## The relaunch contract, stated plainly
///
/// `startMonitoringSignificantLocationChanges` survives termination. When the
/// device moves roughly 500 m, iOS relaunches this app into the background with
/// `UIApplication.LaunchOptionsKey.location` set. Three things about that are
/// easy to get wrong and are handled here:
///
///  * The relaunched app **must restart monitoring immediately**, in
///    `didFinishLaunchingWithOptions`. A relaunch does not carry the old
///    registration forward; an app that waits for Dart to ask gets one callback
///    and is never woken again.
///  * The launch key is **consumed once** and reported to Dart as
///    `wasLaunchedForLocation`, so a launch the user did not ask for stays
///    silent — no route restored, no room marked read.
///  * Granularity is ~500 m and several minutes. Between callbacks the share
///    reads STALE to every viewer, which is correct: between callbacks nobody
///    knows where this phone is.
///
/// It requires Always. On When-In-Use everything above is skipped and the share
/// simply stops when the process does — which is the ordinary outcome, not a
/// failure, and nothing here reports it as one.
/// Deliberately NOT a `UNUserNotificationCenterDelegate`. `AppDelegate` already
/// owns that role and there is only one; a second claimant would silently take
/// the first one's deliveries and break every push in the app. The STOP action
/// reaches this class through [handleNotificationResponse], called from
/// AppDelegate's override.
final class LiveLocationBridge: NSObject, CLLocationManagerDelegate {

  /// Set before Dart exists, read once by it. Same "native buffers, Dart
  /// drains" pattern the VoIP and notification channels in this file use, and
  /// for the same reason: on a background relaunch the OS talks to us a long
  /// time before an isolate is listening.
  static var launchedForLocation = false

  private static let notificationId = "monkeyhub.liveShare"
  private static let stopActionId = "monkeyhub.liveShare.stop"
  private static let categoryId = "monkeyhub.liveShare.category"

  private let manager = CLLocationManager()
  private var channel: FlutterMethodChannel?

  /// The Dart future waiting on the Always prompt, if any. Held because
  /// `requestAlwaysAuthorization` answers through the delegate rather than a
  /// completion handler, and a FlutterResult cannot be completed twice — so this
  /// is nulled the moment it is used.
  private var pendingAuthResult: FlutterResult?

  func register(on engine: FlutterEngine) {
    guard let registrar = engine.registrar(forPlugin: "MonkeyHubLiveLocationPlugin")
    else { return }
    let channel = FlutterMethodChannel(
      name: "monkeyhub/live_location",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
    manager.delegate = self
    registerNotificationCategory()
  }

  /// Re-arms significant-change monitoring on a relaunch, before Dart is up.
  ///
  /// Called from `didFinishLaunchingWithOptions`. The share may turn out to be
  /// over — the persisted handle decides that, in Dart, a moment later — but
  /// re-registering first costs nothing and NOT doing it costs everything: an
  /// app relaunched for location that does not restart monitoring gets exactly
  /// one more callback in its life.
  func handleLaunch(options: [UIApplication.LaunchOptionsKey: Any]?) {
    guard options?[.location] != nil else { return }
    LiveLocationBridge.launchedForLocation = true
    NSLog("[live-location] relaunched by significant location change")
    manager.delegate = self
    manager.startMonitoringSignificantLocationChanges()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationTier":
      result(tierString())

    case "requestAlwaysAuthorization":
      requestAlways(result: result)

    case "startSharing":
      let args = call.arguments as? [String: Any] ?? [:]
      startSharing(
        title: args["title"] as? String ?? "",
        body: args["body"] as? String ?? "",
        stopLabel: args["stopLabel"] as? String ?? "Stop",
        significantChanges: args["significantChanges"] as? Bool ?? false
      )
      result(nil)

    case "stopSharing":
      stopSharing()
      result(nil)

    case "wasLaunchedForLocation":
      let was = LiveLocationBridge.launchedForLocation
      // Consumed. A second reader asking "was this a location launch?" ten
      // minutes into a session the user has been tapping through would get a
      // yes, and act on it.
      LiveLocationBridge.launchedForLocation = false
      result(was)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Authorization

  private func tierString() -> String {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    switch status {
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "whenInUse"
    default: return "none"
    }
  }

  /// Shows the Always prompt, and resolves with whatever iOS decides.
  ///
  /// The honest description of what happens next, because the naive reading of
  /// this API is wrong: on a device that already holds When-In-Use,
  /// `requestAlwaysAuthorization` very often returns the SAME status
  /// immediately and shows the user nothing. iOS defers the real question until
  /// the app has actually used location in the background, then asks on its own
  /// terms — the "Keep Only While Using / Change to Always" sheet, which can
  /// arrive hours later.
  ///
  /// So a `whenInUse` answer here means "not decided yet", never "refused", and
  /// the Dart side is written to carry on with Tier 1 and never re-ask. The
  /// two-second timeout below exists for exactly that case: without it the Dart
  /// future would hang until the user next moved 500 m.
  private func requestAlways(result: @escaping FlutterResult) {
    if tierString() == "always" {
      result("always")
      return
    }
    if pendingAuthResult != nil {
      // A second request while one is open. Answering with the current status
      // is better than replacing the pending result, which would strand the
      // first caller forever.
      result(tierString())
      return
    }
    pendingAuthResult = result
    manager.requestAlwaysAuthorization()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      guard let self, let pending = self.pendingAuthResult else { return }
      self.pendingAuthResult = nil
      pending(self.tierString())
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let pending = pendingAuthResult else { return }
    pendingAuthResult = nil
    pending(tierString())
  }

  // MARK: - Sharing

  private func startSharing(
    title: String,
    body: String,
    stopLabel: String,
    significantChanges: Bool
  ) {
    postNotification(title: title, body: body, stopLabel: stopLabel)
    // Guarded on Always, and silently. Asking for significant-change monitoring
    // without it is not an error iOS reports — it simply never calls back — so
    // the check is here rather than left to the OS, and a When-In-Use user gets
    // the full backgrounded-app share with no warning about what they do not
    // have.
    guard significantChanges, tierString() == "always" else { return }
    manager.startMonitoringSignificantLocationChanges()
  }

  private func stopSharing() {
    manager.stopMonitoringSignificantLocationChanges()
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(
      withIdentifiers: [LiveLocationBridge.notificationId])
    center.removeDeliveredNotifications(
      withIdentifiers: [LiveLocationBridge.notificationId])
  }

  /// The iOS answer to "let me stop this without hunting for the app".
  ///
  /// Not as good as Android's ongoing notification — iOS has no such thing for
  /// a non-service app, so this is an ordinary local notification that the user
  /// can swipe away without stopping anything. It is a shortcut, not a status
  /// display. The actual always-visible indicator on iOS is the blue status-bar
  /// pill that `showsBackgroundLocationIndicator` draws, and tapping that goes
  /// straight into the app.
  ///
  /// Interruption level `.passive` so it lands in Notification Centre without
  /// lighting the screen or making a sound. A share the user just started does
  /// not need announcing to the person who started it.
  private func postNotification(title: String, body: String, stopLabel: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.categoryIdentifier = LiveLocationBridge.categoryId
    content.sound = nil
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .passive
    }
    // Rebuilt on every start so the action carries the user's current language.
    registerNotificationCategory(stopLabel: stopLabel)
    let request = UNNotificationRequest(
      identifier: LiveLocationBridge.notificationId,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        // Not fatal and not surfaced. The user declined notifications, most
        // likely; the share itself is unaffected and the blue pill is still
        // there.
        NSLog("[live-location] notification failed: \(error.localizedDescription)")
      }
    }
  }

  private func registerNotificationCategory(stopLabel: String = "Stop sharing") {
    let stop = UNNotificationAction(
      identifier: LiveLocationBridge.stopActionId,
      title: stopLabel,
      options: [.destructive]
    )
    let category = UNNotificationCategory(
      identifier: LiveLocationBridge.categoryId,
      actions: [stop],
      intentIdentifiers: [],
      options: []
    )
    let center = UNUserNotificationCenter.current()
    // Merged rather than replaced: this app registers no other categories today
    // but overwriting the whole set from a location bridge is the kind of line
    // that quietly breaks somebody else's notification a year from now.
    center.getNotificationCategories { existing in
      var next = existing.filter { $0.identifier != LiveLocationBridge.categoryId }
      next.insert(category)
      center.setNotificationCategories(next)
    }
  }

  /// True if this response was the share's STOP button, in which case Dart has
  /// been told and the caller should not treat it as an ordinary tap.
  ///
  /// Called from AppDelegate's own `didReceive response` override, because
  /// `UNUserNotificationCenter.delegate` is already assigned there and a second
  /// claimant would silently take the first one's deliveries.
  func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
    guard response.actionIdentifier == LiveLocationBridge.stopActionId else {
      return false
    }
    stopSharing()
    // The notification is already gone; what matters is that the SERVER hears
    // about it, which only Dart can do. Buffered by nothing on purpose: pressing
    // STOP on a notification launches the app if it is not running, and by the
    // time this fires the engine has been started for at least a run loop.
    channel?.invokeMethod("stopRequested", arguments: nil)
    return true
  }
}

/// Bridges UIScreen.capturedDidChangeNotification → Flutter event sink.
/// Pushes the current isCaptured bool on listen so Dart has the right
/// initial state; subsequent emissions come from AppDelegate's observer.
private class _CaptureStreamHandler: NSObject, FlutterStreamHandler {
  weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
    super.init()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.setCaptureEventSink(events)
    events(UIScreen.main.isCaptured)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    appDelegate?.setCaptureEventSink(nil)
    return nil
  }
}

// MARK: - Native media gallery (monkeyhub/video presentGallery)

/// One page of [MediaGalleryController]: a video or a photo, at a `file://`
/// URL when a copy is on disk, else its remote URL.
struct MediaGalleryItem {
  let isVideo: Bool
  let url: URL
  let poster: URL?
}

/// What every gallery page answers to: where it sits, and being swiped onto
/// and off screen.
protocol MediaGalleryPage: UIViewController {
  var pageIndex: Int { get }
  /// Swiped to and settled: a video starts playing.
  func becameCurrent()
  /// Swiped away: a video pauses, so two never play at once.
  func resignedCurrent()
  /// Whether a downward drag may start closing the gallery from here (a
  /// zoomed photo wants the drag for panning instead).
  var allowsDismissDrag: Bool { get }
}

/// The swipeable native gallery: Photos' shape, the system player inside it.
///
/// Every video page is a full `AVPlayerViewController`, so scrubbing, the
/// volume, AirPlay, Picture-in-Picture, captions and VoiceOver are the
/// system's own, exactly as they were when one video opened alone. Photos are
/// zoomable pages beside them. Swiping left and right moves between them;
/// only the page in view plays.
///
/// Pages fill the whole screen, so a video or photo sits exactly where the
/// Flutter pager that opened this had it: no jump on the handoff.
///
/// One close button on screen, never two. A video page shows the system
/// player's own controls, ✕ included (AVKit draws one inside any full-screen
/// modal, and there is no way to hide just that one), so this adds nothing
/// there. A photo page has no player, so it gets this gallery's ✕ in the same
/// top-left place, fading in and out as the swipe crosses between kinds.
/// However the gallery goes (either ✕, a drag down), the page it closed on is
/// reported from [viewDidDisappear], the one place every dismissal passes.
final class MediaGalleryController: UIViewController,
  UIPageViewControllerDataSource, UIPageViewControllerDelegate,
  UIGestureRecognizerDelegate
{
  private let items: [MediaGalleryItem]
  private(set) var index: Int
  var onClose: ((Int) -> Void)?

  private let pager = UIPageViewController(
    transitionStyle: .scroll,
    navigationOrientation: .horizontal,
    options: [.interPageSpacing: 14]
  )
  private let bar = UIView()
  private let barFade = CAGradientLayer()
  private let closeLabel: String?

  /// The floating bar's height below the status bar.
  static let barHeight: CGFloat = 52
  private var closed = false
  private var reported = false

  init(items: [MediaGalleryItem], index: Int, closeLabel: String?) {
    self.items = items
    self.index = index
    self.closeLabel = closeLabel
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
    modalPresentationCapturesStatusBarAppearance = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    addChild(pager)
    view.addSubview(pager.view)
    pager.didMove(toParent: self)
    pager.dataSource = self
    pager.delegate = self
    pager.setViewControllers([page(at: index)], direction: .forward, animated: false)

    // A fade rather than a fill: the media shows through, as it does under
    // the Flutter pager's chrome.
    barFade.colors = [
      UIColor.black.withAlphaComponent(0.55).cgColor,
      UIColor.black.withAlphaComponent(0).cgColor,
    ]
    bar.layer.insertSublayer(barFade, at: 0)
    view.addSubview(bar)

    // The close button: a round frosted disc with an ×, the same shape and
    // place as the Flutter viewer's, built from the system's own material.
    let disc = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    disc.isUserInteractionEnabled = false
    disc.layer.cornerRadius = 20
    disc.clipsToBounds = true
    disc.translatesAutoresizingMaskIntoConstraints = false
    let close = UIButton(type: .system)
    close.setImage(
      UIImage(
        systemName: "xmark",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
      ),
      for: .normal
    )
    close.tintColor = .white
    close.accessibilityLabel = closeLabel ?? NSLocalizedString("Close", comment: "")
    close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    close.translatesAutoresizingMaskIntoConstraints = false
    bar.addSubview(disc)
    bar.addSubview(close)

    NSLayoutConstraint.activate([
      close.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
      close.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -6),
      close.widthAnchor.constraint(equalToConstant: 40),
      close.heightAnchor.constraint(equalToConstant: 40),
      disc.centerXAnchor.constraint(equalTo: close.centerXAnchor),
      disc.centerYAnchor.constraint(equalTo: close.centerYAnchor),
      disc.widthAnchor.constraint(equalToConstant: 40),
      disc.heightAnchor.constraint(equalToConstant: 40),
    ])

    // Drag down to close, as in Photos. Only from a page that allows it, and
    // only when the drag is clearly downward, so it never fights the pager's
    // horizontal swipe or a zoomed photo's pan.
    let pan = UIPanGestureRecognizer(target: self, action: #selector(dismissPan(_:)))
    pan.delegate = self
    view.addGestureRecognizer(pan)
    updateChrome(animated: false)
  }

  /// This gallery's ✕ only where the system player's is not: photo pages.
  private func updateChrome(animated: Bool) {
    let show = !(items[index].isVideo)
    let apply = { self.bar.alpha = show ? 1 : 0 }
    bar.isUserInteractionEnabled = show
    if animated {
      UIView.animate(withDuration: 0.2, animations: apply)
    } else {
      apply()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let top = view.safeAreaInsets.top + Self.barHeight
    bar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: top)
    barFade.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: top + 24)
    // The whole screen, so media centres where the Flutter pager centred it.
    pager.view.frame = view.bounds
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    current?.becameCurrent()
  }

  private var current: MediaGalleryPage? {
    pager.viewControllers?.first as? MediaGalleryPage
  }

  private func page(at i: Int) -> UIViewController {
    let item = items[i]
    return item.isVideo
      ? MediaGalleryVideoPage(item: item, pageIndex: i)
      : MediaGalleryPhotoPage(item: item, pageIndex: i)
  }

  // MARK: paging

  func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerBefore viewController: UIViewController
  ) -> UIViewController? {
    guard let p = viewController as? MediaGalleryPage, p.pageIndex > 0 else { return nil }
    return page(at: p.pageIndex - 1)
  }

  func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerAfter viewController: UIViewController
  ) -> UIViewController? {
    guard let p = viewController as? MediaGalleryPage, p.pageIndex < items.count - 1 else {
      return nil
    }
    return page(at: p.pageIndex + 1)
  }

  func pageViewController(
    _ pageViewController: UIPageViewController,
    willTransitionTo pendingViewControllers: [UIViewController]
  ) {
    // Stop the sound the moment the swipe begins, not when it lands.
    current?.resignedCurrent()
  }

  func pageViewController(
    _ pageViewController: UIPageViewController,
    didFinishAnimating finished: Bool,
    previousViewControllers: [UIViewController],
    transitionCompleted completed: Bool
  ) {
    guard let now = current else { return }
    index = now.pageIndex
    updateChrome(animated: true)
    now.becameCurrent()
  }

  // MARK: closing

  @objc private func closeTapped() { close() }

  private func close() {
    guard !closed else { return }
    closed = true
    current?.resignedCurrent()
    dismiss(animated: true)
  }

  /// Every way out ends here: this gallery's ✕, a drag down, and the system
  /// player's own ✕, which dismisses through UIKit without ever calling
  /// [close]. Reporting from here is what keeps the Flutter screen
  /// underneath landing on the right item whichever button was used.
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isBeingDismissed || presentingViewController == nil, !reported else { return }
    reported = true
    closed = true
    current?.resignedCurrent()
    onClose?(index)
  }

  func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
    guard let pan = g as? UIPanGestureRecognizer, current?.allowsDismissDrag ?? false else {
      return false
    }
    let v = pan.velocity(in: view)
    return v.y > 0 && abs(v.y) > abs(v.x) * 1.5
  }

  @objc private func dismissPan(_ pan: UIPanGestureRecognizer) {
    let dy = max(0, pan.translation(in: view).y)
    switch pan.state {
    case .changed:
      pager.view.transform = CGAffineTransform(translationX: 0, y: dy)
      view.backgroundColor = UIColor.black.withAlphaComponent(1 - min(dy / 600, 0.6))
    case .ended, .cancelled:
      if dy > 140 || pan.velocity(in: view).y > 900 {
        close()
      } else {
        UIView.animate(withDuration: 0.25) {
          self.pager.view.transform = .identity
          self.view.backgroundColor = .black
        }
      }
    default:
      break
    }
  }
}

/// A video page: the system player, embedded, with the poster on its content
/// overlay until the first frame is ready.
final class MediaGalleryVideoPage: UIViewController, MediaGalleryPage {
  let pageIndex: Int
  private let item: MediaGalleryItem
  private let playerController = AVPlayerViewController()
  private var readyObservation: NSKeyValueObservation?
  private let posterView = UIImageView()
  private var wantsPlay = false

  init(item: MediaGalleryItem, pageIndex: Int) {
    self.item = item
    self.pageIndex = pageIndex
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  var allowsDismissDrag: Bool { true }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    addChild(playerController)
    playerController.view.frame = view.bounds
    playerController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(playerController.view)
    playerController.didMove(toParent: self)
    playerController.entersFullScreenWhenPlaybackBegins = false
    // A video that finishes stays on its last frame with the system's replay
    // control, as in Photos. `true` here played the player's exit animation
    // at the end, which looked exactly like the gallery closing when it had
    // not: only the close button or a drag down closes.
    playerController.exitsFullScreenWhenPlaybackEnds = false

    // The player is made with the page, but nothing plays until the page is
    // the current one: a neighbour prepared off screen starts instantly when
    // swiped to.
    let player = AVPlayer(url: item.url)
    player.automaticallyWaitsToMinimizeStalling = true
    playerController.player = player

    if let poster = item.poster, let overlay = playerController.contentOverlayView {
      posterView.frame = overlay.bounds
      posterView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      posterView.contentMode = .scaleAspectFit
      overlay.addSubview(posterView)
      MediaGalleryImageLoader.load(poster) { [weak self] image in
        self?.posterView.image = image
      }
      readyObservation = playerController.observe(\.isReadyForDisplay, options: [.new]) {
        [weak self] controller, _ in
        guard controller.isReadyForDisplay else { return }
        DispatchQueue.main.async {
          UIView.animate(withDuration: 0.15) { self?.posterView.alpha = 0 }
        }
      }
    }
    if wantsPlay { player.play() }
  }

  func becameCurrent() {
    wantsPlay = true
    playerController.player?.play()
  }

  func resignedCurrent() {
    wantsPlay = false
    playerController.player?.pause()
  }

  deinit {
    readyObservation?.invalidate()
    // Let go of the decoder and the audio session with the page, or audio
    // keeps going after a swipe or a close.
    playerController.player?.pause()
    playerController.player?.replaceCurrentItem(with: nil)
  }
}

/// A photo page: pinch and double-tap to zoom, as in Photos.
final class MediaGalleryPhotoPage: UIViewController, MediaGalleryPage, UIScrollViewDelegate {
  let pageIndex: Int
  private let item: MediaGalleryItem
  private let scroll = UIScrollView()
  private let imageView = UIImageView()
  private let spinner = UIActivityIndicatorView(style: .medium)

  init(item: MediaGalleryItem, pageIndex: Int) {
    self.item = item
    self.pageIndex = pageIndex
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  var allowsDismissDrag: Bool { scroll.zoomScale <= scroll.minimumZoomScale + 0.01 }

  func becameCurrent() {}

  func resignedCurrent() {
    scroll.setZoomScale(scroll.minimumZoomScale, animated: false)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    scroll.frame = view.bounds
    scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    scroll.delegate = self
    scroll.minimumZoomScale = 1
    scroll.maximumZoomScale = 4
    scroll.showsVerticalScrollIndicator = false
    scroll.showsHorizontalScrollIndicator = false
    scroll.contentInsetAdjustmentBehavior = .never
    view.addSubview(scroll)

    imageView.frame = scroll.bounds
    imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    imageView.contentMode = .scaleAspectFit
    scroll.addSubview(imageView)

    spinner.color = .white
    spinner.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    spinner.autoresizingMask = [
      .flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin,
    ]
    view.addSubview(spinner)
    spinner.startAnimating()

    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
    doubleTap.numberOfTapsRequired = 2
    scroll.addGestureRecognizer(doubleTap)

    MediaGalleryImageLoader.load(item.url) { [weak self] image in
      self?.spinner.stopAnimating()
      self?.imageView.image = image
    }
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

  @objc private func doubleTapped(_ tap: UITapGestureRecognizer) {
    if scroll.zoomScale > scroll.minimumZoomScale {
      scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
      return
    }
    let point = tap.location(in: imageView)
    let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
    scroll.zoom(
      to: CGRect(
        x: point.x - size.width / 2, y: point.y - size.height / 2,
        width: size.width, height: size.height
      ),
      animated: true
    )
  }
}

/// Loads a picture for a gallery page, from disk or the network, decoded off
/// the main thread and delivered on it. Cached in memory for the gallery's
/// life so swiping back to a page does not load it twice.
enum MediaGalleryImageLoader {
  private static let cache = NSCache<NSURL, UIImage>()

  static func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
    if let hit = cache.object(forKey: url as NSURL) {
      completion(hit)
      return
    }
    // Foundation.Data, spelled out: flutter_callkit_incoming exports a public
    // class named `Data`, and the bare name is ambiguous in this file.
    let finish: (Foundation.Data?) -> Void = { data in
      let image = data.flatMap { UIImage(data: $0) }?.preparingForDisplay()
      if let image { cache.setObject(image, forKey: url as NSURL) }
      DispatchQueue.main.async { completion(image) }
    }
    if url.isFileURL {
      DispatchQueue.global(qos: .userInitiated).async {
        finish(try? Foundation.Data(contentsOf: url))
      }
    } else {
      URLSession.shared.dataTask(with: url) { data, _, _ in finish(data) }.resume()
    }
  }
}

/// Tells Dart whether any call is up on this phone: ringing, connected or on
/// hold, from the carrier, another VoIP app, or our own CallKit cards.
///
/// The only way to see a call answered from the compact incoming-call banner:
/// the app never resigns active for it, so Flutter's lifecycle stays `resumed`
/// through the whole conversation. Dart asks `active` once and then hears
/// `changed(Bool)` on every edge. A separate observer from AppDelegate's own,
/// which answers ring-watch questions and must not grow a delegate.
final class PhoneCallActivity: NSObject, CXCallObserverDelegate {
  private let observer = CXCallObserver()
  private var channel: FlutterMethodChannel?
  private var last: Bool?

  private var active: Bool {
    observer.calls.contains { !$0.hasEnded }
  }

  func attach(_ channel: FlutterMethodChannel) {
    self.channel = channel
    // nil: delegate callbacks on the main queue, where the channel lives.
    observer.setDelegate(self, queue: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "active":
        let now = self?.active ?? false
        self?.last = now
        result(now)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    let now = active
    if now == last { return }
    last = now
    channel?.invokeMethod("changed", arguments: now)
  }
}
