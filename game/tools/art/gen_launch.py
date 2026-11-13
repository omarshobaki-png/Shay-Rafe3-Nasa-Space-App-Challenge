"""Launch screen art: the launchers cut into the pieces that come apart in flight, tumbling copies of the
pieces that fall away, a stowed payload that shows when the fairing opens, and the close-up of the upper
stage for the deployment camera.

    python tools/art/gen_launch.py            (writes art/launch/*.png)

Source sprites: art/parts/lv_<id>.png (read only). 1 art pixel = 1 game pixel, light from the upper left.
Every piece keeps the launcher's own coordinates: piece_<id>_<name>.png is the full launcher-sized canvas
with only that piece's pixels, so the screen draws every piece at the launcher's top-left corner.
Tumble strips (tumble_<id>_<name>.png) hold 16 frames, 22.5 degrees apart, each frame a square that is
centred on the piece's centre. Rotation happens here, never at run time.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "parts")
OUT = os.path.join(ROOT, "art", "launch")
FRAMES = 16

# rows where each launcher comes apart: [fairing end, upper stage end] (core = the rest).
# Read off the sprites: Falcon 9 / Heavy fairing seam at row 37, interstage starts at 67;
# Vulcan fairing seam 58, Centaur ends 76; Electron fairing seam 25, kick ring 35.
CUTS = {"electron": (26, 36), "falcon9": (38, 67), "vulcan": (59, 77), "heavy": (38, 67)}


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    if isinstance(img, np.ndarray):
        img = Image.fromarray(img.astype(np.uint8))
    img.save(os.path.join(OUT, name))


def rgb(k):
    return np.array(P[k], dtype=np.uint8)


def only(a, mask):
    out = a.copy()
    out[~mask] = 0
    return out


def write_tumble(piece, name):
    ys, xs = np.nonzero(piece[:, :, 3])
    crop = Image.fromarray(piece[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    side = int(np.ceil(np.hypot(*crop.size))) + 2
    side += side % 2
    strip = Image.new("RGBA", (side * FRAMES, side), (0, 0, 0, 0))
    for i in range(FRAMES):
        r = crop.rotate(-22.5 * i, resample=Image.NEAREST, expand=True)
        strip.paste(r, (i * side + (side - r.width) // 2, (side - r.height) // 2), r)
    save(strip, "tumble_" + name + ".png")


def vulcan_core(a):
    """Vulcan's orange core with the solid boosters taken off: rows below the boosters' tops repeat
    the clean core row 90, then a dark engine section and two engine bells."""
    h, w = a.shape[:2]
    core = np.zeros_like(a)
    core[77:97] = a[77:97]
    row = a[90].copy()
    for y in range(97, 154):
        core[y] = row
    jet = [rgb("jet3"), rgb("jet2"), rgb("jet2"), rgb("jet1"), rgb("jet1"), rgb("jet0")]
    xs = [x for x in range(w) if row[x, 3] > 0]
    x0, x1 = xs[0], xs[-1]
    for y in range(154, 162):
        for x in range(x0, x1 + 1):
            k = int((x - x0) / max(1, x1 - x0) * (len(jet) - 1))
            core[y, x] = jet[k]
        core[y, x0] = rgb("ol")
        core[y, x1] = rgb("ol")
    core[154, x0:x1 + 1] = rgb("ol")
    for bx in (x0 + 2, x1 - 7):  # two BE-4 bells
        for y in range(162, 167):
            spread = (y - 162) // 2
            for x in range(bx - spread, bx + 6 + spread):
                if 0 <= x < w:
                    t = (x - (bx - spread)) / max(1, 5 + 2 * spread)
                    core[y, x] = rgb("metal3") if t < 0.3 else (rgb("metal2") if t < 0.65 else rgb("metal1"))
            core[y, max(0, bx - spread)] = rgb("ol")
            core[y, min(w - 1, bx + 5 + spread)] = rgb("ol")
    return core


def vulcan_boosters(a):
    """The three solid boosters seen from the front: every pixel below row 97 that is not the core."""
    h, w = a.shape[:2]
    row = a[90]
    mask = np.zeros((h, w), bool)
    for y in range(97, h):
        for x in range(w):
            if a[y, x, 3] == 0:
                continue
            core_px = row[x, 3] > 0 and np.array_equal(a[y, x], row[x])
            gap = (11 <= x <= 14 or 22 <= x <= 23) and 100 <= y <= 161
            if not core_px and not gap:
                mask[y, x] = True
    xs = np.arange(w)[None, :].repeat(h, 0)
    return [only(a, mask & (xs < 11)), only(a, mask & (xs >= 11) & (xs < 22)), only(a, mask & (xs >= 22))]


def payload(width, height):
    """A spacecraft folded for launch, small enough to sit in the fairing: gold foil body, a stack of
    folded solar panels on each side, a stowed dish on top, a dark adapter ring under it."""
    im = np.zeros((height, width, 4), np.uint8)
    gold = [rgb("gold4"), rgb("gold3"), rgb("gold2"), rgb("gold1")]
    cell = [rgb("cell3"), rgb("cell2"), rgb("cell1")]
    pw = max(1, width // 5)
    body0, body1 = pw, width - pw
    top = max(2, height // 4)
    for y in range(top, height - 2):
        for x in range(body0, body1):
            t = (x - body0) / max(1, body1 - body0 - 1)
            im[y, x] = gold[min(3, int(t * 3.6))]
        if (y - top) % 4 == 3:  # foil seams
            im[y, body0 + 1:body1 - 1] = rgb("gold1")
    for y in range(top + 1, height - 2):  # folded panels
        for x in list(range(0, body0)) + list(range(body1, width)):
            k = 0 if x < body0 and x == 0 else (2 if x >= body1 and x == width - 1 else 1)
            im[y, x] = cell[k] if (y - top) % 3 else rgb("metal2")
    # dish folded on top
    dw = max(3, (body1 - body0) - 2)
    dx = (width - dw) // 2
    for y in range(0, top):
        shrink = (top - y) // 2
        for x in range(dx + shrink, dx + dw - shrink):
            t = (x - dx) / max(1, dw - 1)
            im[y, x] = rgb("paint4") if t < 0.35 else (rgb("paint3") if t < 0.7 else rgb("paint2"))
    im[height - 2:, body0:body1] = rgb("jet2")
    im[height - 1, body0:body1] = rgb("ol")
    # outline
    al = im[:, :, 3] > 0
    edge = np.zeros_like(al)
    edge[:, 1:] |= al[:, 1:] & ~al[:, :-1]
    edge[:, :-1] |= al[:, :-1] & ~al[:, 1:]
    edge[1:, :] |= al[1:, :] & ~al[:-1, :]
    im[edge & (np.arange(width)[None, :] > width // 2)] = rgb("ol")
    return im


def cam_stage(dark):
    """Close-up of the top of the upper stage for the deployment camera: a wide cylinder, the payload
    adapter cone and the separation ring the spacecraft sits on. 170 x 110 px, ring top at row 0..6."""
    w, h = 170, 110
    im = np.zeros((h, w, 4), np.uint8)
    if dark:
        ramp = [rgb("jet3"), rgb("jet2"), rgb("jet2"), rgb("jet1"), rgb("jet1"), rgb("jet0")]
    else:
        ramp = [rgb("paint4"), rgb("paint3"), rgb("paint3"), rgb("paint2"), rgb("paint1"), rgb("paint0")]
    metal = [rgb("metal4"), rgb("metal3"), rgb("metal2"), rgb("metal1"), rgb("metal0")]

    def shade(t, r):
        # cylinder lit from the upper left: brightest a third of the way across
        k = abs(t - 0.28) / 0.72
        return r[min(len(r) - 1, int(k * len(r)))]

    ring_w, ring_h = 66, 6
    cone_h = 26
    body_w = 160
    cx = w // 2
    # separation ring (metal, with clamp bolts)
    for y in range(0, ring_h):
        x0 = cx - ring_w // 2
        for x in range(x0, x0 + ring_w):
            im[y, x] = shade((x - x0) / (ring_w - 1), metal)
        if y == 2:
            for x in range(x0 + 3, x0 + ring_w - 3, 7):
                im[y, x] = rgb("jet0")
    im[ring_h - 1, cx - ring_w // 2:cx + ring_w // 2] = rgb("metal0")
    # adapter cone (gold foil wrapped, like real payload adapters' insulation blankets? keep it metal grey)
    for y in range(ring_h, ring_h + cone_h):
        t = (y - ring_h) / (cone_h - 1)
        half = int(ring_w / 2 + 2 + t * (body_w / 2 - ring_w / 2 - 2))
        for x in range(cx - half, cx + half):
            im[y, x] = shade((x - (cx - half)) / (2 * half - 1), ramp if not dark else metal)
        if (y - ring_h) % 9 == 8:
            im[y, cx - half:cx + half] = (ramp[3] if not dark else metal[3])
        im[y, cx - half] = rgb("ol")
        im[y, cx + half - 1] = rgb("ol")
    # body
    y0 = ring_h + cone_h
    x0 = cx - body_w // 2
    for y in range(y0, h):
        for x in range(x0, x0 + body_w):
            im[y, x] = shade((x - x0) / (body_w - 1), ramp)
        im[y, x0] = rgb("ol")
        im[y, x0 + body_w - 1] = rgb("ol")
    im[y0, x0:x0 + body_w] = rgb("ol")
    im[y0 + 1, x0 + 1:x0 + body_w - 1] = ramp[0]  # highlight strip under the rim
    for y in range(y0 + 22, h, 26):  # panel joints and rivets
        im[y, x0 + 1:x0 + body_w - 1] = ramp[4]
        for x in range(x0 + 4, x0 + body_w - 4, 6):
            im[y - 2, x] = ramp[3]
    for x in (x0 + 34, x0 + 96):  # stringers
        im[y0 + 2:, x] = ramp[3] if not dark else ramp[1]
    # a dark umbilical tunnel down the right side and a red stripe band
    im[y0 + 4:, x0 + body_w - 18:x0 + body_w - 12] = rgb("jet1")
    im[y0 + 4:, x0 + body_w - 12] = rgb("jet0")
    band = y0 + 50
    for x in range(x0 + 1, x0 + body_w - 1):
        k = abs((x - x0) / (body_w - 1) - 0.28) / 0.72
        im[band:band + 4, x] = rgb("red3") if k < 0.2 else (rgb("red2") if k < 0.6 else rgb("red1"))
    return im


def main():
    for lv, (f_end, u_end) in CUTS.items():
        a = np.array(Image.open(os.path.join(SRC, "lv_%s.png" % lv)).convert("RGBA"))
        h, w = a.shape[:2]
        ys = np.arange(h)[:, None].repeat(w, 1)
        xs = np.arange(w)[None, :].repeat(h, 0)
        alpha = a[:, :, 3] > 0
        fair = alpha & (ys < f_end)
        fx = np.nonzero(fair.any(0))[0]
        mid = (fx.min() + fx.max() + 1) // 2
        save(only(a, fair & (xs < mid)), "piece_%s_fair_l.png" % lv)
        save(only(a, fair & (xs >= mid)), "piece_%s_fair_r.png" % lv)
        write_tumble(only(a, fair & (xs < mid)), "%s_fair_l" % lv)
        write_tumble(only(a, fair & (xs >= mid)), "%s_fair_r" % lv)
        upper = only(a, alpha & (ys >= f_end) & (ys < u_end))
        save(upper, "piece_%s_upper.png" % lv)
        core_mask = alpha & (ys >= u_end)
        if lv == "heavy":
            side_l = core_mask & (xs < 17)
            side_r = core_mask & (xs >= 33)
            core = only(a, core_mask & ~side_l & ~side_r)
            boosters = [only(a, side_l), only(a, side_r)]
        elif lv == "vulcan":
            core = vulcan_core(a)
            boosters = vulcan_boosters(a)
        else:
            core = only(a, core_mask)
            boosters = []
        save(core, "piece_%s_core.png" % lv)
        write_tumble(core, "%s_core" % lv)
        for i, b in enumerate(boosters):
            save(b, "piece_%s_boost%d.png" % (lv, i))
            write_tumble(b, "%s_boost%d" % (lv, i))
        # the folded spacecraft that shows when the fairing opens
        inner = fx.max() - fx.min() + 1
        pw = max(6, inner - 6)
        ph = max(8, min(int(f_end * 0.6), int(pw * 1.7)))
        save(payload(pw, ph), "payload_%s.png" % lv)
    save(cam_stage(False), "cam_stage.png")
    save(cam_stage(True), "cam_stage_dark.png")


if __name__ == "__main__":
    main()
