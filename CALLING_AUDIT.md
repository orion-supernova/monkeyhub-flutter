# Calling Mechanism Audit — MonkeyHub

**Scope:** 1:1 WebRTC calling and the push/wake pipeline that rings the callee.
**Symptom under investigation:** incoming calls are supposed to ring the native UI
(iOS CallKit / Android ConnectionService) *every time*, but they routinely "fall
back" to a plain notification.

**TL;DR:**
- **Android rings a plain notification 100% of the time** because Firebase/FCM was
  removed (commit `3566a7a "android firebase removed and build fixed"`). The
  device never registers an FCM token, so the backend has no native channel to ring.
- **iOS works in local/dev but breaks on TestFlight/App Store** because the app
  ships a `development` APNs entitlement while distribution requires `production`.
- The "plain notification" is **not a runtime fallback** — the backend always fires
  *both* an OneSignal plain push **and** a native VoIP push in parallel. When the
  native push is missing/rejected, OneSignal is simply the only one that lands.

---

## 1. End-to-end call flow

### 1a. Outbound (caller)
```
CallService.initiate()                         lib/calls/call_service.dart:152
  → CallApi.initiateCall()                     lib/backend/call_api.dart  (calls:initiate)
    → backend calls.initiate()                 backend/convex/calls.ts:~70
       schedules, in parallel:
         • calls.sendCallPush  (OneSignal)     backend/convex/calls.ts:174 → :681
         • voipPush.sendVoip   (APNs + FCM)    backend/convex/calls.ts:187 → voipPush.ts:63
  → CallService gets ICE: CallApi.getIceConfig()        call_service.dart:111
  → WebRTC offer/ICE shipped via CallApi.sendCallSignal() call_service.dart:200,259,…
```

### 1b. Inbound (callee) — the wake path (app backgrounded/killed)
```
APNs VoIP push  → iOS AppDelegate.didReceiveIncomingPushWith   ios/Runner/AppDelegate.swift:70
                  → SwiftFlutterCallkitIncomingPlugin.showCallkitIncoming(fromPushKit:true)  (:145)
                  → CXProvider.reportNewIncomingCall  (REQUIRED on iOS 13+)
FCM data push   → [Android FirebaseMessagingService → ConnectionService]   ** MISSING **

then, on user tap:
  FlutterCallkitIncoming.onEvent → NativeCallHandler._onEvent  lib/calls/native_call_handler.dart:74
    → CallService.markAcceptedNatively() / acceptIncoming() / reject()   (:92-96)
```

### 1c. Inbound — the realtime path (app already foreground)
Push is **not** used when the app is alive. A live Convex subscription delivers signals:
```
SignalingSubscriber.start() → CallApi.subscribeCallSignals()   lib/calls/signaling_subscriber.dart:28
  → CallService.handleRemoteSignal()
ActiveCallPill → CallApi.subscribeActiveCall()  (the "Move call here" pill)  active_call_pill.dart:62
```
> This is why calls often "work in the foreground but not when the phone is locked":
> the foreground path never touches push.

---

## 2. Push decision matrix

| Platform | App state | Channel that *should* ring | What actually happens today |
|---|---|---|---|
| iOS (dev/sandbox build) | bg/killed | APNs VoIP → CallKit | ✅ Works (entitlement `development` matches `APNS_SANDBOX=true`) |
| iOS (TestFlight/App Store) | bg/killed | APNs VoIP → CallKit | ❌ `development` token invalid vs prod APNs → OneSignal plain notif |
| iOS (any) | foreground | realtime subscription | ✅ Works (no push needed) |
| Android (any build) | bg/killed | FCM data → ConnectionService | ❌ No FCM token ever registered → OneSignal plain notif |
| Android (any) | foreground | realtime subscription | ✅ Works (no push needed) |
| macOS/Win/Linux/Web | any | (no native wake) | realtime only; OneSignal/registry by design |

---

## 3. Every branch that leads to "OneSignal-only" (plain notification)

1. **Both pushes always fire** — there is no "try native, else plain" logic:
   ```ts
   // backend/convex/calls.ts
   :174  await ctx.scheduler.runAfter(0, internal.calls.sendCallPush, {...}); // OneSignal
   :187  await ctx.scheduler.runAfter(0, internal.voipPush.sendVoip,   {...}); // APNs+FCM
   ```
2. **No device rows → sendVoip returns early:**
   ```ts
   // backend/convex/voipPush.ts:76-78
   if (devices.length === 0) {
     console.log("sendVoip: no devices for callee — OneSignal-only path");
     return;
   }
   ```
