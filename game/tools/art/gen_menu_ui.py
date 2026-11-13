"""Menu and report UI art: logo, bevelled frames and buttons, icons, medals, mission patches,
Tech Lab icons, small planets and props. All drawn in code, 1 art pixel = 1 game pixel.

    python tools/art/gen_menu_ui.py            writes art/menu/*.png
    python tools/art/gen_menu_ui.py preview    also writes a contact sheet to research/work/menu
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_menu as planets  # noqa: E402
from gen_bg import hexc  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "menu")
WORK = os.path.join(os.path.dirname(ROOT), "research", "work", "menu")
OL = "0c0a14"
MADE = {}


def save(arr, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"))
    MADE[name] = arr


def new(w, h):
    return np.zeros((h, w, 4), dtype=np.uint8)


def art(rows, pal):
    """ASCII picture -> RGBA. '.' is transparent; every other character is looked up in pal."""
    w = len(rows[0])
    out = new(w, len(rows))
    for y, row in enumerate(rows):
        assert len(row) == w, "row %d is %d wide, want %d: %s" % (y, len(row), w, row)
        for x, ch in enumerate(row):
            if ch != ".":
                out[y, x] = hexc(pal[ch])
    return out


def outline(img, color=OL, diagonal=False):
    """Add a 1 px outline around the opaque pixels (the picture grows by 1 px on each side)."""
    h, w = img.shape[:2]
    big = new(w + 2, h + 2)
    big[1:-1, 1:-1] = img
    a = big[..., 3] > 0
    grow = np.zeros_like(a)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if (dy or dx) and (diagonal or dy == 0 or dx == 0):
                grow |= np.roll(np.roll(a, dy, 0), dx, 1)
    big[grow & ~a] = hexc(color)
    return big


def paste(dst, src, x, y):
    h, w = src.shape[:2]
    m = src[..., 3] > 0
    dst[y:y + h, x:x + w][m] = src[m]


def rect(img, x, y, w, h, color):
    img[y:y + h, x:x + w] = hexc(color)


# ---------------------------------------------------------------- frames and buttons (9-slice sources)

def mix(a, b, t):
    ca, cb = hexc(a), hexc(b)
    return "%02x%02x%02x" % tuple(int(ca[i] * (1 - t) + cb[i] * t) for i in range(3))


def frame(name, body, light, dark, edge="05070d", shadow=2, size=24, inner=None):
    """A chunky panel: dark outline with cut corners, lit top and left edges, shaded bottom and right
    edges, and a hard drop shadow under it."""
    img = new(size, size + shadow)
    rect(img, 1, shadow, size - 2, size, "05070d")                  # drop shadow
    rect(img, 0, shadow + 1, size, size - 2, "05070d")
    img[..., 3] = np.where(img[..., 3] > 0, 150, 0)
    rect(img, 1, 0, size - 2, size, edge)
    rect(img, 0, 1, size, size - 2, edge)
    rect(img, 1, 1, size - 2, size - 2, body)
    rect(img, 2, 1, size - 4, 1, light)                             # top edge
    rect(img, 1, 2, 1, size - 4, light)                             # left edge
    rect(img, 2, size - 2, size - 4, 1, dark)                       # bottom edge
    rect(img, size - 2, 2, 1, size - 4, dark)                       # right edge
    if inner:
        rect(img, 3, 3, size - 6, size - 6, inner)
    save(img, name)


def button(name, base, text_dark=False):
    """Three states of a 24 px tall button: 2 px top highlight, flat body, 3 px dark lower lip.
    Pressed sits 2 px lower with no lip."""
    hi, lip, edge = mix(base, "ffffff", 0.38), mix(base, "000000", 0.48), "05070d"
    for state, body in (("n", base), ("h", mix(base, "ffffff", 0.16)), ("p", mix(base, "000000", 0.18))):
        img = new(12, 24)
        top = 2 if state == "p" else 0
        rect(img, 1, top, 10, 24 - top, edge)
        rect(img, 0, top + 1, 12, 22 - top, edge)
        rect(img, 1, top + 1, 10, 22 - top, body)
        rect(img, 2, top + 1, 8, 1, mix(hi, "ffffff", 0.3))
        rect(img, 1, top + 2, 10, 1, hi)
        if state == "p":
            rect(img, 1, 22, 10, 1, lip)
        else:
            rect(img, 1, 20, 10, 3, lip)
            rect(img, 1, 20, 10, 1, mix(base, "000000", 0.28))
        save(img, "btn_%s_%s" % (name, state))


def frames_and_buttons():
    frame("card", "121830", "4a5c96", "0a0e1e", size=24)
    frame("card_hot", "18203e", "bfeaff", "2a6a9a", edge="4fd6ff", size=24)
    frame("plate", "141a2e", "4a5c96", "0a0e1e", size=24)
    frame("well", "090c18", "05070d", "2a3558", edge="05070d", shadow=0, size=12)   # sunken area
    frame("tile", "1a2240", "55689e", "0d1226", shadow=1, size=16)
    frame("tile_owned", "14301e", "58c070", "0a1a10", edge="06140a", shadow=1, size=16)
    frame("chip", "2a3560", "6076b0", "161c36", shadow=0, size=10)
    frame("keycap", "d8deea", "ffffff", "8a94b0", edge="1a2038", shadow=2, size=12)
    button("green", "2f9e48")
    button("yellow", "c89a1e")
    button("red", "c2402e")
    button("blue", "34509a")
    button("grey", "3a4058")


# ---------------------------------------------------------------- logo

def font_glyphs():
    fnt = os.path.join(ROOT, "art", "font.fnt")
    atlas = np.array(Image.open(os.path.join(ROOT, "art", "font.png")).convert("RGBA"))
    glyphs = {}
    for line in open(fnt):
        if line.startswith("char id="):
            kv = dict(p.split("=") for p in line.split()[1:])
            x, y, w, h = int(kv["x"]), int(kv["y"]), int(kv["width"]), int(kv["height"])
            glyphs[chr(int(kv["id"]))] = atlas[y:y + h, x:x + w, 3] > 128
    return glyphs


def word_mask(text, scale, gap, bold=0):
    """The game font blown up by a whole number, optionally thickened sideways into a display weight."""
    g = font_glyphs()
    cells = []
    for ch in text:
        if ch == " ":
            cells.append(np.zeros((9 * scale, 3 * scale), dtype=bool))
            continue
        m = np.kron(g[ch], np.ones((scale, scale), dtype=bool))
        if bold:
            wide = np.zeros((m.shape[0], m.shape[1] + bold), dtype=bool)
            for b in range(bold + 1):
                wide[:, b:b + m.shape[1]] |= m
            m = wide
        cells.append(m)
    w = sum(c.shape[1] for c in cells) + gap * (len(cells) - 1)
    out = np.zeros((9 * scale, w), dtype=bool)
    x = 0
    for c in cells:
        out[:c.shape[0], x:x + c.shape[1]] = c
        x += c.shape[1] + gap
    ys = np.where(out.any(axis=1))[0]
    return out[ys.min():ys.max() + 1]


def lettering(mask, bands, top_light, low_shade, rim, pad=3):
    """Flat colour bands down the letters, a lit top edge, a shaded lower edge, a 2 px dark rim."""
    h, w = mask.shape
    img = new(w + 2 * pad, h + 2 * pad + 2)
    m = np.zeros(img.shape[:2], dtype=bool)
    m[pad:pad + h, pad:pad + w] = mask
    grow = m.copy()
    for _ in range(2):
        g2 = grow.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            g2 |= np.roll(np.roll(grow, dy, 0), dx, 1)
        grow = g2
    shadow = np.roll(grow, 2, 0)
    img[shadow] = hexc("05070d", 170)
    img[grow] = hexc(rim)
    for y in range(h):
        col = bands[min(len(bands) - 1, y * len(bands) // h)]
        row = m[pad + y]
        img[pad + y][row] = hexc(col)
    up = np.roll(m, 1, 0)
    down = np.roll(m, -1, 0)
    img[m & ~up] = hexc(top_light)
    img[m & ~down] = hexc(low_shade)
    return img


def logo():
    big = lettering(word_mask("SPACE MISSION", 3, 4, bold=2),
                    ["fff4b8", "ffe27a", "ffd75e", "ffc23c", "f6a428", "e88a1c", "d87616"], "fffbe6", "a85a10", OL)
    small = lettering(word_mask("DESIGNER", 2, 8, bold=1), ["e8f6ff", "bfeaff", "8fd8ff", "4fd6ff"], "ffffff", "2a86b8", OL)
    bh, bw = big.shape[:2]
    sh, sw = small.shape[:2]
    w = bw + 40
    h = bh + sh - 1
    img = new(w, h)
    cx, cy = w // 2, bh // 2 + 3
    # the orbit: a dotted ellipse behind the lettering, brighter on the near (lower) arc
    a, b = w / 2 - 3, bh / 2 + 6
    for i in range(720):
        th = i / 720 * 2 * math.pi
        x, y = int(round(cx + a * math.cos(th))), int(round(cy + b * math.sin(th)))
        if 0 <= x < w and 0 <= y < h:
            near = math.sin(th) > 0
            if (i // 6) % 2 == 0 or near:
                img[y, x] = hexc("8fd8ff" if near else "34509a")
    paste(img, big, (w - bw) // 2, 0)
    sx = (w - sw) // 2
    sy = bh - 3
    rule_y = sy + sh // 2 - 1
    for x0, x1 in ((sx - 58, sx - 8), (sx + sw + 8, sx + sw + 58)):
        rect(img, x0, rule_y, x1 - x0, 2, "4fd6ff")
        rect(img, x0, rule_y + 2, x1 - x0, 1, "05070d")
        rect(img, x0 - 1, rule_y - 1, x1 - x0 + 2, 1, OL)
    paste(img, small, sx, sy)
    save(img, "logo")
    return {"w": w, "h": h, "cx": cx, "cy": cy, "a": a, "b": b}


# ---------------------------------------------------------------- icons (12x12 unless noted)

GOLD = {"o": OL, "a": "7c5418", "b": "b3812a", "c": "dcae44", "d": "f6dc84", "w": "fffbe6"}
UIP = {"o": OL, "w": "ffffff", "t": "e8ecff", "d": "8a94b8", "n": "3a4a7a", "c": "4fd6ff", "C": "1d6a9a",
       "y": "ffd75e", "Y": "b8860b", "g": "6dff8a", "G": "1e8a3c", "r": "ff5a5a", "R": "8c1e22",
       "m": "b4bcc8", "M": "4e5566", "k": "1d2540", "e": "f08a2a", "p": "ff7ad9"}


def icons():
    ic = {
        "coin": art([
            "...cccccc...",
            "..cddddddb..",
            ".cddwddddbb.",
            ".cdwddccdbb.",
            "cddddcbbddba",
            "cdddcbddddba",
            "cdddcbddddba",
            "cddddcbbddba",
            ".cdddddddba.",
            ".bbddddddba.",
            "..bbbbbbba..",
            "...aaaaaa...",
        ], GOLD),
        "gravity": art([
            "..mmmmmmmm..",
            "..mMMMMMMm..",
            "............",
            ".....ww.....",
            ".....ww.....",
            ".....ww.....",
            ".....ww.....",
            "..w..ww..w..",
            "..ww.ww.ww..",
            "...wwwwww...",
            "....wwww....",
            ".....ww.....",
        ], UIP),
        "sun": art([
            ".....yy.....",
            ".y...yy...y.",
            "..y......y..",
            "....yyyy....",
            "...ywwwwy...",
            "yy.ywwwwy.yy",
            "yy.ywwwwy.yy",
            "...ywwwwy...",
            "....yyyy....",
            "..y......y..",
            ".y...yy...y.",
            ".....yy.....",
        ], UIP),
        "radio": art([
            "c.........c.",
            ".c..cccc...c",
            "..c.c..c.c.c",
            "..c.cwwc.c.c",
            "..c.cwwc.c.c",
            ".c..cccc...c",
            "c....mm...c.",
            ".....mm.....",
            "....mmmm....",
            "....m..m....",
            "...mm..mm...",
            "..mmm..mmm..",
        ], UIP),
        "clock": art([
            "...wwwwww...",
            "..wkkkkkkw..",
            ".wkkkwwkkkw.",
            "wkkkkwwkkkkw",
            "wkkkkwwkkkkw",
            "wkkkkwwwwkkw",
            "wkkkkwwwwkkw",
            "wkkkkkkkkkkw",
            "wkkkkkkkkkkw",
            ".wkkkkkkkkw.",
            "..wkkkkkkw..",
            "...wwwwww...",
        ], UIP),
        "lock": art([
            "...mmmmmm...",
            "..mm....mm..",
            "..mm....mm..",
            "..mm....mm..",
            ".yyyyyyyyyy.",
            ".yyyyyyyyyy.",
            ".yyyykkyyyy.",
            ".yyyykkyyyy.",
            ".yyyyykyyyy.",
            ".YyyyyyyyyY.",
            ".YYYYYYYYYY.",
            "............",
        ], UIP),
        "tick": art([
            "............",
            "..........gg",
            ".........ggg",
            "........gggG",
            ".......gggG.",
            "gg....gggG..",
            "ggg..gggG...",
            "GggggggG....",
            ".GggggG.....",
            "..GggG......",
            "...GG.......",
            "............",
        ], UIP),
        "cross": art([
            "............",
            ".rr......rr.",
            ".rrr....rrr.",
            "..rrr..rrrR.",
            "...rrrrrrR..",
            "....rrrrR...",
            "....rrrrR...",
            "...rrrrrrR..",
            "..rrrRRrrr..",
            ".rrrR..Rrrr.",
            ".rrR....Rrr.",
            "..R......R..",
        ], UIP),
        "dash": art([
            "............",
            "............",
            "............",
            "............",
            "............",
            "..dddddddd..",
            "..dddddddd..",
            "..nnnnnnnn..",
            "............",
            "............",
            "............",
            "............",
        ], UIP),
        "flask": art([
            "....wwww....",
            "....w..w....",
            ".....ww.....",
            ".....ww.....",
            "....w..w....",
            "....w..w....",
            "...w....w...",
            "...wggggw...",
            "..wgggwggw..",
            "..wggggggw..",
            ".wgwgggGggw.",
            ".wwwwwwwwww.",
        ], UIP),
        "help": art([
            "...yyyyyy...",
            "..yyyyyyyy..",
            ".yyy....yyy.",
            ".yy......yy.",
            ".........yy.",
            "........yyy.",
            "......yyyy..",
            ".....yyy....",
            ".....yy.....",
            "............",
            ".....yy.....",
            ".....yy.....",
        ], UIP),
        "book": art([
            ".cccc..cccc.",
            "cwwwwccwwwwc",
            "cwddwccwddwc",
            "cwwwwccwwwwc",
            "cwddwccwddwc",
            "cwwwwccwwwwc",
            "cwddwccwddwc",
            "cwwwwccwwwwc",
            "cwwwwccwwwwc",
            "cccccccccccc",
            ".CCCCCCCCCC.",
            "............",
        ], UIP),
        "helmet": art([
            "...wwwwww...",
            "..wwwwwwww..",
            ".wwwwwwwwww.",
            ".wwkkkkkkww.",
            ".wkcckkkkkw.",
            ".wkckkkkkkw.",
            ".wkkkkkkkkw.",
            ".wwkkkkkkww.",
            ".mwwwwwwwwm.",
            "..mmmmmmmm..",
            "..meemmmmm..",
            "..mmmmmmmm..",
        ], UIP),
        "helmet_off": art([
            "...nnnnnn...",
            "..nnnnnnnn..",
            ".nnnnnnnnnn.",
            ".nnkkkkkknn.",
            ".nkkkkkkkkn.",
            ".nkkkkkkkkn.",
            ".nkkkkkkkkn.",
            ".nnkkkkkknn.",
            ".knnnnnnnnk.",
            "..kkkkkkkk..",
            "..kkkkkkkk..",
            "..kkkkkkkk..",
        ], UIP),
        "play": art([
            "............",
            "..ww........",
            "..wwww......",
            "..wwwwww....",
            "..wwwwwwww..",
            "..wwwwwwwww.",
            "..wwwwwwwww.",
            "..wwwwwwww..",
            "..wwwwww....",
            "..wwww......",
            "..ww........",
            "............",
        ], UIP),
        "warn": art([
            ".....rr.....",
            "....rrrr....",
            "....rwwr....",
            "...rrwwrr...",
            "...rrwwrr...",
            "..rrrwwrrr..",
            "..rrrwwrrr..",
            ".rrrrwwrrrr.",
            ".rrrrrrrrrr.",
            "rrrrrwwrrrrr",
            "rrrrrwwrrrrr",
            "RRRRRRRRRRRR",
        ], UIP),
        "wrench": art([
            "........ggg.",
            ".......gg...",
            "......gg...g",
            "......gg..gg",
            "......ggggg.",
            ".....gggggg.",
            "....ggg.....",
            "...ggg......",
            "..ggg.......",
            ".ggg........",
            "ggG.........",
            "gG..........",
        ], UIP),
        "fact": art([
            "..cccccccc..",
            ".cccccccccc.",
            "cccckwwkcccc",
            "cccckwwkcccc",
            "cccccccccccc",
            "cccwwwwkcccc",
            "cccckwwkcccc",
            "cccckwwkcccc",
            "cccckwwkcccc",
            "cccwwwwwwccc",
            ".cccccccccc.",
            "..CCCCCCCC..",
        ], UIP),
        "next": art([
            "............",
            "....ww......",
            "....www.....",
            ".....www....",
            "......www...",
            ".......www..",
            ".......www..",
            "......www...",
            ".....www....",
            "....www.....",
            "....ww......",
            "............",
        ], UIP),
        "star": art([
            ".....yy.....",
            ".....yy.....",
            "....ywwy....",
            "yyyyywwyyyyy",
            ".yywwwwwwyy.",
            "..yywwwwyy..",
            "...ywwwwy...",
            "..yywwwwyy..",
            "..ywwyywwy..",
            ".yyyy..yyyy.",
            ".yy......yy.",
            "............",
        ], UIP),
        "close": art([
            "............",
            ".ww......ww.",
            ".www....www.",
            "..www..www..",
            "...wwwwww...",
            "....wwww....",
            "....wwww....",
            "...wwwwww...",
            "..www..www..",
            ".www....www.",
            ".ww......ww.",
            "............",
        ], UIP),
    }
    for name, img in ic.items():
        # coloured line icons get a dark outline so they read on any plate; solid ones already have an edge
        save(outline(img) if name not in ("coin",) else outline(img), "ic_" + name)
    # role icons for the report's team bars (planner clipboard, engineer wrench, scientist flask, comms dish)
    for name, col in (("lamp_go", ("6dff8a", "1e8a3c", "d8ffe0")), ("lamp_nogo", ("ff5a5a", "8c1e22", "ffd0d0")),
                      ("lamp_off", ("3a4058", "1e2232", "55607e")), ("lamp_warn", ("ffd75e", "b8860b", "fff6c8"))):
        lamp = art([
            "..aaaa..",
            ".awaaab.",
            "awwaaaab",
            "awaaaaab",
            "aaaaaabb",
            "aaaaaabb",
            ".aaaabb.",
            "..bbbb..",
        ], {"a": col[0], "b": col[1], "w": col[2]})
        save(outline(lamp), name)
    for name, col in (("g", ("6dff8a", "1e8a3c", "d8ffe0")), ("y", ("ffd75e", "b8860b", "fff6c8")), ("r", ("ff5a5a", "8c1e22", "ffd0d0"))):
        pip = art([
            ".aaaaa.",
            "awwaaab",
            "awaaaab",
            "aaaaaab",
            "aaaaabb",
            "aaaabbb",
            ".bbbbb.",
        ], {"a": col[0], "b": col[1], "w": col[2]})
        save(outline(pip), "pip_" + name)
    pip_off = art([
        ".kkkkk.",
        "kkkkkkn",
        "kkkkkkn",
        "kkkkkkn",
        "kkkkknn",
        "kkkknnn",
        ".nnnnn.",
    ], {"k": "0d1122", "n": "2a3558"})
    save(outline(pip_off, "2a3558"), "pip_off")


# ---------------------------------------------------------------- medals and mission patches

METALS = {
    "gold": ["7c5418", "b3812a", "dcae44", "f6dc84", "fffbe6"],
    "silver": ["4e5566", "7d8697", "b4bcc8", "dfe4ea", "ffffff"],
    "bronze": ["4a2414", "7c3e1e", "b0622e", "d88c4c", "f4c08c"],
    "fail": ["1e2232", "2e3448", "454d66", "6a7290", "8a94b0"],
}


def disc_mask(d):
    ys, xs = np.mgrid[0:d, 0:d]
    c = (d - 1) / 2.0
    return np.sqrt((xs - c) ** 2 + (ys - c) ** 2)


def medal(metal):
    """16x24: a ribbon and a round medal with a star, lit from the upper left."""
    m = METALS[metal]
    img = new(16, 24)
    rib = ("2a6a9a", "4fd6ff") if metal != "bronze" else ("8c1e22", "ff5a5a")
    for y in range(0, 10):
        rect(img, 3, y, 4, 1, rib[0])
        rect(img, 9, y, 4, 1, rib[0])
        rect(img, 4, y, 2, 1, rib[1])
        rect(img, 10, y, 2, 1, rib[1])
    rect(img, 6, 6, 4, 3, m[1])
    r = disc_mask(14)
    face = new(14, 14)
    face[r <= 7.0] = hexc(m[2])
    ys, xs = np.mgrid[0:14, 0:14]
    face[(r <= 7.0) & (r > 5.4)] = hexc(m[1])
    face[(r <= 7.0) & (r > 5.4) & (xs + ys < 11)] = hexc(m[3])
    face[(r <= 5.4) & (xs + ys < 9)] = hexc(m[3])
    star = ["...w...", "..www..", "wwwwwww", ".wwwww.", ".ww.ww.", "w.....w"] if metal != "fail" else []
    for sy, row in enumerate(star):
        for sx, ch in enumerate(row):
            if ch == "w":
                face[4 + sy, 3 + sx] = hexc(m[4])
            if ch == "w" and sy >= 3:
                face[4 + sy, 3 + sx] = hexc(m[0]) if False else hexc(m[4])
    paste(img, face, 1, 9)
    save(outline(img), "medal_" + metal)


def patch(dest, metal):
    """64x64 embroidered mission patch: a rope rim in the medal's metal, the destination over a dark sky,
    an orbit arc and a small ship star. A failed mission gets a grey rim and a torn stitch."""
    d = 64
    m = METALS[metal]
    img = new(d, d)
    r = disc_mask(d)
    ys, xs = np.mgrid[0:d, 0:d]
    img[r <= 31.5] = hexc(OL)
    rim = (r <= 30.5) & (r > 25.5)
    img[rim] = hexc(m[2])
    img[rim & (xs + ys < 54)] = hexc(m[3])
    img[rim & (xs + ys > 78)] = hexc(m[1])
    ang = np.arctan2(ys - 31.5, xs - 31.5)
    stitch = rim & (r > 27.0) & (r <= 29.0) & (np.floor((ang + math.pi) / (2 * math.pi) * 40).astype(int) % 2 == 0)
    img[stitch] = hexc(m[4] if metal != "fail" else m[0])
    img[(r <= 25.5) & (r > 24.5)] = hexc(OL)
    sky = r <= 24.5
    img[sky] = hexc("0e1430")
    img[sky & (ys > 38)] = hexc("131c40")
    rng = np.random.default_rng(len(dest) * 7 + 3)
    for _ in range(16):
        x, y = rng.integers(10, 54), rng.integers(10, 54)
        if sky[y, x]:
            img[y, x] = hexc("8a94b8" if rng.random() < 0.6 else "e8ecff")
    maps = {"moon": planets.moon_map, "mars": planets.mars_map, "saturn": planets.saturn_map}[dest]()
    if dest == "saturn":
        body = planets.shade(maps[0], maps[1], 22, 0.1, tilt=math.radians(-13), squash=0.93, pad=3, ring=planets.ring_lut())
    else:
        body = planets.shade(maps[0], maps[1], 30, 0.3, pad=0)
    bh, bw = body.shape[:2]
    bx, by = (d - bw) // 2, (d - bh) // 2 + (2 if dest == "saturn" else 3)
    sub = img[by:by + bh, bx:bx + bw]
    keep = (body[..., 3] > 0) & sky[by:by + bh, bx:bx + bw]
    sub[keep] = body[keep]
    # a ship's path: dotted arc over the planet ending in a bright star
    for i in range(0, 30):
        th = math.radians(200 + i * 4.2)
        x, y = int(round(31.5 + 21 * math.cos(th))), int(round(34 + 19 * math.sin(th)))
        if sky[y, x] and i % 2 == 0:
            img[y, x] = hexc("4fd6ff")
    sx, sy = int(round(31.5 + 21 * math.cos(math.radians(326)))), int(round(34 + 19 * math.sin(math.radians(326))))
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
        img[sy + dy, sx + dx] = hexc("ffffff" if abs(dx) + abs(dy) < 2 else "ffd75e")
    if metal == "fail":
        img[..., :3] = np.where((img[..., 3:4] > 0) & sky[..., None], (img[..., :3] * 0.55).astype(np.uint8), img[..., :3])
        for i in range(18, 46):                                  # a red tear across the patch
            x = i
            y = 22 + int((i - 18) * 0.75) + (1 if i % 5 < 2 else 0)
            img[y, x] = hexc("ff5a5a")
            img[y + 1, x] = hexc("8c1e22")
    save(img, "patch_%s_%s" % (dest, metal))


# ---------------------------------------------------------------- Tech Lab icons (24x24)

def tech_icons():
    pal = {"o": OL, "1": "101a3c", "2": "1a2c66", "3": "2b4796", "4": "4f74c8", "5": "9cc0ff",
           "m": "7d8697", "M": "4e5566", "l": "dfe4ea", "w": "ffffff", "g": "6dff8a", "G": "1e8a3c",
           "y": "ffd75e", "Y": "b8860b", "d": "f6dc84", "a": "7c5418", "r": "ff5a5a", "R": "8c1e22",
           "c": "4fd6ff", "C": "1d6a9a", "k": "1e2232", "K": "2e3448", "p": "d6dcea", "P": "a3abc4", "e": "f08a2a"}
    t = {
        "solar2": [
            "........................",
            "........................",
            "..4444444444..4444444444",
            "..4335335334..4335335334",
            "..4335335334..4335335334",
            "..4224224224..4224224224",
            "..4335335334mm4335335334",
            "..4335335334ll4335335334",
            "..4224224224mm4224224224",
            "..4335335334..4335335334",
            "..4335335334..4335335334",
            "..4224224224..4224224224",
            "..4335335334..4335335334",
            "..4335335334..4335335334",
            "..1111111111..1111111111",
            "........................",
            "..........gg............",
            ".........gggg...........",
            "........gggggg..........",
            "..........gg............",
            "..........gg............",
            "..........GG............",
            "........................",
            "........................",
        ],
        "batt2": [
            "........................",
            "........mmmmmmmm........",
            "........mllllllm........",
            ".....MMMMMMMMMMMMMM.....",
            ".....MppppppppppppM.....",
            ".....MpPPPPPPPPPPpM.....",
            ".....MpkkkkkkkkkkPM.....",
            ".....MpkkkkkkyykkPM.....",
            ".....MpkkkkkyykkkPM.....",
            ".....MpkkkkyykkkkPM.....",
            ".....MpkkkyyyyyykPM.....",
            ".....MpkkkkkkyykkPM.....",
            ".....MpkkkkkyykkkPM.....",
            ".....MpkkkkyykkkkPM.....",
            ".....MpkkkyykkkkkPM.....",
            ".....MpkkkkkkkkkkPM.....",
            ".....MpggggggggggPM.....",
            ".....MpggggggggggPM.....",
            ".....MpGGGGGGGGGGPM.....",
            ".....MpPPPPPPPPPPPM.....",
            ".....MMMMMMMMMMMMMM.....",
            "........................",
            "........................",
            "........................",
        ],
        "ka": [
            "........................",
            "..............c....c....",
            "...............c....c...",
            "....pppp....c...c...c...",
            "..ppllllpp...c..c....c..",
            ".pllllllllp..c...c...c..",
            ".pllllllllPp.c...c...c..",
            "pllllllllllPp...c....c..",
            "plllllleellPp..c....c...",
            "pllllleeeelPp.c....c....",
            "plllllleellPp...........",
            "pllllllllllPp...........",
            ".pllllllllPP............",
            ".pPllllllPPp............",
            "..ppPPPPPpp.............",
            "....ppppMM..............",
            ".......MMMM.............",
            "......MMmmMM............",
            ".....MMmmmmMM...........",
            "....MMMMMMMMMM..........",
            "....kkkkkkkkkk..........",
            "........................",
            "........................",
            "........................",
        ],
        "rover2": [
            "........................",
            "................ll......",
            "...............lccl.....",
            "................ll......",
            "................mm......",
            "....444444444...mm......",
            "....433533534...mm......",
            "....444444444...mm......",
            "......mm........mm......",
            "..pppppppppppppppppp....",
            ".pllllllllllllllllllp...",
            ".plPPPPPPPPPPPPPPPPlp.ee",
            ".plPPPPPPPPPPPPPPPPlpee.",
            ".pPPPPPPPPPPPPPPPPPPp...",
            "..MMMMMMMMMMMMMMMMMM....",
            "...kkkk...kkkk...kkkk...",
            "..kKKKKk.kKKKKk.kKKKKk..",
            ".kKKmmKKkKKmmKKkKKmmKKk.",
            ".kKKmmKKkKKmmKKkKKmmKKk.",
            "..kKKKKk.kKKKKk.kKKKKk..",
            "...kkkk...kkkk...kkkk...",
            "........................",
            "........................",
            "........................",
        ],
        "armor": [
            "........................",
            "...cccccccccccccccccc...",
            "..cccwwwwwwwwwwwwwwccc..",
            "..ccwCCCCCCCCCCCCCCwcc..",
            "..cwCCCCCCCCCCCCCCCCwc..",
            "..cwCCCCCCCwwCCCCCCCwc..",
            "..cwCCCCCCCwwCCCCCCCwc..",
            "..cwCCCCCCCwwCCCCCCCwc..",
            "..cwCCCCwwwwwwwwCCCCwc..",
            "..cwCCCCwwwwwwwwCCCCwc..",
            "..cwCCCCCCCwwCCCCCCCwc..",
            "..cwCCCCCCCwwCCCCCCCwc..",
            "..ccwCCCCCCwwCCCCCCwcc..",
            "...cwCCCCCCCCCCCCCCwc...",
            "...ccwCCCCCCCCCCCCwcc...",
            "....ccwCCCCCCCCCCwcc....",
            ".....ccwCCCCCCCCwcc.....",
            "......ccwwCCCCwwcc......",
            ".......cccwwwwccc.......",
            ".........cccccc.........",
            "...........cc...........",
            "........................",
            "........................",
            "........................",
        ],
        "grant": [
            "........................",
            "........................",
            "....GGGGGGGGGGGGGGGGGG..",
            "....GggggggggggggggggG..",
            "....GgGGGGGGGGGGGGGGgG..",
            "..GGGGGGGGGGGGGGGGGGgG..",
            "..GggggggggggggggggGgG..",
            "..GgGGGGGGGGGGGGGGgGgG..",
            "GGGGGGGGGGGGGGGGGGgGgG..",
            "GggggggggggggggggGgGGG..",
            "GgGGGGGGGwwGGGGGgGgG....",
            "GgGGGGGwwwwwwGGGgGgG....",
            "GgGGGGGwwGGGGGGGgGGG....",
            "GgGGGGGwwwwwwGGGgG......",
            "GgGGGGGGGGGwwGGGgG......",
            "GgGGGGGwwwwwwGGGgG......",
            "GgGGGGGGGwwGGGGGgG......",
            "GggggggggggggggggG......",
            "GGGGGGGGGGGGGGGGGG......",
            "........................",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
    }
    for name, rows in t.items():
        save(outline(art(rows, pal))[1:-1, 1:-1], "tech_" + name)


# ---------------------------------------------------------------- small props

def props():
    maps = {"moon": planets.moon_map(), "mars": planets.mars_map(), "saturn": planets.saturn_map()}
    save(planets.shade(maps["moon"][0], maps["moon"][1], 26, 0.3), "mini_moon")
    save(planets.shade(maps["mars"][0], maps["mars"][1], 26, 0.55), "mini_mars")
    sat = planets.shade(maps["saturn"][0], maps["saturn"][1], 20, 0.1, tilt=math.radians(-13), squash=0.93, pad=4, ring=planets.ring_lut())
    ys, xs = np.where(sat[..., 3] > 0)
    save(sat[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "mini_saturn")
    pal = {"o": OL, "1": "1a2c66", "2": "2b4796", "3": "4f74c8", "g": "b3812a", "G": "dcae44", "d": "f6dc84",
           "m": "7d8697", "l": "dfe4ea", "w": "ffffff", "r": "ff5a5a", "p": "d6dcea", "P": "a3abc4", "k": "2e3448", "e": "f08a2a"}
    sat_rows = [
        "...........ll..............",
        "...........mm..............",
        "3333333333.gG.3333333333...",
        "3223223223gGGd3223223223...",
        "3223223223GGGd3223223223.ll",
        "3333333333gGGdmmmmmmmmmmmlw",
        "3223223223gGGd3223223223.ll",
        "3223223223gGGG3223223223...",
        "3333333333.gG.3333333333...",
        "...........mm..............",
    ]
    save(outline(art(sat_rows, pal)), "satellite")
    rocket_rows = [
        "..rr.........",
        ".rrppppppl...",
        "kkpPPPPPPpll.",
        "kkpPPPcPPppww",
        "kkpPPPPPPpll.",
        ".rrppppppl...",
        "..rr.........",
    ]
    pal2 = dict(pal)
    pal2["c"] = "4fd6ff"
    save(outline(art(rocket_rows, pal2)), "logo_rocket")
    # a strip of grey ground for the How To Play landing picture
    w, h = 140, 16
    g = new(w, h)
    rng = np.random.default_rng(3)
    top = (2 + 1.5 * np.sin(np.arange(w) / 9.0) + rng.random(w) * 0.8).astype(int)
    for x in range(w):
        g[top[x]:, x] = hexc("4a4a5e")
        g[top[x], x] = hexc("9c9cb0")
        g[top[x] + 1:top[x] + 3, x] = hexc("707086")
        g[10:, x] = hexc("38384a")
    for _ in range(9):
        cx = rng.integers(4, w - 6)
        g[top[cx] + 3:top[cx] + 5, cx:cx + rng.integers(3, 7)] = hexc("2a2a3a")
    save(g, "ground_moon")


def sheet():
    os.makedirs(WORK, exist_ok=True)
    names = sorted(MADE)
    scale, pad, wmax = 4, 6, 1500
    x = y = pad
    row_h = 0
    places = []
    for n in names:
        a = MADE[n]
        w, h = a.shape[1] * scale, a.shape[0] * scale
        if x + w + pad > wmax:
            x, y, row_h = pad, y + row_h + pad, 0
        places.append((n, x, y))
        x += w + pad
        row_h = max(row_h, h)
    out = Image.new("RGBA", (wmax, y + row_h + pad), (24, 30, 52, 255))
    for n, px, py in places:
        im = Image.fromarray(MADE[n]).resize((MADE[n].shape[1] * scale, MADE[n].shape[0] * scale), Image.NEAREST)
        out.alpha_composite(im, (px, py))
    out.save(os.path.join(WORK, "ui_sheet.png"))


def main():
    frames_and_buttons()
    info = logo()
    icons()
    for m in METALS:
        medal(m)
        for d in ("moon", "mars", "saturn"):
            patch(d, m)
    tech_icons()
    props()
    if "preview" in sys.argv:
        sheet()
    print("menu ui art written to", OUT, "logo:", info)


if __name__ == "__main__":
    main()
