# MonkeyHub · Glass design language (Signal iOS 26–inspired)

Source reference: a screen recording of Signal iOS (Liquid Glass era). Contact sheets are in
`docs/glass_reference/` (`sheet_01..04.png` = the full 29s at 2fps, `hires.png` = 5 key frames).
**Look at them before you write UI code.**

Goal: get MonkeyHub (Flutter) as close as practical to that design language: floating inset sheets,
glass controls, a floating capsule tab bar, grouped inset lists, and springy, physical motion,
without native code. Pure Flutter (`BackdropFilter`, `CustomPainter`, physics simulations).
No new pub dependencies unless the orchestrator approves.

## 1. How this maps onto MonkeyHub (dev branch) — READ FIRST

MonkeyHub already has a glass/motion system. We REFINE it toward section 2; we do not build a parallel kit.
Existing primitives to extend (not duplicate): `LiquidGlass` (lib/widgets/liquid_glass.dart), `GlassConfig`
(lib/data/glass_config.dart, user-tunable — never bypass it), `Spring` (lib/theme/spring.dart, response/ratio),
`MotionScope` (lib/theme/motion.dart — every new animation MUST collapse under `calm`), `SpringPress`,
`showAdaptiveSheet` (80 call sites), `SheetFrame`/`SheetHandle`/`sheetTopRadius` (lib/widgets/sheet_kit.dart),
`SheetDragHost` (sheet_drag.dart), `showIosActionSheet`/`showIosAlert` (sheet_kit.dart), `AppToast`,
`GlassIconButton`/`GlassPillButton`/`GlassButtonGroup` (glass_buttons.dart), `SheetActionButton`/`ProminentButton`
(action_buttons.dart), `Density` (lib/theme/density.dart), `PillBottomNav` + `NativeTabBar` (lib/screens/navigation/).

Orchestrator decisions (binding):
1. Sheets FLOAT on compact (phone) layouts: inset 8 from left/right/bottom, all four corners rounded,
   radius = concentric `sheetRadius(theme)` = `(radiusXl * 1.9).clamp(8, 38)` (round themes hit 38; Retro/Cyberpunk stay
   square-ish). Keep the SOLID fill (no BackdropFilter on moving sheets — documented jank in sheet_surface.dart).
   Desktop/wide popover path unchanged. Full-height sheets (ExpandingSheet at full) may attach to the bottom.
2. Sheet motion = spring (spec values; convert k/c to `Spring` response/ratio: k300 c30 → response 0.363, ratio 0.866),
   velocity hand-off on dismiss, rubber-band ×0.25 above top, dismiss at 700 px/s or 40%.
3. Radii stay theme-derived (clamps), never hard-coded 38/26 for all 17 themes.
4. Glass controls (circle/pill/group/tab lens) "bloom" (grow ~1.06, brighten, spring overshoot). Large capsules and
   list rows keep shrink (0.97). Phone glass circle = 44; compact-desktop Density stays 32.
5. Toast stays top-anchored app-wide.
6. Linked-devices flow keeps its real semantics (approve a web/desktop login). Borrow Signal's visuals only. No fake
   sync/Face ID. No new pub dependencies.
7. Every change gates on `MotionScope.calm`, works in light themes (Risograph, Basic light), and keeps
   `flutter analyze` at baseline (33 infos, 0 warnings/errors) + existing tests green (update tests that encode old geometry
   ONLY when the change is intentional, and say so).
8. Screenshots: `test/design_preview/` (preview_kit.dart `snap()`), output to build/design_preview/. On Linux SF Pro is
   missing → use an Inter-based theme or load Inter for the Cupertino family names in the preview.

## 2. Visual spec (measured from the recording, logical px @ 390pt width)

### Color (Glass theme, dark)
| token | value | where |
|---|---|---|
| background | `#000000` | chat list root |
| surface (page) | `#1C1C1E` | pushed pages (Linked Devices) |
| surfaceRaised (grouped card) | `#2C2C2E` | inset cards / list groups |
| surfaceSunken | `#121214` | inputs |
| ink | `#FFFFFF` | titles |
| inkSoft | `#EBEBF5` @ 0.80 | body |
| inkMuted | `#EBEBF5` @ 0.55 | captions, timestamps |
| accent | `#2C6BED` (Signal blue) | primary capsule, links, badges, ring |
| accentSoft | accent @ 0.18 | |
| success | `#30D158`, danger `#FF453A` | |
| glass tint (dark) | `#3A3A3C` @ 0.55 + blur σ 24 | sheets, buttons, tab bar |
| glass rim | white @ 0.10 top-left → white @ 0.02 bottom-right, 0.8px | specular edge |
| scrim behind modal | black @ 0.40 | |

