"""Menu planets: surface maps and colour ramps for the spinning-planet shader in scripts/screens/menu.gd.

    python tools/art/gen_menu.py            writes art/menu/map_*.png, ramp_*.png, ring_lut.png
    python tools/art/gen_menu.py preview    also writes numpy previews of the shader to research/work/menu

A map is an equirectangular picture of the surface: R = material row in the ramp (x16),
G = relief (128 flat, 64 one tone darker, 192 one tone lighter), B = night light (Earth cities).
A ramp is 6 light levels wide (dark to light) and one row per material. The shader does the
lighting in whole tones, so the planet stays flat-shaded pixel art while it turns.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_bg import fbm, hexc  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "menu")
WORK = os.path.join(os.path.dirname(ROOT), "research", "work", "menu")
LEVELS = 6
MW, MH = 384, 192


def save(arr, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(OUT, name))


def ramp_img(rows):
    out = np.zeros((len(rows), LEVELS, 4), dtype=np.uint8)
    for i, r in enumerate(rows):
        assert len(r) == LEVELS, r
        out[i] = [hexc(h) for h in r]
    return out


def blank():
    m = np.zeros((MH, MW, 4), dtype=np.uint8)
    m[..., 1] = 128
    m[..., 3] = 255
    return m


def grid():
    yy, xx = np.mgrid[0:MH, 0:MW].astype(np.float64)
    lat = (0.5 - (yy + 0.5) / MH) * math.pi
    return xx, yy, lat


def disc(xx, yy, lat, cx, cy, r):
    """Distance (in units of r) from a round spot on the sphere, drawn on the map: wider near the poles."""
    dx = np.abs(xx - cx)
    dx = np.minimum(dx, MW - dx) * np.maximum(np.cos(lat), 0.15)
    return np.sqrt(dx * dx + (yy - cy) ** 2) / r, (xx - cx + MW / 2) % MW - MW / 2, yy - cy


def crater(m, xx, yy, lat, cx, cy, r, floor_cls=None, rim=True):
    """Light comes from the upper left: the bowl's upper left wall is in shadow, its lower right wall is lit."""
    d, dx, dy = disc(xx, yy, lat, cx, cy, r)
    side = (dx * np.maximum(np.cos(lat), 0.15) + dy) / max(r, 1.0)   # < 0 upper left, > 0 lower right
    bowl = d < 0.82
    if floor_cls is not None:
        m[..., 0][bowl] = floor_cls * 16
    m[..., 1][bowl] = 128
    m[..., 1][bowl & (side < -0.25)] = 64
    m[..., 1][bowl & (side > 0.45)] = 192
    if rim and r >= 3:
        ring = (d >= 0.82) & (d < 1.12)
        m[..., 1][ring & (side < -0.2)] = 192
        m[..., 1][ring & (side > 0.5)] = 64


def moon_map():
    m = blank()
    xx, yy, lat = grid()
    mare = fbm(MW, MH, [96, 48, 24], 21) + 0.10 * np.cos(lat * 1.6) - 0.08
    m[..., 0][mare > 0.585] = 16                       # 1 = mare (dark basalt plains)
    tex = fbm(MW, MH, [24, 12, 6], 22)
    m[..., 1][(tex > 0.63)] = 192                      # gentle highland mottling
    m[..., 1][(tex < 0.36)] = 64
    rng = np.random.default_rng(5)
    for r_lo, r_hi, count, floor in ((11, 16, 5, 2), (6, 10, 14, None), (2.5, 5, 60, None)):
        for _ in range(count):
            crater(m, xx, yy, lat, rng.integers(0, MW), rng.integers(22, MH - 22), rng.uniform(r_lo, r_hi), floor)
    for _ in range(5):                                  # young bright craters with ray spokes
        cx, cy, r = rng.integers(0, MW), rng.integers(40, MH - 40), rng.uniform(3.0, 4.5)
        d, dx, dy = disc(xx, yy, lat, cx, cy, r)
        ang = np.arctan2(dy, dx * np.maximum(np.cos(lat), 0.15))
        spoke = (np.cos(ang * 7 + cx) > 0.86) & (d > 1.2) & (d < 5.5 + 2.0 * np.sin(ang * 3))
        m[..., 0][spoke | ((d >= 1.0) & (d < 1.7))] = 48      # 3 = bright ejecta
        crater(m, xx, yy, lat, cx, cy, r, 3, rim=False)
    return m, ramp_img([
        ["14142a", "2a2a3a", "4a4a5e", "707086", "9c9cb0", "c8c8d8"],   # highland
        ["121226", "20202e", "38384a", "56566a", "787890", "9a9ab0"],   # mare
        ["101022", "1a1a28", "2e2e40", "48485c", "66667c", "86869c"],   # crater floor
        ["16162c", "34344a", "5c5c74", "8a8aa0", "b8b8cc", "ececf6"],   # bright ejecta
    ])


