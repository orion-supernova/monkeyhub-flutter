# The system share sheet

Everything that has to agree for **MonkeyHub to appear when somebody shares a
screenshot**, and how to find out which piece is wrong when it doesn't.

Two separate features live here and they fail independently:

| | What the user sees | What makes it work |
|---|---|---|
| **The app in the sheet** | MonkeyHub's icon among the apps | An `ACTION_SEND` activity (Android) / a Share Extension (iOS) |
| **Chats in the top row** | Faces and names, above the app icons | Sharing Shortcuts (Android) / donated `INSendMessageIntent`s (iOS) |

The first one working does not imply the second. **Nothing in this feature fails
loudly** — every misconfiguration below produces a share sheet that is simply
missing something, with no error, no log line, and a green build.

---

## The two doors

```
                  ┌─ tapped a SUGGESTED CHAT ─→ share arrives with a room id
system share sheet┤                             → straight into that chat
                  └─ tapped the APP ICON ─────→ share arrives with no target
                                                → chat picker sheet
```

Both end in the same place: the payload is staged in
[`ShareIntake`](lib/share/share_intake.dart) and the room's own `RoomScreen`
delivers it — through the same editor, the same size cap and the same optimistic
bubble a photo picked from the composer goes through. There is deliberately no
second send pipeline.

One photo gets the editor (crop, annotate, view-once). Anything else goes
straight into the transcript; there is no carousel to preview five photos in.
Text and links land in the **composer**, not in a message: a share is a draft,
and sending it is still the user's tap.

---

## The pieces

### Dart

| Where | What it does |
|---|---|
| `lib/share/shared_payload.dart` | The channel contract, and the only place a platform map becomes a Dart object |
| `lib/share/share_intake.dart` | Receives shares, holds them across login, stages them per room |
| `lib/share/share_targets.dart` | Turns the chat list into the OS's suggestions |
| `lib/widgets/share_target_sheet.dart` | The picker: recent chats, then friends with no chat yet |
| `lib/screens/room_screen.dart` | `_deliverShare` — the room's own send path, reached from a different door |

One channel, `monkeyhub/share`, both directions. Inbound is always **file paths**
— both platforms copy the bytes out of the sender before Dart ever hears about
it, because neither a `content://` grant nor an extension's container survives
long enough to be read later.

### Android

| Where | What it does |
|---|---|
| `ShareTargetActivity.kt` | The `ACTION_SEND` door. Invisible; copies and relaunches |
| `ShareIntake.kt` | Copies the content out of the sender's provider, holds it for Dart |
| `ShareShortcuts.kt` | Publishes the chats as Sharing Shortcuts, draws their icons |
| `res/xml/share_targets.xml` | Declares those shortcuts to be share targets |
| `AndroidManifest.xml` | The intent filters, and `android.app.shortcuts` on **every launcher entry** |

> ### `ShareTargetActivity` exists because of the alternate icons
>
> `MainActivity.applyAlternateIcon` **disables** `.MainActivity` whenever one of
> the seventeen `<activity-alias>` launcher icons is active, and a disabled
> component resolves to nothing. An `ACTION_SEND` filter on `MainActivity` would
> make the app vanish from the share sheet for exactly the users who bothered to
> pick a themed icon.
>
> The same applies to `<meta-data android:name="android.app.shortcuts">`: the
> system reads it from whichever component is the **current** launcher entry, so
> the identical line is repeated on `MainActivity` and on all seventeen aliases.
> `share_handoff_test.dart` fails if a launcher entry is ever added without it.

### iOS

| Where | What it does |
|---|---|
| `ios/ShareExtension/ShareViewController.swift` | The extension. No UI — copies into the App Group and wakes the app |
| `ios/Shared/ShareGroup.swift` | Compiled into **both** binaries. The group id, the inbox layout, the wake-up URL |
| `ios/Runner/ShareInbox.swift` | Reads the container back |
| `AppDelegate.swift` | The channel, and `donateSendMessage` — the suggestions |
| `tool/setup_ios_share_extension.rb` | Creates the extension target. Run from the Podfile's `post_install` |

