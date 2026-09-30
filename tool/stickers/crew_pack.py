#!/usr/bin/env python3
"""Builds the MonkeyHub Crew sticker pack — the brand's own 3D monkeys, moving.

The characters are the ones in branding/: the logo monkey, the astronaut,
the steampunk one, the hiker and the chimp from the "hmm" art. Each is lifted
off its background with the same Vision cutout the app's sticker maker uses
(tool/stickers/cutout.swift), given a white die-cut edge, and animated —
bobs, bounces, a glint across the glasses — with 3D props from Microsoft's
Fluent Emoji (MIT) and the app's cyan chat bubble around them.

    python3 -m venv .venv && .venv/bin/pip install pillow skia-python numpy
    .venv/bin/python tool/stickers/fluent_packs.py build/stickers/fluent
    .venv/bin/python tool/stickers/crew_pack.py build/stickers/crew \\
        build/stickers/fluent

`--sheet <png>` instead draws a contact sheet. Every sticker is a function of
t in [0, 1); motion goes round whole periods, so the loops are seamless.
"""
import io
import json
import math
import os
import subprocess
import sys

import numpy as np
import skia
from PIL import Image, ImageFilter, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from monkey_pack import (CYAN, CYAN_DARK, INK, PINK, WHITE, YELLOW,  # noqa: E402
                         bubble, circle, ease, fill_stroke, paint, star, text)

W = 512
OUT = 320
FRAMES = 30
FRAME_MS = 50
TAU = math.tau
EDGE = 9  # white die-cut edge, in drawing pixels

BRASS = 0xC8A24A
BRASS_DARK = 0x6B5220


# --- the characters ----------------------------------------------------------

def cutout(src):
    """The subject of branding/<src>, on transparency (cached in build/)."""
    cache = os.path.join(ROOT, 'build', 'stickers', 'cutouts')
    os.makedirs(cache, exist_ok=True)
    dest = os.path.join(cache, os.path.basename(src))
    if not os.path.exists(dest):
        subprocess.run(['swift', os.path.join(HERE, 'cutout.swift'),
                        os.path.join(ROOT, src), dest], check=True)
    return Image.open(dest).convert('RGBA')


def prepare(img, crop=None, oval=None):
    """Crops to [crop] (fractions), rounds a flat cut with [oval] (fractions
    of the crop: cx, cy, rx, ry), and pulls the edge in a pixel so no halo of
    the old background survives."""
    w, h = img.size
    if crop:
        l, t, r, b = crop
        img = img.crop((int(l * w), int(t * h), int(r * w), int(b * h)))
        w, h = img.size
    a = np.array(img.getchannel('A'), dtype=np.float32) / 255
    if oval:
        cx, cy, rx, ry = oval
        yy, xx = np.mgrid[0:h, 0:w]
        d = ((xx - cx * w) / (rx * w)) ** 2 + ((yy - cy * h) / (ry * h)) ** 2
        # A soft pixel or two of edge, not a jagged one.
        a *= np.clip((1 - d) * min(w, h) * 0.25, 0, 1)
    mask = Image.fromarray((a * 255).astype(np.uint8)).filter(
        ImageFilter.MinFilter(3))
    img.putalpha(mask)
    return img.crop(img.getbbox())


def to_skia(img):
    arr = np.ascontiguousarray(np.array(img.convert('RGBA')))
    return skia.Image.fromarray(arr, colorType=skia.kRGBA_8888_ColorType)


class Actor:
    """A character: its picture, and where it stands on the canvas."""

    def __init__(self, img, height, foot=478, x=256):
        self.src = img
        self.img = to_skia(img)
        self.scale = height / img.height
        self.w = img.width * self.scale
        self.h = height
        self.x = x
        self.foot = foot

    def point(self, fx, fy):
        """Canvas position of a point given in fractions of the picture."""
        return (self.x - self.w / 2 + fx * self.w,
                self.foot - self.h + fy * self.h)

    def draw(self, c, rot=0.0, sx=1.0, sy=1.0, dx=0.0, dy=0.0, img=None):
        c.save()
        c.translate(self.x + dx, self.foot + dy)
        c.rotate(rot)
        c.scale(sx, sy)
        c.drawImageRect(img or self.img, skia.Rect.MakeLTRB(
            -self.w / 2, -self.h, self.w / 2, 0),
            skia.SamplingOptions(skia.CubicResampler.Mitchell()))
        c.restore()


