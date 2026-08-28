import Cocoa

/// Everything MonkeyHub draws OUTSIDE its own window: the Dock tile badge and
/// the menu-bar status item.
///
/// One object owns both because they render the same fact — how many things are
/// waiting for you — and two independent copies of that number are exactly how
/// the Dock and the menu bar end up disagreeing in front of the user. The
/// number itself is pushed in from Dart over `monkeyhub/badge` (see
/// `BadgeManager`, lib/push/badge_manager.dart), which is the only place in the
/// app that knows how to compute it.
///
/// It also owns show/hide of the main window, because both surfaces offer that
/// and both have to agree about what "showing" means. On this platform the red
/// X and ⌘W do not close the window, they hide it — the process is the delivery
/// path (`MainFlutterWindow.performClose`), so there is no such thing as
/// closing the window and staying reachable.
final class AppChrome: NSObject {
  static let shared = AppChrome()

  /// Whether the menu-bar item is installed. Native `UserDefaults` rather than
  /// the Dart settings store on purpose: this is read during
  /// `applicationDidFinishLaunching`, long before the engine has booted, and a
  /// menu-bar item that pops in a second after launch reads as a glitch. Dart
  /// gets at it through `monkeyhub/desktop` instead — see
  /// `MacAppChrome.setMenuBarVisible` (lib/services/mac_app_chrome.dart), which
  /// is a remote control for this value, not a second copy of it.
  private static let menuBarVisibleKey = "monkeyhub.menuBarItemVisible"

  private var statusItem: NSStatusItem?
  private var statusItemVisibilityObservation: NSKeyValueObservation?

  /// Last count Dart pushed. Kept so the Dock badge and the item's title can be
  /// re-derived whenever either surface is rebuilt — installing the status item
  /// an hour into a session must not show a stale zero.
  private(set) var unread: Int = 0

  // MARK: - The number

  /// Both surfaces, from one value. Clamped at zero because a negative badge is
  /// a Dart-side arithmetic bug, and rendering "-1" in the Dock ships that bug
  /// to the user instead of swallowing it.
  func setUnread(_ count: Int) {
    let next = max(0, count)
    unread = next
    applyDockBadge()
    applyStatusItemTitle()
  }

  private func applyDockBadge() {
    // nil, not "", is what clears a Dock badge: an empty string still draws the
    // red pill, just with nothing in it.
    NSApp.dockTile.badgeLabel = unread > 0 ? Self.badgeText(unread) : nil
    NSApp.dockTile.display()
  }

  /// The Dock shrinks its badge text to fit, so a five-digit count arrives as
  /// an unreadable smear rather than being truncated. Four digits is where it
  /// stops being legible at the default Dock size.
  private static func badgeText(_ n: Int) -> String {
    n > 9999 ? "9999+" : String(n)
  }

  // MARK: - Menu-bar item

  /// Read straight from `UserDefaults` rather than cached, so the value stays
  /// true after the user drags the item out of the menu bar (see the KVO in
  /// [installStatusItem], which writes that gesture back here).
  var menuBarVisible: Bool {
    get {
      let defaults = UserDefaults.standard
      // Absent means "never chosen" — default to showing it. `bool(forKey:)`
      // alone can't tell that apart from an explicit false.
      guard defaults.object(forKey: Self.menuBarVisibleKey) != nil else {
        return true
      }
      return defaults.bool(forKey: Self.menuBarVisibleKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Self.menuBarVisibleKey)
      applyMenuBarVisibility()
    }
  }

  /// Called once at launch, and again whenever the preference flips.
  func install() {
    applyMenuBarVisibility()
    applyDockBadge()
  }

  private func applyMenuBarVisibility() {
    if menuBarVisible {
      if statusItem == nil { installStatusItem() }
    } else {
      removeStatusItem()
    }
  }

  private func installStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    // `.removalAllowed` is the gesture Mac users already know — ⌘-drag the icon
    // off the menu bar and it goes away. Supporting it means the app's own
    // toggle is no longer the only way out, so the KVO below mirrors the
    // gesture back into the preference; without that the settings switch would
    // sit there claiming "on" over an item the user had just thrown away.
    item.behavior = [.removalAllowed]
    item.autosaveName = "MonkeyHubStatusItem"

    if let button = item.button {
      button.image = Self.monkeyGlyph()
      button.imagePosition = .imageLeading
      // Monospaced digits so the item doesn't jitter sideways as the count
      // ticks 9 → 10 → 11 while someone is reading the menu bar.
      button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      // Both buttons through one action; `statusItemClicked` sorts them out.
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.toolTip = "MonkeyHub — click to show the window, right-click for more"
    }

    statusItemVisibilityObservation = item.observe(\.isVisible, options: [.new]) {
      [weak self] _, change in
      guard let self, let visible = change.newValue else { return }
      guard visible == false else { return }
      // Only the drag-off gesture reaches here as `false` while the item is
      // still installed — our own removal tears the observation down first.
      UserDefaults.standard.set(false, forKey: Self.menuBarVisibleKey)
    }

