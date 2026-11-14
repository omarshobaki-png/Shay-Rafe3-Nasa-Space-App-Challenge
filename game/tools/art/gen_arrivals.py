"""Flight-screen arrival close-ups for the five new worlds -> art/flight/big_<id>[_back|_front].png.

    python tools/art/gen_arrivals.py

Same conventions as tools/art/gen_flight.py big_planet() / big_saturn():
- Mercury, Venus: one 211 x 211 layer (radius 100, 5 px pad), like big_moon / big_mars.
- Jupiter, Uranus, Neptune: three layers of one size, all centred on the globe, like big_saturn:
  _back (far half of the rings), the globe (with the ring shadow on it), _front (near half of the rings).
Colours follow art/planet_<id>_*.png (tools/art/gen_planets.py) so the close-up matches the small sprite.
Rings are traced in 3D (ring plane through the globe's centre), so the near and far halves, the globe's
shadow on the rings and the rings' shadow on the globe all come out of the same geometry.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import LIGHT, _sphere, _tex_lookup, dither, fbm, hexc, quant, ramp  # noqa: E402
from gen_flight import save  # noqa: E402


# ------------------------------------------------------------------ rocky worlds

def _rim(img, x, y, d2, r, cols, alphas, widths, wrap=0.0):
    """Air glow outside the limb: bands of colour, strongest on the lit side (wrap > 0 reaches round)."""
    side = np.clip((x * LIGHT[0] - y * LIGHT[1]) + 0.35 + wrap, 0, 1)
    dist = np.sqrt(d2) * r - r
    d0 = 0.0
    for i, (col, a, wd) in enumerate(zip(cols, alphas, widths)):
        m = (dist > d0) & (dist <= d0 + wd) & (side > 0.12 + i * 0.1)
        img[m] = hexc(col, a)
        d0 += wd


def big_mercury(r=100, seed=8):
    """Cratered, Moon-like but browner, with bright young ray craters and smooth dark plains."""
    W, H, x, y, d2, inside, lam, lon, lat = _sphere(r, pad=5)
    d = dither(H, W)
    tw, th = 640, 320
    lit = np.clip((lam - 0.06) * 1.25, 0, 1) ** 0.8
    lon = lon + math.pi
    base = fbm(tw, th, [80, 40, 20, 10, 5], seed)
    plains = fbm(tw, th, [160, 80, 40], seed + 1)
    crat = np.zeros((th, tw))
    rays = np.zeros((th, tw))
    rng = np.random.default_rng(seed + 2)
    yy, xx = np.mgrid[0:th, 0:tw]
    for i in range(240):
        cx, cy = rng.integers(0, tw), rng.integers(20, th - 20)
        cr = rng.integers(9, 22) if i < 16 else rng.integers(2, 8)
        dx = np.minimum(np.abs(xx - cx), tw - np.abs(xx - cx))
        dd = np.sqrt(dx ** 2 + (yy - cy) ** 2) / cr
        lightside = ((xx - cx) + (yy - cy)) < 0
        crat = np.where(dd < 0.8, np.where(lightside, -0.26, -0.08), crat)
        crat = np.where((dd >= 0.8) & (dd < 1.12), np.where(lightside, -0.04, 0.22), crat)
        if i in (3, 9, 22, 40, 77, 120):                       # young craters throw bright rays
            ang = np.arctan2(yy - cy, xx - cx)
            jag = np.sin(ang * 7 + i) + 0.8 * np.sin(ang * 17 + 2 * i) + 0.6 * np.sin(ang * 29 + i * 3)
            reach = 3.0 + 2.2 * (np.sin(ang * 5 + i) * 0.5 + 0.5)
            spokes = (jag > 1.1) & (dd > 1.1) & (dd < reach)
            rays = np.maximum(rays, spokes * (1.0 - dd / reach) * (0.6 + 0.4 * (i % 2)))
            crat = np.where(dd < 1.12, crat + 0.18, crat)
    alb = 0.74 + 0.34 * (_tex_lookup(base, lon, lat) - 0.5) + _tex_lookup(crat, lon, lat)
    alb -= 0.14 * (_tex_lookup(plains, lon, lat) > 0.56)
    alb += 0.3 * _tex_lookup(rays, lon, lat)
    R = ramp("100c0a", "241c16", "3e3226", "5e4e3c", "84705a", "a8927a", "cdbb9c", "ece0c8")
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[...] = R[quant(lit * np.clip(alb, 0, 1.3), len(R), d, 0.55)]
    img[~inside] = 0
    return img


def big_venus(r=100, seed=9):
    """Thick, pale-yellow cloud deck: soft chevron swirls (the UV 'Y'), a bright hazy limb all round."""
    W, H, x, y, d2, inside, lam, lon, lat = _sphere(r, pad=5)
    d = dither(H, W)
    lit = np.clip((lam - 0.02) * 1.15, 0, 1) ** 0.65            # the clouds scatter light deep into night
    warp = fbm(256, 128, [64, 32, 16], seed + 41)
    clouds = fbm(320, 160, [80, 40, 20, 10], seed + 42)
    w = (_tex_lookup(warp, lon, lat) - 0.5) * 5.0
    chevron = np.sin(lat * 6.0 + np.abs(lat) * 0.0 + (lon - 0.2) * 2.4 - np.abs(lat) * 5.0 + w)  # a sideways V
    alb = 0.8 + 0.09 * chevron + 0.22 * (_tex_lookup(clouds, lon + 0.25 * np.sin(lat * 3), lat) - 0.5)
    alb += 0.08 * (np.abs(lat) > 1.05)                          # brighter polar collars
    R = ramp("2c1a08", "5c3c12", "8e6420", "bc9038", "d8b05a", "eacc7e", "f6e2a8", "fdf2c8")
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[...] = R[quant(lit * alb, len(R), d, 0.55)]
    img[~inside] = 0
    _rim(img, x, y, d2, r, ("fdf2c8", "f6e2a8", "deb862"), (235, 150, 70), (1.5, 1.5, 1.6), wrap=0.12)
    dist = np.sqrt(d2) * r - r
    edge = inside & (dist > -3.5)                               # limb brightening from the haze layer
    img[edge, :3] = np.clip(img[edge, :3].astype(int) + 22, 0, 255)
    return img


# ------------------------------------------------------------------ giants: globe + 3D ring plane

def _axis(lean_deg, open_deg):
    """Pole direction (screen x right, y up, z toward viewer): leaning lean_deg from vertical, tipped
    open_deg toward us (the ring opening angle)."""
    a, b = math.radians(lean_deg), math.radians(open_deg)
    return np.array([math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), math.sin(b)])


def giant(r, n, flat, ring_out, globe_fn, ring_fn, pad=4):
    """r: equator radius px; n: pole axis; flat: polar/equator ratio; ring_out: outer ring edge in radii.
    globe_fn(lat, lon, lam, d) -> RGBA; ring_fn(rr, ang, x, y) -> (RGBA, density). Returns back, globe, front."""
    nx, ny, nz = n
    # size: the ring ellipse's extent on screen, plus the globe
    t = np.linspace(0, 2 * math.pi, 720)
    e1 = np.cross(n, [0, 0, 1.0])
    e1 = e1 / np.linalg.norm(e1) if np.linalg.norm(e1) > 1e-6 else np.array([1.0, 0, 0])
    e2 = np.cross(n, e1)
    pts = np.outer(np.cos(t), e1) + np.outer(np.sin(t), e2)
    hx = max(1.0, np.abs(pts[:, 0]).max() * ring_out)
    hy = max(1.0, np.abs(pts[:, 1]).max() * ring_out)
    Wd = 2 * int(math.ceil(hx * r)) + 1 + 2 * pad
    Hd = 2 * int(math.ceil(hy * r)) + 1 + 2 * pad
    ys, xs = np.mgrid[0:Hd, 0:Wd].astype(np.float64)
    X = (xs - (Wd - 1) / 2) / r
    Y = -(ys - (Hd - 1) / 2) / r                                 # y up
    d = dither(Hd, Wd)
    L = LIGHT / np.linalg.norm(LIGHT)
    # oblate globe: |p|^2 + k (p.n)^2 = 1, k = 1/flat^2 - 1; front surface z
    k = 1.0 / flat ** 2 - 1.0
    s = X * nx + Y * ny
    qa = 1.0 + k * nz * nz
    qb = 2.0 * k * nz * s
    qc = X * X + Y * Y + k * s * s - 1.0
    disc = qb * qb - 4 * qa * qc
    inside = disc >= 0
    Z = (-qb + np.sqrt(np.clip(disc, 0, None))) / (2 * qa)
    q = X * nx + Y * ny + Z * nz
    N = np.stack([X + k * q * nx, Y + k * q * ny, Z + k * q * nz], -1)
    N /= np.linalg.norm(N, axis=-1, keepdims=True)
    lam = np.clip(N @ L, 0, 1)
    lat = np.arcsin(np.clip(N @ n, -1, 1))
    v = np.array([0, 0, 1.0]) - nz * n                           # in-plane direction toward the viewer
    v /= np.linalg.norm(v)
    u = np.cross(n, v)
    lon = np.arctan2(N @ u, N @ v)
    globe = np.zeros((Hd, Wd, 4), dtype=np.uint8)
    gi = globe_fn(lat, lon, lam, d)
    globe[inside] = gi[inside]
    # ring plane: p.n = 0
    Zr = -(X * nx + Y * ny) / nz
    P = np.stack([X, Y, Zr], -1)
    rr = np.linalg.norm(P, axis=-1)
    ang = np.arctan2(P @ e2, P @ e1)
    col, dens = ring_fn(rr, ang, X, Y, d)
    ring = dens > 0
    # globe's shadow on the rings: does the ray toward the Sun hit the globe (sphere approximation)?
    pl = P @ L
    hit = (pl * pl - (rr * rr - 1.0) > 0) & (-pl + np.sqrt(np.clip(pl * pl - (rr * rr - 1.0), 0, None)) > 0) & (pl < 0)
    col[ring & hit, :3] = (col[ring & hit, :3] * 0.28).astype(np.uint8)
    front_half = Zr > 0
    back = np.zeros_like(globe)
    front = np.zeros_like(globe)
    bm = ring & ~front_half
    fm = ring & front_half & ~(inside & (Zr < Z))
    back[bm] = col[bm]
    front[fm] = col[fm]
    # rings' shadow on the globe: from each globe point toward the Sun, where does it cross the ring plane?
    Pg = np.stack([X, Y, Z], -1)
    tL = -(Pg @ n) / (L @ n)
    Ps = Pg + tL[..., None] * L
    rs = np.linalg.norm(Ps, axis=-1)
    _, sd = ring_fn(rs, np.arctan2(Ps @ e2, Ps @ e1), X, Y, d)
    shade = inside & (tL > 0) & (sd > 0.25)
    globe[shade, :3] = (globe[shade, :3] * (1.0 - 0.5 * np.clip(sd[shade], 0, 1))[:, None]).astype(np.uint8)
    return back, globe, front, inside


def _rim_giant(globe, inside, col, a):
    """A thin air rim on the lit side, 1 px, like gen_planets' small sprites."""
    g = inside
    grow = np.zeros_like(g)
    grow[1:, :] |= g[:-1, :]
    grow[:-1, :] |= g[1:, :]
    grow[:, 1:] |= g[:, :-1]
    grow[:, :-1] |= g[:, 1:]
    rim = grow & ~g
    H, W = g.shape
    ys, xs = np.mgrid[0:H, 0:W]
    side = ((xs - W / 2) * LIGHT[0] - (ys - H / 2) * LIGHT[1]) > -0.15 * W / 2
    globe[rim & side] = hexc(col, a)
    # and a 1 px bright edge just inside on the lit side
    shrink = g.copy()
    shrink[1:, :] &= g[:-1, :]
    shrink[:-1, :] &= g[1:, :]
    shrink[:, 1:] &= g[:, :-1]
    shrink[:, :-1] &= g[:, 1:]
    edge = g & ~shrink & side
    globe[edge, :3] = np.clip(globe[edge, :3].astype(int) + 30, 0, 255)


