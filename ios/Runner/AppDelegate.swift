import Flutter
import UIKit
import UserNotifications
import PushKit
import CallKit
import AVKit
import AVFoundation
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

  // PushKit registry — must be retained by the app delegate for the whole
  // lifetime, otherwise iOS never delivers VoIP pushes. Token is read by Dart
  // via the `monkeyhub/voip` method channel after registration completes.
  private var voipRegistry: PKPushRegistry?
  private var cachedVoipToken: String?
  private var voipChannel: FlutterMethodChannel?
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
    // Start Dart immediately, headless if need be. On a background VoIP
    // launch this is what makes flutter_callkit_incoming register (its
    // sharedInstance is set inside GeneratedPluginRegistrant.register) so
    // the CallKit ringer can show, and lets the app restore auth + attach
    // signaling so an answered call actually connects.
    let engine = FlutterEngine(name: "main")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    registerAppChannels(on: engine)
    flutterEngine = engine

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_capturedDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

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

    // Ordinary APNs. Taking the delegate is safe: FlutterAppDelegate doesn't
    // claim it (it routes remote notifications through its plugin lifecycle
    // delegate instead), and flutter_callkit_incoming only *offers* a
    // willPresent helper — it never assigns itself.
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
    let info = response.notification.request.content.userInfo
    if let roomId = info["roomId"] as? String, !roomId.isEmpty {
      invokeNotifOrQueue("onOpenRoom", args: ["roomId": roomId])
      completionHandler()
      return
    }
    if (info["kind"] as? String) == "approval" {
      invokeNotifOrQueue("onOpenRequests", args: [:])
      completionHandler()
      return
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    cachedVoipToken = token
    NSLog("[voip] PushKit token: \(token)")
    voipChannel?.invokeMethod("onTokenUpdated", arguments: ["token": token])
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    cachedVoipToken = nil
    voipChannel?.invokeMethod("onTokenUpdated", arguments: ["token": NSNull()])
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
    let convexCallId = (dict["callId"] as? String) ?? ""

    // "taken" push: a sibling device accepted/rejected this call.
    // Dismiss CallKit with `.answeredElsewhere` so the system shows the
    // correct dismissal animation instead of a silent kill. We still must
    // satisfy Apple's "every push reports an incoming call" contract —
    // reportCallEndedElsewhere does that via the foregroundReportProvider.
    if kind == "taken" {
      NSLog("[voip] taken push — answered elsewhere callId=\(convexCallId)")
      reportCallEndedElsewhere(convexCallId: convexCallId)
      completion()
      return
    }

    // Convex callIds are NOT RFC-4122 UUIDs. flutter_callkit_incoming
    // force-unwraps `UUID(uuidString:)` on `data.uuid` at line 286 of
    // SwiftFlutterCallkitIncomingPlugin.swift, so passing our callId
    // crashes the app. Mint a proper UUID for CallKit and preserve the
    // Convex callId in `extra` for Dart-side diagnostics.
    let callUuid = UUID()
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
    if !convexCallId.isEmpty {
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
    callData.extra = [
      "callId": convexCallId,
      "callerName": callerName,
      "callType": callType,
      "rawPayload": dict,
    ] as NSDictionary
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
    // report-and-end for this push. Use the existing escape hatch.
    reportAndEndCall(callerName: "Call")
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

  @objc private func _capturedDidChange() {
    captureEventSink?(UIScreen.main.isCaptured)
  }

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

    if !ids.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // Room-level sweep (sent when the user reads the room elsewhere).
    // removeDeliveredNotifications is asynchronous and fire-and-forget, so we
    // must not resolve the completion handler until the enumeration is done —
    // otherwise iOS can suspend us mid-removal.
    if let roomId, ids.isEmpty {
      center.getDeliveredNotifications { delivered in
        let roomIds = delivered
          .filter { $0.request.content.threadIdentifier == roomId }
          .map { $0.request.identifier }
        if !roomIds.isEmpty {
          center.removeDeliveredNotifications(withIdentifiers: roomIds)
        }
        completionHandler(.newData)
      }
    } else {
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
