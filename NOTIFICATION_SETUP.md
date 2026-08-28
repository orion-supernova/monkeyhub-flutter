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
| Alert push (`backend/convex/push.ts`) | Chat, approvals, call banners, silent dismiss | APNs on topic `<bundle>` → `NotificationService.swift` (only when it carries a face) → `AppDelegate.swift` | FCM data-only → `CallFcmService.kt` → `ChatNotifications.kt` | Web Push (RFC 8291) → `web/mh-push-sw.js` |
| Ring push (`backend/convex/voipPush.ts`) | Call invite / taken, group invite / taken | APNs VoIP on topic `<bundle>.voip` → CallKit | FCM data-only → full-screen call UI | — |
| Daily games nudge (`backend/convex/dailyNudge.ts`) | The once-a-day "you haven't played today" reminder | APNs on topic `<bundle>` | FCM data-only, channel `mh_games` | — (deliberately) |
| Convex realtime subscription | In-app ringing while the app is open | ✓ | ✓ | ✓ |

Four things are worth internalising:

- **A PushKit `taken` is a backstop, never the first word.** iOS demands that
  every VoIP push reports an incoming call; a `taken` that reaches a phone with
  no card left to end therefore has to report a placeholder and end it, which
  current iOS renders as a one-second incoming "Call" that rings and vanishes.
  So the realtime signal is what dismisses a live app's card, and every native
  `taken` is scheduled `calls.TAKEN_PUSH_GRACE_MS` later (`scheduleTakenPush`)
  so the app can report the card gone (`calls:ackNativeDismissed`, from
  `CallService`) and be skipped. A killed process never acks and still gets
  the push. On `end` the PushKit leg is dropped outright (`iosVoip: false`)
  unless the peer is the callee of a call that was still ringing — the one
  state where a card can sit in a process the signal cannot reach.
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
- **A group call rings on the same wire a 1:1 call does.** It did not used to:
  `groupCalls.start` scheduled a banner and nothing else, so an invitee whose
  app was backgrounded or killed got a line in the notification shade while a
  DM call to the same phone raised CallKit. It now sends `group_invite` over
  PushKit/FCM (`voipPush.sendGroupVoip`) and falls back to the banner, per
  invitee, only for whoever no native transport could reach — a browser, a
  desktop, a phone whose VoIP token the dead-token sweep has cleared. Two
  consequences worth knowing. First, **the card's id is derived, not minted**:
  `derivedCallUuid` / `uuidForCallId` / `derivedUuid` are one function in three
  languages over the groupCallId, because a group card can be taken down by a
  process that never raised it (joined on another phone, declined, call ended)
  and there is no state to hand across. Second, **iOS has nothing that ends an
  unanswered card**, so `_expireRingers` is scheduled at
  `INVITE_RING_WINDOW_MS` — the same instant `pendingInviteForUser` stops
  offering the invite, so a live app and a killed one give up together.
  `groupCallId` in the card's `extra` is what makes an accept call
  `groupCalls:join` instead of `calls:accept`; `push_payload_contract_test.dart`
  pins it, and a 1:1 invite omits the key rather than sending it empty.
- **The sender's face is a per-recipient key, not a per-message one.** It rides
  the `perUser` override map because `visibility.avatar` is answered from each
  *recipient's* side, and `buildApnsBody` gates `mutable-content` on that same
  key — so the privacy check and the "don't wake a second process for nothing"
  check turn out to be one line of code. Put `senderAvatarUrl` in the shared
  `data` block instead and you have handed a face to everyone in the room whose
  owner set it to "friends". `push_payload_contract_test.dart` fails if you do.

## macOS: the badge, the menu bar, and ⌘W

macOS still has no banner in this app — the point below about desktop holding a
credential-less `userDevices` row is unchanged. What it does have is a Dock
badge and a menu-bar item, and both are fed by the same in-process count as
every other platform (`BadgeManager` → `monkeyhub/badge` → `AppChrome`,
macos/Runner/AppChrome.swift). One object owns both surfaces so they cannot show
different numbers.

