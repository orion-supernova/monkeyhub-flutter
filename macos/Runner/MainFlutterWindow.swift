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

    super.awakeFromNib()
  }
}
