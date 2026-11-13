"""The game's music, synthesized with numpy (no samples, no AI): five loops and two stingers on one motif.
    python tools/audio/make_music.py [theme hangar ascent drift descent sting_win sting_fail]
Key D minor. Motif: A4 D5 F5 E5 | D5 C5 A4 (up a fourth, up a third, then down by step).
Instruments: detuned saw pad through a moving low-pass, additive plucks (high partials die first) with a
dotted-eighth delay, bells, a soft lead with vibrato, sine + saturated bass, soft drums, baked reverb.
Loops are rendered ROUND the loop (note tails, delay and reverb wrap to the start), so they repeat with
no seam and no crossfade. Rendered at twice the file's rate, then halved."""
import sys
import numpy as np
import synth as S
from synth import TAU, cf, creverb, f, nz, uni, fade

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
def hz(name):
    semi = NOTE[name[0]] + (1 if "#" in name else -1 if "b" in name[1:] else 0)
    return 440.0 * 2 ** ((semi + 12 * (int(name[-1]) + 1) - 69) / 12)

# chord: (pad voicing, bass root, arpeggio tones)
CH = {
    "Dm": ("D3 A3 C4 F4", "D2", "D4 F4 A4 C5"), "Bb": ("Bb2 F3 A3 D4", "Bb2", "D4 F4 A4 Bb4"),
    "F": ("F3 A3 C4 E4", "F2", "F4 A4 C5 E5"), "C": ("C3 G3 D4 E4", "C2", "E4 G4 C5 D5"),
    "Cs": ("C3 G3 C4 F4", "C2", "F4 G4 C5 D5"), "Gm": ("G3 Bb3 D4 F4", "G2", "D4 G4 Bb4 D5"),
    "Dp": ("D3 A3 D4 E4", "D2", "D4 E4 A4 D5"), "Bd": ("D3 F3 Bb3 E4", "D2", "D4 F4 Bb4 D5"),
    "Gd": ("D3 G3 Bb3 E4", "D2", "D4 G4 Bb4 E5"), "As": ("D3 A3 D4 G4", "D2", "E4 G4 A4 D5"),
}

# ---------------------------------------------------------------- instruments (fr Hz, dur s, sr)
_tabs = {}
def osc_saw(fr, n, sr, top=7000.0, ph0=0.0, vib=0.0):
    """Band-limited saw from a wavetable (no aliasing)."""
    h = max(1, min(64, int(top / fr)))
    if h not in _tabs:
        ph = np.arange(2048) / 2048 * TAU
        _tabs[h] = sum(np.sin(k * ph) / k for k in range(1, h + 1)) * (2 / np.pi)
    x = ((ph0 + fr * np.arange(n) / sr + vib) % 1.0) * 2048
    i = x.astype(int); r = x - i
    return _tabs[h][i % 2048] * (1 - r) + _tabs[h][(i + 1) % 2048] * r

def pad(fr, dur, sr, att=0.5, rel=1.0):
    n = int((dur + rel) * sr); t = np.arange(n) / sr
    x = sum(osc_saw(fr * 2 ** (c / 1200), n, sr, 8000, uni(0, 1)) for c in (-9, 0, 8)) / 3
    x += 0.35 * osc_saw(fr * 2 * 2 ** (4 / 1200), n, sr, 8000, uni(0, 1))
    return x * np.minimum(t / att, 1.0) * np.where(t < dur, 1.0, 0.5 * (1 + np.cos(np.pi * np.minimum((t - dur) / rel, 1.0))))

def pluck(fr, dur, sr, bright=1.0, tau=0.35):
    """Additive pluck: partial k decays faster the higher it is, like a closing filter."""
    n = int(min(max(dur + 0.3, tau * 5), 3.0) * sr); t = np.arange(n) / sr
    x = sum(np.sin(TAU * k * fr * t + 0.3 * k) / k * np.exp(-t / tau * (1 + (k - 1) * 0.6 / bright))
            for k in range(1, max(2, min(16, int(7000 / fr))) + 1))
    return x * np.minimum(t / 0.002, 1.0) * np.exp(-np.maximum(t - dur, 0) / 0.12)

