# Background Live Location — Store Paperwork & Device Checklist

Live location sharing keeps publishing when the app is off screen, and picks
itself back up after termination as far as each platform genuinely allows. The
code ships complete. What remains below needs an App Store Connect / Play
Console login and a real phone, and cannot be done from the repo.

Read this before submitting a build. Both stores reject background location for
paperwork reasons far more often than for code reasons, and the two rejections
that matter — Apple's "we could not find the feature" and Google's "your demo
video does not show the disclosure" — are both avoidable by following the
sections below literally.

## What actually ships, per tier

The permission tiers are not a quality ladder. Almost everybody will stay on
When-In-Use and will not notice anything missing.

| | When-In-Use | Always / background |
|---|---|---|
| Share updates while the app is on screen | ✓ | ✓ |
| Share keeps updating with the app backgrounded | ✓ | ✓ |
| Share keeps updating with the screen off | ✓ | ✓ |
| Share resumes after force-quit / reboot | ✗ | ✓ (see limits) |
| Share still ends on time | ✓ | ✓ |
| Stoppable from outside the app | ✓ | ✓ |

The row that costs money at review is the fourth one. Everything else needs no
Always on iOS and no `ACCESS_BACKGROUND_LOCATION` on Android, because the
Android foreground service is started **while the app is on screen** and iOS's
`location` background mode works on When-In-Use.

## Battery: what changes, and by how much

Three tiers, switched by app lifecycle. Defined in
`lib/models/location_share.dart` (`LiveLocationMode`) and pinned by
`test/live_location_publisher_test.dart`.

| | app on screen | backgrounded | backgrounded ≥ 20 min |
|---|---|---|---|
| Desired accuracy | ~10 m (GPS) | ~10 m (GPS) | ~100 m (cell/Wi-Fi) |
| Distance filter | 25 m | 100 m | 250 m |
| Min gap between publishes | 10 s | 30 s | 60 s |
| Heartbeat | 90 s | 90 s | 90 s |
| Viewer sees STALE after | 4 m 30 s | 4 m 30 s | 4 m 30 s |

Reasoning, in the order it matters:

- **The distance filter is the only real knob.** It is enforced by the OS, so at
  100 m a walking phone wakes the app roughly a quarter as often as at 25 m. The
  publish interval only discards work the radio has already been woken to do.
- **The heartbeat never changes.** A viewer cannot tell whether the sharer's app
  is on screen, so a staleness threshold that relaxed when they pocketed their
  phone would change the badge's meaning without telling anybody. One mutation
  every 90 s costs 320 writes over the longest share offered.
- **Only the third tier gives up accuracy**, and it publishes the coarse
  `accuracyM` with it, so the bubble draws a 100 m ring instead of pretending to
  precision it stopped paying for. Twenty minutes is chosen so a 15-minute share
  never reaches it and an 8-hour share crosses it once, early.
- Returning to the app restores the 25 m baseline immediately and re-arms the
  20-minute timer from zero.

---

# Apple

## 1. Info.plist strings (already in the repo — verify they survived the merge)

`ios/Runner/Info.plist`:

```
NSLocationWhenInUseUsageDescription
MonkeyHub uses your location only when you choose to share it in a chat. Live shares stop by themselves at the time you pick.

NSLocationAlwaysAndWhenInUseUsageDescription
Allow always so a live location share you started can pick itself back up if your phone restarts or MonkeyHub is closed. MonkeyHub never uses your location outside a share you started, and every share stops by itself at the time you pick.
```

`UIBackgroundModes` must contain `location` alongside the existing
`remote-notification`, `audio`, `voip`. **Without it nothing fails loudly** —
`geolocator` inspects the bundle itself and quietly refuses to set
`allowsBackgroundLocationUpdates`, so every live share simply stops when the app
leaves the screen. If background sharing "doesn't work", check this key first.

There is no `NSLocationAlwaysUsageDescription`. It is iOS 10 and earlier only;
the deployment target is far past that, and including it invites a reviewer to
ask why an app supporting iOS 15+ ships a key for iOS 10.

## 2. App Review justification for the `location` background mode

Paste into **App Review Information → Notes** in App Store Connect. Written to
answer the three questions the location review actually asks: what the feature
is, that the user starts it deliberately, and that it stops by itself.