def _lit(lam, lo=0.05):
    return np.clip((lam - lo) * 1.2, 0, 1) ** 0.8


def big_jupiter(r=78):
    """Cream zones, rust belts, turbulence, the Great Red Spot; a faint thin dusty ring almost edge-on."""
    n = _axis(-6, 6)
    turb = fbm(512, 256, [64, 32, 16, 8], 451)
    fine = fbm(512, 256, [16, 8, 4], 452)

    def globe(lat, lon, lam, d):
        t = _tex_lookup(turb, lon + math.pi, lat) - 0.5
        f = _tex_lookup(fine, lon + math.pi, lat) - 0.5
        band = (0.5 + 0.3 * np.sin(lat * 11.0 + t * 3.2) + 0.12 * np.sin(lat * 27.0 + t * 7.0 + 1.0)
                + 0.06 * np.sin(lat * 61.0 + t * 12.0) + 0.1 * f)
        Z = ramp("2e2018", "5a4630", "8c7450", "bca27a", "e2cfa4", "f6ecd2", "fffaf0")
        B = ramp("23100a", "4a2112", "74381c", "9c552c", "c07a48", "dca070", "eec29a")
        lit = _lit(lam)
        v = lit * (0.6 + 0.44 * band)
        zi = Z[quant(v, len(Z), d, 0.5)]
        bi = B[quant(v, len(B), d, 0.5)]
        out = np.where((band < 0.46)[..., None], bi, zi)
        # Great Red Spot: south of the equator, with a pale collar
        sx, sy = (lon + 0.12) / 0.3, (lat + 0.38) / 0.12
        e = sx * sx + sy * sy
        S = ramp("3a0e08", "70200e", "a43c1a", "cc6030", "e88a58", "f6b080")
        coll = (e >= 1.0) & (e < 1.5)
        out[coll] = Z[quant(lit[coll] * 0.98, len(Z), d[coll], 0.5)]
        sp = e < 1.0
        out[sp] = S[quant(lit[sp] * (0.85 + 0.35 * (1 - e[sp])), len(S), d[sp], 0.5)]
        # white ovals along a southern belt
        for ox in (-0.5, -0.15, 0.9):
            ex, ey = (lon - ox) / 0.07, (lat + 0.66) / 0.035
            m = ex * ex + ey * ey < 1.0
            out[m] = Z[quant(lit[m] * 1.05, len(Z), d[m], 0.5)]
        # the poles are darker and greyer than the banded tropics (Juno)
        pole = np.abs(lat) > 1.15
        out[pole, :3] = (out[pole, :3] * np.array([0.7, 0.68, 0.74])).astype(np.uint8)
        return out

    def rings(rr, ang, X, Y, d):
        dens = np.zeros_like(rr)
        dens += np.where((rr >= 1.40) & (rr < 1.72), 0.18, 0)    # halo
        dens += np.where((rr >= 1.72) & (rr < 1.81), 0.75, 0)    # main ring
        dens += np.where((rr >= 1.81) & (rr < 1.98), 0.10, 0)    # gossamer (inner part)
        col = np.zeros(rr.shape + (4,), dtype=np.uint8)
        R = ramp("2e1c18", "4a3028", "6a4a3a", "8a6450", "a8806a")
        col[...] = R[np.clip((dens * len(R) + d * 0.6).astype(int), 0, len(R) - 1)]
        col[..., 3] = np.clip(60 + dens * 130, 0, 255).astype(np.uint8)
        return col, np.where(dens > 0, dens, 0)

    back, g, front, inside = giant(r, n, 0.935, 1.98, globe, rings)
    _rim_giant(g, inside, "e8cfa0", 110)
    return back, g, front


