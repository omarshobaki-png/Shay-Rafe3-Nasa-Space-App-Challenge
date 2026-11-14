"""Map icons for the flight screen's Sun-centred map and the Moon map's far strip.
Sizes keep the real ORDER of planet sizes (Mercury < Mars < Venus < Earth < Neptune < Uranus < Saturn < Jupiter),
not the real ratios (the maps say "not to scale"). Made by shrinking art/planet_<name>_60.png.
Run: python tools/art/gen_flight2_icons.py  ->  art/flight/map_<name>.png"""
import os
from PIL import Image

ART = os.path.join(os.path.dirname(__file__), "..", "..", "art")
# disc diameter in px. Real diameters (km, NASA fact sheets): Mercury 4,879, Mars 6,792, Venus 12,104,
# Earth 12,756, Neptune 49,528, Uranus 51,118, Saturn 120,536, Jupiter 142,984.
SIZES = {"mercury": 5, "mars": 6, "venus": 8, "earth": 9, "moon": 3, "neptune": 12, "uranus": 13, "saturn": 15, "jupiter": 17}
SATURN_RING = 2.27  # A ring outer edge / equatorial radius (136,775 / 60,268 km)


def shrink(name: str, d: int) -> Image.Image:
    src = Image.open(os.path.join(ART, "planet_%s_60.png" % name)).convert("RGBA")
    src = src.crop(src.getbbox())
    if name == "saturn":
        w = round(d * SATURN_RING) | 1
        h = max(d, round(src.height * w / src.width))
    else:
        w = h = d
    out = src.resize((w, h), Image.LANCZOS)
    px = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return out


if __name__ == "__main__":
    for n, d in SIZES.items():
        im = shrink(n, d)
        im.save(os.path.join(ART, "flight", "map_%s.png" % n))
        print(n, im.size)


def ship_marker() -> Image.Image:
    """8 headings (0 = right, counter-clockwise in 45 degree steps) of a 9x9 arrowhead: the ship on the maps.
    A symbol, not a picture of the craft, so it never looks bigger than a planet."""
    import math
    from PIL import ImageDraw
    S, N = 9, 8
    sheet = Image.new("RGBA", (S * N, S), (0, 0, 0, 0))
    for f in range(N):
        a = -f * math.pi / 4  # screen y points down
        big = Image.new("L", (S * 8, S * 8), 0)
        d = ImageDraw.Draw(big)
        c = S * 4
        pts = [(4.2, 0), (-3.2, 3.1), (-2.2, 0), (-3.2, -3.1)]
        rot = [(c + 8 * (x * math.cos(a) - y * math.sin(a)), c + 8 * (x * math.sin(a) + y * math.cos(a))) for x, y in pts]
        d.polygon(rot, fill=255)
        m = big.resize((S, S), Image.BOX)
        fr = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        mp, fp = m.load(), fr.load()
        for y in range(S):
            for x in range(S):
                if mp[x, y] >= 100:
                    fp[x, y] = (159, 232, 255, 255) if mp[x, y] >= 200 else (79, 214, 255, 255)
        # dark outline around the shape
        out = fr.copy()
        op = out.load()
        for y in range(S):
            for x in range(S):
                if fp[x, y][3] == 0 and any(0 <= x + dx < S and 0 <= y + dy < S and fp[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    op[x, y] = (12, 10, 20, 255)
        sheet.alpha_composite(out, (f * S, 0))
    return sheet


if __name__ == "__main__":
    ship_marker().save(os.path.join(ART, "flight", "map_ship.png"))
    print("map_ship")
