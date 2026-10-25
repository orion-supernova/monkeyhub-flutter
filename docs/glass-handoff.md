# Signal glass refresh: handoff (2026-10-25)

Read this first if you are a new session continuing the Signal-style design
work. Companion doc: `docs/GLASS_SPEC.md` (section 1 = binding decisions,
section 2 = measured visual and motion target). Reference frames from the
user's Signal iOS 26 screen recording: `docs/glass_reference/`
(`hires.png` = 5 key frames, `sheet_01..04.png` = the whole 29s at 2fps).

## 1. What the user asked

"Watch this Signal recording. Make our Flutter app get really close to this
design language: sheets, glass, animations. Act as orchestrator and work with
Sonnet teams." The recording is Signal's Linked Devices flow on iOS 26 (Liquid
Glass): chat list, settings, linked devices page, "confirm it's you" sheet,
Face ID HUD, scan QR sheet over the camera, Finish Linking sheet, syncing
progress dialog, "Message sync complete" toast.

## 2. State

All work is in one commit on `dev`: `46e0b581 feat(glass): refresh UI with
Signal-inspired glass design` (committed and pushed by the user).

| Package | What landed | Main files |
|---|---|---|
| WP1 sheets | Every compact `showAdaptiveSheet` (80 call sites) floats: inset 8 from sides, lifted `max(8, safeBottom - 26)`, all corners `sheetRadius(theme) = (radiusXl * 1.9).clamp(8, 38)`. Custom `_FloatingSheetRoute`. Spring present (k300 c30), 1:1 drag, rubber-band x0.25, dismiss at 40% or 700 px/s, exit keeps fling velocity. Grabber 36x5, ink 0.30, 8 from top. `showIosActionSheet` = stacked 50pt capsules. `showIosAlert` = 1.12 to 1 scale-in. | `adaptive_sheet.dart`, `sheet_drag.dart`, `sheet_kit.dart`, `sheet_surface.dart` |
| WP2 controls | Press "bloom": glass controls grow to 1.06 and spring back (k400 c18, small overshoot); big capsules and rows still dip 0.97 but release on the spring. Phone glass circle 44 (glyph 20), pill 44, button group 44x44, `kActionButtonHeight` 50. Tab lens springier (0.28/0.72), stretch up to 0.15. Segmented control thumb on a spring. Tab icon default 24. | `spring_press.dart`, `liquid_glass.dart` (`pressScale`), `glass_buttons.dart`, `action_buttons.dart`, `density.dart`, `pill_bottom_nav.dart`, `segmented_control.dart`, `glass_config.dart` |
| WP3 overlays (new) | `showGlassProgress` + `GlassProgressHandle` + `ProgressRing`; `showGlassHud(success:)` + `GlassHudCheck`; `ScanFrameOverlay(active:, detected:)`. Shared `GlassOverlayRoute` in `glass_hud.dart`. | `glass_progress_dialog.dart`, `glass_hud.dart`, `scan_frame_overlay.dart` |
| WP4 chats | Header floats over the list: avatar left, centred "Chats" 17/600, `GlassButtonGroup` search + compose right, soft gradient top edge. Large left title removed. Rows: avatar 52, title 16/600, preview 14, stamp 13, ~72 tall, no dividers, `SpringPress` 0.98, new solid `ChatUnreadBadge`. `pageTransitionsTheme`: Cupertino slide on iOS/macOS/Android, crossfade under calm. | `home_screen.dart`, `chat_list_row.dart`, `chat_list_parts.dart`, `theme/glass_page_transitions.dart`, `app.dart` |
| WP5 linked devices | DevicesScreen: hero card with drawn illustration + "Link a new device" capsule, device rows with a ⋮ glass button opening the action sheet, remove-all kept. Scan screen: full-bleed camera, `ScanFrameOverlay`, glass back + centred title, bottom card that morphs into the 6-digit code field. Detected code opens a "Finish linking" floating sheet (approve/deny), success = check HUD, pop, "Device linked" toast. New-device panel: QR on a white card with app mark, `ProgressRing` while waiting. 16 new l10n keys. | `devices_screen.dart`, `device_login_scan_screen.dart`, `device_login_panel.dart`, `linked_devices_illustration.dart`, `lib/l10n/*` |
| WP6 sweep | Call sites aligned to the new 44pt size (call buttons, composer discs, search field 44, photo chrome, spacers); room header title capsule `pressScale: 0.98`; three sheets with their own panel moved to all-round `sheetRadius`. | `call_button.dart`, `group_call_button.dart`, `chat_composer.dart`, `search_field.dart`, `photo_chrome.dart`, `room_screen.dart`, others |
| WP7 settings | `IosPage` (19+ settings pages): large title replaced by a floating 52pt bar with centred 17/600 title, glass back circle, content scrolls under a gradient edge; `IosPage.barHeight` / `barClearance(context)` and a pinned clearance sliver so pages that pin their own headers sit below the bar. Grouped headers 15/600, dark `groupedFill` lifted toward #2C2C2E-on-black contrast. | `ios_kit.dart`, `settings_screen.dart` |
| Regression fixes | (1) storage tabs slid under the new bar: `_TabsFloor` uses `IosPage.barClearance`. (2) `SheetDragHost`'s drag `GestureDetector` swallowed screen-reader labels in every sheet: now `excludeFromSemantics: true`. (3) how-to-play page dots overflowed 4.5px: `FittedBox(scaleDown)`. | `storage_usage_screen.dart`, `sheet_drag.dart`, `how_to_play.dart` |

