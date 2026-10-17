import Flutter
import UIKit

/// Attaches the UI scene to the pre-warmed FlutterEngine owned by
/// AppDelegate (created in didFinishLaunchingWithOptions, which also runs
/// on background VoIP launches). Building the window manually — instead of
/// letting the Main storyboard instantiate an implicit-engine
/// FlutterViewController — guarantees the whole app runs on exactly ONE
/// engine, whether the process was started by the user or by a PushKit
/// call while the phone was locked.
class SceneDelegate: FlutterSceneDelegate {
  /// The native Liquid Glass tab bar's bridge. Held for the scene's life;
  /// idle until Dart configures it.
  private var nativeChrome: NativeChrome?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let windowScene = scene as? UIWindowScene,
       let appDelegate = UIApplication.shared.delegate as? AppDelegate,
       let engine = appDelegate.flutterEngine {
      let flutterViewController = FlutterViewController(
        engine: engine,
        nibName: nil,
        bundle: nil
      )
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = flutterViewController
      nativeChrome = NativeChrome(
        messenger: engine.binaryMessenger,
        hostController: flutterViewController
      )
      self.window = window
      window.makeKeyAndVisible()
      CaptureGuard.shared.install(in: window)
    }
    // Window is set BEFORE super so Flutter's automatic scene-event
    // registration finds the FlutterViewController in the hierarchy.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}

/// Screenshot, recording and mirroring protection for the whole window.
///
/// iOS has no FLAG_SECURE, and Apple offers no API for this. What it does
/// have is the secure text field: while `isSecureTextEntry` is on, the
/// system leaves that field's internal canvas out of every capture. So the
/// window's layer is moved into that canvas ONCE, when the window first
/// appears, and from then on protection is just the flag. Turning it on or
/// off later never touches the layer tree; re-parenting at runtime is what
/// flashes black.
///
/// Only layers move, never views, so hit testing, the native tab bar and
/// platform views behave exactly as before, and all of them sit inside the
/// window layer and are covered. The keyboard is a separate system window
/// and is not.
///
/// If a future iOS reshapes the field so there is no canvas to borrow,
/// [install] quietly does nothing and `CaptureShield`'s recording overlay
/// is what remains.
final class CaptureGuard {
  static let shared = CaptureGuard()

  private let field = UITextField()
  private(set) var installed = false
  private var wanted = false

  func install(in window: UIWindow) {
    guard !installed, let host = window.layer.superlayer else { return }
    field.isSecureTextEntry = false
    field.isUserInteractionEnabled = false
    field.frame = .zero
    window.addSubview(field)
    guard let canvas = Self.canvas(of: field) else {
      field.removeFromSuperview()
      return
    }
    host.addSublayer(field.layer)
    canvas.addSublayer(window.layer)
    installed = true
    field.isSecureTextEntry = wanted
  }

  func setEnabled(_ enabled: Bool) {
    wanted = enabled
    if !installed, let window = Self.window() { install(in: window) }
    if installed { field.isSecureTextEntry = enabled }
  }

  /// The secure field's drawing canvas: `_UITextLayoutCanvasView` today,
  /// `_UITextFieldCanvasView` before iOS 17. Matched loosely by name first,
  /// then by the position each generation put it in.
  private static func canvas(of field: UITextField) -> CALayer? {
    field.layoutIfNeeded()
    let layers = field.layer.sublayers ?? []
    if let named = layers.first(where: {
      guard let view = $0.delegate as? UIView else { return false }
      return String(describing: type(of: view)).contains("Canvas")
    }) {
      return named
    }
    if #available(iOS 17.0, *) { return layers.last }
    return layers.first
  }

  private static func window() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}
