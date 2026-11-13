"""Depth art for the surface screens: 3D-rendered mountain ranges, top-down floor tiles
for the perspective ground shader, and rocks at several sizes for depth-scaled decor.

    python tools/art/gen_terrain.py

Mountains are rendered like the old voxel-space flight sims: a heightmap is marched
from near to far with a y-buffer, lit from the left with cast shadows, and fades into
the sky with distance. Every layer tiles in x.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import dither, fbm, hexc, quant, ramp, rock, save  # noqa: E402


def ridged(w, h, cells, seed):
    n = fbm(w, h, cells, seed, True, False)
    return 1.0 - np.abs(n * 2.0 - 1.0)


def mountain_range(w, h, seed, R, haze, d0, d1, amp, rise, fog_max, sun=(-0.75, 0.25, 0.6), base_fog=0.5, cells=(96, 48, 24, 12, 6)):
    """Voxel-space render. R: lit ramp dark..light. haze: RGBA the far rows fade to.
    d0..d1: depth range; amp: peak height in px at mid depth; rise: how fast peaks grow with depth."""
    D = 480
    zs = np.linspace(0, 1, D)
    # noise is made on a short grid and stretched in depth, so neighbouring depth rows
    # differ little in height: faces get many thin rows (shading) instead of flat curtains
    small = ridged(w, 48, list(cells), seed) ** 1.4 + fbm(w, 48, [64, 16, 4], seed + 9, True, False) * 0.25
    zi_f = zs * 47
    z0 = np.floor(zi_f).astype(int)
    z1 = np.minimum(z0 + 1, 47)
    tz = (zi_f - z0)[:, None]
    hm = small[z0] * (1 - tz) + small[z1] * tz
    hm *= (0.35 + 0.65 * np.clip(zs[:, None] * rise, 0, 1))
    hm = np.clip(hm, 0, None)
    L = np.array(sun, dtype=np.float64)
    L /= np.linalg.norm(L)
    dz = (d1 - d0) / D
    gx = (np.roll(hm, -1, 1) - np.roll(hm, 1, 1)) * 0.5 * amp * 0.6
    gz = (np.roll(hm, -1, 0) - np.roll(hm, 1, 0)) * 0.5 * amp * 0.6 / dz
    gz[0], gz[-1] = gz[1], gz[-2]
    lam = np.clip((-gx * L[0] - gz * L[1] + L[2]) / np.sqrt(gx * gx + gz * gz + 1), 0, 1)
    # cast shadows: march toward the sun along x
    hpx = hm * amp
    shadow = np.zeros_like(hm, dtype=bool)
    tan_e = L[2] / abs(L[0]) * 0.55
    for k in range(1, 90):
        shadow |= np.roll(hpx, k if L[0] < 0 else -k, 1) > hpx + k * tan_e
    lam = np.where(shadow, lam * 0.35, lam)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ybuf = np.full(w, h, dtype=int)
    rows = np.arange(h)[:, None]
    dth = dither(h, w)
    haze = np.array(haze, dtype=np.float64)
    for zi in range(D):
        dist = d0 + zi * dz
        y = (h - 1 - hpx[zi] * (d0 + (d1 - d0) * 0.5) / dist).astype(int)
        y = np.clip(y, 0, h)
        m = (rows >= y[None, :]) & (rows < ybuf[None, :])
        if not m.any():
            continue
        idx = quant(lam[zi][None, :].repeat(h, 0), len(R), dth, 0.6)
        fog = quant(np.full((h, w), zi / (D - 1) * fog_max), 5, dth, 0.6) / 4.0 * fog_max
        col = R[idx].astype(np.float64) * (1 - fog[..., None]) + haze[None, None, :] * fog[..., None]
        col[..., 3] = 255
        img[m] = col.astype(np.uint8)[m]
        # 1px lit crest on sunlit ridges
        crest = (rows == y[None, :]) & m & (lam[zi][None, :] > 0.55)
        img[crest] = np.clip(R[-1].astype(int) + 16, 0, 255).astype(np.uint8)
        ybuf = np.minimum(ybuf, y)
    # low haze/dust pooled at the foot of the range hides the near-row curtains
    k = np.clip((rows - h * 0.6) / (h * 0.4), 0, 1) ** 1.3 * base_fog
    lv = quant(np.broadcast_to(k, (h, w)), 5, dth, 0.8) / 4.0 * base_fog
    solid = img[..., 3] > 0
    mix = img[..., :3] * (1 - lv[..., None]) + haze[None, None, :3] * lv[..., None]
    img[..., :3] = np.where(solid[..., None], mix, img[..., :3]).astype(np.uint8)
    return img


def floor_tile(n, seed, R, kind):
    """Top-down ground for the mode-7 shader, tileable both ways, hill-shaded from the left."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64)
    hm = fbm(n, n, [32, 16, 8, 4], seed, True, True) * 2.0
    if kind == "moon":
        for _ in range(14):
            cx, cy, r = rng.random() * n, rng.random() * n, rng.uniform(3, 15)
            dx = (xs - cx + n / 2) % n - n / 2
            dy = (ys - cy + n / 2) % n - n / 2
            d = np.sqrt(dx * dx + dy * dy) / r
            hm += np.where(d < 1, (d * d - 1) * r * 0.35, 0) + np.exp(-((d - 1.05) / 0.18) ** 2) * r * 0.12
    else:
        warp = fbm(n, n, [32, 16], seed + 3, True, True)
        hm += np.sin((ys / n * 8 + warp * 1.5) * 2 * np.pi) * 0.9   # wind ripples
    gx = (np.roll(hm, -1, 1) - np.roll(hm, 1, 1)) * 0.5
    gy = (np.roll(hm, -1, 0) - np.roll(hm, 1, 0)) * 0.5
    lam = np.clip(0.55 - gx * 0.32 - gy * 0.12, 0, 1)
    d = dither(n, n)
    img = R[quant(lam, len(R), d, 0.7)].copy()
    peb = np.array([R[0], R[-1]], dtype=np.uint8)
    for _ in range(40 if kind == "mars" else 24):
        px, py = rng.integers(0, n), rng.integers(0, n)
        img[py, px] = peb[1]
        img[(py + 1) % n, px] = peb[0]
        if rng.random() < 0.4:
            img[py, (px + 1) % n] = peb[1]
            img[(py + 1) % n, (px + 1) % n] = peb[0]
    img[..., 3] = 255
    return img


