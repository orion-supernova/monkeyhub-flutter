#!/usr/bin/env python3
"""Generates Jungle Fist's sound effects and music in assets/audio/fight/.

Pure standard library (no numpy), deterministic: rerun to re-cut, the output is
byte-identical. Everything is synthesised from layers, the way a game sound
designer builds a hit: a pitch-dropping body thump, a noise crack for the
transient, a filtered noise tail, a touch of saturation, a short room.

SFX are mono 44.1 kHz (the engine pans them by where the hit landed), the music
loop is mono 22.05 kHz to keep the bundle small. Every file ends on a short
fade so nothing clicks.

Pieces:
  hit_light hit_heavy hit_counter   body thump + noise crack (+ metallic ring)
  block perfect_block               dull wooden clack / bright parry ping
  throw                             cloth grab rustle, then a slam
  whoosh_light whoosh_heavy dash roll   swept band-passed noise
  projectile_fire projectile_hit    energy charge-release / burst
  clash land super_flash ko         metallic clang / soft thud / charge+boom
  round_start round_fight           gong / punchy power-chord stinger
  victory defeat                    short jingles
  ui_tick ui_confirm                menu clicks
  music_rooftop                     32 s synthwave street loop, 120 BPM, A minor
"""

import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio', 'fight')
TAU = 2 * math.pi
SR = 44100
RNG = random.Random(20261105)


# ───────── primitives ─────────

def n_of(sec):
    return int(sec * SR)


def noise(sec):
    return [RNG.uniform(-1, 1) for _ in range(n_of(sec))]


def lp(x, fc, passes=2):
    """One-pole low-pass, [passes] times (12 dB/oct for 2)."""
    a = 1 - math.exp(-TAU * fc / SR)
    for _ in range(passes):
        y, s = [], 0.0
        for v in x:
            s += a * (v - s)
            y.append(s)
        x = y
    return x


def lp_sweep(x, f0, f1, passes=2, curve=1.0):
    """Low-pass whose cutoff glides f0 -> f1 (exponentially) over the buffer."""
    n = len(x)
    for _ in range(passes):
        y, s = [], 0.0
        for i, v in enumerate(x):
            t = (i / n) ** curve
            fc = f0 * (f1 / f0) ** t
            s += (1 - math.exp(-TAU * fc / SR)) * (v - s)
            y.append(s)
        x = y
    return x


def hp(x, fc, passes=1):
    for _ in range(passes):
        l = lp(x, fc, 1)
        x = [a - b for a, b in zip(x, l)]
    return x


def bp(x, lo, hi):
    return hp(lp(x, hi), lo)


def bp_sweep(x, lo0, lo1, hi0, hi1):
    return hp_sweep(lp_sweep(x, hi0, hi1), lo0, lo1)


def hp_sweep(x, f0, f1):
    l = lp_sweep(x, f0, f1, 1)
    return [a - b for a, b in zip(x, l)]


def env(n, attack=0.002, tau=0.05, hold=0.0):
    """Linear attack, optional hold, then exponential decay."""
    a, h = max(1, int(attack * SR)), int(hold * SR)
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i < a + h:
            out.append(1.0)
        else:
            out.append(math.exp(-(i - a - h) / (tau * SR)))
    return out


def mul(x, e):
    return [a * b for a, b in zip(x, e)]


def scale(x, g):
    return [v * g for v in x]


def add_into(dst, src, at=0.0, gain=1.0):
    o = int(at * SR)
    need = o + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[o + i] += v * gain


def silence(sec):
    return [0.0] * n_of(sec)


def sat(x, drive=2.0):
    k = math.tanh(drive)
    return [math.tanh(v * drive) / k for v in x]


def sine_sweep(sec, f0, f1, tau_pitch=None, phase=0.0):
    """Sine whose frequency glides f0 -> f1. With [tau_pitch] the glide is an
    exponential approach (fast then slow, like a kick drum); otherwise it is
    geometric across the whole buffer."""
    n = n_of(sec)
    out, ph = [], phase
    for i in range(n):
        t = i / SR
        if tau_pitch:
            f = f1 + (f0 - f1) * math.exp(-t / tau_pitch)
        else:
            f = f0 * (f1 / f0) ** (i / n)
        ph += TAU * f / SR
        out.append(math.sin(ph))
    return out


