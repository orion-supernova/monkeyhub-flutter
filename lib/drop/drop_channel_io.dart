import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'drop_channel_events.dart';
import 'drop_item.dart';

/// The native half of desktop drag-and-drop.
///
/// Installed on macOS only. Windows and Linux have the same idea and none of
/// the same API, and neither is a platform this app ships; [isSupported] is
/// false there rather than half-true, so `DropController` never installs a
/// listener and no surface ever renders a drop affordance it cannot honour.
///
/// ### Why the bytes are staged
///
/// `performDragOperation` hands over `file://` URLs the app is granted access
/// to for the duration of the drag, under
/// `com.apple.security.files.user-selected.read-only`. That grant is not a
/// thing to still be leaning on ninety seconds later while the photo editor is
/// open and the user is deciding whether to crop — so the native side copies
/// each dropped file into `NSTemporaryDirectory()/monkeyhub-drop/<uuid>/`
/// before Dart hears about the drop at all, and [release] deletes the copy
/// once it has been consumed.
///
/// This is exactly the contract `ShareIntake` already runs for the system
/// share sheet (see `SharedItem`), including the treatment of oversize files:
/// nothing is copied for those, because twenty megabytes of disk churn to
/// produce a refusal is work with no outcome. They arrive with
/// [DroppedFile.oversize] set and no path.
class DropChannel {
  DropChannel._();
  static final DropChannel instance = DropChannel._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/drop');

  /// macOS only. `kIsWeb` is checked first so this never touches `Platform` in
  /// a browser — the convention the rest of this codebase uses.
  static bool get isSupported => !kIsWeb && Platform.isMacOS;

  bool _started = false;
  DropChannelHandlers? _handlers;

  /// Mirrors what was last pushed to the native side, so a redundant flip
  /// across a 200-row list does not become 200 platform-channel round trips.
  bool? _accepting;

  Future<void> start(DropChannelHandlers handlers) async {
    if (!isSupported || _started) return;
    _started = true;
    _handlers = handlers;
    _channel.setMethodCallHandler(_onCall);
    try {
      // Registration happens natively only once Dart says it is listening.
      // Without the handshake a drop during the splash would be accepted by a
      // window with nobody behind it — the cursor would show the copy badge
      // and the file would land nowhere.
      await _channel.invokeMethod<void>('ready');
    } on MissingPluginException {
      // A macOS build that predates the native half. Nothing to register.
      _started = false;
    } catch (e) {
      debugPrint('drop: could not register the native destination: $e');
      _started = false;
    }
  }

  /// Tells AppKit whether to draw the green copy badge on the cursor.
  ///
  /// `draggingUpdated:` has to answer synchronously and this crosses an async
  /// channel, so the native side caches the last answer and uses it for the
  /// next update — the badge is therefore at most one mouse-move behind the
  /// verdict chip, which at 60Hz nobody has ever seen. Making the native side
  /// block on Dart instead would put the engine's latency inside AppKit's drag
  /// loop, which is how a drag ends up stuttering.
  void setAccepting(bool accepting) {
    if (!isSupported || !_started || _accepting == accepting) return;
    _accepting = accepting;
    _channel
        .invokeMethod<void>('accepting', {'accept': accepting})
        .catchError((_) => null);
  }

  /// Reads a landed file's bytes off our own staged copy.
  Future<Uint8List?> read(DroppedFile file) async {
    final path = file.path;
    if (path == null) return file.bytes;
    try {
      return await File(path).readAsBytes();
    } catch (e) {
      debugPrint('drop: could not read staged copy $path: $e');
      return null;
    }
  }

