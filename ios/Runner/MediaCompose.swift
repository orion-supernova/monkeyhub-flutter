import AVFoundation
import Flutter
import Foundation

/// `monkeyhub/media_compose`: joins the segments of a paused-and-resumed
/// voice or video note and trims the result. `compose` takes `paths` (in
/// order), `outPath`, optional `startMs`/`endMs` on the joined timeline and
/// `video`, and answers `{durationMs}` — the true length of what it wrote —
/// or a `compose_failed` error. The caller owns, and deletes, every file
/// involved. See `lib/composer/capture_compose.dart`.
///
/// One `AVMutableComposition` with each segment's tracks laid back to back,
/// then one `AVAssetExportSession` whose `timeRange` is the trim:
/// - Voice: `AVAssetExportPresetAppleM4A`. It re-encodes the AAC, which is
///   seconds of work for a voice note and makes the joins click-free (AAC
///   priming frames at each boundary would otherwise be audible).
/// - Video: passthrough when every segment's track has the same size and
///   `preferredTransform` (the normal case — one lens, one orientation), so the
///   front camera's transform is carried over untouched. When they differ (a
///   flip while paused can change both), passthrough cannot honour a per-
///   segment transform, so it re-encodes at 640x480 through a video
///   composition that fits each segment into the *first* segment's displayed
///   size, aspect-fill and centred. If passthrough itself fails, the same
///   re-encode is the fallback.
final class MediaCompose: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/media_compose",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "compose" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let args = call.arguments as? [String: Any] ?? [:]
            guard let paths = args["paths"] as? [String], !paths.isEmpty,
                  let outPath = args["outPath"] as? String else {
                result(FlutterError(code: "compose_failed",
                                    message: "paths and outPath are required",
                                    details: nil))
                return
            }
            // A Dart null arrives as NSNull, which the casts turn into nil.
            let startMs = (args["startMs"] as? NSNumber)?.int64Value
            let endMs = (args["endMs"] as? NSNumber)?.int64Value
            let video = (args["video"] as? Bool) ?? false
            // Off the main thread: loading tracks synchronously reads the files.
            DispatchQueue.global(qos: .userInitiated).async {
                MediaCompose.compose(paths: paths, outPath: outPath, startMs: startMs,
                                     endMs: endMs, video: video) { durationMs, message in
                    DispatchQueue.main.async {
                        if let ms = durationMs {
                            result(["durationMs": NSNumber(value: ms)])
                        } else {
                            result(FlutterError(code: "compose_failed",
                                                message: message, details: nil))
                        }
                    }
                }
            }
        }
    }

    /// One segment's video, where it sits in the composition.
    private struct Piece {
        let start: CMTime
        let transform: CGAffineTransform
        let size: CGSize
    }

    private static func compose(paths: [String], outPath: String, startMs: Int64?,
                                endMs: Int64?, video: Bool,
                                done: @escaping (Int64?, String?) -> Void) {
        let composition = AVMutableComposition()
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrack: AVMutableCompositionTrack? = video
            ? composition.addMutableTrack(withMediaType: .video,
                                          preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil
        var pieces: [Piece] = []
        var cursor = CMTime.zero

        for path in paths {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path),
                                   options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let sourceVideo = video ? asset.tracks(withMediaType: .video).first : nil
            let sourceAudio = asset.tracks(withMediaType: .audio).first
            // The segment's span is its video's when it has one: that is what
            // the next segment's picture must follow on from.
            guard let window = sourceVideo?.timeRange ?? sourceAudio?.timeRange,
                  window.duration > .zero else { continue }
            do {
                if let source = sourceVideo, let track = videoTrack {
                    try track.insertTimeRange(window, of: source, at: cursor)
                    pieces.append(Piece(start: cursor, transform: source.preferredTransform,
                                        size: source.naturalSize))
                }
                if let source = sourceAudio, let track = audioTrack {
                    // Only the audio inside the video's window, placed at the
                    // same offset it had in its own file: sync survives, and a
                    // few ms of trailing audio cannot overlap the next segment.
                    let overlap = CMTimeRangeGetIntersection(window, otherRange: source.timeRange)
                    if overlap.duration > .zero {
                        try track.insertTimeRange(
                            overlap, of: source,
                            at: CMTimeAdd(cursor, CMTimeSubtract(overlap.start, window.start)))
                    }
                }
            } catch {
                done(nil, "insert failed: \(error.localizedDescription)")
                return
            }
            cursor = CMTimeAdd(cursor, window.duration)
        }

        guard cursor > .zero else {
            done(nil, "no media in segments")
            return
        }
        if let track = audioTrack, track.segments.isEmpty {
            composition.removeTrack(track)
        }
        if let track = videoTrack, track.segments.isEmpty {
            composition.removeTrack(track)
        }

        var start = CMTime(value: startMs ?? 0, timescale: 1000)
        var end = endMs.map { CMTime(value: $0, timescale: 1000) } ?? cursor
        start = max(.zero, min(start, cursor))
        end = min(end, cursor)
        guard end > start else {
            done(nil, "empty trim range")
            return
        }
        let range = CMTimeRange(start: start, end: end)
        let out = URL(fileURLWithPath: outPath)

        guard video, let first = pieces.first, let track = videoTrack,
              !track.segments.isEmpty else {
            export(composition, preset: AVAssetExportPresetAppleM4A, fileType: .m4a,
                   range: range, videoComposition: nil, to: out) { ms, message in
                done(ms, message)
            }
            return
        }

        let uniform = pieces.allSatisfy {
            $0.size == first.size && $0.transform == first.transform
        }
        let fitted = normalised(pieces, track: track, duration: cursor)
        if uniform {
            // Passthrough ignores any video composition; the track's own
            // transform is what keeps the front camera upright.
            track.preferredTransform = first.transform
            export(composition, preset: AVAssetExportPresetPassthrough, fileType: .mp4,
                   range: range, videoComposition: nil, to: out) { ms, message in
                if ms != nil {
                    done(ms, message)
                    return
                }
                // The layer instructions carry each segment's transform on
                // this path; leaving the track's in place would apply it twice.
                track.preferredTransform = .identity
                MediaCompose.export(composition, preset: AVAssetExportPreset640x480, fileType: .mp4,
                       range: range, videoComposition: fitted, to: out, done: done)
            }
        } else {
            export(composition, preset: AVAssetExportPreset640x480, fileType: .mp4,
                   range: range, videoComposition: fitted, to: out, done: done)
        }
    }

    /// A video composition that draws every segment upright, filling the first
    /// segment's displayed size. The composition track's own transform is left
    /// at identity on this path — the layer instructions carry each segment's.
    private static func normalised(_ pieces: [Piece], track: AVMutableCompositionTrack,
                                   duration: CMTime) -> AVMutableVideoComposition? {
        guard let first = pieces.first else { return nil }
        let shown = CGRect(origin: .zero, size: first.size).applying(first.transform)
        let width = (abs(shown.width) / 2).rounded() * 2
        let height = (abs(shown.height) / 2).rounded() * 2
        guard width > 0, height > 0 else { return nil }
        let render = CGSize(width: width, height: height)

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        for piece in pieces {
            layer.setTransform(fit(piece, into: render), at: piece.start)
        }
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layer]

        let composition = AVMutableVideoComposition()
        composition.renderSize = render
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.instructions = [instruction]
        return composition
    }

    /// The segment's own transform, then moved to the origin, scaled to cover
    /// [render] and centred in it.
    private static func fit(_ piece: Piece, into render: CGSize) -> CGAffineTransform {
        let rect = CGRect(origin: .zero, size: piece.size).applying(piece.transform)
        guard rect.width > 0, rect.height > 0 else { return piece.transform }
        let scale = max(render.width / rect.width, render.height / rect.height)
        let dx = (render.width - rect.width * scale) / 2
        let dy = (render.height - rect.height * scale) / 2
        return piece.transform
            .concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: dx, y: dy))
    }

    private static func export(_ asset: AVAsset, preset: String, fileType: AVFileType,
                               range: CMTimeRange,
                               videoComposition: AVVideoComposition?, to out: URL,
                               done: @escaping (Int64?, String?) -> Void) {
        try? FileManager.default.removeItem(at: out)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            done(nil, "no export session for \(preset)")
            return
        }
        session.outputURL = out
        // The camera writes QuickTime-branded files; passthrough into an MP4
        // container is supported for H.264/AAC, but answer with .mov rather
        // than fail on the rare build where it is not offered.
        if session.supportedFileTypes.contains(fileType) {
            session.outputFileType = fileType
        } else if fileType == .mp4, session.supportedFileTypes.contains(.mov) {
            session.outputFileType = .mov
        } else {
            done(nil, "\(preset) cannot write \(fileType.rawValue)")
            return
        }
        session.timeRange = range
        session.shouldOptimizeForNetworkUse = true
        if let composition = videoComposition {
            session.videoComposition = composition
        }
        session.exportAsynchronously {
            guard session.status == .completed else {
                try? FileManager.default.removeItem(at: out)
                done(nil, session.error?.localizedDescription ?? "export \(session.status.rawValue)")
                return
            }
            let length = AVURLAsset(url: out).duration
            let seconds = CMTimeGetSeconds(length)
            guard seconds.isFinite, seconds > 0 else {
                try? FileManager.default.removeItem(at: out)
                done(nil, "export produced no media")
                return
            }
            done(Int64((seconds * 1000).rounded()), nil)
        }
    }
}