**Why the Dock badge used to stay empty.** Not the badge path — that worked. The
count feeding it was always zero, because the open room's read cursor advanced
whether or not anyone was there. Everywhere else "the room is open" is a safe
stand-in for "you are reading it": a backgrounded mobile app is suspended within
seconds, its subscriptions stop firing, and nothing arrives to be marked read.
macOS deliberately breaks that assumption — the red X and ⌘W hide the window and
keep the process alive, because the process IS the delivery path — so messages
kept landing in the open room and kept being marked read on behalf of somebody
who had put the window away hours earlier. `unreadCount` never left zero, so
there was nothing to badge, and the sender was shown SEEN for a message that had
never been on a screen. A background browser tab had the same hole.

`ChatRepository._markReadOrDefer` now holds the cursor back whenever
`viewerIsPresent` is false, and `flushDeferredRead` takes it on the next
`resumed`. The messages are on screen in the open room, so coming back to the
app IS reading them. Leaving the room while away discards the held read instead
— walking out of a chat you never looked at is the clearest possible statement
that you did not read it.

`viewerIsPresent` (lib/push/viewer_presence.dart) is deliberately the *same*
predicate `MessageAlerts` uses to decide whether to ping. A build where a
message is silent but still marked read is a message that vanishes without ever
having been seen.

**⌘W.** The Flutter macOS template ships a MainMenu.xib with no Close item at
all, so the shortcut did nothing — there was no menu item for AppKit to match it
against. The Window menu now carries Close (⌘W) and Show Window (⌘0). ⌘W routes
to `MainFlutterWindow.performClose`, which hides rather than closes, for the
delivery reason above; ⌘0 exists because AppKit drops an ordered-out window from
the Window menu entirely, so once hidden there was nothing in the menu bar that
could bring it back.

**The menu-bar item.** Left-click toggles the window, right-click opens a menu
(open/hide, the unread summary, quit). It can be removed by ⌘-dragging it off
the bar or from Settings ▸ NOTIFICATIONS ▸ MENU BAR ICON; the preference lives
in native `UserDefaults`, because it is read at
`applicationDidFinishLaunching` — long before the engine boots — and an icon
that pops into the bar a second after every launch reads as a glitch. Dart
reaches it over `monkeyhub/desktop`. The glyph is drawn as a path rather than
shipped as an asset: menu-bar images are flattened to a single tint, which the
full-colour app icon cannot survive.

Its menu titles are English-only, like the rest of the native menu bar (About,
Quit, Edit are already untranslated) — the app's ARB strings do not reach an
NSMenu.

## The daily games nudge

The only push here that no user action produced, which is why it is the only one
with rules of its own. Nothing needs configuring — it rides the APNs key and FCM
service account that are already set up — but four things are worth knowing
before changing it.

**It is sent at local noon, from one quarter-hourly cron.** `dailyNudge.run`
runs on `0,15,30,45 * * * *` and asks whose wall clock reads 12:00 right now,
answered by an equality probe on `userDevices.by_tz_offset`. Istanbul is nudged
at Istanbul's lunchtime and California at California's. Quarter-hourly and not
hourly because India (+5:30), Nepal (+5:45) and Chatham (+12:45) have noons an
hourly tick would never land on. Most of the 96 daily ticks match no populated
zone and cost one index probe returning nothing.

A **cron string, not `crons.interval`** — the distinction is load-bearing and
was a real bug. An interval is measured from the end of the previous run, so the
ticks slide later by however long each took; since a tick is snapped to the
nearest quarter hour to decide which zone it serves, a drifting schedule skips a
quarter outright and the zone that quarter addresses hears nothing that day.
`test/daily_nudge_schedule_test.dart` fails if it is changed back.

**A missed tick is not a lost day.** Each tick also re-serves the zones whose
noon fell in the previous hour (`dueOffsetsAt`, `CATCH_UP_TICKS`), and each
bucket runs inside its own try/catch. Free, because a zone already served today
costs one document read per person to establish that and sends nothing.

