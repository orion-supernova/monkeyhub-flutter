#!/usr/bin/env python3
"""Draws the MonkeyHub monkey sticker pack — our own mascot, frame by frame.

A cartoon chimp in the app's colours (brown fur, a warm face, the cyan of the
chat bubble in branding/monkey), drawn with Skia at 512px, given a white
die-cut edge, and written as 256px animated WebP loops, with the manifest
backend/scripts/seed-sticker-packs.mjs uploads from.

    python3 -m venv .venv && .venv/bin/pip install pillow skia-python
    .venv/bin/python tool/stickers/monkey_pack.py build/stickers/monkey

Every sticker is a function of t in [0, 1) that draws one frame; anything
that moves goes round a whole sine period, so each loop is seamless.
"""
import json
import math
import os
import sys

import numpy as np
import skia
from PIL import Image

W = 512  # drawing size
OUT = 256  # file size
FRAMES = 36
FRAME_MS = 40

FUR = 0x7A4A2A
FUR_DARK = 0x5C3520
SKIN = 0xF6D5B0
SKIN_DARK = 0xE3AE84
INK = 0x2E1B0F
MOUTH = 0x7A1F2A
TONGUE = 0xF07C8C
BLUSH = 0xF39A9A
CYAN = 0x22D3EE
CYAN_DARK = 0x0E7490
RED = 0xEF4444
PINK = 0xFB7185
YELLOW = 0xFACC15
WHITE = 0xFFFFFF
TEAR = 0x7DD3FC

TAU = math.tau


def paint(color, alpha=255, stroke=0.0, cap=skia.Paint.kRound_Cap):
    p = skia.Paint(AntiAlias=True)
    p.setColor(skia.ColorSetARGB(alpha, color >> 16 & 255, color >> 8 & 255,
                                 color & 255))
    if stroke:
        p.setStyle(skia.Paint.kStroke_Style)
        p.setStrokeWidth(stroke)
        p.setStrokeCap(cap)
        p.setStrokeJoin(skia.Paint.kRound_Join)
    return p


def fill_stroke(c, path, color, width=6.0, ink=INK):
    c.drawPath(path, paint(color))
    if width:
        c.drawPath(path, paint(ink, stroke=width))


def oval(cx, cy, rx, ry):
    p = skia.Path()
    p.addOval(skia.Rect.MakeLTRB(cx - rx, cy - ry, cx + rx, cy + ry))
    return p


def circle(cx, cy, r):
    return oval(cx, cy, r, r)


def heart(cx, cy, s):
    p = skia.Path()
    p.moveTo(cx, cy + 0.42 * s)
    p.cubicTo(cx - 0.62 * s, cy + 0.02 * s, cx - 0.5 * s, cy - 0.58 * s,
              cx, cy - 0.2 * s)
    p.cubicTo(cx + 0.5 * s, cy - 0.58 * s, cx + 0.62 * s, cy + 0.02 * s,
              cx, cy + 0.42 * s)
    p.close()
    return p


def drop(cx, cy, s):
    p = skia.Path()
    p.moveTo(cx, cy - s)
    p.cubicTo(cx + 0.2 * s, cy - 0.5 * s, cx + 0.6 * s, cy - 0.1 * s,
              cx + 0.6 * s, cy + 0.3 * s)
    p.cubicTo(cx + 0.6 * s, cy + 0.75 * s, cx - 0.6 * s, cy + 0.75 * s,
              cx - 0.6 * s, cy + 0.3 * s)
    p.cubicTo(cx - 0.6 * s, cy - 0.1 * s, cx - 0.2 * s, cy - 0.5 * s,
              cx, cy - s)
    p.close()
    return p


def star(cx, cy, r, points=4, inner=0.38, rot=0.0):
    p = skia.Path()
    for i in range(points * 2):
        a = rot + i * math.pi / points - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        p.moveTo(x, y) if i == 0 else p.lineTo(x, y)
    p.close()
    return p


def union(*paths):
    out = paths[0]
    for q in paths[1:]:
        out = skia.Op(out, q, skia.PathOp.kUnion_PathOp)
    return out


