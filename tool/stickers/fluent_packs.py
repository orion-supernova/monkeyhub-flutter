#!/usr/bin/env python3
"""Builds the Fluent 3D sticker packs from Microsoft's animated Fluent Emoji.

Source: https://github.com/microsoft/fluentui-emoji-animated (MIT). Each emoji
there is a 256px animated PNG of ~2.7 MB — far too heavy to send in a chat —
so this converts them to 192px animated WebP at ~12 fps, about 200 KB each,
and writes the manifest `backend/scripts/seed-sticker-packs.mjs` uploads from.

    python3 -m venv .venv && .venv/bin/pip install pillow
    .venv/bin/python tool/stickers/fluent_packs.py build/stickers/fluent

Needs the GitHub CLI (`gh`) for the repository listing. Re-running skips
anything already converted.
"""
import concurrent.futures as cf
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

from PIL import Image, ImageSequence

REPO = "microsoft/fluentui-emoji-animated"
MEDIA = f"https://media.githubusercontent.com/media/{REPO}/main/"
RAW = f"https://raw.githubusercontent.com/{REPO}/main/"

SIZE = 192
QUALITY = 72
FRAME_STEP = 2  # every other frame: ~12 fps, half the bytes, still smooth

AUTHOR = "Microsoft — Fluent Emoji"
LICENSE = "MIT"
SOURCE = "https://github.com/microsoft/fluentui-emoji-animated"

# Pack slug, title, and Fluent folder names in the order they appear. A name
# the repository does not have is skipped with a warning.
PACKS = [
    ("fluent-faces", "3D Faces", [
        "Grinning squinting face", "Face with tears of joy",
        "Rolling on the floor laughing", "Smiling face with heart-eyes",
        "Smiling face with hearts", "Star-struck", "Partying face",
        "Face blowing a kiss", "Winking face", "Smiling face with sunglasses",
        "Thinking face", "Face with rolling eyes", "Melting face",
        "Face holding back tears", "Loudly crying face", "Pleading face",
        "Exploding head", "Face screaming in fear", "Face with steam from nose",
        "Face with symbols on mouth", "Sleeping face", "Zany face",
        "Money-mouth face", "Nerd face", "Hugging face", "Shushing face",
        "Face with monocle", "Cowboy hat face", "Hot face", "Cold face",
    ]),
    ("fluent-animals", "3D Animals", [
        "Monkey face", "See-no-evil monkey", "Dog face", "Cat face", "Fox",
        "Panda", "Koala", "Lion", "Tiger face", "Unicorn", "Penguin", "Owl",
        "Frog", "Octopus", "Dolphin", "Spouting whale", "Butterfly",
        "Honeybee", "Turtle", "Hamster", "Rabbit face", "Bear",
        "Front-facing baby chick", "Hatching chick", "Parrot", "Flamingo",
        "Sloth", "Otter", "T-rex", "Dragon face",
    ]),
    ("fluent-love", "3D Love & celebrations", [
        "Red heart", "Heart on fire", "Sparkling heart", "Growing heart",
        "Beating heart", "Heart with arrow", "Mending heart", "Broken heart",
        "Heart hands", "Folded hands", "Clapping hands", "Thumbs up",
        "Waving hand", "Ok hand", "Victory hand", "Love-you gesture",
        "Handshake", "Flexed biceps", "Party popper", "Confetti ball",
        "Birthday cake", "Wrapped gift", "Balloon", "Fire", "Sparkles",
        "Hundred points", "Glowing star", "Clinking glasses", "Rocket",
        "Trophy",
    ]),
]


def repo_paths():
    out = subprocess.run(
        ["gh", "api", f"repos/{REPO}/git/trees/main?recursive=1",
         "--jq", '.tree[] | select(.path | endswith(".png")) | .path'],
        check=True, capture_output=True, text=True).stdout
    return out.split("\n")


def animated_path(paths, name):
    """The animated PNG for [name] — the plain one, or the Default skin tone."""
    prefix = f"assets/{name}/"
    plain = [p for p in paths if p.startswith(prefix + "animated/")]
    if plain:
        return plain[0]
    default = [p for p in paths if p.startswith(prefix + "Default/animated/")]
    return default[0] if default else None


def fetch(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def glyph(name):
    meta = json.loads(fetch(RAW + urllib.parse.quote(f"assets/{name}/metadata.json")))
    return meta.get("glyph", "")


def convert(src_bytes, dest):
    import io
    im = Image.open(io.BytesIO(src_bytes))
    frames, durations = [], []
    for f in ImageSequence.Iterator(im):
        frames.append(f.convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS))
        durations.append(int(f.info.get("duration", 42)))
    frames = frames[::FRAME_STEP]
    durations = [sum(durations[i:i + FRAME_STEP])
                 for i in range(0, len(durations), FRAME_STEP)]
    frames[0].save(dest, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, quality=QUALITY, method=4,
                   format="WEBP", minimize_size=True)


def build_one(job):
    name, path, dest = job
    if os.path.exists(dest):
        return name, None
    try:
        convert(fetch(MEDIA + urllib.parse.quote(path)), dest)
        return name, None
    except Exception as e:  # noqa: BLE001 — report and keep going
        return name, str(e)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    paths = repo_paths()
    manifest = []
    jobs = []
    for order, (slug, title, names) in enumerate(PACKS):
        pack_dir = os.path.join(out_dir, slug)
        os.makedirs(pack_dir, exist_ok=True)
        stickers = []
        for i, name in enumerate(names):
            path = animated_path(paths, name)
            if path is None:
                print(f"  skip (not in repo): {name}", file=sys.stderr)
                continue
            dest = os.path.join(pack_dir, f"{i:02d}.webp")
            jobs.append((name, path, dest))
            stickers.append({"file": os.path.relpath(dest, out_dir),
                             "name": name, "order": i})
        manifest.append({"slug": slug, "title": title, "author": AUTHOR,
                         "license": LICENSE, "sourceUrl": SOURCE,
                         "format": "image", "contentType": "image/webp",
                         "width": SIZE, "height": SIZE, "stickers": stickers})

    # Emoji first (cheap, serial is fine), then the heavy conversions in
    # parallel — one animated WebP encode takes a while.
    for pack in manifest:
        for s in pack["stickers"]:
            s["emoji"] = glyph(s.pop("name"))
    with cf.ProcessPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        for name, err in ex.map(build_one, jobs):
            print(f"  {'FAIL ' + err if err else 'ok'}: {name}", file=sys.stderr)

    for pack in manifest:
        pack["stickers"] = [s for s in pack["stickers"]
                            if os.path.exists(os.path.join(out_dir, s["file"]))]
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    total = sum(len(p["stickers"]) for p in manifest)
    size = sum(os.path.getsize(os.path.join(out_dir, s["file"]))
               for p in manifest for s in p["stickers"])
    print(f"{total} stickers, {size // 1024} KB, manifest at {out_dir}/manifest.json")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/stickers/fluent")