def bell(fr, dur, sr, tau=0.9):
    n = int(tau * 4.5 * sr); t = np.arange(n) / sr
    x = sum(a * np.sin(TAU * r * fr * t) * np.exp(-t / (tau * d))
            for r, a, d in ((1, 1.0, 1.0), (2.0, 0.45, 0.6), (3.0, 0.22, 0.4), (4.2, 0.16, 0.25), (5.4, 0.08, 0.18)))
    return x * np.minimum(t / 0.003, 1.0)

def lead(fr, dur, sr, rel=0.25):
    """Soft saw + sine with a late vibrato."""
    n = int((dur + rel) * sr); t = np.arange(n) / sr
    vib = -(fr * 0.004 / (TAU * 5.2)) * np.cos(TAU * 5.2 * t) * np.minimum(t / 0.4, 1.0)
    x = 0.5 * osc_saw(fr, n, sr, 3500, 0.0, vib) + 0.7 * np.sin(TAU * (fr * t + vib)) + 0.25 * osc_saw(fr * 1.004, n, sr, 3500, 0.3, vib)
    e = np.minimum(t / 0.04, 1.0) * (0.85 + 0.15 * np.exp(-t / 0.2))
    return x * e * np.where(t < dur, 1.0, 0.5 * (1 + np.cos(np.pi * np.minimum((t - dur) / rel, 1.0))))

def brass(fr, dur, sr):
    """Saw stack whose brightness swells in: the fanfare voice."""
    n = int((dur + 0.3) * sr); t = np.arange(n) / sr
    x = sum(osc_saw(fr * 2 ** (c / 1200), n, sr, 6000, uni(0, 1)) for c in (-7, 0, 7)) / 3
    b = np.minimum(t / 0.12, 1.0)
    x = f(x, "lp", 900, 2, sr) * (1 - b) + f(x, "lp", 3200, 2, sr) * b
    return x * np.minimum(t / 0.03, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.08))

def bass(fr, dur, sr):
    """Sine sub + saturated saw, so it is felt on big speakers and still heard on small ones."""
    n = int((dur + 0.08) * sr); t = np.arange(n) / sr
    x = np.sin(TAU * fr * t) + 0.5 * osc_saw(fr, n, sr, 900)
    e = np.minimum(t / 0.006, 1.0) * (0.7 + 0.3 * np.exp(-t / 0.15)) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.03))
    return np.tanh(1.8 * x * e)

def kick(sr, soft=1.0):
    t = np.arange(int(0.3 * sr)) / sr
    x = np.sin(TAU * np.cumsum(62 + 80 * np.exp(-t / 0.03)) / sr) * np.exp(-t / (0.11 * soft))
    return np.tanh(2 * x) + f(nz(len(t)), "hp", 2500, 2, sr) * np.exp(-t / 0.003) * 0.25
def hat(sr, tau=0.025):
    t = np.arange(int(tau * 7 * sr)) / sr
    return f(nz(len(t)), "hp", 7000, 2, sr) * np.exp(-t / tau)
def shaker(sr):
    t = np.arange(int(0.12 * sr)) / sr
    return S.bp(nz(len(t)), 4000, 9000, 2, sr) * np.minimum(t / 0.012, 1.0) * np.exp(-np.maximum(t - 0.012, 0) / 0.03)
def snare(sr):
    t = np.arange(int(0.3 * sr)) / sr
    return S.bp(nz(len(t)), 900, 4500, 2, sr) * np.exp(-t / 0.07) + np.sin(TAU * 190 * t) * np.exp(-t / 0.04) * 0.6
def rim(sr):
    t = np.arange(int(0.06 * sr)) / sr
    return np.sin(TAU * 1700 * t) * np.exp(-t / 0.008) + f(nz(len(t)), "hp", 3000, 2, sr) * np.exp(-t / 0.002) * 0.4
def tom(sr, fr=95.0):
    t = np.arange(int(0.5 * sr)) / sr
    return np.tanh(2 * np.sin(TAU * np.cumsum(fr + 70 * np.exp(-t / 0.05)) / sr) * np.exp(-t / 0.16))
def swell(sr, sec, lo=1500, hi=7000):
    """Noise that rises into a downbeat."""
    t = np.arange(int(sec * sr)) / sr
    return fade(S.bp(nz(len(t)), lo, hi, 2, sr) * (t / sec) ** 2.5, 0.01, 0.03, sr)