def saw_wave(freq, sec, detune=0.0):
    n = n_of(sec)
    out, ph = [], RNG.random()
    inc = freq * (1 + detune) / SR
    for _ in range(n):
        out.append(2 * ph - 1)
        ph += inc
        ph -= int(ph)
    return out


def square_wave(freq, sec, duty=0.5):
    n = n_of(sec)
    out, ph, inc = [], 0.0, freq / SR
    for _ in range(n):
        out.append(1.0 if ph < duty else -1.0)
        ph += inc
        ph -= int(ph)
    return out


def tri_wave(freq, sec):
    n = n_of(sec)
    out, ph, inc = [], 0.0, freq / SR
    for _ in range(n):
        out.append(4 * abs(ph - 0.5) - 1)
        ph += inc
        ph -= int(ph)
    return out


def partials(freq, sec, ratios, tau, amps=None):
    """Sum of decaying sine partials: bells, gongs, metal. Inharmonic ratios
    are what make it ring like metal instead of like a note."""
    n = n_of(sec)
    out = [0.0] * n
    for k, r in enumerate(ratios):
        a = amps[k] if amps else 1.0 / (1 + k * 0.6)
        t = tau / (1 + k * 0.45)
        w = TAU * freq * r / SR
        ph = RNG.random() * TAU
        for i in range(n):
            out[i] += a * math.sin(w * i + ph) * math.exp(-i / (t * SR))
    return out


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def reverb(x, wet=0.25, size=1.0, damp=3500, tail=0.0):
    """Schroeder room: four damped combs into two all-passes."""
    extra = int(tail * SR) if tail else int(0.35 * SR * size)
    src = x + [0.0] * extra
    n = len(src)
    out = [0.0] * n
    for ms, fb in ((29.7, 0.80), (37.1, 0.78), (41.1, 0.76), (43.7, 0.74)):
        d = max(1, int(ms * size * SR / 1000))
        buf = [0.0] * d
        a = 1 - math.exp(-TAU * damp / SR)
        lpv, idx = 0.0, 0
        for i in range(n):
            y = buf[idx]
            lpv += a * (y - lpv)
            buf[idx] = src[i] + lpv * fb
            idx += 1
            if idx == d:
                idx = 0
            out[i] += y * 0.25
    for ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = max(1, int(ms * SR / 1000))
        buf = [0.0] * d
        idx = 0
        for i in range(n):
            bufout = buf[idx]
            v = out[i] + bufout * g
            buf[idx] = v
            out[i] = bufout - v * g
            idx += 1
            if idx == d:
                idx = 0
    return [s * (1 - wet * 0.5) + o * wet * 2.2 for s, o in zip(src, out)]


def echo(x, delay, fb, mix):
    """Feedback delay: the dry signal plus [mix] of its repeats."""
    d = int(delay * SR)
    n = len(x) + d * 4
    dry = list(x) + [0.0] * (n - len(x))
    wet = [0.0] * n
    for i in range(d, n):
        wet[i] = (dry[i - d] + wet[i - d]) * fb
    return [a + b * mix for a, b in zip(dry, wet)]


def finish(x, peak=0.9, fade=0.006):
    """Peak-normalise and put a short fade on the tail."""
    m = max(1e-9, max(abs(v) for v in x))
    g = peak / m
    f = int(fade * SR)
    out = [v * g for v in x]
    for i in range(min(f, len(out))):
        out[-1 - i] *= i / f
    for i in range(min(24, len(out))):  # ~0.5 ms: no pop on a hard click onset
        out[i] *= i / 24
    return out


def trim_silence(x, thresh=0.0008):
    end = len(x)
    while end > 1 and abs(x[end - 1]) < thresh:
        end -= 1
    return x[:min(len(x), end + int(0.01 * SR))]


