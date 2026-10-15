#!/usr/bin/env python3
"""Slims every bundled font in assets/google_fonts/ in place, keeping exactly
the characters each file already covers.

    python3 -m venv .venv && .venv/bin/pip install fonttools
    .venv/bin/python tool/slim_fonts.py

What goes, and why it is safe:

  - TrueType hinting (fpgm/prep/cvt and per-glyph instructions). Apple
    platforms never run it. Android's FreeType can, so small text there may
    land a fraction of a pixel differently; at phone densities that is not
    visible.
  - Glyphs only reachable through OpenType features this app never asks for:
    stylistic sets, small caps, old-style figures and the like. Kept are the
    features the text shaper applies by default, plus `tnum`, which 119 call
    sites request through `FontFeature.tabularFigures()`. A new FontFeature
    in lib/ means adding its tag to LAYOUT_FEATURES and re-running this.

Variation tables are left alone. Inter and Fraunces still carry a live axis
(opsz; SOFT/WONK), and pinning Fraunces to its default instance changed how it
rendered, so the ~0.3 MB that pinning would save is not worth it.

Checked by rendering every font old and new through Flutter on macOS: all 53
pixel-identical, tabular figures included.

Idempotent: a second run changes nothing measurable.
"""

import glob
import os

from fontTools import subset
from fontTools.ttLib import TTFont

FONT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "google_fonts")

LAYOUT_FEATURES = [
    # Applied by HarfBuzz by default.
    "rvrn", "ccmp", "locl", "mark", "mkmk", "kern", "liga", "clig", "calt",
    "rlig",
    # Requested explicitly: FontFeature.tabularFigures().
    "tnum",
]


def slim(path):
    font = TTFont(path)
    options = subset.Options()
    options.layout_features = LAYOUT_FEATURES
    options.hinting = False
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.glyph_names = False
    options.drop_tables += ["DSIG", "hdmx", "VDMX", "LTSH", "gasp"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=list(font.getBestCmap().keys()))
    subsetter.subset(font)
    font.save(path)


def main():
    before = after = 0
    for path in sorted(glob.glob(os.path.join(FONT_DIR, "*.ttf"))):
        before += os.path.getsize(path)
        slim(path)
        after += os.path.getsize(path)
    print(f"assets/google_fonts: {before / 1e6:.2f} MB -> {after / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
