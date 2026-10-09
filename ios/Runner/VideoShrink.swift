import AVFoundation
import Flutter

/// Re-encodes a video that is over the upload cap until it fits.
///
/// `shrink` takes a file path and the cap in bytes, and answers the path of a
/// new MP4 at or under the cap, or `nil` when even the smallest rendition is
/// too big (a long recording) or the file will not export at all. The caller
/// owns, and deletes, the file it gets back.
///
/// `AVAssetExportSession` presets rather than an `AVAssetWriter` with a bitrate
/// of our own: a preset is a resolution with Apple's tuned bitrate for it, uses
/// the hardware encoder, and keeps rotation, audio and HDR-to-SDR handling
/// right without any of it being written here. The presets are tried largest
/// first; each one's size estimate skips the ones that clearly cannot fit, so a
/// long clip does not pay for three encodes it was never going to keep.
///
/// Kept identical to `macos/Runner/VideoShrink.swift` apart from the import.
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
            shrink(input: URL(fileURLWithPath: input), cap: cap) { path in
                DispatchQueue.main.async { result(path) }
            }
        }
    }

    private static let ladder = [
        AVAssetExportPreset1280x720,
        AVAssetExportPreset960x540,
        AVAssetExportPreset640x480,
        AVAssetExportPresetMediumQuality,
        AVAssetExportPresetLowQuality,
    ]

    static func shrink(input: URL, cap: Int64, done: @escaping (String?) -> Void) {
        let asset = AVURLAsset(url: input)
        func attempt(_ i: Int) {
            guard i < ladder.count else {
                done(nil)
                return
            }
            guard let session = AVAssetExportSession(asset: asset, presetName: ladder[i]) else {
                attempt(i + 1)
                return
            }
            let out = FileManager.default.temporaryDirectory
                .appendingPathComponent("shrink-\(UUID().uuidString).mp4")
            session.outputURL = out
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true
            func export() {
                session.exportAsynchronously {
                    let size = (try? FileManager.default
                        .attributesOfItem(atPath: out.path)[.size] as? NSNumber)?
                        .int64Value ?? -1
                    if session.status == .completed, size > 0, size <= cap {
                        done(out.path)
                        return
                    }
                    try? FileManager.default.removeItem(at: out)
                    attempt(i + 1)
                }
            }
            // The estimate only skips. It runs a little low, so a preset it
            // says is just under the cap is still exported and measured; the
            // last preset always exports, as the final word.
            let last = i == ladder.count - 1
            session.estimateOutputFileLength { length, _ in
                if !last, length > 0, Double(length) > Double(cap) * 1.15 {
                    attempt(i + 1)
                } else {
                    export()
                }
            }
        }
        attempt(0)
    }
}
