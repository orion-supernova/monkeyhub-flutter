import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// The largest file this app will carry, mirrored from
/// `kMaxFileUploadBytes` in `lib/media/file_meta.dart`.
///
/// Duplicated rather than pushed down from Dart because it is needed at the
/// exact moment Dart cannot be consulted: `performDragOperation` copies the
/// dropped files before it reports them, and copying twenty-five megabytes to
/// have Dart refuse it a frame later is disk churn with no outcome. A file
/// past this is reported with its real size and no copy behind it, and the
/// Dart side turns that into the "1 file is over 20 MB" notice.
///
/// If the Dart constant moves, this moves with it. `drop_cap_test.dart` fails
/// loudly if they disagree.
private let kMaxDropBytes: Int = 20 * 1024 * 1024

/// Mirrors `kMaxMediaIntakeBytes` in lib/media/file_meta.dart: the cap for a
/// dropped photo or video, which the app compresses down to [kMaxDropBytes]
/// before it goes. `drop_cap_test.dart` pins this one too.
private let kMaxDropMediaBytes: Int = 500 * 1024 * 1024

/// How far the pointer has to travel before another `move` is worth sending.
///
/// AppKit calls `draggingUpdated:` continuously — including while the pointer
/// is perfectly still — and every call that reaches Dart is a platform-channel
/// round trip plus a hit test plus, potentially, a repaint. One point is below
/// the threshold of anything visible and removes almost all of them.
private let kMoveEpsilon: CGFloat = 1.0

/// Receives files dragged onto the app window from Finder, Photos, Mail or any
/// other Mac application.
///
/// ### Why the window and not a view
///
/// A drag destination is found by walking DOWN from the view under the cursor;
/// the `FlutterView` registers no dragged types, so nothing in the Flutter
/// hierarchy is a candidate. The alternatives were to insert a transparent
/// overlay `NSView` above it — which then has to be excluded from ordinary hit
/// testing, and which Flutter's own resize handling would have to be taught
/// about — or to register the WINDOW, which AppKit consults when no view
/// accepts. The window is the whole content area, which is exactly the region
/// this app wants to receive drags over, and it involves no surgery on a view
/// hierarchy the engine owns.
///
/// ### The Dart handshake
///
/// Nothing is registered until Dart calls `ready`. Before that the app would
/// show the copy cursor and swallow a file with no listener behind it — the
/// splash screen is a real window, and dragging onto it is a real thing people
/// do while an app is still starting.
final class DropDestination: NSObject {
  private weak var window: NSWindow?
  private let channel: FlutterMethodChannel

  /// The answer `draggingUpdated:` gives, maintained from Dart.
  ///
  /// `draggingUpdated:` must return SYNCHRONOUSLY and Dart is across an async
  /// channel, so the cursor badge is at most one mouse-move behind the verdict
  /// chip. Blocking AppKit's drag loop on the engine instead would put Dart's
  /// latency inside the drag itself, which is how a drag starts to stutter.
  private var accepting = true

  private var lastSent: NSPoint?