**The offset comes from the device and is refreshed aggressively.**
`userDevices.tzOffsetMinutes` and `.locale` are written by
`voipTokens:setDeviceContext`, which the client calls on login, on every resume,
when the local day rolls over, and whenever the resolved app language changes —
see `PushManager.syncDeviceContext`. It compares against what it last uploaded,
so the common case costs no round trip. Travel is picked up on the resume as the
phone comes off airplane mode. Every token upload (`setApnsToken`,
`setFcmToken`, `setVoipToken`) stamps the same two values as a floor, so a row
that holds a push credential always has a zone even if the context call never
landed. **Known gap:** daylight saving moves at ~03:00 local, so a phone nobody
opens between the change and noon is nudged an hour off for that one day.
Closing it properly means storing an IANA zone name, which Dart cannot report
without a plugin.

**A device that has never reported a zone is still reached.** `by_tz_offset`
cannot return a row that is missing the field, so under a strictly-zoned
audience those devices were invisible forever while holding live tokens — the
day the nudge shipped that was five of the eleven push-capable phones on the
deployment, every one of them on an app build older than the feature. They are
now a bucket of their own: served with their account's zoned phones when it has
any, and otherwise at noon in a deployment-wide fallback offset.

```sh
# The offset most of your zone-less users actually live in. Default 0 (UTC).
npx convex env set NUDGE_FALLBACK_TZ_OFFSET 180   # Istanbul
```

A device leaves that bucket for its own zone the first time its app tells us
where it is, which is the first login or resume on a build new enough to.

**Nobody is nudged twice, and nobody who already played is nudged at all.**
`dailyNudge.claimNudges` reads the day's five results (the code puzzle and four
boards) and stamps `users.lastNudgedDayKey` in the same mutation. A finished set
is skipped; a retry, an overlapping deploy, a catch-up tick, or a person with
devices in two time zones finds the day already claimed. The same check picks
between the two lines of copy, both of which are true of whoever reads them.

The claim is per ACCOUNT while the audience index is per DEVICE, so the fan-out
runs the other way afterwards: the winner of a claim is re-read through `by_user`
(`devicesForUsers`) and every phone it owns in that bucket is sent to. Reading
devices straight off the audience page instead — which is what this did first —
silently dropped every phone that landed on a later page of a busy zone, because
the day was already claimed by the time that page was reached.

**Web is excluded on purpose; desktop cannot be reached.** A browser only
receives a push while its service worker is alive, so the web audience is
whoever left a tab open. macOS/Windows/Linux have no notification surface in this
app at all — they hold a `userDevices` row with no credential and fail the
audience test on their own, though they do report language and time zone, so
they would join with no backend change the day a local notifier exists.
`push_payload_contract_test.dart` pins both facts.

**The copy is not the same two sentences every day.** It was, and that is the
second way to teach somebody to swipe a daily notification away unread — the
first being sending it to people who already played. `claimNudges` now returns
the day's shape rather than a sentence: how many of the five are left, whether
something was opened and walked away from, whether the day is untouched.
`friendsAhead` adds how many friends already played today. `composeNudge` pools
every line that is true of the reader and rotates by calendar day, so
consecutive days cannot repeat, everyone in a language reads the same line on
the same day, and the exact title+body pair comes back roughly every 12 days in
the commonest state and every 30 in the richest.

The lines never name a game, on purpose. The backend knows exactly which board
was left half-played; saying so turns a nudge into a status report, and costs
four game names in twelve languages for a detail nobody wants at lunchtime.

The social line obeys `visibility.puzzle`, exactly as `games.standings` does,
and needs two friends before it fires — at one, "a friend played today" is a
statement about one identifiable person. It is capped three ways
(`SOCIAL_FRIEND_CAP`, `SOCIAL_USERS_PER_QUERY`, `SOCIAL_MAX`) so it cannot grow
into the query that takes the box down, runs only over accounts that already won
a claim, and fails soft: losing it costs the sentence, never the notification.

Copy lives in `NUDGE_COPY` in `dailyNudge.ts`, one row per shipped language,
mirroring `lib/l10n/app_*.arb`. `test/daily_nudge_copy_test.dart` fails if a
thirteenth language ships without one — nothing else would notice — and fails
too if a language is given fewer lines than English, repeats a line inside one
list, or puts `{count}` in a list that passes no number.

