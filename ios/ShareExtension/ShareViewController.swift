import Intents
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// MonkeyHub's entry in the iOS share sheet.
///
/// ### It sends. It does not open the app.
///
/// On iOS a share extension that bounces into its container app is a broken
/// experience: the user is in Photos, they expect to stay in Photos, and every
/// messaging app they already use (Messages, WhatsApp, Telegram) composes and
/// sends without leaving. So this presents a real compose sheet — pick a chat,
/// add a caption, Send — and talks to Convex itself.
///
/// It can do that because of one property of this backend: **there is no
/// `ctx.auth` anywhere in the deployment** and `messages:send` takes the
/// sender's user id as an ordinary argument (see the note at the top of
/// `backend/convex/feed.ts`). So the user id the app leaves in the App Group is
/// the whole credential, and three ordinary HTTP calls do what the Dart client
/// does over its socket. No Flutter engine, no Convex client, no second login —
/// none of which would fit in an extension's memory budget anyway.
///
/// ### Opening the app is the escape hatch, not the path
///
/// Two cases still need it: nobody is signed in on this device (so there is no
/// session to send with), and the user wants the photo EDITOR — crop,
/// annotation, view-once — which lives in the app and is not worth rebuilding
/// here. Both offer a button; neither is the default.
///
/// `extensionContext.open` is the documented way out of a share extension, and
/// it is asynchronous: `completeRequest` must be called from its completion
/// handler, never beside it. Calling both in sequence tears the extension down
/// before iOS acts on the request, which looks exactly like "the sheet appeared
/// and nothing happened". It is also allowed to refuse — see [openHost]
/// for the fallback — and if both fail the payload is already in the container,
/// so the app collects it on its next foreground (`ShareInbox`).
class ShareViewController: UIViewController {

    /// Longest the extension will spend copying attachments before working with
    /// whatever arrived. Enforced inside [Staging], which is the only place that
    /// can still deliver a partial result. iOS will kill this process on its own
    /// schedule regardless, and a share sheet that sits there is worse than one
    /// that arrives incomplete.
    private static let stagingDeadline: TimeInterval = 20

    private let model = ComposeModel()
    private var finished = false
    private var stagingDir: URL?
    /// The copy currently in flight. Held because an in-flight operation that
    /// nobody owns is one iOS is free to deallocate mid-copy — see the note on
    /// [Staging] about what that looked like.
    private var staging: Staging?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        model.session = ShareSession.load()
        model.chats = model.session?.chats ?? []
        // A tap on one of MonkeyHub's own suggestions in the sheet's top row
        // arrives as an INSendMessageIntent carrying the room id the app
        // donated. Pre-select it — that tap already answered "which chat", and
        // asking again is what makes a suggestion pointless.
        let donated = (extensionContext?.intent as? INSendMessageIntent)?
            .conversationIdentifier
        model.selectedChatId = donated
            ?? (model.chats.count == 1 ? model.chats.first?.id : nil)

        model.onSend = { [weak self] in self?.send() }
        model.onOpenApp = { [weak self] in self?.openApp() }
        model.onCancel = { [weak self] in self?.cancel() }

