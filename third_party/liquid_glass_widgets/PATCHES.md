# Patches on liquid_glass_widgets 1.16.1

Vendored from pub.dev (MIT). `example/` and `skills/` were dropped. Every change is marked `SWIRL PATCH` in the source: `grep -rn "SWIRL PATCH" lib`.

## Per-tab pill widths

Upstream sizes the selected pill to one equal tab slot. Native iOS hugs the selected tab's content: a short label gets a narrow pill and a long one a wide pill, and the pill changes size as it slides.

`GlassTabBar.bottom(indicatorItemWidths: [...])` takes one pill width per tab, in logical pixels. The tab slots, icons and labels stay equal. Null keeps the upstream behaviour.

The pill and the selected-colour mask also read the bar's `tabPadding` (`slotPadding`), which insets the whole tab row. Upstream assumes the default 4. With a larger inset (native has about 13) the slots move in and the pill follows, so it stays centered on its icon on the end tabs too.

Touched: `resolveVariableTabPill` (`tab_bar_layout_utils.dart`), `AnimatedGlassIndicator`, `JellyClipper` (the selected-colour mask, must match the pill), `TabIndicator`, `TabBarBottomLayout`, `GlassTabBar`.

## Upgrading

Upstream 1.16.1 changes nothing for us until we bump. To upgrade: copy the new release over this folder and re-apply the `SWIRL PATCH` blocks (7 sites).

## MonkeyHub's copy

Copied unchanged from Swirl's vendored copy (1.16.1 plus the SWIRL PATCH per-tab pill widths) on 2026-11-07. MonkeyHub makes no changes of its own. It backs `UiKit.shader` (lib/ui/kits/shader/, lib/data/shader_glass_config.dart), which only runs on Android and iOS. Re-sync from Swirl rather than editing here.