Off switches: the per-device `userDevices.gameRemindersEnabled` (Settings ▸
Notifications ▸ DAILY GAME REMINDER), the Android `mh_games` channel, and
`pushEnabled`, which silences everything. The first two exist because the only
way to stop a daily broadcast should not cost you your messages.

Ops: `npx convex run dailyNudge:audienceReport` — devices per time zone and per
language, plus how many are reachable at all. `fallback` is the count still on a
build that has never uploaded an offset; it should fall towards zero over a
release. (The first version of this report keyed its counts by locale into an
object and used `"—"` for "none", which Convex rejects as a field name — so the
one command for finding out whether anybody was being missed threw on every
deployment that had a single device with no locale. Counts are arrays now.)

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

## 1b. Apple: Communication Notifications

What puts the **sender's face where the app icon normally sits** on a chat
banner, rather than a thumbnail beside it. The work happens in
`ios/NotificationService/NotificationService.swift`, a Notification Service
Extension iOS wakes for any push carrying `mutable-content: 1`.

Two things are needed, and **both fail the build loudly** — this is a
§1-shaped capability, not an associated-domains-shaped one:

1. **An App ID for the extension**, `com.walhallaa.chatTest-20241220.NotificationService`,
   exactly as the Share Extension has one. Without it:

       No profiles for 'com.walhallaa.chatTest-20241220.NotificationService'
       were found.

2. **"Communication Notifications" enabled on the app's App ID**
   `com.walhallaa.chatTest-20241220`, then regenerated profiles. Without it:

       Provisioning profile "..." doesn't include the
       com.apple.developer.usernotifications.communication entitlement.

The capability is **self-service** — the portal marks it editable, so there is
no request form and Xcode's Signing & Capabilities pane can add it directly.

**Enable it on the extension's App ID too**, not only the app's. Xcode's portal
database claims this capability is unavailable on an ordinary app extension
(it lists `application` and `watchkit2-extension` and nothing else) — the
database is simply wrong. The portal offers the checkbox, and both binaries
ship signed with the entitlement:

```sh
codesign -d --entitlements - --xml build/ios/iphoneos/Runner.app/PlugIns/NotificationService.appex
# → com.apple.developer.usernotifications.communication = true
```

It is wrong about App Groups on the Share Extension in the same way. Do not read
that list as evidence a capability cannot be had.

The runtime fallback stays regardless. If `content.updating(from:)` is ever
refused on a device, `NotificationService.swift` catches it, delivers the plain
banner, and logs `[push] communication notification refused: …` — so the failure
costs the face and never the message.

Nothing else needs configuring — no new key, no new env var. The extension takes
no pods and is created by `tool/setup_ios_notification_extension.rb` from the
Podfile's `post_install`, the same way the Share Extension is.

**Two limits worth knowing before someone files them as bugs:**

- **The CallKit ringer keeps the generic silhouette, 1:1 and group alike.** A
  PushKit payload never passes through a Notification Service Extension, and
  CallKit draws a photo only for a handle that matches a real entry in the
  system Contacts app. There is no API to hand it an arbitrary image. Android's
  full-screen ringer *does* take an avatar (`CallFcmService.kt` passes `avatar`
  to flutter_callkit_incoming, for both kinds), so the two platforms genuinely
  differ here. What iOS does get is the `call_invite` and `group_call_invite`
  **banners**, which `voipPush.ts` sends only when the ring failed on every
  device.
- **A mention's title is drawn from the intent, not from `aps.alert.title`.** So
  "X mentioned you" would be overwritten by the bare sender name. `sendMessagePush`
  puts the mention in the *subtitle* instead, which `updating(from:)` leaves
  alone; delete that and iOS silently stops distinguishing a mention from any
  other message. **The subtitle itself survives `updating(from:)` intact** —
  measured, not assumed: a harness built the same intent this extension builds
  and read the result back as `title=<sender> subtitle=<room> body=<message>`.
  That is why the room name on a group CHAT banner needed no fixing, and why
  the group CALL banner did: its room name was in the *title*, which the intent
  does overwrite. `displayName(in:)` names the person after the room for that
  one kind.

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