        install(ShareComposeHost(model: model))
        stage()
    }

    private func install<Content: View>(_ root: Content) {
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    // MARK: - Staging

    /// Copies the attachments out of their item providers and onto disk.
    ///
    /// Still done even though the send path could stream straight from the
    /// providers: the "Open MonkeyHub" hand-off needs files in the shared
    /// container, and a provider's URL is valid only inside its own callback.
    private func stage() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let fallbackText = items.compactMap { $0.attributedContentText?.string }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let inbox = ShareGroup.inboxURL(create: true) else {
            // The App Group is missing from this binary's entitlements or its
            // provisioning profile. Nothing can be staged and nothing can be
            // handed over — see SHARE_SHEET.md.
            NSLog("[share] no App Group container — is \(ShareGroup.identifier) provisioned?")
            model.state = .failed("MonkeyHub could not open its shared storage.")
            model.ready = true
            return
        }

        let dir = inbox.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stagingDir = dir

        let job = Staging(directory: dir)
        staging = job
        job.run(providers: providers, deadline: Self.stagingDeadline) { [weak self] staged, text in
            guard let self else { return }
            self.staging = nil
            self.model.items = staged
            self.model.sharedText = text ?? fallbackText
            self.model.previewImage = Self.thumbnail(for: staged)
            self.model.ready = true
            if staged.isEmpty && (self.model.sharedText?.isEmpty ?? true) {
                self.model.state = .failed("Nothing came through from that app.")
            }
        }
    }

    /// A small preview of the first image, decoded at thumbnail size.
    ///
    /// `thumbnailFromImageAlways` rather than a full decode: a 12 megapixel
    /// HEIC decoded to show a 56 pt square is most of an extension's memory
    /// budget spent on a thumbnail.
    private static func thumbnail(for items: [StagedItem]) -> UIImage? {
        guard let first = items.first(where: { $0.isImage && !$0.oversize }) else { return nil }
        guard let source = CGImageSourceCreateWithURL(first.url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 240,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Sending

    private func send() {
        // Both of these are reachable from a sheet the user is looking at, and
        // an early `return` here is a Send button that swallows the tap: no
        // spinner, no error, nothing. A share arriving on a signed-out device
        // still carries a donated room id, so the button is live even when
        // there is no session behind it.
        guard let session = model.session else {
            model.state = .failed("Open MonkeyHub and sign in before sending from here.")
            return
        }
        guard let roomId = model.selectedChatId else {
            model.state = .failed("Pick a chat first.")
            return
        }
        model.state = .sending

        let caption = model.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let sendable = model.items.filter { !$0.oversize }

        // Text-only share: one message, no upload.
        if sendable.isEmpty {
            let body = [model.sharedText, caption.isEmpty ? nil : caption]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            guard !body.isEmpty else {
                model.state = .failed("There is nothing to send.")
                return
            }
            postMessage(session: session, roomId: roomId, content: body, item: nil) { [weak self] error in
                self?.finishSend(error)
            }
            return
        }

        // Attachments, one at a time. Sequential rather than concurrent for the
        // same two reasons the app's own queue is: the order the user chose has
        // to survive, and an extension holding four videos in memory at once is
        // an extension the system kills.
        //
        // The caption rides on the FIRST attachment, which is where every chat
        // app puts it and where this app's own `sendMediaLocal(caption:)` puts
        // it too. Any shared text is appended to it rather than sent separately.
        let leadingText = [model.sharedText, caption.isEmpty ? nil : caption]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        var remaining = sendable
        var isFirst = true

        func next() {
            guard !remaining.isEmpty else {
                finishSend(nil)
                return
            }
            let item = remaining.removeFirst()
            let content = isFirst ? leadingText : ""
            isFirst = false
            postMessage(session: session, roomId: roomId, content: content, item: item) { [weak self] error in
                if let error {
                    self?.finishSend(error)
                    return
                }
                next()
            }
        }
        next()
    }

    /// Uploads [item] if there is one, then posts the message.
    ///
    /// The argument names are `messages:send`'s, and they are a cross-language
    /// contract with `ChatApi.sendMessage` in lib/backend/chat_api.dart —
    /// `share_contract_test.dart` reads both files and fails if they drift.
    private func postMessage(
        session: ShareSession,
        roomId: String,
        content: String,
        item: StagedItem?,
        completion: @escaping (String?) -> Void
    ) {
        // Read here, not at staging time: staging starts the moment the sheet
        // opens, before the user has had any chance to touch the HD toggle, so
        // this is the first point its value can be trusted. Nil means "the
        // staged bytes go out unchanged" — HD is on, the item isn't a photo,
        // or it was already under the cap.
        let compressed = model.hd ? nil : item.flatMap(PhotoSendCompression.compress)

        func post(storageId: String?) {
            var args: [String: Any] = [
                "roomId": roomId,
                "userId": session.userId,
                "content": content,
                "type": item?.messageType ?? "text",
                // Idempotency. A send whose response is lost on the wire is
                // retried by nothing here — but the extension can be killed
                // mid-flight and the user can share the same photo again, and
                // this makes the second one a no-op rather than a duplicate.
                "clientId": UUID().uuidString,
            ]
            if let name = session.senderName, !name.isEmpty {
                args["senderName"] = name
            }
            if let storageId {
                args["mediaStorageId"] = storageId
            }
            if let item {
                if let compressed {
                    args["mediaWidth"] = compressed.width
                    args["mediaHeight"] = compressed.height
                } else if let size = item.pixelSize {
                    args["mediaWidth"] = Int(size.width)
                    args["mediaHeight"] = Int(size.height)
                }
                // Set on documents ONLY, matching the Dart side exactly: a
                // photo carrying a fileName renders as a downloadable blob
                // instead of a picture.
                if item.messageType == "file" {
                    args["fileName"] = item.fileName
                    args["fileSize"] = item.byteCount
                    args["mimeType"] = item.mimeType
                }
                // Photos only, matching the scope `PhotoViewOnceToggle` has in
                // the app — the extension never offers this for a video or a
                // file. Omitted rather than sent false, matching
                // `ChatApi.sendMessage`'s own `if (viewOnce) 'viewOnce': true`.
                if model.viewOnce, item.isImage {
                    args["viewOnce"] = true
                }
            }
            ConvexHTTP.mutation(
                deploymentUrl: session.deploymentUrl,
                sessionToken: session.sessionToken,
                path: "messages:send",
                args: args
            ) { result in
                switch result {
                case .success: completion(nil)
                case .failure(let error): completion(Self.describe(error))
                }
            }
        }

        guard let item else {
            post(storageId: nil)
            return
        }

        let data: Data
        let contentType: String
        if let compressed {
            data = compressed.data
            contentType = compressed.contentType
        } else {
            guard let raw = try? Data(contentsOf: item.url, options: .mappedIfSafe) else {
                completion("That file could not be read.")
                return
            }
            data = raw
            contentType = item.mimeType
        }

        ConvexHTTP.upload(
            deploymentUrl: session.deploymentUrl,
            sessionToken: session.sessionToken,
            data: data,
            contentType: contentType
        ) { result in
            switch result {
            case .success(let storageId): post(storageId: storageId)
            case .failure(let error): completion(Self.describe(error))
            }
        }
    }

    private static func describe(_ error: ConvexHTTP.Failure) -> String {
        switch error {
        case .transport:
            return "Could not reach MonkeyHub. Check your connection and try again."
        case .server(let message):
            // Surfaced rather than swallowed: the useful ones here are the
            // server's own refusals — not a member of that room any more, the
            // room is gone, a child-account guard — and a generic "failed"
            // would leave the user retrying something that cannot work.
            return message
        case .malformed:
            return "MonkeyHub sent back something unexpected."
        }
    }

    private func finishSend(_ error: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let error {
                self.model.state = .failed(error)
                return
            }
            // Sent. Delete the staging directory WITHOUT leaving a manifest, or
            // the app would deliver the same photos again the next time it came
            // to the foreground — see `ShareInbox.drain`.
            if let dir = self.stagingDir {
                try? FileManager.default.removeItem(at: dir)
            }
            self.finish()
        }
    }

    // MARK: - The escape hatch

    /// Hands the share to the app instead of sending it here.
    ///
    /// Writes the manifest LAST and by an atomic move, so the app can never
    /// find a payload describing files that are still being copied — then asks
    /// iOS to open the app, and completes only once that request has been
    /// answered. Completing beside the call rather than inside its handler is
    /// what made an earlier build appear to do nothing at all.
    ///
    /// Two things can go wrong after that and both look identical to the user,
    /// so both are handled: `open` can answer `false` (see [openHost]),
    /// and on some releases it never answers at all — hence the watchdog. The
    /// payload is in the container either way, so the worst case is the app
    /// collecting it on the user's next visit rather than immediately.
    private func openApp() {
        guard let dir = stagingDir else {
            finish()
            return
        }
        writeManifest(at: dir)

        // Every route out of here is asynchronous and any of them may never
        // answer, so one latch settles the request whichever gets there first.
        var settled = false
        let done: () -> Void = { [weak self] in
            guard let self, !settled else { return }
            settled = true
            self.finish()
        }

        openHost { opened in
            if !opened {
                // Not fatal and not worth an alert: the payload is in the
                // container, so the app collects it the moment the user gets
                // there — which they are already on their way to doing.
                NSLog("[share] could not open the host app; payload left for its next foreground")
            }
            done()
        }
        // Neither route is guaranteed to call back — both are documented to and
        // on some releases neither does. The sheet has to close regardless.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { done() }
    }

    /// Asks iOS to bring the app up, by each route there is.
    ///
    /// `NSExtensionContext.open` is documented for Today and iMessage
    /// extensions **only**. From a share extension it is tolerated rather than
    /// supported and answers `false` — which is the whole of "the Open in
    /// MonkeyHub button does not open MonkeyHub". So a refusal falls through to
    /// the scene, which can do it and is allowed to.
    ///
    /// `UIScene.open(_:options:completionHandler:)` is the piece that makes
    /// this ordinary code rather than a hack. `UIApplication.shared` and its
    /// `open` are both annotated unavailable to app extensions and will not
    /// compile here, which is why every recipe on the subject reaches for the
    /// responder chain and `perform(NSSelectorFromString("openURL:"))` — and
    /// that recipe is now doubly dead:
    ///
    ///  * iOS 26 refuses the deprecated `openURL:` outright, logging
    ///    "BUG IN CLIENT OF UIKIT … Force returning false (NO)" and doing
    ///    nothing, while still answering `responds(to:)` — so the caller
    ///    believes it worked;
    ///  * and the first responder that answers the three-argument spelling is
    ///    the **scene**, whose `options:` is a `UISceneOpenExternalURLOptions`
    ///    rather than UIApplication's dictionary. Handing it the dictionary
    ///    that spelling implies crashes the extension outright with
    ///    `-[__NSDictionary0 universalLinksOnly]: unrecognized selector`.
    ///
    /// The scene is reachable directly and its `open` is public, extension-safe
    /// API. No selector, no `perform`, no guessing which object answered.
    private func openHost(_ completion: @escaping (Bool) -> Void) {
        guard let context = extensionContext else {
            completion(false)
            return
        }
        context.open(ShareGroup.hostURL) { [weak self] opened in
            DispatchQueue.main.async {
                if opened {
                    completion(true)
                    return
                }
                guard let scene = self?.view.window?.windowScene else {
                    NSLog("[share] no scene to open from")
                    completion(false)
                    return
                }
                NSLog("[share] extensionContext.open refused; going through the scene")
                scene.open(ShareGroup.hostURL, options: nil) { opened in
                    completion(opened)
                }
            }
        }
    }

    private func writeManifest(at dir: URL) {
        var payload: [String: Any] = [
            "items": model.items.map { $0.manifestEntry },
        ]
        let caption = model.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = [model.sharedText, caption.isEmpty ? nil : caption]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        if !text.isEmpty { payload["text"] = text }
        if let roomId = model.selectedChatId { payload["targetId"] = roomId }

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

    // MARK: - Teardown

    private func cancel() {
        if let dir = stagingDir {
            try? FileManager.default.removeItem(at: dir)
        }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// Recompresses a staged photo for a non-HD send: capped at [maxEdge] on its
/// longest side, re-encoded as JPEG at [quality].
///
/// Mirrors `compressForSend`/`prepareUneditedForSend` in
/// lib/media/image_raster.dart exactly — same cap, same quality — so a photo
/// costs the same on the wire whether it left the app's own composer or this
/// sheet. HD is not a mirror of anything here: it is simply skipping this
/// step, which is what the Dart `hd` branch does too — the source bytes,
/// untouched.
private enum PhotoSendCompression {
    /// Matches `kSendPhotoMaxEdge`.
    static let maxEdge: CGFloat = 1280
    /// Matches `kSendPhotoQuality` (0-100 there, 0-1 for ImageIO here).
    static let quality: CGFloat = 0.75

    struct Result {
        let data: Data
        let contentType: String
        let width: Int
        let height: Int
    }

    /// Nil means "send the staged file as-is" — not a photo, or its longest
    /// edge is already at or under the cap, exactly like the Dart
    /// pass-through does.
    static func compress(_ item: StagedItem) -> Result? {
        guard item.isImage else { return nil }
        if let size = item.pixelSize, max(size.width, size.height) <= maxEdge {
            return nil
        }
        guard let source = CGImageSourceCreateWithURL(item.url as CFURL, nil) else { return nil }
        // A thumbnail request, not a full decode-then-scale: it downsamples
        // during decode, which is both the fast path and the one that keeps
        // a 12 megapixel HEIC from being fully decoded in an extension's
        // memory budget just to be immediately thrown away.
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }

        return Result(
            data: data as Data,
            contentType: "image/jpeg",
            width: cgImage.width,
            height: cgImage.height
        )
    }
}

/// Bridges the controller's state into SwiftUI.
final class ComposeModel: ObservableObject {
    @Published var chats: [ShareChat] = []
    @Published var items: [StagedItem] = []
    @Published var sharedText: String?
    @Published var previewImage: UIImage?
    @Published var selectedChatId: String?
    @Published var caption: String = ""
    /// Off every time the sheet opens, and never written to `UserDefaults` or
    /// the App Group — unlike the app's own `SettingsStore.photoHd`, this is
    /// a one-time choice for this share only. A fresh process next time means
    /// a fresh `false` here for free.
    @Published var hd: Bool = false
    /// Same one-time contract as `hd`. The app doesn't persist this one
    /// either — `_viewOnce` in `camera_editor_screen.dart` and
    /// `photo_tray_screen.dart` both start `false` on every open — so there
    /// is nothing to deliberately avoid saving here, only something to not
    /// introduce.
    @Published var viewOnce: Bool = false
    @Published var state: ShareComposeView.SendState = .idle
    /// False until staging finishes, so Send cannot fire at an empty list.
    @Published var ready: Bool = false

    var session: ShareSession?
    var onSend: () -> Void = {}
    var onOpenApp: () -> Void = {}
    var onCancel: () -> Void = {}
}

private struct ShareComposeHost: View {
    @ObservedObject var model: ComposeModel

    var body: some View {
        ShareComposeView(
            chats: model.chats,
            attachmentCount: model.items.filter { !$0.oversize }.count,
            previewImage: model.previewImage,
            sharedText: model.sharedText,
            hasCompressiblePhoto: model.items.contains { $0.isImage && !$0.oversize },
            selectedChatId: $model.selectedChatId,
            caption: $model.caption,
            hd: $model.hd,
            viewOnce: $model.viewOnce,
            state: model.ready ? model.state : .sending,
            onSend: model.onSend,
            onOpenApp: model.onOpenApp,
            onCancel: model.onCancel
        )
    }
}
