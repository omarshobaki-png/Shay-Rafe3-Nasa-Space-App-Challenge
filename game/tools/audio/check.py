"""Measure every file in audio/ against the project's targets and print one row per file.
    python tools/audio/check.py [name ...]
lufs = integrated for loops, ambience and music; loudest 400 ms for one-shots (integrated cannot measure a
sound under 0.4 s). tp = true peak (4x oversampled). sub% = share of energy under 60 Hz (limit 15).
small = loudness lost after a 200 Hz high-pass (what a laptop speaker drops). seam = jump at the loop point
compared with the largest step inside the file (under 1 = no click)."""
import os, sys, glob, json
import numpy as np, soundfile as sf
from scipy import signal
from synth import OUT, momentary_max, integrated, true_peak, f

LOOPED = ("thrust", "rover_loop", "drill", "amb_", "music_")
rows = []; total = 0; bad = []
names = sys.argv[1:]
for p in sorted(glob.glob(os.path.join(OUT, "*.wav"))):
    name = os.path.basename(p)[:-4]; total += os.path.getsize(p)
    if names and name not in names: continue
    x, sr = sf.read(p, always_2d=True)
    mono = x.mean(axis=1); loop = name.startswith(LOOPED)
    steady = loop or name.startswith("sting_")
    lufs = integrated(x, sr) if steady else momentary_max(x, sr)
    fr, P = signal.periodogram(mono, sr)
    def share(lo, hi): return round(float(P[(fr >= lo) & (fr < hi)].sum() / (P.sum() + 1e-20) * 100), 1)
    hp = np.stack([f(x[:, c], "hp", 200, 4, sr) for c in range(x.shape[1])], axis=1)
    small = (integrated(x, sr) - integrated(hp, sr)) if steady else (momentary_max(x, sr) - momentary_max(hp, sr))
    d = np.abs(np.diff(mono))
    r = {"name": name, "sr": sr, "ch": x.shape[1], "len_s": round(len(mono) / sr, 2), "lufs": round(lufs, 1),
         "tp": round(true_peak(x, sr), 1), "sub%": share(0, 60), "low%": share(60, 250), "mid%": share(250, 2000),
         "pres%": share(2000, 6000), "air%": share(6000, 1e9), "small": round(small, 1),
         "seam": round(float(abs(mono[0] - mono[-1]) / (d.max() + 1e-12)), 2) if loop else "", "kb": os.path.getsize(p) // 1024}
    rows.append(r)
    if r["tp"] > -1.0: bad.append(name + ": true peak %.1f" % r["tp"])
    if r["sub%"] > 15: bad.append(name + ": sub %.1f%%" % r["sub%"])
    if loop and r["seam"] > 1.0: bad.append(name + ": loop seam %.2f" % r["seam"])
hdr = list(rows[0].keys())
print("\t".join(hdr))
for r in rows: print("\t".join(str(r[h]) for h in hdr))
print("total audio/: %.2f MB in wav files" % (total / 1e6))
print("PROBLEMS:", bad if bad else "none")
json.dump(rows, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "check.json"), "w"), indent=1)
