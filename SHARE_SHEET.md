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

### iOS sends without opening the app. Android opens it.

That difference is not an inconsistency, it is the platform convention:

* **iOS** — the extension is a real compose sheet (pick a chat, add a caption,
  Send) and it talks to Convex itself. The user stays in Photos, exactly as they
  do with Messages, WhatsApp and Telegram. Opening the app is an *escape hatch*,
  offered for two cases only: nobody is signed in, or the user wants the photo
  editor (crop, annotation, view-once), which lives in the app.
* **Android** — there is no in-chooser compose convention. The chooser hands the
  intent to an activity and the app opens, which is what WhatsApp and Telegram
  do there too.

On the Android path (and the iOS escape hatch) the payload is staged in
[`ShareIntake`](lib/share/share_intake.dart) and the room's own `RoomScreen`
delivers it — through the same editor, the same size cap and the same optimistic
bubble a photo picked from the composer goes through.

> ### How the extension can send with no app, no engine and no login
>
> The app leaves three strings and the recent-chat list in the App Group
> (`ShareSession`), and the extension does the rest with three `URLSession`
> calls against Convex's HTTP API — the same function paths and argument shapes
> the Dart client uses over its socket (`ConvexHTTP.swift`):
>
> | | |
> |---|---|
> | `deploymentUrl` | which backend. Read live at publish time, so a server switch follows |
> | `userId` | who the message is from — an ordinary argument to `messages:send` |
> | `sessionToken` | the credential. `SessionGuard.identityArg`, spelled the same on both sides |
>
> **The token was not always there, and its absence is the bug this box used to
> predict.** The backend once authenticated nothing, the user id alone was the
> whole credential, and this note said "if the backend ever gains real
> authentication, this stops working". It did: `withToken` in
> `backend/convex/functions.ts` now wraps *every* authenticated function with a
> required `sessionToken`. The Dart client answered that in one place
> (`ConvexBackend._withToken`) and nothing in the app noticed — while the
> extension went on sending the old argument set, and every share died on
>
> ```
> ArgumentValidationError: Object is missing the required field `sessionToken`.
> ```
>
> after composing a perfect sheet. `ConvexHTTP.mutation` now injects it the same
> way, once, and `share_contract_test.dart` reads `SessionGuard.identityArg` out
> of the Dart source and fails if the Swift half spells it differently — the
> check that would have caught it. Note what the old contract test could not
> see: it verified that every argument Swift *sends* exists in Dart, which says
> nothing about an argument the backend *requires* and Swift omits.
>
> The cache is written at the same protection class the keychain holds the
> session under (`first_unlock_this_device` ↔
> `.completeFileProtectionUntilFirstUserAuthentication`), excluded from backups,
> and **deleted on sign-out** — it is a live session token, and otherwise the
> next person to pick up the phone could send as the account that left, from the
> share sheet, without unlocking the app.

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
| `ios/ShareExtension/ShareViewController.swift` | The extension: composes, uploads, sends, and completes |
| `ios/ShareExtension/ShareComposeView.swift` | The sheet the user sees (SwiftUI, deliberately system-native) |
| `ios/ShareExtension/ConvexHTTP.swift` | Just enough Convex to send one message, over `URLSession` |
| `ios/ShareExtension/Staging.swift` | Copies attachments out of their item providers |
| `ios/Shared/ShareGroup.swift`, `ShareSession.swift` | Compiled into **both** binaries: the group id, the inbox layout, the wake-up URL, the cached session |
| `ios/Runner/ShareInbox.swift` | Reads a handed-off payload back |
| `ios/Runner/ShareCache.swift` | Writes the session the extension sends with; clears it on sign-out |
| `AppDelegate.swift` | The channel, and `donateSendMessage` — the suggestions |
| `tool/setup_ios_share_extension.rb` | Creates the extension target. Run from the Podfile's `post_install` |

> ### The copy has to be owned by something
>
> `Staging` is started by the controller and then referenced by nothing except
> the item-provider callbacks it registered. Captured weakly, it is deallocated
> before the first provider answers — every file is discarded and the completion
> never runs, which the user sees as a sheet that spins for the whole staging
> deadline and then offers nothing to send. So the controller holds it *and* its
> own callbacks capture `self` strongly. `share_contract_test.dart` fails if
> either goes away.
>
> The deadline lives inside `Staging` rather than beside it for the same reason:
> a provider that never calls its completion handler is ordinary (a declined
> transcode, an iCloud original that will not download), and only the thing
> holding the results can answer with a partial one.

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
2. Install, **open the app once and sign in**. This is not optional: signing in
   is what writes the session the extension sends with, and suggestions come
   from donations, which a fresh install has none of.
3. Send a message to two or three chats. That is what populates the top row.
4. Take a screenshot → Share → MonkeyHub. **The app must not open.** A compose
   sheet appears with those chats in it; pick one, press Send, and you should be
   back in Photos with the message already delivered.
5. Tap one of the suggested chats in the top row instead — the same sheet opens
   with that chat already selected.

**The way out of the sheet has two routes and needs both.**
`extensionContext.open` is documented for Today and iMessage extensions *only*;
from a share extension it is tolerated rather than supported and answers `false`
on most releases. When it does, `openViaResponder` walks the responder chain to
`UIApplication` and sends it `openURL:` — the route every app that leaves a share
sheet actually takes. On some releases the completion handler never fires at
all, so a watchdog settles the hand-off either way. If both routes fail the
payload is still in the container and the app collects it on its next
foreground; the URL was only ever an optimisation.

If the sheet appears and **nothing happens at all**, the App Group is not
provisioned: `ShareSession.load()` returns nil, the picker is empty, and the
only offer is "Open MonkeyHub". Check the console for
`no App Group container`.

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

> ### The chat list is not filtered on `ChatRoom.isMember`
>
> `repo.rooms` is `rooms:listUserRooms` and nothing else — already, by
> definition, the rooms the viewer is in. `ChatRoom.isMember` is filled in by
> `rooms:listPublic` **alone**, so it is `false` on every room in that list.
>
> `buildShareTargets` used to test it anyway, which rejected all of them: the
> extension cached an empty picker and offered nothing but "Open MonkeyHub" on
> an account with seventeen chats. The same guard stood in
> `share_target_sheet.dart` and `forward_target_sheet.dart`, emptying both of
> those outright. It survived because the test fixtures defaulted `isMember` to
> `true`, which the server never sends — they now default to `false`, like the
> real thing.
>
> A membership question here, if one ever genuinely arises, is
> `ChatRepository.isMemberOf`.

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