def arc(c, cx, cy, rx, ry, start, sweep, color=INK, width=7.0):
    p = skia.Path()
    p.addArc(skia.Rect.MakeLTRB(cx - rx, cy - ry, cx + rx, cy + ry), start,
             sweep)
    c.drawPath(p, paint(color, stroke=width))


def text(c, s, x, y, size, color, alpha=255, rot=0.0):
    font = skia.Font(skia.Typeface('Arial Rounded MT Bold') or
                     skia.Typeface('Helvetica'), size)
    c.save()
    c.translate(x, y)
    c.rotate(rot)
    outline = paint(WHITE, alpha, stroke=size * 0.18)
    c.drawString(s, 0, 0, font, outline)
    c.drawString(s, 0, 0, font, paint(color, alpha))
    c.restore()


def ease(x):
    """0→1→0 over one period, smooth at both ends."""
    return 0.5 - 0.5 * math.cos(TAU * x)


def blink_of(t, at=0.72, length=0.08):
    """1 when the eyes are open, dipping to 0 for a quick blink."""
    d = (t - at) % 1.0
    if d > length:
        return 1.0
    return abs(1 - 2 * d / length)


# --- the monkey ------------------------------------------------------------

EYE_X, EYE_Y = 46, -18


def draw_eyes(c, style, t, look=(0, 0)):
    lx, ly = look
    if style in ('open', 'wide', 'sad', 'lookup'):
        open_ = blink_of(t) if style != 'wide' else 1.0
        for side in (-1, 1):
            ex = side * EYE_X
            if style == 'wide':
                c.drawPath(oval(ex, EYE_Y, 27, 31), paint(WHITE))
                c.drawPath(oval(ex, EYE_Y, 27, 31), paint(INK, stroke=5))
                c.drawPath(oval(ex + lx, EYE_Y + ly, 11, 12), paint(INK))
                c.drawPath(circle(ex + lx + 4, EYE_Y + ly - 4, 3.5),
                           paint(WHITE))
                continue
            ry = max(2.5, 21 * open_)
            ox, oy = (lx, ly) if style != 'lookup' else (side * 3 + 4, -9)
            c.drawPath(oval(ex + ox, EYE_Y + oy, 16, ry), paint(INK))
            if open_ > 0.5:
                c.drawPath(circle(ex + ox + 6, EYE_Y + oy - 8, 5.5),
                           paint(WHITE))
                if style == 'sad':
                    c.drawPath(circle(ex + ox - 5, EYE_Y + oy + 6, 3),
                               paint(WHITE))
    elif style == 'happy':  # ^ ^
        for side in (-1, 1):
            arc(c, side * EYE_X, EYE_Y + 8, 17, 15, 200, 140, width=8)
    elif style == 'closed':  # sleeping, ∪ ∪
        for side in (-1, 1):
            arc(c, side * EYE_X, EYE_Y - 4, 16, 12, 20, 140, width=7)
    elif style == 'squeeze':  # > <
        for side in (-1, 1):
            p = skia.Path()
            ex = side * EYE_X
            p.moveTo(ex - side * 16, EYE_Y - 13)
            p.lineTo(ex + side * 12, EYE_Y)
            p.lineTo(ex - side * 16, EYE_Y + 13)
            c.drawPath(p, paint(INK, stroke=8))
    elif style == 'wink':
        c.drawPath(oval(-EYE_X, EYE_Y, 16, 21), paint(INK))
        c.drawPath(circle(-EYE_X + 6, EYE_Y - 8, 5.5), paint(WHITE))
        arc(c, EYE_X, EYE_Y + 8, 17, 15, 200, 140, width=8)
    elif style == 'heart':
        beat = 1 + 0.16 * ease(t * 2)
        for side in (-1, 1):
            h = heart(side * EYE_X, EYE_Y, 58 * beat)
            fill_stroke(c, h, RED, 4)
            c.drawPath(circle(side * EYE_X - 9, EYE_Y - 10, 5),
                       paint(WHITE, 220))


