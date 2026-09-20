// The OS's side of a drag.
//
// Two implementations, chosen at compile time, because the two platforms that
// have a desktop drag are the two that share nothing at all mechanically:
//
//   * **macOS** — `MainFlutterWindow` registers itself as an
//     `NSDraggingDestination` and pushes `enter` / `move` / `exit` / `drop`
//     over the `monkeyhub/drop` method channel. It reads the pasteboard during
//     the drag, so names and sizes arrive on hover, and it stages the dropped
//     files into our own cache before Dart hears about them.
//   * **web** — DOM `dragenter` / `dragover` / `dragleave` / `drop` on the
//     document, via `dart:js_interop`. `DataTransfer` withholds names until
//     the drop, so the hover carries MIME types and a count and nothing else.
//
// `dart.library.js_interop` rather than `dart.library.html`, deliberately: the
// web deploy is `flutter build web --wasm` and dart2wasm ships no `dart:html`,
// so an `if (dart.library.html)` condition silently resolves to the stub there
// — see the note on `lib/media/blob_url.dart`, which still has that bug.
//
// Every other platform gets `DropChannel.isSupported == false` from the io
// file and nothing is ever installed. There is no drag to receive on a phone.
export 'drop_channel_io.dart' if (dart.library.js_interop) 'drop_channel_web.dart';
