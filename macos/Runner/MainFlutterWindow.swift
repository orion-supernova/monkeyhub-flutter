import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Floor the window size so the responsive shell always has room for its
    // rail + panes and never collapses into a degenerate sliver.
    self.minSize = NSSize(width: 480, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // monkeyhub/device — exposes the human-readable Mac name (set in
    // System Settings → General → About → Name). Used by the global
    // "Move call here" pill so sibling devices can render
    // "On Bob's MacBook Pro".
    let deviceChannel = FlutterMethodChannel(
      name: "monkeyhub/device",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    deviceChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getDisplayName":
        result(Host.current().localizedName)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // monkeyhub/badge — set or clear the Dock icon badge. Mirrors the iOS
    // app-icon badge (see ios/Runner/AppDelegate.swift). Driven by
    // BadgeManager's unread/request count.
    let badgeChannel = FlutterMethodChannel(
      name: "monkeyhub/badge",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    badgeChannel.setMethodCallHandler { call, result in
      guard call.method == "set" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let count = (args["count"] as? Int) ?? 0
      DispatchQueue.main.async {
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
      }
      result(nil)
    }

    super.awakeFromNib()
  }

  /// The red close button hides the window instead of closing it.
  ///
  /// Closing would tear down the `FlutterViewController` — and with it the
  /// engine, the Dart isolate and the Convex socket — which on macOS is the
  /// whole delivery path: there is no push on this platform to pick up the
  /// slack (see `MessageAlerts`, lib/push/message_alerts.dart). The window is
  /// therefore never actually closed; ⌘Q is what ends the session.
  ///
  /// Hiding, not minimising, on purpose: a hidden window leaves no window-list
  /// entry to be confused by, and comes back instantly and fully rendered from
  /// the Dock (`AppDelegate.applicationShouldHandleReopen`). Flutter reports
  /// `AppLifecycleState.hidden` for it, which is exactly the `away` presence
  /// this state deserves — the person is reachable, just not looking.
  override func performClose(_ sender: Any?) {
    // Full screen has to be left first. Ordering a full-screen window out
    // strands its Space: the display stays on an empty black desktop the user
    // has to swipe out of, with no window left to explain why.
    guard styleMask.contains(.fullScreen) else {
      orderOut(sender)
      return
    }
    var token: NSObjectProtocol?
    token = NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification,
      object: self,
      queue: .main
    ) { [weak self] _ in
      if let token = token {
        NotificationCenter.default.removeObserver(token)
      }
      self?.orderOut(nil)
    }
    toggleFullScreen(sender)
  }
}
