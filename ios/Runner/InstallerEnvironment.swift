import Flutter
import StoreKit
import UIKit

/// The App Store side of the update check (`lib/update/apple_store.dart`).
///
/// Same channel name as macOS's `InstallerEnvironment.swift` so the Dart side
/// is one file. iOS doesn't need the macOS `environment` method: its receipt
/// already tells TestFlight from the App Store (see `release_channel.dart`).
///
/// - `storefront`: the ISO alpha-3 code of the storefront this device buys
///   from, so the lookup asks the store the user will actually update from.
/// - `showStorePage`: MonkeyHub's App Store page as a sheet over the app.
///   Apple lets no app install its own update; this is the nearest thing, with
///   the page's button reading Update for an installed app.
final class InstallerEnvironment: NSObject, SKStoreProductViewControllerDelegate {
    private static let shared = InstallerEnvironment()

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/installer",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
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

    /// False when there's nothing to present from (backgrounded, or another
    /// store page already up); Dart then opens the App Store itself.
    private func present(appId: String) -> Bool {
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else { return false }
        while let next = top.presentedViewController { top = next }
        if top is SKStoreProductViewController { return false }

        let controller = SKStoreProductViewController()
        controller.delegate = self
        // Presented before the product loads, so the tap answers at once; the
        // sheet fills in when StoreKit returns. Dart has already been told it
        // worked by then, so a load failure falls back here, to the App Store
        // app itself, rather than leaving the user on an empty sheet.
        top.present(controller, animated: true)
        controller.loadProduct(
            withParameters: [SKStoreProductParameterITunesItemIdentifier: appId]
        ) { loaded, error in
            guard !loaded else { return }
            NSLog("[installer] store page failed: \(error?.localizedDescription ?? "unknown")")
            DispatchQueue.main.async {
                controller.dismiss(animated: true) {
                    if let url = URL(string: "itms-apps://apps.apple.com/app/id\(appId)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        return true
    }

    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true)
    }
}
