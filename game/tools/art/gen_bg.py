"""Planets, parallax layers, ground textures, rocks and clouds as palette pixel art.

    python tools/art/gen_bg.py

Everything is drawn at 1 art pixel = 1 game pixel (640x360 viewport), quantized to
small ramps with a 4x4 Bayer dither, lit from the upper left like the ship sprites.
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art")

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47
LIGHT = np.array([-0.62, 0.5, 0.6])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def ramp(*hs):
    return np.array([hexc(h) for h in hs], dtype=np.uint8)


def dither(h, w):
    return np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]


def quant(v, n, d, k=1.0):
    """v 0..1 -> ramp index with ordered dither of strength k."""
    return np.clip(np.floor(v * n + d * k), 0, n - 1).astype(int)


def vnoise(w, h, cell, rng, tile_x=True, tile_y=False):
    gw, gh = -(-w // cell), -(-h // cell)
    g = rng.random((gh + 1, gw + 1))
    if tile_x:
        g[:, gw] = g[:, 0]
    if tile_y:
        g[gh, :] = g[0, :]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    fx, fy = xs / cell, ys / cell
    ix, iy = fx.astype(int), fy.astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[iy, ix] * (1 - tx) + g[iy, ix + 1] * tx
    b = g[iy + 1, ix] * (1 - tx) + g[iy + 1, ix + 1] * tx
    return a * (1 - ty) + b * ty


def fbm(w, h, cells, seed, tile_x=True, tile_y=False):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for c in cells:
        out += vnoise(w, h, c, rng, tile_x, tile_y) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def fbm1(w, cells, seed):
    return fbm(w, 1, cells, seed)[0]


def save(img, name):
    Image.fromarray(img).save(os.path.join(OUT, name))


# ------------------------------------------------------------------ planets

def _sphere(r, squash=1.0, pad=2, extra_w=0, extra_h=0):
    S = 2 * r + 1 + 2 * pad
    W, H = S + 2 * extra_w, S + 2 * extra_h
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    x = (xs - (W - 1) / 2) / r
    y = (ys - (H - 1) / 2) / (r * squash)
    d2 = x * x + y * y
    inside = d2 <= 1.0
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    lam = np.clip(x * LIGHT[0] + (-y) * LIGHT[1] + z * LIGHT[2], 0, 1)
    lon = np.arctan2(x, z)
    lat = np.arcsin(np.clip(-y, -1, 1))
    return W, H, x, y, d2, inside, lam, lon, lat


def _tex_lookup(tex, lon, lat, spin=0.0):
    th, tw = tex.shape
    u = (((lon + spin) / (2 * math.pi)) % 1.0 * tw).astype(int) % tw
    v = np.clip(((lat / math.pi) + 0.5) * th, 0, th - 1).astype(int)
    return tex[th - 1 - v, u]


def planet(kind, r, seed=4):
    pad = 2
    if kind == "saturn":
        return saturn(r)
    W, H, x, y, d2, inside, lam, lon, lat = _sphere(r, pad=pad)
    d = dither(H, W)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    detail = 1.0 if r >= 12 else 0.6
    if kind == "moon":
        base = fbm(256, 128, [64, 32, 16, 8], seed, True, False)
        maria = fbm(256, 128, [128, 64, 32], seed + 1) > 0.56
        crat = np.zeros((128, 256))
        rng = np.random.default_rng(seed + 2)
        yy, xx = np.mgrid[0:128, 0:256]
        for _ in range(26):
            cx, cy, cr = rng.integers(0, 256), rng.integers(10, 118), rng.integers(3, 11)
            dd = np.sqrt(np.minimum(np.abs(xx - cx), 256 - np.abs(xx - cx)) ** 2 + (yy - cy) ** 2) / cr
            crat -= np.where(dd < 0.8, 0.22, 0)
            crat += np.where((dd >= 0.8) & (dd < 1.15), 0.18, 0)
        alb = 0.62 + 0.25 * (_tex_lookup(base, lon, lat) - 0.5) * detail + _tex_lookup(crat, lon, lat) * detail
        alb -= 0.2 * _tex_lookup(maria.astype(float), lon, lat)
        R = ramp("15151f", "2e2e3c", "4e4e60", "76768a", "a2a2b4", "cfcfdc")
        v = lam ** 0.8 * np.clip(alb, 0, 1.2)
        img[...] = R[quant(v, len(R), d, 0.9)]
    elif kind == "mars":
        base = fbm(256, 128, [64, 32, 16, 8], seed)
        dark = fbm(256, 128, [128, 64, 32], seed + 5)
        alb = 0.78 + 0.25 * (_tex_lookup(base, lon, lat) - 0.5) - 0.28 * (_tex_lookup(dark, lon, lat) > 0.57)
        R = ramp("1c0a08", "3e160e", "6a2616", "98391e", "c2582c", "e08450", "f2b07c")
        v = lam ** 0.85 * alb
        img[...] = R[quant(v, len(R), d, 0.9)]
        cap = np.abs(lat) > 1.22 + 0.08 * np.sin(lon * 3)
        C = ramp("4a4656", "9a98aa", "dcdce6", "fafafc")
        img[cap] = C[quant(lam[cap] ** 0.8, len(C), d[cap], 0.9)]
    elif kind == "earth":
        land = fbm(256, 128, [64, 32, 16, 8], seed + 11)
        cloud = fbm(256, 128, [32, 16, 8, 4], seed + 12)
        L = _tex_lookup(land, lon, lat) > 0.53
        Cl = _tex_lookup(cloud, lon, lat)
        O = ramp("06102e", "0c2458", "143e8a", "2264b8", "4a92da", "8cc4f2")
        G = ramp("0e1a0c", "1e3a16", "33621e", "5a8a2e", "92a650", "d0c890")
        v = lam ** 0.75
        img[...] = O[quant(v, len(O), d, 0.9)]
        img[L] = G[quant(v[L], len(G), d[L], 0.9)]
        ice = np.abs(lat) > 1.25
        CW = ramp("3a4660", "8a9ab8", "d6e0f0", "ffffff")
        cmask = (Cl > 0.61) | ice
        img[cmask] = CW[quant(v[cmask] * (0.7 + 0.5 * (Cl[cmask] - 0.5)), len(CW), d[cmask], 0.9)]
    img[~inside] = 0
    # atmosphere rim (Earth blue, Mars dusty) on the lit side
    if kind in ("earth", "mars"):
        rim = (d2 > 1.0) & (d2 <= (1.0 + 1.6 / r) ** 2)
        side = (x * LIGHT[0] - y * LIGHT[1]) > -0.25
        col = hexc("7ab8ff", 150) if kind == "earth" else hexc("e8a07a", 110)
        img[rim & side] = col
        edge = inside & (d2 > (1.0 - 1.4 / r) ** 2) & side
        img[edge, :3] = np.clip(img[edge, :3].astype(int) + (40 if kind == "earth" else 24), 0, 255)
    return img


def saturn(r):
    tilt = math.radians(-14)
    ring_out, rb = 2.3, 0.34
    S = int(2 * ring_out * r) + 6
    Hh = int(2 * r * 1.15) + 8
    ys, xs = np.mgrid[0:Hh, 0:S].astype(np.float64)
    X0 = (xs - (S - 1) / 2) / r
    Y0 = (ys - (Hh - 1) / 2) / r
    ct, st_ = math.cos(tilt), math.sin(tilt)
    x = X0 * ct - Y0 * st_
    y = X0 * st_ + Y0 * ct
    yp = y / 0.9
    d2 = x * x + yp * yp
    inside = d2 <= 1.0
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    lam = np.clip(x * LIGHT[0] + (-yp) * LIGHT[1] + z * LIGHT[2], 0, 1)
    lat = np.arcsin(np.clip(-yp, -1, 1))
    d = dither(Hh, S)
    band = 0.5 + 0.22 * np.sin(lat * 9.0) + 0.12 * np.sin(lat * 23.0 + 1.0) + 0.06 * np.sin(lat * 41.0)
    band += 0.05 * np.sin(x * 9 + lat * 30)
    P = ramp("2a1e10", "54401e", "86683a", "b8945a", "dcbc7c", "f0dca8", "fbf2d4")
    img = np.zeros((Hh, S, 4), dtype=np.uint8)
    v = lam ** 0.75 * (0.55 + 0.5 * band)
    planet_px = P[quant(v, len(P), d, 0.9)]
    # rings
    rr = np.sqrt(x * x + (y / rb) ** 2)
    dens = np.zeros_like(rr)
    dens += np.where((rr > 1.24) & (rr < 1.52), 0.28, 0)          # C ring
    dens += np.where((rr >= 1.52) & (rr < 1.95), 0.9 - 0.25 * ((rr - 1.52) / 0.43), 0)  # B ring
    dens += np.where((rr >= 2.03) & (rr < 2.27), 0.55, 0)          # A ring
    dens *= np.where((rr > 2.19) & (rr < 2.21), 0.0, 1.0)          # Encke gap
    dens *= 0.85 + 0.15 * np.sin(rr * 60)
    ring = dens > 0.05
    RR = ramp("3e3424", "6e5e40", "a49070", "d2c09a", "efe2c0")
    lit = np.where(x < 0, 1.0, 0.85)
    ring_px = RR[quant(np.clip(dens * lit, 0, 1), len(RR), d, 0.9)]
    ring_px[..., 3] = np.clip(80 + dens * 200, 0, 255).astype(np.uint8)
    back = ring & (y < 0)
    front = ring & (y >= 0)
    # planet shadow falls on the rings behind it to the lower right of the light
    shadow = ring & (np.abs(x - 0.0) < 1.0) & (y < 0) & (x > 0.2)
    img[back] = ring_px[back]
    img[shadow, :3] = (img[shadow, :3] * 0.45).astype(np.uint8)
    img[inside] = planet_px[inside]
    # ring shadow on the planet: just below the front ring's inner edge
    rs = inside & (np.abs(np.sqrt(x * x + ((y - 0.22) / rb) ** 2) - 1.75) < 0.22) & (y > 0)
    img[rs, :3] = (img[rs, :3] * 0.6).astype(np.uint8)
    img[front & ~(inside & (rr < 1.0))] = ring_px[front & ~(inside & (rr < 1.0))]
    a = img[..., 3] > 0
    ys_, xs_ = np.where(a)
    return img[ys_.min():ys_.max() + 1, xs_.min():xs_.max() + 1]


# ------------------------------------------------------------------ space

def space_bg(w=640, h=360, seed=7):
    d = dither(h, w)
    neb = fbm(w, h, [160, 80, 40, 20, 10], seed, True, True)
    neb2 = fbm(w, h, [128, 64, 32, 16], seed + 3, True, True)
    grad = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    band = np.exp(-((np.linspace(-1, 1, h)[:, None] * 1.4 + 0.3 * np.sin(np.linspace(0, 2 * np.pi, w))[None, :]) ** 2) * 2.5)
    v = np.clip((neb - 0.46) * 1.7, 0, 1) * band * 0.7 + 0.06 * grad
    V = ramp("06070f", "090b18", "0e1024", "151632", "1e1a40", "2a2050")
    img = V[quant(v, len(V), d, 1.0)]
    rng = np.random.default_rng(seed + 9)
    for _ in range(520):
        sx, sy = rng.integers(0, w), rng.integers(0, h)
        b = rng.random() ** 3
        c = int(70 + 185 * b)
        tint = rng.choice([(1, 1, 1), (0.8, 0.9, 1.0), (1.0, 0.9, 0.75)])
        img[sy, sx, :3] = [int(c * t) for t in tint]
    for _ in range(14):
        sx, sy = rng.integers(2, w - 2), rng.integers(2, h - 2)
        img[sy, sx, :3] = 255
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            img[sy + dy, sx + dx, :3] = (150, 170, 220)
    img[..., 3] = 255
    return img


# ------------------------------------------------------------------ horizons

def ridge_layer(w, h, base, amp, cells, seed, fill, rim, shade=None, mesa=False, strata=None):
    hp = fbm1(w, cells, seed)
    if mesa:
        hp = np.round(hp * 5) / 5 * 0.85 + hp * 0.15
        k = np.ones(9) / 9  # sloped mesa sides
        hp = np.convolve(np.concatenate([hp[-4:], hp, hp[:4]]), k, mode="valid")
    top = (base - amp * (hp - 0.5) * 2).astype(int)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    d = dither(h, w)
    ys = np.arange(h)[:, None]
    body = ys >= top[None, :]
    depth = np.clip((ys - top[None, :]) / max(1, h - top.min()), 0, 1)
    F = ramp(*fill)
    idx = quant(1 - depth * 0.9, len(F), d, 0.8)
    img[body] = F[idx][body]
    if strata is not None:
        sn = fbm(w, h, [80, 40], seed + 4)
        stripe = (((ys + (sn * 6).astype(int)) // 5) % 3 == 0) & body
        img[stripe, :3] = (img[stripe, :3] * strata).astype(np.uint8)
    # lit faces: where the skyline rises to the right it faces the light
    slope = np.roll(top, 1) - top
    for xx in range(w):
        t0 = top[xx]
        if 0 <= t0 < h:
            img[t0, xx] = rim
            if slope[xx] > 0 and t0 + 1 < h:
                img[t0 + 1, xx] = rim
            elif shade is not None and slope[xx] < 0:
                for k in range(1, min(4, h - t0)):
                    img[t0 + k, xx] = shade
    return img


def ground_tex(w, h, seed, R, pebble, n_peb=16):
    d = dither(h, w)
    v = fbm(w, h, [32, 16, 8, 4], seed, True, True)
    img = R[quant(v, len(R), d, 1.0)]
    rng = np.random.default_rng(seed + 1)
    P = np.array(pebble, dtype=np.uint8)
    for _ in range(n_peb):
        cx, cy = rng.integers(0, w), rng.integers(0, h)
        rx, ry = rng.integers(1, 4), rng.integers(1, 3)
        for yy in range(-ry, ry + 1):
            for xx in range(-rx, rx + 1):
                if (xx / (rx + 0.5)) ** 2 + (yy / (ry + 0.5)) ** 2 <= 1:
                    k = 2 if (xx + yy) < 0 else (1 if (xx + yy) == 0 else 0)
                    img[(cy + yy) % h, (cx + xx) % w] = P[k]
        img[(cy + ry + 1) % h, (cx + np.arange(-rx, rx + 1)) % w] = P[0] // 2 + R[0] // 2
    img[..., 3] = 255
    return img


def rock(w, h, seed, R, outline, full=False):
    """A boulder lit from the upper left: sitting on the ground (flat bottom), or `full` (floating)."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    cx, cy = (w - 1) / 2, ((h - 1) / 2 if full else h - 1)
    ang = np.arctan2(ys - cy, xs - cx)
    wob = 1 + 0.08 * np.sin(ang * 3 + rng.random() * 6) + 0.05 * np.sin(ang * 7 + rng.random() * 6)
    nx = (xs - cx) / (w / 2 - 1)
    ny = (ys - cy) / ((h / 2 - 1) if full else (h - 2))
    inside = (np.abs(nx) ** 2.6 + np.abs(ny) ** 2.6) <= wob ** 2.6
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    facet = np.round((fbm(w, h, [10, 5], seed + 2, False, False) - 0.5) * 4) / 4
    lam = np.clip(nx * LIGHT[0] - ny * LIGHT[1] + nz * LIGHT[2] + facet * 0.7, 0, 1)
    d = dither(h, w)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[...] = R[quant(lam, len(R), d, 0.5)]
    img[~inside] = 0
    a = img[..., 3] > 0
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if not a[y, x] and any(0 <= y + dy < h and 0 <= x + dx < w and a[y + dy, x + dx] for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y, x] = outline
    return out


