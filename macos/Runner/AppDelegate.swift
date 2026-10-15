import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  // Closing the window must NOT quit MonkeyHub. The live socket is still the
  // primary path on this platform — every ring, every in-app ping, every
  // badge update arrives over the Convex connection THIS process holds open.
  // APNs (see "Alert push" below) is the banner for a Mac whose window is
  // hidden or behind other apps, and the backstop for one that was quit; it
  // does not ring and it does not keep the in-app state live. A process that
  // exits with its window is still a person who stops being reachable for
  // calls.
  //
  // The red X and ⌘W hide the window rather than closing it (see
  // `MainFlutterWindow.performClose`), so this is the braces to that belt —
  // it also covers any other path that manages to close the last window.
  // ⌘Q still quits, and quitting is still the only thing that stops delivery.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // At DID-finish rather than WILL-, deliberately: the menu-bar item reaches
  // the main window through `mainFlutterWindow`, and that outlet is only
  // connected once MainMenu.xib has finished loading.
  override func applicationDidFinishLaunching(_ notification: Notification) {
    AppChrome.shared.install()
    installNotificationChannel()
    // Before the launch finishes, so a banner click that IS the launch (the
    // app was quit) reaches `didReceive response`. Assigned here rather than
    // in a plugin: no plugin in this app's macOS set presents notifications.
    UNUserNotificationCenter.current().delegate = self
    // Does NOT prompt — a device token is issued regardless of authorization,
    // exactly as on iOS. Asking is a separate, Dart-driven act
    // (PushManager._maybeRequestNotificationPermission).
    //
    // Needs `com.apple.developer.aps-environment` in the signed entitlements
    // AND a provisioning profile that grants it; without either this fails
    // with "no valid aps-environment entitlement" in
    // `didFailToRegisterForRemoteNotificationsWithError` and the Mac simply
    // never gets a token. See DebugProfile.entitlements.
    NSApp.registerForRemoteNotifications()
  }

  // ── Alert push ───────────────────────────────────────────────────────────
  //
  // The macOS half of `monkeyhub/notifications`, mirroring the iOS channel in
  // ios/Runner/AppDelegate.swift closely enough that PushManager drives both
  // with the same calls. What macOS deliberately does NOT have:
  //   - PushKit / `monkeyhub/voip`. There is no CallKit ringer on the Mac; an
  //     incoming call rings over the live socket. The only call surface APNs
  //     can produce here is the backend's banner rescue (calls.sendCallPush),
  //     sent when no phone could be rung.
  //   - A Notification Service Extension, so no push inbox and no sender face.
  //     `mutable-content` is simply ignored by macOS without an extension.
  //
  // Same APNs topic as iOS (the bundle id is shared), so the backend sends a
  // Mac row exactly as it sends an iPhone row, keyed on its own `apnsEnv`.
  private var cachedApnsToken: String?
  private var notifChannel: FlutterMethodChannel?
  // Queue-until-Dart-exists, as on iOS: the token and a launch-causing tap
  // both arrive before Dart has installed its handler.
  private var pendingNotifEvents: [(method: String, args: [String: Any])] = []
  private var notifDartReady = false
  // Pushed from Dart on every room open/close; read synchronously in
  // `willPresent`.
  private var activeRoomId: String?

  /// Kinds the app already announces itself while it is on screen: a message
  /// gets MessageAlerts' in-app ping (lib/push/message_alerts.dart) and a call
  /// rings over the socket. A banner on top would be the same event twice.
  private static let selfAnnouncedKinds: Set<String> = [
    "message", "call_invite", "group_call_invite",
  ]

  private func installNotificationChannel() {
    guard
      let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else {
      NSLog("[apns] no FlutterViewController; notification channel not installed")
      return
    }
    let channel = FlutterMethodChannel(
      name: "monkeyhub/notifications",
      binaryMessenger: controller.engine.binaryMessenger
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
          DispatchQueue.main.async { result(nil) }
        }
      case "getApnsToken":
        result(self?.cachedApnsToken)
      case "getApnsEnvironment":
        // On the Mac this lives on the notification channel — there is no
        // voip channel to host it, and PushManager asks here on macOS.
        result(Self.apnsEnvironment())
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
        self?.activeRoomId = args["roomId"] as? String
        result(nil)
      case "takePendingEvents":
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
      case "takePushInbox":
        // No Notification Service Extension on the Mac, so nothing is ever
        // staged. Answered rather than left unimplemented so the contract is
        // the same on every Apple platform.
        result([])
      case "clearPushInbox":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func invokeNotifOrQueue(_ method: String, args: [String: Any]) {
    if notifDartReady, let channel = notifChannel {
      channel.invokeMethod(method, arguments: args)
    } else {
      pendingNotifEvents.append((method: method, args: args))
    }
  }

  override func application(
    _ application: NSApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    cachedApnsToken = token
    NSLog("[apns] alert token: \(token)")
    invokeNotifOrQueue("onApnsTokenUpdated", args: ["token": token])
  }

  override func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // The usual cause on a Mac is a profile without the Push Notifications
    // capability: "no valid aps-environment entitlement string found".
    NSLog("[apns] registration failed: \(error.localizedDescription)")
  }

  /// The silent `kind=dismiss` push: a message deleted, or a room read on
  /// another device. Same job as the iOS handler — pull the matching banners
  /// out of Notification Center. Nothing is displayed.
  override func application(
    _ application: NSApplication,
    didReceiveRemoteNotification userInfo: [String: Any]
  ) {
    guard (userInfo["kind"] as? String) == "dismiss" else { return }
    var ids: [String] = []
    if let raw = userInfo["dismissIds"] as? String,
       let bytes = raw.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: bytes) as? [String] {
      ids = parsed
    }
    let roomId = (userInfo["roomId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let center = UNUserNotificationCenter.current()
    if !ids.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: ids)
    }
    let wanted = Set(ids)
    center.getDeliveredNotifications { delivered in
      var doomed: [String] = []
      for n in delivered {
        let info = n.request.content.userInfo
        if let mid = info["messageId"] as? String, wanted.contains(mid) {
          doomed.append(n.request.identifier)
          continue
        }
        if wanted.isEmpty, let roomId, n.request.content.threadIdentifier == roomId {
          doomed.append(n.request.identifier)
        }
      }
      if !doomed.isEmpty {
        center.removeDeliveredNotifications(withIdentifiers: doomed)
      }
    }
  }

  /// Whether someone is looking at the window right now — the native twin of
  /// Dart's `viewerIsPresent` (lib/push/viewer_presence.dart), which on macOS
  /// is Flutter's `resumed`: app frontmost, window visible and key. The two
  /// must agree, because MessageAlerts stays quiet exactly when this says
  /// "nobody is looking" and lets the banner below speak instead.
  private var viewerIsPresent: Bool {
    guard NSApp.isActive, let window = mainFlutterWindow else { return false }
    return window.isVisible && window.isKeyWindow && !window.isMiniaturized
  }

  /// `aps-environment` from the embedded provisioning profile, mapped to the
  /// APNs host ("sandbox" | "production"). On macOS the profile is
  /// Contents/embedded.provisionprofile and the key is the prefixed
  /// `com.apple.developer.aps-environment`. Nil when there is no profile
  /// (e.g. a Developer ID build without one); Dart then falls back to its
  /// build-mode heuristic.
  private static func apnsEnvironment() -> String? {
    let url = Bundle.main.bundleURL
      .appendingPathComponent("Contents")
      .appendingPathComponent("embedded.provisionprofile")
    guard
      let data = try? Data(contentsOf: url),
      let raw = String(data: data, encoding: .ascii),
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
      let apsEnv = (entitlements["com.apple.developer.aps-environment"]
        ?? entitlements["aps-environment"]) as? String
    else {
      return nil
    }
    return apsEnv == "production" ? "production" : "sandbox"
  }

  // Clicking the Dock icon brings the hidden window back. Without this the app
  // would be reachable but unreachable-to-its-owner: an ordered-out window is
  // also dropped from the Window menu, so the Dock is the only way back in.
  //
  // No `NSApp.activate` needed — the Dock click that produced this callback has
  // already activated us.
  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(self)
    }
    return true
  }

  /// The Window ▸ MonkeyHub item (⌘0), and the Dock menu's first entry.
  ///
  /// The stock window commands are not enough on their own once the window is
  /// hidden: AppKit drops an ordered-out window from the Window menu entirely,
  /// so Minimize and Zoom grey out and nothing in the menu bar can bring it
  /// back. This is the item that always can.
  @IBAction func showMainWindow(_ sender: Any?) {
    AppChrome.shared.showWindow()
  }

  /// Right-click on the Dock icon. The count is the same one the badge is
  /// drawn from, so the two cannot disagree.
  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    menu.autoenablesItems = false
    let show = NSMenuItem(
      title: "Show MonkeyHub",
      action: #selector(showMainWindow(_:)),
      keyEquivalent: ""
    )
    show.target = self
    menu.addItem(show)
    let unread = AppChrome.shared.unread
    if unread > 0 {
      menu.addItem(.separator())
      let summary = NSMenuItem(
        title: unread == 1 ? "1 waiting" : "\(unread) waiting",
        action: nil,
        keyEquivalent: ""
      )
      summary.isEnabled = false
      menu.addItem(summary)
    }
    return menu
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
  /// Called only while MonkeyHub is the active app. Anything the app already
  /// announces itself (see `selfAnnouncedKinds`) is silent while the window is
  /// in front of the user — MessageAlerts has pinged, or the call is ringing —
  /// and so is a push for the room on screen. With the window hidden or not
  /// key the banner shows, because then MessageAlerts is the one staying quiet.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let info = notification.request.content.userInfo
    if viewerIsPresent {
      if let kind = info["kind"] as? String, Self.selfAnnouncedKinds.contains(kind) {
        completionHandler([])
        return
      }
      if let roomId = info["roomId"] as? String, !roomId.isEmpty, roomId == activeRoomId {
        completionHandler([])
        return
      }
    }
    completionHandler([.banner, .list, .sound, .badge])
  }

  /// A banner was clicked. Same routing as iOS, plus bringing the window back:
  /// on the Mac it is usually hidden (⌘W hides rather than closes), and
  /// activating the app alone does not order a hidden window front.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    AppChrome.shared.showWindow()
    let info = response.notification.request.content.userInfo
    let kind = info["kind"] as? String
    if let roomId = info["roomId"] as? String, !roomId.isEmpty {
      let focus = info["focus"] as? String ?? ""
      invokeNotifOrQueue("onOpenRoom", args: ["roomId": roomId, "focus": focus])
    } else if kind == "approval" {
      invokeNotifOrQueue("onOpenRequests", args: [:])
    } else if kind == "daily_games" || kind == "game_result" {
      invokeNotifOrQueue("onOpenGames", args: [:])
    } else if kind == "friend_moment",
              let momentId = info["momentId"] as? String, !momentId.isEmpty {
      let focus = info["focus"] as? String ?? ""
      invokeNotifOrQueue("onOpenMoment", args: ["momentId": momentId, "focus": focus])
    }
    completionHandler()
  }
}
