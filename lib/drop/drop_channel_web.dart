import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../media/file_meta.dart' show kMaxFileUploadBytes;
import 'drop_channel_events.dart';
import 'drop_item.dart';

/// The browser's side of drag-and-drop.
///
/// ### Why the listeners are on `document` and not on a zone
///
/// A file dropped on a page that did not `preventDefault` it is a NAVIGATION:
/// the browser leaves the app and opens the file. There is no undo for that —
/// the tab is gone, the socket is gone, and anything unsent with it. So every
/// `dragover` and every `drop` anywhere in the document is cancelled here,
/// including the ones that land nowhere useful, and a drop outside a zone is
/// dealt with by quietly doing nothing rather than by letting the default
/// through. This listener is a safety net first and a feature second.
///
/// ### What a browser will not tell us
///
/// `DataTransfer` exposes `items` during a drag but withholds `getAsFile()`
/// and every name until the `drop` event — deliberately, since a page could
/// otherwise read a directory listing off a hover. What survives is
/// `item.kind` and `item.type`, so the hover knows there are three files and
/// that two of them are `image/png`, and the verdict chip counts types instead
/// of naming files. [DropSnapshot.namesKnown] is false for the whole of a web
/// drag and the UI branches on it.
class DropChannel {
  DropChannel._();
  static final DropChannel instance = DropChannel._();

  /// Always, in a browser. Mobile browsers have no drag to receive and simply
  /// never fire these events, which costs four inert listeners and nothing
  /// else — cheaper than a user-agent sniff that would be wrong on a
  /// touchscreen laptop.
  static bool get isSupported => true;

  bool _started = false;
  DropChannelHandlers? _handlers;

  /// `dragenter` and `dragleave` both fire as the pointer crosses between
  /// child elements, so a naive `dragleave` handler tears the overlay down
  /// mid-drag and builds it straight back — a strobe. The counter is the
  /// standard fix: only the leave that takes the depth back to zero is real.
  int _depth = 0;

  /// Last position forwarded, so a `dragover` storm (Chrome fires it at the
  /// display's refresh rate for as long as the pointer is inside the window,
  /// even when the pointer is perfectly still) does not become a rebuild
  /// storm.
  Offset? _last;

  Future<void> start(DropChannelHandlers handlers) async {
    if (_started) return;
    _started = true;
    _handlers = handlers;
    final doc = web.document;
    doc.addEventListener('dragenter', _onDragEnter.toJS);
    doc.addEventListener('dragover', _onDragOver.toJS);
    doc.addEventListener('dragleave', _onDragLeave.toJS);
    doc.addEventListener('drop', _onDrop.toJS);
    // The safety net, and it earns its place twice.
    //
    // A drop the browser CANCELS — which is what happens whenever
    // `dropEffect` is left at 'none', i.e. every drop over something this app
    // will not accept — fires no `drop` event at all, so `drop` cannot be the
    // only thing that closes a session. And `dragenter` / `dragleave` are
    // counted in pairs, which is one dropped event away from a counter that
    // never returns to zero and an overlay that never fades.
    doc.addEventListener('dragend', _onDragEnd.toJS);
  }

  /// No-op in a browser. The cursor's copy badge is controlled by
  /// `dataTransfer.dropEffect`, which has to be set inside the event handler
  /// and is therefore set there — see [_onDragOver] — rather than pushed in
  /// from outside the way the macOS channel has to.
  void setAccepting(bool accepting) {
    _accepting = accepting;
  }

  bool _accepting = true;

  /// Already in memory by the time a bundle exists here: a browser has no
  /// filesystem to stage into, so [_readBundle] reads the whole file during
  /// the drop and [DroppedFile.bytes] is what comes out.
  Future<Uint8List?> read(DroppedFile file) async => file.bytes;

  /// No-op. Nothing was staged; the bytes are garbage-collected with the
  /// bundle.
  void release(DropBundle bundle) {}

  // ─────────────────────────────── handlers ───────────────────────────────