def big_uranus(r=52):
    """Pale cyan, almost featureless, lying on its side: the lit pole faces us, the narrow dark rings
    stand nearly upright around it."""
    n = _axis(-72, 32)
    turb = fbm(256, 128, [64, 32], 551)

    def globe(lat, lon, lam, d):
        t = _tex_lookup(turb, lon + math.pi, lat) - 0.5
        band = 0.5 + 0.05 * np.sin(lat * 8.0 + t) + 0.03 * t
        R = ramp("0c2a30", "1a5058", "2e7c84", "56a8ac", "8ccfce", "b0e2e0", "d4f4f2")
        v = _lit(lam, 0.02) * (0.78 + 0.5 * (band - 0.5) + 0.2)
        v += 0.08 * (lat > 0.95)                                 # the bright polar hood (Hubble, JWST)
        return R[quant(v, len(R), d, 0.5)]

    # 13 rings (Voyager 2, Earth-based): radii in Uranus radii, the epsilon ring outermost and widest
    # (spread a little so 1 px rings do not merge into a grey sheet at this size)
    RADII = [(1.46, .006), (1.54, .006), (1.62, .008), (1.70, .010), (1.78, .010), (1.87, .012), (2.00, .030)]

    def rings(rr, ang, X, Y, d):
        dens = np.zeros_like(rr)
        px = 1.0 / r
        for rad, wd in RADII:
            wd = max(wd, 0.7 * px)
            dens = np.maximum(dens, np.where(np.abs(rr - rad) < wd, 1.0 if rad == 2.0 else 0.6, 0))
        col = np.zeros(rr.shape + (4,), dtype=np.uint8)
        col[...] = hexc("4a4e58")
        col[dens >= 1.0] = hexc("6e727e")
        col[..., 3] = np.where(dens >= 1.0, 235, 180).astype(np.uint8)
        return col, dens

    back, g, front, inside = giant(r, n, 0.977, 2.04, globe, rings)
    _rim_giant(g, inside, "b4eeee", 120)
    return back, g, front