**`webPush.ts` is the one backend file that says `"use node"`.** Convex's
default V8 isolate implements only part of WebCrypto, and the missing piece is
exactly what RFC 8291 is built on — `crypto.subtle.deriveBits` for ECDH throws
`Not implemented` there. APNs and FCM stay in V8 because they only ever *sign*;
Web Push has to agree a shared secret with the browser, and there is no way to
do that without ECDH. `push.ts` therefore reaches it over `ctx.runAction`
rather than importing it, since a V8 module that imported it would pull the
Node runtime into its own bundle. The cost is a slower cold start on the web
path only.

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
   the right room. From a sender **with an avatar** on iOS, the banner shows
   that face in place of the app icon; from one without, the app icon — and the
   Convex log for that push carries no `mutable-content`. Set the sender's
   avatar visibility to "nobody" and it must go back to the app icon, which is
   the per-recipient gate holding on iOS the way it already does on Android.
   Point the avatar at a dead URL and the banner must still arrive *promptly*,
   faceless: a picture that will not load may never hold up a message.
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
14. iOS communication notifications: after step 5, confirm a **group** message
    shows the sender's name over the room's name, an `@`-mention still says
    "mentioned you", and both survive a force-quit (swipe away, then send) —
    an extension runs for a killed app. Then re-check the paths the extension
    now sits in front of: tap-to-open-room, banner clearing when the room is
    read elsewhere, two messages in one room still threading together, and no
    banner while that room is on screen.
15. Daily nudge: set the device clock to a zone whose noon is minutes away,
    reopen the app (that is what uploads the offset), and confirm
    `npx convex run dailyNudge:audienceReport` counts it under the right zone
    and reports `fallback: 0` for it.
    At noon the banner must arrive in the app's language, and tapping it must
    land on the Feed with the games shelf open — not merely raise the app.
    Play everything, and the next day's nudge must not arrive at all.
16. **Group call ringing**, which is the same script as step 2 with a group
    call instead of a DM one, plus the four ways the ring has to stop. Start a
    group call in a room whose other members are on **killed** apps: each must
    get the full-screen ringing UI, titled with the ROOM, not a notification in
    the shade. Then, one per run: answer on one of two phones the same account
    owns → the other's card goes; decline → the sibling's card goes and the
    declining phone does NOT flash a second one-second "Call"; have the starter
    hang up while it rings → the card goes; and leave one ringing untouched for
    a minute → it stops on its own rather than ringing until it is picked up.
    Answering must land in the group call screen, not the DM one — and a DM
    call ringing on the same phone at the same time must be unaffected by any
    of it.
17. **Avatar orientation.** Set an avatar from a photo taken in PORTRAIT on a
    phone camera (one that has never been through the crop screen's re-encode
    — an older account's picture is the easiest source) and send a message from
    it. The face on the banner must be the way up it was taken, on both
    platforms. The failure is a quarter turn, and the tell is that the same
    picture looks correct everywhere inside the app.

## Notes

- The app prompts Android users once for **full-screen notifications**
  (Android 14+) and **battery-optimization exemption** after login — both are
  required for reliable ringing on OEM-skinned devices (Xiaomi/Samsung/Oppo).
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` can draw scrutiny in Google Play
  review; calling apps are the canonical accepted use case, but be ready to
  justify it in the review notes.
- Android notification channels are new ids (`mh_messages`, `mh_requests`,
  `mh_call_banner`, `mh_games`). A channel's importance is immutable once created, so a user
  who had specifically muted the old vendor's channel will hear these until they
  mute them too. No API can inherit that setting.
- A delivered notification cannot be recalled on any platform, by any API. The
  silent dismiss push is the only mechanism, and it reaches neither a force-quit
  iOS app nor a force-stopped Android one — so a banner can outlive its message
  until next launch.
- The Android release build still signs with the **debug** keystore
  (`android/app/build.gradle.kts` TODO) — set up a real signing config before
  shipping to Play.
