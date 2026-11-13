"""Depth art for the landing and surface screens: mountain ranges, top-down floor tiles for the
perspective ground shader, and rocks at several sizes for depth-scaled decor.

    python tools/art/gen_terrain.py

Mountains are height fields made of ridged pyramids, painted front to back from a raised camera
and shaded in flat tones (sun on the left, cast shadows). Every layer tiles in x.
The other surface sprites (craters, sky, parachute, HUD icons) come from gen_surface.py.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import dither, fbm, hexc, quant, ramp, save  # noqa: E402

LIGHT = np.array([-0.62, 0.5, 0.6])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def mode3(idx, n):
    """3x3 majority filter on a tone-index image (-1 = empty stays empty): removes single-pixel noise."""
    h, w = idx.shape
    best = np.zeros((h, w), dtype=int)
    bestc = np.full((h, w), -1)
    pad = np.pad(idx, 1, mode="edge")
    pad[:, 0] = pad[:, -2]
    pad[:, -1] = pad[:, 1]
    for k in range(n):
        c = np.zeros((h, w), dtype=int)
        for dy in range(3):
            for dx in range(3):
                c += (pad[dy:dy + h, dx:dx + w] == k) * (2 if (dy == 1 and dx == 1) else 1)
        up = c > bestc
        best[up] = k
        bestc[up] = c[up]
    return np.where(idx < 0, -1, best)


def peak_field(w, depth, seed, lines, slope=1.0, ridges=(3, 4), ridge_amp=0.5, mesa=0.0, rough=2.0,
               cells=(160, 80, 40), round_r=0.0, sharp=2.0):
    """Height field (depth rows x w columns, in px): the union of ridged pyramids strung along
    meandering crest lines. Every peak is a cone whose slope changes with the compass angle, so it
    gets sharp spurs with flat faces between them, and flat faces shade to flat tones.
    lines: (depth 0..1, lowest peak px, highest peak px, peak spacing px). mesa: share cut flat (Mars)."""
    rng = np.random.default_rng(seed)
    zs, xs = np.mgrid[0:depth, 0:w].astype(np.float64)
    h = np.zeros((depth, w))
    for li, (zf, hmin, hmax, step) in enumerate(lines):
        prof = fbm(w, 1, list(cells), seed + 31 * li, True, False)[0]
        prof = (prof - prof.min()) / (prof.max() - prof.min())
        prof = prof ** sharp                                  # few tall summits, long low saddles
        wander = (fbm(w, 1, [200, 100], seed + 77 + li, True, False)[0] - 0.5) * depth * 0.22
        x = rng.uniform(0, step)
        while x < w:
            xi = int(x) % w
            H = hmin + (hmax - hmin) * prof[xi] * rng.uniform(0.85, 1.1)
            pz = zf * depth + wander[xi] + rng.uniform(-0.04, 0.04) * depth
            dx = (xs - x + w / 2) % w - w / 2
            dz = zs - pz
            d = np.sqrt(dx * dx + dz * dz)
            th = np.arctan2(dz, dx)
            K = int(rng.integers(ridges[0], ridges[1] + 1))
            m = 1.0 + ridge_amp * np.abs(np.sin(K * th / 2 + rng.uniform(0, 6.283)))
            m2 = 1.0 + 0.14 * np.abs(np.sin((2 * K + 1) * th / 2 + rng.uniform(0, 6.283)))
            rr = round_r * rng.uniform(0.5, 1.5)              # rounded summit
            cone = H - (np.sqrt(d * d + rr * rr) - rr) * slope * rng.uniform(0.75, 1.2) * m * m2
            if mesa > 0 and rng.random() < 0.5:
                cone = np.minimum(cone, H * rng.uniform(1 - mesa, 1 - mesa * 0.3))
            h = np.maximum(h, cone)
            x += step * rng.uniform(0.6, 1.4)
    h = np.clip(h, 0, None)
    if rough > 0:
        h += (fbm(w, depth, [24, 12, 6], seed + 5, True, False) - 0.5) * rough * np.clip(h / 6.0, 0, 1)
    return h


def mountain_range(w, h, hpx, R, haze, fog, tilt, sun=(-0.7, 0.35, 0.6), shrink=0.4, sub=4, shadow_len=70, rim=True):
    """Paint a height field seen from a raised camera, lit from the left with cast shadows.
    Orthographic in x (so the layer tiles), perspective in y: the ground plane spans `tilt` rows
    from the nearest depth row (image bottom) to the farthest, so near slopes show their tops
    instead of hanging as vertical curtains (the old voxel-space streaks).
    R: lit ramp dark..light. haze: RGB the layer fades to. fog: (near, far) fade amount."""
    depth = hpx.shape[0]
    L = np.array(sun, dtype=np.float64)
    L /= np.linalg.norm(L)
    gx = (np.roll(hpx, -1, 1) - np.roll(hpx, 1, 1)) * 0.5
    gz = np.gradient(hpx, axis=0)
    # faces looking left (at the sun) are bright, faces looking at the camera mid, looking right dark
    lam = (gx * (-L[0]) + gz * L[1] + L[2]) / np.sqrt(gx * gx + gz * gz + 1)
    tone = np.clip(0.5 + (lam - L[2]) * 0.95, 0, 1)
    shadow = np.zeros_like(hpx, dtype=bool)
    tan_e = L[2] / abs(L[0]) * 0.9
    for k in range(2, shadow_len):
        shadow |= np.roll(hpx, k if L[0] < 0 else -k, 1) > hpx + k * tan_e + 1.0
    tone = np.where(shadow, np.minimum(tone, 0.45) * 0.5, tone)
    n = len(R)
    tidx = np.clip(np.floor(tone * n * 0.999), 0, n - 1).astype(int)
    idx = np.full((h, w), -1)
    zrow = np.zeros((h, w))
    ybuf = np.full(w, h, dtype=int)
    rows = np.arange(h)[:, None]
    D = depth * sub
    for zi in range(D):
        zf = zi / sub
        z0 = min(int(zf), depth - 1)
        z1 = min(z0 + 1, depth - 1)
        t = zf - z0
        hh = hpx[z0] * (1 - t) + hpx[z1] * t
        zn = zi / (D - 1.0)
        y = np.clip(np.floor(h - 1 - tilt * zn - hh / (1.0 + zn * shrink)).astype(int), 0, h)
        m = (rows >= y[None, :]) & (rows < ybuf[None, :])
        if m.any():
            idx = np.where(m, tidx[z0][None, :], idx)
            zrow = np.where(m, zn, zrow)
        ybuf = np.minimum(ybuf, y)
    idx = mode3(idx, n)
    solid = idx >= 0
    top = solid & ~np.roll(solid, 1, 0)
    top[0] = solid[0]
    fz = np.round((fog[0] + (fog[1] - fog[0]) * zrow) * 6) / 6.0
    hz = np.array(haze[:3], dtype=np.float64)
    col = R[np.clip(idx, 0, n - 1)][..., :3].astype(np.float64)
    if rim:  # 1 px lit crest on sunlit skylines
        rimc = np.clip(R[-1][:3].astype(np.float64) + 14, 0, 255)
        col = np.where((top & (idx >= n // 2))[..., None], rimc[None, None, :], col)
    col = col * (1 - fz[..., None]) + hz[None, None, :] * fz[..., None]
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    img[..., 3] = np.where(solid, 255, 0)
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
    img = R[quant(lam, len(R), d, 0.35)].copy()
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


def facet_rock(w, h, seed, R, outline, table=False, veins=None):
    """A boulder cut into flat facets (no dither), lit from the upper left, with a dark outline, a
    lit upper-left rim and a rounded base that sits in the soil. table: flattened top to stand on.
    veins: two colours (dark, light) of crystal veins for sample rocks."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    cx, cy = (w - 1) / 2, h * 0.62
    ang = np.arctan2(ys - cy, xs - cx)
    wob = 1 + 0.07 * np.sin(ang * 3 + rng.random() * 6) + 0.05 * np.sin(ang * 5 + rng.random() * 6)
    nx = (xs - cx) / (w / 2 - 0.5)
    ny = np.where(ys < cy, (ys - cy) / (cy - 0.5), (ys - cy) / ((h - 1 - cy) * 1.15 + 0.5))
    p = 3.1 if table else 2.5
    inside = (np.abs(nx) ** p + np.abs(ny) ** p) <= wob ** p
    # facets: nearest of a few seed points; each facet takes the sphere normal at its seed
    nf = int(np.clip(w * h / 30, 4, 44))
    fx = rng.uniform(0.08, 0.92, nf) * w
    fy = rng.uniform(0.05, 0.95, nf) * h
    d2 = (xs[..., None] - fx) ** 2 + ((ys[..., None] - fy) * 1.3) ** 2
    f = np.argmin(d2, axis=2)
    snx = np.clip((fx - cx) / (w / 2), -1, 1)
    sny = np.clip((fy - cy) / (h * 0.62), -1, 1)
    snz = np.sqrt(np.clip(1 - snx * snx * 0.8 - sny * sny * 0.8, 0.05, 1))
    lam = np.clip(snx * LIGHT[0] - sny * LIGHT[1] + snz * LIGHT[2] + rng.uniform(-0.16, 0.16, nf), 0, 1)
    lam = lam / lam.max()
    n = len(R)
    tone = np.clip(np.floor(lam * n * 0.999), 0, n - 1).astype(int)[f]
    tone = np.where(ys >= h - 2, np.maximum(tone - 1, 0), tone)     # dark lower edge
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[...] = R[tone]
    img[~inside] = 0
    a = inside
    up = np.roll(a, 1, 0)
    up[0] = False
    left = np.roll(a, 1, 1)
    left[:, 0] = False
    hi = a & (~up | ~left) & (nx < 0.35) & (ny < 0.2)               # lit rim on the upper left
    img[hi] = np.clip(R[-1].astype(int) + np.array([14, 14, 14, 0]), 0, 255).astype(np.uint8)
    if veins is not None:
        for _ in range(max(2, w // 6)):
            vx, vy = rng.uniform(0.2, 0.8) * w, rng.uniform(0.25, 0.75) * h
            ln = rng.integers(2, max(3, w // 4))
            sl = rng.choice([-1, 1])
            for k in range(ln):
                px, py = int(vx + k), int(vy + sl * (k // 2))
                if 0 <= px < w and 0 <= py < h and a[py, px]:
                    img[py, px] = veins[1] if k % 3 != 2 else veins[0]
    out = img.copy()
    pad = np.pad(a, 1)
    edge = ~a & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
    out[edge] = outline
    return out


def main():
    ol = hexc("0c0a14")
    # Moon: no air, so distance does not fade; the far layers are simply darker to keep depth readable.
    msky = hexc("0c0d14")
    save(mountain_range(640, 60, peak_field(640, 120, 111, [(0.6, 8, 40, 46)], slope=0.4, rough=0, round_r=10, ridges=(2, 4)),
                        ramp("252840", "31354e"), msky, (0.0, 0.0), 5, rim=False), "surface/moon_range_dist.png")
    save(mountain_range(640, 140, peak_field(640, 260, 101, [(0.8, 40, 170, 54), (0.55, 24, 90, 44), (0.35, 10, 40, 40)], slope=0.85, round_r=8, sharp=2.2),
                        ramp("1e2030", "33374a", "4b5068", "666b84"), msky, (0.0, 0.2), 16), "moon_range_far.png")
    save(mountain_range(640, 90, peak_field(640, 170, 102, [(0.8, 12, 64, 34), (0.45, 5, 30, 28)], slope=0.6, ridge_amp=0.45, round_r=9),
                        ramp("1a1b28", "30323f", "4c4f60", "70748a", "989cb2", "c2c6da"), msky, (0.0, 0.1), 24), "moon_range_near.png")
    # Mars: dusty air fades the far ranges into the butterscotch sky; many summits are mesas.
    rsky = hexc("d8a676")
    save(mountain_range(640, 60, peak_field(640, 120, 211, [(0.6, 8, 38, 50)], slope=0.4, rough=0, mesa=0.5, round_r=6, ridges=(2, 4)),
                        ramp("c08a66", "cd9872"), rsky, (0.0, 0.0), 5, rim=False), "surface/mars_range_dist.png")
    save(mountain_range(640, 140, peak_field(640, 260, 201, [(0.8, 36, 150, 58), (0.55, 22, 80, 46), (0.35, 10, 36, 40)], slope=0.85, mesa=0.45, round_r=5, sharp=2.2),
                        ramp("8a4a30", "a65c3a", "be7248", "d08a5c"), rsky, (0.1, 0.4), 16), "mars_range_far.png")
    save(mountain_range(640, 90, peak_field(640, 170, 202, [(0.8, 12, 58, 36), (0.45, 5, 28, 30)], slope=0.6, mesa=0.4, ridge_amp=0.45, round_r=7),
                        ramp("4a1c12", "642818", "80361e", "9c4628", "b85a34", "cc7444"), rsky, (0.0, 0.2), 24), "mars_range_near.png")
    save(floor_tile(128, 311, ramp("2e2f3c", "3a3c4a", "474a5a", "56596a", "666a7c", "7e8296"), "moon"), "floor_moon.png")
    save(floor_tile(128, 312, ramp("4e1e12", "62281a", "74321e", "863c24", "9a4a2c", "b25e38"), "mars"), "floor_mars.png")
    rm = ramp("2a2a36", "4a4a58", "6e6e80", "9a9aac", "c4c4d2")
    rr = ramp("3a1410", "5e2418", "8a3a22", "b45a34", "d8845a")
    for i, (w, h) in enumerate(((6, 4), (9, 6), (14, 9), (20, 13), (30, 19), (44, 28))):
        save(facet_rock(w, h, 900 + i, rm, ol), "pebble_moon_%d.png" % i)
        save(facet_rock(w, h, 950 + i, rr, ol), "pebble_mars_%d.png" % i)
    for h in (23, 50):
        save(facet_rock(67, h + 12, 420 + h, rm, ol, table=True), "boulder_moon_%d.png" % h)
        save(facet_rock(67, h + 12, 520 + h, rr, ol, table=True), "boulder_mars_%d.png" % h)
    cy = (hexc("1d5a80"), hexc("8fe3f5"))
    save(facet_rock(20, 13, 77, ramp("3a3a46", "6a6a7a", "9a9aac", "c8c8d6"), ol, veins=cy), "sample_moon_big.png")
    save(facet_rock(20, 13, 78, ramp("3a1810", "6e3020", "a04e32", "d07a50"), ol, veins=cy), "sample_mars_big.png")
    print("TERRAIN DONE")


if __name__ == "__main__":
    os.makedirs(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "art", "surface"), exist_ok=True)
    main()
