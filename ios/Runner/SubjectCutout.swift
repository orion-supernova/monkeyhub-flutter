import Flutter
import UIKit
import Vision
import CoreImage

/// Lifts the subject out of a photo — the "make a sticker" cut-out.
///
/// `VNGenerateForegroundInstanceMaskRequest` is the same model behind the
/// Photos app's long-press "lift subject" and iMessage's live stickers, so on
/// iOS 17+ this is the real thing with no model to ship. Older systems answer
/// `nil` and the Dart side falls back to a plain shaped crop.
///
/// `cutout` takes the image bytes and returns a PNG of the subject on a
/// transparent background, cropped to the subject's bounds — or `nil` when the
/// OS is too old or no subject was found (a landscape, a wall of text).
final class SubjectCutout: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/cutout",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isSupported":
                if #available(iOS 17.0, *) { result(true) } else { result(false) }
            case "cutout":
                let args = call.arguments as? [String: Any] ?? [:]
                guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data else {
                    result(nil)
                    return
                }
                // Off the main thread: the request is a few hundred ms of
                // Neural Engine work on a full-resolution photo.
                DispatchQueue.global(qos: .userInitiated).async {
                    let png = SubjectCutout.cutout(data)
                    DispatchQueue.main.async {
                        result(png.map { FlutterStandardTypedData(bytes: $0) })
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    static func cutout(_ data: Data) -> Data? {
        guard #available(iOS 17.0, *) else { return nil }
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return nil
        }
        let handler = VNImageRequestHandler(ciImage: source, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let masked = CIImage(cvPixelBuffer: buffer)
            let context = CIContext()
            guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
            return context.pngRepresentation(of: masked, format: .RGBA8, colorSpace: space)
        } catch {
            NSLog("[cutout] failed: \(error.localizedDescription)")
            return nil
        }
    }
}
