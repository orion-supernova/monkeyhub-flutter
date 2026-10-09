import ImageIO
import UniformTypeIdentifiers
import UIKit

/// One attachment, copied out of its item provider and onto disk.
///
/// The copy is not optional. `NSItemProvider`'s file URL is valid only inside
/// the callback that produced it — it is deleted the moment that closure
/// returns — so anything that wants to read the bytes later (an upload, or the
/// app after a hand-off) has to own its own copy first.
struct StagedItem {
    let url: URL
    let mimeType: String
    let fileName: String
    let byteCount: Int64
    /// True when the file is over its intake cap (`ShareGroup.intakeCap`) and
    /// was NOT copied. Reported rather than dropped so the sheet can say why
    /// fewer things went than were shared.
    let oversize: Bool
    let pixelSize: CGSize?

    /// True when the provider declared no concrete type at all and this was
    /// staged through the final `public.data` fallback.
    ///
    /// Which matters for exactly one thing: an app that shares a LINK often
    /// hands over a second, typeless provider holding the link's preview image
    /// — the App Store does, with a ~270 KB blob and a five-character
    /// extensionless name. That is furniture for the URL, not a document
    /// anybody meant to send, and attaching it turns "here's a game" into a
    /// mystery `application/octet-stream` with the URL stranded in a caption
    /// underneath. See [Staging.run], which drops these when the share also
    /// carries text.
    let opaque: Bool

    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isVideo: Bool { mimeType.hasPrefix("video/") }

    /// A video that was taken in but is over the upload cap, so it is
    /// compressed before it goes. The sheet says so before Send.
    var needsShrink: Bool { isVideo && !oversize && byteCount > ShareGroup.maxUploadBytes }

    /// Which of the app's message types this becomes.
    ///
    /// Only the top-level MIME type is consulted, exactly as
    /// `SharedItem.messageType` does in Dart. A share sheet is where unusual
    /// subtypes turn up — `image/heic`, `image/avif`, `video/quicktime` — and
    /// treating an unfamiliar one as a document sends somebody's photo as a
    /// downloadable blob.
    var messageType: String {
        if mimeType.hasPrefix("image/") { return "image" }
        if mimeType.hasPrefix("video/") { return "video" }
        return "file"
    }

    /// The shape `SharedPayload.fromChannel` parses, for the hand-off path.
    var manifestEntry: [String: Any] {
        [
            "path": oversize ? "" : url.path,
            "mimeType": mimeType,
            "fileName": fileName,
            "size": byteCount,
            "oversize": oversize,
        ]
    }
}

/// Pulls every attachment out of its `NSItemProvider` and onto disk.
///
/// A small state machine rather than a chain of nested closures: providers load
/// asynchronously and out of order, and the results have to keep the order the
/// user chose them in — five photos sent in a shuffled order is a bug people
/// notice immediately.
///
/// ### Its own callbacks hold it alive, on purpose
///
/// Every closure below captures `self` **strongly**. That is not an oversight
/// and it is not a leak: nothing else references a Staging — the controller
/// starts one and the loads it kicked off are the only things left pointing at
/// it — so a weak capture means the object is gone before the first provider
/// answers, every staged file is discarded, and [run]'s completion is never
/// called at all. The symptom is a share sheet that spins, then offers nothing
/// to send. The closures are released as they fire, so the object goes away
/// when the work does.
final class Staging {

    init(directory: URL) {
        self.directory = directory
    }

    private let directory: URL
    private let queue = DispatchQueue(label: "monkeyhub.share.staging")