3. **Per-device skips** (`voipPush.ts:157`, `:186`): APNs skipped if `voipToken` missing
   or `platform === "ios-simulator"`; FCM skipped if `fcmToken` missing.
4. **Client never uploads an Android token:** `MainActivity.kt` `getToken` returns `null`,
   so `PushManager._uploadFcmToken(null)` early-returns (`lib/push/push_manager.dart:188-198`)
   — and because it returns before any `registerDevice`, **the Android device gets no row at all**.

---

## 4. Root causes (ranked)

### #1 — Android FCM is gone (always broken) — **PRIMARY**
- `android/app/src/main/kotlin/.../MainActivity.kt` `getToken` → `result.success(null)`
  ("Firebase disabled").
- No `google-services.json`; no `com.google.gms.google-services` plugin / `firebase-messaging`
  dependency in `android/app/build.gradle.kts`.
- No `FirebaseMessagingService` and no `com.google.firebase.MESSAGING_EVENT` service in
  `AndroidManifest.xml`.
- No `USE_FULL_SCREEN_INTENT` permission (Android 12+ needs it for full-screen incoming-call UI).
- **Effect:** the chain in §3.4 → §3.2 → every Android call rings only the OneSignal banner.
- **Fix:** requires your Firebase project assets — see §6 runbook. *(Not done in this PR.)*

### #2 — iOS distribution entitlement mismatch — **breaks prod**
- `ios/Runner/Runner.entitlements` shipped `aps-environment = development`.
- Backend defaults `APNS_SANDBOX="true"` → `api.sandbox.push.apple.com`
  (`voipPush.ts:223,236`). Dev build + sandbox host = consistent → dev works.
- A distribution build's provisioning profile uses **production** APNs; a token minted
  under a `development` entitlement is rejected by the prod host → only OneSignal lands.
- **Fix (this PR), two parts:**
  1. Added `ios/Runner/RunnerRelease.entitlements` with `aps-environment = production`,
     wired to **Release** and **Profile** configs in `project.pbxproj` (Debug keeps
     `development`). Now each build mints the correct token type.
  2. **Per-token APNs environment** (replaces the single global `APNS_SANDBOX` flag, which
     could only serve sandbox *or* production — never both on one deployment). The client
     tags every VoIP token with the environment of the build that minted it
     (`kDebugMode ? "sandbox" : "production"`, `lib/push/push_manager.dart`), stored on
     `userDevices.apnsEnv` (`schema.ts`, `voipTokens.setVoipToken`). `sendApnsVoip` then
     picks `api.sandbox.push.apple.com` vs `api.push.apple.com` **per token**
     (`voipPush.ts`), falling back to the `APNS_SANDBOX` env only for legacy rows that
     predate this field. Result: a Debug-on-device build and a TestFlight build both ring
     correctly against the **same** Convex deployment.
- **`APNS_SANDBOX` is now optional** — only the fallback for pre-migration tokens. Setting
  it `false` is harmless; once every client re-logs-in, each token carries its own env and
  that wins. (Simulator still cannot receive VoIP at all — foreground realtime only.)

### #3 — Backend swallows config/transient errors — **hides misconfig**
- Previously `pushToDevice` only reacted to `*_BAD_TOKEN` (410/400); any other error
  (missing APNs env, expired `.p8`, JWT failure, malformed FCM service-account JSON,
  401/403, 429/5xx) was logged and ignored. A misconfigured prod silently rings nobody,
  and (worse) stale tokens were never distinguished from server faults.
- **Fix (this PR):** three error classes with sentinel prefixes in
  `sendApnsVoip` / `sendFcmData` and matching handling in `pushToDevice`:
  - `*_BAD_TOKEN` (410/400/UNREGISTERED) → clear that device's token (unchanged).
  - `*_MISCONFIG` (missing env, bad key/JSON, 401/403) → log
    **`CALL_PUSH_MISCONFIG: …`** loudly, never clear the token.
  - `*_TRANSIENT` (429/5xx/network) → log, never clear, retry on next call.
  - Grep prod logs for `CALL_PUSH_MISCONFIG` to instantly spot a broken deployment.

### #4 — iOS pre-login PushKit token could be dropped — **minor**
- PushKit issues the VoIP token at launch, often *before* sign-in. The `onTokenUpdated`
  handler (`push_manager.dart:92`) early-returns when `_userId == null`, so a token that
  arrived pre-login relied entirely on the `getToken` pull at login.
- **Fix (this PR):** cache the latest token in `_pendingVoipToken` regardless of login
  state and flush it during `login()` if `getToken` returns null.

