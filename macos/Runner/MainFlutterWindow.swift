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

    // monkeyhub/badge — the unread/request count, pushed in from
    // `BadgeManager` (lib/push/badge_manager.dart) on every change. Mirrors the
    // iOS app-icon badge (see ios/Runner/AppDelegate.swift).
    //
    // `AppChrome` owns what happens to the number, because on this platform it
    // lands on two surfaces — the Dock tile and the menu-bar item — and they
    // have to show the same thing.
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
        AppChrome.shared.setUnread(count)
      }
      result(nil)
    }

    // monkeyhub/desktop — the settings screen's remote control for the
    // menu-bar item. The preference itself lives in native `UserDefaults`
    // (see `AppChrome.menuBarVisible`) because it has to be readable at launch,
    // before the engine exists; this channel is how the Dart switch reads and
    // writes it rather than keeping a second copy that can drift.
    let desktopChannel = FlutterMethodChannel(
      name: "monkeyhub/desktop",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    desktopChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getMenuBarVisible":
        DispatchQueue.main.async {
          result(AppChrome.shared.menuBarVisible)
        }
      case "setMenuBarVisible":
        let args = call.arguments as? [String: Any] ?? [:]
        let visible = (args["visible"] as? Bool) ?? true
        DispatchQueue.main.async {
          AppChrome.shared.menuBarVisible = visible
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  /// The red close button and ⌘W hide the window instead of closing it.
  ///
  /// Closing would tear down the `FlutterViewController` — and with it the
  /// engine, the Dart isolate and the Convex socket — which on macOS is the
  /// whole delivery path: there is no push on this platform to pick up the
  /// slack (see `MessageAlerts`, lib/push/message_alerts.dart). The window is
  /// therefore never actually closed; ⌘Q is what ends the session.
  ///
  /// Hiding, not minimising, on purpose: a hidden window leaves no window-list
  /// entry to be confused by, and comes back instantly and fully rendered from
  /// the Dock (`AppDelegate.applicationShouldHandleReopen`), the menu-bar item
  /// (`AppChrome.toggleWindow`) or Window ▸ MonkeyHub (⌘0). Flutter reports
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
