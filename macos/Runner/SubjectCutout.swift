import Cocoa
import FlutterMacOS
import Vision
import CoreImage

/// Lifts the subject out of a photo — the "make a sticker" cut-out. The macOS
/// twin of `ios/Runner/SubjectCutout.swift`; see there for the reasoning.
/// `VNGenerateForegroundInstanceMaskRequest` needs macOS 14; older systems
/// answer `nil` and the Dart side falls back to a shaped crop.
final class SubjectCutout: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/cutout",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isSupported":
                if #available(macOS 14.0, *) { result(true) } else { result(false) }
            case "cutout":
                let args = call.arguments as? [String: Any] ?? [:]
                guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data else {
                    result(nil)
                    return
                }
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
        guard #available(macOS 14.0, *) else { return nil }
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