def draw_mouth(c, style, t, amount=1.0):
    if style == 'smile':
        p = skia.Path()
        p.moveTo(-34, 56)
        p.quadTo(0, 84, 34, 56)
        c.drawPath(p, paint(INK, stroke=7))
    elif style in ('grin', 'laugh'):
        h = (42 if style == 'grin' else 58) * amount
        w = 40 if style == 'grin' else 50
        p = skia.Path()
        p.moveTo(-w, 48)
        p.cubicTo(-w + 4, 48 + h * 1.3, w - 4, 48 + h * 1.3, w, 48)
        p.quadTo(0, 58, -w, 48)
        p.close()
        c.drawPath(p, paint(MOUTH))
        c.save()
        c.clipPath(p, doAntiAlias=True)
        c.drawPath(oval(0, 48 + h * 0.95, w * 0.62, h * 0.42), paint(TONGUE))
        c.drawPath(oval(0, 52, w * 0.85, 9), paint(WHITE))  # teeth
        c.restore()
        c.drawPath(p, paint(INK, stroke=6))
    elif style == 'o':
        r = 15 + 6 * amount
        p = oval(0, 66, r * 0.85, r)
        fill_stroke(c, p, MOUTH, 6)
    elif style == 'frown':
        p = skia.Path()
        p.moveTo(-28, 74)
        p.quadTo(0, 52, 28, 74)
        c.drawPath(p, paint(INK, stroke=7))
    elif style == 'wobble':  # upset, wavy
        p = skia.Path()
        p.moveTo(-32, 68)
        for i in range(1, 5):
            p.quadTo(-32 + i * 16 - 8, 68 + (8 if i % 2 else -8), -32 + i * 16,
                     68)
        c.drawPath(p, paint(INK, stroke=6))
    elif style == 'kiss':
        for dy in (-7, 7):
            arc(c, 6, 64 + dy, 10, 8, -90, 180, width=6)
    elif style == 'smirk':
        p = skia.Path()
        p.moveTo(-26, 64)
        p.quadTo(8, 80, 36, 54)
        c.drawPath(p, paint(INK, stroke=7))
    elif style == 'chew':
        open_ = 0.5 + 0.5 * math.sin(TAU * t * 3)
        p = oval(0, 64, 22, 4 + 12 * open_)
        fill_stroke(c, p, MOUTH, 6)
    elif style == 'flat':
        p = skia.Path()
        p.moveTo(-24, 66)
        p.lineTo(24, 66)
        c.drawPath(p, paint(INK, stroke=7))


def draw_brows(c, style):
    if style is None:
        return
    for side in (-1, 1):
        p = skia.Path()
        x = side * EYE_X
        if style == 'angry':
            p.moveTo(x + side * 24, EYE_Y - 44)
            p.lineTo(x - side * 18, EYE_Y - 30)
        elif style == 'sad':
            p.moveTo(x + side * 22, EYE_Y - 30)
            p.lineTo(x - side * 18, EYE_Y - 44)
        elif style == 'up':
            p.moveTo(x - 18, EYE_Y - 52)
            p.quadTo(x, EYE_Y - 62, x + 18, EYE_Y - 52)
        c.drawPath(p, paint(INK, stroke=8))


def draw_head(c, t, eyes='open', mouth='smile', brows=None, blush=False,
              look=(0, 0), mouth_amount=1.0, tint=0.0):
    # ears, behind the head
    for side in (-1, 1):
        fill_stroke(c, circle(side * 138, 8, 50), FUR, 7)
        c.drawPath(circle(side * 138, 8, 30), paint(SKIN_DARK))
    head = circle(0, 0, 140)
    tuft = skia.Path()
    tuft.moveTo(-34, -134)
    tuft.cubicTo(-30, -178, 4, -186, 8, -160)
    tuft.cubicTo(18, -184, 44, -170, 34, -132)
    fill_stroke(c, union(head, tuft), FUR, 7)
    if tint:
        c.drawPath(union(head, tuft), paint(RED, int(120 * tint)))
    face = union(circle(-EYE_X, -18, 58), circle(EYE_X, -18, 58),
                 oval(0, 52, 102, 70))
    fill_stroke(c, face, SKIN, 6)
    if blush:
        for side in (-1, 1):
            c.drawPath(oval(side * 80, 38, 17, 9), paint(BLUSH, 170))
    for side in (-1, 1):  # nostrils
        c.drawPath(oval(side * 11, 28, 5, 3.5), paint(FUR_DARK))
    draw_brows(c, brows)
    draw_eyes(c, eyes, t, look)
    draw_mouth(c, mouth, t, mouth_amount)


