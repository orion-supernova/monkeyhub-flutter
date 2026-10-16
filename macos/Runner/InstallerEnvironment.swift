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
final class InstallerEnvironment: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/installer",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "environment" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard #available(macOS 13.0, *) else {
                result(nil)
                return
            }
            Task {
                let env = await InstallerEnvironment.environment()
                DispatchQueue.main.async { result(env) }
            }
        }
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