# ---------------------------------------------------------------- the song buffer
class Song:
    def __init__(self, bpm, bars, out_sr=24000):
        self.out_sr = out_sr; self.sr = out_sr * 2; self.beat = 60.0 / bpm; self.bars = bars
        self.n = int(round(bars * 4 * self.beat * out_sr)) * 2
        self.t = np.arange(self.n) / self.sr
    def bus(self): return np.zeros(self.n)
    def add(self, bus, sig, beat, gain=1.0):
        """Mix a note in at a beat; whatever runs past the end wraps to the start."""
        i = int(round(beat * self.beat * self.sr)) % self.n
        sig = sig[:self.n]; m = min(len(sig), self.n - i)
        bus[i:i + m] += sig[:m] * gain
        if m < len(sig): bus[:len(sig) - m] += sig[m:] * gain
    def notes(self, bus, inst, seq, bar0=0, gain=1.0, oct=1.0, **kw):
        """seq = [(bar, beat, length in beats, 'A4'), ...]"""
        for bar, beat, dur, nm in seq:
            self.add(bus, inst(hz(nm) * oct, dur * self.beat, self.sr, **kw), (bar0 + bar) * 4 + beat, gain * uni(0.88, 1.0))
    def chords(self, bus, prog, bars_each=1, gain=1.0, att=0.5):
        for i, c in enumerate(prog):
            for nm in CH[c][0].split():
                self.add(bus, pad(hz(nm), bars_each * 4 * self.beat, self.sr, att), i * bars_each * 4, gain)
    def hits(self, bus, sig_fn, beats, bars, gain=1.0, every=1):
        for b in bars:
            for k in beats:
                self.add(bus, sig_fn(self.sr), b * 4 + k, gain * uni(0.85, 1.0))
    def sweep(self, x, lo, hi, cycles=1.0, ph=0.0):
        """Low-pass that opens and closes over whole cycles of the loop."""
        m = 0.5 - 0.5 * np.cos(TAU * cycles * self.t / (self.n / self.sr) + ph)
        return cf(x, "lp", lo, 2, self.sr) * (1 - m) + cf(x, "lp", hi, 2, self.sr) * m
    def delay(self, x, beats=0.75, fb=0.45, taps=5, lp=3500):
        y = np.zeros(self.n); d = x
        for _ in range(taps):
            d = cf(np.roll(d, int(round(beats * self.beat * self.sr))), "lp", lp, 1, self.sr) * fb
            y += d
        return y
    def rev(self, x, rt, wet, lo=250, hi=5000): return creverb(x, rt, wet, lo, hi, self.sr) - x  # wet only
    def halo(self, x, rt=3.0, hp=2500):
        """Air: the top of a bus through a long reverb (wet only)."""
        return self.rev(cf(x, "hp", hp, 2, self.sr), rt, 1.0, 2000, 9000)
    def section(self, bar_a, bar_b, edge=0.5):
        """Gain curve that is 1 inside bars [a, b) and 0 outside, with soft edges (in beats)."""
        b = self.t / self.beat; e = edge
        return np.clip((b - bar_a * 4 + e) / e, 0, 1) * np.clip((bar_b * 4 - b) / e, 0, 1)
    def master(self, mix, lufs=-18.0, drive=1.2, bright=1.0, shape=None):
        """shape = gain curve over the loop (sections that breathe); bright = high shelf above 2.5 kHz, so the
        track is not muffled next to the effects (1.0 = +6 dB)."""
        x = cf(mix, "hp", 40, 2, self.sr)
        x = x + bright * cf(x, "hp", 2500, 1, self.sr)
        if shape is not None: x = x * shape
        x = np.tanh(drive * x / (np.sqrt(np.mean(x ** 2)) * 4.5)) # gentle glue: peaks round off, body untouched
        x = S.to_rate(x, self.out_sr, self.sr, circ=True)
        return S.level(x, lufs, "int", -1.6, self.out_sr, circ=True)

