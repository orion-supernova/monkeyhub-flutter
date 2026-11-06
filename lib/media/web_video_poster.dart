// A poster frame for a video picked in a browser.
//
// `VideoPoster` is mobile-only: its plugin has no web implementation. A
// browser can decode the clip itself, though: a muted `<video>` on an object
// URL, seeked a little way in and drawn onto a canvas. That needs
// `dart:js_interop`, hence the conditional export; off-web the stub answers
// null and the caller keeps using `VideoPoster`.
export 'web_video_poster_io.dart' if (dart.library.js_interop) 'web_video_poster_web.dart';
