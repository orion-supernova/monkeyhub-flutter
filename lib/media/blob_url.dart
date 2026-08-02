// Blob object-URL indirection.
//
// On web there is no filesystem, so the trick the native audio path uses —
// download the bytes to a correctly-named file and let the OS read the
// extension — has no equivalent. The web version of the same idea is to wrap
// the bytes in a Blob carrying the right MIME and hand the media element an
// object URL, which is what `AudioFileCache.webPlayableUrl` does.
//
// This needs `dart:js_interop`, which cannot be compiled for the VM, hence the
// conditional export. Off-web it resolves to a stub that returns null and the
// caller falls back to the plain URL.
export 'blob_url_io.dart' if (dart.library.html) 'blob_url_web.dart';
