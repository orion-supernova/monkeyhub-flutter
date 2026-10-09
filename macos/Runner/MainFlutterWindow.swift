import Cocoa
import FlutterMacOS

/// `NSDraggingDestination` is declared here rather than inherited, and that is
/// not a formality: `NSWindow` picks the protocol up from Objective-C, so Swift
/// sees no methods to `override` — writing `override func draggingEntered` does
/// not compile, and leaving the conformance off means AppKit's
/// `respondsToSelector:` check finds nothing and the window silently refuses
/// every drag.
class MainFlutterWindow: NSWindow, NSDraggingDestination {
  /// Receives files dragged onto this window from Finder and every other Mac
  /// app. Registered lazily — see [DropDestination] for why nothing accepts a
  /// drag until Dart says it is listening.
  ///
  /// Held here because the destination has to outlive `awakeFromNib`, and
  /// implemented as forwarding methods below rather than by assigning a
  /// delegate: `NSDraggingDestination` is an informal protocol that AppKit
  /// invokes on the WINDOW itself, so the window is the only object that can
  /// receive it.
  private var dropDestination: DropDestination?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Floor the CONTENT size (not the frame, which counts the title bar) at
    // the width the side rail + split shell needs — `Breakpoints.split` in
    // lib/theme/layout.dart is 720, and this sits above it with room to
    // spare. A desktop window that could shrink to phone width would swap
    // its whole chrome for the bottom pill mid-drag, which no Mac app does.
    let minContent = NSSize(width: 760, height: 560)
    self.contentMinSize = minContent
    // Come back where the user left it, like every Mac app. The saved frame
    // is read BEFORE the autosave name is set, because setting the name
    // first would immediately write the nib's default frame over it. A frame
    // saved under an older, smaller floor is grown to the new one rather than
    // trusted, so the first launch after this change cannot open in the
    // phone layout.
    let autosaveName = "MonkeyHubMainWindow"
    if self.setFrameUsingName(autosaveName) {
      let content = self.contentRect(forFrameRect: self.frame)
      if content.width < minContent.width || content.height < minContent.height {
        var grown = content
        grown.size.width = max(content.width, minContent.width)
        grown.size.height = max(content.height, minContent.height)
        self.setFrame(self.frameRect(forContentRect: grown), display: true)
      }
    }
    self.setFrameAutosaveName(autosaveName)

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
      case "getDiskSpace":
        // Data and Storage's "uses N% of your free space"; same keys as iOS.
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [
          .volumeAvailableCapacityForImportantUsageKey,
          .volumeTotalCapacityKey,
        ])
        result([
          "free": NSNumber(value: values?.volumeAvailableCapacityForImportantUsage ?? 0),
          "total": NSNumber(value: values?.volumeTotalCapacity ?? 0),
        ])
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

    // monkeyhub/preview — QuickLook for a received document. A singleton
    // because `QLPreviewPanel` is app-wide and there is exactly one of it.
    DocumentPreview.register(
      with: flutterViewController.engine.binaryMessenger
    )

    // monkeyhub/cutout — lifts a photo's subject out for "make a sticker".
    SubjectCutout.register(
      with: flutterViewController.engine.binaryMessenger
    )

    // monkeyhub/video_shrink — re-encodes a video over the upload cap.
    VideoShrink.register(
      with: flutterViewController.engine.binaryMessenger
    )

    // monkeyhub/drop — desktop drag-and-drop. Constructed here (it owns its
    // own channel) and reached by the four forwarding methods below.
    dropDestination = DropDestination(
      window: self,
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }

  // ─────────────────── NSDraggingDestination, forwarded ───────────────────
  //
  // Every one of these is on the hot path of a live drag: AppKit calls
  // `draggingUpdated` for as long as the pointer is inside the window. They
  // must return synchronously and must not block — see `DropDestination` for
  // how the answer stays in step with Dart without waiting on it.
  //
  // On the WINDOW rather than on a view, because the dragging destination is
  // found by walking down from the view under the cursor and the `FlutterView`
  // registers no dragged types — so nothing inside the engine's hierarchy is
  // ever a candidate. AppKit consults the window when no view accepts.

  func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    return dropDestination?.draggingEntered(sender) ?? []
  }

  func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
    return dropDestination?.draggingUpdated(sender) ?? []
  }

  func draggingExited(_ sender: (any NSDraggingInfo)?) {
    dropDestination?.draggingExited(sender)
  }

  func draggingEnded(_ sender: any NSDraggingInfo) {
    dropDestination?.draggingEnded(sender)
  }

  func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    return true
  }

  func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    return dropDestination?.performDragOperation(sender) ?? false
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
