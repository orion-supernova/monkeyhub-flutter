# Lessons

Mistakes we made once and do not want to make again. Each entry: what broke,
why, the rule, and where the guard lives. Newest at the bottom; add to it
whenever a bug teaches something general.

---

## L1. A native event must ask for a frame (2026-11-08)

**What broke.** Calls tab, Liquid kit: tapping Tümü / Cevapsız on the native
segmented control moved the thumb at once, but the list kept showing the old
filter for a second or more. The Flutter skin of the same control was instant.

**Why.** The tap reached Dart immediately. `IosSegmentedControl._commit` hands
the value over in `addPostFrameCallback`, which runs after the *next* frame.
The Flutter skin's own `setState` (the sliding thumb) always scheduled that
frame. A native control changes nothing in Flutter's tree, so no frame was
coming, and the commit waited for whatever unrelated redraw happened next.

**Rule.** Any code that reacts to a platform event (method channel, native
control, push tap, deep link) and defers work with `addPostFrameCallback` /
`endOfFrame` must also call `SchedulerBinding.instance.ensureVisualUpdate()`.
A post-frame callback does not schedule a frame by itself.

**Guards.**
- `NativeControl._event` (`lib/ui/native/native_control.dart`) asks for a frame
  after every event, so every native control is covered centrally.
- `_consumePendingInvite` / `_consumePendingPushRoom` (`lib/app.dart`) do too.
- Test: `native_controls_test.dart` › "a native segmented change commits without
  waiting for an unrelated frame" (fails without the fix).

**Smell to grep for.** `addPostFrameCallback` inside a `setMethodCallHandler`
path or an `onEvent` handler.

---

## L2. A sheet's × sits concentric with the sheet corner (2026-11-08)

**What broke.** The × on sheets was 14pt from the side but ~19pt from the top,
so it crowded the 38pt corner's curve.

**Rule.** Inset corner chrome by the same amount on both axes, so a disc sits
concentric with the rounded corner. Fix it in the shared primitive (`SheetBar`
in `lib/widgets/sheet_kit.dart`, now 18pt), never per screen.

---

## L3. Real native glass, not a Flutter imitation (2026-11-08)

**What broke.** The call details action tiles were restyled with Flutter-drawn
"glass" (`ChromeDisc.plate`). On device next to real iOS 26 glass it read as
fake and had no interactive press.

**Rule.** In the Liquid kit, anything that should look like system glass is a
native control: add a `NativeSpec` kind (Dart) and a view (`NativeControls.swift`),
and keep the Flutter widget as its `standIn` twin via
`FlutterSkinsOnly(child: Builder(builder: build))`. When the Flutter layout
must decide the size (equal-height tile rows), lay out the Flutter face
invisibly and put the `NativeControl` in `Positioned.fill` over it
(see `QuickActionTile`).

**Checklist for a new native kind.**
- Map every Cupertino icon you use in `_symbols` (`sfSymbolFor` returns null and
  silently falls back to Flutter otherwise).
- Typecheck Swift at the app's deployment target (15.0, not 26):
  `xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios15.0-simulator -F /opt/homebrew/share/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator ios/Runner/NativeControls.swift`
- Tell the user a Swift change needs a full `flutter run`; hot reload does not
  pick it up.
- If the control emits events, L1 already covers frame scheduling.

---

## L4. Extend the shared primitive, never copy it (2026-11-08)

The action tiles needed the ×'s chrome in a rounded rect. `ChromeDisc` gained a
`.plate` constructor (shape + press scale) instead of a second copy of the
layers. One material, one place to fix.

---

## L5. A sheet is the last stop (2026-11-08)

**What broke.** Stacked calls were moved into a "Call history" list inside the
details sheet (iPhone Recents style). Picking a call there swapped the sheet's
content, which was hard to navigate. Reverted.

**Rule.** Choose between items in the list, before a sheet opens. A sheet shows
one thing. Stacked calls expand in the row into tappable time capsules (×N
pill with a turning chevron, time span), each opening its own details sheet.

**Also tried and rejected:** an inset grouped card with dividers under the row
("boxy"). Light capsules beat boxes for a small set of siblings.

---

## L6. Look at it before calling it done (2026-11-08)

Render a throwaway test to PNG (`RepaintBoundary.toImage`) and look at it.
Notes:
- Tests draw text in Ahem (every glyph a wide block), so wrapping looks worse
  than on a device; judge geometry, not text width.
- Delete the throwaway test (`test/zz_tmp/`) before committing.

---

## L7. Tooling slip: zsh does not word-split (2026-11-08)

`flutter test test/a.dart $files` with `files="b.dart c.dart"` passes ONE
argument in zsh, and the run "fails" while loading. Pass files explicitly or use
`${=files}`. A loading failure is not a test failure; read it before reporting.