def glinted(actor, box, t, dark=True):
    """[actor]'s picture with a shine sweeping across its lenses — the dark
    (or, for mirrored goggles, the bright and saturated) pixels in [box]."""
    arr = np.array(actor.src, dtype=np.float32)
    h, w = arr.shape[:2]
    l, tp, r, b = (int(box[0] * w), int(box[1] * h), int(box[2] * w),
                   int(box[3] * h))
    region = arr[tp:b, l:r]
    rgb = region[..., :3]
    lum = rgb.mean(-1)
    if dark:
        lens = (lum < 45) & (region[..., 3] > 200)
    else:
        sat = rgb.max(-1) - rgb.min(-1)
        lens = (sat > 60) & (region[..., 3] > 200)
    yy, xx = np.mgrid[0:b - tp, 0:r - l]
    # A diagonal band that crosses the lenses in the first half of the loop
    # and rests off them for the second.
    pos = -0.3 + 1.9 * min(1.0, t * 2)
    u = (xx / (r - l)) + 0.5 * (yy / (b - tp))
    band = np.exp(-((u - pos) / 0.07) ** 2) * 0.85
    band += np.exp(-((u - pos + 0.16) / 0.025) ** 2) * 0.6
    add = (band * lens)[..., None]
    region[..., :3] = rgb * (1 - add) + 255 * add
    arr[tp:b, l:r] = region
    return to_skia(Image.fromarray(arr.astype(np.uint8), 'RGBA'))


class Prop:
    """A Fluent emoji, playing its own animation."""

    def __init__(self, fluent_dir, file):
        im = Image.open(os.path.join(fluent_dir, file))
        self.frames = [to_skia(f.convert('RGBA'))
                       for f in ImageSequence.Iterator(im)]

    def draw(self, c, x, y, size, t, rot=0.0, alpha=255, speed=1):
        f = self.frames[int((t * speed % 1.0) * len(self.frames))]
        c.save()
        c.translate(x, y)
        c.rotate(rot)
        p = skia.Paint(AntiAlias=True)
        p.setAlphaf(alpha / 255)
        c.drawImageRect(f, skia.Rect.MakeLTRB(-size / 2, -size / 2, size / 2,
                                              size / 2),
                        skia.SamplingOptions(skia.CubicResampler.Mitchell()), p)
        c.restore()


# --- motion ------------------------------------------------------------------

def hop(t, n=1):
    """0 on the ground, 1 at the top of a hop; [n] hops a loop."""
    return abs(math.sin(math.pi * t * n))


def squash(t, n=1):
    """Squash on landing: 1 in the air, below 1 at the moment of touchdown."""
    d = min((t * n) % 1.0, 1 - (t * n) % 1.0)
    return 1 - 0.07 * max(0.0, 1 - d / 0.12)


def gear(c, x, y, r, teeth, rot, color=BRASS):
    p = skia.Path()
    for i in range(teeth * 2):
        a0 = rot + math.pi * i / teeth
        a1 = rot + math.pi * (i + 1) / teeth
        rr = r if i % 2 == 0 else r * 0.8
        for a in (a0 + 0.06, a1 - 0.06):
            px, py = x + rr * math.cos(a), y + rr * math.sin(a)
            p.moveTo(px, py) if (i == 0 and a == a0 + 0.06) else p.lineTo(px, py)
    p.close()
    hole = skia.Path()
    hole.addCircle(x, y, r * 0.32)
    body = skia.Op(p, hole, skia.PathOp.kDifference_PathOp)
    fill_stroke(c, body, color, 4, BRASS_DARK)


# --- the stickers ------------------------------------------------------------