def cloud(w, h, seed):
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    m = np.zeros((h, w), bool)
    sh = np.zeros((h, w))
    for _ in range(7):
        cx, cy = rng.uniform(w * 0.2, w * 0.8), rng.uniform(h * 0.45, h * 0.75)
        rr = rng.uniform(h * 0.22, h * 0.42)
        dd = ((xs - cx) ** 2 + ((ys - cy) * 1.2) ** 2) / rr ** 2
        m |= dd < 1
        sh = np.maximum(sh, np.clip(1 - dd, 0, 1) * (1 - (ys - (cy - rr)) / (2 * rr)))
    m &= ys < h * 0.82
    C = ramp("8aa0c8", "bccbe4", "e6edf8", "ffffff")
    d = dither(h, w)
    img[...] = C[quant(np.clip(sh * 1.6 + 0.15, 0, 1), len(C), d, 0.8)]
    img[~m] = 0
    img[m, 3] = 230
    return img


def launch_sky(w, h):
    d = dither(h, w)
    g = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    S = ramp("1d3c86", "24509e", "2e64b4", "3c7cc8", "5494d8", "74aee4", "9cc8ee", "c4def4")
    img = S[quant(g ** 1.3, len(S), d, 1.0)]
    # sun glow upper left
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    sd = np.sqrt((xs - 330) ** 2 + (ys - 70) ** 2)
    glow = np.clip(1 - sd / 22, 0, 1) * 0.8
    gm = glow > 0.15
    Gw = ramp("8cc0ec", "b8daf4", "e2f0fa", "fffbe8")
    img[gm] = Gw[quant(glow[gm], len(Gw), d[gm], 1.0)]
    img[sd < 5] = hexc("fffbe8")
    img[..., 3] = 255
    return img


