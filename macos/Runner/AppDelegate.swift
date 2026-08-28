import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Closing the window must NOT quit MonkeyHub. macOS has no push — see the
  // class doc on `MessageAlerts` (lib/push/message_alerts.dart): on this
  // platform every message, ring and badge arrives over the Convex socket THIS
  // process holds open, so a process that exits with its window is a person who
  // silently stops being reachable. On mobile the OS keeps delivering after the
  // app dies; here nothing does.
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
