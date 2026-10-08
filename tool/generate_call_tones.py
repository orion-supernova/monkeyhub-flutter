#!/usr/bin/env python3
"""Generates the call tones in assets/audio/. Stdlib only; rerun to re-cut.

ringback.wav  The caller's "the other phone is ringing" tone: the plain
              European / ITU-T E.180 cadence everyone knows, 425 Hz,
              1 s on, 4 s off. One 5 s cycle, starting on the tone, so a
              looped player reads as the real thing from the first beat.
connected.wav The caller's "they picked up": two soft rising notes
              (G5 then C6), plucked, a quarter of a second of sound.
"""

import math
import os
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def write(name, rate, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767))
            for s in samples))
    print(path, os.path.getsize(path), 'bytes')


def ringback():
    rate = 16000
    on, period, fade, amp, hz = 1.0, 5.0, 0.012, 0.34, 425.0
    out = []
    for i in range(int(rate * period)):
        t = i / rate
        if t >= on:
            out.append(0.0)
            continue
        # Raised-cosine edges: a hard-gated sine clicks at both ends.
        env = 1.0
        if t < fade:
            env = 0.5 - 0.5 * math.cos(math.pi * t / fade)
        elif t > on - fade:
            env = 0.5 - 0.5 * math.cos(math.pi * (on - t) / fade)
        out.append(amp * env * math.sin(2 * math.pi * hz * t))
    write('ringback.wav', rate, out)


def connected():
    rate = 44100
    length = 0.42
    # (start s, Hz, decay time constant s)
    notes = [(0.0, 783.99, 0.075), (0.085, 1046.50, 0.12)]
    out = []
    for i in range(int(rate * length)):
        t = i / rate
        s = 0.0
        for start, hz, tau in notes:
            u = t - start
            if u < 0:
                continue
            attack = min(1.0, u / 0.004)
            env = attack * math.exp(-u / tau)
            # A touch of the octave for warmth; a bare sine sounds like a test
            # signal.
            s += env * (math.sin(2 * math.pi * hz * u)
                        + 0.18 * math.sin(4 * math.pi * hz * u))
        # Last 20 ms fade to exact silence.
        tail = length - t
        if tail < 0.02:
            s *= tail / 0.02
        out.append(0.36 * s)
    write('connected.wav', rate, out)


if __name__ == '__main__':
    ringback()
    connected()
