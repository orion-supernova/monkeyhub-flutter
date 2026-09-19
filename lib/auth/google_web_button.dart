// Google's own rendered sign-in button.
//
// Only the web draws Google's button instead of ours: google_sign_in 7 has no
// `authenticate()` there, because Google Identity Services mints an ID token
// only from a click on its own button. See
// `SocialSignIn.googleUsesRenderedButton`. Every other platform resolves to a
// stub that is never reached.
//
// `dart.library.js_interop` rather than the `dart.library.html` the older
// indirections use: the web build is `--wasm`, and dart2wasm has no dart:html,
// so an `html` condition would quietly pick the stub there.
export 'google_web_button_io.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
