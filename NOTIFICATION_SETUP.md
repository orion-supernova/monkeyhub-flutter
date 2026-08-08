# Notification & Call-Push Setup

There is no push-notification vendor. The app registers directly with APNs and
FCM, browsers subscribe to Web Push, and the Convex backend talks to Apple,
Google and the browsers' push services itself — so volume is unlimited and free,
and the payloads are ours to shape.

The code ships everything needed for reliable pushes and incoming-call UI on
both platforms in every app state (foreground / background / killed). What
remains below needs console access and can't be done from the repo.

## How delivery works

| Path | Carries | iOS | Android | Web |
|---|---|---|---|---|
| Alert push (`backend/convex/push.ts`) | Chat, approvals, call banners, silent dismiss | APNs on topic `<bundle>` → `AppDelegate.swift` | FCM data-only → `CallFcmService.kt` → `ChatNotifications.kt` | Web Push (RFC 8291) → `web/mh-push-sw.js` |
| Ring push (`backend/convex/voipPush.ts`) | Call invite / taken | APNs VoIP on topic `<bundle>.voip` → CallKit | FCM data-only → full-screen call UI | — |
| Convex realtime subscription | In-app ringing while the app is open | ✓ | ✓ | ✓ |

Two things are worth internalising:

- **iOS holds two different APNs tokens on two different topics.** The PushKit
  token rings the phone; the ordinary token draws banners. Sending one on the
  other's topic returns `400 DeviceTokenNotForTopic`, and the dead-token sweep
  then clears a perfectly good credential — which silently stops that phone
  ringing, with a symptom pointing nowhere near notifications. They live in
  separate columns (`userDevices.voipToken` / `.apnsToken`) and `push.ts`
  structurally cannot see the VoIP one.
- **Android is sent data-only, always.** A `notification` payload would be
  rendered by the system and would skip `onMessageReceived` while backgrounded,
  forfeiting collapse, group summaries, per-room dismissal and active-room
  suppression. The cost is that a *force-stopped* app receives nothing until
  next launch — already true of the call path.

## 1. Apple: APNs key and the Time Sensitive capability

The APNs auth key (`.p8`) is already set and signs **both** topics — nothing new
is needed for it. What is new:

**Enable "Time Sensitive Notifications" on the App ID**
(developer.apple.com → Certificates, IDs & Profiles → Identifiers →
`com.walhallaa.chatTest-20241220`), then regenerate provisioning profiles.

Both entitlement files already declare
`com.apple.developer.usernotifications.time-sensitive`. If the capability is not
enabled on the App ID, **signing fails** — which is at least loud. If the
entitlement were missing instead, `interruption-level: time-sensitive` would be
**silently ignored**: no error, no log, and call banners simply get swallowed by
Focus. Verify by putting a device in Focus and calling it.

Existing Convex env (unchanged): `APNS_KEY_ID`, `APNS_TEAM_ID`,
`APNS_BUNDLE_ID`, `APNS_KEY_P8`, `APNS_SANDBOX`.

## 2. Firebase project (Android)

> Already done, and there is only one right answer: **`monkeyhub-2b2c6`** (project
> number `691782206017`), owned by **maymunpartisi0@gmail.com** — the same account
> that owns the Google Cloud project and the Play publishing service account. All
> three consumers below already point at it. Older MonkeyHub-named Firebase
> projects on muratcankoc@gmail.com (`monkey-hub-fa2a8`, `monkeychat-d01f0`) hold
> iOS-only apps, are wired to nothing, and must not be used. Re-do the steps below
> only if the project is ever lost.

1. https://console.firebase.google.com → **Add project** (name: anything, e.g.
   `monkeyhub`; Analytics optional — off is fine).
2. In the project: **Add app → Android**, package name exactly:
   `com.walhallaa.chattest20241220`
3. Download **google-services.json** → put it at `android/app/google-services.json`.
   (Gradle wiring is already committed; the build fails with a clear message
   until this file exists.)

Firebase is used **only** as an FCM transport. No Firebase SDK ships in the iOS
binary, which is why there is no `firebase_messaging` Flutter plugin — Android
FCM is wired natively through the `monkeyhub/fcm` method channel instead.

## 3. FCM service account in Convex

1. Firebase console → ⚙ **Project settings → Service accounts →
   Generate new private key** → downloads a JSON file.
