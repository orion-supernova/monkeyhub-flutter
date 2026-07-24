import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

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
}
