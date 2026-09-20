# Dragging files into MonkeyHub

Everything that has to agree for **a file dragged out of Finder (or a browser,
or Mail, or Photos) to land in a chat**, what the app can tell the user *before*
they let go, and which half of it is a platform limit rather than a bug.

**macOS and web only.** iOS and Android have no desktop drag to receive;
`DropController.isSupported` is false there, nothing registers, and every drop
affordance is absent rather than inert. The system share sheet is the mobile
door and it is a [different feature](SHARE_SHEET.md) with a different contract.

---

## The shape of it

```
                    ┌──────────────── macOS ─────────────────┐
                    │ MainFlutterWindow : NSDraggingDestination
                    │   └── DropDestination.swift            │
                    │         reads the pasteboard on HOVER  │
                    │         stages the files on DROP       │
   the OS ──────────┤                                        ├──→ DropController
                    │ ┌───────────────── web ──────────────┐ │      │
                    │ │ document dragenter/over/leave/drop │ │      │
                    │ │   drop_channel_web.dart            │ │      │
                    │ │     types on HOVER, files on DROP  │ │      │
                    └─┴────────────────────────────────────┴─┘      │
                                                                    ▼
             DropZoneRegistry ◀── rectangles ── DropZone ×N    DropChrome
             "what is under the pointer"        (transcript,   (cards, chip,
                                                 chat rows)     aura, burst)
                                                       │
                                                       ▼
                                          RoomScreen._deliverDrop
                                          → the same send path a
                                            picked photo takes
```

Two things are worth saying plainly because everything else follows from them.

### 1. There are no pointer events

An OS drag produces no Flutter pointers. `Listener`, `MouseRegion` and the whole
hit-test tree see nothing at all — the platform reports a position in window
coordinates and that is the entire input. So the app keeps its own list of
rectangles ([`DropZoneRegistry`](lib/drop/drop_zone_registry.dart)) and answers
"what is under here" itself.

The consequence that bites: **a rectangle does not stop existing when it is
covered.** A chat row laid out past the end of its viewport, or a whole screen
underneath a pushed route, still measures exactly where it would paint. Two
guards handle that and both are load-bearing:

* `DropZoneHandle.rect` intersects with the nearest `RenderAbstractViewport`, so
  a scrolled-away row cannot claim the pointer over the header.
* `DropZone` watches `ModalRoute.secondaryAnimation` and switches itself off
  while something is pushed over it. Without it, a file dropped on an open photo
  editor goes to the transcript behind it.

### 2. The two platforms know different things at different times

|                       | during the drag | at the drop |
|-----------------------|-----------------|-------------|
| **macOS** — pasteboard | name, byte count, sniffed UTI | the same, plus the bytes |
| **web** — `DataTransfer` | MIME type and a count, nothing else | everything |

A browser withholds names and `getAsFile()` until the `drop` event on purpose:
a page could otherwise read a directory listing off a hover. That is why
`DropSnapshot.namesKnown` exists and why the UI branches on it — on a Mac the
hover card says `Q3-deck.key · 4.2 MB`, in Chrome it says `photo`, and neither
of them is lying.

It is also why there are **two** places that speak: the verdict chip before the
drop, and a toast after it. On macOS the toast is almost always silent, because
everything it could say was already on the chip. On web it is the first chance
to say "that one went as a file".

---

## What the user sees

| | |
|---|---|
| **aura** | a wash in from the window's edges. The one signal that says "this window is receiving something" when the pointer is over a part of the app with no zone in it. Edges rather than a scrim, so the target zone stays the brightest thing on screen. |
| **cards** | one per dragged item, up to four, fanned and trailing the pointer on a spring. Each card follows the one above it slightly more slowly, which is what makes the stack swing out on a turn. |
| **zone glow** | painted *inside* the target: a wash, a spotlight under the cursor, a marching dashed ring and corner brackets that close in. |
| **verdict chip** | what letting go would do, and the one caveat worth saying. |
| **burst** | a ring at the point of release, handing off to the optimistic bubble already appearing in the transcript. |

Under Reduce Motion (`MotionScope.calm`) the trail, the fan, the march and the
burst all go. The ring, the cards and the chip stay: they are the *answer*, and
the answer is not decoration.

---

## What happens to what

`lib/drop/drop_classifier.dart` holds four tables, and the split into four is
the whole point — "supported" is not a boolean here.

| tier | example | becomes | says |
|---|---|---|---|
| renderable | `.png` `.jpg` `.mp4` `.mp3` | picture / video / audio | nothing |
| **fragile** | `.heic` `.flac` | picture / audio | "may not preview everywhere" |
| **fallback** | `.mkv` `.psd` `.wma` | **document** | "will be sent as a file" |
| ordinary | `.pdf` `.zip` `.key` | document | nothing |

`.heic` is the case the middle tier exists for: a Mac hands it over whenever a
photo is dragged out of Photos, Apple platforms and Android draw it, no browser
does. Downgrading it to a document would be the wrong trade for the common case
(Mac → phone), so it goes as a picture *and says so*.