    /// Copies every provider's payload into the staging directory.
    ///
    /// [completion] runs on the main queue and runs **exactly once**: when
    /// every provider has answered, or when [deadline] elapses with whatever
    /// has landed by then. The deadline is not belt-and-braces — a provider
    /// that never calls its completion handler is an ordinary occurrence (a
    /// declined transcode, an iCloud original that will not download), and one
    /// of them must not be able to hold the whole sheet at a spinner.
    func run(
        providers: [NSItemProvider],
        deadline: TimeInterval,
        completion: @escaping ([StagedItem], String?) -> Void
    ) {
        var staged = [Int: StagedItem]()
        var text: String?
        var delivered = false
        let group = DispatchGroup()

        // Reads and writes of the three variables above happen here and only
        // here, on the one serial queue, which is what makes them safe to share
        // between however many providers are loading at once.
        func deliver(timedOut: Bool = false) {
            self.queue.async {
                guard !delivered else { return }
                delivered = true
                if timedOut {
                    NSLog("[share] staging deadline reached; going with what arrived")
                }
                var ordered = staged.keys.sorted().compactMap { staged[$0] }
                // A typeless blob arriving beside a URL is that URL's preview
                // image — see `StagedItem.opaque`. Dropped rather than sent,
                // so sharing an App Store page produces a link with a preview
                // card, which is what it produces in every other chat app and
                // what the person sharing it meant.
                //
                // Only when there IS text: an opaque blob on its own is an
                // ordinary document (a provider that declared nothing, a file
                // with no extension) and still goes.
                if text != nil, ordered.contains(where: { $0.opaque }) {
                    let dropped = ordered.filter { $0.opaque }
                    ordered = ordered.filter { !$0.opaque }
                    for item in dropped {
                        try? FileManager.default.removeItem(at: item.url)
                    }
                    NSLog("[share] dropped \(dropped.count) typeless item(s) beside a link")
                }
                DispatchQueue.main.async { completion(ordered, text) }
            }
        }

        for (index, provider) in providers.enumerated() {
            group.enter()
            load(provider, index: index) { result in
                self.queue.async {
                    switch result {
                    case .file(let item): staged[index] = item
                    case .text(let value):
                        // First one wins. A share carries one message, and a
                        // browser sending both a title and a URL is the only
                        // common way to get two.
                        if text == nil { text = value }
                    case .none: break
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { deliver() }
        DispatchQueue.main.asyncAfter(deadline: .now() + deadline) {
            deliver(timedOut: true)
        }
    }

    private enum Loaded {
        case file(StagedItem)
        case text(String)
        case none
    }

    private func load(
        _ provider: NSItemProvider,
        index: Int,
        completion: @escaping (Loaded) -> Void
    ) {
        // Order matters and is not arbitrary. `public.url` conforms for a file
        // URL as well as a web one, and `public.data` conforms for everything —
        // so the specific types have to be asked about first or every photo
        // would be staged as an anonymous document.
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            copyFile(provider, type: imageType(for: provider), index: index, completion: completion)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            copyFile(provider, type: UTType.movie.identifier, index: index, completion: completion)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            copyFile(provider, type: UTType.audio.identifier, index: index, completion: completion)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            copyFile(provider, type: UTType.fileURL.identifier, index: index, completion: completion)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { value, _ in
                if let url = value as? URL, !url.isFileURL {
                    completion(.text(url.absoluteString))
                } else {
                    completion(.none)
                }
            }
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { value, _ in
                if let string = value as? String {
                    completion(.text(string))
                } else if let data = value as? Data,
                          let string = String(data: data, encoding: .utf8) {
                    completion(.text(string))
                } else {
                    completion(.none)
                }
            }
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            // The end of the line: a provider that declared nothing more
            // specific than "bytes". Marked, because that is the signature of
            // a link's preview image as well as of a genuine typeless file,
            // and only [run] can tell the two apart.
            copyFile(provider, type: UTType.data.identifier, index: index,
                     opaque: true, completion: completion)
            return
        }
        completion(.none)
    }

    /// Which representation of a picture to ask for.
    ///
    /// A screenshot is a PNG and asking for JPEG would re-encode text and thin
    /// lines into a smear, so PNG wins when it is offered. Otherwise ask for
    /// JPEG *even when the provider does not list it* — that is the request
    /// that makes `NSItemProvider` transcode, which is the only thing standing
    /// between an iPhone's HEIC and a recipient on a platform that cannot
    /// decode it.
    private func imageType(for provider: NSItemProvider) -> String {
        if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            return UTType.png.identifier
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            return UTType.gif.identifier
        }
        return UTType.jpeg.identifier
    }

    private func copyFile(
        _ provider: NSItemProvider,
        type: String,
        index: Int,
        opaque: Bool = false,
        completion: @escaping (Loaded) -> Void
    ) {
        // `loadFileRepresentation`'s URL is valid only for the length of the
        // callback — it is deleted the moment this closure returns — so the
        // copy has to happen inside it rather than being scheduled from it.
        provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
            guard let url else {
                NSLog("[share] load failed for \(type): \(error?.localizedDescription ?? "unknown")")
                // A provider that cannot produce the type we asked for. The
                // common case is a transcode it declined; fall back to whatever
                // it does have rather than dropping the attachment.
                if type != UTType.data.identifier,
                   provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    // `opaque` is carried, not set: this is a RETRY of a
                    // concrete type the provider declined to produce, not a
                    // provider that declared nothing. A transcode that failed
                    // is still somebody's photograph.
                    self.copyFile(provider, type: UTType.data.identifier,
                                  index: index, opaque: opaque,
                                  completion: completion)
                } else {
                    completion(.none)
                }
                return
            }
            completion(self.stage(url, index: index, opaque: opaque))
        }
    }

