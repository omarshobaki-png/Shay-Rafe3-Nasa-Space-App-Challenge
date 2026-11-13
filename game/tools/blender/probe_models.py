"""Models for the Saturn ring drone screen, rendered headless for pixel art.

    blender -b --factory-startup -P tools/blender/probe_models.py

Writes art/raw3d/probe/<name>_{id,n}.png and art/raw3d/probe/parts.json:
  rock_<k>_<ff>     seven ring boulders, 16 tumbling frames each (faceted rock with ice patches)
  near_<k>          three big boulders for the out-of-focus foreground layer
  drone_<tilt><dmg> the sampling drone, 3 steering tilts x 3 hull damage states, bigger than art/drone.png
  orbiter_<c>       the orbiter with a docking port underneath, clamps open (0) and closed (1)
Uses the helpers of tools/blender/ships.py (read-only import). tools/art/gen_probe.py composes the sprites.
"""
import json
import math
import os
import random
import sys

import bpy
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pixelrender as pr  # noqa: E402
import ships as S  # noqa: E402

OUT = os.path.join(ROOT, "art", "raw3d", "probe")
S.OUT = OUT
S.PARTS.update({
    "rock": ((255, 128, 0), ["rock0", "rock1", "rock2", "rock3", "rock4"], 5),
    "ice":  ((0, 128, 255), ["ice0", "ice1", "ice2", "ice3"], 5),
    "lamp": ((128, 255, 0), ["lamp0", "lamp1", "lamp2"], 9),
})
ROCK_FRAMES = 16
# name: (seed, canvas px, pixels per unit, squash xyz, chips, ice share, spin axis)
ROCKS = {
    "rock_0": (11, 18, 7.0, (1.0, 0.9, 0.82), 4, 0.30, (0.3, 0.5, 0.8)),
    "rock_1": (12, 22, 9.0, (1.0, 0.85, 0.9), 5, 0.20, (-0.5, 0.6, 0.6)),
    "rock_2": (13, 30, 12.0, (1.0, 0.8, 0.86), 6, 0.35, (0.6, 0.4, 0.7)),
    "rock_3": (14, 36, 15.0, (0.92, 0.9, 1.0), 6, 0.15, (-0.2, 0.7, 0.7)),
    "rock_4": (15, 48, 20.0, (1.0, 0.86, 0.8), 7, 0.30, (0.4, 0.6, -0.7)),
    "rock_5": (16, 56, 23.5, (0.95, 0.9, 0.92), 8, 0.22, (-0.6, 0.5, 0.6)),
    "rock_6": (17, 70, 30.0, (1.0, 0.84, 0.88), 9, 0.28, (0.25, 0.75, 0.6)),
}
NEAR = {"near_0": (31, 120, 52.0), "near_1": (32, 96, 41.0), "near_2": (33, 150, 66.0)}


def rock_mesh(seed, squash, chips, ice, subdiv=2):
    """A chipped boulder: a noisy ball cut by flat planes, with ice on some facets."""
    rnd = random.Random(seed)
    off = Vector((rnd.uniform(0, 50), rnd.uniform(0, 50), rnd.uniform(0, 50)))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    planes = []
    for _ in range(chips):
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized()
        planes.append((n, rnd.uniform(0.66, 0.86)))
    for v in o.data.vertices:
        d = v.co.normalized()
        r = 1.0 + 0.30 * noise.noise(d * 1.3 + off) + 0.14 * noise.noise(d * 2.9 + off)
        p = d * r
        for n, dist in planes:
            k = p.dot(n)
            if k > dist:
                p = p - n * (k - dist)
        v.co = Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2]))
    o.data.materials.append(S.mat("rock"))
    o.data.materials.append(S.mat("ice"))
    cut = 1.0 - 2.0 * ice
    for p in o.data.polygons:
        p.use_smooth = False
        c = p.center.normalized()
        p.material_index = 1 if noise.noise(c * 1.7 + off * 2.0) * 2.2 > cut else 0
    o.parent = S.ROOT_OBJ
    return o


