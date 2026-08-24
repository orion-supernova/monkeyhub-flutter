import Intents
import UIKit
import UniformTypeIdentifiers

/// MonkeyHub's entry in the iOS share sheet.
///
/// Deliberately has no interface. The chat picker, the photo editor and the
/// composer all live in the app, where they are already written, already
/// themed and already localized — and an extension is a separate process with
/// a small memory budget, no session, and no access to the Convex client. So
/// this does the one thing only an extension can do: it copies what it was
/// handed into the shared App Group container while the item providers are
/// still alive, and then wakes the app.
///
/// ### The tap that named a chat
///
/// When the user taps one of MonkeyHub's own suggestions in the sheet's top row
/// rather than the app icon, iOS delivers an `INSendMessageIntent` on
/// `extensionContext.intent` carrying the `conversationIdentifier` the app
/// donated — which is the room id. That is the whole mechanism behind
/// "suggested people": the app donates on send (see `donateSendMessage` in
/// AppDelegate.swift), and it comes back here.
///
/// `IntentsSupported` in Info.plist has to list `INSendMessageIntent` or iOS
/// never offers the suggestions in the first place, and never sets this.
///
/// ### Waking the app
///
/// `extensionContext.open` is the only documented way out of a share extension,
/// and it is allowed to fail. It is not treated as fatal here: the payload is
/// already in the container, so the app finds it on its next foreground pass
/// regardless (see `ShareInbox.drain`). What is deliberately NOT done is the
/// widely-copied trick of walking the responder chain to reach
/// `UIApplication.shared` — that is private API use from an extension, and it
/// is a review rejection.
class ShareViewController: UIViewController {

    /// Longest the extension will spend copying before it gives up and hands
    /// over whatever it has.
    ///
    /// A share sheet that sits there is worse than a share that arrives
    /// incomplete: the user has already left the app they were in, and iOS will
    /// kill this process on its own schedule anyway.
    private static let deadline: TimeInterval = 20

    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // No layout at all — the view is never seen. Clear rather than the
        // default white so a slow copy does not flash a white card over the
        // share sheet.
        view.backgroundColor = .clear

        let roomId = (extensionContext?.intent as? INSendMessageIntent)?
            .conversationIdentifier

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let fallbackText = items.compactMap { $0.attributedContentText?.string }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let inbox = ShareGroup.inboxURL(create: true) else {
            // The App Group is not in this binary's entitlements or profile.
            // Nothing can be handed over, and there is no way to say so from
            // here — the container is the only channel. See SHARE_SHEET.md.
            NSLog("[share] no App Group container — is \(ShareGroup.identifier) provisioned?")
            finish()
            return
        }

