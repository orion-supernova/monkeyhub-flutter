/// The platform's speech engine, or null where there is none (web).
///
/// A conditional import because `whisper_ggml` is `dart:ffi`, which a web
/// build cannot compile at all — not merely cannot run.
library;

export 'whisper_engine_io.dart'
    if (dart.library.js_interop) 'whisper_engine_web.dart';
