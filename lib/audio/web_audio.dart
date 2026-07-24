// Web audio indirection.
//
// On web, alert sounds go through a raw HTMLAudioElement rather than just_audio.
// Why: just_audio's web backend uses the Web Audio API, which browsers SUSPEND
// while a tab is hidden — so a new-message ping was silent in the background
// (exactly when you most need it). An <audio> element keeps playing across tab
// switches and can start playback from a hidden tab once unlocked by a gesture.
// Off-web this resolves to a no-op stub (native/desktop use just_audio).
export 'web_audio_io.dart' if (dart.library.html) 'web_audio_web.dart';