        let stagingDir = inbox.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deadline) { [weak self] in
            guard let self, !self.finished else { return }
            NSLog("[share] timed out staging attachments")
            self.finish()
        }

        Staging(directory: stagingDir).run(providers: providers) { [weak self] items, text in
            guard let self else { return }
            let body = text ?? fallbackText
            if items.isEmpty && (body?.isEmpty ?? true) {
                try? FileManager.default.removeItem(at: stagingDir)
                self.finish()
                return
            }
            self.writeManifest(
                at: stagingDir, items: items, text: body, roomId: roomId
            )
            self.wakeApp()
            self.finish()
        }
    }

    /// Written last, and moved into place rather than written in place.
    ///
    /// The app treats a manifest's existence as "this directory is complete",
    /// so it must never be readable while the attachments beside it are still
    /// being copied. A move within one volume is atomic; a write is not.
    private func writeManifest(
        at dir: URL,
        items: [[String: Any]],
        text: String?,
        roomId: String?
    ) {
        var payload: [String: Any] = ["items": items]
        if let text, !text.isEmpty { payload["text"] = text }
        if let roomId, !roomId.isEmpty { payload["targetId"] = roomId }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let temp = dir.appendingPathComponent(".\(ShareGroup.manifestName).tmp")
        let final = dir.appendingPathComponent(ShareGroup.manifestName)
        do {
            try data.write(to: temp, options: .atomic)
            try FileManager.default.moveItem(at: temp, to: final)
        } catch {
            NSLog("[share] could not write manifest: \(error.localizedDescription)")
        }
    }

    private func wakeApp() {
        extensionContext?.open(ShareGroup.hostURL) { opened in
            if !opened {
                // Not a failure worth reporting to the user: the payload is in
                // the container and the app collects it the next time it comes
                // to the foreground.
                NSLog("[share] could not open the host app; payload left for the next launch")
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// Pulls every attachment out of its `NSItemProvider` and onto disk.
///
/// A small state machine rather than a chain of nested closures: providers load
/// asynchronously and out of order, and the results have to keep the order the
/// user chose them in — five photos sent in a shuffled order is a bug people
/// notice immediately.
private final class Staging {

    init(directory: URL) {
        self.directory = directory
    }

    private let directory: URL
    private let queue = DispatchQueue(label: "monkeyhub.share.staging")

    func run(
        providers: [NSItemProvider],
        completion: @escaping ([[String: Any]], String?) -> Void
    ) {
        var staged = [Int: [String: Any]]()
        var text: String?
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            group.enter()
            load(provider, index: index) { [weak self] result in
                guard let self else { group.leave(); return }
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

        group.notify(queue: .main) {
            self.queue.sync {
                let ordered = staged.keys.sorted().compactMap { staged[$0] }
                completion(ordered, text)
            }
        }
    }

    private enum Loaded {
        case file([String: Any])
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
            copyFile(provider, type: UTType.data.identifier, index: index, completion: completion)
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
        completion: @escaping (Loaded) -> Void
    ) {
        // `loadFileRepresentation`'s URL is valid only for the length of the
        // callback — it is deleted the moment this closure returns — so the
        // copy has to happen inside it rather than being scheduled from it.
        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
            guard let self else { completion(.none); return }
            guard let url else {
                NSLog("[share] load failed for \(type): \(error?.localizedDescription ?? "unknown")")
                // A provider that cannot produce the type we asked for. The
                // common case is a transcode it declined; fall back to whatever
                // it does have rather than dropping the attachment.
                if type != UTType.data.identifier,
                   provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    self.copyFile(provider, type: UTType.data.identifier,
                                  index: index, completion: completion)
                } else {
                    completion(.none)
                }
                return
            }
            completion(self.stage(url, index: index))
        }
    }

    private func stage(_ source: URL, index: Int) -> Loaded {
        let fm = FileManager.default
        let name = "\(index)_\(sanitize(source.lastPathComponent))"
        let destination = directory.appendingPathComponent(name)
        let size = (try? fm.attributesOfItem(atPath: source.path)[.size] as? Int64) ?? nil

        // Refused before the copy, not after. The composer would refuse it
        // anyway, and an extension has a memory and time budget that a
        // 500 MB copy does not fit inside.
        if let size, size > ShareGroup.maxUploadBytes {
            return .file([
                "path": "",
                "mimeType": mimeType(for: source),
                "fileName": source.lastPathComponent,
                "size": size,
                "oversize": true,
            ])
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

        let written = (try? fm.attributesOfItem(atPath: destination.path)[.size] as? Int64)
            ?? nil ?? 0
        if written == 0 {
            try? fm.removeItem(at: destination)
            return .none
        }
        return .file([
            "path": destination.path,
            "mimeType": mimeType(for: destination),
            "fileName": source.lastPathComponent,
            "size": written,
            "oversize": false,
        ])
    }

    /// Keeps a provider-supplied name from becoming a path. The name is only
    /// ever a suffix of ours, but a provider is free to hand back
    /// `../../Library/Preferences/x` and this is the one place that string
    /// would otherwise be joined onto a directory.
    private func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "..", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "attachment" : cleaned
    }

    private func mimeType(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
    }
}