MOTIF = [(0, 0, 1, "A4"), (0, 1, 1, "D5"), (0, 2, 1.5, "F5"), (0, 3.5, .5, "E5"), (1, 0, 1.5, "D5"), (1, 1.5, .5, "C5"), (1, 2, 2, "A4")]
ANSWER = [(0, 0, 1, "A4"), (0, 1, 1, "C5"), (0, 2, 1.5, "F5"), (0, 3.5, .5, "G5"), (1, 0, 1.5, "A5"), (1, 1.5, .5, "G5"), (1, 2, 2, "E5")]
RISE = [(0, 0, 1, "D5"), (0, 1, 1, "F5"), (0, 2, 1.5, "A5"), (0, 3.5, .5, "G5"), (1, 0, 1.5, "F5"), (1, 1.5, .5, "D5"), (1, 2, 2, "C5")]
CLOSE = [(0, 0, 1, "C5"), (0, 1, 1, "F5"), (0, 2, 1, "A5"), (0, 3, 1, "C6"), (1, 0, 2, "G5"), (1, 2, 1, "E5"), (1, 3, 1, "D5")]
def at(seq, bar): return [(b + bar, k, d, n) for b, k, d, n in seq]
def arp(s, bus, prog, bars, pattern, step=0.5, gain=1.0, bars_each=1, **kw):
    """Chord tones in a fixed order, one per step."""
    for b in bars:
        tones = CH[prog[(b // bars_each) % len(prog)]][2].split()
        for i, k in enumerate(pattern):
            if k is not None:
                s.add(bus, pluck(hz(tones[k % 4]) * (2 if k >= 4 else 1), step * s.beat, s.sr, **kw), b * 4 + i * step, gain * uni(0.8, 1.0))
def bassline(s, bus, prog, bars, beats, gain=1.0, bars_each=1):
    for b in bars:
        root = hz(CH[prog[(b // bars_each) % len(prog)]][1])
        for k, d, o in beats:
            s.add(bus, bass(root * o, d * s.beat, s.sr), b * 4 + k, gain)

# ---------------------------------------------------------------- the tracks
def theme():
    """Menu and report: calm, hopeful. 24 bars at 84 BPM (68.6 s): A (melody on bells), A' (lead + arpeggio +
    soft drums), B (lift to Bb and C, the motif answered an octave up), last bar thins back to the start."""
    s = Song(84, 24)
    prog = ["Dm", "Bb", "F", "C"] * 4 + ["Bb", "C", "Dm", "Dm", "Bb", "C", "F", "Cs"]
    p = s.bus(); s.chords(p, prog)
    mel = at(MOTIF, 0) + at(ANSWER, 2) + at(RISE, 4) + at(CLOSE, 6)
    b_mel = [(0, 0, 1, "D5"), (0, 1, 1, "F5"), (0, 2, 1.5, "Bb5"), (0, 3.5, .5, "A5"), (1, 0, 1.5, "G5"), (1, 1.5, .5, "E5"), (1, 2, 2, "C5")] \
        + at(MOTIF[:4], 2) + [(3, 0, 3, "D5")] \
        + [(4, 0, 1, "D5"), (4, 1, 1, "F5"), (4, 2, 1.5, "Bb5"), (4, 3.5, .5, "A5"), (5, 0, 1.5, "G5"), (5, 1.5, .5, "A5"), (5, 2, 2, "C6"),
           (6, 0, 2, "A5"), (6, 2, 1, "F5"), (6, 3, 1, "C5"), (7, 0, 3, "E5")]
    bl = s.bus(); s.notes(bl, bell, mel, 0, 1.0, tau=0.8)                       # A: bells carry the tune
    s.notes(bl, bell, at(MOTIF, 0) + at(RISE, 4), 8, 0.35, 2.0, tau=0.5)        # A': bells sparkle an octave up
    s.notes(bl, bell, b_mel, 16, 0.4, tau=0.7)
    ld = s.bus(); s.notes(ld, lead, mel, 8); s.notes(ld, lead, b_mel, 16, 1.0)
    ar = s.bus(); arp(s, ar, prog, range(8, 23), [0, 2, 1, 2, 3, 2, 1, 2], 0.5, 1.0, bright=0.8, tau=0.25)
    ba = s.bus(); bassline(s, ba, prog, range(0, 8), [(0, 3.5, 1)]); bassline(s, ba, prog, range(8, 16), [(0, 2.5, 1), (2.5, 1.5, 1)])
    bassline(s, ba, prog, range(16, 23), [(0, 1.5, 1), (1.5, 1, 1), (2.5, 1, 2), (3.5, .5, 1)]); bassline(s, ba, prog, [23], [(0, 3.5, 1)])
    dr = s.bus(); s.hits(dr, lambda sr: kick(sr, 0.9), [0, 2.5], range(8, 23), 0.8); s.hits(dr, hat, [1, 3], range(8, 16), 0.26)
    s.hits(dr, shaker, [0.5, 1.5, 2.5, 3.5], range(16, 23), 0.32); s.hits(dr, rim, [3], range(16, 23), 0.25)
    s.add(dr, swell(s.sr, 2 * s.beat), 8 * 4 - 2, 0.12); s.add(dr, swell(s.sr, 2 * s.beat), 16 * 4 - 2, 0.16)
    pf = s.sweep(p, 1100, 4200, 3.0, np.pi)
    mel_bus = bl * 0.20 + s.delay(bl, 0.75, 0.4) * 0.12 + ld * 0.20 + s.delay(ld, 0.75, 0.35) * 0.07
    mix = pf * 0.16 + s.rev(pf, 2.4, 0.5) * 0.16 + mel_bus + s.rev(mel_bus, 2.0, 0.5) + cf(ar, "lp", 3000, 1, s.sr) * 0.10 \
        + s.delay(ar, 0.75, 0.4) * 0.06 + ba * 0.20 + dr * 0.30 + s.rev(dr, 0.7, 0.2) + s.halo(p) * 0.10
    # A is the quiet statement (bells alone), A' and B open up, the last bar falls back to it
    return s, s.master(mix, bright=1.5, shape=0.76 + 0.24 * s.section(8, 23, 4.0))

def hangar():
    """Builder: light and unhurried, leaves 1-4 kHz to the UI. 16 bars at 92 BPM (41.7 s): warm pad, the motif low
    on a muted pluck every other pair of bars, soft kick, shaker in the second half. No lead."""
    s = Song(92, 16)
    prog = ["Dm", "Bb", "Gm", "C", "Dm", "Bb", "F", "Cs"]
    p = s.bus(); s.chords(p, prog, 2, 1.0, 0.8)
    low = lambda seq: [(b, k, d, n[:-1] + str(int(n[-1]) - 1)) for b, k, d, n in seq]
    gm = [(0, 0, 1, "D4"), (0, 1, 1, "G4"), (0, 2, 1.5, "Bb4"), (0, 3.5, .5, "A4"), (1, 0, 1.5, "G4"), (1, 1.5, .5, "F4"), (1, 2, 2, "D4")]
    fm = [(0, 0, 1, "C4"), (0, 1, 1, "F4"), (0, 2, 1.5, "A4"), (0, 3.5, .5, "G4"), (1, 0, 1.5, "F4"), (1, 1.5, .5, "E4"), (1, 2, 2, "C4")]
    pl = s.bus()
    s.notes(pl, pluck, low(MOTIF), 0, 1.0, bright=0.5, tau=0.5); s.notes(pl, pluck, gm, 4, 1.0, bright=0.5, tau=0.5)
    s.notes(pl, pluck, low(RISE), 8, 1.0, bright=0.5, tau=0.5); s.notes(pl, pluck, fm, 12, 1.0, bright=0.5, tau=0.5)
    s.notes(pl, pluck, [(3, 2, 2, "D4"), (7, 2, 2, "E4"), (11, 2, 2, "F4"), (15, 3, 1, "A3")], 0, 0.6, bright=0.5, tau=0.6)
    ba = s.bus(); bassline(s, ba, prog, range(16), [(0, 1.5, 1), (2.5, 1, 1)], 1.0, 2)
    dr = s.bus(); s.hits(dr, lambda sr: kick(sr, 0.8), [0, 2], range(4, 16), 0.7); s.hits(dr, rim, [3], range(5, 16, 2), 0.12)
    s.hits(dr, shaker, [0.5, 1.5, 2.5, 3.5], range(8, 16), 0.10)
    pf = s.sweep(p, 700, 1500, 2.0)
    plf = cf(pl, "lp", 1800, 2, s.sr)
    mix = pf * 0.2 + s.rev(pf, 2.2, 0.5) * 0.2 + plf * 0.22 + s.delay(plf, 0.75, 0.4, 4, 1500) * 0.10 + s.rev(plf, 1.6, 0.35) * 0.22 \
        + ba * 0.16 + dr * 0.28 + s.rev(dr, 0.6, 0.15)
    return s, s.master(mix, bright=1.2)

def ascent():
    """Launch to arrival: drive. 16 bars at 124 BPM (31 s): eighth-note bass in 3-3-2, four-on-the-floor kick,
    sixteenth arpeggio with delay; the motif enters at bar 5 and runs double-time over F and C from bar 9."""
    s = Song(124, 16)
    prog = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "C", "F", "C", "Dm", "Bb", "F", "C", "Dm", "C"]
    p = s.bus(); s.chords(p, prog, 1, 1.0, 0.15)
    ba = s.bus(); bassline(s, ba, prog, range(16), [(0, .45, 1), (.5, .45, 1), (1, .45, 1), (1.5, .45, 2), (2, .45, 1), (2.5, .45, 1), (3, .45, 2), (3.5, .45, 1)])
    ar = s.bus(); arp(s, ar, prog, range(16), [0, 1, 2, 3, 4, 3, 2, 1] * 2, 0.25, 1.0, bright=1.2, tau=0.18)
    dbl = [(0, 0, .5, "A4"), (0, .5, .5, "C5"), (0, 1, 1, "F5"), (0, 2, 1.5, "A5"), (0, 3.5, .5, "G5"), (1, 0, 1.5, "G5"), (1, 1.5, .5, "E5"), (1, 2, 1, "C5"), (1, 3, 1, "E5"),
           (2, 0, .5, "A4"), (2, .5, .5, "D5"), (2, 1, 1, "F5"), (2, 2, 1.5, "A5"), (2, 3.5, .5, "F5"), (3, 0, 1.5, "F5"), (3, 1.5, .5, "D5"), (3, 2, 2, "D5"),
           (4, 0, .5, "C5"), (4, .5, .5, "F5"), (4, 1, 1, "A5"), (4, 2, 1.5, "C6"), (4, 3.5, .5, "A5"), (5, 0, 1.5, "G5"), (5, 1.5, .5, "E5"), (5, 2, 2, "G5"),
           (6, 0, 1, "A5"), (6, 1, 1, "F5"), (6, 2, 1, "D5"), (6, 3, 1, "A4"), (7, 0, 1, "C5"), (7, 1, 1, "E5"), (7, 2, 1, "G5"), (7, 3, 1, "E5")]
    ld = s.bus(); s.notes(ld, lead, at(MOTIF, 4) + at(ANSWER, 6), 0, 0.8); s.notes(ld, lead, dbl, 8)
    pk = s.bus(); s.notes(pk, pluck, at(MOTIF, 4) + at(ANSWER, 6), 0, 0.8, bright=1.2); s.notes(pk, pluck, dbl, 8, 0.6, 2.0, bright=1.0)
    dr = s.bus(); s.hits(dr, kick, [0, 1, 2, 3], range(16), 1.0); s.hits(dr, hat, [0.5, 1.5, 2.5, 3.5], range(16), 0.2)
    s.hits(dr, hat, [0.25, 0.75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75], range(8, 16), 0.07)
    s.hits(dr, snare, [1, 3], range(4, 16), 0.42); s.hits(dr, tom, [3, 3.5], [3, 7, 15], 0.4)
    for b in (4, 8, 16):
        s.add(dr, swell(s.sr, 4 * s.beat), b * 4 - 4, 0.14)
    pf = s.sweep(p, 900, 2800, 2.0, np.pi)
    arf = s.sweep(ar, 1200, 5000, 4.0, np.pi)
    mel = ld * 0.17 + pk * 0.14
    mix = pf * 0.13 + s.rev(pf, 1.6, 0.4) * 0.13 + arf * 0.09 + s.delay(arf, 0.75, 0.4) * 0.06 + mel + s.delay(mel, 0.75, 0.35) * 0.3 \
        + s.rev(mel, 1.5, 0.4) + ba * 0.19 + dr * 0.30 + s.rev(dr, 0.5, 0.15)
    return s, s.master(mix, drive=1.5, bright=1.6)

def drift():
    """Cruise, surface, trip home: calm, no drums. 12 bars at 72 BPM (40 s): wide pad, slow bell arpeggio with
    delay, the motif at half speed, a soft sub."""
    s = Song(72, 12)
    prog = ["Dm", "F", "Bb", "C", "Gm", "Cs"]
    p = s.bus(); s.chords(p, prog, 2, 1.0, 1.2)
    half = [(0, 0, 2, "A4"), (0, 2, 2, "D5"), (1, 0, 3, "F5"), (1, 3, 1, "E5"), (2, 0, 3, "D5"), (2, 3, 1, "C5"), (3, 0, 4, "A4"),
            (4, 0, 2, "A4"), (4, 2, 2, "C5"), (5, 0, 3, "F5"), (5, 3, 1, "G5"), (6, 0, 3, "A5"), (6, 3, 1, "G5"), (7, 0, 4, "E5"),
            (8, 0, 4, "D5"), (9, 0, 4, "Bb4"), (10, 0, 4, "C5"), (11, 2, 2, "G4")]
    bl = s.bus(); s.notes(bl, bell, half, 0, 1.0, tau=1.3)
    ar = s.bus()
    for b in range(12):
        tones = CH[prog[b // 2]][2].split()
        for k, i in ((0.5, 0), (1.5, 2), (2.5, 1), (3.5, 3)) if b % 2 == 0 else ((1, 1), (2.5, 2), (3, 0)):
            s.add(ar, bell(hz(tones[i]), 1.0, s.sr, 0.5), b * 4 + k, uni(0.6, 1.0))
    ba = s.bus(); bassline(s, ba, prog, range(12), [(0, 3.8, 1)], 1.0, 2)
    air = cf(nz(s.n), "hp", 4000, 2, s.sr) * (0.5 - 0.5 * np.cos(TAU * 3 * s.t / (s.n / s.sr))) ** 2
    pf = s.sweep(p, 700, 2400, 3.0, np.pi)
    mb = bl * 0.20 + s.delay(bl, 1.5, 0.45) * 0.10 + ar * 0.07 + s.delay(ar, 0.75, 0.5) * 0.05
    mix = pf * 0.19 + s.rev(pf, 3.0, 0.6) * 0.19 + mb + s.rev(mb, 2.6, 0.6) + ba * 0.13 + air * 0.004
    return s, s.master(mix, bright=1.5)

def descent():
    """Landing and the Saturn drone: tension over a D pedal. 12 bars at 100 BPM (28.8 s): pulsing bass, ticking
    hats, a heartbeat tom, unresolved chords, the motif's first four notes low and unanswered, tremolo from bar 9."""
    s = Song(100, 12)
    prog = ["Dp", "Bd", "Dp", "Gd", "Bd", "As"]
    p = s.bus(); s.chords(p, prog, 2, 1.0, 0.6)
    ba = s.bus()
    for b in range(12):
        for i, nm in enumerate(("D2", "D2", "D3", "D2", "D2", "F2", "D2", "C2")):
            s.add(ba, bass(hz(nm), 0.4 * s.beat, s.sr), b * 4 + i * 0.5, 1.0 if i % 2 == 0 else 0.75)
    frag = [(0, 0, 1, "A3"), (0, 1, 1, "D4"), (0, 2, 1.5, "F4"), (0, 3.5, 2.5, "E4")]
    pk = s.bus()
    for b, o in ((0, 1), (4, 1), (8, 2), (10, 2)):
        s.notes(pk, pluck, frag, b, 1.0, o, bright=0.9, tau=0.45)
    s.notes(pk, pluck, [(2, 2, 1, "D4"), (2, 3, 3, "Bb3"), (6, 2, 1, "G4"), (6, 3, 3, "E4")], 0, 0.8, bright=0.9, tau=0.45)
    st = s.bus()                                                    # sixteenth stabs on D from bar 5
    for b in range(4, 12):
        for i in range(16):
            if i % 4 != 0:
                s.add(st, pluck(hz("D4"), 0.1, s.sr, 0.7, 0.08), b * 4 + i * 0.25, 0.5 if i % 2 else 0.8)
    dr = s.bus(); s.hits(dr, hat, [i * 0.25 for i in range(16)], range(12), 0.08); s.hits(dr, hat, [0, 1, 2, 3], range(12), 0.10)
    s.hits(dr, lambda sr: tom(sr, 80.0), [0, 0.75], range(12), 0.5); s.hits(dr, rim, [2], range(4, 12), 0.2)
    s.hits(dr, snare, [3.5], [7, 11], 0.3)
    s.add(dr, swell(s.sr, 8 * s.beat, 800, 5000), 12 * 4 - 8, 0.2)
    trem = 1 - s.section(8, 12, 2.0) * 0.5 * (0.5 + 0.5 * np.sin(TAU * 4 * s.t / s.beat))
    pf = s.sweep(p, 700, 2600, 1.0) * trem
    mix = pf * 0.17 + s.rev(pf, 2.0, 0.5) * 0.17 + pk * 0.22 + s.delay(pk, 0.75, 0.5) * 0.12 + s.rev(pk, 1.8, 0.4) * 0.22 \
        + cf(st, "lp", 2200, 1, s.sr) * 0.07 + ba * 0.17 + dr * 0.30 + s.rev(dr, 0.6, 0.2)
    return s, s.master(mix, drive=1.5, bright=1.6)

def _sting(mix_fn, bpm, bars, sec, lufs):
    s = Song(bpm, bars, 32000); x = mix_fn(s)
    x = np.tanh(x / (np.sqrt(np.mean(x ** 2)) * 4.0))
    x = S.to_rate(f(x, "hp", 45, 2, s.sr), 32000, s.sr)[:int(sec * 32000)]
    return s, S.level(fade(x, 0.002, 0.5, 32000), lufs, "int", -1.5, 32000)

def sting_win():
    """Mission success: C F A run into a held F major chord with the top C, drum, swell and bells (3.4 s)."""
    def mix(s):
        run = [(0, 0, .5, "C5"), (0, .5, .5, "F5"), (0, 1, .5, "A5"), (0, 1.5, 3.2, "C6")]
        br = s.bus(); s.notes(br, brass, run, 0, 1.0); s.notes(br, brass, run, 0, 0.6, 0.5)
        s.notes(br, brass, [(0, 1.5, 3.2, "F4"), (0, 1.5, 3.2, "A4"), (0, 1.5, 3.2, "C5"), (0, 1.5, 3.2, "F5")], 0, 0.6)
        bl = s.bus(); s.notes(bl, bell, run + [(0, 2, 1, "F6"), (0, 2.5, 1, "A6"), (0, 3, 1, "C7")], 0, 1.0, tau=0.6)
        ba = s.bus(); s.add(ba, bass(hz("F2"), 1.6, s.sr), 1.5); s.add(ba, bass(hz("C3"), 0.6, s.sr), 0)
        dr = s.bus(); s.add(dr, tom(s.sr, 90.0), 0, 0.7); s.add(dr, tom(s.sr, 75.0), 1.5, 1.0); s.add(dr, swell(s.sr, 1.5 * s.beat), 0, 0.3)
        s.add(dr, hat(s.sr, 0.25), 1.5, 0.35)
        m = br * 0.22 + bl * 0.14 + ba * 0.2 + dr * 0.35
        return m + s.rev(m, 1.6, 0.45)
    return _sting(mix, 120, 4, 3.4, -15.0)

def sting_fail():
    """Mission failed: F falls a minor third to D on a dark saw stack, bells step down, a low drop under it (3 s)."""
    def mix(s):
        br = s.bus(); s.notes(br, brass, [(0, 0, 1.4, "F4"), (0, 1.5, 3.0, "D4"), (0, 0, 1.4, "A3"), (0, 1.5, 3.0, "F3"), (0, 1.5, 3.0, "D3"), (0, 2.5, 2.0, "Eb3")], 0, 1.0)
        bl = s.bus(); s.notes(bl, bell, [(0, 0, 1, "A4"), (0, 0.75, 1, "F4"), (0, 1.5, 2, "D4")], 0, 1.0, tau=0.7)
        t = np.arange(int(1.6 * s.sr)) / s.sr
        drop = np.tanh(3 * np.sin(TAU * np.cumsum(62 + 60 * np.exp(-t / 0.35)) / s.sr) * np.exp(-t / 0.5))
        lo = s.bus(); s.add(lo, drop, 1.5); s.add(lo, tom(s.sr, 70.0), 0, 0.8)
        m = cf(br, "lp", 1300, 2, s.sr) * 0.26 + bl * 0.12 + lo * 0.18
        return m + s.rev(m, 2.0, 0.5, 150, 2500)
    return _sting(mix, 100, 4, 3.0, -15.0)

TRACKS = {"theme": theme, "hangar": hangar, "ascent": ascent, "drift": drift, "descent": descent, "sting_win": sting_win, "sting_fail": sting_fail}
if __name__ == "__main__":
    for nm in (sys.argv[1:] or list(TRACKS)):
        S.seed("music_" + nm)
        s, x = TRACKS[nm]()
        S.save(nm if nm.startswith("sting") else "music_" + nm, x, s.out_sr)
        print("made", nm, "%.1f s" % (len(x) / s.out_sr))