def tower(h=120):
    w = 18
    img = np.zeros((h, w, 4), dtype=np.uint8)
    dark, mid, lit = hexc("5a2416"), hexc("8e3a22"), hexc("c8643a")
    for y in range(h):
        img[y, 1] = lit
        img[y, 2] = mid
        img[y, 12] = mid
        img[y, 13] = dark
    for y in range(0, h, 10):
        for x in range(1, 14):
            img[y, x] = mid
        for k in range(10):
            xx = 2 + int(k * 1.1)
            if y + k < h:
                img[y + k, xx] = dark
    for y in (30, 60, 90):  # service arms reaching toward the rocket
        img[y:y + 3, 13:18] = mid
        img[y, 13:18] = lit
    return img


def launch_ground(w, h):
    d = dither(h, w)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ys = np.arange(h)[:, None] * np.ones((1, w))
    xs = np.ones((h, 1)) * np.arange(w)[None, :]
    sea = ys < 14
    S = ramp("1a4a7c", "2a64a0", "4486c0", "7ab0dc")
    img[sea] = S[quant(1 - ys[sea] / 14, len(S), d[sea], 1.0)]
    shimmer = sea & (((xs + ys * 3).astype(int) % 23) == 0)
    img[shimmer] = hexc("cfe6f6")
    hill = fbm1(w, [80, 40, 20], 31)
    top = 10 + (hill * 10).astype(int)
    G = ramp("1c3a1a", "2a5226", "3a6c2e", "54883a", "78a44a")
    n = fbm(w, h, [16, 8, 4], 32)
    land = ys >= top[None, :]
    img[land] = G[quant(np.clip(n * 0.8 + (1 - (ys - 10) / h) * 0.4, 0, 1), len(G), d, 1.0)][land]
    # concrete pad
    pad = (ys >= 26) & (xs > 130) & (xs < 270)
    C = ramp("4a4e5a", "6c707c", "8e929c", "b0b4bc")
    img[pad] = C[quant(np.clip(0.75 - (ys[pad] - 26) / 80 + n[pad] * 0.2, 0, 1), len(C), d[pad], 1.0)]
    img[26, 131:270] = hexc("c8ccd4")
    img[..., 3] = 255
    return img


