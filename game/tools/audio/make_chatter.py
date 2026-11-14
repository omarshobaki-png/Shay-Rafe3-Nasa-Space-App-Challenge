"""The dialogue's "bibi" chatter: 5 tiny toy blips (talk_bi.wav, talk_bi_1..4.wav), pure Python (no numpy,
no samples, no AI). Audio.chatter() plays one on every 2nd or 3rd letter with +-12% pitch.
    python tools/audio/make_chatter.py
Each blip: a soft square (odd harmonics 1, 3, 5 with falling weights) or a triangle, a pitch glide (down = "bi",
up = "mi"), a 1.5 ms attack and a fast exponential decay, levelled to PEAK_DB. Prints length and peak."""
import math
import os
import struct
import wave

SR = 44100
PEAK_DB = -9.0   # like ui_hover; Audio plays them Data.TALK["chatter_db"] under the effects
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio")

# (start Hz, end Hz, ms, decay ms, shape)
BLIPS = [
    (720, 640, 30, 9, "square"),
    (820, 740, 26, 8, "square"),
    (560, 640, 34, 11, "tri"),
    (900, 800, 22, 7, "tri"),
    (640, 580, 38, 12, "square"),
]


def blip(f0, f1, ms, tau_ms, shape):
    n = int(SR * ms / 1000)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        k = i / max(n - 1, 1)
        ph += 2 * math.pi * (f0 + (f1 - f0) * k) / SR
        if shape == "square":   # soft: only the low odd harmonics
            x = math.sin(ph) + math.sin(3 * ph) / 4.5 + math.sin(5 * ph) / 12.0
        else:
            x = 2 / math.pi * math.asin(math.sin(ph))
        env = min(t / 0.0015, 1.0) * math.exp(-t / (tau_ms / 1000))
        env *= min((n - 1 - i) / (SR * 0.002), 1.0)   # 2 ms fade to zero: no click at the end
        out.append(x * env)
    peak = max(abs(v) for v in out)
    g = 10 ** (PEAK_DB / 20) / peak
    return [v * g for v in out]


def save(name, xs):
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(round(v * 32767))) for v in xs))


if __name__ == "__main__":
    for i, b in enumerate(BLIPS):
        name = "talk_bi" if i == 0 else "talk_bi_%d" % i
        xs = blip(*b)
        save(name, xs)
        peak = 20 * math.log10(max(abs(v) for v in xs))
        print("%-10s %4.0f ms  peak %5.1f dBFS  %d-%d Hz %s" % (name, 1000 * len(xs) / SR, peak, b[0], b[1], b[4]))
