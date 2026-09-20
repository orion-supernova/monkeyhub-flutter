import Cocoa
import FlutterMacOS
import Quartz

/// Shows a received document in Apple's own previewer — the macOS half of
/// `lib/media/document_preview.dart`.
///
/// See the iOS file of the same name for why this is QuickLook rather than a
/// renderer. The difference here is only mechanical: macOS has no
/// `QLPreviewController` to present, it has a shared `QLPreviewPanel` that the
/// app hands a data source to and orders front. The panel is app-wide and
/// there is exactly one, which is why this class is a singleton rather than
/// something constructed per preview.
final class DocumentPreview: NSObject {
    static let shared = DocumentPreview()

    private let directory: URL
    private var item: URL?

    private override init() {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("monkeyhub-preview", isDirectory: true)
        super.init()
    }

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/preview",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            shared.handle(call, result: result)
        }
        shared.sweep()
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
        // A name off a message somebody else sent — the same guard
        // `Staging.sanitize` and the iOS half both make.
        let safe = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "..", with: "_")
        let url = directory.appendingPathComponent(safe)
        try data.write(to: url, options: .atomic)
        item = url
        return url
    }

    /// Orders the shared panel front with [url] in it.
    ///
    /// The data source is assigned before the panel is shown and
    /// `reloadData()` is called after: the panel is shared and may already be
    /// open on the previous document, in which case ordering it front again
    /// would show the old one.
    private func present(_ url: URL) -> Bool {
        guard let panel = QLPreviewPanel.shared() else { return false }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    /// Deletes everything previewed in a previous run — on launch rather than
    /// on close, for the reason the iOS half gives: the panel holds the URL
    /// while it is open.
    private func sweep() {
        let directory = self.directory
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

extension DocumentPreview: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        item == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        item as NSURL?
    }
}