  void _onDragEnter(web.Event e) {
    final drag = e as web.DragEvent;
    final dt = drag.dataTransfer;
    if (dt == null || !_carriesSomethingWeWant(dt)) return;
    e.preventDefault();
    _depth++;
    if (_depth > 1) return;
    _last = null;
    _handlers?.onEnter(_snapshotOf(dt), _positionOf(drag));
  }

  void _onDragOver(web.Event e) {
    final drag = e as web.DragEvent;
    final dt = drag.dataTransfer;
    if (dt == null) return;
    if (!_carriesSomethingWeWant(dt)) return;
    // The line that stops the browser from navigating away. Unconditional for
    // anything we recognise, whether or not a zone is under the pointer.
    e.preventDefault();
    // What the cursor shows, and rather more than that: leaving this at 'none'
    // makes the browser CANCEL the drop outright — no `drop` event, no default
    // action, and a `dragleave` in its place. That is the behaviour we want
    // for a drop over something this app will not accept, and it is why
    // `dragend` above has to be able to close a session on its own.
    dt.dropEffect = _accepting ? 'copy' : 'none';

    // Chrome fires `dragover` continuously on a stationary pointer. Anything
    // that does not move the pointer cannot change the answer, so it does not
    // reach Dart.
    final at = _positionOf(drag);
    final last = _last;
    if (last != null && (last - at).distanceSquared < 1.0) return;
    _last = at;

    // A drag that began outside the window — dropped in from another app
    // without crossing a `dragenter` we saw, which happens when the window is
    // activated by the drag itself — still has to open a session.
    if (_depth == 0) {
      _depth = 1;
      _handlers?.onEnter(_snapshotOf(dt), at);
      return;
    }
    _handlers?.onMove(at);
  }

  void _onDragLeave(web.Event e) {
    if (_depth == 0) return;
    _depth--;
    if (_depth > 0) return;
    _last = null;
    _handlers?.onLeave();
  }

  void _onDragEnd(web.Event e) {
    if (_depth == 0 && _last == null) return;
    _depth = 0;
    _last = null;
    _handlers?.onLeave();
  }