def mars_map():
    m = blank()
    xx, yy, lat = grid()
    dark = fbm(MW, MH, [96, 48, 24, 12], 31) + 0.06 * np.cos(lat * 2.0)
    dust = fbm(MW, MH, [96, 48, 24], 33)
    m[..., 0][dust > 0.6] = 32                          # 2 = bright dust basin
    m[..., 0][dark > 0.6] = 16                          # 1 = dark basalt (Syrtis-like)
    tex = fbm(MW, MH, [24, 12, 6], 34)
    m[..., 1][tex > 0.64] = 192
    m[..., 1][tex < 0.35] = 64
    rng = np.random.default_rng(9)
    for _ in range(34):
        crater(m, xx, yy, lat, rng.integers(0, MW), rng.integers(26, MH - 26), rng.uniform(2.5, 6.0))
    # a canyon scar along the equator (Valles Marineris runs about a fifth of the way round Mars)
    cx0, cy0, length = 150, 104, 78
    wob = fbm(MW, 1, [48, 24, 12], 35)[0]
    for i in range(length):
        x = (cx0 + i) % MW
        y = cy0 + int((wob[x] - 0.5) * 14) - i // 13
        half = 1 + int(2.2 * math.sin(math.pi * i / length) + (wob[(x * 3) % MW] - 0.5) * 2)
        m[y - half:y + half + 1, x, 0] = 64            # 4 = canyon floor
        m[y - half:y + half + 1, x, 1] = 128
        m[y - half - 1, x, 1] = 192                    # lit far wall
        m[y - half, x, 1] = 64                         # shadow under the near wall
    # shield volcanoes west of the canyon (Tharsis): lit flank, shaded flank, a caldera pit
    for cx, cy, r in ((96, 86, 12), (118, 100, 6), (124, 88, 6), (130, 76, 6)):
        d, dx, dy = disc(xx, yy, lat, cx, cy, r)
        side = (dx + dy) / r
        hill = d < 1.0
        m[..., 0][hill] = 0
        m[..., 1][hill] = 128
        m[..., 1][hill & (side < -0.35)] = 192
        m[..., 1][hill & (side > 0.55)] = 64
        m[..., 1][d < 0.28] = 64
    edge = 0.10 * (fbm(MW, 1, [96, 48, 24], 36)[0] - 0.5)
    cap_n = lat > math.radians(71) + edge[None, :]
    cap_s = lat < -(math.radians(76) + edge[None, ::-1])
    m[..., 0][cap_n | cap_s] = 48                        # 3 = polar ice
    m[..., 1][cap_n | cap_s] = 128
    return m, ramp_img([
        ["1c0a08", "4a1a10", "7c2e18", "a8441e", "cc6630", "e89058"],   # ochre plains
        ["160806", "34120c", "561e12", "7a2c16", "9c3e20", "bc5a34"],   # dark basalt
        ["200c08", "5a2414", "8e3c1e", "bc5a2a", "e08448", "f6b47c"],   # bright dust
        ["241410", "5e5c70", "9a98ac", "c8c8d6", "e8e8f0", "ffffff"],   # polar ice
        ["120604", "280e0a", "42160e", "5e2012", "7a2c18", "963c22"],   # canyon floor
    ])


def saturn_map():
    m = blank()
    xx, yy, lat = grid()
    wob = (fbm(MW, MH, [96, 48], 41) - 0.5) * 0.10
    s = np.sin(lat + wob)                                # bands follow latitude, with a slow wave
    band = 0.5 + 0.30 * np.sin(s * 15.0) + 0.16 * np.sin(s * 37.0 + 1.0) + 0.08 * np.sin(s * 71.0)
    cls = np.clip(np.floor(band * 4.0), 0, 3).astype(np.uint8)
    cls[np.abs(lat) > math.radians(68)] = 3              # darker polar hoods
    m[..., 0] = cls * 16
    streak = fbm(MW, MH, [48, 12], 42)
    m[..., 1][(streak > 0.66) & (np.abs(lat) < 1.0)] = 192
    return m, ramp_img([
        ["2a1e10", "6e5630", "a48450", "d0b070", "ecd49a", "fbf0cc"],   # cream zone
        ["2a1e10", "644c28", "987644", "c4a060", "e2c484", "f4e0b0"],   # gold
        ["241a0e", "58421e", "886838", "b28c50", "d2ae70", "e8cc98"],   # tan belt
        ["20160c", "4a361a", "74562c", "9a7440", "b8925a", "d2b07c"],   # brown belt
    ])


