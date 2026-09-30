// Lifts the subject out of a picture onto a transparent background, with the
// same Vision request the app's own sticker maker uses (SubjectCutout.swift).
//
//   swift tool/stickers/cutout.swift <in.png> <out.png>
//
// Needs macOS 14. The output is cropped to the subject.
import AppKit
import CoreImage
import Vision

let args = CommandLine.arguments
guard args.count == 3,
      let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("usage: cutout.swift <in> <out>\n".data(using: .utf8)!)
    exit(2)
}
let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: cg)
try handler.perform([request])
guard let observation = request.results?.first,
      !observation.allInstances.isEmpty else {
    FileHandle.standardError.write("no subject found\n".data(using: .utf8)!)
    exit(1)
}
let buffer = try observation.generateMaskedImage(
    ofInstances: observation.allInstances, from: handler,
    croppedToInstancesExtent: true)
let ci = CIImage(cvPixelBuffer: buffer)
let rep = NSBitmapImageRep(ciImage: ci)
try rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: args[2]))
print("\(args[2]) \(Int(ci.extent.width))x\(Int(ci.extent.height))")
