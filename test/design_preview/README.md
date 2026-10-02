# Design previews

Not tests. Each `*_preview.dart` renders real widgets under every theme to PNG
so a design change can be looked at before it ships. They are deliberately not
named `*_test.dart`, so the regular suite never runs them; run one by path:

    flutter test test/design_preview/home_preview.dart

PNGs land in `build/design_preview/` (gitignored). `preview_kit.dart` loads the
real fonts (SF from macOS, the bundled Google fonts, the icon fonts), so the
renders match the device closely; emoji render as boxes.