def earth_map():
    """A band of Earth from the horizon up to 30 degrees, 1024 px = a third of the way round (it repeats)."""
    w, h = 1024, 256
    m = np.zeros((h, w, 4), dtype=np.uint8)
    m[..., 1] = 128
    m[..., 3] = 255
    land = fbm(w, h, [256, 128, 64, 32, 16], 51) + 0.5 * (fbm(w, h, [512, 256], 52) - 0.5)
    dry = fbm(w, h, [128, 64, 32], 53)
    m[..., 0][land > 0.50] = 16                          # 1 = shallow sea
    m[..., 0][land > 0.545] = 32                         # 2 = green land
    m[..., 0][(land > 0.56) & (dry > 0.55)] = 48         # 3 = dry land
    m[..., 0][(land > 0.70)] = 64                        # 4 = high snow
    rough = fbm(w, h, [16, 8, 4], 54)
    is_land = land > 0.545
    m[..., 1][is_land & (rough > 0.62)] = 192
    m[..., 1][is_land & (rough < 0.36)] = 64
    rng = np.random.default_rng(12)
    city = (rng.random((h, w)) < 0.05) & is_land & (fbm(w, h, [64, 32], 55) > 0.52) & (land < 0.68)
    m[..., 2][city] = 255
    cl = fbm(w, h, [128, 64, 32, 16, 8], 56) + 0.35 * (fbm(w, h, [256, 128], 57) - 0.5)
    c = np.zeros((h, w, 4), dtype=np.uint8)
    c[..., 3] = 255
    c[..., 0][cl > 0.56] = 128                           # thin cloud (shadow tone under the bright tops)
    c[..., 0][cl > 0.60] = 255                           # cloud top
    return m, c, ramp_img([
        ["040a1e", "0a1c4a", "103270", "184c98", "2a6cbc", "4a8cd6"],   # deep sea
        ["050c22", "0c2456", "144084", "2060b0", "3a86d0", "68aee8"],   # shallow sea
        ["050c0a", "12281a", "1e4420", "326428", "508638", "7ca850"],   # green land
        ["0a0a08", "2a2414", "4e4020", "7a6430", "a48a48", "c8b070"],   # dry land
        ["0c1020", "3a4660", "6c7c9c", "a0b0cc", "d0dcec", "ffffff"],   # snow
        ["0a0e1c", "343e58", "66748e", "9aa8c2", "ccd6e8", "ffffff"],   # cloud
    ])


def ring_lut():
    """Saturn's rings from 1.20 to 2.35 planet radii. Row 0 lit, row 1 in the planet's shadow.
    Alpha: 0 gap, 128 thin (drawn as a checker), 255 solid."""
    n = 64
    out = np.zeros((2, n, 4), dtype=np.uint8)
    tones = ["3e3424", "6e5e40", "a49070", "d2c09a", "efe2c0"]
    for i in range(n):
        rr = 1.20 + (2.35 - 1.20) * (i + 0.5) / n
        tone, alpha = 0, 0
        if 1.24 <= rr < 1.50:
            tone, alpha = 1, 128                          # C ring, thin
        elif 1.50 <= rr < 1.95:
            tone, alpha = (4 if rr < 1.72 else 3), 255   # B ring, the bright one
            if abs(rr - 1.62) < 0.015 or abs(rr - 1.84) < 0.015:
                tone = 2
        elif 2.03 <= rr < 2.27:                           # A ring, beyond the Cassini division
            tone, alpha = 2, 255
            if abs(rr - 2.19) < 0.012:
                alpha = 0                                 # Encke gap
        out[0, i] = hexc(tones[tone], alpha)
        out[1, i] = hexc(tones[max(0, tone - 2)], alpha)
    return out


# ---------------------------------------------------------------- numpy copy of the shader, for previews

BAYER2 = np.array([[0.0, 0.5], [0.75, 0.25]]) - 0.375
LIGHT = np.array([-0.55, -0.60, 0.58])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


WRAP = 0.16          # how far the light wraps past the terminator (keeps the night side a thin crescent)


