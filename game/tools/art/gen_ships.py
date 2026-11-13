"""Compose Blender passes in art/raw3d into palette pixel sprites in art/.

    python tools/art/gen_ships.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from compose3d import compose, save_sheet  # noqa: E402
from palette import P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(ROOT, "art", "raw3d")
OUT = os.path.join(ROOT, "art")

with open(os.path.join(RAW, "parts.json")) as fh:
    meta = json.load(fh)
PARTS = {n: {"id": v["id"], "ramp": [P[c] for c in v["ramp"]], "order": v["order"]} for n, v in meta.items()}


def one(name):
    img, _, _ = compose(os.path.join(RAW, name + "_id.png"), os.path.join(RAW, name + "_n.png"),
                        PARTS, factor=4, outline=True, selective=True)
    return img


for n in ("rocket", "lander", "drone", "orbiter"):
    im = one(n)
    Image.fromarray(im).save(os.path.join(OUT, n + ".png"))
    print(n, im.shape[1], "x", im.shape[0])
frames = [one("rover_%d" % i) for i in range(8)]
save_sheet(frames, os.path.join(OUT, "rover.png"))
print("rover sheet", frames[0].shape[1] * len(frames), "x", frames[0].shape[0])