> **Background location — what it is used for**
>
> MonkeyHub is a private messenger. Its one location feature is live location
> sharing: a user chooses to share where they are with one chat, for 15 minutes,
> 1 hour, or 8 hours, and the share stops by itself at the end of that period.
> There is no fourth "until I turn it off" option, by design.
>
> The `location` background mode exists so the share keeps updating when the user
> puts their phone in a pocket — which is the normal case for the feature, since
> people share their location while walking or travelling somewhere rather than
> while staring at the app. Without it, a share stops the moment the screen
> locks and the recipient sees a position that is minutes old, which defeats the
> purpose.
>
> **This is never silent.** `showsBackgroundLocationIndicator` is enabled for the
> entire duration of every share, so iOS draws the blue status-bar indicator the
> whole time. We also post a notification with a "Stop sharing" action so the
> share can be ended without opening the app.
>
> **Nothing is collected.** The position is written onto the single chat message
> that represents the share, visible only to that conversation's members, and is
> overwritten in place rather than accumulated — there is no location history,
> no analytics SDK, no advertising SDK, and no third-party recipient of any kind.
> The share's expiry is enforced on our server, so it ends on time even if the
> app never runs again.
>
> **"Always" is optional and requested contextually.** The app asks for When In
> Use at the moment a user first shares a location. It asks for Always only when
> a user starts a *live* share, only once ever, and only after a sheet explaining
> that it buys exactly one thing: the share resuming itself if the phone
> restarts. A user who declines gets the complete background-sharing experience
> and is never asked again.
>
> **To reproduce:** open any chat → attachment (+) button → "location" → pick any
> "SHARE LIVE" duration → grant location → background the app. The blue indicator
> appears and the shared card keeps updating for the recipient. Tapping "Stop
> sharing" on the card, or the notification action, ends it immediately.

## 3. Privacy nutrition label

Under **App Privacy → Data Types → Location → Precise Location**:

- Used for: **App Functionality** only. Not "Analytics", not "Product
  Personalization", not "Third-Party Advertising".
- Linked to the user: **Yes** (it is attached to a message they sent).
- Used for tracking: **No.**

## 4. Honest limits on iOS

- `startMonitoringSignificantLocationChanges` is the only iOS API that relaunches
  a terminated app. Granularity is roughly **500 m and several minutes** — it is
  not continuous tracking, and between callbacks the share correctly reads STALE
  to viewers.
- It requires **Always**. On When-In-Use the share stops when the process does.
- `requestAlwaysAuthorization` on a device that already holds When-In-Use very
  often returns the same status immediately and shows nothing. iOS defers the
  real question until the app has used location in the background and then asks
  on its own terms ("Keep Only While Using" / "Change to Always"), possibly
  hours later. The app treats that as "not decided yet", carries on with
  background sharing, and never re-asks.
- A user who force-quits from the app switcher gets no relaunch from the OS
  until the next significant location change. That is Apple's rule, not a bug.

---

# Google Play

## 1. Permissions requested, and the reason for each

| Permission | Why | Which tier |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Take the position the user chose to share. | All |
| `ACCESS_COARSE_LOCATION` | Declared alongside FINE so Android 12+ shows the precise/approximate toggle at all. A coarse fix is a legitimate answer — the card draws the accuracy it was given. | All |
| `FOREGROUND_SERVICE_LOCATION` | Type for `LiveLocationService`, which keeps the share publishing off screen. Started while the app is on screen, so it needs no background-location permission. | All |
| `POST_NOTIFICATIONS` | Already declared for chat. Also carries the ongoing share notification and its STOP action. | All |
| `ACCESS_BACKGROUND_LOCATION` | **Only** so `LiveLocationBootReceiver` can restart an unexpired share after a reboot. Requested separately, after a live share has been started, and only from a user who chose it in an explainer sheet. | Opt-in |
| `RECEIVE_BOOT_COMPLETED` | Trigger for that receiver. | Opt-in |

## 2. Background-location declaration (Play Console → App content → Sensitive app permissions)

**Which feature requires background location?**

> Live location sharing. A user chooses to share where they are with one specific
> chat for a fixed period (15 minutes, 1 hour, or 8 hours). Background location
> is used only to let that share resume by itself if the phone is restarted or
> the app is closed before the period ends.

**Why does the feature need background location rather than foreground?**

> The share itself does not — it runs on a location-typed foreground service
> started while the app is on screen, with a persistent notification. Background
> location is required only by our BOOT_COMPLETED receiver, which restarts that
> foreground service after a reboot for a share that has not yet expired.
> Without it, a user whose phone restarts mid-share silently stops being
> findable by the person they chose to share with.

**Is the feature user-visible and prominently disclosed?**

> Yes. A persistent notification with a "Stop sharing" action is shown for the
> entire duration of every share and cannot be swiped away. Before the
> background permission is requested, the app shows an in-app sheet explaining
> exactly what it adds and offering an equally prominent decline. The permission
> is never requested at launch or during onboarding.

**Is location data transmitted off-device?**

> The position is written onto the single chat message that represents the share
> and is visible only to members of that conversation. It is overwritten in place
> rather than accumulated — no location history is stored. It is not shared with
> any third party, not used for advertising, and there is no analytics or
> attribution SDK in the app.

**Can the user disable the feature?**

> Yes. The share can be ended at any time from the notification's STOP action or
> from the message itself, and every share ends automatically at the time the
> user picked. Declining the background permission leaves all other sharing
> behaviour intact.

## 3. The demo video

Play rejects more submissions over the video than over the code. It must be a
single unedited screen recording of a **real device**, and it must show, in
order:

1. Launching the app cold — proving no location prompt appears at launch.
2. Opening a chat, tapping the attachment (+) button, choosing **location**, and
   picking a **SHARE LIVE** duration.
