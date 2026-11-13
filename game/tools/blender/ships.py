"""Spacecraft models for Space Mission Designer, rendered headless for pixel art.

    blender -b --factory-startup -P tools/blender/ships.py

Writes art/raw3d/<name>_{id,n}.png and art/raw3d/parts.json.
Shapes are generic (no real logos). Z is up, X is right, the camera looks along +Y.
Sprites are big (the rover is ~70 px long) so they carry detail, like a hero car
in a pixel racing game: panel lines, rims, treads, lights.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pixelrender as pr  # noqa: E402

OUT = os.path.join(ROOT, "art", "raw3d")
FACTOR = 4

# part: (id colour, ramp names, order)
PARTS = {
    "paint":  ((255, 0, 0), ["paint0", "paint1", "paint2", "paint3", "paint4"], 5),
    "jet":    ((0, 255, 0), ["jet0", "jet1", "jet2", "jet3"], 5),
    "gold":   ((0, 0, 255), ["gold0", "gold1", "gold2", "gold3", "gold4"], 5),
    "metal":  ((255, 255, 0), ["metal0", "metal1", "metal2", "metal3", "metal4"], 4),
    "glass":  ((255, 0, 255), ["glass0", "glass1", "glass2", "glass3"], 7),
    "cell":   ((0, 255, 255), ["cell0", "cell1", "cell2", "cell3"], 6),
    "tyre":   ((128, 0, 0), ["tyre0", "tyre1", "tyre2"], 6),
    "red":    ((0, 128, 0), ["red0", "red1", "red2", "red3"], 7),
    "hub":    ((0, 0, 128), ["metal1", "metal2", "metal3", "metal4"], 8),
    "nozzle": ((128, 128, 0), ["jet0", "metal0", "metal1", "metal2"], 4),
    "light":  ((128, 0, 128), ["gold3", "gold4", "paint4"], 9),
    "chrome": ((0, 128, 128), ["metal0", "metal2", "metal4", "paint4"], 7),
    "dark":   ((64, 64, 64), ["jet0", "jet1", "jet2"], 6),
}

ROOT_OBJ = None


def mat(part):
    return pr.material(part, PARTS[part][0])


def _finish(obj, part, smooth=True):
    obj.data.materials.append(mat(part))
    for p in obj.data.polygons:
        p.use_smooth = smooth
    if ROOT_OBJ is not None:
        obj.parent = ROOT_OBJ
    return obj


def cyl(part, loc, r, depth, rot=(0, 0, 0), verts=24, r2=None, smooth=True):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return _finish(bpy.context.object, part, smooth)


def box(part, loc, size, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    return _finish(o, part, False)


def sphere(part, loc, r, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    return _finish(o, part)


def strut(part, a, b, r):
    a, b = Vector(a), Vector(b)
    d = b - a
    mid = (a + b) / 2
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cyl(part, mid, r, d.length, rot, verts=8)


def begin(tilt=0.0, yaw=0.0, roll=0.0):
    global ROOT_OBJ
    pr.reset_scene()
    bpy.ops.object.empty_add(location=(0, 0, 0))
    ROOT_OBJ = bpy.context.object
    ROOT_OBJ.rotation_euler = Euler((math.radians(tilt), math.radians(roll), math.radians(yaw)))


def shoot(name, w, h, ppm, cx=0.0, cz=0.0):
    pr.ortho_camera(cx, cz, max(w, h) / ppm, w * FACTOR, h * FACTOR)
    bpy.context.view_layer.update()
    pr.render_passes(os.path.join(OUT, name), pr.normal_matcap())


def wheel(x, y, z, r, w, spin, side):
    """Tyre with treads, a chrome rim and a hub; `spin` turns the treads and spokes."""
    rx = math.radians(90)
    cyl("tyre", (x, y, z), r, w, rot=(rx, 0, 0), verts=24)
    for k in range(10):
        a = spin + k * math.tau / 10
        box("dark", (x + math.cos(a) * r, y, z + math.sin(a) * r), (0.07, w * 1.02, 0.07), (0, -a, 0))
    cyl("chrome", (x, y + side * (w / 2), z), r * 0.66, 0.04, rot=(rx, 0, 0), verts=20)
    cyl("hub", (x, y + side * (w / 2 + 0.03), z), r * 0.22, 0.05, rot=(rx, 0, 0), verts=8)
    for k in range(3):
        a = spin * 0.5 + k * math.tau / 3
        box("hub", (x + math.cos(a) * r * 0.4, y + side * (w / 2 + 0.03), z + math.sin(a) * r * 0.4), (r * 0.45, 0.03, 0.05), (0, -a, 0))


# ------------------------------------------------------------------ models

def rocket():
    """A generic two-stage kerosene rocket."""
    begin(0, 20)
    for i, x in enumerate((-0.22, 0.0, 0.22)):
        cyl("nozzle", (x, -0.05 if i == 1 else 0.05, 0.22), 0.16, 0.44, r2=0.08)
    cyl("jet", (0, 0, 0.7), 0.44, 0.5)                          # engine section
    box("dark", (0, 0, 0.5), (0.95, 0.95, 0.08))
    cyl("paint", (0, 0, 3.7), 0.42, 5.6)                        # first stage
    for z in (1.6, 3.0, 4.4, 5.8):                              # panel seams
        cyl("dark", (0, 0, z), 0.425, 0.04)
    box("metal", (0.0, -0.43, 3.6), (0.06, 0.04, 5.0))           # raceway
    cyl("red", (0, 0, 5.2), 0.425, 0.22)                         # accent band
    cyl("jet", (0, 0, 6.85), 0.43, 0.7)                          # interstage
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = math.cos(a) * 0.45, math.sin(a) * 0.45
        strut("jet", (x, y, 0.55), (x * 1.04, y * 1.04, 2.6), 0.07)  # folded legs
        box("dark", (x, y, 6.6), (0.26, 0.05, 0.32), (0, 0, a))  # grid fins
    cyl("paint", (0, 0, 8.25), 0.42, 2.1)                        # second stage
    cyl("dark", (0, 0, 7.3), 0.425, 0.04)
    cyl("paint", (0, 0, 10.05), 0.5, 1.5)                        # fairing
    box("dark", (0, -0.5, 10.05), (0.03, 0.03, 1.5))             # fairing seam
    cyl("paint", (0, 0, 11.3), 0.5, 1.0, r2=0.1)                 # ogive
    cyl("dark", (0, 0, 9.3), 0.505, 0.04)
    shoot("rocket", 28, 196, 16.0, 0, 5.9)


def lander():
    begin(12, 28)
    cyl("gold", (0, 0, 1.2), 0.95, 0.8, verts=8, smooth=False)   # descent stage, foil
    for i in range(8):                                           # foil creases
        a = math.radians(22.5 + 45 * i)
        box("dark", (math.cos(a) * 0.93, math.sin(a) * 0.93, 1.2), (0.03, 0.03, 0.8), (0, 0, a))
    cyl("paint", (0, 0, 1.72), 0.82, 0.24, verts=8, smooth=False)  # deck
    box("paint", (0, 0, 2.25), (0.95, 0.85, 0.75))               # ascent stage
    box("dark", (0, -0.43, 2.0), (0.9, 0.02, 0.04))              # panel lines
    box("dark", (-0.2, -0.43, 2.25), (0.02, 0.02, 0.7))
    box("glass", (0.25, -0.44, 2.35), (0.34, 0.03, 0.22))         # window
    box("glass", (0.48, -0.2, 2.35), (0.03, 0.3, 0.22))
    for sx in (-1, 1):                                           # RCS quads
        box("metal", (sx * 0.5, -0.45, 2.55), (0.12, 0.08, 0.12))
        box("nozzle", (sx * 0.58, -0.45, 2.55), (0.06, 0.05, 0.05))
    cyl("metal", (-0.25, 0.1, 2.85), 0.04, 0.5)                  # mast
    cyl("paint", (-0.25, 0.1, 3.15), 0.36, 0.08, rot=(0.5, 0, 0), r2=0.06)  # dish
    cyl("metal", (0.35, 0.2, 2.75), 0.02, 0.4)                   # whip antenna
    cyl("red", (0.3, -0.4, 2.66), 0.06, 0.06)                    # beacon
    cyl("nozzle", (0, 0, 0.6), 0.34, 0.45, r2=0.18)
    box("cell", (-1.35, 0, 1.75), (0.55, 0.05, 0.7))              # side panel
    for k in range(3):
        box("metal", (-1.35, -0.03, 1.5 + k * 0.25), (0.55, 0.02, 0.015))
    strut("metal", (-0.95, 0, 1.75), (-1.08, 0, 1.75), 0.03)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = math.cos(a), math.sin(a)
        strut("metal", (x * 0.8, y * 0.8, 1.3), (x * 1.55, y * 1.55, 0.12), 0.055)
        strut("chrome", (x * 0.85, y * 0.85, 0.85), (x * 1.3, y * 1.3, 0.45), 0.04)
        cyl("metal", (x * 1.58, y * 1.58, 0.06), 0.17, 0.08)
    shoot("lander", 80, 72, 20.0, 0, 1.75)


def rover(frame):
    begin(9, 18)
    spin = -frame * math.tau / 40.0
    box("paint", (0, 0, 1.0), (2.0, 1.15, 0.5))                  # chassis
    box("dark", (0, -0.58, 0.92), (1.8, 0.02, 0.04))             # panel line
    box("dark", (-0.4, -0.58, 1.0), (0.03, 0.02, 0.42))
    box("dark", (0.45, -0.58, 1.0), (0.03, 0.02, 0.42))
    for k in range(4):                                           # vents
        box("jet", (-0.85 + k * 0.1, -0.58, 1.08), (0.04, 0.02, 0.18))
    box("cell", (0.1, 0, 1.28), (1.8, 1.2, 0.05))                # solar deck
    for k in range(5):
        box("metal", (-0.7 + k * 0.4, 0, 1.31), (0.02, 1.2, 0.02))
    box("gold", (-0.2, 0, 0.72), (1.4, 0.9, 0.08))               # belly foil
    cyl("jet", (-1.2, 0.0, 1.25), 0.22, 0.6, rot=(0, math.radians(-40), 0), verts=12)  # RTG
    for k in range(4):
        a = k * math.pi / 4
        box("dark", (-1.2, 0, 1.25), (0.05, 0.62, 0.05), (a, math.radians(-40), 0))
    strut("metal", (0.75, -0.2, 1.3), (0.75, -0.2, 2.05), 0.05)  # mast
    box("paint", (0.78, -0.2, 2.15), (0.36, 0.52, 0.22))          # camera head
    box("glass", (0.97, -0.33, 2.16), (0.02, 0.1, 0.09))
    box("glass", (0.97, -0.07, 2.16), (0.02, 0.1, 0.09))
    box("red", (0.78, -0.47, 2.2), (0.05, 0.02, 0.05))
    cyl("paint", (-0.45, 0.25, 1.62), 0.32, 0.05, rot=(math.radians(-20), math.radians(30), 0), r2=0.06)  # HGA dish
    strut("metal", (-0.45, 0.25, 1.3), (-0.45, 0.25, 1.6), 0.03)
    strut("metal", (-0.9, 0.35, 1.3), (-0.9, 0.35, 1.9), 0.02)   # antenna
    box("light", (1.01, -0.4, 1.05), (0.03, 0.12, 0.08))         # headlights
    box("light", (1.01, 0.4, 1.05), (0.03, 0.12, 0.08))
    strut("metal", (1.0, -0.35, 0.95), (1.35, -0.35, 0.75), 0.04)  # arm, stowed
    strut("metal", (1.35, -0.35, 0.75), (1.35, -0.35, 1.15), 0.035)
    box("metal", (1.38, -0.35, 1.22), (0.16, 0.16, 0.16))
    box("dark", (1.38, -0.44, 1.22), (0.06, 0.02, 0.06))
    for side in (-0.75, 0.75):
        s = -1 if side < 0 else 1
        strut("metal", (0.2, side, 0.95), (0.95, side, 0.42), 0.045)   # rocker
        strut("metal", (0.2, side, 0.95), (-0.45, side, 0.62), 0.045)
        strut("metal", (-0.45, side, 0.62), (0.0, side, 0.42), 0.04)  # bogie
        strut("metal", (-0.45, side, 0.62), (-0.95, side, 0.42), 0.04)
        cyl("chrome", (0.2, side * 1.02, 0.95), 0.07, 0.06, rot=(math.radians(90), 0, 0), verts=8)
        for x in (-0.95, 0.0, 0.95):
            wheel(x, side, 0.36, 0.36, 0.3, spin, s)
    shoot("rover_%d" % frame, 80, 60, 22.0, 0.15, 1.12)


def drone():
    begin(18, 25)
    sphere("paint", (0, 0, 0.5), 0.7, (1.0, 1.0, 0.55))        # shell
    cyl("dark", (0, 0, 0.62), 0.705, 0.03)
    cyl("gold", (0, 0, 0.32), 0.75, 0.22)                      # foil belt
    sphere("glass", (0.55, -0.22, 0.45), 0.18)                 # sensor eye
    sphere("light", (0.6, -0.26, 0.5), 0.05)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = math.cos(a) * 0.95, math.sin(a) * 0.95
        strut("metal", (x * 0.6, y * 0.6, 0.4), (x, y, 0.4), 0.05)
        cyl("jet", (x, y, 0.38), 0.2, 0.28, r2=0.12)           # thruster pods
        cyl("red", (x, y, 0.55), 0.07, 0.05)
    cyl("nozzle", (0, 0, 0.0), 0.28, 0.3, r2=0.16)
    strut("metal", (-0.3, 0.2, 0.8), (-0.4, 0.3, 1.3), 0.025)
    box("metal", (0.2, -0.4, 0.15), (0.2, 0.1, 0.12))           # sample scoop
    shoot("drone", 46, 32, 18.0, 0, 0.45)


def orbiter():
    begin(10, 20, 90)                                           # axis along +X, dish to the right
    cyl("gold", (0, 0, 0.0), 0.55, 1.6, verts=16)              # bus
    for z in (-0.4, 0.3):
        cyl("dark", (0, 0, z), 0.56, 0.03, verts=16)
    cyl("paint", (0, 0, 1.25), 1.25, 0.18, r2=0.3)             # high-gain dish
    cyl("dark", (0, 0, 1.2), 1.26, 0.03)
    cyl("metal", (0, 0, 1.5), 0.08, 0.3)
    cyl("nozzle", (0, 0, -1.0), 0.32, 0.45, r2=0.16)            # main engine
    for a in (200, 260, 320):                                  # three RTGs
        r = math.radians(a)
        x, y = math.cos(r), math.sin(r)
        strut("metal", (x * 0.5, y * 0.5, -0.5), (x * 1.1, y * 1.1, -0.7), 0.04)
        cyl("jet", (x * 1.25, y * 1.25, -0.75), 0.13, 0.7, rot=(0, math.radians(70), r))
    strut("metal", (-0.5, 0, -0.2), (-2.0, 0, -0.8), 0.025)    # magnetometer boom
    box("metal", (-2.05, 0, -0.82), (0.14, 0.14, 0.14))
    box("paint", (0, -0.62, 0.2), (0.5, 0.1, 0.5))             # instrument pallet
    box("glass", (0, -0.69, 0.25), (0.2, 0.04, 0.15))
    box("light", (0.2, -0.69, 0.0), (0.06, 0.03, 0.06))
    shoot("orbiter", 80, 74, 18.0, 0.05, 0.35)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rocket()
    lander()
    for f in range(8):
        rover(f)
    drone()
    orbiter()
    meta = {n: {"id": list(v[0]), "ramp": v[1], "order": v[2]} for n, v in PARTS.items()}
    with open(os.path.join(OUT, "parts.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print("SHIPS DONE")