2. Set it on the production deployment (https://termio-api.walhallaa.com):

   ```sh
   cd backend
   npx convex env set FCM_SERVICE_ACCOUNT_JSON "$(cat /path/to/service-account.json)"
   ```

   Without this, Convex logs `CALL_PUSH_MISCONFIG: FCM cannot send` on every
   push to an Android device.

## 4. Web Push: generate a VAPID key pair

Web Push identifies the sender with an ES256 key pair (RFC 8292). Generate it
once and keep it — rotating re-mints every existing browser subscription.

```sh
openssl ecparam -genkey -name prime256v1 -noout -out vapid.pem
openssl pkcs8 -topk8 -nocrypt -in vapid.pem -out vapid_pkcs8.pem

# The public half, as the raw uncompressed point in base64url:
openssl ec -in vapid.pem -pubout -outform DER | tail -c 65 | \
  base64 | tr '+/' '-_' | tr -d '='
```

```sh
cd backend
npx convex env set VAPID_PRIVATE_KEY_P8 "$(cat vapid_pkcs8.pem)"
npx convex env set VAPID_PUBLIC_KEY <the base64url value above>
npx convex env set VAPID_SUBJECT mailto:hey@swirlyourwines.com
```

Then put the **same public value** in `env.local` as `VAPID_PUBLIC_KEY` — the
browser is handed it verbatim to subscribe. It is public by design. Leaving it
blank simply disables web push; every other platform is unaffected, and it is
deliberately not in `Env.missing()` so it can never block an app launch.

Prove the encryption before trusting it — it is the only hand-rolled crypto in
the codebase and its failure mode is a silent `400`:

```sh
cd backend && npx convex run webPush:selfTest
```

Both `roundTrip` and `matchesRfc` must be true; it reproduces the published
RFC 8291 §5 vector byte for byte.

Two web caveats worth knowing: Safari only delivers Web Push to a site added to
the Home Screen on iOS 16.4+, and Chrome's `userVisibleOnly` means every push
must display something — which is why the backend never sends the silent
`dismiss` kind to a browser.

## Verifying end to end

1. Log in on a device → check Convex `userDevices` has a row for it with
   `apnsToken` (iOS) or `fcmToken` (Android).
2. Call that device with the app **killed** (swipe away) → full-screen ringing
   UI must appear; accept → app opens into the connected call.
3. Caller cancels while it rings → the ringing UI is dismissed.
4. Repeat with the app backgrounded, then foregrounded (foreground rings
   in-app only).
5. Send a chat message to a backgrounded device → banner arrives; tapping opens
   the right room.
6. Open that room on a second device → the banner clears on the first, and the
   badge drops.
7. **Foreground, inside that room** → no banner (the live subscription already
   has the message). Foreground in a *different* room → banner.
8. iOS with a Focus mode on → a call banner still breaks through. If it doesn't,
   the Time Sensitive capability from §1 is missing.
9. Android 13+ on first launch → the notification prompt appears exactly once.
   Deny it and watch `adb logcat`: there must be no repeating
   `voipTokens:setFcmToken` storm.
10. Android with an alternate launcher icon enabled → tapping a notification
    still opens the app (it resolves the launcher intent, not `.MainActivity`,
    which is disabled while an alias is active).
11. Doze test: `adb shell cmd deviceidle force-idle` then send → must still land.
12. Watch Convex logs: `sendAlert: APNs OK` / `FCM OK` / `WebPush OK`, and zero
    `ALERT_PUSH_MISCONFIG`. In particular **zero**
    `APNS_BAD_TOKEN:400:TopicDisallowed` — that means a topic bug is actively
    eating the token table.
13. `npx convex run push:coverageReport` → how much of the active user base is
    actually reachable. `iosVoipOnly` counts devices still on a build that
    predates direct push.

## Notes

- The app prompts Android users once for **full-screen notifications**
  (Android 14+) and **battery-optimization exemption** after login — both are
  required for reliable ringing on OEM-skinned devices (Xiaomi/Samsung/Oppo).
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` can draw scrutiny in Google Play
  review; calling apps are the canonical accepted use case, but be ready to
  justify it in the review notes.
- Android notification channels are new ids (`mh_messages`, `mh_requests`,
  `mh_call_banner`). A channel's importance is immutable once created, so a user
  who had specifically muted the old vendor's channel will hear these until they
  mute them too. No API can inherit that setting.
- A delivered notification cannot be recalled on any platform, by any API. The
  silent dismiss push is the only mechanism, and it reaches neither a force-quit
  iOS app nor a force-stopped Android one — so a banner can outlive its message
  until next launch.
- The Android release build still signs with the **debug** keystore
  (`android/app/build.gradle.kts` TODO) — set up a real signing config before
  shipping to Play.
