"""Effects kit sprite sheets (flames, smoke, explosions, sparkles, glows, suns, rings, trails, beams).

    python tools/art/gen_fx.py            # writes art/fx/*.png
    python tools/art/gen_fx.py preview    # also writes 4x preview sheets to research/work/fx/

Everything is 1 art pixel = 1 game pixel, hard-edged, small palettes, no blur: soft edges and fades are
ordered dither. scripts/fx.gd reads these sheets; the layout numbers below (FLAME_W, FLAME_M, PUFF_CELL,
...) are repeated there as constants, so change both together.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "fx")
WORK = os.path.join(os.path.dirname(ROOT), "research", "work", "fx")

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def bayer(h, w, ox=0, oy=0):
    """Ordered dither thresholds in (0,1), tiled over an h x w area."""
    ys, xs = np.mgrid[0:h, 0:w]
    return (BAYER4[(ys + oy) % 4, (xs + ox) % 4] + 0.5) / 16.0


def vnoise(h, w, cell, seed):
    """Smooth value noise 0..1."""
    rng = np.random.default_rng(seed)
    gh, gw = int(h / cell) + 2, int(w / cell) + 2
    g = rng.random((gh, gw))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    fx, fy = xs / cell, ys / cell
    ix, iy = fx.astype(int), fy.astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[iy, ix] * (1 - tx) + g[iy, ix + 1] * tx
    b = g[iy + 1, ix] * (1 - tx) + g[iy + 1, ix + 1] * tx
    return a * (1 - ty) + b * ty


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))


def paste(dst, src, x, y):
    dst[y:y + src.shape[0], x:x + src.shape[1]] = src


# ------------------------------------------------------------------ engine flame
# One sheet per nozzle width. Columns are the 8 animation frames, rows are plume lengths
# (FLAME_M4 x width / 4), then one last row: the repeating body tile for plumes longer than the longest row.

FLAME_W = [3, 5, 8, 11, 14, 20, 30]
FLAME_M4 = [3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 22, 24]  # plume lengths in quarter widths
FLAME_FRAMES = 8
FLAME_COLS = ["9a2c14", "d04a1c", "f08a2a", "ffc83a", "fff3b0", "ffffff"]  # tip red-brown .. white-hot core
LAYER_W = [1.0, 1.0, 0.84, 0.64, 0.44, 0.26]   # half-width of each tone, as a share of the plume
LAYER_L = [1.0, 0.86, 0.74, 0.60, 0.45, 0.31]  # how far down the plume each tone reaches
LEN_FLICK = [1.0, 0.86, 0.95, 0.80, 0.98, 0.88, 0.92, 0.78]


def flame_pad(w):
    return max(2, (w + 2) // 4)


def flame_period(w):
    """Spacing of the shock diamonds = height of the repeating body tile (FLAME_PERIOD in fx.gd)."""
    return max(3, (17 * w + 10) // 20)


def flame_split(w):
    """Row of the longest plume where body tiles are inserted (FLAME_SPLIT in fx.gd)."""
    return (3 * w + 1) // 2


def flame_lengths(w):
    return [max(2, (m * w + 2) // 4) for m in FLAME_M4]


def flame_cell(w, length, f, tile=False, cols=FLAME_COLS):
    """One frame of a plume pointing down, nozzle on the top row. tile=True: the repeating body slice."""
    pad = flame_pad(w)
    cw = w + 2 * pad
    p = flame_period(w)
    full = flame_lengths(w)[-1]
    h = p if tile else length
    L = full if tile else length
    ys, xs = np.mgrid[0:h, 0:cw].astype(np.float64)
    yp = ys + flame_split(w) if tile else ys          # pattern coordinate: diamonds, waves
    ysh = np.full_like(ys, flame_split(w)) if tile else ys  # shape coordinate: taper
    cx = (cw - 1) / 2.0
    lf = L * LEN_FLICK[f]
    ph = f / float(FLAME_FRAMES)
    u0 = np.clip(ysh / lf, 0, 1.2)
    sway = w * 0.07 * u0 ** 2 * np.sin(2 * math.pi * (ph + 0.7 * u0))
    dx = xs - cx - sway
    flare = 0.80 + 0.20 * np.clip(ysh / max(1.0, 0.35 * w), 0, 1)
    long_plume = L >= 3 * w and w >= 11
    idx = np.full((h, cw), -1, dtype=int)
    for i in range(len(cols)):
        u = ysh / (lf * LAYER_L[i])
        taper = np.clip(1 - np.clip(u, 0, 1) ** 1.7, 0, 1) ** 0.72
        hw = (w / 2.0) * LAYER_W[i] * flare * taper
        amp = w * (0.015 + 0.11 * np.clip(u, 0, 1)) * (1.0 if i < 2 else 0.55)
        wl = np.sin(2 * math.pi * (yp / p - 3 * ph) + 1.3 + i) + 0.3 * np.sin(2 * math.pi * (2 * yp / p - 5 * ph) + 0.4)
        wr = np.sin(2 * math.pi * (yp / p - 3 * ph) - 2.1 - i) + 0.3 * np.sin(2 * math.pi * (2 * yp / p - 5 * ph) + 2.9)
        if long_plume and i >= 4:
            hw = hw * 0.55  # the core thins to a thread; the shock diamonds below carry the white
        inside = (u < 1) & (dx > -(hw + amp * wl)) & (dx < hw + amp * wr) & (hw > (0.9 if w >= 8 else 0.4))
        idx[inside] = i
    if long_plume:
        # shock diamonds: a chain of white rhombi down the centre line, shrinking with distance
        k = 0
        while True:
            yc = 0.55 * w + k * p
            a = w * 0.27 * 0.84 ** k * (1.0 if (f + k) % 3 else 0.86)
            b = p * 0.42
            if a < 0.9 or (not tile and yc + b > lf * 0.68):
                break
            if tile and yc - b > flame_split(w) + p:
                break
            d = np.abs(xs - cx) / a + np.abs(yp - yc) / b
            rim = np.abs(xs - cx) / (a + 1.0) + np.abs(yp - yc) / (b + 1.0)
            idx[(rim < 1) & (idx >= 2) & (idx < 4)] = 4
            idx[(d < 1) & (idx >= 2)] = 5
            k += 1
    if not tile:
        # hot nozzle exit: one or two rows of white right under the bell
        rows = 1 if w < 11 else 2
        hot = (ys < rows) & (np.abs(dx) < w * 0.5 * 0.80 * 0.72) & (idx >= 0)
        idx[hot] = np.maximum(idx[hot], 4 if w < 8 else 5)
        # ragged tip: a few detached licks below and beside the tip
        if length >= 1.5 * w and w >= 5:
            rng = np.random.default_rng(w * 1000 + length * 10 + f)
            for _ in range(2 + w // 6):
                ly = int(rng.uniform(0.62, 1.0) * lf)
                uu = ly / lf
                span = (w / 2.0) * (1 - uu ** 1.7) ** 0.72 + w * 0.12
                lx = int(round(cx + rng.uniform(-1, 1) * span + w * 0.07 * uu ** 2 * math.sin(2 * math.pi * (ph + 0.7 * uu))))
                lh = 1 + int(rng.integers(0, 1 + w // 8))
                lw = 1 if w < 14 else int(rng.integers(1, 3))
                c = 0 if uu > 0.8 or rng.random() < 0.5 else 1
                y0, y1, x0, x1 = ly, min(h, ly + lh), max(0, lx), min(cw, lx + lw)
                sub = idx[y0:y1, x0:x1]
                sub[sub < 0] = c
    img = np.zeros((h, cw, 4), dtype=np.uint8)
    for i, c in enumerate(cols):
        img[idx == i] = hexc(c)
    return img


def flame_sheet(w, cols=FLAME_COLS):
    cw = w + 2 * flame_pad(w)
    lens = flame_lengths(w)
    p = flame_period(w)
    sheet = np.zeros((sum(lens) + p, cw * FLAME_FRAMES, 4), dtype=np.uint8)
    y = 0
    for length in lens:
        for f in range(FLAME_FRAMES):
            paste(sheet, flame_cell(w, length, f, cols=cols), f * cw, y)
        y += length
    for f in range(FLAME_FRAMES):
        paste(sheet, flame_cell(w, 0, f, tile=True, cols=cols), f * cw, y)
    return sheet


# ------------------------------------------------------------------ lobed clouds (smoke, fireballs)

LIGHT = np.array([-0.55, -0.66, 0.51])  # from the upper left, towards the viewer (screen y points down)


def make_lobes(seed, n):
    """Unit-size lobe set: n satellites around a centre ball. Rows of (angle, distance, radius, spin)."""
    rng = np.random.default_rng(seed)
    out = []
    for j in range(n):
        ang = 2 * math.pi * (j + rng.uniform(-0.3, 0.3)) / n
        out.append((ang, rng.uniform(0.44, 0.62), rng.uniform(0.28, 0.42), rng.uniform(-1, 1)))
    return out


def cloud(cell_w, cell_h, cx, cy, radius, lobes, spread, turn, shrink=1.0, core=0.60, flat=0.5):
    """Heightfield of overlapping balls. Returns (inside mask, light -1..1, depth 0..1 inside each ball).
    Ball centres snap to half pixels so small balls stay round. `flat` blends each ball's own shading
    with one shading for the whole cloud (0 = lumpy, 1 = one smooth ball)."""
    ys, xs = np.mgrid[0:cell_h, 0:cell_w].astype(np.float64)
    hmax = np.zeros((cell_h, cell_w))
    lam = np.zeros((cell_h, cell_w))
    depth = np.zeros((cell_h, cell_w))
    balls = [(cx, cy, radius * core)]
    for ang, dist, rad, spin in lobes:
        a = ang + turn * spin
        balls.append((cx + math.cos(a) * dist * radius * spread, cy + math.sin(a) * dist * radius * spread, rad * radius * shrink))
    for bx, by, br in balls:
        if br < 0.7:
            continue
        bx, by = round(bx * 2) / 2.0, round(by * 2) / 2.0
        d2 = (xs - bx) ** 2 + (ys - by) ** 2
        z = np.sqrt(np.clip(br * br + 0.3 - d2, 0, None))
        l = ((xs - bx) * LIGHT[0] + (ys - by) * LIGHT[1] + z * LIGHT[2]) / br
        top = z > hmax
        lam[top] = l[top]
        hmax = np.maximum(hmax, z)
        depth = np.maximum(depth, z / br)
    whole = ((xs - cx) * LIGHT[0] + (ys - cy) * LIGHT[1]) / max(1.0, radius) + 0.15
    return hmax > 0, flat * whole + (1 - flat) * lam, np.clip(depth, 0, 1)


def dissolve(mask, depth, amount, seed, cell=3.0, grain=0.22):
    """Eat a cloud away from its rim and from noise holes with ordered dither. amount 0 keeps all, 1 removes all.
    `grain` is the share of pure dither: low breaks the cloud into lumps, high thins it into a dithered veil."""
    if amount <= 0:
        return mask
    h, w = mask.shape
    ys, xs = np.mgrid[0:h, 0:w]
    radial = np.clip(1.0 - np.hypot(xs - (w - 1) / 2.0, ys - (h - 1) / 2.0) / (0.5 * min(h, w)), 0, 1)
    solid = 0.30 * depth + 0.25 * radial + 0.45 * vnoise(h, w, cell, seed)
    thr = (1.0 - grain) * solid + grain * bayer(h, w)
    return mask & (thr > amount)


# ------------------------------------------------------------------ smoke and dust puffs
# puff_<size>.png: 8 frames across, 2 shape variants down. Greys only: the game multiplies by a tint.

PUFF_CELL = [10, 16, 30]
PUFF_R = [3.6, 6.6, 12.6]
PUFF_FRAMES = 8
PUFF_TONES = [(255, 255, 255, 255), (208, 212, 226, 255), (158, 164, 188, 255), (116, 122, 150, 255)]
PUFF_GROW = [0.44, 0.60, 0.74, 0.85, 0.93, 1.0, 1.05, 1.08]
PUFF_GONE = [0.0, 0.0, 0.0, 0.06, 0.16, 0.28, 0.42, 0.58]
PUFF_SPREAD = [0.55, 0.70, 0.82, 0.92, 1.0, 1.08, 1.15, 1.22]
PUFF_CORE = [0.66, 0.64, 0.62, 0.60, 0.58, 0.56, 0.54, 0.52]
PUFF_LOBE = [1.0, 1.0, 1.0, 1.0, 1.0, 0.98, 0.95, 0.92]


def puff_cell(size, f, variant):
    cell, R = PUFF_CELL[size], PUFF_R[size]
    lobes = make_lobes(40 + size * 7 + variant * 13, [5, 7, 8][size])
    c = (cell - 1) / 2.0
    k = f / (PUFF_FRAMES - 1.0)
    mask, lam, depth = cloud(cell, cell, c, c, R * PUFF_GROW[f], lobes, PUFF_SPREAD[f], 0.5 * k,
                             PUFF_LOBE[f] * [0.8, 0.9, 1.0][size], PUFF_CORE[f] * [1.12, 1.05, 1.0][size], [0.75, 0.6, 0.45][size])
    mask = dissolve(mask, depth, PUFF_GONE[f], 300 + size * 10 + variant, 2.0 + size, 0.34)
    hi = 0.22 + 0.5 * k           # the highlight shrinks as the puff cools and thins
    tone = np.where(lam > hi, 0, np.where(lam > -0.16, 1, 2))
    if size > 0:
        tone = np.where(lam < -0.56, 3, tone)
    if f == 0:
        tone = np.minimum(tone, 1)
    img = np.zeros((cell, cell, 4), dtype=np.uint8)
    for i, col in enumerate(PUFF_TONES):
        img[mask & (tone == i)] = col
    return img


def puff_sheet(size):
    cell = PUFF_CELL[size]
    sheet = np.zeros((cell * 2, cell * PUFF_FRAMES, 4), dtype=np.uint8)
    for v in range(2):
        for f in range(PUFF_FRAMES):
            paste(sheet, puff_cell(size, f, v), f * cell, v * cell)
    return sheet


# ------------------------------------------------------------------ explosion
# boom_<size>.png: 10 frames across. Flash, fireball, ring shockwave and sparks, then dark smoke.

BOOM_CELL = [32, 64, 112]
BOOM_R = [10, 20, 36]
BOOM_FRAMES = 10
FIRE = ["ffffff", "fff3b0", "ffc83a", "f08a2a", "d04a1c", "8c2416"]
FIRE_AT = [0.86, 0.70, 0.52, 0.36, 0.22, 0.10]
SMOKE = ["8e8799", "625b6e", "433c4e", "2a2433"]
BOOM_SCALE = [0.0, 0.88, 1.0, 1.08, 1.13, 1.17, 1.21, 1.25, 1.29, 1.33]
BOOM_HEAT = [0.0, 0.62, 0.34, 0.10, -0.10, -0.30, -0.50, -0.68, -0.9, -0.9]
BOOM_SEAM = [0.0, 0.0, 0.0, 0.2, 0.6, 1.0, 1.2, 1.2, 0.0, 0.0]
BOOM_GONE = [0.0, 0.0, 0.0, 0.0, 0.0, 0.04, 0.12, 0.24, 0.40, 0.58]
BOOM_SPREAD = [0.0, 0.62, 0.74, 0.84, 0.92, 1.0, 1.08, 1.17, 1.27, 1.38]
BOOM_CORE = [0.0, 0.62, 0.62, 0.62, 0.60, 0.58, 0.54, 0.46, 0.36, 0.24]
BOOM_LOBE = [0.0, 1.0, 1.0, 1.0, 1.0, 0.98, 0.92, 0.82, 0.70, 0.56]
BOOM_RISE = [0.0, 0.0, 0.0, 0.02, 0.05, 0.09, 0.14, 0.20, 0.27, 0.34]
BOOM_RING = [None, None, (1.20, 1, 0.75, 1), (1.42, 1, 0.5, 2), (1.56, 1, 0.25, 3)]


def boom_cell(size, f):
    cell, R = BOOM_CELL[size], float(BOOM_R[size])
    c = (cell - 1) / 2.0
    ys, xs = np.mgrid[0:cell, 0:cell].astype(np.float64)
    dist = np.hypot(xs - c, ys - c)
    img = np.zeros((cell, cell, 4), dtype=np.uint8)
    by = bayer(cell, cell)
    if f == 0:
        # flash: a white burst with four tapered spikes and a pale rim
        ang = np.arctan2(ys - c, xs - c)
        star = 0.46 * R + 0.5 * R * np.abs(np.cos(2 * ang)) ** 10 + 0.16 * R * np.abs(np.cos(4 * ang + 0.6)) ** 6
        img[dist < star + 1.0] = hexc(FIRE[1])
        img[dist < star] = hexc(FIRE[0])
        return img
    # ring shockwave, behind the fireball
    if f < len(BOOM_RING) and BOOM_RING[f] is not None:
        rr, th, dens, ci = BOOM_RING[f]
        ring = (np.abs(dist - rr * R) < th * 0.5) & (by <= dens)
        img[ring] = hexc(FIRE[ci])
    # flying sparks: short radial streaks that outrun the fireball
    rng = np.random.default_rng(900 + size)
    n = [6, 8, 11][size]
    for j in range(n):
        a = 2 * math.pi * (j + rng.uniform(-0.45, 0.45)) / n + 0.4
        v = rng.uniform(0.16, 0.40)
        ln = rng.uniform(0.4, 1.6) * [4.0, 6.0, 9.0][size] * max(0.25, 1.0 - 0.14 * f)
        head = R * (0.55 + v * f * (1.0 - 0.045 * f))
        if f > 5 or head > c - 1:
            continue
        for s in np.arange(0.0, ln, 0.5):
            px, py = int(round(c + math.cos(a) * (head - s))), int(round(c + math.sin(a) * (head - s)))
            if 0 <= px < cell and 0 <= py < cell:
                heat = min(5, max(0, f - 2) + (2 if s > ln * 0.45 else 0))
                img[py, px] = hexc(FIRE[heat])
    # fireball turning into smoke: soot lobes with a lit upper-left face, a shadow crescent and dark seams
    # between the lobes; the fire shrinks back into those seams before it goes out
    k = (f - 1) / (BOOM_FRAMES - 2.0)
    lobes = make_lobes(70 + size * 5, [6, 8, 11][size])
    cy = c - BOOM_RISE[f] * R
    mask, lam, depth = cloud(cell, cell, c, cy, R * BOOM_SCALE[f], lobes, BOOM_SPREAD[f], 0.6 * k, BOOM_LOBE[f], BOOM_CORE[f], 0.25)
    mask = dissolve(mask, depth, BOOM_GONE[f], 500 + size, 2.0 + size * 1.5, 0.3)
    hot = np.hypot(xs - (c - 0.08 * R), ys - (cy + 0.10 * R)) / (R * BOOM_SCALE[f])
    seam = np.clip(0.62 - depth, 0, 1) * np.clip(1.25 - hot, 0, 1)
    heat = BOOM_HEAT[f] + 0.62 * (1 - hot) + 0.46 * (vnoise(cell, cell, 2.0 + size * 1.5, 77 + size + f // 2) - 0.5) + BOOM_SEAM[f] * seam
    tone = np.where(lam > 0.42, 0, np.where(lam > -0.12, 1, np.where(lam > -0.52, 2, 3)))
    if size > 0:
        tone = np.minimum(3, tone + (depth < 0.30))
    for i, col in enumerate(SMOKE):
        img[mask & (tone == i)] = hexc(col)
    for i in range(len(FIRE) - 1, -1, -1):
        img[mask & (heat > FIRE_AT[i])] = hexc(FIRE[i])
    return img


def boom_sheet(size):
    cell = BOOM_CELL[size]
    sheet = np.zeros((cell, cell * BOOM_FRAMES, 4), dtype=np.uint8)
    for f in range(BOOM_FRAMES):
        paste(sheet, boom_cell(size, f), f * cell, 0)
    return sheet


# ------------------------------------------------------------------ debris chunks
# debris.png: 4 shapes across, 4 quarter turns down, 5x5 cells.

DEBRIS = [
    ["..#..", ".##o.", ".###.", "..#..", "....."],
    [".....", ".oo..", ".###.", "..##.", "....."],
    [".....", "..o..", ".##..", ".....", "....."],
    ["...o.", "..#..", ".#...", ".....", "....."],
]


def debris_sheet():
    sheet = np.zeros((20, 20, 4), dtype=np.uint8)
    for i, rows in enumerate(DEBRIS):
        cell = np.zeros((5, 5, 4), dtype=np.uint8)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    cell[y, x] = hexc("3a3f52")
                elif ch == "o":
                    cell[y, x] = hexc("c9cfdc")
        for r in range(4):
            paste(sheet, np.rot90(cell, -r), i * 5, r * 5)
    return sheet


# ------------------------------------------------------------------ sparkle
# sparkle_<size>.png: 6 frames across; row 0 is tinted by the game, row 1 is the white-hot centre.

SPARK_R = [3, 5, 8]
SPARK_FRAMES = 6


def sparkle_sheet(size):
    R = SPARK_R[size]
    cell = 2 * R + 1
    sheet = np.zeros((cell * 2, cell * SPARK_FRAMES, 4), dtype=np.uint8)
    ys, xs = np.mgrid[0:cell, 0:cell]
    ax, ay = np.abs(xs - R), np.abs(ys - R)

    def cross(r):
        return ((ax == 0) & (ay <= r)) | ((ay == 0) & (ax <= r))

    def diamond(r):
        return (ax + ay) <= r

    def dots(r):
        return ((ax == 0) & (ay == r)) | ((ay == 0) & (ax == r))

    def diag(r):
        return (ax == ay) & (ax <= r) & (ax > 0)

    big = max(1, R // 3)
    none = np.zeros((cell, cell), dtype=bool)
    shapes = [
        (cross(max(1, R // 3)), diamond(0)),
        (cross(R * 2 // 3) | diamond(big), cross(max(1, R // 3))),
        (cross(R) | diamond(big + 1) | diag(big + 1), cross(R // 2) | diamond(big)),
        (cross(R - 1) | diamond(big) | diag(big), cross(max(1, R // 3))),
        (dots(R) | dots(R - 1) | (diamond(big) & ~diamond(big - 1)) | (diag(big + 1) & ~diag(big)), diamond(0)),
        (dots(R) | diamond(0), none),
    ]
    for f, (halo, core) in enumerate(shapes):
        a = np.zeros((cell, cell, 4), dtype=np.uint8)
        a[halo] = (255, 255, 255, 255)
        b = np.zeros((cell, cell, 4), dtype=np.uint8)
        b[core] = (255, 255, 255, 255)
        paste(sheet, a, f * cell, 0)
        paste(sheet, b, f * cell, cell)
    return sheet


# ------------------------------------------------------------------ glow
# glow_pool.png (2:1 ellipses, light lying on the ground) and glow_round.png: one cell per radius in
# GLOW_R, side by side. White with on/off alpha in ordered-dither rings; the game tints it.

GLOW_R = [3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96]
GLOW_BANDS = [(0.24, 1.0), (0.42, 0.75), (0.60, 0.5), (0.77, 0.25), (0.90, 0.125), (1.0, 0.0625)]


def glow_cell(r, squash):
    w, h = 2 * r, max(1, int(round(2 * r * squash)))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    ax, ay = np.abs(xs - (w - 1) / 2.0), np.abs(ys - (h - 1) / 2.0)
    d = np.hypot(ax / r, ay / (h / 2.0))
    by = (BAYER4[ys.astype(int) % 4, xs.astype(int) % 4] + 0.5) / 16.0  # not mirrored: a mirrored dither shows as four quadrants
    on = np.zeros((h, w), dtype=bool)
    last = 0.0
    for edge, dens in GLOW_BANDS:
        on |= (d >= last) & (d < edge) & (by <= dens)
        last = edge
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[on] = (255, 255, 255, 255)
    return img


def glow_sheet(squash):
    hmax = int(round(2 * GLOW_R[-1] * squash))
    sheet = np.zeros((hmax, 2 * sum(GLOW_R), 4), dtype=np.uint8)
    x = 0
    for r in GLOW_R:
        paste(sheet, glow_cell(r, squash), x, 0)
        x += 2 * r
    return sheet


# ------------------------------------------------------------------ sun
# sun_<size>.png: 4 twinkle frames across; row 0 halo, rays and disc (tinted), row 1 the bright core.

SUN_DISC = [3, 6, 11]
SUN_HALO = [7, 12, 20]
SUN_RAY = [10, 19, 32]
SUN_FRAMES = 4


def sun_sheet(size):
    rd, rh, rr = SUN_DISC[size], SUN_HALO[size], SUN_RAY[size]
    cell = 2 * rr + 3
    c = rr + 1
    sheet = np.zeros((cell * 2, cell * SUN_FRAMES, 4), dtype=np.uint8)
    ys, xs = np.mgrid[0:cell, 0:cell]
    ax, ay = np.abs(xs - c), np.abs(ys - c)   # mirrored coordinates: every pattern is 4-way symmetric
    dist = np.hypot(ax, ay)
    span = rh - rd
    for f in range(SUN_FRAMES):
        on = dist <= rd + 0.35
        on |= (dist <= rd + 0.35 + span * 0.30) & (((ax + ay + rd) % 2) == 0)
        on |= (dist <= rd + span * 0.68) & ((ax % 2) == 0) & ((ay % 2) == 0)
        on |= (dist <= rh) & ((ax % 4) == 0) & ((ay % 4) == 0)
        on |= (dist <= rh) & ((ax % 4) == 2) & ((ay % 4) == 2)
        axis_len = int(round(rr * [1.0, 0.84, 0.70, 0.84][f]))
        diag_len = int(round(rr * [0.60, 0.70, 0.80, 0.70][f]))
        axis_ray = ((ax == 0) | (ay == 0)) & (ax + ay >= rd + 2) & (ax + ay <= axis_len) & (ax + ay != axis_len - 2)
        dd = np.round(ax * 1.4142).astype(int)
        diag_ray = (ax == ay) & (dd >= rd + 2) & (dd <= diag_len) & (ax != int(diag_len * 0.7071) - 1)
        on |= axis_ray | diag_ray
        if size == 2:
            # short in-between dashes on clean 2:1 pixel slopes, outside the halo
            lo, hi = rh - 2 + (f % 2), rh + 3 + (f % 2)
            on |= ((ax == 2 * ay) | (ay == 2 * ax)) & (dist >= lo) & (dist <= hi)
        a = np.zeros((cell, cell, 4), dtype=np.uint8)
        a[on] = (255, 255, 255, 255)
        b = np.zeros((cell, cell, 4), dtype=np.uint8)
        b[dist <= rd - 0.65] = (255, 255, 255, 255)
        paste(sheet, a, f * cell, 0)
        paste(sheet, b, f * cell, cell)
    return sheet


# ------------------------------------------------------------------ ground shockwave ring
# ring_<size>.png: 8 frames across, a flat ellipse seen in perspective, thick at the near edge.

RING_RX = [12, 24, 44]
RING_SQUASH = 0.34
RING_FRAMES = 8
RING_Q = [0.26, 0.43, 0.58, 0.70, 0.80, 0.88, 0.95, 1.0]


def ring_cell_size(size):
    rx = RING_RX[size]
    return 2 * rx + 4, 2 * int(round(rx * RING_SQUASH)) + 4


def ring_sheet(size):
    rx = RING_RX[size]
    ry = rx * RING_SQUASH
    cw, ch = ring_cell_size(size)
    sheet = np.zeros((ch, cw * RING_FRAMES, 4), dtype=np.uint8)
    ys, xs = np.mgrid[0:ch, 0:cw].astype(np.float64)
    cx, cy = (cw - 1) / 2.0, (ch - 1) / 2.0
    by = bayer(ch, cw)
    for f in range(RING_FRAMES):
        a, b = rx * RING_Q[f], ry * RING_Q[f]
        th = [3, 3, 3, 3, 2, 2, 2, 2][f] if size > 0 else [2, 2, 2, 2, 2, 1, 1, 1][f]
        outer = ((xs - cx) / a) ** 2 + ((ys - cy) / b) ** 2 <= 1.0
        ia, ib = max(0.1, a - th), max(0.1, b - max(1.0, th * 0.6))
        inner = ((xs - cx) / ia) ** 2 + ((ys - cy + 0.5) / ib) ** 2 <= 1.0
        on = outer & ~inner & (by <= [1, 1, 1, 1, 0.75, 0.5, 0.5, 0.25][f])
        v = [255, 255, 255, 240, 225, 210, 195, 180][f]
        cell = np.zeros((ch, cw, 4), dtype=np.uint8)
        cell[on] = (v, v, v, 255)
        paste(sheet, cell, f * cw, 0)
    return sheet


# ------------------------------------------------------------------ engine trail in space
# trail_<width>.png: 4 frames across, rows are lengths. A thin streak that thins out into dither.

TRAIL_W = [1, 3, 5]
TRAIL_LEN = [8, 12, 16, 24, 32, 48, 64, 96, 128]
TRAIL_FRAMES = 4


def trail_sheet(w):
    sheet = np.zeros((sum(TRAIL_LEN), w * TRAIL_FRAMES, 4), dtype=np.uint8)
    y0 = 0
    for length in TRAIL_LEN:
        ys, xs = np.mgrid[0:length, 0:w]
        u = ys / float(length)
        dx = np.abs(xs - (w - 1) / 2.0)
        for f in range(TRAIL_FRAMES):
            by = (BAYER4[(ys + 3 * f) % 4, (xs + f) % 4] + 0.5) / 16.0
            half = (w / 2.0) * (1 - u) ** 0.6
            on = (dx < np.maximum(half, 0.6)) & ((1 - u) ** 1.3 * 1.25 > by)
            val = np.where((u < 0.18) & (dx < max(0.6, w * 0.22)), 255, np.where(u < 0.5, 222, 178)).astype(np.uint8)
            cell = np.zeros((length, w, 4), dtype=np.uint8)
            cell[on] = np.stack([val, val, val, np.full_like(val, 255)], axis=-1)[on]
            paste(sheet, cell, f * w, y0)
        y0 += length
    return sheet


# ------------------------------------------------------------------ scanner beam
# beam_<width>.png: 8 frames across, rows are lengths. A cone that opens to <width> px, dithered fill,
# solid edges and a bright scan line that runs outward.

BEAM_W = [9, 17, 33]
BEAM_LEN = [12, 16, 24, 32, 48, 64, 96]
BEAM_FRAMES = 8


def beam_sheet(w):
    sheet = np.zeros((sum(BEAM_LEN), w * BEAM_FRAMES, 4), dtype=np.uint8)
    y0 = 0
    for length in BEAM_LEN:
        ys, xs = np.mgrid[0:length, 0:w]
        dx = np.abs(xs - (w - 1) / 2.0)
        half = 0.5 + (w / 2.0 - 0.5) * (ys + 1.0) / length
        inside = dx < half
        edge = inside & (dx >= half - 1.0)
        for f in range(BEAM_FRAMES):
            scan = int((f + 0.5) / BEAM_FRAMES * length)
            fill = inside & (((xs + ys + f // 2) % 2) == 0) & ((ys + f) % 4 != 3)
            cell = np.zeros((length, w, 4), dtype=np.uint8)
            cell[fill] = (150, 150, 150, 255)
            cell[edge] = (215, 215, 215, 255)
            cell[inside & (ys == scan)] = (255, 255, 255, 255)
            cell[inside & (ys == scan - 1) & ((xs % 2) == 0)] = (235, 235, 235, 255)
            paste(sheet, cell, f * w, y0)
        y0 += length
    return sheet


# ------------------------------------------------------------------ preview helpers

def upscale(img, k=4, bg=(16, 20, 31), tint=(1.0, 1.0, 1.0)):
    a = img[..., 3:4].astype(np.float64) / 255.0
    rgb = (img[..., :3] * np.array(tint) * a + np.array(bg) * (1 - a)).astype(np.uint8)
    return np.repeat(np.repeat(rgb, k, axis=0), k, axis=1)


def preview(img, name, k=4, bgs=((16, 20, 31), (150, 190, 236), (214, 150, 100)), tint=(1.0, 1.0, 1.0)):
    os.makedirs(WORK, exist_ok=True)
    out = np.concatenate([upscale(img, k, bg, tint) for bg in bgs], axis=0)
    Image.fromarray(out, "RGB").save(os.path.join(WORK, name))


def main():
    pv = len(sys.argv) > 1 and sys.argv[1] == "preview"
    sheets = {}
    for w in FLAME_W:
        sheets["flame_%d" % w] = flame_sheet(w)
    for s in range(3):
        sheets["puff_%d" % s] = puff_sheet(s)
        sheets["boom_%d" % s] = boom_sheet(s)
        sheets["sparkle_%d" % s] = sparkle_sheet(s)
        sheets["sun_%d" % s] = sun_sheet(s)
        sheets["ring_%d" % s] = ring_sheet(s)
    sheets["debris"] = debris_sheet()
    sheets["glow_pool"] = glow_sheet(0.5)
    sheets["glow_round"] = glow_sheet(1.0)
    for w in TRAIL_W:
        sheets["trail_%d" % w] = trail_sheet(w)
    for w in BEAM_W:
        sheets["beam_%d" % w] = beam_sheet(w)
    for name, img in sheets.items():
        save(img, name + ".png")
    if pv:
        for name, img in sheets.items():
            if not name.startswith(("flame", "trail", "beam")):
                k = 2 if name.startswith("glow") or name == "boom_2" else 4
                preview(img, "pv_%s.png" % name, k)
    print("wrote %d sheets to %s" % (len(sheets), OUT))


if __name__ == "__main__":
    main()