    statusItem = item
    applyStatusItemTitle()
  }

  private func removeStatusItem() {
    // Order matters: drop the observation first, or removing the item fires it
    // with `isVisible == false` and it looks identical to the user's drag.
    statusItemVisibilityObservation = nil
    if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
    statusItem = nil
  }

  private func applyStatusItemTitle() {
    guard let button = statusItem?.button else { return }
    // Plain `title`, not an attributed string: the menu bar inverts its
    // contents while a menu is open, and only the plain path gets that
    // inversion for free. The leading space is the gap between glyph and count.
    button.title = unread > 0 ? " \(unread > 99 ? "99+" : String(unread))" : ""
    button.setAccessibilityLabel(
      unread > 0 ? "MonkeyHub, \(unread) waiting" : "MonkeyHub"
    )
  }

  // MARK: - Clicks

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    let secondary =
      event?.type == .rightMouseUp
      || event?.modifierFlags.contains(.control) == true
    if secondary {
      showStatusMenu()
    } else {
      toggleWindow()
    }
  }

  /// Popped on demand rather than assigned to `statusItem.menu`, because an
  /// item that owns a menu never delivers a left-click action at all — the menu
  /// swallows it, and the one-click "show me the window" this item exists for
  /// would be gone.
  private func showStatusMenu() {
    guard let item = statusItem else { return }
    item.menu = buildStatusMenu()
    item.button?.performClick(nil)
    item.menu = nil
  }

  private func buildStatusMenu() -> NSMenu {
    let menu = NSMenu()
    // Required for the disabled summary line below to STAY disabled: with
    // auto-enabling on, AppKit re-derives every item's state from whether the
    // responder chain handles its action, and an item with no action at all
    // comes back enabled.
    menu.autoenablesItems = false

    let toggle = NSMenuItem(
      title: isWindowShowing ? "Hide MonkeyHub" : "Open MonkeyHub",
      action: #selector(menuToggleWindow),
      keyEquivalent: ""
    )
    toggle.target = self
    menu.addItem(toggle)

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

    menu.addItem(.separator())
    let quit = NSMenuItem(
      title: "Quit MonkeyHub",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quit.target = NSApp
    menu.addItem(quit)
    return menu
  }

  @objc private func menuToggleWindow() { toggleWindow() }

  // MARK: - The window

  private var window: NSWindow? {
    (NSApp.delegate as? AppDelegate)?.mainFlutterWindow
  }

  /// "Showing" means the person can actually see it — on screen, not
  /// miniaturised, and in the app they are currently looking at. A visible
  /// window behind three other apps is not showing, and the status item's job
  /// there is to bring it forward rather than to hide something the user cannot
  /// see in the first place.
  var isWindowShowing: Bool {
    guard let window else { return false }
    return window.isVisible && !window.isMiniaturized && NSApp.isActive
  }

  func toggleWindow() {
    if isWindowShowing {
      window?.performClose(nil)
    } else {
      showWindow()
    }
  }

  func showWindow() {
    guard let window else { return }
    // Before `makeKeyAndOrderFront`, which does not undo a miniaturise on its
    // own — the window would be ordered to the front of a Space it is not on
    // and stay in the Dock.
    if window.isMiniaturized { window.deminiaturize(nil) }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  // MARK: - Glyph

  /// The menu-bar mark, drawn rather than shipped as an asset.
  ///
  /// The app icon is a full-colour 3D render, which is the one thing a menu-bar
  /// icon cannot be: macOS flattens a template image to a single tint and that
  /// render collapses into an unreadable blob. This is the same monkey reduced
  /// to a silhouette that survives the flattening — and because it is a path,
  /// it stays crisp on every scale factor instead of needing @1x/@2x/@3x PNGs
  /// that drift apart.
  ///
  /// Drawn with the non-zero winding rule, so the sub-paths compose: ears and
  /// head UNION into one silhouette where they overlap, the reversed eyes and
  /// muzzle punch holes in it, and the nostrils — inside the muzzle hole —
  /// wind back to filled. The geometry is tuned so nothing straddles a boundary
  /// it shouldn't: the eyes clear the ears, and the muzzle sits fully inside the
  /// head, because a shape that crosses one of those edges inverts there and
  /// bites a notch out of the face.
  private static func monkeyGlyph() -> NSImage {
    // 18pt is the menu bar's icon box, and the shape is sized to nearly fill it
    // (13.2pt tall, 16.4pt wide): a first cut that sat a couple of points
    // shorter read as visibly undersized next to Wi-Fi and Bluetooth, which is
    // the only reference anyone ever sees it against. `flipped: false` keeps
    // the maths below in AppKit's own bottom-left origin.
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
      func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
      }
      let path = NSBezierPath()
      path.windingRule = .nonZero
      path.append(oval(3.4, 9.7, 2.6, 2.6))            // left ear
      path.append(oval(14.6, 9.7, 2.6, 2.6))           // right ear
      path.append(oval(9.0, 9.0, 5.4, 6.6))            // head
      path.append(oval(7.1, 11.3, 1.2, 1.2).reversed)  // left eye
      path.append(oval(10.9, 11.3, 1.2, 1.2).reversed) // right eye
      path.append(oval(9.0, 6.3, 3.1, 2.4).reversed)   // muzzle
      path.append(oval(8.3, 6.4, 0.45, 0.45))          // left nostril
      path.append(oval(9.7, 6.4, 0.45, 0.45))          // right nostril
      NSColor.black.setFill()
      path.fill()
      return true
    }
    // The whole point: macOS re-tints a template for light bars, dark bars and
    // the inverted look while a menu is open. A non-template image would stay
    // black on a black menu bar.
    image.isTemplate = true
    return image
  }
}
