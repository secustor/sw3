#!/usr/bin/env python3
"""Station chatter voice clips mods/traffic/Data/SOUND/trf_voice/ (design/station-chatter-spec.md 6.5): per line key
the designator clips <key>_<tag>.wav (tag ftu, triada, uss, inoco: the call sign's designator spoken, the flight number
text-only; rchreqc for the three corporations only), 71 files, and the generic <key>.wav (no designator; trf_chatter's
fallback for an unknown one), 18 files.

Check the shipped set (stdlib only, no Piper needed):
  python3 -I mods/traffic/tools/gen_voice.py [--check]
Without an option it prints the table of the shipped files (speaker, spoken text, length, peak, RMS, bytes).
--check exits 1 when a file is missing, an extra file is in trf_voice/ (dotfiles are skipped), a file is not in or
differs (sha256, size) from the manifest tools/gen_voice.sha256, a header is not 22,050 Hz mono 16-bit PCM, a peak is
not -3 dBFS, a length is outside 1.5..4.5 s, or the set is 14 MB or more.

Re-render (needs Piper; the venv and the models are scratch, never shipped):
  python3 -m venv .work/voice/venv && .work/voice/venv/bin/pip install piper-tts==1.8.0   # onnxruntime 1.31.1
  U=.work/untrusted/voice
  .work/voice/venv/bin/python -I mods/traffic/tools/gen_voice.py --render \\
    --trader $U/en_US-norman-medium/en_US-norman-medium.onnx \\
    --control $U/en_GB-cori-medium/en_GB-cori-medium.onnx [--write | --check]
--render alone renders in memory and prints the table; --render --write writes the wav files and the manifest;
--render --check renders and exits 1 when any shipped file differs from the new render (runs are byte identical).
All 89 clips take about 2.5 minutes. Clip i of clips() uses seed SEED + i; the generic clips come first, so they keep
the bytes of their first render.
Models (https://huggingface.co/rhasspy/piper-voices, each .onnx with its .onnx.json beside it), md5:
  en_US-norman-medium.onnx 829cea515dc724d694b83b71e8083f9f, .onnx.json 975830d6f230f6eccf657d265de99eba (trader)
  en_GB-cori-medium.onnx   f143307611eccea9d976235d0895f57c, .onnx.json 12b1dc45d8919f3475cf296d5f16a4c6 (control)
Both voices: dataset LibriVox, "License: public domain" (model cards; design/mod-research/station-chatter-data.md 7).

Chain per clip (22,050 Hz mono 16-bit PCM):
 1. Piper renders each sentence (fixed onnxruntime seed, the voice loaded fresh per clip). Each sentence is trimmed of
    silence (40 dB under its peak), internal pauses over 0.15 s are shortened to 0.15 s, sentences are joined with a
    short gap. A phrase longer than its clip's target (3.5 s generic, 3.8 s designator clips, less the fixed parts) is
    rendered again faster (length_scale down to 0.8; at 0.8 a clip may end up to the 4.5 s hard limit).
 2. Radio: band-pass 300 to 3,000 Hz (two RBJ biquad high-pass and two low-pass stages), RMS -18 dBFS, a compressor
    (3:1 above -24 dBFS, 5 ms attack, 60 ms release) with make-up to RMS -18 dBFS, a tanh soft clip at -6 dBFS.
 3. Overdrive: a soft knee (linear to half the -6 dBFS ceiling, tanh above it) after a drive gain found by bisection so
    the voice RMS rises 3 dB, then one more 300 Hz high-pass and 3,000 Hz low-pass for the new harmonics and the tanh
    clip at -6 dBFS again for the filters' overshoot.
 4. Dropouts: clips with at least 2.0 s of voice get one, at least 2.8 s two: 20 to 40 ms at -12 dB with 3 ms ramps,
    placed by the LCG away from the first and last 0.3 s.
 5. Assembly: 50 ms lead-in silence, gen_squelch's 5 ms click, the voice over a noise bed at -40 dBFS RMS (gen_squelch's
    LCG through its one-pole 800 Hz high-pass and 3,000 Hz low-pass), the band-limited 150 ms squelch tail, 30 ms
    trailing silence; short phrases get open carrier before and after the voice up to MIN_LEN.
 6. Crackle: 2 to 6 pops per clip at LCG times inside the carrier, each 1 to 3 ms of noise through a one-pole 1,500 Hz
    high-pass and 5,000 Hz low-pass under a linear decay, 0.4 to 0.8 of the voice peak.
 7. Every file normalised to the same peak, -3 dBFS.
Nothing outside the repo is read or written; the model paths are arguments.
"""
import argparse
import hashlib
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "Data", "SOUND", "trf_voice"))
MANIFEST = os.path.join(HERE, "gen_voice.sha256")
RATE = 22050
SEED = 0x5357                 # gen_squelch's seed; clip i uses SEED + i for its noise and the TTS
LEAD, TRAIL = 0.050, 0.030    # seconds of silence before the click and after the tail
CLICK, TAIL, FADE = 0.005, 0.150, 0.010
MIN_LEN, MAX_LEN, HARD_MAX = 1.5, 3.5, 4.5   # target length of a clip in seconds (generic clips)
DES_MAX = 3.8                # target length of a designator clip
PEAK_DB = -3.0
RMS_DB = -18.0
BED_DB = -40.0
CLIP_DB = -6.0
DRIVE_DB = 3.0               # overdrive: voice RMS rise
DROP_DB = -12.0
TRIM_REL_DB = -40.0          # trim and pause threshold relative to each sentence's peak
PAUSE_MAX = 0.15             # internal pauses longer than this are shortened to it
SET_MAX = 14000000           # bytes of the whole set

