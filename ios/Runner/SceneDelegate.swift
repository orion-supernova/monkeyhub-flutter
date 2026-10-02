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
    }
    // Window is set BEFORE super so Flutter's automatic scene-event
    // registration finds the FlutterViewController in the hierarchy.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
