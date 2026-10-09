import Flutter
import Foundation

/// `monkeyhub/video_shrink`: the app's handle on [VideoShrinkCore], which
/// re-encodes a video over the upload cap until it fits. `shrink` takes the
/// input path and the cap in bytes, and answers the output path or nil. See
/// `lib/media/video_shrink.dart`.
final class VideoShrink: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/video_shrink",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "shrink" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let args = call.arguments as? [String: Any] ?? [:]
            guard let input = args["input"] as? String,
                  let cap = (args["capBytes"] as? NSNumber)?.int64Value else {
                result(nil)
                return
            }
            VideoShrinkCore.shrink(input: URL(fileURLWithPath: input), cap: cap) { path in
                DispatchQueue.main.async { result(path) }
            }
        }
    }
}
