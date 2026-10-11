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
- All Dart files except the two listed under patch 5 are unmodified.
  Android (`android/`) was unmodified until 2026-10-11; it now carries the
  upstream 3.1.4-3.1.6 Android fixes plus patches B-F, listed below.

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
6. **Ended calls in `activeCalls` (iOS, `CallManager.swift`).** The list is
   read from `CXCallObserver`, which keeps an ended call listed for a while,
   and any call the plugin holds no entry for (AppDelegate's fallback ringer,
   or a card whose entry was dropped) comes back as a bare `{id}` with no
   `extra`. `NativeCallHandler.cardGone` read such a bare entry as "not this
   call", so a still-ringing card could ack itself dismissed and switch off
   the server's `taken` push: the 2026-10-08 cancelled call that kept an
   iPhone ringing. Ended calls are now skipped, so a bare entry always means
   a live card the app cannot identify, which `cardGone` treats as not gone.
7. **`trackedCalls()` (iOS, `SwiftFlutterCallkitIncomingPlugin.swift`).** A
   read of the plugin's own `callManager.calls`, not filtered through
   `CXCallObserver` (which lags a just-reported card and keeps an ended one).
   AppDelegate decides "is this call's card still up" (`cardLive`, the basis
   of the dismissal ack) and "end this call's ringing card" (`callOver`, the
   native ring watch, the ring report's answer) from it, by the card's real
   UUID, so neither depends on Dart guessing the PushKit-minted id. Additive
   only; nothing upstream calls it.

A. **Call audio ownership (iOS, `SwiftFlutterCallkitIncomingPlugin.swift`).**
   `configureAudioSession()` wrote playAndRecord with no `defaultToSpeaker`,
   the per-call mode (`videoChat` force-sets the speaker) and a 44.1 kHz
   preferred rate at ring, dial, answer, 1.2 s after answer and every
   `didActivate`. Each category write dropped the app's speaker override, so
   the sound jumped between earpiece and speaker until Dart re-asserted a
   round trip later, and the rate write restarted WebRTC's audio unit. New
   static hooks `callAudioConfigurator` (the host writes category/mode/route;
   the plugin keeps only `setActive`) and `audioSessionIdleHandler` (after
   `deactivateAudioSessionIfIdle`, so the host restores its non-call
   category). `didActivate` also runs the configurator first, including for a
   connected call's re-activation, which returned early before. A third hook,
   `callAudioLive`, fires at `CXAnswerCallAction` and `CXStartCallAction`
   before their configure, so the host turns on the in-call screen behaviour
   (idle timer off, proximity sensor) only once a call is really live and
   never for a card that is only ringing. The host side is `CallAudioRouter`
   in `ios/Runner/AppDelegate.swift`. With no hook set the plugin behaves
   exactly as upstream.
8. **CallKit lifecycle fixes from the 2026-10-11 ghost-ring audit (iOS).**
   Compared against upstream 3.1.6.
   - **8a** `CXEndCallAction` for a call the plugin has no entry for used to
     `fail()` (the call stays ALIVE, the card keeps ringing) and tell Dart
     TIMEOUT with `self.data`, the last invite, possibly a different call.
     Now fulfills, and reports DECLINE/ENDED only when `self.data` is this
     call.
   - **8b** `callConnected` connected `self.data` (the last invite) on the
     PushKit branch whatever id was asked for, and clobbered `self.data` with
     a bare stub on the other. Now connects the requested id; the stored
     invite is only a fallback for an unparseable one.
   - **8c** (upstream #850) no `configureAudioSession()` before
     `reportNewIncomingCall` on the non-PushKit path.
   - **8d** `timedOutPerforming` looked the call up by the ACTION's uuid (never
     a call) and then fulfilled/failed a timed-out action, which CallKit
     forbids. Resolves via `CXCallAction.callUUID`, completes nothing.
   - **8e** `CallManager.endCall`: a refused end transaction was a `print()`
     and the card rang on. Now NSLogs and falls back to
     `reportCall(endedAt:reason: .remoteEnded)`, dropping the entry and
     letting the audio session go.
   - **8f** `CallManager.connectedCall` connects once, and requests a
     `CXAnswerCallAction` only for an incoming card not yet answered (each
     repeat used to re-emit ACCEPT to Dart). `NativeCallHandler.markConnected`
     also reports each call once.

## Android (2026-10-11)

U. **Upstream 3.1.4-3.1.6, Android only, ported by hand** (diff of the 3.1.3
   archive against 3.1.6, applied on top of B-F): placeholder
   `startForeground` (PHONE_CALL) before any work and `START_NOT_STICKY` with
   null-intent recovery in `CallkitNotificationService` (#857); MICROPHONE /
   CAMERA service types only when granted (#848); no full-screen-intent
   settings page thrown over the incoming screen on Android 14+ (#856);
   `CallkitSoundPlayerManager.play` honours the ringer mode (silent: nothing,
   vibrate: no ringtone); the volume key silences only on STREAM_RING and
   `CallkitConnection.onSilence` stops the ringtone (#855); the incoming
   activity's wake lock is released on answer/decline and the activity is
   `showWhenLocked` in the manifest; `PERMISSION_CALL` is `signature`, the
   activity's receiver `RECEIVER_NOT_EXPORTED`, `registerPhoneAccount` cannot
   crash startup, unknown method calls answer `notImplemented`; Telecom hold
   is forwarded and self-resumed (`CAPABILITY_HOLD`). **Not ported:** 3.1.6's
   `registerTelecomOutgoingCall` (`placeCall` on `ACTION_CALL_START`). It
   would hand every outgoing call's audio mode to Telecom alongside
   flutter_webrtc's AudioSwitch; that needs a device test first.

B. **Ended-call registry** (`SharedPreferencesUtils.kt`, `markCallEnded` /
   `isCallEnded`, own prefs file `flutter_callkit_incoming_ended`, 10 min
   TTL). Written on DECLINE / ENDED / TIMEOUT, by `endCall` (public and the
   method channel, even when no card is listed yet) and by the host's
   `CallFcmService` on a `taken` push. Read by: the INCOMING receiver (drops
   an ended or already-shown id: upstream #878, and a second INCOMING used
   to orphan a RINGING Telecom connection), `onCreateIncomingConnection`
   (refuses an ended or duplicate id: upstream #879), the ACCEPT receiver
   (an Accept on an ended call starts nothing), and `CallkitIncomingActivity`
   (closes itself in onCreate/onResume and refuses Accept for an ended id:
   upstream #881).

C. **Foreground broadcast queue.** Every intent the receiver's companion
   builds carries `FLAG_RECEIVER_FOREGROUND`; the background queue could
   hold a cancel's ENDED for seconds on a busy phone.

D. **Scoped ENDED** (upstream #887). An ENDED naming no listed card and no
   Telecom connection, while another call is listed, returns early: its
   un-scoped sound stop and `stopService` used to cut a live call's
   foreground service (and so its mic in background).

E. **Telecom answer/reject reach the app** (upstream #886).
   `CallkitConnection.onAnswer` / `onReject` / `onDisconnect` send the same
   ACCEPT / DECLINE / ENDED broadcasts as the card's buttons (and onAnswer
   opens the app), so a headset, car or watch answer or reject is no longer
   Telecom-only.

F. **Log tag.** `CallkitIncomingBroadcastReceiver.RING_TAG = "MHCallRing"`,
   shared with the host's `CallFcmService`: `adb logcat -s MHCallRing`.

G. **Full-screen card hears its end** (`CallkitIncomingActivity.getIntentEnded`).
   Upstream gave the ended broadcast a component (`setClassName` to the
   activity), and a runtime-registered receiver only gets broadcasts whose
   component is null, so `EndedCallkitIncomingBroadcastReceiver` never
   fired: a cancel, `taken` or ring-watch end left the locked-screen card
   up until its timeout or the next resume. Now package-scoped only, and it
   carries the ended call's id (`clearIncomingNotification` passes it) so an
   end for a different call cannot close the card. The other `setClassName`
   intents in the plugin target the MANIFEST receiver/activity, where an
   explicit component is right.

H. **Ongoing-call service survives its own failure**
   (`CallkitNotificationService.onStartCommand`). Its catch used to
   `stopSelf()` after the placeholder `startForeground` succeeded, taking
   the foreground service (and the background mic) from a live call. Now
   the placeholder stays, re-posted under the call's types (microphone,
   camera for video) best effort.

## When bumping the plugin version

Re-apply every `MONKEYHUB PATCH` block against the new version (or drop the
ones upstream fixed), and re-check the pubspec pin note about 1.5.x/newer
audio-session handling before touching flutter_webrtc in the same change.
Pub will otherwise silently take these fixes away — the symptom is the
orange dot coming back on canceled calls and declines that ring forever.