def big_neptune(r=56):
    """Deep blue with white methane streaks and the Great Dark Spot; faint rings with the bright Adams arcs."""
    n = _axis(16, 22)
    turb = fbm(256, 128, [64, 32, 16], 651)

    def globe(lat, lon, lam, d):
        t = _tex_lookup(turb, lon + math.pi, lat) - 0.5
        band = 0.5 + 0.14 * np.sin(lat * 8.0 + t * 2.0)
        R = ramp("040a24", "0a1848", "12286e", "1c4096", "2a5cba", "3c78d4", "5c96e6", "94c0f6")
        lit = _lit(lam)
        out = R[quant(lit * (0.74 + 0.6 * (band - 0.5) + 0.18), len(R), d, 0.5)]
        sx, sy = (lon + 0.28) / 0.24, (lat + 0.2) / 0.1            # Great Dark Spot
        e = sx * sx + sy * sy
        dk = e < 1.0
        out[dk, :3] = (out[dk, :3] * 0.5).astype(np.uint8)
        comp = ((lon + 0.12) / 0.12) ** 2 + ((lat + 0.31) / 0.03) ** 2 < 1.0    # its bright companion
        streaks = [(0.46, -0.05, 1.1, 0.03), (0.3, 0.35, 0.5, 0.02), (-0.62, 0.25, 0.6, 0.025)]
        wh = comp.copy()
        for la, lo, ln, wd in streaks:
            wh |= (np.abs(lat - la - 0.04 * np.sin(lon * 5)) < wd) & (np.abs(lon - lo) < ln * 0.5)
        W = ramp("4a6a9a", "a8c4ec", "e6f2ff", "ffffff")
        wl = wh & (lam > 0.12)
        out[wl] = W[quant(lit[wl], len(W), d[wl], 0.5)]
        return out

    ARCS = [(-2.15, 0.10), (-1.95, 0.06), (-1.82, 0.12), (-1.62, 0.05)]   # angles (rad) and widths on the Adams ring

    def rings(rr, ang, X, Y, d):
        dens = np.zeros_like(rr)
        dens += np.where((rr >= 1.62) & (rr < 1.76), 0.22, 0)    # Galle: broad, faint
        dens += np.where(np.abs(rr - 2.15) < 0.018, 0.5, 0)      # Le Verrier
        dens += np.where((rr >= 2.16) & (rr < 2.31), 0.12, 0)    # Lassell sheet
        dens += np.where(np.abs(rr - 2.31) < 0.012, 0.35, 0)     # Arago
        adams = np.abs(rr - 2.54) < 0.02
        dens += np.where(adams, 0.45, 0)
        arc = np.zeros_like(rr, dtype=bool)
        for a0, wd in ARCS:
            arc |= adams & (np.abs(np.angle(np.exp(1j * (ang - a0)))) < wd)
        col = np.zeros(rr.shape + (4,), dtype=np.uint8)
        R = ramp("2e2228", "4a383e", "6a5458", "8a7070")
        col[...] = R[np.clip((dens * 2.2 * len(R) / 2 + d * 0.6).astype(int), 0, len(R) - 1)]
        col[..., 3] = np.clip(70 + dens * 200, 0, 255).astype(np.uint8)
        clump = d > -0.2                                         # ordered dither: clumps, not a clean line
        col[arc & clump] = hexc("f0dcd0")
        col[arc & ~clump] = hexc("b09890")
        dens = np.where(arc, 1.0, dens)
        return col, dens

    back, g, front, inside = giant(r, n, 0.983, 2.6, globe, rings)
    _rim_giant(g, inside, "7ab0ff", 130)
    return back, g, front


def main():
    save(big_mercury(), "big_mercury.png")
    save(big_venus(), "big_venus.png")
    for name, fn in (("jupiter", big_jupiter), ("uranus", big_uranus), ("neptune", big_neptune)):
        b, g, f = fn()
        save(b, "big_%s_back.png" % name)
        save(g, "big_%s.png" % name)
        save(f, "big_%s_front.png" % name)
        print(name, g.shape[1], "x", g.shape[0])
    print("arrival close-ups written")


if __name__ == "__main__":
    main()
