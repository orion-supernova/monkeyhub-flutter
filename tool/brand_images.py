#!/usr/bin/env python3
"""Cuts every shipped brand image from its full-size original, as small as it
will go.

Run from the repo root after changing the logo, the splash or the Monkey
Collection:

    python3 tool/brand_images.py

Needs Pillow (with WebP) and pngquant (`brew install pngquant`).

What it writes:

  - branding/logo.webp: the in-app mark (`CanonicalLogo`, `MonkeyAvatar`),
    512px, from the 1024px master branding/logo.png. The master is NOT in the
    Flutter bundle; flutter_launcher_icons, flutter_native_splash and msix read
    it from disk.

  - The Monkey Collection, read from lib/widgets/monkey_collection.dart so the
    list lives in one place. For each variant, from branding/source/<name>.*:
      branding/monkey/<name>.webp                     512px, bundled
      ios/Runner/AlternateIcons/<id>@2x.png, @3x.png, 76x76@2x~ipad,
        83.5x83.5@2x~ipad                             120/180/152/167px
      android/.../mipmap-<density>/ic_launcher_<id>.png   48..192px

  - A pngquant pass over the launcher icons and splash images that
    flutter_launcher_icons and flutter_native_splash generate from the master.
    Those tools write full-colour PNGs, so re-run this after either of them.

Then `ruby tool/setup_ios_alternate_icons.rb` (or `pod install`) registers new
alternate-icon PNGs with Xcode.
"""

import glob
import os
import re
import shutil
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
COLLECTION_DART = "lib/widgets/monkey_collection.dart"
SOURCE_DIR = "branding/source"
BUNDLED_PX = 512
WEBP_QUALITY = 80

IOS_ICON_DIR = "ios/Runner/AlternateIcons"
IOS_SIZES = {"@2x": 120, "@3x": 180, "76x76@2x~ipad": 152, "83.5x83.5@2x~ipad": 167}
ANDROID_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

# Generated from the master by flutter_launcher_icons / flutter_native_splash.
QUANTIZE_GLOBS = [
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
    "ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png",
    "android/app/src/main/res/mipmap-*/ic_launcher.png",
    "android/app/src/main/res/drawable*/ic_launcher_foreground.png",
    "android/app/src/main/res/drawable*/splash.png",
    "android/app/src/main/res/drawable*/android12splash.png",
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
    "web/favicon.png",
    "web/icons/*.png",
    "linux/packaging/monkeyhub.png",
]


def collection():
    """(id, asset path) for every MonkeyVariant, in declaration order."""
    text = open(COLLECTION_DART).read()
    pairs = re.findall(
        r"id:\s*'([^']+)',\s*displayName:\s*'[^']*',\s*assetPath:\s*'([^']+)'",
        text,
    )
    if not pairs:
        sys.exit(f"No MonkeyVariant entries found in {COLLECTION_DART}")
    return pairs


def source_for(asset_path):
    name = os.path.splitext(os.path.basename(asset_path))[0]
    found = [
        p for p in glob.glob(os.path.join(SOURCE_DIR, name + ".*"))
        if os.path.splitext(p)[1].lower() in (".png", ".jpg", ".jpeg", ".webp")
    ]
    if len(found) != 1:
        sys.exit(f"Expected one original for {name} in {SOURCE_DIR}, found {found}")
    return found[0]


def opaque(path):
    # Every icon here is full-bleed artwork; iOS rejects alpha in launcher icons.
    return Image.open(path).convert("RGB")


def resized(img, px):
    return img if img.size == (px, px) else img.resize((px, px), Image.LANCZOS)


def write_webp(img, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    resized(img, BUNDLED_PX).save(out, "WEBP", quality=WEBP_QUALITY, method=6)


def write_png(img, px, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    resized(img, px).save(out, "PNG", optimize=True)
    quantize(out)


def quantize(path):
    # Exit 98/99: the result would be larger or below quality; keep the input.
    # The floor is low on purpose: these are photographic renders, which
    # score around Q=50 at 256 colours yet look identical at icon and splash
    # sizes, and a higher floor silently skips every one of them.
    r = subprocess.run(
        ["pngquant", "--quality=40-90", "--speed=1", "--strip",
         "--skip-if-larger", "--force", "--ext", ".png", path],
        capture_output=True,
    )
    if r.returncode not in (0, 98, 99):
        sys.exit(f"pngquant failed on {path}: {r.stderr.decode()}")


def main():
    os.chdir(ROOT)
    if not shutil.which("pngquant"):
        sys.exit("pngquant not found: brew install pngquant")

    write_webp(opaque("branding/logo.png"), "branding/logo.webp")
    print("branding/logo.webp")

    for icon_id, asset in collection():
        img = opaque(source_for(asset))
        write_webp(img, asset)
        for suffix, px in IOS_SIZES.items():
            write_png(img, px, f"{IOS_ICON_DIR}/{icon_id}{suffix}.png")
        for density, px in ANDROID_SIZES.items():
            write_png(img, px,
                      f"android/app/src/main/res/mipmap-{density}/ic_launcher_{icon_id}.png")
        print(f"{asset}  ({icon_id})")

    for pattern in QUANTIZE_GLOBS:
        for path in sorted(glob.glob(pattern)):
            quantize(path)
    print("quantized generated launcher icons and splash images")


if __name__ == "__main__":
    main()