def main():
    ol = hexc("0c0a14")
    moon_R = ramp("1c1d28", "2a2c3a", "3c3f50", "54576c", "72768c", "9296aa")
    mars_R = ramp("4a1c12", "642818", "80361e", "9c4628", "b85a34", "cc7444")
    # Moon: no air, so distance barely fades (a slight darkening keeps the depth readable).
    save(mountain_range(640, 140, 101, moon_R, hexc("0c0d14"), 260, 560, 110, 1.6, 0.45, cells=(160, 80, 40, 20, 10)), "moon_range_far.png")
    save(mountain_range(640, 90, 102, moon_R, hexc("0c0d14"), 90, 180, 42, 1.2, 0.3, cells=(96, 48, 24, 12, 6)), "moon_range_near.png")
    # Mars: dusty air fades the far range into the butterscotch sky.
    save(mountain_range(640, 140, 201, mars_R, hexc("c89a72"), 260, 560, 100, 1.5, 0.75, cells=(160, 80, 40, 20, 10)), "mars_range_far.png")
    save(mountain_range(640, 90, 202, mars_R, hexc("c89a72"), 90, 180, 40, 1.2, 0.4, cells=(96, 48, 24, 12, 6)), "mars_range_near.png")
    save(floor_tile(128, 311, ramp("2e2f3c", "3a3c4a", "474a5a", "56596a", "666a7c", "7e8296"), "moon"), "floor_moon.png")
    save(floor_tile(128, 312, ramp("4e1e12", "62281a", "74321e", "863c24", "9a4a2c", "b25e38"), "mars"), "floor_mars.png")
    rm = ramp("2a2a36", "4a4a58", "6e6e80", "9a9aac", "c4c4d2")
    rr = ramp("3a1410", "5e2418", "8a3a22", "b45a34", "d8845a")
    for i, (w, h) in enumerate(((6, 4), (9, 6), (14, 9), (20, 13), (30, 19), (44, 28))):
        save(rock(w, h, 900 + i, rm, ol), "pebble_moon_%d.png" % i)
        save(rock(w, h, 950 + i, rr, ol), "pebble_mars_%d.png" % i)
    for h in (23, 50):
        save(rock(67, h + 12, 420 + h, rm, ol), "boulder_moon_%d.png" % h)
        save(rock(67, h + 12, 520 + h, rr, ol), "boulder_mars_%d.png" % h)
    save(rock(20, 13, 77, ramp("3a3a46", "6a6a7a", "9a9aac", "c8c8d6"), ol), "sample_moon_big.png")
    save(rock(20, 13, 78, ramp("3a1810", "6e3020", "a04e32", "d07a50"), ol), "sample_mars_big.png")
    print("TERRAIN DONE")


if __name__ == "__main__":
    main()