  void _onDrop(web.Event e) {
    final drag = e as web.DragEvent;
    final dt = drag.dataTransfer;
    // Cancelled even when we are not going to use it: the default action for
    // an uncancelled file drop is to leave the app.
    e.preventDefault();
    _depth = 0;
    _last = null;
    if (dt == null) {
      _handlers?.onLeave();
      return;
    }

    // Read synchronously. `DataTransfer` is neutered the moment this handler
    // returns — `getAsFile`, `webkitGetAsEntry` and `getData` all stop working
    // — so every handle is taken now and the awaiting happens afterwards.
    final handles = <_WebHandle>[];
    final items = dt.items;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind != 'file') continue;
      // Non-null for a directory in every browser that implements the entries
      // API, which is all of them; null only means "could not tell", and a
      // directory reaches us as a zero-byte typeless File either way.
      final entry = item.webkitGetAsEntry();
      final file = item.getAsFile();
      if (file == null) continue;
      handles.add(_WebHandle(file: file, isDirectory: entry?.isDirectory ?? false));
    }
    // Same rule the hover snapshot applies: a Finder file drag carries a
    // `text/uri-list` of `file://` URLs beside the files themselves, and
    // pasting those into the composer would caption every photo with its own
    // path on the sender's disk.
    final text = handles.isEmpty ? _nonEmpty(dt.getData('text/plain')) : null;
    final uri = handles.isEmpty ? _nonEmpty(dt.getData('text/uri-list')) : null;
    final at = _positionOf(drag);

    unawaited(_deliver(handles, text, uri, at));
  }

  Future<void> _deliver(
    List<_WebHandle> handles,
    String? text,
    String? uri,
    Offset at,
  ) async {
    final files = <DroppedFile>[];
    for (final h in handles) {
      final size = h.file.size;
      final name = h.file.name;
      // A directory arrives as a zero-byte File with an empty type. It is
      // reported rather than dropped so the refusal can name it — "Folders
      // can't be sent" is a better answer than a silent no-op.
      if (h.isDirectory) {
        files.add(DroppedFile(
          name: name,
          mimeType: 'inode/directory',
          size: 0,
          oversize: false,
        ));
        continue;
      }
      if (size > kMaxFileUploadBytes) {
        // Not read. The refusal only needs the size, and pulling twenty-plus
        // megabytes through a `FileReader` to then refuse it would stall the
        // tab for the length of the read.
        files.add(DroppedFile(
          name: name,
          mimeType: _nonEmpty(h.file.type) ?? 'application/octet-stream',
          size: size,
          oversize: true,
        ));
        continue;
      }
      Uint8List? bytes;
      try {
        final buffer = await h.file.arrayBuffer().toDart;
        bytes = buffer.toDart.asUint8List();
      } catch (e) {
        debugPrint('drop: could not read $name: $e');
      }
      files.add(DroppedFile(
        name: name,
        mimeType: _nonEmpty(h.file.type) ?? 'application/octet-stream',
        size: size,
        bytes: bytes,
      ));
    }
    await _handlers?.onPerform(
      DropBundle(files: files, text: text, uri: uri),
      at,
    );
  }

  // ─────────────────────────────── internals ───────────────────────────────

  /// Whether this drag is one we are prepared to cancel the default for.
  ///
  /// `types` rather than `items`, because `types` is the one thing every
  /// browser populates on every drag event — Safari's `items` has been empty
  /// on `dragover` in shipping versions.
  static bool _carriesSomethingWeWant(web.DataTransfer dt) {
    for (final type in _typesOf(dt)) {
      if (type == 'Files' || type == 'text/uri-list' || type == 'text/plain') {
        return true;
      }
    }
    return false;
  }

  /// `DataTransfer.types` as Dart strings.
  ///
  /// Converted once per call rather than indexed through the `JSArray`: every
  /// index on a JS array crosses the interop boundary, and this runs on
  /// `dragover`, which fires at the display's refresh rate.
  static List<String> _typesOf(web.DataTransfer dt) =>
      [for (final t in dt.types.toDart) t.toDart];

  static DropSnapshot _snapshotOf(web.DataTransfer dt) {
    final candidates = <DropCandidate>[];
    final items = dt.items;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind != 'file') continue;
      candidates.add(DropCandidate(
        // No name and no size — see the class doc. `type` is the browser's own
        // guess from the extension and is empty for anything it has no
        // registration for, which the classifier reads as `DropKind.unknown`.
        mimeType: _nonEmpty(item.type),
      ));
    }
    // Safari's empty `items` on hover: fall back to knowing only that files
    // are coming. One anonymous candidate is honest — the count is unknown,
    // and the chip says "file" rather than inventing a number.
    if (candidates.isEmpty && _hasType(dt, 'Files')) {
      candidates.add(const DropCandidate());
    }
    return DropSnapshot(
      items: candidates,
      namesKnown: false,
      sizesKnown: false,
      // Flags, not contents: `getData` returns an empty string on every drag
      // event except `drop`, by design. Only claimed when no file is coming —
      // a file drag out of Finder also carries a `text/uri-list` of `file://`
      // URLs, and treating that as a link would put a `file:///Users/...`
      // string in the composer beside the photo it belongs to.
      carriesText: candidates.isEmpty && _hasType(dt, 'text/plain'),
      carriesLink: candidates.isEmpty && _hasType(dt, 'text/uri-list'),
    );
  }

  static bool _hasType(web.DataTransfer dt, String want) =>
      _typesOf(dt).contains(want);

  /// CSS pixels relative to the Flutter view, which is what Flutter's own
  /// global coordinate space is on this platform.
  ///
  /// The view's own offset is subtracted rather than assumed zero: the app is
  /// normally the whole page, but an embedder that hosts it in a positioned
  /// element would otherwise put every hover a header's height too low.
  static Offset _positionOf(web.DragEvent e) {
    final host = web.document.querySelector('flutter-view');
    final rect = host?.getBoundingClientRect();
    final dx = rect?.left ?? 0;
    final dy = rect?.top ?? 0;
    return Offset(e.clientX - dx, e.clientY - dy);
  }

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}

/// A file handle taken synchronously out of the drop event, before the
/// `DataTransfer` is neutered.
class _WebHandle {
  _WebHandle({required this.file, required this.isDirectory});
  final web.File file;
  final bool isDirectory;
}
