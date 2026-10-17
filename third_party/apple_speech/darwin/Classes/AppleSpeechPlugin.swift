// Flutter glue for AppleSpeechCore. Kept separate so the core compiles
// without Flutter (see the comment at the top of AppleSpeechCore.swift).
//
// Channel "monkeyhub/apple_speech". Every call runs in a detached task, off
// the platform thread, and replies on the main thread. Progress goes back to
// Dart as a "progress" call {id, fraction}, throttled to 1% steps.

import Foundation
#if os(iOS)
@preconcurrency import Flutter
#else
@preconcurrency import FlutterMacOS
#endif

public final class AppleSpeechPlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private let core = AppleSpeechCore.shared

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(name: "monkeyhub/apple_speech", binaryMessenger: messenger)
        let instance = AppleSpeechPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let core = self.core
        let reply: @Sendable (Any?) -> Void = { value in
            DispatchQueue.main.async { result(value) }
        }
        switch call.method {
        case "isAvailable":
            Task.detached(priority: .userInitiated) { reply(await core.isAvailable()) }
        case "supportedLocales":
            Task.detached(priority: .userInitiated) { reply(await core.supportedLocales()) }
        case "installedLocales":
            Task.detached(priority: .userInitiated) { reply(await core.installedLocales()) }
        case "bestLocale":
            let preferred = args["preferred"] as? [String] ?? []
            Task.detached(priority: .userInitiated) { reply(await core.bestLocale(preferred)) }
        case "engineFor":
            let locale = args["locale"] as? String ?? ""
            Task.detached(priority: .userInitiated) { reply(await core.engine(for: locale)) }
        case "ensurePermission":
            Task.detached(priority: .userInitiated) { reply(await core.ensurePermission()) }
        case "ensureAssets":
            let locale = args["locale"] as? String ?? ""
            let progress = progressSink(args["id"] as? Int)
            Task.detached(priority: .userInitiated) {
                do {
                    try await core.ensureAssets(locale, onProgress: progress)
                    reply(nil)
                } catch {
                    reply(Self.flutterError(error))
                }
            }
        case "transcribe":
            let path = args["path"] as? String ?? ""
            let locale = args["locale"] as? String ?? ""
            let progress = progressSink(args["id"] as? Int)
            Task.detached(priority: .userInitiated) {
                do {
                    let r = try await core.transcribe(path: path, locale: locale, onProgress: progress)
                    reply(Self.encode(r))
                } catch {
                    reply(Self.flutterError(error))
                }
            }
        case "cancel":
            Task.detached(priority: .userInitiated) {
                await core.cancel()
                reply(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// A throttled progress callback that reports to Dart under [id], or a
    /// no-op when Dart passed no id (no listener).
    private func progressSink(_ id: Int?) -> @Sendable (Double) -> Void {
        guard let id else { return { _ in } }
        let channel = self.channel
        let state = ProgressThrottle()
        return { fraction in
            guard state.shouldSend(fraction) else { return }
            DispatchQueue.main.async {
                channel.invokeMethod("progress", arguments: ["id": id, "fraction": fraction])
            }
        }
    }

    private static func encode(_ r: AppleSpeechResultOut) -> [String: Any] {
        var out: [String: Any] = [
            "text": r.text,
            "locale": r.locale,
            "engine": r.engine,
            "interpolated": r.interpolated,
            "words": r.words.map { w -> [String: Any] in
                var m: [String: Any] = ["text": w.text, "startMs": w.startMs, "endMs": w.endMs]
                if let c = w.confidence { m["confidence"] = c }
                return m
            },
        ]
        if let c = r.confidence { out["confidence"] = c }
        return out
    }

    private static func flutterError(_ error: Error) -> FlutterError {
        let e = AppleSpeechCore.map(error, fallback: .failed)
        return FlutterError(code: e.code.rawValue, message: e.message, details: nil)
    }
}

/// Sends a progress value only when it moved by at least 1%, or hit 0 / 1.
private final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var last = -1.0

    func shouldSend(_ fraction: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if fraction <= 0 || fraction >= 1 || abs(fraction - last) >= 0.01 {
            if fraction == last { return false }
            last = fraction
            return true
        }
        return false
    }
}