def hand(c, x, y, rot=0.0, kind='open', scale=1.0):
    """A little skin-coloured paw at (x, y); 'open', 'fist', or 'thumb'."""
    c.save()
    c.translate(x, y)
    c.rotate(rot)
    c.scale(scale, scale)
    if kind == 'open':
        fingers = [oval(-22 + i * 15, -34, 8, 18) for i in range(4)]
        thumb = oval(-36, 2, 17, 9)
        palm = oval(0, 0, 32, 30)
        fill_stroke(c, union(palm, thumb, *fingers), SKIN, 6)
    elif kind in ('fist', 'thumb'):
        fist = skia.Path()
        fist.addRRect(skia.RRect.MakeRectXY(
            skia.Rect.MakeLTRB(-30, -24, 30, 28), 18, 18))
        parts = [fist]
        if kind == 'thumb':
            th = skia.Path()
            th.addRRect(skia.RRect.MakeRectXY(
                skia.Rect.MakeLTRB(-26, -70, -4, -14), 11, 11))
            parts.append(th)
        fill_stroke(c, union(*parts), SKIN, 6)
        for i in range(3):  # knuckle lines
            p = skia.Path()
            p.moveTo(10, -12 + i * 14)
            p.lineTo(28, -12 + i * 14)
            c.drawPath(p, paint(INK, stroke=4))
    c.restore()


def bubble(c, x, y, w, h, t, dots=True, color=CYAN):
    body = skia.Path()
    body.addRRect(skia.RRect.MakeRectXY(
        skia.Rect.MakeLTRB(x - w / 2, y - h / 2, x + w / 2, y + h / 2),
        h * 0.42, h * 0.42))
    tail = skia.Path()
    tail.moveTo(x - w * 0.22, y + h / 2 - 4)
    tail.lineTo(x - w * 0.34, y + h / 2 + h * 0.34)
    tail.lineTo(x - w * 0.02, y + h / 2 - 4)
    tail.close()
    fill_stroke(c, union(body, tail), color, 6, CYAN_DARK)
    if dots:
        for i in range(3):
            lift = max(0.0, math.sin(TAU * (t - i * 0.14)))
            c.drawPath(circle(x + (i - 1) * w * 0.25, y - 10 * lift, h * 0.1),
                       paint(WHITE))


# --- the stickers ----------------------------------------------------------

def s_wave(c, t):
    bob = 5 * math.sin(TAU * t)
    c.translate(0, bob)
    draw_head(c, t, 'happy', 'grin', blush=True)
    hand(c, 150, 90, rot=-15 + 25 * math.sin(TAU * t * 2), kind='open')


def s_lol(c, t):
    shake = math.sin(TAU * t * 3)
    c.rotate(5 * shake)
    c.translate(0, 6 * abs(shake))
    draw_head(c, t, 'squeeze', 'laugh', mouth_amount=0.85 + 0.15 * abs(shake))
    for side in (-1, 1):  # tears flying off
        for k in range(2):
            ph = (t * 2 + k * 0.5) % 1.0
            x = side * (100 + 70 * ph)
            y = -30 - 50 * ph + 120 * ph * ph
            c.drawPath(drop(x, y, 24 * (1 - 0.4 * ph)),
                       paint(TEAR, int(255 * (1 - ph))))


def s_love(c, t):
    c.rotate(4 * math.sin(TAU * t))
    draw_head(c, t, 'heart', 'grin', blush=True)
    for k in range(3):
        ph = (t + k / 3) % 1.0
        x = -150 + k * 150 + 20 * math.sin(TAU * ph)
        y = -150 - 90 * ph
        fill_stroke(c, heart(x, y, 44 * (1 - 0.4 * ph)), PINK, 0)


def s_wink(c, t):
    c.rotate(6 * math.sin(TAU * t))
    wink = 'wink' if (t % 1.0) < 0.6 else 'open'
    draw_head(c, 0.0, wink, 'smirk', blush=True)
    s = 0.6 + 0.6 * ease(t)
    fill_stroke(c, star(118, -110, 34 * s, rot=40 * t), YELLOW, 5)


