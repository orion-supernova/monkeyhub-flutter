import Flutter
import UIKit

/// The app's bottom bar, drawn by iOS itself so it is real Liquid Glass.
///
/// A plain `UITabBar` added as a SIBLING above the Flutter view — deliberately
/// not a `UiKitView` platform view. Any platform view on screen drops every
/// Flutter list from 120 Hz to bursts of 60 (flutter/flutter#190815, no opt-out
/// since 3.38) and doubles the cost of each `BackdropFilter` beside it
/// (flutter/flutter#138656). A sibling view is outside Flutter's compositor
/// entirely, and its glass still samples the Flutter pixels underneath,
/// because those are just the Metal layer below it in the view hierarchy.
///
/// Dart owns all state (`lib/screens/navigation/native_tab_bar.dart`) and
/// pushes it here over `monkeyhub/native_chrome`; this side only renders and
/// reports taps. Every Dart call is idempotent, so a hot restart — which
/// leaves this view alive under a fresh isolate — resyncs by just calling
/// `configure` again.
final class NativeChrome: NSObject, UITabBarDelegate {
  private let channel: FlutterMethodChannel
  private weak var hostController: UIViewController?
  private var bar: UITabBar?

  /// The Dart widget instance that owns the bar. A theme change rebuilds the
  /// shell, so the new instance configures the bar BEFORE the old one is
  /// disposed — without an owner, the old dispose tore down the new bar and
  /// the tab bar vanished. Calls from anyone but the current owner are
  /// ignored.
  private var owner: Int = -1

  /// Takes the controller, never its view. Reading `.view` here — during scene
  /// connection, before the window is visible and before FlutterSceneDelegate
  /// has registered the controller — forces FlutterViewController to load its
  /// view early, and the engine then never presents a frame: a black screen
  /// with only this bar on it. The view is looked up when Dart first
  /// configures the bar, by which point the app is running and on screen.
  init(messenger: FlutterBinaryMessenger, hostController: UIViewController) {
    channel = FlutterMethodChannel(
      name: "monkeyhub/native_chrome",
      binaryMessenger: messenger
    )
    self.hostController = hostController
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let from = args["owner"] as? Int ?? -1
    if call.method != "isSupported" && call.method != "configure"
        && from != owner {
      result(nil)
      return
    }
    switch call.method {
    case "isSupported":
      if #available(iOS 26, *) { result(true) } else { result(false) }
    case "configure":
      owner = from
      configure(args)
      result(nil)
    case "update":
      update(args)
      result(nil)
    case "setVisible":
      let visible = args["visible"] as? Bool ?? true
      bar?.isUserInteractionEnabled = visible
      UIView.animate(withDuration: visible ? 0.25 : 0.15) {
        self.bar?.alpha = visible ? 1 : 0
      }
      result(nil)
    case "dispose":
      bar?.removeFromSuperview()
      bar = nil
      owner = -1
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configure(_ args: [String: Any]) {
    guard #available(iOS 26, *),
          let host = hostController?.viewIfLoaded,
          host.window != nil
    else { return }
    bar?.removeFromSuperview()
    let items = args["items"] as? [[String: String]] ?? []
    let tabBar = UITabBar()
    tabBar.delegate = self
    tabBar.items = items.enumerated().map { index, item in
      let symbol = item["symbol"] ?? "circle"
      let tabItem = UITabBarItem(
        title: item["label"],
        image: UIImage(systemName: symbol),
        selectedImage: UIImage(systemName: item["selectedSymbol"] ?? symbol)
      )
      tabItem.tag = index
      return tabItem
    }
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(tabBar)
    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      tabBar.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ])
    bar = tabBar
  }

  private func update(_ args: [String: Any]) {
    guard let bar, let items = bar.items else { return }
    if let selected = args["selected"] as? Int, selected < items.count {
      bar.selectedItem = items[selected]
    }
    if let badges = args["badges"] as? [Int] {
      for (index, count) in badges.enumerated() where index < items.count {
        items[index].badgeValue = count > 0 ? (count > 99 ? "99+" : "\(count)") : nil
      }
    }
    if let tint = args["tint"] as? Int {
      bar.tintColor = UIColor(argb: tint)
    }
    if let dark = args["dark"] as? Bool {
      // The app's theme, not the phone's: Midnight on a phone in light mode
      // still wants dark glass.
      bar.overrideUserInterfaceStyle = dark ? .dark : .light
    }
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    // Fires for the already-selected item too; Dart decides whether that is a
    // switch or a reselect-to-top.
    channel.invokeMethod("select", arguments: item.tag)
  }
}

private extension UIColor {
  convenience init(argb: Int) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