    private func stage(_ source: URL, index: Int, opaque: Bool = false) -> Loaded {
        let fm = FileManager.default
        let name = sanitize(source.lastPathComponent)
        let destination = directory.appendingPathComponent("\(index)_\(name)")
        let declared = (try? fm.attributesOfItem(atPath: source.path)[.size] as? Int64) ?? nil

        // Refused before the copy, not after. A document over the upload cap
        // cannot be sent at all; a photo or video gets the larger intake cap,
        // because it is compressed on the way out, but past that the copy is
        // more than an extension's time budget and the clip could not fit
        // anyway. A file copy streams, so memory is not what bounds it.
        if let declared, declared > ShareGroup.intakeCap(for: mimeType(for: source)) {
            return .file(StagedItem(
                url: destination, mimeType: mimeType(for: source), fileName: name,
                byteCount: declared, oversize: true, pixelSize: nil, opaque: opaque
            ))
        }

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            NSLog("[share] copy failed: \(error.localizedDescription)")
            return .none
        }

        let written = ((try? fm.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? nil) ?? 0
        if written == 0 {
            try? fm.removeItem(at: destination)
            return .none
        }
        return .file(StagedItem(
            url: destination,
            mimeType: mimeType(for: destination),
            fileName: name,
            byteCount: written,
            oversize: false,
            pixelSize: Self.pixelSize(of: destination),
            opaque: opaque
        ))
    }

    /// The picture's intrinsic size, read from its header.
    ///
    /// Rides onto the message so nobody — sender included — has to decode the
    /// photo before they can lay out a bubble the right shape for it, which is
    /// the same reason the app's editor sends it. `CGImageSourceCopyProperties`
    /// reads the header only; nothing is decoded.
    private static func pixelSize(of url: URL) -> CGSize? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Double,
            let height = props[kCGImagePropertyPixelHeight] as? Double,
            width > 0, height > 0
        else { return nil }

        // Orientation 5–8 are the quarter turns, where the stored pixel
        // dimensions are the transposed ones. A bubble laid out from the raw
        // numbers renders every rotated photo in the wrong aspect.
        let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
        return orientation >= 5
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    /// Keeps a provider-supplied name from becoming a path. The name is only
    /// ever a suffix of ours, but a provider is free to hand back
    /// `../../Library/Preferences/x`, and this is the one place that string
    /// would otherwise be joined onto a directory.
    private func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "..", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "attachment" : cleaned
    }

    /// What to upload this as.
    ///
    /// The extension first, because it is what the sender's own filesystem
    /// says and it is right almost every time. But it is *only* a name, and a
    /// provider is free to hand over a file that has none — the App Store's
    /// link-preview blob arrives as five characters with no dot in them — at
    /// which point the old answer was `application/octet-stream`, which turns
    /// a picture into a downloadable mystery.
    ///
    /// So when the name says nothing, the BYTES are asked. Header sniffing,
    /// not decoding: sixteen bytes off the front of the file, matched against
    /// the handful of signatures a share sheet actually produces.
    private func mimeType(for url: URL) -> String {
        if let byName = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType {
            return byName
        }
        return Self.sniff(url) ?? "application/octet-stream"
    }

    /// Identifies a file from its magic bytes, or nil for anything not listed.
    ///
    /// Deliberately short. This is the fallback for a file with no name to go
    /// on, and guessing wrong is worse than not guessing — the same rule
    /// `mimeTypeForFileName` states on the Dart side. Every entry here is a
    /// format the transcript can actually render or play, because the only
    /// thing this changes is whether the message arrives as a picture instead
    /// of as an anonymous blob.
    private static func sniff(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 16), head.count >= 12 else {
            return nil
        }
        let b = [UInt8](head)

        if b.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "image/png"
        }
        if b.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if b.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if b.starts(with: [0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }
        // RIFF....WEBP
        if b.starts(with: [0x52, 0x49, 0x46, 0x46]),
           Array(b[8..<12]) == [0x57, 0x45, 0x42, 0x50] {
            return "image/webp"
        }
        // ISO base media: the brand at bytes 4..12 decides which one.
        if Array(b[4..<8]) == [0x66, 0x74, 0x79, 0x70] {
            let brand = String(bytes: b[8..<12], encoding: .ascii) ?? ""
            switch brand {
            case "heic", "heix", "heim", "heis", "hevc", "mif1", "msf1":
                return "image/heic"
            case "qt  ":
                return "video/quicktime"
            default:
                return "video/mp4"
            }
        }
        return nil
    }
}