def s_sad(c, t):
    c.translate(0, 8 * ease(t))
    draw_head(c, 0.0, 'sad', 'wobble', brows='sad')
    for side in (-1, 1):
        ph = (t + (0.5 if side > 0 else 0)) % 1.0
        c.drawPath(drop(side * 48, 10 + 110 * ph, 13),
                   paint(TEAR, int(255 * min(1, 2.5 * (1 - ph)))))


def s_angry(c, t):
    shake = math.sin(TAU * t * 4)
    c.translate(5 * shake, 0)
    draw_head(c, 0.0, 'open', 'frown', brows='angry', tint=0.5 + 0.5 * ease(t))
    # the 💢 mark, throbbing at the temple
    s = 1 + 0.25 * ease(t * 2)
    c.save()
    c.translate(112, -104)
    c.scale(s, s)
    for k in range(4):
        c.save()
        c.rotate(45 + 90 * k)
        p = skia.Path()
        p.moveTo(-9, -30)
        p.quadTo(-9, -9, -30, -9)
        c.drawPath(p, paint(RED, stroke=10))
        c.restore()
    c.restore()


def s_thumbs(c, t):
    c.translate(-12, 0)
    draw_head(c, t, 'happy', 'grin', blush=True)
    lift = 10 * math.sin(TAU * t * 2)
    hand(c, 160, 110 - lift, rot=-8 + 6 * math.sin(TAU * t * 2),
         kind='thumb', scale=1.25)
    s = ease(t * 2)
    fill_stroke(c, star(200, -60, 22 * s + 4), YELLOW, 4)


def s_sleep(c, t):
    c.rotate(-8 + 5 * math.sin(TAU * t))
    c.translate(0, 6 * math.sin(TAU * t))
    draw_head(c, t, 'closed', 'o', mouth_amount=0.2 + 0.3 * ease(t))
    c.rotate(8)
    for k in range(3):
        ph = (t + k / 3) % 1.0
        a = int(255 * math.sin(math.pi * ph))
        text(c, 'z' if k % 2 else 'Z', 90 + 60 * ph, -110 - 90 * ph,
             46 + 20 * ph, CYAN_DARK, a, rot=-12)


def s_shock(c, t):
    shake = math.sin(TAU * t * 5)
    c.translate(4 * shake, 0)
    s = 1 + 0.05 * ease(t * 2)
    c.scale(s, s)
    draw_head(c, 0.0, 'wide', 'o', brows='up', mouth_amount=1.4)
    for side in (-1, 1):  # shock lines
        for i in range(3):
            a = math.radians(-130 + i * 25) if side < 0 else \
                math.radians(-50 - i * 25)
            r0 = 170 + 10 * ease(t * 2)
            p = skia.Path()
            p.moveTo(r0 * math.cos(a), r0 * math.sin(a))
            p.lineTo((r0 + 30) * math.cos(a), (r0 + 30) * math.sin(a))
            c.drawPath(p, paint(INK, stroke=7))


def s_party(c, t):
    colors = [PINK, YELLOW, CYAN, 0x86EFAC, 0xC4B5FD]
    for k in range(12):  # confetti behind the monkey, falling off the edge
        ph = (t + k * 0.37) % 1.0
        x = -220 + (k * 41) % 440
        y = -340 + 680 * ph
        c.save()
        c.translate(x, y)
        c.rotate(360 * ph * (1 if k % 2 else -1) + k * 30)
        c.drawRect(skia.Rect.MakeLTRB(-10, -5, 10, 5), paint(colors[k % 5]))
        c.restore()
    c.rotate(7 * math.sin(TAU * t))
    draw_head(c, t, 'happy', 'grin', blush=True)
    hat = skia.Path()  # party hat on the tuft
    hat.moveTo(-50, -122)
    hat.lineTo(30, -236)
    hat.lineTo(62, -110)
    hat.close()
    fill_stroke(c, hat, CYAN, 6)
    for i in range(3):
        p = skia.Path()
        p.moveTo(-34 + i * 24, -140 - i * 32)
        p.lineTo(-10 + i * 22, -134 - i * 34)
        c.drawPath(p, paint(YELLOW, stroke=9))
    fill_stroke(c, circle(30, -238, 15), YELLOW, 5)