def rocks():
    for name, (seed, px, ppm, squash, chips, ice, axis) in ROCKS.items():
        S.begin()
        rock_mesh(seed, squash, chips, ice, 3 if px >= 48 else 2)
        ax = Vector(axis).normalized()
        S.ROOT_OBJ.rotation_mode = "AXIS_ANGLE"
        for f in range(ROCK_FRAMES):
            S.ROOT_OBJ.rotation_axis_angle = (math.tau * f / ROCK_FRAMES, ax.x, ax.y, ax.z)
            S.shoot("%s_%02d" % (name, f), px, px, ppm)
    for name, (seed, px, ppm) in NEAR.items():
        S.begin(20, 30)
        rock_mesh(seed, (1.0, 0.85, 0.8), 7, 0.0, 3)
        S.shoot(name, px, px, ppm)


def drone(name, roll, damage):
    """The sampling drone of ships.py at a bigger scale, with seams, a hatch, a scoop arm and damage."""
    S.begin(18, 25, roll)
    S.sphere("paint", (0, 0, 0.5), 0.7, (1.0, 1.0, 0.55))            # shell
    S.cyl("dark", (0, 0, 0.62), 0.705, 0.03)                        # shell seams
    S.cyl("dark", (0, 0, 0.76), 0.535, 0.025)
    S.cyl("metal", (0, 0, 0.885), 0.2, 0.05)                        # top hatch
    S.cyl("chrome", (0, 0, 0.915), 0.1, 0.04)
    S.cyl("gold", (0, 0, 0.32), 0.75, 0.22)                         # foil belt
    S.cyl("dark", (0, 0, 0.2), 0.74, 0.03)
    for i in range(8):                                              # belt ribs
        a = math.radians(22.5 + 45 * i)
        S.box("dark", (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.32), (0.03, 0.03, 0.2), (0, 0, a))
    S.sphere("glass", (0.55, -0.22, 0.45), 0.18)                    # sensor eye
    S.sphere("light", (0.6, -0.26, 0.5), 0.05)
    S.cyl("metal", (0.5, -0.2, 0.45), 0.2, 0.06, rot=(math.radians(90), 0, math.radians(68)))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = math.cos(a) * 0.95, math.sin(a) * 0.95
        S.strut("metal", (x * 0.6, y * 0.6, 0.4), (x, y, 0.4), 0.05)
        if damage == 2 and i == 1:
            continue                                                # this pod was torn off
        S.cyl("jet", (x, y, 0.38), 0.2, 0.28, r2=0.12)              # thruster pods
        S.cyl("nozzle", (x, y, 0.22), 0.11, 0.06, r2=0.14)
        S.cyl("red", (x, y, 0.55), 0.07, 0.05)
    S.cyl("nozzle", (0, 0, 0.0), 0.28, 0.3, r2=0.16)                # main engine
    S.cyl("dark", (0, 0, 0.14), 0.3, 0.03)
    if damage < 2:                                                  # antenna
        S.strut("metal", (-0.3, 0.2, 0.8), (-0.4, 0.3, 1.3), 0.025)
        S.sphere("red", (-0.4, 0.3, 1.32), 0.05)
    else:
        S.strut("metal", (-0.3, 0.2, 0.8), (-0.36, 0.26, 1.02), 0.025)
        S.strut("metal", (-0.36, 0.26, 1.02), (-0.62, 0.2, 1.08), 0.025)
    S.box("metal", (0.2, -0.4, 0.15), (0.2, 0.1, 0.12))             # sample scoop
    S.strut("metal", (0.2, -0.45, 0.1), (0.34, -0.62, -0.06), 0.03)
    S.box("chrome", (0.36, -0.64, -0.1), (0.16, 0.1, 0.06))
    scorch = [(-0.45, -0.75, 0.42, 0.17)] if damage >= 1 else []
    if damage >= 2:
        scorch += [(0.1, -0.8, 0.6, 0.2), (-0.7, -0.4, 0.1, 0.14), (0.5, -0.5, 0.9, 0.12)]
    for sx, sy, sz, r in scorch:                                    # burnt dents on the shell
        d = Vector((sx, sy, sz)).normalized()
        S.sphere("jet", (d.x * 0.7, d.y * 0.7, 0.5 + d.z * 0.385), r, (1.0, 0.55, 0.8))
    if damage >= 2:
        S.box("jet", (0.05, -0.74, 0.34), (0.5, 0.05, 0.035), (0, math.radians(24), 0))  # torn foil
    S.shoot(name, 66, 48, 24.0, 0, 0.5)


