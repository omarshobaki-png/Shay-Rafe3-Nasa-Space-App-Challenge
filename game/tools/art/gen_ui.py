"""UI kit textures for Space Mission Designer, all drawn in code (numpy / PIL, no source images).

    python tools/art/gen_ui.py [reference_sheet.png]

Writes art/ui/*.png: 9-slice frames and buttons, parts-bin tiles, lamps, attach node, gauge,
scrollbar, checkbox and separator pieces, and the 12 x 12 icons. With a path argument it also writes
a reference sheet of every texture at 4x with its name.
Rules: light from the upper left, outline #05070d, 3-4 flat tones per material, every edge of a
9-slice texture is uniform along its length so it can stretch (margins are listed in scripts/pix.gd).
The display font is made by tools/art/gen_ui_font.py.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parents[2] / "art" / "ui"


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OL = C("05070d")
CLEAR = (0, 0, 0, 0)


class Im:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def rect(self, x, y, w, h, c):
        if w > 0 and h > 0:
            self.a[max(y, 0):y + h, max(x, 0):x + w] = c

    def px(self, x, y, c):
        self.a[y, x] = c

    def mask(self, inset, cut):
        """Boolean mask of the rectangle inset by `inset`, corners chamfered by `cut` pixels."""
        m = np.zeros((self.h, self.w), bool)
        w, h = self.w - 2 * inset, self.h - 2 * inset
        for j in range(h):
            k = max(0, cut - j, cut - (h - 1 - j))
            m[inset + j, inset + k:inset + w - k] = True
        return m

    def ring(self, inset, cut, cut_in, light, dark, mid=None):
        """One-pixel ring at `inset`: `light` on the top and left, `dark` on the bottom and right."""
        m = self.mask(inset, cut) & ~self.mask(inset + 1, cut_in)
        mid = mid if mid is not None else light
        ys, xs = np.nonzero(m)
        for x, y in zip(xs, ys):
            top, left = y == inset, x == inset
            bottom, right = y == self.h - 1 - inset, x == self.w - 1 - inset
            if (top and right) or (bottom and left):
                c = mid
            elif top or left:
                c = light
            elif bottom or right:
                c = dark
            else:  # chamfer pixel: by quadrant
                lx, ty = x < self.w / 2, y < self.h / 2
                c = light if (lx and ty) else dark if (not lx and not ty) else mid
            self.a[y, x] = c

    def fill(self, inset, cut, c):
        self.a[self.mask(inset, cut)] = c

    def art(self, x, y, rows, pal):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.a[y + j, x + i] = pal[ch]

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.a, "RGBA").save(OUT / f"{name}.png")


# ---------------------------------------------------------------- frames (9-slice)

def gusset(im, n, colours, dot=None):
    """Corner gussets: a 3 px triangle of frame metal inside ring `n` at every corner, with one bolt pixel.
    colours = (top-left, bottom-right, the other two); stays inside the 6 px 9-slice margin."""
    lt, dk, md = colours
    for sx in (0, 1):
        for sy in (0, 1):
            c = lt if (sx == 0 and sy == 0) else dk if (sx == 1 and sy == 1) else md
            for i in range(3):
                for j in range(3 - i):
                    x = n + i if sx == 0 else im.w - 1 - n - i
                    y = n + j if sy == 0 else im.h - 1 - n - j
                    im.px(x, y, c)
            if dot:
                im.px(n if sx == 0 else im.w - 1 - n, n if sy == 0 else im.h - 1 - n, dot)


def plate(name, size, cut, rings, face, groove=None, bolt=None):
    """Bevelled plate: outline, then `rings` = [(light, dark, mid)] from the outside in, then the face.
    `groove` = (shadow, lip): a recess line inside the frame (shadow under the top and left, lit lip at the
    bottom and right) and corner gussets in the colours of the last ring, each with a `bolt` pixel."""
    im = Im(size, size)
    im.ring(0, cut, max(cut - 1, 0), OL, OL)
    for i, (lt, dk, md) in enumerate(rings):
        im.ring(i + 1, max(cut - 1 - i, 0), max(cut - 2 - i, 0), lt, dk, md)
    n = len(rings) + 1
    im.fill(n, max(cut - n, 0), face)
    if groove:
        im.ring(n, 3, 3, groove[0], groove[1], groove[0])
        gusset(im, n, rings[-1], bolt)
    im.save(name)
    return im


def frames():
    # panel: dark metal plate, 2 px rim lit from the upper left, a recess line, bolted corner gussets,
    # slightly translucent body
    plate("panel", 24, 2,
          [(C("8497d6"), C("28325c"), C("46568e")), (C("46568e"), C("1c2448"), C("2e3a6a"))],
          C("151b30", 240), groove=(C("080b17", 250), C("1f2848", 245)), bolt=C("b9c6f2"))
    plate("panel_dark", 24, 2,
          [(C("6a7cba"), C("1d2547"), C("36437a")), (C("36437a"), C("12172f"), C("222b50"))],
          C("0a0e1c", 246), groove=(C("03050b", 250), C("161c36", 248)), bolt=C("94a6dc"))
    # trim: white mask drawn over a panel and tinted (UI.panel(bg, border) with a custom border colour)
    im = Im(24, 24)
    w = (255, 255, 255, 255)
    im.ring(1, 1, 0, w, (255, 255, 255, 150), (255, 255, 255, 200))
    im.ring(2, 0, 0, (255, 255, 255, 110), (255, 255, 255, 60), (255, 255, 255, 80))
    gusset(im, 3, ((255, 255, 255, 110), (255, 255, 255, 60), (255, 255, 255, 80)), (255, 255, 255, 230))
    im.save("panel_trim")
    # tooltip: near-black note with a thin gold line
    plate("tooltip", 16, 1, [(C("e2bd4f"), C("8f7226"), C("b8963a"))], C("070a13", 250))
    # hud: frame only (the translucent body is drawn in code so it can be tinted), plus a trim mask
    im = Im(24, 24)
    im.ring(0, 1, 0, OL, OL)
    im.ring(1, 0, 0, (255, 255, 255, 26), (0, 0, 0, 90), (0, 0, 0, 0))
    im.save("hud")
    im = Im(24, 24)
    line = (255, 255, 255, 120)
    im.ring(1, 0, 0, (255, 255, 255, 170), line, line)
    for sx in (0, 1):  # corner brackets, 2 px thick, 6 px long
        for sy in (0, 1):
            for k in range(6):
                for t in (1, 2):
                    x = (1 + k) if sx == 0 else (22 - k)
                    y = t if sy == 0 else (23 - t)
                    im.px(x, y, w)
                    x = t if sx == 0 else (23 - t)
                    y = (1 + k) if sy == 0 else (22 - k)
                    im.px(x, y, w)
    im.save("hud_trim")
    # key cap for key prompts
    im = Im(12, 13)
    im.ring(0, 1, 0, OL, OL)
    im.rect(1, 1, 10, 9, C("dfe4f5"))
    im.rect(1, 1, 10, 1, C("ffffff"))
    im.rect(1, 10, 10, 2, C("8a94b8"))
    im.save("keycap")


# ---------------------------------------------------------------- buttons (9-slice, 16 x 17)

def button(name, ol, hl, face, lip, pressed=False, side=None):
    im = Im(16, 17)
    y0 = 1 if pressed else 0
    m = np.zeros((17, 16), bool)
    m[y0:, :] = True
    m[y0, 0] = m[y0, 15] = m[16, 0] = m[16, 15] = False  # 1 px rounded corners
    im.a[m] = ol
    if pressed:
        im.rect(1, 2, 14, 14, face)
        im.rect(1, 2, 14, 1, lip)   # inner shadow: the face has sunk under the rim
        im.rect(1, 15, 14, 1, lip)
    else:
        im.rect(1, 1, 14, 13, face)
        im.rect(1, 1, 14, 1, hl)
        im.rect(1, 14, 14, 2, lip)
        if side:
            im.rect(1, 2, 1, 12, side[0])
            im.rect(14, 2, 1, 12, side[1])
    im.save(name)


def buttons():
    button("btn_normal", OL, C("8194d2"), C("34437e"), C("1a2249"), side=(C("42539a"), C("2a3768")))
    button("btn_hover", OL, C("b9c6f2"), C("4a5eaa"), C("26326a"), side=(C("5d73c2"), C("3c4d90")))
    button("btn_pressed", OL, None, C("273262"), C("131936"), pressed=True)
    button("btn_disabled", C("090c18"), C("222a48"), C("181d33"), C("11152a"))
    g_ol = C("04160b")
    button("btn_go_normal", g_ol, C("c4ffcf"), C("43d472"), C("168a47"), side=(C("6ae690"), C("32bd5f")))
    button("btn_go_hover", g_ol, C("efffee"), C("6cec92"), C("1fa457"), side=(C("96f7b0"), C("50d67a")))
    button("btn_go_pressed", g_ol, None, C("2fb45c"), C("0e6a35"), pressed=True)
    d_ol = C("1c0704")
    button("btn_danger_normal", d_ol, C("ffd0a6"), C("f4703f"), C("a3321c"), side=(C("ff8e5c"), C("dc5a30")))
    button("btn_danger_hover", d_ol, C("ffe9d4"), C("ff8d5c"), C("be3f23"), side=(C("ffa97e"), C("ee7443")))
    button("btn_danger_pressed", d_ol, None, C("d5542c"), C("7c2413"), pressed=True)
    # neutral greys that take any colour through modulate (UI.color_button)
    g = lambda v: (v, v, v, 255)
    button("btn_tint_normal", OL, g(255), g(205), g(120), side=(g(228), g(184)))
    button("btn_tint_hover", OL, g(255), g(238), g(150), side=(g(250), g(215)))
    button("btn_tint_pressed", OL, None, g(165), g(95), pressed=True)
    # keyboard focus: a yellow line just inside the outline
    im = Im(16, 17)
    im.ring(1, 0, 0, C("ffd75e"), C("ffd75e"))
    im.a[15:, :] = 0
    im.rect(1, 15, 14, 1, C("ffd75e"))
    im.rect(1, 2, 1, 13, C("ffd75e"))
    im.rect(14, 2, 1, 13, C("ffd75e"))
    im.save("btn_focus")
    # tabs: open at the bottom so they join the panel under them
    for name, hl, face, top in (("tab_normal", C("46568e"), C("1b2340"), 2), ("tab_sel", C("ffd75e"), C("2c3970"), 0)):
        im = Im(16, 16)
        m = np.zeros((16, 16), bool)
        m[top:, :] = True
        m[top, 0] = m[top, 15] = False
        im.a[m] = OL
        im.rect(1, top + 1, 14, 15 - top, face)
        im.rect(1, top + 1, 14, 1 if top else 2, hl)
        im.save(name)


# ---------------------------------------------------------------- tiles, gauge, scrollbar, checks, separators

def well(name, w, h, rim_tl, rim_br, face, rim2=None, cut=1):
    """Recessed slot: shadow on the top and left rim, light on the bottom and right."""
    im = Im(w, h)
    im.ring(0, cut, 0, OL, OL)
    im.ring(1, 0, 0, rim_tl, rim_br)
    im.fill(2, 0, face)
    if rim2:
        im.ring(2, 0, 0, rim2[0], rim2[1])
    im.save(name)
    return im


def tiles():
    well("tile_normal", 30, 30, C("0a0d1c"), C("33406e"), C("111730"), rim2=(C("0d1226"), C("161d3a")))
    well("tile_hover", 30, 30, C("3fb4de"), C("2a86b0"), C("1a2448"), rim2=(C("131a36"), C("222d58")))
    well("tile_sel", 30, 30, C("ffe58a"), C("d9a836"), C("27326a"), rim2=(C("ffd75e"), C("b98a24")))
    im = well("tile_off", 30, 30, C("0b0e1c"), C("171c32"), C("0c0f1e"))
    for y in range(2, 28):  # hatch: unavailable
        for x in range(2, 28):
            if (x + y) % 6 == 0:
                im.px(x, y, C("151a2e"))
    im.save("tile_off")


def gauge():
    well("gauge_frame", 12, 8, C("03040a"), C("33406e"), C("0b0f20"))
    im = Im(4, 4)  # fill: greys for modulate, light top row, dark bottom row
    for y, v in enumerate((255, 222, 222, 150)):
        im.rect(0, y, 4, 1, (v, v, v, 255))
    im.save("gauge_fill")
    im = Im(5, 4)
    im.art(0, 0, ["kkkkk", "kyyyk", ".kyk.", "..k.."], {"k": OL, "y": C("ffd75e")})
    im.save("gauge_mark")


def scrollbar():
    im = Im(6, 12)
    im.rect(0, 0, 6, 12, OL)
    im.rect(1, 1, 4, 10, C("0b0f20"))
    im.rect(1, 1, 1, 10, C("070a16"))
    im.save("scroll_track")
    for name, hl, face, lo in (("scroll_grab", C("7386c6"), C("3a4a7a"), C("232c54")),
                               ("scroll_grab_hover", C("9fe6ff"), C("4fd6ff"), C("2a86b0")),
                               ("scroll_grab_pressed", C("fff0b0"), C("ffd75e"), C("b98a24"))):
        im = Im(6, 12)
        im.ring(0, 1, 0, OL, OL)
        im.rect(1, 1, 4, 10, face)
        im.rect(1, 1, 4, 1, hl)
        im.rect(1, 2, 1, 8, hl)
        im.rect(4, 2, 1, 9, lo)
        im.rect(1, 10, 4, 1, lo)
        im.save(name)


def checks():
    pal = {"k": OL, "s": C("0a0d1c"), "f": C("111730"), "r": C("33406e"), "e": C("6dff8a"), "g": C("1f8f4a"),
           "y": C("ffd75e"), "q": C("b98a24")}
    box = [".kkkkkkkkkk.", "kssssssssssk", "ksffffffffrk", "ksffffffffrk", "ksffffffffrk", "ksffffffffrk",
           "ksffffffffrk", "ksffffffffrk", "ksffffffffrk", "ksffffffffrk", "ksrrrrrrrrrk", ".kkkkkkkkkk."]
    tick = ["............", "............", "............", ".........ee.", "........eeg.", "..ee...eeg..",
            "..eee.eeg...", "...eeeeg....", "....eeg.....", ".....g......", "............", "............"]
    rad = ["....kkkk....", "..kkssssk k.".replace(" ", "k"), ".kssffffsrk.", ".ksffffffrk.", "ksffffffffrk", "ksffffffffrk",
           "ksffffffffrk", "ksffffffffrk", ".ksffffffrk.", ".krrffffrrk.", "..kkrrrrkk..", "....kkkk...."]
    dot = ["............", "............", "............", "............", ".....yy.....", "....yyyq....",
           "....yyyq....", ".....qq.....", "............", "............", "............", "............"]
    for name, base, mark in (("check_off", box, None), ("check_on", box, tick), ("radio_off", rad, None), ("radio_on", rad, dot)):
        im = Im(12, 12)
        im.art(0, 0, base, pal)
        if mark:
            im.art(0, 0, mark, pal)
        im.save(name)


def separators():
    im = Im(4, 2)  # engraved groove: dark line over a lit line
    im.rect(0, 0, 4, 1, C("05070d", 220))
    im.rect(0, 1, 4, 1, C("33406e"))
    im.save("sep_h")
    im = Im(2, 4)
    im.rect(0, 0, 1, 4, C("05070d", 220))
    im.rect(1, 0, 1, 4, C("33406e"))
    im.save("sep_v")


# ---------------------------------------------------------------- lamps and attach node

LAMP = [
    "...hhhh...",
    ".hhkkkkmm.",
    ".hkLLLLkm.",
    "hkLWWLLLkm",
    "hkLWLLLLkd",
    "hkLLLLLSkd",
    "mkLLLLSSkd",
    ".mkLLSSkd.",
    ".mmkkkkdd.",
    "...dddd...",
]
NODE = [
    "..kkkkk..",
    ".kLLLGGk.",
    "kLWWLGGGk",
    "kLWLGGGGk",
    "kLLGGGGSk",
    "kGGGGGSSk",
    "kGGGGSSSk",
    ".kGSSSSk.",
    "..kkkkk..",
]


def lamps():
    bezel = {"k": OL, "h": C("b4bcc8"), "m": C("7d8697"), "d": C("4e5566")}
    for name, lens in (("lamp_ok", ("d6ffdd", "4dff78", "1fae4c")), ("lamp_warn", ("fff6c4", "ffd75e", "c98a1e")),
                       ("lamp_bad", ("ffd2cc", "ff5a5a", "b3262c")), ("lamp_off", ("4a5270", "262c44", "171b2e"))):
        im = Im(10, 10)
        im.art(0, 0, LAMP, {**bezel, "W": C(lens[0]), "L": C(lens[1]), "S": C(lens[2])})
        im.save(name)
    im = Im(9, 9)
    im.art(0, 0, NODE, {"k": OL, "W": C("e4ffe9"), "L": C("9dffb0"), "G": C("43d472"), "S": C("168a47")})
    im.save("node")


# ---------------------------------------------------------------- icons (10 x 10 art + 1 px outline = 12 x 12)

PAL = {
    "k": OL, "w": C("f4f6fb"), "l": C("b4bcc8"), "g": C("7d8697"), "d": C("4e5566"),
    "y": C("ffd75e"), "q": C("b98a24"), "o": C("ff9f43"), "n": C("b4501a"),
    "r": C("ff5a5a"), "m": C("a3262c"), "c": C("4fd6ff"), "b": C("2b74d9"), "u": C("1a2c66"),
    "e": C("6dff8a"), "f": C("1f9a4c"), "p": C("ff7ad9"),
}

ICONS = {
    "mass": [  # a weight with a ring handle
        "...llll...",
        "..ll..lg..",
        "..l....g..",
        ".wwllllgg.",
        ".wllllllg.",
        "wwllllllgg",
        "wllllllllg",
        "wllllllllg",
        "llllllgggg",
        "ggggggggdd",
    ],
    "power": [  # lightning bolt
        "......wy..",
        ".....wyy..",
        "....wyy...",
        "...wyyy...",
        "..wyyyyyy.",
        ".yyyyyyo..",
        "....yyo...",
        "...yyo....",
        "...yo.....",
        "..yo......",
    ],
    "fuel": [  # drop
        "....oo....",
        "....oo....",
        "...oooo...",
        "...oyon...",
        "..oyyoon..",
        "..oyooon..",
        ".ooyoooon.",
        ".ooooooon.",
        "..oooonn..",
        "...nnnn...",
    ],
    "money": [  # dollar coin
        "...yyyy...",
        "..wyyqyy..",
        ".wyyqqqyq.",
        "wyyyqyyyyq",
        "yyyyqqqyyq",
        "yyyyyyqyyq",
        "yyyyqqqyyq",
        ".yyyyqyyq.",
        "..yyyyqq..",
        "...qqqq...",
    ],
    "time": [  # clock
        "...cccc...",
        "..cwwwwc..",
        ".cwwuwwwc.",
        "cwwwuwwwwc",
        "cwwwuwwwwc",
        "cwwwuuuwwb",
        "cwwwwwwwwb",
        ".cwwwwwwb.",
        "..cwwwwb..",
        "...bbbb...",
    ],
    "data": [  # disk
        "bbbbbbbbb.",
        "bbwwwlubbb",
        "bbwwwlubbb",
        "bbwwwlubbb",
        "bbbbbbbbbb",
        "bbbbbbbbbb",
        "bwwwwwwwwb",
        "bwllllllwb",
        "bwwwwwwwwb",
        "uwllllllwu",
    ],
    "comms": [  # dish and radio waves
        "......cc..",
        ".w......c.",
        ".ww..cc..c",
        ".wlw...c.c",
        ".wllw.w.c.",
        ".wlllw....",
        "..wlllw...",
        "...wwww...",
        "...gg.....",
        "..gggg....",
    ],
    "science": [  # flask
        "...wwww...",
        "....wl....",
        "....wl....",
        "....wl....",
        "...wllg...",
        "...weeg...",
        "..weeeeg..",
        "..wepeeg..",
        ".weeeepeg.",
        ".wffffffg.",
    ],
    "landing": [  # lander on its legs
        "...wwww...",
        "..wwwwll..",
        "..wcculg..",
        ".yyyyyyqq.",
        ".yyyyyyqq.",
        "..lqqqqg..",
        ".l..oo..g.",
        ".l..yo..g.",
        "l........g",
        "ll......gg",
    ],
    "return": [  # U-turn arrow
        "...cccc...",
        "..cwwwcc..",
        ".cc....cc.",
        ".cc....cb.",
        ".cc....cb.",
        "ccccc..cb.",
        ".ccb...cb.",
        "..b....cb.",
        ".......cb.",
        ".......bb.",
    ],
    "shield": [
        "wccccbbbbb",
        "wccccbbbbb",
        "cccccbbbbb",
        "cccccbbbbb",
        "cccccbbbbb",
        "cccccbbbbu",
        ".ccccbbbu.",
        ".ccccbbbu.",
        "..cccbbu..",
        "....cu....",
    ],
    "robot": [
        "....rr....",
        "....gg....",
        ".wwwwwwll.",
        ".wllllllg.",
        "lwccllccgg",
        "lwccllccgg",
        ".wllllllg.",
        ".wlddddlg.",
        ".lllllllg.",
        "..gggggg..",
    ],
    "launcher": [  # rocket
        "....rr....",
        "...rrrm...",
        "...wwwl...",
        "...wccl...",
        "...wccl...",
        "...wwwl...",
        "..rwwwlm..",
        ".rrwwwlmm.",
        ".r.oyyo.m.",
        "....oo....",
    ],
    "path": [  # flight path: an arc from Earth (bottom left) to the Moon (top right)
        "....yyy.ww",
        "..yy....wl",
        ".y........",
        ".y........",
        "y.........",
        "y.........",
        "bbee......",
        "beebb.....",
        "bbbeb.....",
        ".bbb......",
    ],
    "core": [  # spacecraft bus with solar wings
        "....ll....",
        "...wyyq...",
        "...yyyq...",
        "bcbyyyqbcb",
        "bcbyyyqbcb",
        "bcbyyyqbcb",
        "...yyqq...",
        "...qqqq...",
        "....dd....",
        "...dddd...",
    ],
    "help": [
        "...cccc...",
        "..cwwwwc..",
        ".cwwbbwwb.",
        "ccbbbbwwbb",
        "cbbbbwwbbb",
        "cbbbwwbbbb",
        "cbbbwwbbbb",
        ".bbbbbbbb.",
        "..bbwwbb..",
        "...bbbb...",
    ],
    "close": [
        ".rrrrrrrr.",
        "rrrrrrrrrr",
        "rrwwrrwwrr",
        "rrrwwwwrrr",
        "rrrrwwrrrr",
        "rrrrwwrrrr",
        "rrrwwwwrrm",
        "rrwwrrwwmm",
        "rrrrrrmmmm",
        ".mmmmmmmm.",
    ],
    "lock": [
        "...llll...",
        "..ll..lg..",
        "..l....g..",
        "..l....g..",
        ".yyyyyyyy.",
        ".ywyyyyyq.",
        ".yyykkyyq.",
        ".yyykkyyq.",
        ".yyyyyyqq.",
        ".qqqqqqqq.",
    ],
    "battery": [
        "...llll...",
        ".wwwwwwll.",
        ".wkkkkkkl.",
        ".wkeeeekl.",
        ".wkeeeekl.",
        ".wkkkkkkl.",
        ".wkeeeekl.",
        ".wkeeffkl.",
        ".wkkkkkkg.",
        ".llllllgg.",
    ],
    "sample": [  # crystal
        "...cccc...",
        "..cwwccb..",
        ".cwwccccb.",
        "cwccccccbb",
        "ccccccbbbb",
        ".ccccbbbu.",
        "..cccbbu..",
        "...cbbu...",
        "....bu....",
        "..........",
    ],
    "hull": [  # two bolted armour plates
        ".wwwwwwww.",
        "wlllllllgg",
        "wldlllldlg",
        "wllllllllg",
        "lllllllggg",
        "dddddddddd",
        "wwwwwwwwwg",
        "wldlllldlg",
        "lllllllggg",
        ".gggggggg.",
    ],
    "speed": [  # dial with a needle
        "..........",
        "...wwww...",
        ".www..wwl.",
        ".w.....rl.",
        "ww....rr.l",
        "w....rr..l",
        "w...rr...l",
        "w..ddd...l",
        "...ddd....",
        "..........",
    ],
    "alt": [  # height above the ground
        "....cc....",
        "...cccc...",
        "..cccccc..",
        ".cccccccc.",
        "....cc....",
        "....cc....",
        "....cc....",
        "..........",
        "llllllllll",
        "d.d.d.d.d.",
    ],
    "gravity": [  # arrow falling onto a world
        "....oo....",
        "....oo....",
        "....oo....",
        ".oooooooo.",
        "..oooooo..",
        "...oooo...",
        "....oo....",
        "...llll...",
        ".llllllll.",
        "llllllgggg",
    ],
    "star": [
        "....ww....",
        "....yy....",
        "...yyyy...",
        "wyyyyyyyyq",
        ".yyyyyyyq.",
        "..yyyyyq..",
        "..yyyyyq..",
        ".yyyqyyyq.",
        ".yyq..qyq.",
        "yq......qq",
    ],
    "credits": [  # stack of coins
        "..........",
        "..yyyyyy..",
        ".ywwyyyyq.",
        ".yyyyyyyq.",
        ".qyyyyyyq.",
        ".yqqqqqqy.",
        ".qyyyyyyq.",
        ".yqqqqqqy.",
        ".qyyyyyyq.",
        "..qqqqqq..",
    ],
    # extras beyond the brief: states, navigation and team roles
    "ok": [
        "..........",
        "........ee",
        ".......eee",
        "......eef.",
        "ee...eef..",
        "eee.eef...",
        ".eeeef....",
        "..eef.....",
        "...f......",
        "..........",
    ],
    "bad": [
        "rr......rr",
        "rrr....rrm",
        ".rrr..rrm.",
        "..rrrrrm..",
        "...rrrm...",
        "...rrrr...",
        "..rrmrrr..",
        ".rrm..rrr.",
        "rrm....rrr",
        "rm......rm",
    ],
    "warn": [
        "....yy....",
        "....yy....",
        "...yyyy...",
        "...ykky...",
        "..yykkyy..",
        "..yykkyy..",
        ".yyyyyyyy.",
        ".yyykkyyq.",
        "yyyyyyyyqq",
        "qqqqqqqqqq",
    ],
    "play": [
        ".ww.......",
        ".wwww.....",
        ".wwwwww...",
        ".wwwwwwww.",
        ".wwwwwwwww",
        ".wwwwwwwwl",
        ".wwwwwwll.",
        ".wwwwll...",
        ".wwll.....",
        ".ll.......",
    ],
    "back": [
        "....ww....",
        "...www....",
        "..www.....",
        ".wwwwwwwww",
        "wwwwwwwwww",
        "wwwwwwwwwl",
        ".wwlllllll",
        "..wll.....",
        "...wll....",
        "....ll....",
    ],
    "wrench": [
        "......ww..",
        ".....wl...",
        ".....wl..g",
        ".....wllgg",
        "....wllgg.",
        "...wllg...",
        "..wllg....",
        ".wllg.....",
        "wllg......",
        "lgg.......",
    ],
    "clipboard": [
        "...dddd...",
        ".lldlldll.",
        ".lwwwwwwg.",
        ".lwuuuuwg.",
        ".lwwwwwwg.",
        ".lwuuuwwg.",
        ".lwwwwwwg.",
        ".lwuuuuwg.",
        ".lwwwwwwg.",
        ".lggggggg.",
    ],
    "helmet": [
        "..wwwwww..",
        ".wwwwwwwl.",
        "wwuuuuuull",
        "wuccuuuuul",
        "wucuuuuuul",
        "wuuuuuuuul",
        "wwuuuuuulg",
        ".wwwwwwlg.",
        ".lwwwwllg.",
        "..llllgg..",
    ],
}


def outline(a):
    """Add a 1 px outline (4-neighbour) around the opaque pixels of an RGBA array."""
    solid = a[:, :, 3] > 0
    grow = np.zeros_like(solid)
    grow[1:, :] |= solid[:-1, :]
    grow[:-1, :] |= solid[1:, :]
    grow[:, 1:] |= solid[:, :-1]
    grow[:, :-1] |= solid[:, 1:]
    a[grow & ~solid] = OL
    return a


def icons():
    for name, rows in ICONS.items():
        assert len(rows) == 10 and all(len(r) == 10 for r in rows), name
        im = Im(12, 12)
        im.art(1, 1, rows, PAL)
        outline(im.a)
        im.save("icon_" + name)


# ---------------------------------------------------------------- reference sheet

def sheet(path):
    files = sorted(OUT.glob("*.png"))
    scale, cell_w, pad = 4, 172, 8
    cols = 7
    cells = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        cells.append((f.stem, im.resize((im.width * scale, im.height * scale), Image.NEAREST)))
    row_h = max(c[1].height for c in cells) + 22
    rows = (len(cells) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * cell_w + pad, rows * row_h + pad), C("1b2138"))
    d = ImageDraw.Draw(sh)
    for i, (name, im) in enumerate(cells):
        x, y = pad + (i % cols) * cell_w, pad + (i // cols) * row_h
        for yy in range(0, im.height, 8):  # checker so translucent parts show
            for xx in range(0, im.width, 8):
                if (xx // 8 + yy // 8) % 2 == 0:
                    d.rectangle([x + xx, y + yy, x + min(xx + 7, im.width - 1), y + min(yy + 7, im.height - 1)], fill=C("262e4c"))
        sh.alpha_composite(im, (x, y))
        d.text((x, y + row_h - 20), name, fill=C("e8ecff"))
    sh.convert("RGB").save(path)


if __name__ == "__main__":
    frames()
    buttons()
    tiles()
    gauge()
    scrollbar()
    checks()
    separators()
    lamps()
    icons()
    print("wrote %d textures to %s" % (len(list(OUT.glob("*.png"))), OUT))
    if len(sys.argv) > 1:
        sheet(sys.argv[1])
        print("sheet", sys.argv[1])
