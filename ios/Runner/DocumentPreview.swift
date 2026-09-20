import Flutter
import QuickLook
import UIKit

/// Shows a received document in Apple's own previewer.
///
/// ### Why QuickLook and not a renderer
///
/// `FileMessage` used to state that this app has no in-app viewer, on the
/// grounds that "a chat app that renders PDFs is a chat app that renders PDFs
/// badly". That is still true of CARRYING a renderer — a PDF or EPUB engine is
/// megabytes of dependency and a permanent stream of layout bugs in somebody
/// else's format. It is not an argument against previewing, which is what it
/// had turned into: receiving a book meant downloading it to find out what it
/// was.
///
/// QuickLook is the whole of the answer on this platform. It is already in the
/// OS, it renders PDF, EPUB, Pages, Numbers, Keynote, Office, RTF, HEIC and
/// more, it is what Mail and Messages use, and it costs one channel.
///
/// ### The file has to exist on disk, and has to be named
///
/// `QLPreviewItem` is a URL and nothing else. There is no way to hand
/// QuickLook bytes plus a type — it identifies the file by its EXTENSION and
/// never sniffs — so the Dart side guarantees a usable name and this writes
/// the bytes under it. Temp files are swept on the next launch rather than on
/// dismissal: the preview holds the URL for as long as it is up, and racing it
/// with a delete is how a book closes itself halfway through.
final class DocumentPreview: NSObject {
    private let directory: URL
    private var item: URL?
    private weak var presented: QLPreviewController?

    override init() {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("monkeyhub-preview", isDirectory: true)
        super.init()
    }

    /// Installs the channel. Called once from `AppDelegate`.
    static func register(with messenger: FlutterBinaryMessenger) -> DocumentPreview {
        let preview = DocumentPreview()
        let channel = FlutterMethodChannel(name: "monkeyhub/preview",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak preview] call, result in
            guard let preview else {
                result(false)
                return
            }
            preview.handle(call, result: result)
        }
        preview.sweep()
        return preview
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "show" else {
            result(FlutterMethodNotImplemented)
            return
        }
        let args = call.arguments as? [String: Any] ?? [:]
        guard
            let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
            let name = args["fileName"] as? String, !name.isEmpty
        else {
            result(false)
            return
        }

        do {
            let url = try write(data, named: name)
            DispatchQueue.main.async {
                result(self.present(url))
            }
        } catch {
            NSLog("[preview] could not stage \(name): \(error.localizedDescription)")
            result(false)
        }
    }

    private func write(_ data: Data, named name: String) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        // The provider-supplied name is only ever a suffix of ours, but it is
        // still a string from a message somebody else sent — the same guard
        // `Staging.sanitize` makes, for the same reason.
        let safe = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "..", with: "_")
        let url = directory.appendingPathComponent(safe)
        try data.write(to: url, options: .atomic)
        item = url
        return url
    }

    /// Puts the previewer on screen over whatever is already there.
    ///
    /// Returns false rather than throwing when there is nothing to present
    /// from — an app in the background, a controller already presenting — and
    /// the Dart side falls back to the share sheet it used to show. A preview
    /// that cannot open must degrade into the old behaviour, not into an error.
    private func present(_ url: URL) -> Bool {
        guard QLPreviewController.canPreview(url as QLPreviewItem) else {
            NSLog("[preview] QuickLook declined \(url.lastPathComponent)")
            return false
        }
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else { return false }
        while let next = top.presentedViewController { top = next }
        if top is QLPreviewController { return false }

        let controller = QLPreviewController()
        controller.dataSource = self
        controller.delegate = self
        presented = controller
        top.present(controller, animated: true)
        return true
    }

    /// Deletes everything previewed in a previous run.
    ///
    /// On launch rather than on dismissal, deliberately: the previewer holds
    /// the URL for as long as it is open, and an app that deletes the file
    /// under it closes the document mid-page. Nothing here is precious — the
    /// bytes are a copy of a blob the server still has.
    private func sweep() {
        let directory = self.directory
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

extension DocumentPreview: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        item == nil ? 0 : 1
    }

    func previewController(
        _ controller: QLPreviewController,
        previewItemAt index: Int
    ) -> QLPreviewItem {
        (item ?? URL(fileURLWithPath: "/dev/null")) as QLPreviewItem
    }
}