def saturn_clouds(w=640, h=110):
    d = dither(h, w)
    ys = np.arange(h)[:, None] * np.ones((1, w))
    n = fbm(w, h, [80, 40, 20, 10], 51, True, False)
    warp = fbm(w, h, [160, 64], 52, True, False)
    band = 0.5 + 0.3 * np.sin((ys + warp * 18) * 0.16) + 0.15 * np.sin((ys + n * 10) * 0.41)
    v = np.clip(band * 0.7 + n * 0.4 - ys / h * 0.35, 0, 1)
    P = ramp("2a1e10", "4e3a1c", "7a5e30", "a8844c", "cfab6a", "e8cc8e", "f6e6b8")
    img = P[quant(v, len(P), d, 1.0)]
    img[..., 3] = 255
    return img


def ring_band(w=640, h=72):
    d = dither(h, w)
    ys = np.arange(h)[:, None] * np.ones((1, w))
    streak = fbm(w, h, [320, 160, 80], 61, True, False)
    rows = fbm(1, h, [8, 4, 2], 62, False, False)[:, 0][:, None]
    dens = np.clip(rows * 1.3 - 0.25 + (streak - 0.5) * 0.25, 0, 1)
    dens *= np.clip(np.minimum(ys, h - 1 - ys) / 6, 0, 1)
    R = ramp("54483a", "8a7a5e", "bcac88", "e6d8b4", "fff4dc")
    img = R[quant(dens, len(R), d, 1.0)]
    img[..., 3] = np.clip(dens * 150, 0, 255).astype(np.uint8)
    rng = np.random.default_rng(63)
    for _ in range(260):  # ice glints
        x, y = rng.integers(0, w), rng.integers(2, h - 2)
        if dens[y, x] > 0.25:
            img[y, x] = hexc("f4fbff", 220)
    return img