Light themes (Risograph): glass tint = white @ 0.65, rim = white @ 0.6, scrim black @ 0.2.

### Type (Inter via google_fonts ≈ SF Pro)
nav title 17/600 · large section title 20/700 · section header 15/600 inkSoft · list title 16/500 ·
list subtitle 14/400 inkMuted · button 17/600 · caption 12/400 inkMuted · tab label 10/600.

### Geometry
- Screen-side margins 16. Grouped card radius **26**, internal padding 16, gap between groups 24.
- Floating sheet: inset **8** left/right/bottom from the safe edges (bottom: max(8, viewPadding.bottom − 26)),
  radius **38** (concentric with device corners), grabber 36×5 radius 2.5 at top, 8 below top edge, inkMuted @ 0.5.
- Full-height sheet / pushed "card" pages: top corners 38, attached to bottom edge.
- Glass circle button: **44** diameter, icon 20. Glass pill (e.g. "Edit"): height 44, h-padding 16, text 17/500.
- Button group (camera + compose in Chats header): one capsule h44 containing 2 icons, 44 each.
- Primary capsule button: height **50**, full width, radius 25, accent fill, white 17/600.
  Secondary capsule (action sheet "Cancel"): same shape, fill = ink @ 0.12.
- Floating tab bar: capsule h **62**, centered, bottom = safe bottom + 0 (sits in home-indicator area like
  iOS 26), width = items × 76 + 8; selected item has a lens capsule (ink @ 0.14) inset 4 that **slides** between
  items. Icon 24 + label 10/600 below.
- Progress dialog: centered card width 270, radius 30, ring 44 stroke 3 accent, title 17/600,
  sub 13 inkMuted, a hairline, then accent text button 17.
- HUD: 160×160 radius 22, glass, icon 64, label 15/600 below.
- Toast: capsule h 44, h-padding 20, glass (slightly lighter: ink @ 0.16 over tint), text 15/500,
  sits 96 above bottom safe edge (above tab bar). In from y+12/opacity 0, out reverse, 2.2s default.
- Section header: 15/600, padding left 4, 8 above card.
- Avatars: circles 52 in list rows; row height ~72; titles 16/600 + verified badge accent.

### Motion (this is what makes it feel native)
- **Sheets**: present with a spring (`SpringDescription(mass: 1, stiffness: 300, damping: 30)` ≈ iOS
  `.smooth`, slight settle), from below the screen. Scrim fades with 0.25 s. Dismiss: drag down follows the
  finger 1:1 (rubber-band above the top detent: offset * 0.25), release velocity > 700 px/s or past 40%
  of height → dismiss with a spring carrying the fling velocity; otherwise spring back.
- **Detents**: a sheet may declare detents (e.g. `[GlassDetent.fitContent]`, `[GlassDetent.fraction(0.5), GlassDetent.large]`,
  `GlassDetent.height(84)`). Height changes between detents animate with the same spring, and the
  sheet can **morph** between content states (`AnimatedSize` + crossfade), like "Scan QR Code" → collapsed
  "Finish Linking" bar in the reference.
- **Press bloom** (Liquid Glass): on pointer down glass controls scale to 1.06 (circle/pill) or 0.97 (big
  capsule / list rows), brighten tint +0.06; on release spring back (stiffness 400, damping 18 → tiny overshoot).
  Haptic `HapticFeedback.selectionClick()` on tab change, `lightImpact()` on primary button.
- **Tab lens**: slides with spring (stiffness 500, damping 32); while sliding it stretches horizontally
  by up to 1.15× based on velocity (goo/“liquid” feel), then settles.
- **Push**: iOS-style — incoming page slides from right (100%→0), outgoing slides to −30% and dims
  (black @ 0.1); edge-swipe back with interactive drag. Wrap/extend `CupertinoPageRoute` behaviour; duration 450 ms,
  curve `Curves.easeOutQuint` forward (`Cubic(0.2, 0.9, 0.1, 1.0)` is fine).
- **Dialogs/HUD**: scale 1.12→1.0 + fade in (spring, ~300 ms), scale 1.0→0.92 + fade out (180 ms).
- **Action sheet**: same floating inset card as sheets, but content = message + stacked capsule buttons,
  each button gap 10.
- Lists: staggered entrance (opacity 0→1, y 12→0, 40 ms stagger, max 8 items).

## 3. (sections 3–4 removed: written against an older codebase)