# Generic clips <key>.wav: (key, speaker, spoken text). Speaker per trf_chatter.script TRF_RcK(): cs/as "t" trader, "c"
# control. The text is the fixed phraseology of each line (spec 7); call sign, bay, cargo and destination stay
# text-only: a leading "Control" stands in for the station, "Roger" or nothing for the call sign, "the bay" for
# "bay $3", "cargo" for the cargo. The sign-off is joined with a comma (the text has ". Over and out."): Piper renders a
# separate "Over and out." sentence after another one with a long tail (2.35 s instead of 1.15 s), which pushed both out
# clips over 4.5 s.
PHRASES = [
    ("rchreq1", "trader", "Control, inbound with cargo, request docking."),
    ("rchreq2", "trader", "Control, at the outer marker, request docking clearance."),
    ("rchreqc", "trader", "Control, heavy, full load, request docking."),
    ("rchreqa1", "control", "Roger, cleared to dock, follow the beacon."),
    ("rchreqa2", "control", "Cleared to dock, reduce speed at the marker."),
    ("rchhold1", "control", "Hold position, bay occupied, expect delay."),
    ("rchhold2", "control", "Standby. Traffic in the bay, hold at the outer marker."),
    ("rchholda", "trader", "Wilco, holding."),
    ("rchgo1", "control", "The bay is now clear, cleared to dock."),
    ("rchgo2", "control", "You're number one, cleared to dock."),
    ("rchgoa1", "trader", "Cleared to dock."),
    ("rchgoa2", "trader", "Roger, on our way in."),
    ("rchin1", "trader", "Control, docked, clamps on."),
    ("rchin2", "trader", "Control, secured in the bay, shutting down."),
    ("rchout1", "trader", "Control, clear of the bay, request departure."),
    ("rchout2", "trader", "Control, undocking, ready to depart."),
    ("rchouta1", "control", "Departure lane clear, cleared to depart, over and out."),
    ("rchouta2", "control", "Roger, frequency change approved, over and out."),
]

# Per voice: Piper length_scale (above 1 slower), sentence gap in seconds.
VOICE = {
    "trader": {"length": 1.05, "gap": 0.16},
    "control": {"length": 0.92, "gap": 0.10},
}