def sky(w, h, R):
    d = dither(h, w)
    g = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    img = R[quant(g ** 0.9, len(R), d, 1.0)]
    img[..., 3] = 255
    return img


def sample_rock(kind):
    R = ramp("3a3a46", "6a6a7a", "9a9aac", "c8c8d6") if kind == "moon" else ramp("3a1810", "6e3020", "a04e32", "d07a50")
    img = rock(12, 8, 77 if kind == "moon" else 78, R, hexc("0c0a14"))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind in ("earth", "moon", "mars", "saturn"):
        for r in (9, 12, 22, 36, 60):
            save(planet(kind, r), "planet_%s_%d.png" % (kind, r))
    save(space_bg(), "bg_space.png")
    # Moon horizon (no air: crisp but dim), Mars (dusty haze, mesas)
    save(ridge_layer(640, 110, 50, 34, [160, 80, 40, 20], 101,
                     ["1a1b26", "222432", "2a2d3e"], hexc("4e526a"), hexc("15161f")), "moon_far.png")
    save(ridge_layer(640, 90, 38, 22, [128, 64, 32, 16, 8], 102,
                     ["2a2c38", "363948", "44475a", "52566a"], hexc("8a8ea6"), hexc("22232e")), "moon_mid.png")
    save(ridge_layer(640, 110, 56, 30, [160, 80, 40], 201,
                     ["7a4a3e", "86523e", "925a42"], hexc("c08a6a"), None, mesa=True, strata=0.92), "mars_far.png")
    save(ridge_layer(640, 90, 40, 20, [128, 64, 32, 16], 202,
                     ["5a2618", "6c2e1c", "7e3822", "8e4228"], hexc("c87a4e"), hexc("4a1e14")), "mars_mid.png")
    save(ground_tex(128, 64, 301, ramp("3e3e4a", "4c4c5a", "5a5a6a", "686878"),
                    [hexc("4a4a58"), hexc("8a8a9c"), hexc("b4b4c4")]), "ground_moon.png")
    save(ground_tex(128, 64, 302, ramp("5a2414", "6a2c18", "7a341c", "8a3e22"),
                    [hexc("4a1c10"), hexc("a85a34"), hexc("d08858")]), "ground_mars.png")
    rm = ramp("2a2a36", "4a4a58", "6e6e80", "9a9aac", "c4c4d2")
    rr = ramp("3a1410", "5e2418", "8a3a22", "b45a34", "d8845a")
    ol = hexc("0c0a14")
    for h in (14, 30):
        save(rock(40, h + 10, 400 + h, rm, ol), "rock_moon_%d.png" % h)
        save(rock(40, h + 10, 500 + h, rr, ol), "rock_mars_%d.png" % h)
    rg = ramp("2e2a30", "4e4852", "766e78", "a49ca4", "d0c8cc")
    for i, dia in enumerate((12, 16, 20, 22)):
        img = rock(dia, dia, 600 + i, rg, ol, full=True)
        save(img, "rock_ring_%d.png" % dia)
    save(sample_rock("moon"), "sample_moon.png")
    save(sample_rock("mars"), "sample_mars.png")
    save(launch_sky(430, 360), "launch_sky.png")
    save(launch_ground(430, 90), "launch_ground.png")
    save(tower(), "tower.png")
    for i in range(3):
        save(cloud(56 + i * 10, 22 + i * 3, 700 + i), "cloud_%d.png" % i)
    save(saturn_clouds(), "saturn_clouds.png")
    save(ring_band(), "ring_band.png")
    save(sky(640, 300, ramp("4e3224", "6a4430", "88583e", "a46e4e", "c08a60", "d8a676", "e8c090")), "mars_sky_day.png")
    save(sky(640, 300, ramp("05040a", "0a0812", "110c1a", "1a1220", "261824")), "mars_sky_night.png")
    print("BG DONE")


if __name__ == "__main__":
    main()