def write(name, samples, rate=None):
    rate = rate or SR
    path = os.path.join(OUT, name + '.wav')
    os.makedirs(OUT, exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    size = os.path.getsize(path)
    print('%-18s %6.2fs %8d bytes' % (name, len(samples) / rate, size))
    return size


# ───────── building blocks for hits ─────────

def thump(sec, f0, f1, tau_pitch, tau_amp, drive=1.6):
    n = n_of(sec)
    return sat(mul(sine_sweep(sec, f0, f1, tau_pitch), env(n, 0.001, tau_amp)), drive)


def crack(sec, lo, hi, tau, gain=1.0):
    n = n_of(sec)
    return scale(mul(bp(noise(sec), lo, hi), env(n, 0.0005, tau)), gain)


def click(gain=0.6):
    return [gain * (1 - i / 40) * RNG.uniform(-1, 1) for i in range(40)]


# ───────── effects ─────────

def hit_light():
    out = silence(0.22)
    add_into(out, thump(0.2, 260, 95, 0.02, 0.05), 0, 0.9)
    add_into(out, crack(0.12, 1800, 7000, 0.018), 0, 0.9)
    add_into(out, scale(lp(mul(noise(0.18), env(n_of(0.18), 0.001, 0.04)), 1200), 1.2), 0, 0.5)
    add_into(out, click(), 0, 0.5)
    return finish(sat(out, 1.8), 0.92)


def hit_heavy():
    out = silence(0.6)
    add_into(out, thump(0.55, 150, 36, 0.045, 0.14, 2.4), 0, 1.0)
    add_into(out, crack(0.2, 1200, 9000, 0.035), 0, 1.0)
    add_into(out, scale(lp(mul(noise(0.4), env(n_of(0.4), 0.001, 0.09)), 900), 1.4), 0, 0.7)
    add_into(out, thump(0.12, 520, 160, 0.015, 0.03), 0, 0.5)
    add_into(out, click(0.9), 0, 0.6)
    out = sat(out, 2.2)
    return finish(reverb(out, 0.12, 0.7), 0.95)


def hit_counter():
    out = hit_heavy()
    out = out + [0.0] * n_of(0.4)
    ring = partials(1180, 0.7, [1, 2.76, 5.4, 8.93], 0.28, [0.8, 0.5, 0.3, 0.18])
    add_into(out, scale(ring, 0.55), 0.005)
    add_into(out, crack(0.05, 5000, 14000, 0.012), 0, 0.5)
    zing = mul(sine_sweep(0.25, 3200, 2400), env(n_of(0.25), 0.002, 0.07))
    add_into(out, zing, 0.0, 0.18)
    return finish(reverb(out, 0.18, 0.9), 0.95)


def block():
    out = silence(0.2)
    add_into(out, thump(0.12, 190, 110, 0.02, 0.035, 1.5), 0, 0.8)
    add_into(out, partials(430, 0.14, [1, 1.58, 2.31], 0.03), 0, 0.5)
    add_into(out, crack(0.06, 900, 4500, 0.01), 0, 0.7)
    add_into(out, click(0.4), 0, 0.4)
    return finish(sat(out, 1.4), 0.8)


def perfect_block():
    out = silence(0.55)
    ping = partials(1760, 0.5, [1, 2.0, 3.0, 4.02], 0.2, [1.0, 0.45, 0.25, 0.12])
    add_into(out, ping, 0, 0.8)
    add_into(out, partials(2637, 0.4, [1, 2.0], 0.14), 0.012, 0.45)
    add_into(out, crack(0.04, 4000, 12000, 0.008), 0, 0.6)
    add_into(out, thump(0.1, 300, 130, 0.015, 0.03), 0, 0.5)
    shim = mul(sine_sweep(0.3, 1200, 5200), env(n_of(0.3), 0.01, 0.07))
    add_into(out, shim, 0, 0.12)
    out = echo(out, 0.09, 0.35, 0.35)
    return finish(reverb(out, 0.15, 0.6), 0.88)


def throw():
    out = silence(0.8)
    rustle = bp_sweep(noise(0.3), 400, 900, 1400, 3200)
    trem = [0.55 + 0.45 * math.sin(TAU * 17 * i / SR) for i in range(len(rustle))]
    add_into(out, mul(mul(rustle, trem), env(len(rustle), 0.03, 0.15, 0.08)), 0, 0.5)
    add_into(out, thump(0.08, 300, 150, 0.02, 0.03), 0.0, 0.4)
    t = 0.3
    add_into(out, thump(0.5, 130, 32, 0.05, 0.13, 2.4), t, 1.0)
    add_into(out, crack(0.18, 800, 8000, 0.04), t, 0.95)
    add_into(out, scale(lp(mul(noise(0.4), env(n_of(0.4), 0.001, 0.1)), 700), 1.3), t, 0.7)
    add_into(out, click(0.9), t, 0.5)
    return finish(reverb(sat(out, 2.0), 0.14, 0.8), 0.95)


def whoosh(sec, lo0, lo1, hi0, hi1, peak_at, gain_body=0.0, body=(0, 0)):
    n = n_of(sec)
    k = math.log(0.5) / math.log(peak_at)  # puts the loudest point at peak_at
    e = [math.sin(math.pi * (i / n) ** k) ** 2 for i in range(n)]
    x = mul(bp_sweep(noise(sec), lo0, lo1, hi0, hi1), e)
    if gain_body:
        add_into(x, mul(sine_sweep(sec, body[0], body[1]), e), 0, gain_body)
    return x


def whoosh_light():
    return finish(whoosh(0.22, 800, 2500, 2500, 7000, 0.42), 0.7, 0.02)


def whoosh_heavy():
    x = whoosh(0.4, 250, 1100, 1200, 4200, 0.45, 0.35, (120, 55))
    return finish(sat(x, 1.4), 0.8, 0.03)


def projectile_fire():
    out = silence(0.7)
    # Charge: a rising sine/saw whine, then the release crack and a falling zap.
    up = mul(sine_sweep(0.16, 220, 1400), env(n_of(0.16), 0.01, 0.2))
    add_into(out, up, 0, 0.4)
    t = 0.14
    zap = sat(mul(sine_sweep(0.45, 2000, 260, 0.09), env(n_of(0.45), 0.001, 0.14)), 2.0)
    fm = [math.sin(TAU * 90 * i / SR) for i in range(len(zap))]
    add_into(out, [z * (0.75 + 0.25 * f) for z, f in zip(zap, fm)], t, 0.8)
    add_into(out, crack(0.12, 2000, 10000, 0.02), t, 0.8)
    add_into(out, thump(0.3, 200, 60, 0.04, 0.08), t, 0.8)
    add_into(out, bp_sweep(mul(noise(0.4), env(n_of(0.4), 0.01, 0.12)), 600, 300, 6000, 1500), t, 0.5)
    return finish(reverb(out, 0.18, 0.8), 0.9)


def projectile_hit():
    out = silence(0.55)
    burst = lp_sweep(mul(noise(0.4), env(n_of(0.4), 0.001, 0.1)), 9000, 500, 2)
    add_into(out, burst, 0, 0.9)
    add_into(out, thump(0.35, 170, 48, 0.04, 0.09, 2.0), 0, 0.9)
    add_into(out, crack(0.1, 2500, 12000, 0.015), 0, 0.7)
    spark = mul(sine_sweep(0.3, 1500, 420, 0.1), env(n_of(0.3), 0.001, 0.08))
    add_into(out, spark, 0, 0.35)
    return finish(reverb(sat(out, 1.8), 0.16, 0.8), 0.92)


def clash():
    out = silence(0.7)
    for t, g, f in ((0.0, 1.0, 1450), (0.065, 0.7, 1750)):
        add_into(out, partials(f, 0.6, [1, 2.76, 5.4, 8.93, 13.3], 0.25, [0.8, 0.6, 0.4, 0.3, 0.2]), t, g)
        add_into(out, crack(0.07, 3000, 13000, 0.012), t, g * 0.8)
        add_into(out, thump(0.1, 340, 130, 0.015, 0.03), t, g * 0.6)
    return finish(reverb(sat(out, 1.5), 0.18, 0.8), 0.9)


def land():
    out = silence(0.2)
    add_into(out, thump(0.17, 120, 50, 0.03, 0.05, 1.3), 0, 0.9)
    add_into(out, scale(lp(mul(noise(0.12), env(n_of(0.12), 0.001, 0.025)), 800), 1.2), 0, 0.5)
    return finish(out, 0.7, 0.012)


def roll():
    out = silence(0.4)
    n = n_of(0.3)
    rustle = bp_sweep(noise(0.3), 350, 600, 1500, 2600)
    am = [0.5 + 0.5 * abs(math.sin(TAU * 7 * i / SR)) for i in range(n)]
    add_into(out, mul(mul(rustle, am), env(n, 0.02, 0.2, 0.05)), 0, 0.7)
    add_into(out, thump(0.1, 110, 55, 0.02, 0.04), 0.27, 0.6)
    return finish(out, 0.6, 0.015)


def dash():
    out = whoosh(0.22, 1000, 3000, 3000, 9000, 0.3)
    out = add_puff(out)
    return finish(out, 0.6, 0.015)


def add_puff(x):
    add_into(x, mul(lp(noise(0.06), 600), env(n_of(0.06), 0.001, 0.02)), 0, 0.5)
    return x


def super_flash():
    out = silence(1.9)
    charge = 0.72
    n = n_of(charge)
    # Rising saw+sine whine with a swell; noise riser underneath.
    f_a = [110 * (2200 / 110) ** ((i / n) ** 1.6) for i in range(n)]
    ph, whine = 0.0, []
    for i, f in enumerate(f_a):
        ph += f / SR
        ph -= int(ph)
        whine.append(0.6 * (2 * ph - 1) + 0.4 * math.sin(TAU * ph))
    swell = [(i / n) ** 2.2 for i in range(n)]
    whine = lp_sweep(whine, 400, 9000, 2)
    add_into(out, mul(whine, swell), 0, 0.5)
    rise = mul(bp_sweep(noise(charge), 300, 3000, 1500, 12000), swell)
    add_into(out, rise, 0, 0.45)
    # Impact
    t = charge
    add_into(out, thump(1.0, 120, 30, 0.07, 0.3, 2.6), t, 1.0)
    add_into(out, crack(0.3, 900, 11000, 0.06), t, 1.0)
    add_into(out, scale(lp(mul(noise(0.8), env(n_of(0.8), 0.001, 0.2)), 1100), 1.2), t, 0.6)
    add_into(out, partials(660, 1.0, [1, 2.76, 5.4, 8.93], 0.45), t, 0.35)
    return finish(reverb(sat(out, 2.0), 0.2, 1.0, tail=0.4), 0.95, 0.03)


def ko():
    out = silence(2.6)
    add_into(out, thump(1.6, 95, 26, 0.09, 0.4, 2.8), 0, 1.0)
    add_into(out, thump(0.3, 400, 90, 0.02, 0.06), 0, 0.7)
    add_into(out, crack(0.35, 700, 12000, 0.08), 0, 1.0)
    add_into(out, scale(lp(mul(noise(1.0), env(n_of(1.0), 0.001, 0.3)), 900), 1.4), 0, 0.7)
    add_into(out, click(1.0), 0, 0.6)
    # Low boom tail: a sub that keeps ringing, a slow metallic shimmer over it.
    add_into(out, mul(sine_sweep(1.8, 55, 38), env(n_of(1.8), 0.02, 0.7)), 0.02, 0.8)
    add_into(out, partials(320, 1.5, [1, 2.76, 5.4], 0.5), 0, 0.18)
    out = reverb(sat(out, 2.2), 0.28, 1.3, damp=2400, tail=1.0)
    return finish(trim_silence(out), 0.97, 0.05)


def round_start():
    # Gong: strike transient, inharmonic partials, a slow beating swell.
    out = silence(3.2)
    f0 = 98
    ratios = [1, 1.51, 2.0, 2.76, 3.72, 4.9, 6.3]
    amps = [1.0, 0.8, 0.7, 0.6, 0.45, 0.3, 0.2]
    add_into(out, partials(f0, 3.0, ratios, 1.4, amps), 0, 0.75)
    add_into(out, partials(f0 * 1.004, 3.0, ratios[:4], 1.2, amps[:4]), 0, 0.4)
    add_into(out, crack(0.25, 400, 6000, 0.05), 0, 0.7)
    add_into(out, thump(0.5, 140, 55, 0.04, 0.15, 1.8), 0, 0.5)
    sw = mul(bp(noise(2.6), 1200, 5500), env(n_of(2.6), 0.9, 0.7))
    add_into(out, sw, 0, 0.08)
    out = reverb(out, 0.25, 1.2, tail=0.8)
    return finish(trim_silence(out), 0.9, 0.08)


def power_chord(freqs, sec, tau, cut0, cut1):
    out = silence(sec)
    for f in freqs:
        for det in (-0.006, 0.0, 0.007):
            add_into(out, saw_wave(f, sec, det), 0, 1.0 / (len(freqs) * 3))
    out = lp_sweep(out, cut0, cut1, 2)
    return mul(out, env(len(out), 0.004, tau))


def round_fight():
    out = silence(1.1)
    add_into(out, thump(0.5, 160, 40, 0.04, 0.12, 2.2), 0, 1.0)
    add_into(out, crack(0.15, 1500, 10000, 0.03), 0, 0.9)
    chord = power_chord([midi(45), midi(52), midi(57), midi(64)], 0.9, 0.28, 6000, 700)
    add_into(out, sat(chord, 2.4), 0, 0.85)
    riser = mul(bp_sweep(noise(0.18), 800, 3000, 3000, 9000), env(n_of(0.18), 0.12, 0.05))
    add_into(out, riser, 0, 0.0)  # kept off: the stinger lands on the beat
    return finish(reverb(out, 0.14, 0.8), 0.95, 0.04)


def pluck(freq, sec, tau=0.18, cut0=7000, cut1=900, wave_=saw_wave, voices=2):
    x = silence(sec)
    for v in range(voices):
        det = (v - (voices - 1) / 2) * 0.008
        add_into(x, wave_(freq * (1 + det), sec), 0, 1.0 / voices)
    return mul(lp_sweep(x, cut0, cut1, 2, 0.5), env(n_of(sec), 0.003, tau))


def victory():
    out = silence(3.2)
    # G4 C5 E5 G5 | C6 with a held C major stack: a bright little fanfare.
    seq = [(67, 0.0), (72, 0.11), (76, 0.22), (79, 0.33), (76, 0.50), (79, 0.61), (84, 0.72)]
    for m, t in seq:
        add_into(out, pluck(midi(m), 0.5, 0.2, 9000, 2200, square_wave), t, 0.5)
        add_into(out, pluck(midi(m + 12), 0.4, 0.12, 9000, 3000, tri_wave), t, 0.2)
    t = 0.72
    for m in (60, 64, 67, 72, 76):
        add_into(out, pluck(midi(m), 1.8, 0.7, 8000, 1500, saw_wave, 3), t, 0.22)
    add_into(out, pluck(midi(36), 1.4, 0.5, 900, 300, saw_wave), t, 0.7)
    add_into(out, thump(0.4, 130, 45, 0.04, 0.1, 1.8), 0.0, 0.8)
    add_into(out, thump(0.5, 130, 45, 0.04, 0.12, 1.8), t, 0.9)
    add_into(out, crack(1.2, 5000, 14000, 0.4), t, 0.2)
    add_into(out, partials(midi(96), 1.2, [1, 2.76, 5.4], 0.4), t, 0.1)
    return finish(trim_silence(reverb(out, 0.2, 1.0, tail=0.8)), 0.92, 0.08)


def defeat():
    out = silence(3.0)
    # A, G, F, E falling, each sagging in pitch, heavy lowpass: a slow wah-wah.
    seq = [(57, 0.0, 0.5), (55, 0.45, 0.5), (53, 0.9, 0.55), (52, 1.4, 1.5)]
    for m, t, d in seq:
        f = midi(m)
        n = n_of(d)
        ph, x = 0.0, []
        for i in range(n):
            fi = f * (1 - 0.035 * (i / n) ** 1.5)
            ph += fi / SR
            ph -= int(ph)
            x.append(0.7 * (2 * ph - 1) + 0.3 * math.sin(TAU * ph * 2))
        x = lp_sweep(x, 2400, 380, 2)
        add_into(out, mul(x, env(n, 0.01, d * 0.5)), t, 0.6)
    add_into(out, thump(0.9, 90, 30, 0.1, 0.3, 2.0), 1.4, 0.8)
    add_into(out, pluck(midi(40), 1.5, 0.8, 600, 200, saw_wave), 1.4, 0.5)
    return finish(trim_silence(reverb(out, 0.24, 1.2, damp=2200, tail=0.8)), 0.88, 0.08)


def ui_tick():
    out = silence(0.06)
    add_into(out, mul(sine_sweep(0.05, 2200, 1400, 0.01), env(n_of(0.05), 0.0005, 0.012)), 0, 0.8)
    add_into(out, click(0.5), 0, 0.5)
    return finish(out, 0.5, 0.004)


def ui_confirm():
    out = silence(0.4)
    add_into(out, pluck(midi(76), 0.25, 0.07, 9000, 3500, tri_wave, 1), 0, 0.8)
    add_into(out, pluck(midi(81), 0.35, 0.12, 9000, 3500, tri_wave, 1), 0.075, 0.9)
    add_into(out, partials(midi(93), 0.3, [1, 2.0], 0.08), 0.075, 0.12)
    return finish(reverb(out, 0.1, 0.5), 0.6, 0.01)


# ───────── music ─────────

def music_rooftop():
    """16 bars at 120 BPM (32 s), A minor: Am F C G, four times. Kick, snare,
    hats, a rolling 8th-note bass, a plucked 16th arpeggio and a detuned pad.
    Everything but the kick is ducked by the kick (a faint sidechain) so it
    pumps the way synthwave does, and the loop wraps its own reverb tail so the
    seam is silent."""
    global SR
    SR = 22050
    bpm = 120
    beat = 60.0 / bpm
    bars = 16
    total = bars * 4 * beat
    N = n_of(total)
    tail = n_of(1.5)

    def stem():
        return [0.0] * (N + tail)

    drums, snare_s, bass, arp, pad = stem(), stem(), stem(), stem(), stem()
    kicks = []

    def put(dst, src, at, gain=1.0):
        o = int(at * SR)
        for i, v in enumerate(src):
            j = o + i
            if j >= len(dst):
                break
            dst[j] += v * gain

    kick = sat(mul(sine_sweep(0.32, 150, 46, 0.03), env(n_of(0.32), 0.001, 0.11)), 1.8)
    kick = [k + c for k, c in zip(kick, scale(crack(0.32, 1500, 6000, 0.006), 0.35))]
    snare = [a + b for a, b in zip(
        mul(bp(noise(0.3), 1600, 7000), env(n_of(0.3), 0.001, 0.07)),
        scale(mul(sine_sweep(0.3, 240, 170, 0.04), env(n_of(0.3), 0.001, 0.05)), 0.7))]
    hat = mul(hp(noise(0.08), 6500), env(n_of(0.08), 0.0005, 0.012))
    ohat = mul(hp(noise(0.3), 6000), env(n_of(0.3), 0.001, 0.07))

    # Chord roots (MIDI), one per bar group of four: Am F C G.
    roots = [45, 41, 36, 43]
    chords = [(57, 60, 64), (53, 57, 60), (55, 60, 64), (55, 59, 62)]
    arp_pat = [0, 1, 2, 1, 0, 1, 2, 1, 2, 1, 0, 1, 2, 1, 2, 1]

    for bar in range(bars):
        c = bar % 4
        t0 = bar * 4 * beat
        root = midi(roots[c])
        ch = chords[c]
        fill = (bar % 8 == 7)
        # drums
        for b in range(4):
            t = t0 + b * beat
            if b == 0 or b == 2:
                put(drums, kick, t, 0.95)
                kicks.append(t)
            if b in (1, 3):
                put(snare_s, snare, t, 0.8)
            if b == 1 and bar % 2 == 1:
                put(drums, kick, t + 0.75 * beat, 0.7)  # syncopated pickup
                kicks.append(t + 0.75 * beat)
            put(drums, hat, t, 0.30)
            put(drums, hat, t + 0.5 * beat, 0.20)
            if b % 2 == 1:
                put(drums, ohat, t + 0.5 * beat, 0.12)
        if fill:
            for k in range(4):
                put(snare_s, snare, t0 + 3 * beat + k * 0.25 * beat, 0.35 + 0.12 * k)
        # bass: 8ths on the root, octave pop on the "and" of 2 and 4
        for e in range(8):
            t = t0 + e * 0.5 * beat
            f = root * (2 if e in (3, 7) else 1)
            note = pluck(f, 0.5 * beat * 0.95, 0.16, 1100, 260, saw_wave, 2)
            put(bass, note, t, 0.55)
        # arp: 16ths over the chord, an octave up on the second half of a bar pair
        up = 2 if (bar % 4) >= 2 else 1
        for s in range(16):
            if bar < 4 and s % 2 == 1:
                continue  # sparse intro
            t = t0 + s * 0.25 * beat
            m = ch[arp_pat[s]] + 12 * up
            note = pluck(midi(m), 0.22, 0.09, 5500, 1400, saw_wave, 2)
            put(arp, note, t, 0.22)
        # pad: held chord, slow swell
        if bar >= 2:
            dur = 4 * beat
            padv = silence(dur)
            for m in ch:
                for det in (-0.007, 0.007):
                    add_into(padv, saw_wave(midi(m), dur, det), 0, 0.15)
            padv = lp(padv, 1400)
            sw = [min(1.0, i / n_of(0.5)) * min(1.0, (len(padv) - i) / n_of(0.3)) for i in range(len(padv))]
            put(pad, mul(padv, sw), t0, 0.4)

    # Sidechain: every non-kick stem ducks hard on a kick and recovers.
    duck = [1.0] * (N + tail)
    for kt in kicks:
        o = int(kt * SR)
        for i in range(n_of(0.22)):
            j = o + i
            if j >= len(duck):
                break
            d = 1 - 0.55 * math.exp(-i / (0.07 * SR))
            if d < duck[j]:
                duck[j] = d

    # Reverb sends: gated-ish snare room and a wide-ish arp.
    snare_s = reverb(snare_s, 0.3, 0.9, tail=0.5)
    arp = reverb(echo(arp, 0.75 * beat, 0.35, 0.3), 0.18, 1.0, tail=0.8)

    n_all = max(len(drums), len(snare_s), len(arp))

    def at(a, i):
        return a[i] if i < len(a) else 0.0

    mix = []
    for i in range(n_all):
        dk = duck[i] if i < len(duck) else 1.0
        mix.append(at(drums, i) + at(snare_s, i) * 0.9
                   + (at(bass, i) * 1.0 + at(pad, i) * 0.9 + at(arp, i) * 1.0) * dk)
    mix = sat(mix, 1.15)
    # Fold the tail over the start so the loop closes on its own reverb.
    body = mix[:N]
    for i, v in enumerate(mix[N:]):
        body[i % N] += v
    # Peak ~ -9 dBFS: it sits under the effects.
    m = max(abs(v) for v in body)
    body = [v * (0.36 / m) for v in body]
    # Equal-power micro-fades inside the loop point are NOT used: the wrap is
    # continuous by construction.
    return body, 22050


EFFECTS = [
    ('hit_light', hit_light), ('hit_heavy', hit_heavy), ('hit_counter', hit_counter),
    ('block', block), ('perfect_block', perfect_block), ('throw', throw),
    ('whoosh_light', whoosh_light), ('whoosh_heavy', whoosh_heavy),
    ('projectile_fire', projectile_fire), ('projectile_hit', projectile_hit),
    ('clash', clash), ('land', land), ('roll', roll), ('dash', dash),
    ('super_flash', super_flash), ('ko', ko), ('round_start', round_start),
    ('round_fight', round_fight), ('victory', victory), ('defeat', defeat),
    ('ui_tick', ui_tick), ('ui_confirm', ui_confirm),
]


def main():
    global SR
    total = 0
    for name, fn in EFFECTS:
        SR = 44100
        total += write(name, fn())
    body, rate = music_rooftop()
    SR = rate
    total += write('music_rooftop', body, rate)
    print('total', total, 'bytes (%.2f MB)' % (total / 1e6))


if __name__ == '__main__':
    main()
