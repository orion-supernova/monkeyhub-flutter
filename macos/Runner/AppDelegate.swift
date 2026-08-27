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
  // The red X hides the window rather than closing it (see
  // `MainFlutterWindow.performClose`), so this is the braces to that belt —
  // it also covers any other path that manages to close the last window.
  // ⌘Q still quits, and quitting is still the only thing that stops delivery.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
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

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
