# Patches on liquid_glass_widgets 1.17.0

Vendored from pub.dev (MIT). `example/` and `skills/` were dropped. Every change is marked `SWIRL PATCH` in the source: `grep -rn "SWIRL PATCH" lib`.

## Per-tab pill widths

Upstream sizes the selected pill to one equal tab slot. Native iOS hugs the selected tab's content: a short label gets a narrow pill and a long one a wide pill, and the pill changes size as it slides.

`GlassTabBar.bottom(indicatorItemWidths: [...])` takes one pill width per tab, in logical pixels. The tab slots, icons and labels stay equal. Null keeps the upstream behaviour.

The pill and the selected-colour mask also read the bar's `tabPadding` (`slotPadding`), which insets the whole tab row. Upstream assumes the default 4. With a larger inset (native has about 13) the slots move in and the pill follows, so it stays centered on its icon on the end tabs too.

Touched: `resolveVariableTabPill` (`tab_bar_layout_utils.dart`), `AnimatedGlassIndicator`, `JellyClipper` (the selected-colour mask, must match the pill), `TabIndicator`, `TabBarBottomLayout`, `GlassTabBar`.

## Upgrading

Upstream 1.17.0 (2026-11-07) does not include per-tab pill widths, so every `SWIRL PATCH` block was re-applied by diffing pristine 1.16.1 against our 1.16.1 and patching the result onto 1.17.0 (the indicator needed its import re-added by hand; `glass_tab_bar.dart` needed three hunks re-placed). To upgrade again: copy the new release over this folder and re-apply the `SWIRL PATCH` blocks (9 marked lines in 6 files). `example/` and `skills/` stay dropped.

## What 1.17.0 changed that matters to MonkeyHub

- Default style is `GlassStyle.ios27` everywhere (`LiquidGlassSettings.ios27Light` / `ios27Dark` / `ios27Indicator`), with `ios26` and `classic` selectable through `GlassTheme`. Our shader kit uses `ios27` presets by theme brightness.
- Calibrated against native UIKit: `GlassTabBar` (icon 27.5 pt, magnification 1.25), `GlassSwitch` (thumb shadow, shader mounted only while pressed), `GlassSlider`, `GlassSegmentedControl`, the indicator pill, `GlassMenu` / `GlassPullDownButton` / `GlassContextMenu`, `GlassModalSheet` / `GlassSheet` (38 pt corners), `GlassDialog` and action sheets (320 pt platter).
- Hero controls and transient overlays default to `GlassQuality.premium` under ios27; we pin quality ourselves from `ShaderGlassConfig` (premium only with Full lens refraction, never on low tier or in power saving).
- New: `GlassButton.pressLightColor`, `GlassMenu.opaqueColor` / `border`, `GlassSwitch` On/Off labels and RTL mirroring.

## MonkeyHub's copy

Started as Swirl's vendored copy (1.16.1 plus the SWIRL PATCH per-tab pill widths), upgraded to 1.17.0 on 2026-11-07. MonkeyHub makes no changes of its own beyond the patches above. It backs `UiKit.shader` (lib/ui/kits/shader/, lib/data/shader_glass_config.dart), which only runs on Android and iOS.
