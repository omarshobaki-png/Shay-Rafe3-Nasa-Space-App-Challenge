"""Shared numpy helpers for the game's sound: noise, filters, saturation, reverb, loop seams, loudness.
Everything here is plain code synthesis (no samples, no AI). Used by make_sounds.py and make_music.py.
Python with numpy, scipy and soundfile."""
import os, zlib
import numpy as np, soundfile as sf
from scipy import signal
from scipy.ndimage import minimum_filter1d, uniform_filter1d

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "audio"))
TAU = 2 * np.pi
_r = np.random.default_rng(0)

def seed(name, take=0):
    """Every sound gets its own repeatable noise."""
    global _r
    _r = np.random.default_rng(zlib.crc32(name.encode()) + take)

def n_(sec, sr=SR): return int(round(sec * sr))
def t_(sec, sr=SR): return np.arange(n_(sec, sr)) / sr
def nz(n): return _r.standard_normal(n)
def uni(lo, hi): return float(_r.uniform(lo, hi))
def f(x, kind, fc, order=2, sr=SR): return signal.sosfilt(signal.butter(order, fc, kind, fs=sr, output="sos"), x)
def bp(x, lo, hi, order=2, sr=SR): return f(x, "bp", [lo, hi], order, sr)
def cf(x, kind, fc, order=2, sr=SR):
    """Circular filter for loops: the second pass over the tiled loop is the periodic steady state."""
    return f(np.tile(x, 2), kind, fc, order, sr)[len(x):]
def brown(n): return f(np.cumsum(nz(n)) / 30.0, "hp", 25)
def sat(x, d=2.0): return np.tanh(d * x) / np.tanh(d)
def dec(t, tau): return np.exp(-t / tau)
def env(t, a, tau): return np.minimum(t / a, 1.0) * np.exp(-np.maximum(t - a, 0.0) / tau)
def sine(fr, t, ph=0.0): return np.sin(TAU * fr * t + ph)
def sweep(t, f0, f1, tau):
    """Sine whose pitch falls (or rises) from f0 to f1 with time constant tau: the weight of an impact."""
    return np.sin(TAU * np.cumsum(f1 + (f0 - f1) * np.exp(-t / tau)) / SR)
def modal(t, parts):
    """Damped sines (freq, amp, tau): the ring of a struck metal part."""
    return sum(a * np.sin(TAU * fr * t) * np.exp(-t / tau) for fr, a, tau in parts)
def saw(fr, t, top=5000.0, sr=SR):
    """Band-limited saw (additive); fr may be an array for glides."""
    ph = TAU * np.cumsum(np.broadcast_to(np.asarray(fr, dtype=float), t.shape)) / sr
    out = np.zeros(len(t))
    for k in range(1, max(2, int(top / float(np.max(fr))) + 1)):
        out += np.sin(k * ph) / k
    return out * (2 / np.pi)
def lfo(n, lo, hi):
    """Slow random wobble 0..1."""
    y = bp(nz(n), lo, hi)
    return 0.5 + 0.5 * y / (np.abs(y).max() + 1e-9)
def spiky(n, rate, power=2):
    """Random spiky gate 0..1 (plume crackle, debris, grit)."""
    g = np.abs(f(nz(n), "lp", rate)) ** power
    return g / (g.max() + 1e-9)
def crackle(n, rate=28, lo=1500, hi=7000): return bp(nz(n), lo, hi) * spiky(n, rate)
def put(buf, x, at, g=1.0):
    i = n_(at); m = min(len(x), len(buf) - i)
    if m > 0: buf[i:i + m] += x[:m] * g
    return buf
def fade(x, a=0.001, r=0.02, sr=SR):
    na, nr = max(1, n_(a, sr)), max(1, n_(r, sr)); x = x.copy()
    x[:na] *= np.linspace(0, 1, na); x[-nr:] *= np.linspace(1, 0, nr)
    return x

def _ir(rt, lo, hi, sr=SR):
    """Synthetic room: band-passed noise with a 60 dB decay over rt seconds, unit energy."""
    n = int(rt * sr); t = np.arange(n) / sr
    ir = f(f(nz(n), "hp", lo, 2, sr), "lp", hi, 2, sr) * np.exp(-6.9 * t / rt)
    return ir / np.sqrt(np.sum(ir ** 2))
def reverb(x, rt=0.3, wet=0.2, lo=300, hi=5000, pre=0.01):
    """Baked tail for one-shots (the web build plays samples that bypass bus effects)."""
    ir = np.concatenate([np.zeros(n_(pre)), _ir(rt, lo, hi)])
    y = wet * signal.fftconvolve(x, ir)
    y[:len(x)] += x
    return y
