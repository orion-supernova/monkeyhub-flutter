import Cocoa
import FlutterMacOS
import StoreKit

/// Where this copy of the app came from: the Mac App Store, TestFlight, or
/// neither.
///
/// macOS reports no installer at all to Flutter, and one binary goes to
/// TestFlight first and the Mac App Store after approval, so the build-time
/// channel (`macos-testflight`) is right for only half its life. StoreKit's
/// `AppTransaction` knows: `.production` is a store install, `.sandbox` is
/// TestFlight. It needs macOS 13; older systems answer nil and the Dart side
/// keeps the build-time channel. See `lib/update/release_channel.dart`.
///
/// The same channel carries the App Store side of the update check
/// (`lib/update/apple_store.dart`), shared with iOS's file of the same name:
/// `storefront` (ISO alpha-3, for the version lookup) and `showStorePage`
/// (the store page as a sheet on the main window; the nearest thing to an
/// in-place update Apple allows).
final class InstallerEnvironment: NSObject, SKStoreProductViewControllerDelegate {
    private static let shared = InstallerEnvironment()

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/installer",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "environment":
                guard #available(macOS 13.0, *) else {
                    result(nil)
                    return
                }
                Task {
                    let env = await InstallerEnvironment.environment()
                    DispatchQueue.main.async { result(env) }
                }
            case "storefront":
                Task {
                    let code = await Storefront.current?.countryCode
                    DispatchQueue.main.async { result(code) }
                }
            case "showStorePage":
                let args = call.arguments as? [String: Any] ?? [:]
                guard let appId = args["appId"] as? String, !appId.isEmpty else {
                    result(false)
                    return
                }
                DispatchQueue.main.async {
                    result(shared.present(appId: appId))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// False when there's no window to hang the sheet on; Dart then opens the
    /// Mac App Store itself. A product that fails to load falls back the same
    /// way from here, since Dart has already been told the sheet is up.
    private func present(appId: String) -> Bool {
        guard let host = (NSApp.keyWindow ?? NSApp.mainWindow)?.contentViewController,
              host.presentedViewControllers?.contains(where: { $0 is SKStoreProductViewController }) != true
        else { return false }

        let controller = SKStoreProductViewController()
        controller.delegate = self
        host.presentAsSheet(controller)
        controller.loadProduct(
            withParameters: [SKStoreProductParameterITunesItemIdentifier: appId]
        ) { loaded, error in
            guard !loaded else { return }
            NSLog("[installer] store page failed: \(error?.localizedDescription ?? "unknown")")
            DispatchQueue.main.async {
                controller.dismiss(nil)
                if let url = URL(string: "macappstore://apps.apple.com/app/id\(appId)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        return true
    }

    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(nil)
    }

    @available(macOS 13.0, *)
    static func environment() async -> String? {
        do {
            // Unverified still says where it came from; the update prompt is
            // not a security decision.
            let shared = try await AppTransaction.shared
            let tx: AppTransaction
            switch shared {
            case .verified(let t): tx = t
            case .unverified(let t, _): tx = t
            }
            switch tx.environment {
            case .production: return "production"
            case .sandbox: return "sandbox"
            case .xcode: return "xcode"
            default: return nil
            }
        } catch {
            return nil
        }
    }
}
