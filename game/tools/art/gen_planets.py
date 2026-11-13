"""The other planets of the Solar System, in the same style as gen_bg.planet():
Mercury, Venus, Jupiter, Uranus, Neptune.

    python tools/art/gen_planets.py

Writes art/planet_<name>_<r>.png for r in 9, 12, 22, 36, 60 (Pix.planet(r, name) picks the nearest).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import LIGHT, _sphere, _tex_lookup, dither, fbm, hexc, quant, ramp, save  # noqa: E402

SIZES = (9, 12, 22, 36, 60)


def _craters(seed, n=30):
    crat = np.zeros((128, 256))
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:128, 0:256]
    for _ in range(n):
        cx, cy, cr = rng.integers(0, 256), rng.integers(10, 118), rng.integers(2, 9)
        dd = np.sqrt(np.minimum(np.abs(xx - cx), 256 - np.abs(xx - cx)) ** 2 + (yy - cy) ** 2) / cr
        crat -= np.where(dd < 0.8, 0.2, 0)
        crat += np.where((dd >= 0.8) & (dd < 1.15), 0.16, 0)
    return crat


def planet(kind, r, seed=4):
    squash = {"jupiter": 0.94, "uranus": 0.98, "neptune": 0.98}.get(kind, 1.0)
    W, H, x, y, d2, inside, lam, lon, lat = _sphere(r, squash=squash, pad=2)
    d = dither(H, W)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    detail = 1.0 if r >= 12 else 0.5
    k = 0.9 if r >= 22 else 0.5   # less dither on the small ones
    if kind == "mercury":
        base = fbm(256, 128, [64, 32, 16, 8], seed + 31, True, False)
        alb = 0.66 + 0.3 * (_tex_lookup(base, lon, lat) - 0.5) * detail + _tex_lookup(_craters(seed + 32, 40), lon, lat) * detail
        R = ramp("17120f", "33291f", "574636", "7f6a52", "a89274", "cdbb9c")
        img[...] = R[quant(lam ** 0.8 * np.clip(alb, 0, 1.2), len(R), d, k)]
    elif kind == "venus":
        warp = fbm(256, 128, [64, 32, 16], seed + 41)
        clouds = fbm(256, 128, [128, 32, 16, 8], seed + 42)
        swirl = 0.5 + 0.3 * np.sin(lat * 7.0 + (_tex_lookup(warp, lon, lat) - 0.5) * 6.0 * detail + lon * 1.2)
        alb = 0.72 + 0.2 * (swirl - 0.5) + 0.2 * (_tex_lookup(clouds, lon, lat) - 0.5) * detail
        R = ramp("2c1a08", "5c3c12", "8e6420", "bc9038", "deb862", "f2dc94", "fdf2c8")
        img[...] = R[quant(lam ** 0.7 * alb, len(R), d, k)]
    elif kind == "jupiter":
        turb = fbm(256, 128, [64, 32, 16, 8], seed + 51)
        t = (_tex_lookup(turb, lon, lat) - 0.5) * detail
        band = 0.5 + 0.3 * np.sin(lat * 11.0 + t * 2.4) + 0.12 * np.sin(lat * 27.0 + t * 5.0 + 1.0)
        # belts are darker and redder: pick between two ramps by the band value
        Z = ramp("2e2018", "5a4630", "8c7450", "bca27a", "e2cfa4", "f6ecd2")   # zones (cream)
        B = ramp("23100a", "4a2112", "74381c", "9c552c", "c07a48", "dca070")   # belts (rust)
        v = lam ** 0.75 * (0.62 + 0.42 * band)
        zi = Z[quant(v, len(Z), d, k)]
        bi = B[quant(v, len(B), d, k)]
        img[...] = np.where((band < 0.46)[..., None], bi, zi)
        # Great Red Spot, south of the equator
        sx, sy = (lon - 0.45) / 0.34, (lat + 0.38) / 0.17
        spot = (sx * sx + sy * sy) < 1.0
        if r >= 12:
            S = ramp("3a0e08", "70200e", "a43c1a", "cc6030", "e88a58")
            img[spot] = S[quant(lam[spot] ** 0.75 * (0.75 + 0.25 * (1 - (sx * sx + sy * sy)[spot])), len(S), d[spot], k)]
    elif kind == "uranus":
        band = 0.5 + 0.08 * np.sin(lat * 6.0) * detail
        R = ramp("0c2a30", "1a5058", "2e7c84", "56a8ac", "8ccfce", "c2ecea")
        img[...] = R[quant(lam ** 0.75 * (0.7 + 0.5 * (band - 0.5) + 0.26), len(R), d, k)]
    elif kind == "neptune":
        turb = fbm(256, 128, [64, 32, 16], seed + 61)
        band = 0.5 + 0.14 * np.sin(lat * 8.0 + (_tex_lookup(turb, lon, lat) - 0.5) * 2.0) * detail
        R = ramp("060c2c", "0e1e58", "183888", "2a5cba", "4c88de", "8cbcf4")
        img[...] = R[quant(lam ** 0.75 * (0.72 + 0.6 * (band - 0.5) + 0.2), len(R), d, k)]
        if r >= 12:
            sx, sy = (lon + 0.3) / 0.3, (lat + 0.3) / 0.14
            dark = (sx * sx + sy * sy) < 1.0
            img[dark, :3] = (img[dark, :3] * 0.6).astype(np.uint8)
            streak = (np.abs(lat - 0.42 - 0.05 * np.sin(lon * 5)) < 0.035) & (np.sin(lon * 3 + 1.0) > 0.2)
            img[streak & (lam > 0.3)] = hexc("e6f2ff")
    img[~inside] = 0
    # a thin atmosphere rim on the lit side for the planets that have thick air
    rim_col = {"venus": hexc("f6e2a8", 120), "jupiter": hexc("e8cfa0", 90), "uranus": hexc("b4eeee", 110),
               "neptune": hexc("7ab0ff", 120)}.get(kind)
    if rim_col is not None:
        rim = (d2 > 1.0) & (d2 <= (1.0 + 1.6 / r) ** 2)
        side = (x * LIGHT[0] - y * LIGHT[1]) > -0.25
        img[rim & side] = rim_col
    return img


def main():
    for kind in ("mercury", "venus", "jupiter", "uranus", "neptune"):
        for r in SIZES:
            save(planet(kind, r), "planet_%s_%d.png" % (kind, r))
    print("PLANETS DONE")


if __name__ == "__main__":
    main()