def creverb(x, rt, wet, lo=300, hi=5000, sr=SR):
    """Circular reverb: the tail wraps round the loop, so the loop stays seamless."""
    ir = np.zeros(len(x)); h = _ir(rt, lo, hi, sr); ir[:len(h)] = h
    return x + wet * np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), len(x))
def seam(x, n):
    """x is longer than n: fold the extra tail into the head with an equal-power crossfade.
    For noise only (equal power adds 3 dB to identical signals); tonal layers are made periodic instead."""
    k = len(x) - n; w = np.sqrt(np.linspace(0, 1, k)); y = x[:n].copy()
    y[:k] = x[:k] * w + x[n:] * np.sqrt(1 - w ** 2)
    return y

# ---- loudness (ITU-R BS.1770) ----
def kweight(x, sr):
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = np.tan(np.pi * f0 / sr); Vh = 10 ** (G / 20); Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    x = signal.lfilter(b, [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0], x)
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / sr); a0 = 1 + K / Q + K * K
    return signal.lfilter([1, -2, 1], [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0], x)
def _blocks(x, sr, hop):
    """Mean square of 400 ms blocks of the K-weighted signal (channels summed)."""
    x = np.atleast_2d(x.T).T if x.ndim == 2 else x[:, None]
    pad = int(0.4 * sr); w = int(0.4 * sr); h = max(1, int(hop * sr)); tot = 0
    for c in range(x.shape[1]):
        k = kweight(np.concatenate([np.zeros(pad), x[:, c], np.zeros(pad)]), sr)
        cs = np.concatenate([[0.0], np.cumsum(k ** 2)])
        tot = tot + (cs[w::h] - cs[:-w:h][:len(cs[w::h])]) / w
    return tot
def momentary_max(x, sr=SR):
    """Loudest 400 ms: the loudness of a one-shot (integrated loudness cannot measure sounds under 0.4 s)."""
    return float(-0.691 + 10 * np.log10(max(_blocks(x, sr, 0.01).max(), 1e-12)))
def integrated(x, sr=SR):
    """Gated integrated loudness, for loops, ambience and music."""
    ms = _blocks(x, sr, 0.1)
    ms = ms[4:-4] if len(ms) > 12 else ms  # drop the padded blocks
    l = -0.691 + 10 * np.log10(np.maximum(ms, 1e-12))
    ms = ms[l > -70.0]
    if len(ms) == 0: return -70.0
    rel = -0.691 + 10 * np.log10(ms.mean()) - 10.0
    return float(-0.691 + 10 * np.log10(ms[(-0.691 + 10 * np.log10(ms)) > rel].mean()))
def true_peak(x, sr=SR):
    return float(20 * np.log10(np.abs(signal.resample_poly(x, 4, 1, axis=0)).max() + 1e-12))
def limit(x, ceil_db=-1.5, look=0.003, sr=SR, circ=False):
    """Look-ahead peak limiter: the gain dips smoothly around a peak, so nothing clips and nothing crunches."""
    n = len(x)
    if circ: x = np.concatenate([x, x, x])
    a = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    k = max(2, int(look * sr))
    g = uniform_filter1d(minimum_filter1d(np.minimum(1.0, 10 ** (ceil_db / 20) / np.maximum(a, 1e-9)), 2 * k + 1), k)
    y = x * (g if x.ndim == 1 else g[:, None])
    return y[n:2 * n] if circ else y
def level(x, target, mode="mom", ceil=-1.2, sr=SR, circ=False):
    """Bring a sound to its loudness class (not to peak), then keep the TRUE peak under the ceiling."""
    c = ceil
    for _ in range(6):
        cur = momentary_max(x, sr) if mode == "mom" else integrated(x, sr)
        x = limit(x * 10 ** ((target - cur) / 20), c, sr=sr, circ=circ)
        over = true_peak(x, sr) - ceil  # bright sounds peak between the samples
        if over > 0: c -= over + 0.1
    return x * min(1.0, 10 ** ((ceil - true_peak(x, sr)) / 20))
def to_rate(x, sr_out, sr_in=SR, circ=False):
    if sr_out == sr_in: return x
    g = np.gcd(sr_out, sr_in); n = len(x)
    if not circ: return signal.resample_poly(x, sr_out // g, sr_in // g, axis=0)
    y = signal.resample_poly(np.concatenate([x, x, x]), sr_out // g, sr_in // g, axis=0)
    m = n * sr_out // sr_in
    return y[m:2 * m]
def save(name, x, sr):
    assert np.abs(x).max() < 1.0, name + " clips"
    os.makedirs(OUT, exist_ok=True)
    sf.write(os.path.join(OUT, name + ".wav"), x, sr, subtype="PCM_16")