class Crew:
    def __init__(self, fluent_dir):
        logo = prepare(cutout('branding/logo.png'))
        self.logo = Actor(logo, 410, x=250)
        astro = prepare(cutout('branding/monkey/monkey-astronaut.png'),
                        crop=(0, 0, 1, 0.74), oval=(0.5, 0.36, 0.56, 0.66))
        self.astro = Actor(astro, 400)
        steam = prepare(cutout('branding/monkey/monkey-fields.png'),
                        crop=(0, 0, 1, 0.7), oval=(0.5, 0.34, 0.6, 0.68))
        self.steam = Actor(steam, 400)
        self.hiker = Actor(prepare(cutout('branding/monkey/monkey-hiking.png')),
                           420)
        hmm = prepare(cutout('branding/monkey/monkey-hmm.png'),
                      crop=(0.0, 0.0, 1, 1), oval=(0.5, 0.52, 0.5, 0.5))
        self.hmm = Actor(hmm, 330, foot=470, x=300)
        f = lambda name: Prop(fluent_dir, name)  # noqa: E731
        self.heart = f('fluent-love/00.webp')
        self.wave = f('fluent-love/12.webp')
        self.thumb = f('fluent-love/11.webp')
        self.popper = f('fluent-love/18.webp')
        self.fire = f('fluent-love/23.webp')
        self.glow = f('fluent-love/26.webp')
        self.rocket = f('fluent-love/28.webp')
        self.hundred = f('fluent-love/25.webp')
        # The logo monkey's sunglasses, and the steampunk goggles, as
        # fractions of their pictures.
        self.logo_lenses = (0.05, 0.2, 0.95, 0.36)
        self.steam_lenses = (0.2, 0.26, 0.8, 0.46)

    def stickers(self):
        return [
            ('cool', '😎', self.cool),
            ('love', '😍', self.love),
            ('typing', '💬', self.typing),
            ('party', '🥳', self.party),
            ('gamer', '🎮', self.gamer),
            ('sleepy', '😴', self.sleepy),
            ('space', '🚀', self.space),
            ('wow', '🤩', self.wow),
            ('nerd', '🤓', self.nerd),
            ('hundred', '💯', self.hundred_),
            ('hi', '👋', self.hi),
            ('thumbs', '👍', self.thumbs),
            ('hike', '🥾', self.hike),
            ('thinking', '🤔', self.thinking),
        ]

    def plain_stickers(self):
        """The characters alone — no props, no motion."""
        def still(actor, **kw):
            return lambda c, t: actor.draw(c, **kw)
        return [
            ('logo', '😎', still(self.logo)),
            ('astronaut', '🚀', still(self.astro)),
            ('steampunk', '🤓', still(self.steam)),
            ('hiker', '🥾', still(self.hiker)),
            ('thinking', '🤔', still(self.hmm)),
        ]

    def cool(self, c, t):
        a = self.logo
        nod = math.sin(TAU * t * 2)
        a.draw(c, sy=1 - 0.012 * (1 + nod), dy=0,
               img=glinted(a, self.logo_lenses, t))
        s = ease(t * 2)
        if s > 0.1:
            self.glow.draw(c, 430, 120, 110 * s, t)
        s2 = ease(t * 2 + 0.5)
        if s2 > 0.2:
            fill_stroke(c, star(80, 190, 26 * s2), WHITE, 0)

    def love(self, c, t):
        a = self.logo
        a.draw(c, rot=3 * math.sin(TAU * t))
        for k in range(3):
            ph = (t + k / 3) % 1.0
            x = [120, 400, 250][k] + 24 * math.sin(TAU * (ph + k * 0.3))
            y = 260 - 230 * ph
            # Grows in and shrinks away (see gamer for why not a fade).
            size = 110 * min(1, 5 * ph, 4 * (1 - ph))
            if size > 12:
                self.heart.draw(c, x, y, size, t + k / 3)

    def typing(self, c, t):
        a = self.logo
        a.x = 210
        a.draw(c, dy=-6 * ease(t), sy=1 + 0.01 * ease(t))
        a.x = 250
        s = 1 + 0.04 * math.sin(TAU * t)
        c.save()
        c.translate(392, 110)
        c.scale(s, s)
        bubble(c, 0, 0, 170, 108, t)
        c.restore()

    def party(self, c, t):
        a = self.logo
        colors = [PINK, YELLOW, CYAN, 0x86EFAC, 0xC4B5FD]
        for k in range(14):  # confetti behind
            ph = (t + k * 0.37) % 1.0
            x = 30 + (k * 71) % 452
            y = -30 + 580 * ph
            c.save()
            c.translate(x, y)
            c.rotate(360 * ph * (1 if k % 2 else -1) + k * 30)
            c.drawRect(skia.Rect.MakeLTRB(-11, -5, 11, 5), paint(colors[k % 5]))
            c.restore()
        h = hop(t, 2)
        a.draw(c, dy=-44 * h, sy=squash(t, 2), sx=2 - squash(t, 2))
        self.popper.draw(c, 420, 150, 150, t, rot=-10)

    def gamer(self, c, t):
        a = self.logo
        jitter = math.sin(TAU * t * 6)
        a.draw(c, rot=1.6 * jitter, dy=-3 * abs(jitter))
        cx, cy = a.point(0.5, 0.64)
        colors = [CYAN, PINK, 0xA3E635, YELLOW]
        for k in range(8):  # pixels flying off the console, out to the sides
            ph = (t * 2 + k / 8) % 1.0
            side = 1 if k % 2 else -1
            ang = (-0.55 + 0.25 * (k // 2)) if side > 0 else \
                (math.pi + 0.55 - 0.25 * (k // 2))
            r = 90 + 150 * ph
            x, y = cx + r * math.cos(ang), cy + r * math.sin(ang)
            # Shrinking out, not fading: a faded speck keeps its full white
            # edge and reads as a stray grey dot.
            s = 16 * (1 - ph)
            if s > 3:
                c.drawRect(skia.Rect.MakeXYWH(x - s / 2, y - s / 2, s, s),
                           paint(colors[k % 4]))
        self.fire.draw(c, 430, 110, 110, t)

    def sleepy(self, c, t):
        a = self.logo
        a.draw(c, rot=-5 + 3 * math.sin(TAU * t), sy=1 - 0.015 * ease(t))
        for k in range(3):
            ph = (t + k / 3) % 1.0
            alpha = int(255 * math.sin(math.pi * ph))
            text(c, 'z' if k % 2 else 'Z', 350 + 70 * ph, 150 - 110 * ph,
                 52 + 26 * ph, CYAN_DARK, alpha, rot=-12)

    def space(self, c, t):
        for k in range(9):  # stars behind, twinkling
            x = 40 + (k * 131) % 440
            y = 40 + (k * 83) % 300
            s = 5 + 9 * ease(t + k * 0.21)
            fill_stroke(c, star(x, y, s), WHITE if k % 3 else YELLOW, 0)
        # the rocket streaks past behind the helmet, high up
        self.rocket.draw(c, -80 + 680 * t, 150 - 110 * t, 100, t)
        a = self.astro
        a.draw(c, rot=5 * math.sin(TAU * t), dy=-14 - 14 * math.sin(TAU * t))

    def wow(self, c, t):
        a = self.astro
        s = 1 + 0.03 * ease(t * 2)
        a.draw(c, sx=s, sy=s)
        for k in range(6):
            ang = TAU * k / 6 + 0.4
            ph = (t * 2 + k / 6) % 1.0
            r = 205 + 20 * ph
            x, y = 256 + r * math.cos(ang), 250 + r * 0.9 * math.sin(ang)
            fill_stroke(c, star(x, y, 22 * math.sin(math.pi * ph) + 1,
                                rot=ph), YELLOW if k % 2 else WHITE, 0)
        self.glow.draw(c, 420, 90, 90, t)

    def nerd(self, c, t):
        gear(c, 70, 120, 46, 10, TAU * t / 5)
        gear(c, 128, 58, 30, 8, -TAU * t / 5 * 46 / 30 + 0.2)
        gear(c, 448, 150, 38, 9, -TAU * t / 5)
        a = self.steam
        a.draw(c, rot=2 * math.sin(TAU * t),
               img=glinted(a, self.steam_lenses, t, dark=False))

    def hundred_(self, c, t):
        a = self.steam
        a.draw(c, dy=-8 * hop(t, 2), sy=squash(t, 2))
        s = 1 + 0.12 * ease(t * 2)
        self.hundred.draw(c, 420, 120, 130 * s, t, rot=12)

    def hi(self, c, t):
        a = self.hiker
        a.x = 230
        a.draw(c, rot=3 * math.sin(TAU * t))
        a.x = 256
        self.wave.draw(c, 410, 170, 150, t, rot=10 * math.sin(TAU * t * 2),
                       speed=2)

    def thumbs(self, c, t):
        a = self.hiker
        a.x = 220
        a.draw(c, dy=-10 * hop(t, 1), sy=squash(t, 1))
        a.x = 256
        s = 1 + 0.1 * ease(t * 2)
        self.thumb.draw(c, 410, 200 - 12 * ease(t * 2), 150 * s, t)

    def hike(self, c, t):
        a = self.hiker
        h = hop(t, 2)
        side = 1 if (t * 2) % 2 < 1 else -1
        a.draw(c, dy=-26 * h, rot=side * 4 * h, sy=squash(t, 2))

    def thinking(self, c, t):
        a = self.hmm
        a.draw(c, rot=-2 * math.sin(TAU * t))
        s = 1 + 0.04 * math.sin(TAU * t)
        c.save()
        c.translate(140, 130)
        c.scale(-s, s)  # the tail points back at the chimp
        bubble(c, 0, 0, 180, 112, t, dots=False)
        c.restore()
        for i in range(3):
            lift = max(0.0, math.sin(TAU * (t - i * 0.14)))
            c.drawPath(circle(140 + (i - 1) * 45, 130 - 10 * lift, 11),
                       paint(WHITE))


# --- output ------------------------------------------------------------------

def render(fn, t):
    surface = skia.Surface(W, W)
    c = surface.getCanvas()
    c.clear(skia.ColorTRANSPARENT)
    fn(c, t)
    art = surface.makeImageSnapshot()
    out = skia.Surface(W, W)
    oc = out.getCanvas()
    oc.clear(skia.ColorTRANSPARENT)
    edge = skia.Paint(AntiAlias=True)
    edge.setColorFilter(
        skia.ColorFilters.Blend(skia.ColorWHITE, skia.BlendMode.kSrcIn))
    for k in range(20):  # a round die-cut edge (Skia's dilate is square)
        a = TAU * k / 20
        oc.drawImage(art, EDGE * math.cos(a), EDGE * math.sin(a),
                     skia.SamplingOptions(), edge)
    oc.drawImage(art, 0, 0)
    small = skia.Surface(OUT, OUT)
    sc = small.getCanvas()
    sc.clear(skia.ColorTRANSPARENT)
    sc.drawImageRect(out.makeImageSnapshot(), skia.Rect.MakeWH(OUT, OUT),
                     skia.SamplingOptions(skia.CubicResampler.Mitchell()))
    arr = small.makeImageSnapshot().toarray(
        colorType=skia.kRGBA_8888_ColorType, alphaType=skia.kUnpremul_AlphaType)
    return Image.fromarray(np.ascontiguousarray(arr), 'RGBA')


def sheet(crew, dest, per=4):
    items = crew.stickers()
    img = Image.new('RGBA', (OUT * per, OUT * len(items)), (38, 42, 50, 255))
    for i, (_, _, fn) in enumerate(items):
        for k in range(per):
            img.alpha_composite(render(fn, k / per), (k * OUT, i * OUT))
    img.save(dest)


# The moment each sticker is caught at when it is saved still: the glint
# mid-sweep, the hearts in the air, the hop at its top.
STILL_AT = {'cool': 0.28, 'love': 0.45, 'party': 0.25, 'space': 0.3,
            'hike': 0.25, 'thumbs': 0.5, 'hundred': 0.25}


def build(crew, out_dir, plain=False):
    """Writes the pack as still WebP stickers: the dressed-up set, or with
    [plain] just the characters themselves."""
    slug = 'monkeyhub-crew-plain' if plain else 'monkeyhub-crew'
    pack_dir = os.path.join(out_dir, slug)
    os.makedirs(pack_dir, exist_ok=True)
    stickers = []
    items = crew.plain_stickers() if plain else crew.stickers()
    for i, (name, emoji, fn) in enumerate(items):
        dest = os.path.join(pack_dir, f'{i:02d}-{name}.webp')
        render(fn, STILL_AT.get(name, 0.25)).save(
            dest, quality=88, method=6, format='WEBP')
        stickers.append({'file': os.path.relpath(dest, out_dir),
                         'order': i, 'emoji': emoji})
        print(f'  {name}: {os.path.getsize(dest) // 1024} KB', file=sys.stderr)
    manifest = [{
        'slug': slug,
        'title': 'MonkeyHub Crew' + (' (plain)' if plain else ''),
        'order': -2,
        'author': 'MonkeyHub' + ('' if plain else '; props: Microsoft Fluent Emoji'),
        'license': 'Original artwork' + ('' if plain else '; props MIT'),
        'sourceUrl': 'https://monkeyhub.walhallaa.com', 'format': 'image',
        'contentType': 'image/webp', 'width': OUT, 'height': OUT,
        'stickers': stickers,
    }]
    with open(os.path.join(out_dir, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)


if __name__ == '__main__':
    args = sys.argv[1:]
    plain = '--plain' in args
    args = [a for a in args if a != '--plain']
    if args and args[0] == '--sheet':
        sheet(Crew(args[2]), args[1])
    else:
        build(Crew(args[1] if len(args) > 1 else 'build/stickers/fluent'),
              args[0] if args else 'build/stickers/crew', plain=plain)
