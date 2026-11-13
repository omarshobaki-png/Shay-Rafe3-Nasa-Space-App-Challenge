"""Solar-system strip for the menu: every planet at one compressed scale, plus the edge of the Sun.

    python tools/art/gen_menu_system.py      writes art/menu/sys_<id>.png and art/menu/sun_edge.png

Scale rule (written on the menu as "not to scale"): radius_px = 7 * sqrt(R / R_earth), rounded,
so the size ORDER is always the real one. Mean radii, km, NASA planetary fact sheets:
Jupiter 69,911  Saturn 58,232  Uranus 25,362  Neptune 24,622  Earth 6,371  Venus 6,052
Mars 3,390  Mercury 2,440  Moon 1,737.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_bg  # noqa: E402
import gen_planets  # noqa: E402
from gen_bg import dither, fbm, hexc, quant, ramp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "menu")

RADIUS_KM = {"mercury": 2440, "venus": 6052, "earth": 6371, "moon": 1737, "mars": 3390,
             "jupiter": 69911, "saturn": 58232, "uranus": 25362, "neptune": 24622}


def px_radius(kind):
    r = 7.0 * math.sqrt(RADIUS_KM[kind] / RADIUS_KM["earth"])
    return max(3, int(math.floor(r + 0.5)) if kind != "moon" else int(math.floor(r)))  # Moon rounds down: it must stay smaller than Mercury


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))


def body(kind, r):
    if kind in ("moon", "mars", "earth", "saturn"):
        return gen_bg.planet(kind, r)
    return gen_planets.planet(kind, r)


def sun_edge(R=92, vis=30, H=220):
    """The left edge of the Sun: a disc of radius R whose right `vis` px show, with a corona beyond it."""
    glow = 26
    W = vis + glow
    cx, cy = vis - R - 1, (H - 1) / 2
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    dx, dy = xs - cx, ys - cy
    d = np.sqrt(dx * dx + dy * dy) / R
    img = np.zeros((H, W, 4), dtype=np.uint8)
    th = dither(H, W)
    gran = fbm(W, H, [6, 3], 5, False, False)
    # limb darkening: bright at the centre, orange-red at the rim
    mu = np.sqrt(np.clip(1 - d * d, 0, 1))
    S = ramp("8a2a08", "c44a10", "e8761c", "f8a834", "ffd060", "fff0a8", "fffbe6")
    v = np.clip(0.25 + 0.75 * mu ** 0.45 + 0.12 * (gran - 0.5), 0, 1)
    inside = d <= 1.0
    disc = S[quant(v, len(S), th, 0.8)]
    img[inside] = disc[inside]
    # corona: a few stepped rings of falling alpha, warm yellow
    out = ~inside
    k = (d - 1.0) * R    # px beyond the rim
    C = [(2, hexc("ffd060", 170)), (5, hexc("f8a834", 110)), (10, hexc("e8761c", 60)), (17, hexc("c44a10", 32)), (26, hexc("8a2a08", 16))]
    lo = 0
    for hi, col in C:
        m = out & (k > lo) & (k <= hi)
        img[m] = col
        lo = hi
    return img


def main():
    for kind in RADIUS_KM:
        r = px_radius(kind)
        save(body(kind, r), "sys_%s.png" % kind)
        print(kind, r)
    save(sun_edge(), "sun_edge.png")
    print("MENU SYSTEM DONE")


if __name__ == "__main__":
    main()
