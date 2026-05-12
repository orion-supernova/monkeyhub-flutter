import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Event sink for screen-capture state changes pushed to Dart.
  fileprivate var captureEventSink: FlutterEventSink?

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