# Designator clips <key>_<tag>.wav (spec 6.5, owner decision 15): the same lines with the call sign's designator spoken
# where the text has the call sign ({d}); the flight number stays text-only. A trader line names it after the addressee
# ("Control, FTU, ..."), a control line opens with it; "Roger" and "Wilco" stay where the text has them. Tags as
# trf_chatter's TRF_RcFacTag, then the spoken form: Piper (espeak-ng) reads "FTU" and "USS" as letters ("ef tee you",
# "you ess ess") and "InoCo" as "Ino Co"; "F T U" or "U S S" only add a pause per letter. A carrier's call sign ends in
# "heavy"; an independent's never. rchreqc (carrier request) exists for the corporations only.
DES = [("ftu", "FTU"), ("triada", "Triada heavy"), ("uss", "USS heavy"), ("inoco", "InoCo heavy")]
CORP = ("triada", "uss", "inoco")
DPHRASES = [
    ("rchreq1", "Control, {d}, inbound with cargo, request docking."),
    ("rchreq2", "Control, {d}, at the outer marker, request docking clearance."),
    ("rchreqc", "Control, {d}, full load, request docking."),
    ("rchreqa1", "{d}, cleared to dock, follow the beacon."),
    ("rchreqa2", "{d}, cleared to dock, reduce speed at the marker."),
    ("rchhold1", "{d}, hold position, bay occupied, expect delay."),
    ("rchhold2", "{d}, standby. Traffic in the bay, hold at the outer marker."),
    ("rchholda", "Wilco, holding, {d}."),
    ("rchgo1", "{d}, the bay is now clear, cleared to dock."),
    ("rchgo2", "{d}, number one, cleared to dock."),
    ("rchgoa1", "Cleared to dock, {d}."),
    ("rchgoa2", "Roger, on our way in, {d}."),
    ("rchin1", "Control, {d}, docked, clamps on."),
    ("rchin2", "Control, {d}, secured in the bay, shutting down."),
    ("rchout1", "Control, {d}, clear of the bay, request departure."),
    ("rchout2", "Control, {d}, undocking, ready to depart."),
    ("rchouta1", "{d}, departure lane clear, cleared to depart, over and out."),
    ("rchouta2", "{d}, roger, frequency change approved, over and out."),
]


def clips():
    """[(name, key, speaker, spoken text, target length s)]: the 18 generic clips first (clip index = seed offset, so
    their bytes stay those of the render before the designator clips existed), then per key the designator clips in
    DES order."""
    spk = dict((k, sp) for k, sp, _ in PHRASES)
    out = [(k + ".wav", k, sp, t, MAX_LEN) for k, sp, t in PHRASES]
    for k, t in DPHRASES:
        for tag, say in DES:
            if k == "rchreqc" and tag not in CORP:
                continue
            out.append(("%s_%s.wav" % (k, tag), k, spk[k], t.replace("{d}", say), DES_MAX))
    return out


def speech_max(target):
    """Seconds of speech that fit a clip of target seconds."""
    return target - (LEAD + CLICK + TAIL + TRAIL) - 0.02


def db(x):
    return 10.0 ** (x / 20.0)


def lcg(seed):
    """The 31-bit LCG x = (1103515245 x + 12345) mod 2^31 of gen_squelch, as a generator of raw states."""
    x = seed
    while True:
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        yield x


def noise(n, seed):
    """n values in -1..1 from the LCG (as gen_squelch)."""
    g, out = lcg(seed), []
    for _ in range(n):
        out.append(next(g) / 1073741823.5 - 1.0)
    return out


def onepole_band(src, hp_hz=800.0, lp_hz=3000.0):
    """gen_squelch's band limit: one-pole high-pass, then one-pole low-pass."""
    dt = 1.0 / RATE
    rc = 1.0 / (2 * math.pi * hp_hz)
    b = rc / (rc + dt)
    a = 1.0 - math.exp(-2 * math.pi * lp_hz / RATE)
    hp, lp, xp, out = 0.0, 0.0, 0.0, []
    for x in src:
        hp = b * (hp + x - xp)
        xp = x
        lp += a * (hp - lp)
        out.append(lp)
    return out


def biquad(src, kind, f0, q=0.7071):
    """RBJ cookbook high-pass or low-pass, direct form I."""
    w = 2 * math.pi * f0 / RATE
    cw, al = math.cos(w), math.sin(w) / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    else:
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in src:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def rms(s):
    return math.sqrt(sum(v * v for v in s) / len(s)) if s else 0.0