Refusals, all of them named rather than silent: a folder, a file over
`kMaxFileUploadBytes`, a zero-byte file, a room whose guardian policy forbids
attachments, and the tail of a drag that does not fit in one send.

### The batch budget

A drag is the only door in this app that can deliver a hundred files in one
gesture — selecting a folder's worth in Finder and pulling it over is not an
edge case, it is what drag-and-drop is *for*. `kMaxDropItems` (20) and
`kMaxDropBatchBytes` (40 MB) bound it, in drag order, from the end.

Without them a big drop walks into
`ChatRepository._maxRetainedUploadBytes` (48 MB), whose overflow path is the
dead end `lib/media/file_meta.dart` describes: a failed bubble with no bytes
left to retry. Refusing here instead names the files while the pointer is still
holding them. `drop_cap_test.dart` pins the relationship.

---

## Where you can drop

| target | priority | what it does |
|---|---|---|
| the open conversation | 0 | sends here |
| a row in the chat list | 20 | selects that room and sends there |

Ties between zones at the same priority go to the **smaller rectangle**, which
is what makes nesting work without every caller hand-picking a number.

A drop on a chat row has further to travel than one into an open conversation —
the row selects a room, the shell swaps a pane, and only then is there a
`RoomScreen`. [`DropIntake`](lib/drop/drop_intake.dart) parks the bundle for
that hop, exactly as `ShareIntake` does for the share sheet.

> **The row's `onDrop` returns the intake's future, not its own.** This is the
> one piece of wiring that deletes user data if it is got wrong.
> `DropController` releases macOS's staged copies when `onDrop` completes, and
> the row's own work is over the instant the room is selected — seconds before
> the bytes have been read. `drop_intake_test.dart` pins both directions:
> complete too early and the file is deleted mid-send, complete never and every
> drop leaks a copy into the temp directory.

---

## Why macOS copies the file

`performDragOperation` hands over `file://` URLs the app may read *for the
duration of the drag*, under
`com.apple.security.files.user-selected.read-only`. That grant is not something
to still be leaning on ninety seconds later while the photo editor is open and
the user is deciding whether to crop.

So the native side copies each dropped file into
`NSTemporaryDirectory()/monkeyhub-drop/<uuid>/` *before* Dart hears about the
drop, and `release` deletes the copy once it has been consumed. Same contract
`ShareIntake` already runs for the share sheet, including the treatment of
oversize files: nothing is copied for those, because twenty megabytes of disk
churn to produce a refusal is work with no outcome.

The UUID is the **folder**, not the file — the original name rides on the
message, because `ChatMessage.fileName` is what the recipient sees.

---

## Things that fail quietly

Every item here produces a green build and a drag that simply does nothing.

* **`DropDestination.swift` missing from the Xcode target.** It compiles for
  nobody, the window never registers, and drag-and-drop is absent on macOS with
  no error anywhere. Pinned by `drop_cap_test.dart`.
* **`MainFlutterWindow` not declaring `NSDraggingDestination`.** `NSWindow`
  picks the protocol up from Objective-C, so Swift sees no methods to
  `override` — and without the explicit conformance AppKit's
  `respondsToSelector:` check finds nothing.
* **The channel name.** A typo on either side of `monkeyhub/drop` is a drag
  that produces nothing at all. Pinned.
* **The cap drifting apart.** `kMaxDropBytes` in Swift mirrors
  `kMaxFileUploadBytes` in Dart. Drift up and oversize files get copied anyway;
  drift down and files Dart would accept arrive with no bytes behind them.
  Pinned.
* **`preventDefault` missing on web.** A file dropped on a page that did not
  cancel it is a *navigation*: the browser leaves the app and opens the file.
  There is no undo — the tab is gone, the socket with it. Every `dragover` and
  every `drop` anywhere in the document is cancelled, including ones that land
  nowhere.
* **`dart.library.html` instead of `dart.library.js_interop`.** The web deploy
  is `--wasm`, and dart2wasm ships no `dart:html` — a conditional export
  written the old way silently resolves to the stub. (Seven indirections in
  this repo still have that bug; this one does not.)

---

## Testing it

There is no way to synthesise an OS drag under `flutter test`, so the platform
half is exercised by source scans and the rest through `DropController`'s own
seams.

| file | what it pins |
|---|---|
| `drop_classifier_test.dart` | the format tables, the refusals, the batch budget |
| `drop_copy_test.dart` | the sentence, and the silence on a clean drop |
| `drop_zone_test.dart` | measuring, viewport clipping, priority, route coverage |
| `drop_controller_test.dart` | a whole drag: targeting, re-planning, release |
| `drop_intake_test.dart` | the chat-row handoff in both directions |
| `drop_chrome_test.dart` | the overlay says the right thing, and is absent otherwise |
| `drop_cap_test.dart` | the Swift/Dart cap, the channel name, the Xcode target |

By hand, on a Mac: drag a `.heic` and a `.mkv` in together and check the chip
says one thing before the drop and the toast says the other after it. In a
browser: drag a folder in and check the app does not navigate away.