Verification at the time of the commit:
- `flutter analyze`: 32 issues, identical to the pre-change baseline (includes
  7 pre-existing warnings, mostly in `test/design_preview/`).
- Full `flutter test` run against a clean worktree of the pre-change HEAD:
  every failure on the new tree (15: `composer_multiline_inset_test` x4,
  `drop_chrome_test` x10, `room_unread_divider_widget_test` x1) also fails on
  the old tree. No new failures.
- New tests: `sheet_floating_test`, `spring_press_bloom_test`,
  `glass_overlays_test`, `device_link_flow_test` (+ updated
  `devices_screen_test`, `create_room_sheet_layout_test`, `hover_test`,
  `pill_bottom_nav_gesture_test`, `room_header_controls_test`).
- Nothing was tried on a real device. Visuals were checked only through
  `test/design_preview` renders.

## 3. Decisions taken (and why)

- Refine the existing kit, never fork a parallel one (the app already had
  `LiquidGlass`, `Spring`, `SpringPress`, `MotionScope`, `GlassConfig`).
- Sheets keep a SOLID fill: blur on a moving sheet caused documented jank
  (`sheet_surface.dart` header comment).
- Radii stay theme-derived (17 themes; Retro/Cyberpunk stay square-ish).
- Toasts stay top-anchored (the codebase chose this explicitly).
- Linked-devices keeps real semantics (a phone approves a web/desktop login).
  No fake "confirm it's you" or Face ID step: no real re-auth gate exists and
  it would need `local_auth` (new dependency = user decision).
- Chats header camera slot became search: `CameraScreen` always needs a
  room-bound callback, so nothing on the chat list can receive a photo.
- Every animation collapses under `MotionScope.calm`; user-tunable
  `GlassConfig` knob ids were not renamed.

## 4. Open items (pick up here)

1. Real-device pass on iOS and Android. Note: on iOS the default tab bar is
   the native `UITabBar` (`NativeTabBar`), so the lens changes only show on
   the Flutter engine (Android, web, desktop, or GlassEngine.flutter).
2. Translations for the 16 new keys (`devicesHeroCaption`, `devicesLinkNew`,
   `devicesLinkedHeader`, `devicesLinkedOn`, `devicesLastActive`,
   `devicesMoreActions`, `devicesEmptyList`, `deviceLinkScanTitle`,
   `deviceLinkScanInstruction`, `deviceLinkEnterCodeInstead`,
   `deviceLinkScanInstead`, `deviceLinkEnterCodeTitle`,
   `deviceLinkEnterCodeBody`, `deviceLinkFinishTitle`, `deviceLinkLinkedHud`,
   `deviceLinkLinkedToast`). Non-English ARBs hold English placeholders.
3. `profile_screen.dart` ~1636-1645: the "Scan to sign in" row is now
   redundant (Devices owns the flow). Remove it with `_openDeviceLoginScan`,
   then update `deviceLoginScreenIntro` copy to point at Settings > Devices >
   Link a new device.
4. Settings search: the shared `SearchField` / `settings_search.dart` still
   renders large; target a 36pt filled capsule.
5. `room_filter_bar.dart`: lighter idle chip style (Signal's list is cleaner).
6. Big tappable `LiquidGlass` surfaces added later must pass `pressScale`
   (0.98 or 1.0); the default 1.06 bloom is for small controls.
7. `search_field.dart:420` `ClipRect` shaves ~1.3px of the Cancel disc bloom
   while pressed (left as is).
8. Optional, user decision: "confirm it's you" step with `local_auth`.
9. Pre-existing failing tests above are unrelated but still red.

## 5. How this was run, and what to do differently

- No Flutter on PATH on this machine: stable SDK installed at
  `~/.cache/flutter-sdk` (`export PATH="$HOME/.cache/flutter-sdk/bin:$PATH"`).
  `graphify` is not installed here, so `graphify update .` (CLAUDE.md) was
  not run.
- Screenshots without a backend: `flutter test test/design_preview/<x>_preview.dart`
  writes PNGs to `build/design_preview/` (iPhone 16 Pro size).
  `preview_kit.dart` now loads Inter under the SF Pro family names when SF
  Pro is missing (Linux). Relevant previews: `sheets_preview`,
  `sheets2_preview`, `wp2_preview`, `glass_overlays_preview`, `home_preview`,
  `settings_review_preview`, `devices_flow_preview`.
- An empty, gitignored `env.local` was created so tests can load the asset
  bundle.
- Orchestration: two read-only audit agents first, then 7 Sonnet work
  packages with strict file ownership (4 in parallel, then 3), then one fixer
  agent; orchestrator reviewed screenshots and diffed full-suite failures
  against a clean worktree.
- Rule slips in this session (the standing rules were not loaded on this
  machine): agents ran `dart format` on whole files (`home_screen.dart`,
  `how_to_play.dart`), and the full test suite was run instead of only
  touched files. Next session: never `dart format`, run only touched tests,
  never push or deploy without asking, no em dashes in user-facing text.