> **Correction to first-pass analysis:** the `onTokenUpdated` rotation handler *is*
> wired in `PushManager.initialize` — iOS is not missing it. The real iOS issue is the
> entitlement (#2), not a missing callback.

---

## 5. What this PR changed

**Fixes (no external assets):**
- `ios/Runner/RunnerRelease.entitlements` (new) + `project.pbxproj` Release/Profile wiring — root cause #2 (part 1).
- Per-token APNs env — root cause #2 (part 2): `schema.ts` (`userDevices.apnsEnv`),
  `voipTokens.setVoipToken` (accept/store), `voipPush.ts` (per-token host selection),
  `lib/backend/chat_api.dart` (`setVoipToken` param), `lib/push/push_manager.dart`
  (tag `kDebugMode ? sandbox : production`).
- `backend/convex/voipPush.ts` — three-class error handling + `CALL_PUSH_MISCONFIG` marker — root cause #3.
- `lib/push/push_manager.dart` — `_pendingVoipToken` cache + flush on login — root cause #4.

**Dead code deleted:**
- `CallApi.activeCallForUser` (`lib/backend/call_api.dart`) — unused; only `subscribeActiveCall` is live.
- `clearTokens` mutation (`backend/convex/voipTokens.ts`) — deprecated shim, no callers.

**Still required to fully fix the symptom:**
- Android Firebase re-enable (root cause #1) — §6.
- iOS: nothing more for the env — per-token handles sandbox + production on one
  deployment. (`APNS_SANDBOX` is now just the legacy fallback; optional.)

---

## 6. Android Firebase re-enable runbook *(needs your Firebase project)*

1. **Firebase console:** add the Android app (package `com.walhallaa.chattest20241220`);
   download `google-services.json` → place in `android/app/`.
2. **Gradle:**
   - `android/settings.gradle.kts` (or root `build.gradle.kts`): add plugin
     `id("com.google.gms.google-services") version "<latest>" apply false`.
   - `android/app/build.gradle.kts`: `id("com.google.gms.google-services")`; add
     `implementation(platform("com.google.firebase:firebase-bom:<latest>"))` and
     `implementation("com.google.firebase:firebase-messaging")`.
3. **`MainActivity.kt`:** implement the `monkeyhub/fcm` `getToken` to return a real token
   via `FirebaseMessaging.getInstance().token` (await), replacing `result.success(null)`.
4. **`FirebaseMessagingService`:** add a subclass; in `onMessageReceived`, detect call
   data-messages (the payload `sendFcmData` sends) and route them into
   `flutter_callkit_incoming` (`showCallkitIncoming`) so ConnectionService rings — do **not**
   post a normal notification for calls. Register it in `AndroidManifest.xml` with the
   `com.google.firebase.MESSAGING_EVENT` intent filter. Also forward token-refresh
   (`onNewToken`) so rotated tokens reach `api.setFcmToken`.
5. **Manifest permissions:** add `USE_FULL_SCREEN_INTENT` (Android 12+) alongside the
   existing `FOREGROUND_SERVICE*` permissions.
6. **Backend env:** ensure `FCM_SERVICE_ACCOUNT_JSON` is set on the Convex deployment
   (service-account JSON for the same Firebase project).
7. **Verify:** background the app, place a call → ConnectionService full-screen ringer
   appears; check logs show `sendVoip: FCM OK device=…` (not `CALL_PUSH_MISCONFIG`).

### iOS production checklist
- Distribution builds now use `RunnerRelease.entitlements` (`aps-environment=production`) — confirm Xcode signing is clean.
- Per-token env means **no `APNS_SANDBOX` juggling** — Debug device + TestFlight both ring on one deployment after each re-logs-in (so its token carries `apnsEnv`).
- Ensure valid `APNS_KEY_ID/TEAM_ID/BUNDLE_ID/KEY_P8`; `APNS_BUNDLE_ID` must be the app bundle id (topic is `${bundleId}.voip`). `APNS_SANDBOX` is optional (legacy-token fallback only).

---

## 7. Verification (run by you — project convention is you run Flutter/Convex)
- `flutter analyze` → no new errors (touches `call_api.dart`, `push_manager.dart`).
- Backend typecheck/`npx convex dev` → compiles (touches `voipPush.ts`, `voipTokens.ts`).
- iOS: Debug builds keep `development` entitlement; Archive/Release pick
  `RunnerRelease.entitlements` (production) with no provisioning errors.
- Smoke: iOS dev call backgrounded → CallKit rings (unchanged); iOS TestFlight after
  `APNS_SANDBOX=false` → CallKit rings; Android → still plain notif until §6 is done.