def shade(mapimg, ramp, diameter, spin=0.0, tilt=0.0, squash=1.0, pad=0, dstr=0.2, ring=None, ring_b=0.31):
    r = diameter / 2.0
    w = int(diameter * (2.4 if ring is not None else 1.0)) + 2 * pad
    h = diameter + 2 * pad
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    px = (xs + 0.5 - w / 2.0) / r
    py = (ys + 0.5 - h / 2.0) / r
    ca, sa = math.cos(-tilt), math.sin(-tilt)
    qx, qy = px * ca - py * sa, px * sa + py * ca
    lr = np.array([LIGHT[0] * ca - LIGHT[1] * sa, LIGHT[0] * sa + LIGHT[1] * ca, LIGHT[2]])
    qys = qy / squash
    r2 = qx * qx + qys * qys
    inside = r2 <= 1.0
    z = np.sqrt(np.clip(1.0 - r2, 0, 1))
    mh, mw = mapimg.shape[:2]
    u = ((np.arctan2(qx, z) / (2 * math.pi) + spin) % 1.0 * mw).astype(int) % mw
    v = np.clip(((0.5 + np.arcsin(np.clip(qys, -1, 1)) / math.pi) * mh).astype(int), 0, mh - 1)
    tex = mapimg[v, u]
    cls = (tex[..., 0].astype(int) + 8) // 16
    relief = (tex[..., 1].astype(int) + 32) // 64 - 2
    lam = np.clip((qx * lr[0] + qys * lr[1] + z * lr[2] + WRAP) / (1.0 + WRAP), 0, 1)
    d = np.tile(BAYER2, (h // 2 + 1, w // 2 + 1))[:h, :w]
    lev = np.floor(np.power(lam, 0.8) * (LEVELS - 0.6) + d * dstr).astype(int)
    lit = lev > 0
    out = np.zeros((h, w, 4), dtype=np.uint8)
    if ring is not None:
        nrm = np.array([0.0, -math.sqrt(1 - ring_b * ring_b), ring_b])
        vv = qy / ring_b
        rr = np.sqrt(qx * qx + vv * vv)
        ri = np.clip(((rr - 1.20) / (2.35 - 1.20) * ring.shape[1]).astype(int), 0, ring.shape[1] - 1)
        p3 = np.stack([qx, vv * ring_b, vv * math.sqrt(1 - ring_b * ring_b)], axis=-1)
        along = p3 @ lr
        perp = np.linalg.norm(p3 - along[..., None] * lr, axis=-1)
        shadow = (perp < 1.0) & (along < 0)
        rc = ring[np.where(shadow, 1, 0), ri]
        checker = ((xs + ys) % 2) == 0
        rmask = (rr > 1.20) & (rr < 2.35) & ((rc[..., 3] > 200) | ((rc[..., 3] > 60) & checker))
        # ring shadow on the planet
        s3 = np.stack([qx, qys, z], axis=-1)
        t = -(s3 @ nrm) / float(nrm @ lr)
        hit = s3 + t[..., None] * lr
        hr = np.linalg.norm(hit, axis=-1)
        hi = np.clip(((hr - 1.20) / (2.35 - 1.20) * ring.shape[1]).astype(int), 0, ring.shape[1] - 1)
        rshadow = (t > 0) & (hr > 1.20) & (hr < 2.35) & (ring[0, hi][..., 3] > 200)
        lev = np.where(rshadow, lev - 2, lev)
    lev = np.where(lit, np.clip(lev + relief, 1, LEVELS - 1), 0)
    lev = np.clip(lev, 0, LEVELS - 1)
    col = ramp[np.clip(cls, 0, ramp.shape[0] - 1), lev]
    if ring is not None:
        back = rmask & (vv < 0)
        out[back] = rc[back]
        out[back, 3] = 255
    out[inside] = col[inside]
    if ring is not None:
        front = rmask & (vv >= 0)
        out[front] = rc[front]
        out[front, 3] = 255
    return out


def limb(mapimg, clouds, ramp, w=640, h=80, radius=560.0, spin=0.0, cloud_spin=0.0):
    """Numpy copy of the Earth-limb shader: the top of a huge disc, lit from the left, night on the right."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    px = (xs + 0.5 - w / 2.0) / radius
    py = (ys + 0.5 - (8.0 + radius)) / radius
    r2 = px * px + py * py
    rad = np.sqrt(r2)
    z = np.sqrt(np.clip(1.0 - r2, 0, 1))
    ll = np.array([-0.80, -0.30, 0.52])
    ll = ll / np.linalg.norm(ll)
    lam = np.clip((px * ll[0] + py * ll[1] + z * ll[2] + 0.1) / 1.1, 0, 1)
    mh, mw = mapimg.shape[:2]
    ang = np.arctan2(px, -py) / (2 * math.pi) * 3.0
    v = np.clip((np.arcsin(z) / 0.6 * mh).astype(int), 0, mh - 1)
    u = ((ang + spin) % 1.0 * mw).astype(int) % mw
    uc = ((ang + cloud_spin) % 1.0 * mw).astype(int) % mw
    tex = mapimg[v, u]
    cls = (tex[..., 0].astype(int) + 8) // 16
    relief = (tex[..., 1].astype(int) + 32) // 64 - 2
    cl = clouds[v, uc][..., 0]
    cl_sh = clouds[np.clip(v + 3, 0, mh - 1), (uc + 4) % mw][..., 0]     # the cloud up-light of this point
    d = np.tile(BAYER2, (h // 2 + 1, w // 2 + 1))[:h, :w]
    lev = np.floor(np.power(lam, 0.8) * (LEVELS - 0.6) + d * 0.2).astype(int)
    lit = lev > 0
    lev = lev + relief - np.where((cl_sh > 100) & (cl < 100), 1, 0)
    lev = np.where(cl > 200, lev + 1, lev)
    cls = np.where(cl > 100, 5, cls)
    lev = np.where((1.0 - rad) * radius < 2.5, lev + 1, lev)                # haze along the horizon
    lev = np.where(lit, np.clip(lev, 1, LEVELS - 1), 0)
    out = np.zeros((h, w, 4), dtype=np.uint8)
    col = ramp[np.clip(cls, 0, ramp.shape[0] - 1), lev]
    inside = r2 <= 1.0
    out[inside] = col[inside]
    city = inside & ~lit & (tex[..., 2] > 128) & (cl < 100)
    out[city] = hexc("ffc860")
    hgt = (rad - 1.0) * radius                                             # px above the horizon
    glow = [("9ad8ff", 0.0, 1.5), ("3a86d0", 1.5, 3.5), ("143e84", 3.5, 6.5)]
    for hx, a, b in glow:
        band = (hgt > a) & (hgt <= b) & (lam > 0.12)
        out[band] = hexc(hx)
    night_rim = (hgt > 0) & (hgt <= 1.5) & (lam <= 0.12)
    out[night_rim] = hexc("12244e")
    return out


def preview():
    os.makedirs(WORK, exist_ok=True)
    moon, moon_r = moon_map()
    mars, mars_r = mars_map()
    sat, sat_r = saturn_map()
    ring = ring_lut()
    tiles = []
    for spin in (0.0, 0.33, 0.66):
        tiles.append(shade(moon, moon_r, 118, spin, pad=4))
        tiles.append(shade(mars, mars_r, 118, spin, pad=4))
        tiles.append(shade(sat, sat_r, 76, spin, tilt=math.radians(-13), squash=0.93, pad=26, ring=ring))
    w = sum(t.shape[1] for t in tiles[:3]) + 16
    h = max(t.shape[0] for t in tiles)
    sheet = np.zeros((h * 3, w, 4), dtype=np.uint8)
    sheet[...] = (8, 10, 22, 255)
    for i, t in enumerate(tiles):
        x = sum(tt.shape[1] + 4 for tt in tiles[:i % 3]) + 4
        y = (i // 3) * h + (h - t.shape[0]) // 2
        a = t[..., 3:4] / 255.0
        sheet[y:y + t.shape[0], x:x + t.shape[1], :3] = (t[..., :3] * a + sheet[y:y + t.shape[0], x:x + t.shape[1], :3] * (1 - a)).astype(np.uint8)
    im = Image.fromarray(sheet)
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(WORK, "planets_preview.png"))
    em, ec, er = earth_map()
    strip = np.zeros((170, 640, 4), dtype=np.uint8)
    strip[...] = (8, 10, 22, 255)
    for i, (sp, cs) in enumerate(((0.0, 0.0), (0.4, 0.55))):
        lb = limb(em, ec, er, spin=sp, cloud_spin=cs)
        a = lb[..., 3:4] / 255.0
        strip[i * 85:i * 85 + 80, :, :3] = (lb[..., :3] * a + strip[i * 85:i * 85 + 80, :, :3] * (1 - a)).astype(np.uint8)
    im = Image.fromarray(strip)
    im.resize((1280, 340), Image.NEAREST).save(os.path.join(WORK, "limb_preview.png"))


def main():
    for name, (m, r) in (("moon", moon_map()), ("mars", mars_map()), ("saturn", saturn_map())):
        save(m, "map_%s.png" % name)
        save(r, "ramp_%s.png" % name)
    em, ec, er = earth_map()
    save(em, "map_earth.png")
    save(ec, "map_clouds.png")
    save(er, "ramp_earth.png")
    save(ring_lut(), "ring_lut.png")
    if "preview" in sys.argv:
        preview()
    print("menu planets written to", OUT)


if __name__ == "__main__":
    main()