def s_think(c, t):
    c.rotate(-6)
    draw_head(c, t, 'lookup', 'flat', brows=None)
    tap = 6 * math.sin(TAU * t * 2)
    hand(c, 30, 150 + tap, rot=-20, kind='fist', scale=0.95)
    for i in range(3):  # thought dots rising to a bubble
        on = ((t * 3) % 3) >= i
        dot = circle(120 + i * 28, -120 - i * 28, 9 + i * 5)
        c.drawPath(dot, paint(CYAN if on else WHITE))
        c.drawPath(dot, paint(CYAN_DARK, stroke=4))


def s_typing(c, t):
    c.translate(-30, 30)
    c.scale(0.86, 0.86)
    draw_head(c, t, 'lookup', 'smile', look=(4, -6))
    c.resetMatrix()
    c.translate(W / 2, W / 2)
    s = 1 + 0.04 * math.sin(TAU * t)
    c.scale(s, s)
    bubble(c, 120, -150, 170, 110, t)


def s_kiss(c, t):
    c.rotate(-5 + 5 * math.sin(TAU * t))
    draw_head(c, 0.0, 'wink', 'kiss', blush=True)
    ph = t % 1.0
    x = 70 + 130 * ph
    y = 60 - 150 * ph + 30 * math.sin(TAU * ph)
    fill_stroke(c, heart(x, y, 30 + 40 * ph), RED, 4)


def s_cool(c, t):
    draw_head(c, t, 'open', 'smirk')
    slide = min(1.0, t * 2.2)  # the glasses drop in, then rest
    slide = 1 - (1 - slide) ** 3
    y = -200 + (200 - 18) * slide
    glasses = union(
        skia.Path().addRRect(skia.RRect.MakeRectXY(
            skia.Rect.MakeLTRB(-98, y - 24, -8, y + 28), 20, 20)),
        skia.Path().addRRect(skia.RRect.MakeRectXY(
            skia.Rect.MakeLTRB(8, y - 24, 98, y + 28), 20, 20)),
        skia.Path().addRect(skia.Rect.MakeLTRB(-12, y - 16, 12, y - 6)),
        skia.Path().addRect(skia.Rect.MakeLTRB(-128, y - 16, -96, y - 8)),
        skia.Path().addRect(skia.Rect.MakeLTRB(96, y - 16, 128, y - 8)))
    c.drawPath(glasses, paint(0x111827))
    shine = skia.Path()
    shine.moveTo(-80, y - 10)
    shine.lineTo(-60, y - 10)
    c.drawPath(shine, paint(CYAN, stroke=6))
    shine2 = skia.Path()
    shine2.moveTo(26, y - 10)
    shine2.lineTo(46, y - 10)
    c.drawPath(shine2, paint(CYAN, stroke=6))
    if slide >= 1:
        s = ease((t - 0.45) / 0.55)
        fill_stroke(c, star(118, -64, 26 * s + 1), WHITE, 0)


def s_see_no_evil(c, t):
    peek = max(0.0, math.sin(TAU * t)) ** 2  # hands part now and then
    c.rotate(-4 * math.sin(TAU * t))
    draw_head(c, 0.0, 'happy', 'grin', blush=True, mouth_amount=0.7)
    for side in (-1, 1):
        hand(c, side * (48 + 26 * peek), -24 + 8 * peek,
             rot=side * (8 + 20 * peek), kind='open', scale=1.45)


def s_banana(c, t):
    c.rotate(3 * math.sin(TAU * t))
    draw_head(c, t, 'happy', 'chew', blush=True)
    bob = 8 * math.sin(TAU * t * 1.5)
    c.save()
    c.translate(96, 118 + bob)
    c.rotate(-40)
    c.scale(1.7, 1.7)
    b = skia.Path()  # a banana, half peeled
    b.moveTo(-60, 20)
    b.cubicTo(-40, 60, 40, 60, 62, 0)
    b.cubicTo(40, 30, -20, 30, -52, 4)
    b.close()
    fill_stroke(c, b, YELLOW, 6)
    tip = skia.Path()
    tip.addRRect(skia.RRect.MakeRectXY(
        skia.Rect.MakeLTRB(56, -8, 72, 4), 4, 4))
    fill_stroke(c, tip, 0x6B4F1D, 4)
    c.restore()
    hand(c, 158, 176 + bob, rot=-30, kind='fist', scale=0.95)


