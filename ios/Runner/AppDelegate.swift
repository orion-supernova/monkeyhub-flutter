import Flutter
import UIKit
import UserNotifications
import PushKit
import CallKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CXProviderDelegate {
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

  fileprivate func setCaptureEventSink(_ sink: FlutterEventSink?) {
    captureEventSink = sink
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

    // iOS 13+ requires that every VoIP push report an incoming call to
    // CallKit within ~5s, or the system kills the app and may revoke the
    // PushKit token. We have two paths:
    //   - App in background/killed → show the full CallKit ringer.
    //   - App in foreground → the Convex realtime signal subscription is
    //     already routing the in-app IncomingCallScreen; stacking CallKit
    //     on top produces a jarring dual-UI. Use the "report and
    //     immediately end" escape hatch so we satisfy the API contract
    //     without UI.
    let isForeground = UIApplication.shared.applicationState == .active
    if isForeground {
      NSLog("[voip] foreground push — report-and-end (no CallKit UI)")
      reportAndEndCall(callerName: callerName)
      completion()
      return
    }

    // Stash the CallKit UUID so a follow-up "taken" push can end this
    // specific call with `.answeredElsewhere`.
    if !convexCallId.isEmpty {
      callKitUuidByCallId[convexCallId] = callUuid
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

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      callData,
      fromPushKit: true
    )
    completion()
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
    let uuid = callKitUuidByCallId.removeValue(forKey: convexCallId)
    if let uuid = uuid {
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.saveEndCall(uuid.uuidString, 4)
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
    // .answeredElsewhere needs a one-shot provider; everything else
    // (icon, ringtone, supportsVideo) is irrelevant since we never
    // show its UI.
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
      // Mark answered-elsewhere with a real timestamp so iOS classifies
      // this as a successfully-handled VoIP push and won't surface a
      // missed-call notification.
      self?.foregroundReportProvider.reportCall(
        with: uuid,
        endedAt: Date(),
        reason: .answeredElsewhere
      )
    }
  }

  // MARK: - CXProviderDelegate
  // Apple requires a delegate on every CXProvider, even one we only use
  // for report-and-end. We don't expose CallKit interaction through this
  // provider (the flutter_callkit_incoming plugin owns the user-facing
  // provider), so every action just gets failed/fulfilled minimally.

  func providerDidReset(_ provider: CXProvider) {
    // No persistent state to clear — this provider is fire-and-forget.
  }

  func provider(_ provider: CXProvider, perform action: CXAction) {
    action.fulfill()
  }

  @objc private func _capturedDidChange() {
    captureEventSink?(UIScreen.main.isCaptured)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // monkeyhub/capture — screen-capture/mirroring observation.
    if let captureRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "MonkeyHubCapturePlugin") {
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MonkeyHubLauncherIconPlugin") {
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

    // monkeyhub/voip — exposes the PushKit VoIP token to Dart. Dart calls
    // `getToken` after PushManager.login(userId) and uploads the result to
    // Convex's setVoipToken mutation. We also push token updates over the
    // same channel via `onTokenUpdated` so token rotation propagates.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MonkeyHubVoipPlugin") {
      let channel = FlutterMethodChannel(
        name: "monkeyhub/voip",
        binaryMessenger: registrar.messenger()
      )
      voipChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getToken":
          result(self?.cachedVoipToken)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // monkeyhub/badge — set or clear the app icon badge count.
    // Register the channel via a plugin registrar so we get a binaryMessenger
    // without depending on the rootViewController being a FlutterViewController.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MonkeyHubBadgePlugin") {
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