def trim(s, pad=0.015):
    """Cut leading and trailing 10 ms windows whose RMS is below the peak plus TRIM_REL_DB, keep pad seconds, and
    shorten every internal run of such windows longer than PAUSE_MAX to PAUSE_MAX (the middle is cut out)."""
    if not s:
        return []
    w = int(0.010 * RATE)
    thr = max(abs(v) for v in s) * db(TRIM_REL_DB)
    loud = [rms(s[i:i + w]) > thr for i in range(0, len(s), w)]
    act = [k for k, q in enumerate(loud) if q]
    if not act:
        return []
    p = int(pad * RATE)
    keep = int(PAUSE_MAX / 0.010)
    out, k = [], act[0]
    while k <= act[-1]:
        if loud[k]:
            out += s[k * w:(k + 1) * w]
            k += 1
            continue
        j = k
        while not loud[j]:
            j += 1
        n = j - k
        if n > keep:
            out += s[k * w:(k + keep // 2) * w] + s[(j - (keep - keep // 2)) * w:j * w]
        else:
            out += s[k * w:j * w]
        k = j
    return s[max(0, act[0] * w - p):act[0] * w] + out + s[(act[-1] + 1) * w:(act[-1] + 1) * w + p]


def resample(s, src_rate):
    if src_rate == RATE:
        return s
    n = int(len(s) * RATE / float(src_rate))
    out = []
    for i in range(n):
        t = i * src_rate / float(RATE)
        j = int(t)
        f = t - j
        a = s[j] if j < len(s) else 0.0
        b = s[j + 1] if j + 1 < len(s) else a
        out.append(a + (b - a) * f)
    return out


def tts(model, text, seed, length):
    """Piper sentences of text as floats at RATE, trimmed; the voice is loaded fresh with a fixed seed."""
    import onnxruntime as ort
    from piper import PiperVoice, SynthesisConfig
    ort.set_seed(seed)
    v = PiperVoice.load(model)
    cfg = SynthesisConfig(length_scale=length, normalize_audio=False)
    parts = []
    for c in v.synthesize(text, cfg):
        raw = c.audio_int16_bytes
        a = struct.unpack("<%dh" % (len(raw) // 2), raw)
        parts.append(resample([x / 32768.0 for x in a], c.sample_rate))
    return [trim(p) for p in parts if p]


def speech(model, spk, text, seed, smax):
    """The joined speech, rendered faster when longer than smax seconds; returns (samples, length_scale)."""
    length = VOICE[spk]["length"]
    gap = [0.0] * int(VOICE[spk]["gap"] * RATE)
    while True:
        parts = tts(model, text, seed, length)
        s = []
        for k, p in enumerate(parts):
            s += (gap if k else []) + p
        if len(s) / float(RATE) <= smax or length <= 0.8:
            return s, length
        length = round(max(0.8, length * smax * RATE / len(s) - 0.01), 3)


def compress(s):
    """Feed-forward compressor on a peak envelope: 3:1 above -24 dBFS, 5 ms attack, 60 ms release."""
    att = math.exp(-1.0 / (0.005 * RATE))
    rel = math.exp(-1.0 / (0.060 * RATE))
    thr, ratio, env, out = db(-24.0), 3.0, 0.0, []
    for x in s:
        a = abs(x)
        env = att * env + (1 - att) * a if a > env else rel * env + (1 - rel) * a
        g = (env / thr) ** (1.0 / ratio - 1.0) if env > thr else 1.0
        out.append(x * g)
    return out


def radio(s):
    """Band-pass 300-3,000 Hz, RMS -18 dBFS, compressor, make-up, soft clip at CLIP_DB."""
    for kind, f in (("hp", 300.0), ("hp", 300.0), ("lp", 3000.0), ("lp", 3000.0)):
        s = biquad(s, kind, f)
    k = db(RMS_DB) / (rms(s) or 1.0)
    s = compress([v * k for v in s])
    k = db(RMS_DB) / (rms(s) or 1.0)
    s = [v * k for v in s]
    c = db(CLIP_DB)
    return [c * math.tanh(v / c) for v in s]


def knee(x, c):
    """Soft knee: linear up to c/2, then tanh towards the ceiling c (slope 1 at the knee)."""
    t = 0.5 * c
    a = abs(x)
    if a <= t:
        return x
    y = t + (c - t) * math.tanh((a - t) / (c - t))
    return y if x > 0 else -y


def overdrive(s):
    """Radio overdrive: the drive gain g (bisection, 24 steps) for which the knee output's RMS is DRIVE_DB above the
    input's, then a 300 Hz high-pass, a 3,000 Hz low-pass and the tanh clip at the ceiling again (the filters overshoot).
    Returns (samples, g)."""
    c = db(CLIP_DB)
    r0 = rms(s) or 1.0
    want = r0 * db(DRIVE_DB)
    lo, hi = 1.0, 64.0
    for _ in range(24):
        g = 0.5 * (lo + hi)
        if rms([knee(v * g, c) for v in s]) < want:
            lo = g
        else:
            hi = g
    g = 0.5 * (lo + hi)
    out = [knee(v * g, c) for v in s]
    out = biquad(biquad(out, "hp", 300.0), "lp", 3000.0)
    return [c * math.tanh(v / c) for v in out], g


def dropouts(s, gen):
    """One (voice >= 2.0 s) or two (>= 2.8 s) dropouts of 20-40 ms at DROP_DB with 3 ms ramps, at least 0.3 s from both
    ends; returns the list of (start s, length s)."""
    secs = len(s) / float(RATE)
    n = 2 if secs >= 2.8 else 1 if secs >= 2.0 else 0
    marks = []
    lo, hi = int(0.3 * RATE), len(s) - int(0.3 * RATE)
    ramp = int(0.003 * RATE)
    k = db(DROP_DB)
    for i in range(n):
        span = (hi - lo) // n
        ln = int((0.020 + (next(gen) % 21) / 1000.0) * RATE)
        st = lo + i * span + next(gen) % max(1, span - ln)
        for j in range(ln):
            e = min(1.0, j / float(ramp), (ln - 1 - j) / float(ramp))
            s[st + j] *= 1.0 - (1.0 - k) * e
        marks.append((st / float(RATE), ln / float(RATE)))
    return marks


def crackle(body, vpeak, gen):
    """2-6 pops of 1-3 ms band-limited noise under a linear decay, 0.4-0.8 of the voice peak, added into body."""
    n = 2 + next(gen) % 5
    for _ in range(n):
        ln = int((0.001 + (next(gen) % 3) / 1000.0) * RATE)
        at = next(gen) % max(1, len(body) - ln)
        amp = vpeak * (0.4 + (next(gen) % 41) / 100.0)
        burst = onepole_band(noise(ln + 8, next(gen)), 1500.0, 5000.0)[8:]
        top = max(abs(x) for x in burst) or 1.0
        for j in range(ln):
            body[at + j] += burst[j] / top * amp * (1.0 - j / float(ln))
    return n


def fade(s, n_in, n_out):
    n = len(s)
    for i in range(min(n_in, n)):
        s[i] *= i / float(n_in)
    for i in range(min(n_out, n)):
        s[n - 1 - i] *= i / float(n_out)
    return s


def clip(model, spk, text, idx, target):
    """Samples (16-bit ints) of one finished clip (target length target s) plus info."""
    seed = SEED + idx
    gen = lcg(seed * 7 + 1)
    sp, length = speech(model, spk, text, seed, speech_max(target))
    v = radio(sp)
    v, drive = overdrive(v)
    drops = dropouts(v, gen)
    v = fade(v, int(FADE * RATE), int(FADE * RATE))
    vpeak = max(abs(x) for x in v) or 1.0
    fixed = LEAD + CLICK + TAIL + TRAIL
    extra = max(0.0, MIN_LEN - fixed - len(v) / float(RATE))
    pre = int(extra * 0.6 * RATE) + int(0.020 * RATE)
    post = int(extra * 0.4 * RATE) + int(0.020 * RATE)
    body = [0.0] * pre + v + [0.0] * post
    src = noise(len(body) + int((CLICK + TAIL) * RATE), seed)
    band = onepole_band(src)
    bed = band[:len(body)]
    k = db(BED_DB) / (rms(bed) or 1.0)
    bed = fade([x * k for x in bed], int(FADE * RATE), 0)
    body = [a + b for a, b in zip(body, bed)]
    pops = crackle(body, vpeak, gen)
    nc = int(CLICK * RATE)
    click = [src[i] * (1.0 - i / float(nc)) * 0.7 * vpeak for i in range(nc)]
    nt = int(TAIL * RATE)
    tb = band[len(body):len(body) + nt]
    top = max(abs(x) for x in tb) or 1.0
    kd = math.log(1000.0) / nt
    tail = fade([x / top * 0.5 * vpeak * math.exp(-kd * i) for i, x in enumerate(tb)], 0, int(FADE * RATE))
    out = [0.0] * int(LEAD * RATE) + click + body + tail + [0.0] * int(TRAIL * RATE)
    m = max(abs(x) for x in out) or 1.0
    g = db(PEAK_DB) / m
    pcm = [max(-32768, min(32767, int(round(x * g * 32767)))) for x in out]
    info = {"speech": len(sp) / float(RATE), "length_scale": length, "drive": drive, "pops": pops, "drops": drops}
    return pcm, info


def wav_bytes(s):
    data = struct.pack("<%dh" % len(s), *s)
    hdr = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(data), b"WAVE", b"fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16,
                      b"data", len(data))
    return hdr + data


def wav_read(b):
    """(rate, channels, bits, samples) of a 44-byte-header PCM wav, or None."""
    if len(b) < 44 or b[0:4] != b"RIFF" or b[8:12] != b"WAVE" or b[12:16] != b"fmt " or b[36:40] != b"data":
        return None
    fmt, ch, rate, _, _, bits = struct.unpack("<HHIIHH", b[20:36])
    n = struct.unpack("<I", b[40:44])[0]
    if fmt != 1 or n != len(b) - 44 or bits != 16:
        return None
    return rate, ch, bits, struct.unpack("<%dh" % (n // 2), b[44:44 + n])


def stats(b):
    """Length s, peak dBFS, RMS dBFS of wav bytes b, or None."""
    w = wav_read(b)
    if not w:
        return None
    rate, ch, bits, s = w
    pk = max(abs(x) for x in s) if s else 0
    return {"rate": rate, "ch": ch, "len": len(s) / float(rate), "peak": pk,
            "peak_db": 20 * math.log10(max(pk, 1) / 32767.0), "rms_db": 20 * math.log10(max(rms(s), 1) / 32767.0)}


def read_manifest():
    """{name: (sha256, size)} from tools/gen_voice.sha256 ("<sha256>  <size>  <name>.wav" per line)."""
    m = {}
    with open(MANIFEST, "r", encoding="ascii") as f:
        for ln in f:
            p = ln.split()
            if len(p) == 3:
                m[p[2]] = (p[0], int(p[1]))
    return m


def write_manifest(rows):
    with open(MANIFEST, "w", encoding="ascii", newline="\n") as f:
        for name, b in rows:
            f.write("%s  %d  %s\n" % (hashlib.sha256(b).hexdigest(), len(b), name))


def check_files(out_dir, table):
    """Shipped set against the manifest and the format rules; prints the table, returns the number of problems."""
    bad, total = 0, 0
    try:
        man = read_manifest()
    except OSError:
        print("voice: manifest %s missing" % MANIFEST)
        return 1
    cl = clips()
    want = set(c[0] for c in cl)
    if set(man) != want:
        print("voice: manifest names differ from the phrase table")
        bad += 1
    try:
        have = set(x for x in os.listdir(out_dir) if not x.startswith("."))   # dotfiles (.DS_Store) are not clips
    except OSError:
        have = set()
    for x in sorted(have - want):
        print("voice: extra file %s" % os.path.join(out_dir, x))
        bad += 1
    if table:
        print("file                 speaker  len_s  peak_dB  rms_dB  bytes   spoken text")
    target = int(round(db(PEAK_DB) * 32767))
    for name, key, spk, text, _ in cl:
        path = os.path.join(out_dir, name)
        try:
            with open(path, "rb") as f:
                b = f.read()
        except OSError:
            print("voice: %s missing" % path)
            bad += 1
            continue
        total += len(b)
        st = stats(b)
        if not st:
            print("voice: %s is not 16-bit PCM wav with a 44-byte header" % path)
            bad += 1
            continue
        if table:
            print("%-20s %-8s %5.2f  %7.1f  %6.1f  %6d  %s" % (name, spk, st["len"], st["peak_db"], st["rms_db"], len(b),
                                                               text))
        why = []
        if st["rate"] != RATE or st["ch"] != 1:
            why.append("format %d Hz %d ch" % (st["rate"], st["ch"]))
        if abs(st["peak"] - target) > 1:
            why.append("peak %d, want %d" % (st["peak"], target))
        if st["len"] < MIN_LEN - 0.005 or st["len"] > HARD_MAX:
            why.append("length %.2f s" % st["len"])
        m = man.get(name)
        if not m:
            why.append("not in the manifest")
        elif m[1] != len(b) or m[0] != hashlib.sha256(b).hexdigest():
            why.append("sha256 or size differs from the manifest")
        if why:
            print("voice: %s: %s" % (path, "; ".join(why)))
            bad += 1
    print("voice: %d files, %d bytes in all (limit %d)" % (len(cl), total, SET_MAX))
    if total >= SET_MAX:
        print("voice: set too large")
        bad += 1
    return bad


def render(models, out_dir, write, check):
    bad, total, rows = 0, 0, []
    print("file                 speaker  len_s  speech_s  lscale  drive  pops  drops            peak_dB  rms_dB  bytes")
    for idx, (name, key, spk, text, tl) in enumerate(clips()):
        pcm, i = clip(models[spk], spk, text, idx, tl)
        b = wav_bytes(pcm)
        st = stats(b)
        total += len(b)
        rows.append((name, b))
        dr = ",".join("%.2f+%.3f" % d for d in i["drops"]) or "-"
        print("%-20s %-8s %5.2f  %8.2f  %6.3f  %5.2f  %4d  %-15s  %7.1f  %6.1f  %d" % (
            name, spk, st["len"], i["speech"], i["length_scale"], i["drive"], i["pops"], dr, st["peak_db"], st["rms_db"],
            len(b)))
        if st["len"] > HARD_MAX:
            print("voice: %s over %.1f s" % (name, HARD_MAX))
            bad += 1
        path = os.path.join(out_dir, name)
        if check:
            try:
                with open(path, "rb") as f:
                    old = f.read()
            except OSError:
                old = None
            if old != b:
                print("voice: %s %s" % (path, "missing" if old is None else "differs from the new render"))
                bad += 1
    print("voice: %d bytes in all" % total)
    if write and not bad:
        os.makedirs(out_dir, exist_ok=True)
        for name, b in rows:
            with open(os.path.join(out_dir, name), "wb") as f:
                f.write(b)
        write_manifest(rows)
        print("voice: wrote %d files to %s and %s" % (len(rows), out_dir, MANIFEST))
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 on any difference (with --render: against a new render)")
    ap.add_argument("--render", action="store_true", help="render with Piper (needs --trader and --control)")
    ap.add_argument("--write", action="store_true", help="with --render: write the wav files and the manifest")
    ap.add_argument("--trader", help="Piper .onnx model of the trader voice (its .onnx.json beside it)")
    ap.add_argument("--control", help="Piper .onnx model of the control voice")
    ap.add_argument("--out", default=OUT, help="clip directory (default Data/SOUND/trf_voice)")
    a = ap.parse_args()
    if a.render:
        if not a.trader or not a.control:
            ap.error("--render needs --trader and --control")
        bad = render({"trader": a.trader, "control": a.control}, a.out, a.write, a.check)
    else:
        if a.write:
            ap.error("--write needs --render")
        bad = check_files(a.out, True)
    if a.check or a.render:
        print("voice: %s" % ("all up to date" if not bad else "%d problem(s)" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