  /// Deletes the staged copies behind [bundle].
  ///
  /// Fire-and-forget and failure-tolerant, for the reason `ShareIntake`'s own
  /// disposal gives: the worst case is a few megabytes in a temp directory the
  /// OS already reclaims on its own schedule, and the alternative — awaiting a
  /// delete on the path that just handed the user their photo editor — is a
  /// spinner for nothing.
  void release(DropBundle bundle) {
    if (!isSupported) return;
    final paths = [
      for (final f in bundle.files)
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;
    _channel
        .invokeMethod<void>('release', {'paths': paths})
        .catchError((_) => null);
  }

  // ─────────────────────────────── paste ───────────────────────────────

  /// Whether ⌘V can ask the system clipboard for files and images. macOS
  /// only, like the drag itself.
  static bool get canReadClipboard => isSupported;

  /// What ⌘V would paste, if it is something to ATTACH: Finder-copied files,
  /// or an image (a screenshot copied with ⌃⇧⌘4, a picture copied out of
  /// Preview or a browser). Null when the clipboard holds plain text, or
  /// nothing this app would send — the composer then runs its ordinary text
  /// paste.
  ///
  /// Text wins over an image when the clipboard has both, which it often
  /// does: Word and Pages put a picture of the copied words beside the words
  /// themselves, and pasting a screenshot of a sentence would be absurd.
  /// Files win over text, because Finder puts the file NAME on the clipboard
  /// beside the file.
  ///
  /// The native side stages a copy exactly as it does for a drop, so the
  /// result goes through the same intake and is released the same way.
  Future<DropBundle?> readClipboard() async {
    if (!isSupported) return null;
    try {
      final args = await _channel.invokeMethod<Map>('readClipboard');
      if (args == null) return null;
      final bundle = _bundleFrom(args);
      return bundle.files.isEmpty ? null : bundle;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('drop: could not read the clipboard: $e');
      return null;
    }
  }

  /// A browser hands pasted files to a page only through its `paste` event;
  /// macOS is asked directly by [readClipboard], so there is nothing to listen
  /// to here.
  Object addPasteListener(Future<void> Function(DropBundle bundle) onPaste) =>
      onPaste;
  void removePasteListener(Object token) {}

  Future<Object?> _onCall(MethodCall call) async {
    final h = _handlers;
    if (h == null) return null;
    final args = call.arguments as Map? ?? const {};
    switch (call.method) {
      case 'enter':
        h.onEnter(_snapshotFrom(args), _offsetFrom(args));
        return null;
      case 'move':
        h.onMove(_offsetFrom(args));
        return null;
      case 'exit':
        h.onLeave();
        return null;
      case 'drop':
        // Awaited on purpose. The native side holds its staged copies until
        // this returns, so a consumer that reads the bytes asynchronously
        // cannot lose them to its own cleanup.
        await h.onPerform(_bundleFrom(args), _offsetFrom(args));
        return null;
      default:
        return null;
    }
  }

  static Offset _offsetFrom(Map args) => Offset(
        (args['x'] as num?)?.toDouble() ?? 0,
        (args['y'] as num?)?.toDouble() ?? 0,
      );

  static String? _string(Object? v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  static DropSnapshot _snapshotFrom(Map args) {
    final raw = args['items'] as List? ?? const [];
    final items = <DropCandidate>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      items.add(DropCandidate(
        name: _string(entry['name']),
        mimeType: _string(entry['mime']),
        size: (entry['size'] as num?)?.toInt(),
        isDirectory: entry['dir'] == true,
      ));
    }
    return DropSnapshot(
      items: items,
      text: _string(args['text']),
      uri: _string(args['uri']),
      // The pasteboard carries both during the drag — this is the platform
      // that can say everything up front, and the hover card is built around
      // being able to.
      namesKnown: items.isNotEmpty,
      sizesKnown: items.isNotEmpty && items.every((i) => i.size != null),
    );
  }

  static DropBundle _bundleFrom(Map args) {
    final raw = args['files'] as List? ?? const [];
    final files = <DroppedFile>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = _string(entry['name']) ?? 'file';
      files.add(DroppedFile(
        name: name,
        mimeType: _string(entry['mime']) ?? 'application/octet-stream',
        size: (entry['size'] as num?)?.toInt() ?? 0,
        path: _string(entry['path']),
        oversize: entry['oversize'] == true,
      ));
    }
    return DropBundle(
      files: files,
      text: _string(args['text']),
      uri: _string(args['uri']),
    );
  }
}
