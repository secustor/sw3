#!/usr/bin/env python3
"""Generate the station chatter radio cue mods/traffic/Data/SOUND/trf_squelch.wav (design/station-chatter-spec.md 6.5).

Run with: python3 -I gen_squelch.py [--write | --check] [--out PATH]
The cue is a short radio squelch: a 5 ms click of unfiltered noise falling linearly from full scale, then noise
band-limited by a one-pole high-pass (800 Hz) and a one-pole low-pass (3,000 Hz) under an exponential decay that reaches
-60 dB 200 ms after the click, a 10 ms linear fade at the end; 0.25 s in all, the peak normalised to 0.7 of full scale,
22,050 Hz mono 16-bit PCM (44-byte RIFF header, 11,068 bytes). The noise source is a linear congruential generator with a
fixed seed, so every run writes the same bytes. Without an option it prints the length, the peak and the size.
--write writes the file; --check builds it in memory and exits 1 when the file is missing or its bytes differ.
Nothing outside the repo is read or written.
"""
import argparse
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Data", "SOUND", "trf_squelch.wav")
RATE = 22050
TOTAL = 0.25          # seconds
CLICK = 0.005         # seconds of the click
DECAY = 0.200         # seconds from the click's end to -60 dB
FADE = 0.010          # seconds of the closing fade
HP_HZ, LP_HZ = 800.0, 3000.0
PEAK = 0.7
SEED = 0x5357


def noise(n, seed=SEED):
    """n values in -1..1 from the 31-bit LCG x = (1103515245 x + 12345) mod 2^31."""
    x, out = seed, []
    for _ in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        out.append(x / 1073741823.5 - 1.0)
    return out


def samples():
    n = int(TOTAL * RATE)
    nc = int(CLICK * RATE)
    src = noise(n)
    # Band limit: one-pole high-pass, then one-pole low-pass.
    dt = 1.0 / RATE
    rc = 1.0 / (2 * math.pi * HP_HZ)
    b = rc / (rc + dt)
    a = 1.0 - math.exp(-2 * math.pi * LP_HZ / RATE)
    hp, lp, xp, band = 0.0, 0.0, 0.0, []
    for x in src:
        hp = b * (hp + x - xp)
        xp = x
        lp += a * (hp - lp)
        band.append(lp)
    top = max(abs(v) for v in band[nc:]) or 1.0
    k = math.log(1000.0) / (DECAY * RATE)     # -60 dB after DECAY seconds
    nf = int(FADE * RATE)
    out = []
    for i in range(n):
        if i < nc:
            v = src[i] * (1.0 - i / float(nc))
        else:
            v = band[i] / top * math.exp(-k * (i - nc))
        if i >= n - nf:
            v *= (n - 1 - i) / float(nf)
        out.append(v)
    m = max(abs(v) for v in out) or 1.0
    return [int(round(v / m * PEAK * 32767)) for v in out]


def wav_bytes(s):
    data = struct.pack("<%dh" % len(s), *s)
    hdr = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(data), b"WAVE", b"fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16,
                      b"data", len(data))
    return hdr + data


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--write", action="store_true", help="write the file")
    ap.add_argument("--check", action="store_true", help="exit 1 when the file differs")
    ap.add_argument("--out", default=OUT, help="output path (default Data/SOUND/trf_squelch.wav)")
    a = ap.parse_args()
    s = samples()
    b = wav_bytes(s)
    path = os.path.normpath(a.out)
    print("squelch: %d samples (%.3f s) at %d Hz, peak %d of 32767, %d bytes" % (len(s), len(s) / float(RATE), RATE,
                                                                                    max(abs(v) for v in s), len(b)))
    if a.check:
        try:
            with open(path, "rb") as f:
                old = f.read()
        except OSError:
            print("squelch: %s missing" % path)
            return 1
        if old != b:
            print("squelch: %s differs (run --write)" % path)
            return 1
        print("squelch: %s up to date" % path)
        return 0
    if a.write:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(b)
        print("squelch: wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