3. The **in-app disclosure sheet** appearing ("If your phone restarts…"), with
   its explanatory text legible on screen for at least three seconds. This is
   the shot reviewers look for; a video that cuts straight to the system dialog
   is the most common rejection.
4. Tapping the option that asks for background access, then the **system
   permission screen** and the user granting "Allow all the time".
5. The **ongoing notification** in the shade, with its STOP button visible.
6. Backgrounding the app and the share continuing to update (show the recipient's
   screen, or the same account on a second device).
7. Pressing **STOP** on the notification and the share ending.

Keep it under two minutes and do not add music or captions over the disclosure
sheet — the reviewer must be able to read it.

## 4. Honest limits on Android

- `BOOT_COMPLETED` is not delivered until the device is unlocked once after a
  reboot on modern Android, because the share's deadline lives in
  credential-encrypted storage. A phone that reboots in a pocket resumes when it
  is next unlocked.
- **OEM power managers override all of this.** Xiaomi (MIUI), Huawei (EMUI),
  Samsung ("Put unused apps to sleep"), Oppo and Vivo kill foreground services
  and suppress boot broadcasts for apps the user has not exempted by hand. There
  is no API that changes this and the app does not claim otherwise. The app
  already asks for a battery-optimisation exemption post-login for calls
  (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`), which helps but does not guarantee.
- On Android 11+ `ACCESS_BACKGROUND_LOCATION` **cannot** be granted from a
  runtime dialog. The system requires the user to pick "Allow all the time" on
  the app's settings page, so the app opens that page. This is Google's flow,
  not a shortcut.
- A share still ends on time in every one of these cases: the deadline is
  enforced by the server, and a share whose publisher has gone silent reads as
  STALE to viewers rather than showing a stale position as current.

---

# What to test on a real device

Simulators grant everything and never terminate an app, so none of this is
meaningful on one. Both platforms need two accounts (or two devices) so the
recipient's view can be watched.

**Tier 1 — backgrounded, both platforms**

- [ ] Cold launch a fresh install. **No location prompt appears.**
- [ ] Start a 15-minute live share. Confirm the recipient's card updates.
- [ ] Background the app. iOS: the blue status-bar pill appears. Android: the
      ongoing notification appears with a STOP button.
- [ ] Walk ~200 m with the screen off. The recipient's card follows, at coarser
      steps than it did on screen.
- [ ] Return to the app. Updates get finer again within one movement.
- [ ] Leave it backgrounded for 25 minutes, then check the recipient's card shows
      a **wider accuracy ring** — the deep-background tier engaging.
- [ ] Stand still for 5 minutes backgrounded. The card must **not** go STALE (the
      heartbeat keeps running at 90 s in every tier).

**The stop paths**

- [ ] Android: press STOP on the notification. The card goes ENDED on the
      recipient's screen and the notification disappears.
- [ ] iOS: long-press the MonkeyHub notification → "Stop sharing". Same result.
- [ ] Tap the blue iOS pill — it should open MonkeyHub.
- [ ] Stop from the bubble in-app. The notification disappears on both.

**Tier 2 — termination**

- [ ] iOS with Always: start an 8-hour share, force-quit from the app switcher,
      then travel **at least 1 km**. The share resumes (allow several minutes;
      significant-change monitoring is ~500 m granularity). Check the recipient's
      card updates without you opening the app.
- [ ] iOS with When-In-Use: same test. The share should go STALE and stay
      stale — and must still show ENDED at the deadline, from the server.
- [ ] Android with background permission: start a share, reboot the phone,
      **unlock it**, and wait. The notification returns and the card updates
      without opening the app.
- [ ] Android on a Xiaomi/Samsung handset: repeat and expect it may not resume.
      Confirm the share still shows ENDED at its deadline on the recipient's
      screen.

**The deadline is authoritative — the important negative test**

- [ ] Start a 15-minute share, force-quit the app, and leave the phone alone.
      After 15 minutes the recipient's card must read ENDED, not STALE-forever.
- [ ] Relaunch the app after that deadline. It must **not** start publishing
      again, and must not post a notification.
- [ ] Stop a share on device A while device B (same account) is offline. Bring B
      back. It must not resume the share.

**Permission escalation**

- [ ] The Always/background sheet appears exactly once, on the first live share.
- [ ] Decline it, then start three more live shares. It must not appear again,
      and each share must still work backgrounded.
- [ ] Deny location entirely, then try to share. The "open settings" sheet
      appears; no infinite prompt loop.
- [ ] Turn location off device-wide, then try to share. The **location settings**
      sheet appears, not the app-permission one.
- [ ] iOS: after several minutes of background use on When-In-Use, iOS shows its
      own "Keep Only While Using / Change to Always" prompt. Both answers must
      leave the app working, with no in-app follow-up.

**Sign-out**

- [ ] Start a share, sign out. The notification disappears and no resume happens
      on next launch — even though the share is still live server-side for its
      recipients.