The extension target is **generated, not committed**. Committing it would be
~2000 lines of `project.pbxproj` that no review can read. The script is
idempotent — a second run over a configured project saves nothing — so
`pod install` keeps it in step for free, and `ruby tool/setup_ios_share_extension.rb`
repairs it by hand.

---

## Prerequisites you cannot skip

These are Apple Developer portal changes. **Do them before the first TestFlight
build**, because two of the three fail silently.

### 1. App Groups on BOTH App IDs

| App ID | Bundle id |
|---|---|
| The app | `com.walhallaa.chatTest-20241220` |
| The extension | `com.walhallaa.chatTest-20241220.ShareExtension` |

Enable **App Groups** on both, with the group `group.com.walhallaa.monkeyhub`
selected on each.

The extension's App ID does not exist yet — create it. Apple requires an
extension's bundle id to be prefixed by its container's; a mismatch is an
"invalid bundle" rejection at upload, not a build error.

**Failure modes, in order of how hard they are to diagnose:**

* Capability missing from an App ID → **signing fails**. The good case.
* Provisioning profile predates the capability → signing fails. Regenerate it.
* The group string differs between `ios/Runner/*.entitlements` and
  `ios/ShareExtension/ShareExtension.entitlements` → **everything builds, everything
  signs**, `containerURL` returns nil at runtime, and the share sheet dismisses
  to nothing. `share_handoff_test.dart` pins the three files against each other
  so this one cannot happen by accident.

### 2. Nothing for Android

Sharing Shortcuts need no console configuration, no permission and no manifest
placeholder beyond what is already committed.

---

## Testing it

### iOS

1. **Delete the app first.** iOS caches an app's extension registrations, and a
   plain reinstall over an older build sometimes keeps the old set.
2. Install, **open the app once and sign in** — suggestions come from donations,
   and a fresh install has donated nothing.
3. Send a message to two or three chats. That is what populates the top row.
4. Take a screenshot → Share. MonkeyHub should be in the app row; the chats you
   just messaged should be above it.

Suggestions can take a minute to appear and are ranked by iOS, not by us. There
is no way to force one, and no API to inspect the ranking. If the app icon shows
but the chats never do, the donation is the piece to suspect — check that all
three of these are present, because any one missing kills it silently:

* `IntentsSupported` in `ios/ShareExtension/Info.plist`
* `NSUserActivityTypes` in `ios/Runner/Info.plist`
* `donateSendMessage` actually running (it logs on failure only)

### Android

```sh
# Is the app registered as a share target at all?
adb shell dumpsys package com.walhallaa.chattest20241220 | grep -A5 SEND

# What shortcuts are published right now?
adb shell cmd shortcut get-shortcuts com.walhallaa.chattest20241220
```

Then: screenshot → Share. Direct Share suggestions appear from Android 10 (API
29) up; below that the app still appears as an ordinary target.

**If the app appears but the chats never do**, the cause is almost always one of
the two silent ones: the shortcut's `setCategories` not matching the
`<category>` in `share_targets.xml`, or a launcher entry with no
`android.app.shortcuts` meta-data (see the box above). Both are pinned by
`share_handoff_test.dart`.

---

## The size cap, three times

`kMaxFileUploadBytes` (20 MB) is enforced in Dart, in `ShareIntake.kt` and in
`ShareGroup.swift`. That duplication is deliberate: the native halves refuse
**before** the copy, so a 500 MB video is never written to the user's disk in
order to be rejected a second later. `share_handoff_test.dart` reads all three
out of source and fails if they drift.

An oversized file is reported rather than dropped — the picker says how many
were left out and why, because silently sending fewer things than were shared is
worse than saying no.

---

## The URL that is not an invite

The iOS extension wakes the app with `monkeyhub://share/open`, reusing the
invite link's already-registered scheme.

`parseInviteLink` **explicitly refuses** it, near the top, before anything else
looks at it. That refusal is load-bearing: the parser's last resort is "treat
whatever is left as a typed code", so an unrecognised URL does not return null —
`monkeyhub://share/open` would become the invite code `SHAREOPEN` and open a
join screen for a room that has never existed, from a URL the app sent itself.
See `kSharePathSegment` in `lib/invites/invite_link.dart`, and DEEP_LINKS.md for
everything else about that scheme.
