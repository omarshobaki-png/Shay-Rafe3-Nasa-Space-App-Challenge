"""Half-size ships for the menu posters and the How To Play pictures: the same Blender passes
(art/raw3d) composed at 8 render pixels per art pixel instead of 4, so they stay real pixel art.

    python tools/art/gen_menu_ships.py
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from compose3d import compose  # noqa: E402
from palette import P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(ROOT, "art", "raw3d")
OUT = os.path.join(ROOT, "art", "menu")

with open(os.path.join(RAW, "parts.json")) as fh:
    meta = json.load(fh)
PARTS = {n: {"id": v["id"], "ramp": [P[c] for c in v["ramp"]], "order": v["order"]} for n, v in meta.items()}

os.makedirs(OUT, exist_ok=True)
for src, dst in (("lander", "veh_lander"), ("rover_0", "veh_rover"), ("orbiter", "veh_orbiter"),
                 ("drone", "veh_drone"), ("rocket", "veh_rocket")):
    img, _, _ = compose(os.path.join(RAW, src + "_id.png"), os.path.join(RAW, src + "_n.png"),
                        PARTS, factor=8, alpha_cut=0.3, outline=True, selective=True)
    Image.fromarray(img).save(os.path.join(OUT, dst + ".png"))
    print(dst, img.shape[1], "x", img.shape[0])
