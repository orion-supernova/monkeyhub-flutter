// Web presence indirection.
//
// On web this registers a `pagehide` handler so a closing tab flips the user
// offline immediately (a best-effort complement to the server-side staleness
// fallback, which is the real backstop when the beacon doesn't flush). On every
// other platform it resolves to a no-op stub. Mirrors `web_badge.dart`.
export 'web_presence_io.dart' if (dart.library.html) 'web_presence_web.dart';