def orbiter(name, clamp):
    """The orbiter of ships.py at a bigger scale with a docking port underneath (local +X is down)."""
    S.begin(10, 20, 90)
    rx = (0, math.radians(90), 0)
    S.cyl("gold", (0, 0, 0.0), 0.55, 1.6, verts=16)                 # bus
    for z in (-0.4, 0.3, 0.72):
        S.cyl("dark", (0, 0, z), 0.56, 0.03, verts=16)
    S.cyl("metal", (0, 0, -0.78), 0.5, 0.06, verts=16)
    S.cyl("paint", (0, 0, 1.25), 1.25, 0.18, r2=0.3)                # high-gain dish
    S.cyl("dark", (0, 0, 1.2), 1.26, 0.03)
    S.cyl("metal", (0, 0, 1.5), 0.08, 0.3)
    for a in (30, 150, 270):                                        # feed struts
        r = math.radians(a)
        S.strut("metal", (math.cos(r) * 0.9, math.sin(r) * 0.9, 1.3), (0, 0, 1.64), 0.02)
    S.cyl("nozzle", (0, 0, -1.0), 0.32, 0.45, r2=0.16)              # main engine
    for a in (200, 260, 320):                                       # three RTGs
        r = math.radians(a)
        x, y = math.cos(r), math.sin(r)
        S.strut("metal", (x * 0.5, y * 0.5, -0.5), (x * 1.1, y * 1.1, -0.7), 0.04)
        S.cyl("jet", (x * 1.25, y * 1.25, -0.75), 0.13, 0.7, rot=(0, math.radians(70), r))
    S.strut("metal", (-0.5, 0, -0.2), (-2.0, 0, -0.8), 0.025)       # magnetometer boom
    S.box("metal", (-2.05, 0, -0.82), (0.14, 0.14, 0.14))
    S.box("paint", (0, -0.62, 0.2), (0.5, 0.1, 0.5))                # instrument pallet
    S.box("glass", (0, -0.69, 0.25), (0.2, 0.04, 0.15))
    S.box("light", (0.2, -0.69, 0.0), (0.06, 0.03, 0.06))
    S.box("paint", (-0.2, -0.6, -0.55), (0.3, 0.08, 0.2))           # star tracker
    S.box("glass", (-0.2, -0.65, -0.55), (0.12, 0.03, 0.1))
    # docking port: a truss down to a white capture cone with a dark rim, lamps and two latch arms
    for s in (-1, 1):
        S.strut("metal", (0.45, 0, -0.1 + s * 0.3), (1.08, 0, -0.1 + s * 0.2), 0.035)
        S.strut("metal", (0.45, 0, -0.1 - s * 0.3), (1.08, 0, -0.1 + s * 0.2), 0.025)
    S.cyl("metal", (1.06, 0, -0.1), 0.24, 0.08, rot=rx, verts=16)
    S.cyl("paint", (1.24, 0, -0.1), 0.26, 0.3, rot=rx, verts=16, r2=0.5)   # capture cone
    S.cyl("dark", (1.4, 0, -0.1), 0.52, 0.045, rot=rx, verts=16)          # rim
    S.cyl("jet", (1.42, 0, -0.1), 0.4, 0.03, rot=rx, verts=16)            # socket
    for s in (-1, 1):
        S.box("lamp", (1.33, -0.36, -0.1 + s * 0.26), (0.07, 0.06, 0.07))
        z0 = -0.1 + s * 0.5
        z1 = -0.1 + s * (0.74 - 0.24 * clamp)
        S.strut("metal", (1.36, 0, z0), (1.62, 0, z1), 0.04)                # latch arms
        S.strut("red", (1.62, 0, z1), (1.72, 0, z1 - s * 0.1 * (0.3 + clamp)), 0.045)
    S.shoot(name, 120, 112, 26.0, 0.05, 0.25)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    what = os.environ.get("PROBE_ONLY", "rocks,drone,orbiter").split(",")
    if "rocks" in what:
        rocks()
    if "drone" in what:
        for ti, roll in enumerate((-13, 0, 13)):
            for dmg in range(3):
                drone("drone_%d%d" % (ti, dmg), roll, dmg)
    if "orbiter" in what:
        orbiter("orbiter_0", 0.0)
        orbiter("orbiter_1", 1.0)
    meta = {n: {"id": list(v[0]), "ramp": v[1], "order": v[2]} for n, v in S.PARTS.items()}
    with open(os.path.join(OUT, "parts.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print("PROBE MODELS DONE")
