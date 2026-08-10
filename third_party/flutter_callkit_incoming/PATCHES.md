# flutter_callkit_incoming 3.1.3 — vendored, with patches

Vendored from the pub.dev archive of `flutter_callkit_incoming 3.1.3`
(sha256 `0e418f2c7fdbddeebc0288ce0e10c17fd01c1a886731d5cb1048d86b72443b92`,
the exact hash pinned in `pubspec.lock`), minus `example/`, `images/`, and
the `.iml`. Every deliberate change is marked `MONKEYHUB PATCH n` in-source;
`rg -n "MONKEYHUB PATCH"` is the complete list.

## Provenance notes (patch 0 — what we inherited, unchanged)

- The pub-served archive is NOT the upstream GitHub tree: it already ships
  UUID-guard blocks (`[CallkitIncoming]` NSLogs referencing a "SnowChat"
  crash) in `CallManager.swift` and `SwiftFlutterCallkitIncomingPlugin.swift`,
  plus `showCallkitIncoming(onError:)` / `showCallkitIncoming(completion:)`
  overloads that `ios/Runner/AppDelegate.swift` compiles against. These are
  inherited as-is — they ARE what pub.dev serves for 3.1.3, verified by a
  normalized byte-for-byte diff against the freshly downloaded archive.
- The pub archive's `SwiftFlutterCallkitIncomingPlugin.swift` contains 2602
  stray NUL bytes (a UTF-16-pasted region) and CRLF line endings; the
  vendored copy strips/normalizes both. This is a pure encoding cleanup —
  the normalized content is identical.
- **Android (`android/`), and all Dart files except the two listed under
  patch 5, are unmodified** — this bounds the regression surface: no ring
  path, notification, or foreground-service behavior changed on Android.

## The patches

All in `ios/flutter_callkit_incoming/Classes/SwiftFlutterCallkitIncomingPlugin.swift`
unless noted.

1. **Stale mic / orange dot (D1).** `configureAudioSession()` runs
   `setCategory(.playAndRecord)` + `setActive(true)` on every dial, answer,
   ring, and `didActivate` — and upstream never calls `setActive(false)`
   anywhere. flutter_webrtc's own deactivation is gated on "no local audio
   track AND zero peer connections" at moments the cancel path can never
   satisfy, so a canceled outgoing call left the session active and the
   iOS mic indicator lit indefinitely. New `deactivateAudioSessionIfIdle()`
   (no-op while any CallKit call is alive) runs at the end of the
   `CXEndCallAction` handler, in `endAllCalls()`, in `callEndTimeout`, and
   in `provider(_:didDeactivate:)`.
2. **Decline-becomes-ended (D2).** `self.outgoingCall` was assigned on
   `CXStartCallAction` and never cleared, so after the first outgoing call
   of the process: an incoming decline took the ENDED branch (the app then
   never sent its reject upstream — the caller rang out the full 30 s
   timeout), `didActivate` short-circuited for every later call, and
   `endCallNotExist`'s 60 s auto-timeout went dead. The `CXEndCallAction`
   handler now classifies decline-vs-ended from the call itself
   (`call.data.isAccepted || call.isOutGoing`) and nils
   `outgoingCall`/`answerCall` by UUID match (also in `endAllCalls()`).
3. **Post-teardown re-activation (D3).** The answer path re-ran
   `configureAudioSession()` unguarded 1200 ms later, and `didActivate`
   re-ran it for queued activations — both could `setActive(true)` AFTER
   the call's teardown (hang up within ~1.2 s of answering). Both sites now
   guard on call liveness (`callManager` still holding the call / any call).
4. **Wrong-UUID end (D5).** The `handle("endCall")` case clobbered
   `self.data` with a bare `{id}` stub (poisoning the next
   `configureAudioSession`'s mode back to `.default`), and its PushKit
   branch ignored the requested id entirely — `endCall` ended whatever call
   the LAST invite push was for, so a missed-then-cleared card targeted a
   stale UUID, the `CXEndCallAction` failed, and the intended card
   survived. `endCall(_:)` now prefers the requested UUID (stored-invite
   fallback only when the requested one doesn't parse) and the handler no
   longer touches `self.data`.
5. **Dart parser gaps** (`lib/flutter_callkit_incoming.dart`,
   `lib/entities/call_event.dart`). The audio-session event is sent with
   key `isActivate` but the parser demanded `isActive` and threw — the
   event never reached Dart (the app's speaker-route re-asserts exist to
   compensate; they are kept). The parser now accepts both spellings, and
   the Swift sends both. `ACTION_CALL_PROVIDER_DID_RESET` had no Dart
   constant/variant and fell through the parser's default — CallKit could
   tear down every call without the app ever hearing about it. Added
   `CallEventActionCallProviderDidReset` (consumed by
   `NativeCallHandler` → full local teardown).

## When bumping the plugin version

Re-apply every `MONKEYHUB PATCH` block against the new version (or drop the
ones upstream fixed), and re-check the pubspec pin note about 1.5.x/newer
audio-session handling before touching flutter_webrtc in the same change.
Pub will otherwise silently take these fixes away — the symptom is the
orange dot coming back on canceled calls and declines that ring forever.
