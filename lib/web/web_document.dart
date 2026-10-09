// The browser document, from Dart: the tab title and the deep link the page
// was opened on.
//
// On web this resolves to the interop implementation; on every other platform
// to a no-op stub, so callers stay free of `dart:js_interop` / `package:web`
// and native builds never import them. Same pattern as push/web_badge.dart.
export 'web_document_io.dart' if (dart.library.html) 'web_document_web.dart';
