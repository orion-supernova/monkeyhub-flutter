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
      invokeNotifOrQueue("onOpenMoment", args: ["momentId": momentId])
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
    let callUuid = isGroup && !convexCallId.isEmpty
      ? Self.derivedCallUuid(convexCallId)
      : UUID()
    let callerName = (dict["callerName"] as? String) ?? "Incoming call"
    let callerHandle = (dict["callerHandle"] as? String) ?? callerName
    let callType = ((dict["callType"] as? String) == "video") ? 1 : 0

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
    if !convexCallId.isEmpty && !isGroup {
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

    showIncomingWithRetry(callData, convexCallId: convexCallId, pushCompletion: completion)
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
    // A provider reset means the system tore down every call UI — without
    // telling Dart, the WebRTC session (and the microphone) lived on
    // headless. Dart answers with a full local teardown.
    invokeVoipOrQueue("onProviderReset", args: [:])
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    if let callId = fallbackCallIdByUuid[action.callUUID] {
      NSLog("[voip] fallback card answered callId=\(callId)")
      invokeVoipOrQueue("onFallbackAnswer", args: ["callId": callId])
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
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
  private func registerAppChannels(on engine: FlutterEngine) {
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
          // iOS has no FLAG_SECURE equivalent — the Dart layer renders the
          // protection overlay using the event channel below. This method
          // is a no-op on iOS but kept for API symmetry with Android.
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
        default:
          result(FlutterMethodNotImplemented)
        }
      }
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
        default:
          result(FlutterMethodNotImplemented)
        }
      }
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
          }
          result(nil)
        case "deactivateAudioSession":
          // Belt to the vendored plugin's deactivate-on-end (PATCH 1 in
          // third_party/flutter_callkit_incoming): Dart calls this after
          // every local teardown. Strictly a no-op while ANY call UI is
          // alive — the plugin's cards or our fallback provider's — so it
          // can never yank the session out from under a real call. Covers
          // the activation orderings the plugin can't see (e.g. WebRTC
          // activated the raw session before any CallKit call existed, as
          // in group calls, which never raise a card at all).
          if let self = self {
            let pluginBusy =
              !(SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []).isEmpty
            if !pluginBusy && self.fallbackCallIdByUuid.isEmpty {
              do {
                try AVAudioSession.sharedInstance()
                  .setActive(false, options: [.notifyOthersOnDeactivation])
              } catch {
                NSLog("[voip] deactivateAudioSession failed: \(error)")
              }
            }
          }
          result(nil)
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
  /// cheaper thing to be wrong about than a one-way call.
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