  /// Root of everything this class has copied, so a release can be checked
  /// against it and a stray path from a compromised channel message cannot ask
  /// us to delete something else.
  private let stagingRoot: URL

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    self.channel = FlutterMethodChannel(name: "monkeyhub/drop", binaryMessenger: messenger)
    self.stagingRoot = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("monkeyhub-drop", isDirectory: true)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ready":
      DispatchQueue.main.async { [weak self] in
        guard let self, let window = self.window else {
          result(nil)
          return
        }
        window.registerForDraggedTypes([.fileURL, .string, .URL])
        // Anything left behind by a previous run: a crash between the copy and
        // the release leaves files in the staging root, and nothing else ever
        // cleans them up.
        self.purgeStaging()
        result(nil)
      }
    case "accepting":
      let args = call.arguments as? [String: Any] ?? [:]
      accepting = (args["accept"] as? Bool) ?? true
      result(nil)
    case "readClipboard":
      readClipboard(result: result)
    case "release":
      let args = call.arguments as? [String: Any] ?? [:]
      let paths = (args["paths"] as? [String]) ?? []
      release(paths)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // ───────────────────────────── drag lifecycle ─────────────────────────────

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    lastSent = nil
    let point = sender.draggingLocation
    lastSent = point
    var payload = describe(sender.draggingPasteboard)
    let flutterPoint = convert(point)
    payload["x"] = flutterPoint.x
    payload["y"] = flutterPoint.y
    channel.invokeMethod("enter", arguments: payload)
    // Optimistic on entry, for one frame. The alternative is a drag that shows
    // the no-drop cursor for its first moment over every window, which reads
    // as the app refusing before it has looked.
    return .copy
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let point = sender.draggingLocation
    if let last = lastSent,
       abs(last.x - point.x) < kMoveEpsilon, abs(last.y - point.y) < kMoveEpsilon {
      return accepting ? .copy : []
    }
    lastSent = point
    let flutterPoint = convert(point)
    channel.invokeMethod("move", arguments: ["x": flutterPoint.x, "y": flutterPoint.y])
    return accepting ? .copy : []
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    lastSent = nil
    channel.invokeMethod("exit", arguments: nil)
  }

  func draggingEnded(_ sender: NSDraggingInfo) {
    // Belt to `draggingExited`'s braces. A drag cancelled with Escape, or one
    // whose source application quit mid-flight, does not always produce an
    // exit — and a session left open in Dart is an overlay that never fades.
    // Idempotent on the Dart side.
    lastSent = nil
    channel.invokeMethod("exit", arguments: nil)
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    let urls = fileURLs(from: pasteboard)
    let flutterPoint = convert(sender.draggingLocation)
    // Read off the pasteboard on this thread — it is only valid for the length
    // of this call — and do the copying on another.
    let text = urls.isEmpty ? pasteboard.string(forType: .string) : nil
    let link = urls.isEmpty ? webURL(from: pasteboard)?.absoluteString : nil

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let staged = self.stage(urls)
      DispatchQueue.main.async {
        var payload: [String: Any] = [
          "x": flutterPoint.x,
          "y": flutterPoint.y,
          "files": staged,
        ]
        if let text, !text.isEmpty { payload["text"] = text }
        if let link, !link.isEmpty { payload["uri"] = link }
        self.channel.invokeMethod("drop", arguments: payload)
      }
    }
    return true
  }

  // ────────────────────────────── pasteboard ──────────────────────────────

  /// What the drag is carrying, as far as the pasteboard will say — which on
  /// this platform is everything: names, byte counts and content-sniffed UTIs,
  /// all available while the file is still in the air.
  private func describe(_ pasteboard: NSPasteboard) -> [String: Any] {
    let urls = fileURLs(from: pasteboard)
    if urls.isEmpty {
      var payload: [String: Any] = ["items": []]
      if let text = pasteboard.string(forType: .string), !text.isEmpty {
        payload["text"] = text
      }
      if let link = webURL(from: pasteboard)?.absoluteString {
        payload["uri"] = link
      }
      return payload
    }
    var items: [[String: Any]] = []
    for url in urls {
      var entry: [String: Any] = ["name": url.lastPathComponent]
      let values = try? url.resourceValues(
        forKeys: [.fileSizeKey, .isDirectoryKey, .contentTypeKey]
      )
      if let isDirectory = values?.isDirectory, isDirectory {
        entry["dir"] = true
      }
      // Absent rather than zero when the sandbox will not answer for a file we
      // have not been handed yet. The Dart classifier reads a missing size as
      // "not measured" and declines to pre-refuse on it, which is the honest
      // reading — a guessed zero would show every file as empty.
      if let size = values?.fileSize {
        entry["size"] = size
      }
      if let mime = values?.contentType?.preferredMIMEType {
        entry["mime"] = mime
      }
      items.append(entry)
    }
    return ["items": items]
  }

  private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options)
    return (objects as? [URL]) ?? []
  }

  /// A dragged link — a browser tab, an anchor off a web page. File URLs are
  /// excluded here because a Finder drag carries both, and reporting the
  /// file's own `file://` URL as a link would caption every dropped photo with
  /// its path on the sender's disk.
  private func webURL(from pasteboard: NSPasteboard) -> URL? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: false]
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options)
    guard let urls = objects as? [URL] else { return nil }
    return urls.first { !$0.isFileURL }
  }

  // ─────────────────────────────── paste ───────────────────────────────

  /// What ⌘V in the composer would ATTACH, staged exactly like a drop: file
  /// URLs copied in Finder, or else an image (a screenshot copied to the
  /// clipboard, a picture copied out of Preview or a browser). Answers nil
  /// when the clipboard holds plain text, so Dart runs its ordinary text paste
  /// — text beats an image because Word and Pages put a picture of the copied
  /// words beside the words.
  private func readClipboard(result: @escaping FlutterResult) {
    let pasteboard = NSPasteboard.general
    let urls = fileURLs(from: pasteboard)
    if !urls.isEmpty {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        let staged = self.stage(urls)
        DispatchQueue.main.async { result(["files": staged]) }
      }
      return
    }
    if let text = pasteboard.string(forType: .string),
       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      result(nil)
      return
    }
    // Read on this thread (the pasteboard is not to be touched off main);
    // encoded and written on another.
    let png = pasteboard.data(forType: .png)
    let tiff = png == nil ? pasteboard.data(forType: .tiff) : nil
    if png == nil && tiff == nil {
      result(nil)
      return
    }
    let root = stagingRoot
    DispatchQueue.global(qos: .userInitiated).async {
      var data = png
      if data == nil, let tiff, let rep = NSBitmapImageRep(data: tiff) {
        data = rep.representation(using: .png, properties: [:])
      }
      guard let bytes = data else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let name = "Pasted Image.png"
      var entry: [String: Any] = ["name": name, "mime": "image/png", "size": bytes.count]
      if bytes.count > kMaxDropMediaBytes {
        entry["oversize"] = true
      } else {
        do {
          let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          let destination = folder.appendingPathComponent(name)
          try bytes.write(to: destination)
          entry["path"] = destination.path
        } catch {
          NSLog("drop: could not stage pasted image: \(error.localizedDescription)")
        }
      }
      DispatchQueue.main.async { result(["files": [entry]]) }
    }
  }

  // ─────────────────────────────── staging ───────────────────────────────

  /// Copies each dropped file into our own cache and describes the copy.
  ///
  /// The copy is the point. A sandboxed app's access to a dragged URL is a
  /// grant made for the drag; holding that URL and reading it ninety seconds
  /// later — which is exactly what happens when the drop opens the photo
  /// editor and the user starts cropping — is relying on something nobody
  /// promised. Reading our own copy asks nobody's permission, and it is the
  /// same contract `ShareIntake` already runs for the system share sheet.
  private func stage(_ urls: [URL]) -> [[String: Any]] {
    let manager = FileManager.default
    var out: [[String: Any]] = []
    for url in urls {
      let name = url.lastPathComponent
      let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentTypeKey])
      let mime = values?.contentType?.preferredMIMEType ?? "application/octet-stream"
      let isDirectory = values?.isDirectory ?? false
      var entry: [String: Any] = ["name": name, "mime": isDirectory ? "inode/directory" : mime]

      if isDirectory {
        // Reported, not copied and not skipped: the refusal is worth a
        // sentence naming the folder, and recursively copying a directory to
        // then refuse it would be the worst of both.
        entry["size"] = 0
        out.append(entry)
        continue
      }

      let size = values?.fileSize ?? 0
      entry["size"] = size
      let media = mime.hasPrefix("image/") || mime.hasPrefix("video/")
      if size > (media ? kMaxDropMediaBytes : kMaxDropBytes) {
        entry["oversize"] = true
        out.append(entry)
        continue
      }

      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }

      do {
        let folder = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        // The original name is kept so the message carries what the sender's
        // filesystem called it — `ChatMessage.fileName` is what the recipient
        // sees, and a UUID would be a worse document than no name at all. The
        // UUID is the FOLDER, which is what makes two drops of `report.pdf`
        // safe to hold at once.
        let destination = folder.appendingPathComponent(name.isEmpty ? "file" : name)
        try manager.copyItem(at: url, to: destination)
        entry["path"] = destination.path
      } catch {
        NSLog("drop: could not stage \(name): \(error.localizedDescription)")
        // No path and not oversize: Dart reads that as a file with nothing
        // behind it and leaves it out, which beats claiming a copy that is
        // not there.
      }
      out.append(entry)
    }
    return out
  }

  private func release(_ paths: [String]) {
    let manager = FileManager.default
    let root = stagingRoot.standardizedFileURL.path
    DispatchQueue.global(qos: .utility).async {
      for path in paths {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        // Never delete anything outside our own staging root, whatever the
        // channel message says.
        guard url.path.hasPrefix(root + "/") else { continue }
        // The UUID folder, not just the file inside it.
        let folder = url.deletingLastPathComponent()
        try? manager.removeItem(at: folder.path.hasPrefix(root + "/") ? folder : url)
      }
    }
  }

  private func purgeStaging() {
    let root = stagingRoot
    DispatchQueue.global(qos: .utility).async {
      try? FileManager.default.removeItem(at: root)
    }
  }

  // ───────────────────────────── coordinates ─────────────────────────────

  /// Window coordinates (points, bottom-left origin) into Flutter's global
  /// space (logical pixels, top-left origin).
  ///
  /// The flip is the whole conversion: a logical pixel and a point are the
  /// same unit on this platform, so nothing is scaled. Falling back to the
  /// window's own content rect keeps a drag during a window rebuild from
  /// reporting a position off the top of the screen.
  private func convert(_ point: NSPoint) -> (x: Double, y: Double) {
    guard let view = window?.contentViewController?.view ?? window?.contentView else {
      return (x: Double(point.x), y: Double(point.y))
    }
    let inView = view.convert(point, from: nil)
    let y = view.isFlipped ? inView.y : view.bounds.height - inView.y
    return (x: Double(inView.x), y: Double(y))
  }
}
