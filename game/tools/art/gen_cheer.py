"""Art and sound for the v6 discovery cutscene (scripts/screens/cheer.gd). numpy / PIL / scipy only, no AI.

    python tools/art/gen_cheer.py          art -> art/cheer/, sound -> audio/cheer.wav

art/cheer/room.png       640x360  mission control: back wall, wall screen frame, side screens, tiered floor
art/cheer/desk_back.png  640x46   back console row (monitor backs), drawn over the back-row people
art/cheer/desk_front.png 640x86   foreground console row, in shadow
art/cheer/capsule.png    318x260  crew capsule in cutaway (crew tasks), transparent around it
art/cheer/people.png     8 frames x 14 people, 20x36 cells (12 controllers, 2 astronauts)
art/cheer/find_<skin>.png  64x44  rock sample on a tray, shown on the wall screen (land worlds)
Light from the upper left; the wall screen backlights everyone (a cool rim on top edges).
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "cheer")
sys.path.insert(0, HERE)
from gen_bg import hexc, ramp, dither, quant, fbm, rock  # noqa: E402

OL = np.array(hexc("0c0a14"), np.uint8)


def blank(w, h):
    return np.zeros((h, w, 4), np.uint8)


def rect(img, x0, y0, x1, y1, c):
    """Fill [x0, x1) x [y0, y1) with colour c (hex or RGBA)."""
    if isinstance(c, str):
        c = hexc(c)
    img[max(0, y0):max(0, y1), max(0, x0):max(0, x1)] = c


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img).save(os.path.join(OUT, name))


# ------------------------------------------------------------------ the room
WALL = ramp("080b18", "0d1124", "121831", "18203f", "1f2a50", "283664")
FLOOR = ramp("07080f", "0b0d18", "101320", "15192a", "1b2034", "232a42")
BEZ = ["14182a", "1e2232", "2e3448", "454d66", "5e6884"]
WALL_Y = 204           # wall meets floor
SCREEN = (172, 22, 468, 148)   # inner wall screen (cheer.gd draws inside it)
SIDE_L = (26, 40, 148, 124)
SIDE_R = (492, 40, 614, 124)


def bezel(img, x0, y0, x1, y1, t=5):
    """Screen frame of thickness t around the inner rect: dark bezel, lit top-left, dark lower edge."""
    rect(img, x0 - t, y0 - t, x1 + t, y1 + t, BEZ[1])
    rect(img, x0 - t, y0 - t, x1 + t, y0 - t + 1, BEZ[3])      # top highlight strip
    rect(img, x0 - t, y0 - t, x0 - t + 1, y1 + t, BEZ[2])
    rect(img, x0 - t, y1 + t - 1, x1 + t, y1 + t, BEZ[0])      # dark lower edge
    rect(img, x1 + t - 1, y0 - t, x1 + t, y1 + t, BEZ[0])
    rect(img, x0 - 1, y0 - 1, x1 + 1, y1 + 1, "06080f")        # inner lip
    img[y0 - t, x0 - t] = OL
    img[y0 - t, x1 + t - 1] = OL


def room():
    w, h = 640, 360
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    d = dither(h, w)
    sx0, sy0, sx1, sy1 = SCREEN
    scx, scy = (sx0 + sx1) / 2, (sy0 + sy1) / 2
    # wall light: ceiling fixtures throw cones down the wall, the big screen glows around itself
    L = 0.28 + 0.10 * (ys / WALL_Y)
    for fx in range(40, 640, 80):
        dy = np.clip(ys - 10, 0, None)
        cone = np.exp(-((xs - fx) / (14 + dy * 0.45)) ** 2) * np.exp(-dy / 70)
        L += 0.42 * cone
    glow = np.exp(-(((xs - scx) / 230) ** 2 + ((ys - scy) / 110) ** 2))
    L += 0.30 * glow
    wi = quant(np.clip(L, 0, 0.999), len(WALL), d, 0.9)
    # panel seams: dark line, lit line right of it; a horizontal rail at y 166
    for x in range(0, 640, 40):
        wi[:WALL_Y, x] = np.maximum(wi[:WALL_Y, x] - 2, 0)
        wi[:WALL_Y, (x + 1) % 640] = np.minimum(wi[:WALL_Y, (x + 1) % 640] + 1, len(WALL) - 1)
    wi[100, :] = np.maximum(wi[100, :] - 1, 0)
    img = WALL[wi].copy()
    # ceiling and its light fixtures
    rect(img, 0, 0, 640, 9, "05070f")
    rect(img, 0, 9, 640, 10, "1a2240")
    for fx in range(40, 640, 80):
        rect(img, fx - 16, 6, fx + 16, 9, "c8c0a0")
        rect(img, fx - 15, 7, fx + 15, 8, "fff4d4")
    # wainscot rail and kick plate
    rect(img, 0, 164, 640, 168, "2a3458")
    rect(img, 0, 164, 640, 165, "4a5888")
    rect(img, 0, 167, 640, 168, "0a0d1c")
    rect(img, 0, WALL_Y - 5, 640, WALL_Y, "1a2036")
    rect(img, 0, WALL_Y - 5, 640, WALL_Y - 4, "3a4466")
    # a row of round mission patches on the wall above the consoles
    cols = [("2b4796", "4f74c8"), ("8c1e22", "d03a30"), ("7c5418", "dcae44"), ("1e4a2e", "4eaa64"), ("4a1422", "aa3c54")]
    for i, x in enumerate(range(52, 640, 67)):
        c0, c1 = cols[i % len(cols)]
        for yy in range(-6, 7):
            for xx in range(-6, 7):
                r = (xx * xx + yy * yy) ** 0.5
                if r <= 6.4:
                    img[184 + yy, x + xx] = hexc("e6edf8") if r > 5.2 else hexc(c1 if xx + yy < 0 else c0)
        img[183:186, x - 1:x + 2] = hexc("f4f6fb")
        img[191, x - 4:x + 5] = hexc("080b18")
    # floor: perspective carpet, lighter where the screen light falls, a raised tier edge
    vp = (320.0, 120.0)
    fy = ys[WALL_Y:]
    fxs = xs[WALL_Y:]
    Lf = 0.22 + 0.45 * ((fy - WALL_Y) / (h - WALL_Y)) ** 0.8
    Lf += 0.18 * np.exp(-((fxs - 320) / 260) ** 2 - ((fy - WALL_Y) / 60) ** 2)
    fi = quant(np.clip(Lf, 0, 0.999), len(FLOOR), d[WALL_Y:], 0.9)
    k = (fy - vp[1]) / (h - vp[1])
    for xb in range(-960, 1600, 72):     # tile seams converging on the vanishing point
        xl = vp[0] + (xb - vp[0]) * k
        on = np.abs(fxs - xl) < 0.5
        fi[on] = np.maximum(fi[on] - 1, 0)
    for yy in (214, 226, 242, 264, 294, 334):
        fi[yy - WALL_Y, :] = np.maximum(fi[yy - WALL_Y, :] - 1, 0)
    img[WALL_Y:] = FLOOR[fi]
    rect(img, 0, 236, 640, 238, "2a3150")   # tier step: lit nose, dark riser
    rect(img, 0, 238, 640, 242, "080a12")
    # screens
    bezel(img, *SCREEN, t=6)
    rect(img, sx0, sy0, sx1, sy1, "040b16")
    rect(img, 300, sy1 + 6, 340, sy1 + 12, BEZ[1])   # camera bar under the big screen
    rect(img, 318, sy1 + 8, 322, sy1 + 10, "d03a30")
    for r in (SIDE_L, SIDE_R):
        bezel(img, *r, t=4)
    side_map(img, *SIDE_L)
    side_telemetry(img, *SIDE_R)
    for r in (SIDE_L, SIDE_R):        # clock plates above the side screens (cheer.gd writes the time)
        cx = (r[0] + r[2]) // 2
        rect(img, cx - 26, 16, cx + 26, 31, BEZ[0])
        rect(img, cx - 25, 17, cx + 25, 30, "05060c")
        rect(img, cx - 26, 16, cx + 26, 17, BEZ[3])
    img[..., 3] = 255
    return img


def side_map(img, x0, y0, x1, y1):
    """World map with a ground track: the classic mission control wall."""
    w, h = x1 - x0, y1 - y0
    n = fbm(w, h, [24, 12, 6], 31)
    sea = ramp("06142a", "0a1e3c")
    land = ramp("0e3a3a", "16564e", "1e6e5e")
    d = dither(h, w)
    out = sea[quant(n * 0.6, 2, d, 0.4)].copy()
    m = n > 0.56
    out[m] = land[quant(np.clip((n[m] - 0.56) * 4, 0, 0.99), 3, d[m], 0.4)]
    for gx in range(0, w, 20):
        out[:, gx] = np.minimum(out[:, gx].astype(int) + 14, 255)
    for gy in range(0, h, 20):
        out[gy, :] = np.minimum(out[gy, :].astype(int) + 14, 255)
    for x in range(w):    # sine-shaped ground track, dashed behind, solid ahead
        y = int(h / 2 - np.sin((x / w) * 2 * np.pi * 1.5 + 0.6) * h * 0.32)
        if x < w * 0.62 or x % 3 != 0:
            out[y, x] = hexc("ffd75e") if x < w * 0.62 else hexc("8a7430")
    xs = int(w * 0.62)
    ys = int(h / 2 - np.sin((xs / w) * 2 * np.pi * 1.5 + 0.6) * h * 0.32)
    out[ys - 1:ys + 2, xs - 1:xs + 2] = hexc("ff5a5a")
    out[..., 3] = 255
    img[y0:y1, x0:x1] = out


def side_telemetry(img, x0, y0, x1, y1):
    """Telemetry page: rows of 'text', bar meters and a trace."""
    rect(img, x0, y0, x1, y1, "061018")
    rng = np.random.default_rng(5)
    for i in range(6):                       # lines of tiny text blocks
        y = y0 + 6 + i * 6
        x = x0 + 5
        while x < x0 + 60:
            ln = int(rng.integers(2, 7))
            rect(img, x, y, x + ln, y + 2, "3a8a7a" if i % 3 else "8fe3f5")
            x += ln + 2
    for i in range(5):                       # bar meters
        y = y0 + 6 + i * 7
        v = int(rng.integers(20, 50))
        rect(img, x0 + 66, y, x0 + 116, y + 4, "0e2430")
        rect(img, x0 + 66, y, x0 + 66 + v, y + 4, "6dff8a" if v < 44 else "ffd75e")
    for x in range(x1 - x0 - 10):            # trace
        y = int(y1 - 20 - 9 * np.sin(x * 0.21) * np.exp(-x / 120) - 3 * np.sin(x * 0.9))
        img[y, x0 + 5 + x] = hexc("4fd6ff")
        img[y + 1, x0 + 5 + x] = hexc("1d5a80")
    rect(img, x0 + 5, y1 - 8, x1 - 5, y1 - 7, "1d3a48")


DESK = ["090b14", "10131f", "181c2c", "242a40", "3a4260", "56608a"]
MON = ["0c0e18", "161a28", "222838", "343c54"]
BACK_MONS = [22, 102, 182, 262, 352, 432, 512, 592]     # left edges of the back-row monitors (cheer.gd keeps people between them)
FRONT_MONS = [46, 216, 404, 566]


def monitor_back(img, x, y, w, h):
    rect(img, x, y, x + w, y + h, MON[1])
    rect(img, x, y, x + w, y + 1, MON[3])
    rect(img, x, y, x + 1, y + h, MON[2])
    rect(img, x + w - 1, y, x + w, y + h, MON[0])
    rect(img, x + 3, y + 3, x + w - 3, y + 4, MON[0])     # vent slots
    rect(img, x + 3, y + 5, x + w - 3, y + 6, MON[0])
    img[y + h - 3, x + w - 4] = hexc("6dff8a")             # power LED
    sx = x + w // 2 - 2
    rect(img, sx, y + h, sx + 4, y + h + 3, MON[2])        # stand
    # cool spill of the screen light around the top edge (the screen faces away from us)
    rect(img, x - 1, y - 1, x + w + 1, y, "1d4a6a")
    for k in ((x - 1, y - 1), (x + w, y - 1)):
        img[k[1], k[0]] = 0
    # outline
    rect(img, x - 1, y, x, y + h, OL)
    rect(img, x + w, y, x + w + 1, y + h, OL)


def desk(w, h, top, mons, mw, mh, dark):
    img = blank(w, h)
    D = DESK[:-1] if dark else DESK[1:]
    rect(img, 0, top, w, h, D[1])
    rect(img, 0, top, w, top + 1, D[4])           # lit nose of the desk top
    rect(img, 0, top + 1, w, top + 4, D[3])
    rect(img, 0, top + 4, w, top + 5, D[0])       # shadow under the lip
    for x in range(0, w, 64):                     # front panels, lit left edge
        rect(img, x, top + 5, x + 1, h, D[0])
        rect(img, x + 1, top + 5, x + 2, h, D[2])
        img[top + 9, x + 8] = hexc("6dff8a")
        img[top + 9, x + 11] = hexc("ffd75e" if (x // 64) % 3 else "ff5a5a")
    rect(img, 0, h - 3, w, h, D[0])
    for x in mons:
        monitor_back(img, x, top - mh - 3, mw, mh)
    return img


def desk_front():
    img = desk(640, 86, 24, FRONT_MONS, 40, 18, True)
    # mug, binder stack, a paper on the desk top
    rect(img, 90, 16, 97, 24, "d6dcea"); rect(img, 90, 16, 91, 24, "f4f6fb"); rect(img, 96, 16, 97, 24, "8a92aa")
    rect(img, 97, 18, 99, 22, "a3abc4"); rect(img, 91, 17, 96, 18, "4a2e10")
    rect(img, 226, 18, 250, 21, "b4501a"); rect(img, 228, 15, 248, 18, "2b4796"); rect(img, 226, 21, 250, 24, "2e7a46")
    rect(img, 226, 18, 250, 19, "f08a2a"); rect(img, 228, 15, 248, 16, "4f74c8")
    rect(img, 470, 21, 486, 24, "e6edf8"); rect(img, 470, 23, 486, 24, "8a92aa")
    # foreground shade: the bottom of the desk falls off into the dark
    a = img[..., 3] > 0
    for y in range(50, 86):
        k = (y - 50) / 36
        img[y][a[y]] = (img[y][a[y]].astype(float) * (1 - 0.55 * k)).astype(np.uint8)
    img[a, 3] = 255
    return img


# ------------------------------------------------------------------ people
CW, CH = 20, 36
SKINS = [("9a5a40", "d8956c", "f2c09a"), ("7a4630", "b47450", "d49a70"), ("5e3420", "905a36", "b67c50"), ("3a2016", "613a24", "855234")]
HAIRS = {"black": ("100e16", "221e2c", "36304a"), "brown": ("341e12", "5a381e", "7e552c"),
         "blonde": ("94661e", "cc9c40", "eccc70"), "grey": ("5e5e68", "9a9aa4", "cacad2"), "red": ("66220f", "a4401c", "d06630")}
SHIRTS = {"white": ("8a92aa", "cdd4e4", "f4f6fb"), "sky": ("3c6a9a", "6aa0d0", "a6d0f2"), "navy": ("141c3a", "26346a", "3a4e96"),
          "orange": ("8a3a10", "cc6620", "f09a48"), "green": ("1e4a2e", "2e7a46", "50aa66"), "maroon": ("4a1422", "7a2236", "aa3c54"),
          "grey": ("3a3e4a", "5e6474", "8c92a2"), "yellow": ("8a6a14", "cca42a", "f2d05a"), "suit": ("6a7290", "b4bcc8", "eef1f8")}
PANTS = {"navy": ("0e1226", "1a2242", "28345c"), "khaki": ("564630", "86704a", "ae986a"), "black": ("0c0c12", "1a1a24", "2a2a38"),
         "grey": ("2e323e", "4a5060", "6a7284"), "suit": ("5e6680", "a4acbc", "dfe4ea")}
SHOE = ("0c0c12", "26222c", "3e3946")
BOOT = ("3a4058", "6a7290", "a3abc4")
# skin, hair colour, hair style, shirt, pants, extras (headset, glasses, tie, short sleeves, suit)
PEOPLE = [
    (0, "brown", "short", "white", "navy", "tie"),
    (3, "black", "curly", "orange", "black", "headset"),
    (1, "black", "long", "sky", "navy", "glasses"),
    (2, "black", "bun", "green", "khaki", "headset"),
    (0, "blonde", "long", "maroon", "black", ""),
    (1, "grey", "bald", "white", "grey", "glasses tie"),
    (2, "black", "short", "navy", "khaki", "headset short"),
    (3, "black", "bun", "yellow", "navy", ""),
    (0, "red", "curly", "grey", "navy", "glasses"),
    (1, "brown", "short", "sky", "black", "headset short"),
    (2, "black", "long", "white", "navy", "glasses"),
    (3, "grey", "short", "green", "grey", "tie"),
    (1, "black", "short", "suit", "suit", "suit"),     # astronaut 1
    (0, "brown", "bun", "suit", "suit", "suit"),       # astronaut 2
]
# arm poses, screen-left arm, as (x, y) points shoulder -> elbow -> hand; mirrored for the right arm
ARMS = {
    "down": [(5, 14), (5, 21)],
    "back": [(5, 14), (3, 20)],
    "up": [(5, 14), (5, 3)],
    "v": [(5, 14), (1, 4)],
    "clap_o": [(5, 14), (4, 19), (7, 17)],
    "clap_c": [(5, 14), (5, 19), (9, 16)],
    "hug": [(5, 14), (0, 14)],
    "wave": [(5, 14), (2, 10), (3, 4)],
}
# frame: (left arm, right arm, body drop, legs, mouth)
FRAMES = [
    ("down", "down", 0, "stand", "smile"),     # 0 watching
    ("back", "back", 3, "crouch", "smile"),    # 1 anticipation
    ("v", "v", 0, "tuck", "open"),             # 2 airborne
    ("v", "v", 0, "stand", "open"),            # 3 cheer
    ("clap_o", "clap_o", 0, "stand", "open"),  # 4 clap, hands apart
    ("clap_c", "clap_c", 0, "stand", "smile"), # 5 clap, hands together
    ("up", "down", 0, "stand", "open"),        # 6 fist pump
    ("wave", "hug", 0, "stand", "open"),       # 7 side hug (right arm on the neighbour's shoulder)
]


def line_pts(a, b):
    n = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
    return [(round(a[0] + (b[0] - a[0]) * i / n), round(a[1] + (b[1] - a[1]) * i / n)) for i in range(n + 1)]


def person(spec, frame):
    skin_i, hair_c, style, shirt, pants, extra = spec
    la, ra, drop, legs, mouth = FRAMES[frame]
    suit = "suit" in extra
    reg = np.zeros((CH, CW), int)     # region id (for edge shading)
    mat = {}                          # region id -> ramp

    def fill(rid, pts):
        for x, y in pts:
            if 0 <= x < CW and 0 <= y < CH:
                reg[y, x] = rid

    def box(rid, x0, y0, x1, y1):
        fill(rid, [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)])

    dy = drop
    # legs and shoes
    mat[1] = PANTS[pants]; mat[2] = PANTS[pants]; mat[3] = BOOT if suit else SHOE; mat[4] = mat[3]
    if legs == "stand":
        box(1, 7, 24, 9, 32); box(2, 10, 24, 12, 32); box(3, 6, 33, 9, 34); box(4, 10, 33, 13, 34)
    elif legs == "crouch":
        box(1, 6, 27, 8, 29); box(1, 7, 30, 9, 32); box(2, 11, 27, 13, 29); box(2, 10, 30, 12, 32)
        box(3, 6, 33, 9, 34); box(4, 10, 33, 13, 34)
    else:  # tucked in the air, feet together and pointed
        box(1, 7, 24, 9, 29); box(2, 10, 24, 12, 29); box(3, 7, 30, 9, 31); box(4, 10, 30, 12, 31)
    # torso
    mat[5] = SHIRTS[shirt]
    box(5, 6, 13 + dy, 13, 23 + dy)
    for x, y in ((6, 13 + dy), (13, 13 + dy)):
        reg[y, x] = 0
    # head
    mat[6] = SKINS[skin_i]
    box(6, 7, 5 + dy, 12, 11 + dy)
    box(6, 9, 12 + dy, 10, 12 + dy)
    for x, y in ((7, 5 + dy), (12, 5 + dy), (7, 11 + dy), (12, 11 + dy)):
        reg[y, x] = 0
    # hair
    mat[7] = HAIRS[hair_c]
    if style == "short":
        box(7, 7, 4 + dy, 12, 5 + dy); box(7, 7, 6 + dy, 7, 7 + dy); box(7, 12, 6 + dy, 12, 6 + dy)
    elif style == "long":
        box(7, 7, 4 + dy, 12, 5 + dy); box(7, 6, 5 + dy, 6, 13 + dy); box(7, 13, 5 + dy, 13, 13 + dy)
        box(7, 7, 6 + dy, 7, 9 + dy); box(7, 12, 6 + dy, 12, 9 + dy)
    elif style == "bun":
        box(7, 7, 4 + dy, 12, 5 + dy); box(7, 9, 2 + dy, 11, 3 + dy); box(7, 7, 6 + dy, 7, 7 + dy); box(7, 12, 6 + dy, 12, 7 + dy)
    elif style == "curly":
        box(7, 6, 3 + dy, 13, 6 + dy); box(7, 6, 7 + dy, 6, 9 + dy); box(7, 13, 7 + dy, 13, 9 + dy)
        for x in (6, 13):
            reg[3 + dy, x] = 0
    elif style == "bald":
        box(7, 7, 7 + dy, 7, 8 + dy); box(7, 12, 7 + dy, 12, 8 + dy)
    # arms (drawn last: clapping hands sit in front of the torso); each arm on its own grid, mirrored for the right
    for rid, pose, mirror in ((8, la, False), (10, ra, True)):
        mat[rid] = SHIRTS[shirt]
        mat[rid + 1] = SKINS[skin_i] if not suit else SHIRTS["white"]
        g = np.zeros((CH, CW), int)
        pts = [(x, y + dy) for x, y in ARMS[pose]]
        path = []
        for a, b in zip(pts, pts[1:]):
            path += line_pts(a, b)
        cut = len(path) // 2 if "short" in extra else len(path) - 1
        for i, (x, y) in enumerate(path[:-1]):
            for ox in (0, -1):
                if 0 <= x + ox < CW and 0 <= y < CH:
                    g[y, x + ox] = rid if i < cut else rid + 1
        hx, hy = path[-1]
        hy2 = hy - 1 if hy < 14 + dy else hy + 1
        for x, y in ((hx - 1, hy), (hx, hy), (hx - 1, hy2), (hx, hy2)):
            if 0 <= x < CW and 0 <= y < CH:
                g[y, x] = rid + 1
        if mirror:
            g = g[:, ::-1]
        reg[g > 0] = g[g > 0]
    # hug arm: lay it flat along the shoulder line out to the cell edge
    if ra == "hug":
        for x in range(14, CW):
            reg[14 + dy, x] = 10 if x < 17 else 11
            reg[15 + dy, x] = 10 if x < 17 else 11
    # shade: lit left edges, dark right and bottom edges
    img = blank(CW, CH)
    for y in range(CH):
        for x in range(CW):
            r = reg[y, x]
            if r == 0:
                continue
            R = [hexc(c) for c in mat[r]]
            left = x == 0 or reg[y, x - 1] != r
            right = x == CW - 1 or reg[y, x + 1] != r
            low = y == CH - 1 or reg[y + 1, x] != r
            c = R[1]
            if right or (low and r in (5, 6)):
                c = R[0]
            elif left:
                c = R[2]
            img[y, x] = c
    # face and details
    sk = [hexc(c) for c in SKINS[skin_i]]
    eye = hexc("1a1020")
    img[8 + dy, 8] = eye; img[8 + dy, 11] = eye
    if mouth == "open":
        img[10 + dy, 9] = hexc("5a1420"); img[10 + dy, 10] = hexc("5a1420")
    else:
        img[10 + dy, 9] = sk[0]; img[10 + dy, 10] = sk[0]
    if "glasses" in extra:
        for x in (8, 11):
            img[8 + dy, x] = hexc("cfe8ff")
        img[8 + dy, 9] = hexc("2a2630"); img[8 + dy, 10] = hexc("2a2630")
        img[8 + dy, 7] = hexc("2a2630"); img[8 + dy, 12] = hexc("2a2630")
    if "tie" in extra:
        for y in range(13 + dy, 19 + dy):
            if reg[y, 9] == 5:
                img[y, 9] = hexc("8c1e22"); img[y, 10] = hexc("d03a30") if y < 18 + dy else hexc("8c1e22")
    if "headset" in extra:
        for x in range(7, 13):
            img[3 + dy if style == "curly" else 4 + dy, x] = hexc("2a2630")
        img[7 + dy, 6] = hexc("2a2630"); img[8 + dy, 6] = hexc("454d66")
        img[9 + dy, 7] = hexc("2a2630"); img[10 + dy, 8] = hexc("454d66")
    if suit:
        img[12 + dy, 8:12] = hexc("7d8697")                      # neck ring
        img[13 + dy, 8:12] = hexc("b4bcc8")
        img[16 + dy, 7] = hexc("2b4796"); img[16 + dy, 8] = hexc("4f74c8")   # mission patch
        img[17 + dy, 7] = hexc("1a2c66"); img[17 + dy, 8] = hexc("2b4796")
        img[16 + dy, 11] = hexc("d03a30"); img[16 + dy, 12] = hexc("f4f6fb")  # flag
        for x in range(6, 14):                                   # blue trim at the waist
            if reg[22 + dy, x] == 5:
                img[22 + dy, x] = hexc("2b4796")
    # backlight from the wall screen on the top edges
    rim = np.array([150, 225, 255], float)
    for y in range(1, CH):
        for x in range(CW):
            if img[y, x, 3] and not img[y - 1, x, 3] and reg[y, x] in (5, 6, 7, 8, 10):
                img[y, x, :3] = (img[y, x, :3] * 0.55 + rim * 0.45).astype(np.uint8)
    # outline
    a = img[..., 3] > 0
    out = img.copy()
    for y in range(CH):
        for x in range(CW):
            if a[y, x]:
                continue
            if any(0 <= y + j < CH and 0 <= x + i < CW and a[y + j, x + i] for i, j in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y, x] = OL
    return out


def people():
    sheet = blank(CW * len(FRAMES), CH * len(PEOPLE))
    for r, spec in enumerate(PEOPLE):
        for f in range(len(FRAMES)):
            sheet[r * CH:(r + 1) * CH, f * CW:(f + 1) * CW] = person(spec, f)
    return sheet


# ------------------------------------------------------------------ crew capsule (cutaway)
HULL = ["2a2e3a", "6a7290", "a3abc4", "d6dcea", "f4f6fb"]


def capsule():
    w, h = 318, 260
    img = blank(w, h)
    cx = 159
    top, bot = 40, 214
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    half = 44 + (ys - top) / (bot - top) * (112 - 44)
    shell = (ys >= top) & (ys < bot) & (np.abs(xs - cx) <= half)
    # hull, lit from the upper left
    lam = np.clip(0.75 - (xs - cx) / (2 * half + 1e-6) * 1.1, 0, 0.999)
    d = dither(h, w)
    H = ramp(*HULL)
    hi = quant(lam, len(H), d, 0.0)
    img[shell] = H[hi[shell]]
    for yy in range(top + 18, bot, 22):     # panel lines around the cone
        row = shell[yy]
        img[yy][row] = hexc(HULL[1])
    # docking tunnel on top, heat shield below
    rect(img, cx - 20, top - 16, cx + 20, top, HULL[2]); rect(img, cx - 20, top - 16, cx - 17, top, HULL[3])
    rect(img, cx + 16, top - 16, cx + 20, top, HULL[1]); rect(img, cx - 22, top - 18, cx + 22, top - 15, HULL[1])
    rect(img, cx - 114, bot, cx + 114, bot + 7, "7c5418"); rect(img, cx - 114, bot, cx + 114, bot + 1, "b3812a")
    rect(img, cx - 110, bot + 7, cx + 110, bot + 11, "4a2e10")
    # cutaway: the interior behind a cut edge
    itop, ibot = top + 30, bot - 16
    ihalf = half - 9
    inside = (ys >= itop) & (ys < ibot) & (np.abs(xs - cx) <= ihalf)
    W = ramp("3a4058", "566080", "7a84a4", "9aa4c4")
    li = 0.25 + 0.6 * np.exp(-(((xs - cx + 30) / 90) ** 2 + ((ys - itop - 20) / 70) ** 2))
    img[inside] = W[quant(np.clip(li, 0, 0.999), len(W), d, 0.8)[inside]]
    edge = shell & ~inside & (np.abs(xs - cx) <= ihalf + 2) & (ys >= itop - 2) & (ys < ibot + 2)
    img[edge] = hexc("e8a838")             # the cut through the hull insulation
    cut = (shell & ~inside) & ((np.abs(np.abs(xs - cx) - (ihalf + 3)) < 0.6) & (ys >= itop - 3) & (ys < ibot + 3))
    img[cut] = hexc("4a2e10")
    # interior: wall panels, instrument panel with screens, handrails, two seats, a window
    for x in range(cx - 80, cx + 81, 26):
        col = inside[:, x] if 0 <= x < w else None
        if col is not None:
            img[col, x] = hexc("3a4058")
    px0, py0 = cx - 36, itop + 6
    rect(img, px0, py0, px0 + 72, py0 + 22, "1e2232"); rect(img, px0, py0, px0 + 72, py0 + 1, "454d66")
    for i, c in enumerate(("39a0c8", "6dff8a", "39a0c8")):
        sx = px0 + 4 + i * 23
        rect(img, sx, py0 + 4, sx + 19, py0 + 14, "0f2b40"); rect(img, sx + 1, py0 + 5, sx + 18, py0 + 13, "123650")
        for k in range(3):
            rect(img, sx + 2, py0 + 6 + k * 3, sx + 2 + 6 + (k * 5 + i * 3) % 12, py0 + 7 + k * 3, c)
    for i in range(10):
        img[py0 + 17, px0 + 5 + i * 7] = hexc(("ffd75e", "6dff8a", "ff5a5a")[i % 3])
    for y in (itop + 40,):
        rect(img, cx - 70, y, cx - 52, y + 2, "dcae44"); rect(img, cx + 52, y, cx + 70, y + 2, "dcae44")
        rect(img, cx - 70, y + 2, cx - 52, y + 3, "7c5418"); rect(img, cx + 52, y + 2, cx + 70, y + 3, "7c5418")
    for sx in (cx - 46, cx + 14):            # seats (reclined couches) on the floor
        rect(img, sx, ibot - 14, sx + 32, ibot - 8, "26346a"); rect(img, sx, ibot - 14, sx + 32, ibot - 13, "3a4e96")
        rect(img, sx + 26, ibot - 30, sx + 32, ibot - 14, "26346a"); rect(img, sx + 26, ibot - 30, sx + 27, ibot - 14, "3a4e96")
        rect(img, sx + 4, ibot - 8, sx + 8, ibot, "222838"); rect(img, sx + 24, ibot - 8, sx + 28, ibot, "222838")
    # a round window on the right wall of the hull exterior (the outside of the far wall)
    wx, wy = cx + 84, top + 64
    for y in range(-7, 8):
        for x in range(-7, 8):
            r = (x * x + y * y) ** 0.5
            if r <= 7.5 and shell[wy + y, wx + x]:
                img[wy + y, wx + x] = hexc("2e3448") if r > 5.5 else hexc("0f2b40" if x + y > -2 else "39a0c8")
    # RCS quads and a hatch line on the visible hull
    for yy in (top + 24, bot - 30):
        for side in (-1, 1):
            hx = int(cx + side * (44 + (yy - top) / (bot - top) * 68 - 3))
            rect(img, hx - 2, yy, hx + 2, yy + 4, "454d66")
    # outline
    a = img[..., 3] > 0
    out = img.copy()
    ring = np.zeros_like(a)
    ring[1:] |= a[:-1]; ring[:-1] |= a[1:]; ring[:, 1:] |= a[:, :-1]; ring[:, :-1] |= a[:, 1:]
    out[ring & ~a] = OL
    return out


# ------------------------------------------------------------------ finds
ROCKS = {"moon": ("3a3a46", "6a6a7a", "9a9aac", "c8c8d6"), "mars": ("3a1810", "6e3020", "a04e32", "d07a50"),
         "mercury": ("2e2a2a", "5a5450", "8a827a", "b8aea2"), "venus": ("3a2614", "6e4a24", "a07438", "cca05a")}


def find(skin):
    w, h = 64, 44
    img = blank(w, h)
    # sample tray: metal dish with a lit rim and a scale bar
    rect(img, 4, 30, 60, 38, "4e5566"); rect(img, 4, 30, 60, 31, "b4bcc8"); rect(img, 4, 37, 60, 38, "2a2e3a")
    rect(img, 2, 38, 62, 40, "2a2e3a")
    r = rock(38, 24, {"moon": 11, "mars": 12, "mercury": 13, "venus": 14}[skin], ramp(*ROCKS[skin]), OL)
    a = r[..., 3] > 0
    img[8:32, 13:51][a] = r[a]
    for i in range(6):     # 1 cm ticks
        rect(img, 6 + i * 4, 41, 7 + i * 4, 43 if i % 5 == 0 else 42, "f4f6fb")
    rect(img, 6, 43, 27, 44, "f4f6fb")
    return img


# ------------------------------------------------------------------ the cheer sound
def cheer_sound():
    sys.path.insert(0, os.path.join(ROOT, "tools", "audio"))
    import synth as S
    S.seed("cheer")
    sr = S.SR
    L = 4.6
    n = S.n_(L)
    out = np.zeros((n, 2))
    t = S.t_(L)
    rng = np.random.default_rng(7)

    def pan(x, p, at):
        i = S.n_(at)
        m = min(len(x), n - i)
        if m <= 0:
            return
        out[i:i + m, 0] += x[:m] * np.sqrt(0.5 * (1 - p))
        out[i:i + m, 1] += x[:m] * np.sqrt(0.5 * (1 + p))

    # applause: 26 people clapping at their own rate, each clap a short band of noise with a hand "body"
    crowd_env = np.minimum(t / 0.35, 1.0) * np.exp(-np.maximum(t - 2.4, 0) / 0.8)
    for k in range(26):
        rate = rng.uniform(3.6, 5.4)
        tt = rng.uniform(0.05, 0.4)
        p = rng.uniform(-0.9, 0.9)
        lo, hi = rng.uniform(700, 1300), rng.uniform(2600, 5200)
        while tt < L - 0.2:
            g = crowd_env[min(n - 1, S.n_(tt))] * rng.uniform(0.5, 1.0)
            ct = S.t_(0.05)
            clap = S.bp(S.nz(len(ct)), lo, hi) * S.dec(ct, rng.uniform(0.006, 0.012))
            clap += S.bp(S.nz(len(ct)), 300, 900) * S.dec(ct, 0.008) * 0.5
            pan(clap * g, p, tt)
            tt += 1.0 / rate * rng.uniform(0.85, 1.15)

    # voices: "yeah!" and "woo!" shouts, a buzzy glottal source through two moving formants
    def shout(dur, f0, kind):
        st = S.t_(dur)
        cont = f0 * (1 + 0.25 * np.sin(np.pi * np.minimum(st / dur, 1)) - 0.2 * (st / dur) ** 2)
        cont *= 1 + 0.012 * np.sin(2 * np.pi * rng.uniform(5, 7) * st)
        src = S.saw(cont, st, 4500) + 0.06 * S.nz(len(st))
        if kind == "woo":
            f1, f2 = np.full(len(st), 380.0), np.full(len(st), 900.0)
        else:  # "yeah": eh -> ah
            k = np.minimum(st / (dur * 0.6), 1)
            f1, f2 = 500 + 250 * k, 1900 - 700 * k
        y = np.zeros(len(st))
        seg = S.n_(0.02)
        for i in range(0, len(st), seg):   # formant filters stepped every 20 ms
            j = min(len(st), i + seg)
            fa, fb = float(f1[i]), float(f2[i])
            y[i:j] = (S.bp(src, fa * 0.8, fa * 1.25)[i:j] + 0.6 * S.bp(src, fb * 0.85, fb * 1.15)[i:j])
        return y * S.env(st, 0.04, dur * 0.45)
    for k in range(16):
        at = rng.uniform(0.0, 0.55) if k < 11 else rng.uniform(1.0, 2.2)
        f0 = rng.uniform(180, 300) if k % 2 else rng.uniform(110, 170)
        pan(shout(rng.uniform(0.5, 1.0), f0, "woo" if k % 3 == 0 else "yeah") * rng.uniform(0.4, 0.9), rng.uniform(-0.8, 0.8), at)
    # room bed: a low crowd roar under it all
    roar = S.bp(S.nz(n), 250, 2200) * crowd_env * 0.25
    out[:, 0] += roar
    out[:, 1] += S.bp(S.nz(n), 250, 2200) * crowd_env * 0.25
    # bake a short room reverb per channel, then high-pass and level
    y = np.stack([S.reverb(out[:, c], 0.9, 0.22, 300, 6000) for c in range(2)], axis=1)
    y = np.stack([S.f(y[:, c], "hp", 120, 2) for c in range(2)], axis=1)
    sr = 32000   # like the other effects: half the file size, nothing audible lost above 16 kHz
    y = S.to_rate(y, sr)
    y = S.level(y, -13.0, "mom", -1.2, sr)
    keep = np.nonzero(np.abs(y).max(axis=1) > 5e-4)[0][-1] + S.n_(0.02, sr)
    y = y[:keep]
    r = min(len(y), S.n_(0.4, sr))
    y[-r:] *= np.linspace(1, 0, r)[:, None]
    y[:S.n_(0.005, sr)] *= np.linspace(0, 1, S.n_(0.005, sr))[:, None]
    S.save("cheer", y, sr)
    return y, sr


def main():
    save(room(), "room.png")
    save(desk(640, 46, 24, BACK_MONS, 24, 12, False), "desk_back.png")
    save(desk_front(), "desk_front.png")
    save(capsule(), "capsule.png")
    sheet = people()
    save(sheet, "people.png")
    for s in ROCKS:
        save(find(s), "find_%s.png" % s)
    assert sheet.shape == (CH * len(PEOPLE), CW * len(FRAMES), 4)
    y, sr = cheer_sound()
    print("art -> %s; cheer.wav %.2f s, peak %.3f" % (OUT, len(y) / sr, np.abs(y).max()))


if __name__ == "__main__":
    main()
