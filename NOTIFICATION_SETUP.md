# Notification & Call-Push Setup

The code ships everything needed for reliable pushes and incoming-call UI on
both platforms in every app state (foreground / background / killed). Four
external setup steps remain — they need dashboard/console access and can't be
done from the repo.

## How delivery works (context)

| Path | Carries | iOS | Android |
|---|---|---|---|
| Direct push (`backend/convex/voipPush.ts`) | Call invite / taken | APNs VoIP (PushKit) → CallKit via `AppDelegate.swift` | FCM data-only → `CallFcmService.kt` → full-screen call UI |
| OneSignal | Chat, approvals, call fallback banner | OneSignal SDK | OneSignal SDK (own FCM transport) |
| Convex realtime subscription | In-app ringing while app is open | ✓ | ✓ |

## 1. Create the Firebase project (Android call pushes)

1. https://console.firebase.google.com → **Add project** (name: anything, e.g.
   `monkeyhub`; Analytics optional — off is fine).
2. In the project: **Add app → Android**, package name exactly:
   `com.walhallaa.chattest20241220`
3. Download **google-services.json** → put it at `android/app/google-services.json`.
   (Gradle wiring is already committed; the build fails with a clear message
   until this file exists.)

## 2. Set the FCM service account in Convex

1. Firebase console → ⚙ **Project settings → Service accounts →
   Generate new private key** → downloads a JSON file.
2. Set it on the production deployment (https://termio-api.walhallaa.com):

   ```sh
   cd backend
   npx convex env set FCM_SERVICE_ACCOUNT_JSON "$(cat /path/to/service-account.json)"
   ```

   Without this, Convex logs `CALL_PUSH_MISCONFIG: FCM cannot send` on every
   call to an Android callee.

## 3. Upload FCM credentials to OneSignal (Android chat/approval pushes)

OneSignal delivers regular Android notifications through its own FCM
connection — it needs the same service account:

1. https://dashboard.onesignal.com → app `c191a9f0-15cf-402a-8a04-dcc16108f4b0`
   → **Settings → Push Platforms → Google Android (FCM)**.
2. Upload the same service-account JSON from step 2.

Until this is done, Android devices receive **no** OneSignal notifications at
all (chat messages, approvals, call fallback banners).

## 4. iOS Notification Service Extension (badges, confirmed delivery, rich media)

1. Xcode → open `ios/Runner.xcworkspace` → **File → New → Target… →
   Notification Service Extension**.
   - Product Name: `OneSignalNotificationServiceExtension` (exactly — the
     Podfile keys off this name)
   - Language: Swift. **Don't** activate the scheme when prompted.
2. Select the new target → **General → Minimum Deployments** → iOS 13.0.
3. **Signing & Capabilities** (for BOTH `Runner` and the new extension):
   add **App Groups** capability with group
   `group.com.walhallaa.chatTest-20241220.onesignal`
   (the suffix `.onesignal` on the app bundle id is OneSignal's convention).
4. Replace the generated `NotificationService.swift` contents with:

   ```swift
   import UserNotifications
   import OneSignalExtension

   class NotificationService: UNNotificationServiceExtension {

       var contentHandler: ((UNNotificationContent) -> Void)?
       var receivedRequest: UNNotificationRequest!
       var bestAttemptContent: UNMutableNotificationContent?

       override func didReceive(
           _ request: UNNotificationRequest,
           withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
       ) {
           self.receivedRequest = request
           self.contentHandler = contentHandler
           self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
           if let bestAttemptContent = bestAttemptContent {
               OneSignalExtension.didReceiveNotificationExtensionRequest(
                   self.receivedRequest,
                   with: bestAttemptContent,
                   withContentHandler: self.contentHandler)
           }
       }

       override func serviceExtensionTimeWillExpire() {
           if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
               OneSignalExtension.serviceExtensionTimeWillExpire(
                   self.receivedRequest,
                   with: bestAttemptContent)
               contentHandler(bestAttemptContent)
           }
       }
   }
   ```

5. `cd ios && pod install` (the Podfile block for the extension activates
   automatically now that the target exists).
6. App Store/TestFlight signing needs a provisioning profile for the new
   bundle id `com.walhallaa.chatTest-20241220.OneSignalNotificationServiceExtension`
   — Xcode's automatic signing handles this if enabled.

## Verifying end to end

1. Log in on an Android device → check Convex `userDevices` now has a row
   with `fcmToken` for it.
2. Call that device with the app **killed** (swipe away) → full-screen
   ringing UI must appear; accept → app opens into the connected call.
3. Caller cancels while it rings → the ringing UI is dismissed.
4. Repeat with the app backgrounded, then foregrounded (foreground rings
   in-app only).
5. Watch Convex logs during a call: `sendVoip: FCM OK` / `sendVoip: APNs OK`,
   and no `CALL_PUSH_MISCONFIG`.
6. Doze test: `adb shell cmd deviceidle force-idle` then call — must still ring.
7. Send a chat message to a backgrounded Android device → OneSignal banner
   arrives; tapping opens the room.

## Notes

- The app prompts Android users once for **full-screen notifications**
  (Android 14+) and **battery-optimization exemption** after login — both are
  required for reliable ringing on OEM-skinned devices (Xiaomi/Samsung/Oppo).
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` can draw scrutiny in Google Play
  review; calling apps are the canonical accepted use case, but be ready to
  justify it in the review notes.
- The Android release build still signs with the **debug** keystore
  (`android/app/build.gradle.kts` TODO) — set up a real signing config before
  shipping to Play.