STICKERS = [
    ('wave', '👋', s_wave),
    ('lol', '😂', s_lol),
    ('love', '😍', s_love),
    ('wink', '😉', s_wink),
    ('sad', '😢', s_sad),
    ('angry', '😠', s_angry),
    ('thumbs', '👍', s_thumbs),
    ('sleep', '😴', s_sleep),
    ('shock', '😱', s_shock),
    ('party', '🥳', s_party),
    ('think', '🤔', s_think),
    ('typing', '💬', s_typing),
    ('kiss', '😘', s_kiss),
    ('cool', '😎', s_cool),
    ('see-no-evil', '🙈', s_see_no_evil),
    ('banana', '🍌', s_banana),
]


def render(fn, t):
    surface = skia.Surface(W, W)
    c = surface.getCanvas()
    c.clear(skia.ColorTRANSPARENT)
    c.translate(W / 2, W / 2 + 14)
    c.scale(0.82, 0.82)
    fn(c, t)
    art = surface.makeImageSnapshot()
    # The die-cut edge: the silhouette grown by a few pixels, in white, under
    # the art, so the monkey reads on a dark bubble and a light one alike.
    out = skia.Surface(W, W)
    oc = out.getCanvas()
    oc.clear(skia.ColorTRANSPARENT)
    # Skia's dilate is a square, which squares off small round shapes, so the
    # silhouette is stamped round a circle instead.
    edge = skia.Paint(AntiAlias=True)
    edge.setColorFilter(
        skia.ColorFilters.Blend(skia.ColorWHITE, skia.BlendMode.kSrcIn))
    for k in range(20):
        a = TAU * k / 20
        oc.drawImage(art, 8 * math.cos(a), 8 * math.sin(a),
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


def sheet(dest, frames_per=4):
    """A contact sheet of every sticker at a few moments, for eyeballing."""
    cell = OUT
    img = Image.new('RGBA', (cell * frames_per, cell * len(STICKERS)),
                    (38, 42, 50, 255))
    for i, (_, _, fn) in enumerate(STICKERS):
        for k in range(frames_per):
            img.alpha_composite(render(fn, k / frames_per), (k * cell, i * cell))
    img.save(dest)


def main(out_dir):
    pack_dir = os.path.join(out_dir, 'monkeyhub-monkeys')
    os.makedirs(pack_dir, exist_ok=True)
    stickers = []
    for i, (name, emoji, fn) in enumerate(STICKERS):
        frames = [render(fn, f / FRAMES) for f in range(FRAMES)]
        dest = os.path.join(pack_dir, f'{i:02d}-{name}.webp')
        frames[0].save(dest, save_all=True, append_images=frames[1:],
                       duration=FRAME_MS, loop=0, quality=80, method=6,
                       format='WEBP')
        frames[0].save(os.path.join(pack_dir, f'{i:02d}-{name}.png'))
        stickers.append({'file': os.path.relpath(dest, out_dir),
                         'order': i, 'emoji': emoji})
        print(f'  {name}: {os.path.getsize(dest) // 1024} KB', file=sys.stderr)
    manifest = [{
        'slug': 'monkeyhub-monkeys', 'title': 'MonkeyHub Monkeys', 'order': -1,
        'author': 'MonkeyHub', 'license': 'Original artwork',
        'sourceUrl': 'https://monkeyhub.walhallaa.com', 'format': 'image',
        'contentType': 'image/webp', 'width': OUT, 'height': OUT,
        'stickers': stickers,
    }]
    with open(os.path.join(out_dir, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--sheet':
        sheet(sys.argv[2])
    else:
        main(sys.argv[1] if len(sys.argv) > 1 else 'build/stickers/monkey')
