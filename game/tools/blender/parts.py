"""Ship-kit part models for the builder, rendered headless for pixel art.

    blender -b --factory-startup -P tools/blender/parts.py            (everything)
    blender -b --factory-startup -P tools/blender/parts.py -- bus hga  (only the sprites whose name starts so)

Writes art/raw3d/parts/<name>_{id,n}.png, sprites.json (the canvas of each sprite in ship
pixels) and parts.json (materials). tools/art/gen_parts.py turns them into art/parts/*.png.

Every part is modelled where it sits on the finished ship, so the layout needs no hand-tuned
anchors. Units are PIXELS of the final sprite: x right, y away from the camera, z up, origin =
the centre of the spacecraft bus. The view is from 10 degrees above (deck and dish bowls show),
and z values are pre-stretched so that 1 px of z is 1 px on screen.
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

OUT = os.path.join(ROOT, "art", "raw3d", "parts")
FACTOR = 4
S = 0.1  # Blender units per pixel
rad = math.radians

# material: (id colour, ramp (palette names, see gen_parts.py for the extra ones), order)
PARTS = {
    "paint":  ((255, 0, 0), ["paint0", "paint1", "paint2", "paint3", "paint4"], 5),
    "jet":    ((0, 255, 0), ["jet0", "jet1", "jet2", "jet3"], 5),
    "gold":   ((0, 0, 255), ["gold0", "gold1", "gold2", "gold3", "gold4"], 5),
    "metal":  ((255, 255, 0), ["metal0", "metal1", "metal2", "metal3", "metal4"], 6),
    "glass":  ((255, 0, 255), ["glass0", "glass1", "glass2", "glass3"], 8),
    "cell":   ((0, 255, 255), ["cell0", "cell1", "cell2", "cell3"], 6),
    "tyre":   ((128, 0, 0), ["tyre0", "tyre1", "tyre2"], 6),
    "red":    ((0, 128, 0), ["red0", "red1", "red2", "red3"], 7),
    "hub":    ((0, 0, 128), ["metal1", "metal2", "metal3", "metal4"], 8),
    "nozzle": ((128, 128, 0), ["jet0", "metal0", "metal1", "metal2"], 4),
    "light":  ((128, 0, 128), ["gold3", "gold4", "paint4"], 9),
    "chrome": ((0, 128, 128), ["metal0", "metal2", "metal4", "paint4"], 7),
    "dark":   ((64, 64, 64), ["jet0", "jet1", "jet2"], 6),
    "orange": ((255, 128, 0), ["orange0", "orange1", "orange2", "orange3"], 7),
    "deck":   ((128, 255, 0), ["metal0", "metal1", "metal2", "metal3"], 5),
    "rack":   ((0, 128, 255), ["jet0", "jet0", "jet1", "jet1"], 6),
    "green":  ((0, 255, 128), ["green0", "green1", "green2", "green3"], 9),
    "bag":    ((255, 0, 128), ["bag0", "bag1", "bag2", "bag3", "bag4"], 5),
    "seam":   ((128, 0, 255), ["bag0", "bag0", "bag1"], 6),
    "tps":    ((255, 128, 128), ["tps0", "tps1", "tps2", "tps3", "tps4"], 5),
    "hsin":   ((128, 255, 128), ["jet0", "jet1", "jet2", "jet3"], 4),
    "titan":  ((128, 128, 255), ["titan0", "titan1", "titan2", "titan3", "titan4"], 6),
    "rivet":  ((255, 255, 128), ["titan3", "titan4", "paint4"], 9),
    "kadish": ((255, 128, 255), ["jet1", "jet3", "metal1", "metal2"], 5),
    "tdome":  ((128, 255, 255), ["metal0", "metal1", "metal2", "metal3"], 4),
    "slot":   ((64, 128, 255), ["jet1", "jet2", "jet3", "jet3"], 7),
    "hold":   ((255, 255, 255), ["jet0"], 0),      # occluder: cut out of the sprite
}

TILT = 10.0
ZS = 1.0          # z stretch for the current tilt (set in begin)
TILT_OBJ = None
ROOT_OBJ = None   # objects are parented here
MINR = 0.0        # minimum strut radius in px (icons: keeps thin struts alive)
META = {}         # sprite name -> [x0, y0, w, h] canvas in ship pixels (y down)

ZD = 21.5         # deck top
ZB = -23.0        # bus bottom plane (where the tank stack starts)
APO = 39.0 * math.cos(rad(22.5))   # centre-to-face distance of the octagonal bus


def mat(part):
    return pr.material(part, PARTS[part][0])


def P3(p):
    return (p[0] * S, p[1] * S, p[2] * S * ZS)


def _finish(obj, part, smooth=True):
    me = obj.data
    me.materials.append(mat(part))
    for p in me.polygons:
        p.use_smooth = smooth and len(p.vertices) <= 4
    if smooth:  # keep cap rims crisp
        caps = {tuple(sorted(k)) for p in me.polygons if len(p.vertices) > 4 for k in p.edge_keys}
        for e in me.edges:
            if tuple(sorted(e.vertices)) in caps:
                e.use_edge_sharp = True
    obj.parent = ROOT_OBJ
    return obj


def cyl(part, loc, r, depth, rot=(0, 0, 0), verts=24, r2=None, smooth=True, caps=True):
    upright = rot[0] == 0 and rot[1] == 0
    d = depth * S * (ZS if upright else 1.0)
    fill = "NGON" if caps else "NOTHING"
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r * S, depth=d, location=P3(loc),
                                            rotation=rot, end_fill_type=fill)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r * S, radius2=r2 * S, depth=d,
                                        location=P3(loc), rotation=rot, end_fill_type=fill)
    return _finish(bpy.context.object, part, smooth)


def box(part, loc, size, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=P3(loc), rotation=rot)
    o = bpy.context.object
    upright = rot[0] == 0 and rot[1] == 0
    o.scale = (size[0] * S, size[1] * S, size[2] * S * (ZS if upright else 1.0))
    return _finish(o, part, False)


def sphere(part, loc, r, scale=(1, 1, 1), segs=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=r * S, location=P3(loc))
    o = bpy.context.object
    o.scale = scale
    o.data.materials.append(mat(part))
    for p in o.data.polygons:
        p.use_smooth = True
    o.parent = ROOT_OBJ
    return o


def torus(part, loc, R, r, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R * S, minor_radius=r * S, major_segments=24, minor_segments=6,
                                     location=P3(loc), rotation=rot)
    o = bpy.context.object
    o.data.materials.append(mat(part))
    for p in o.data.polygons:
        p.use_smooth = True
    o.parent = ROOT_OBJ
    return o


def strut(part, a, b, r, verts=8):
    a, b = Vector(P3(a)), Vector(P3(b))
    d = b - a
    mid = (a + b) / 2
    rot = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=max(r, MINR) * S, depth=d.length, location=mid, rotation=rot)
    return _finish(bpy.context.object, part, True)


def begin(yaw=0.0, tilt=TILT):
    """New scene. Yaw turns the model about its own axis, then the whole thing tips toward the camera."""
    global ROOT_OBJ, TILT_OBJ, ZS
    pr.reset_scene()
    ZS = 1.0 / math.cos(rad(tilt))
    bpy.ops.object.empty_add(location=(0, 0, 0))
    TILT_OBJ = bpy.context.object
    TILT_OBJ.rotation_euler = Euler((rad(tilt), 0, 0))
    bpy.ops.object.empty_add(location=(0, 0, 0))
    ROOT_OBJ = bpy.context.object
    ROOT_OBJ.parent = TILT_OBJ
    ROOT_OBJ.rotation_euler = Euler((0, 0, rad(yaw)))


def sub(loc, scale=(1, 1, 1), rotz=0.0):
    """Following objects go into a scaled / turned group (for the models borrowed from ships.py)."""
    global ROOT_OBJ
    bpy.ops.object.empty_add(location=P3(loc))
    e = bpy.context.object
    e.parent = ROOT_OBJ
    e.scale = scale
    e.rotation_euler = Euler((0, 0, rad(rotz)))
    ROOT_OBJ = e
    return e


def shoot(name, x0, y0, w, h, mirror=False):
    """Render the canvas x0..x0+w, y0..y0+h (ship pixels, y down). mirror also writes <name>_l,
    the same part on the left side, lit from the same direction."""
    pr.ortho_camera((x0 + w / 2) * S, -(y0 + h / 2) * S, max(w, h) * S, w * FACTOR, h * FACTOR)
    bpy.context.view_layer.update()
    pr.render_passes(os.path.join(OUT, name), pr.normal_matcap())
    META[name] = [x0, y0, w, h]
    if mirror:
        TILT_OBJ.scale = (-1, 1, 1)
        shoot(name + "_l", -(x0 + w), y0, w, h)
        TILT_OBJ.scale = (1, 1, 1)


def bounds():
    bpy.context.view_layer.update()
    xs, zs = [], []
    for o in bpy.data.objects:
        if o.type != "MESH" or (o.data.materials and o.data.materials[0].name == "hold"):
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            xs.append(w.x)
            zs.append(w.z)
    return min(xs), max(xs), min(zs), max(zs)


def shoot_icon(name, model, size=24, fill=22):
    """The same model framed to fill a 24x24 tile, thin struts fattened to stay visible."""
    global MINR
    MINR = 0.0
    model()
    x0, x1, z0, z1 = bounds()
    span = max(x1 - x0, z1 - z0) / S          # px at sprite scale
    MINR = 0.55 * span / fill
    model()
    x0, x1, z0, z1 = bounds()
    span = max(x1 - x0, z1 - z0)
    pr.ortho_camera((x0 + x1) / 2, (z0 + z1) / 2, span * size / fill, size * FACTOR, size * FACTOR)
    bpy.context.view_layer.update()
    pr.render_passes(os.path.join(OUT, "icon_" + name), pr.normal_matcap())
    META["icon_" + name] = [0, 0, size, size]
    MINR = 0.0


# ------------------------------------------------------------------ helpers on the bus

R22 = (0, 0, rad(22.5))


def face(phi, u, z, out=0.0):
    """Point on the bus wall that faces phi degrees (0 = camera, +45 = front right): u along the
    wall, z up, `out` px proud of it."""
    p = rad(phi)
    d = APO + out
    return (math.sin(p) * d + math.cos(p) * u, -math.cos(p) * d + math.sin(p) * u, z)


def fbox(part, phi, u, z, su, sz, thick, out=0.0):
    return box(part, face(phi, u, z, out + thick / 2), (su, thick, sz), (0, 0, rad(phi)))


def fcyl(part, phi, u, z, out, r, depth, r2=None, up=0.0, verts=16):
    """Cylinder whose axis sticks out of the wall (up = degrees above horizontal)."""
    return cyl(part, face(phi, u, z, out), r, depth, rot=(rad(90 - up), 0, rad(phi)), verts=verts, r2=r2)


def bus_body(part="gold"):
    cyl(part, (0, 0, 0), 39, 41, rot=R22, verts=8, smooth=False)
    cyl(part, (0, 0, -21.75), 36.5, 2.5, rot=R22, verts=8, smooth=False)


def dish(part, base, r, depth, lean_cam, lean_right, rim=None, feed="jet", r0=4.0, sub_r=0.0):
    """Open two-step bowl on `base`, leaning toward the camera and to the right, with a feed."""
    rot = (rad(lean_cam), rad(lean_right), 0)
    m = Euler(rot).to_matrix()
    ax, e1, e2 = m @ Vector((0, 0, 1)), m @ Vector((1, 0, 0)), m @ Vector((0, 1, 0))
    b = Vector(base)
    rm = r0 + (r - r0) * 0.55
    d1 = depth * 0.3
    cyl(part, b + ax * (d1 / 2), r0, d1, rot=rot, r2=rm, caps=False, verts=32)
    cyl(rim or part, b + ax * (d1 + (depth - d1) / 2), rm, depth - d1, rot=rot, r2=r, caps=False, verts=32)
    cyl(part, b, r0, 0.6, rot=rot, verts=16)
    focus = b + ax * (depth + r * 0.5)
    for k in range(3):
        a = rad(90 + 120 * k)
        strut("metal", b + ax * depth + (e1 * math.cos(a) + e2 * math.sin(a)) * (r * 0.96), focus, 0.7)
    cyl(feed, focus - ax * 1.5, max(1.6, sub_r), 3.5 if sub_r == 0 else 1.2, rot=rot, verts=12)
    return ax


# ------------------------------------------------------------------ models

def m_bus():
    begin()
    bus_body()
    cyl("deck", (0, 0, 21.0), 38, 1, rot=R22, verts=8, smooth=False)
    cyl("dark", (0, 0, 21.55), 22.5, 0.3)                      # mounting ring on the deck
    cyl("deck", (0, 0, 21.6), 20.5, 0.4)
    cyl("dark", (0, 0, 21.7), 5, 0.4, verts=12)                # centre socket
    for x in (-27, 27):                                        # shoulder sockets
        cyl("dark", (x, -3, 21.6), 4.2, 0.4, verts=12)
        cyl("deck", (x, -3, 21.7), 3, 0.4, verts=12)
    box("red", (20, 24, 22.5), (2, 2, 2))                      # beacon at the back
    for phi in (-90, -45, 0, 45, 90):
        fbox("metal", phi, 0, 19, 29.8, 3, 0.7)                # bright top collar
        fbox("dark", phi, 0, -19.6, 29.8, 1.8, 0.5)            # dark lower band
        fbox("dark", phi, 0, 3.5, 29.8, 0.9, 0.4)              # seam between the two bays
        fbox("dark", phi, 14.7, 0, 0.9, 41, 0.4)               # foil creases at the corners
    fbox("dark", -90, -14.7, 0, 0.9, 41, 0.4)
    # empty racks and mounts (parts fill them)
    fbox("rack", 0, 0, -8.5, 27.6, 20.6, 0.5)                  # battery bank
    fbox("metal", 0, 0, -8.5, 27.6, 0.8, 0.7)
    for u in (-9, -4.5, 0, 4.5, 9):                            # slot guides
        fbox("slot", 0, u, -8.5, 0.8, 20.6, 0.6)
    fbox("rack", -45, 0, -8.5, 23.4, 20.6, 0.5)                # recorder rack
    fbox("slot", -45, 0, -8.5, 0.8, 20.6, 0.6)
    fbox("slot", -45, 0, -8.5, 23.4, 0.8, 0.6)
    for phi in (-45, 0, 45):                                   # instrument mounts
        fbox("deck", phi, 0, 10.5, 9, 6, 0.5)
        for u in (-3, 3):
            fbox("dark", phi, u, 10.5, 1, 1, 0.3, out=0.5)
    fbox("deck", 45, -4, -3, 8, 8, 0.5)                        # arm mount
    fbox("dark", 45, -4, -3, 2, 2, 0.3, out=0.5)
    for k in range(4):                                         # louvres
        fbox("jet", 45, 2.5 + k * 3, -13.5, 1.6, 8, 0.4)
    fbox("light", 0, 11.5, 19, 1.5, 1.5, 0.4, out=0.7)          # status lights
    fbox("green", 0, 8.5, 19, 1.5, 1.5, 0.4, out=0.7)
    for sx in (-1, 1):                                         # thruster quads at the skirt
        box("metal", (sx * 37.5, -4, -18.5), (4, 6, 5))
        box("nozzle", (sx * 40.2, -4, -18.5), (1.6, 3, 3))
        box("nozzle", (sx * 37.5, -4, -21.6), (3, 3, 1.4))


def m_shield():
    begin()
    bus_body("hold")
    cyl("titan", (0, 0, 19.5), 41, 5, rot=R22, verts=8, smooth=False)     # armoured lid and collar
    cyl("titan", (0, 0, -20.5), 41, 5, rot=R22, verts=8, smooth=False)
    cyl("dark", (0, 0, 22.05), 22.5, 0.3)
    cyl("titan", (0, 0, 22.1), 20.5, 0.4)
    apo2 = 41 * math.cos(rad(22.5)) - APO
    for phi in (-90, -45, 0, 45, 90):
        fbox("titan", phi, 0, 3.5, 31.4, 3, 1.6)                           # waist strap
        for u in (-15.6, 15.6):
            fbox("titan", phi, u, 0, 4, 36, 1.9)                           # corner straps
        for u in (-10, -5, 0, 5, 10):                                      # rivets
            fbox("rivet", phi, u, 19.5, 1, 1, 0.4, out=apo2)
            fbox("rivet", phi, u, -20.5, 1, 1, 0.4, out=apo2)
        for z in (-12, 12):
            fbox("rivet", phi, 0, 3.5, 1, 1, 0.4, out=1.6)
    for u in (-9, 9):
        fbox("rivet", 0, u, 3.5, 1, 1, 0.4, out=1.6)


def m_ascent():
    begin()
    z = ZD
    cyl("metal", (0, 0, z + 4.5), 20, 9)                       # propulsion module
    cyl("dark", (0, 0, z + 0.5), 20.4, 1.0)
    for k in range(8):
        a = rad(k * 45 + 10)
        box("dark", (math.cos(a) * 20, math.sin(a) * 20, z + 4.5), (0.9, 0.9, 8), (0, 0, a))
    for sx in (-1, 1):                                         # side tanks and thruster quads
        sphere("gold", (sx * 16, -11, z + 4.6), 5.6)
        box("jet", (sx * 21, 0, z + 6.5), (3, 5, 4))
        box("nozzle", (sx * 23, 0, z + 6.5), (1.4, 2.4, 2.4))
    cyl("jet", (0, 0, z + 10.2), 20.2, 2.4, r2=18.9)            # heat-tile band
    cyl("paint", (0, 0, z + 20), 19, 20, r2=8)                  # capsule
    cyl("red", (0, 0, z + 25.5), 12.9, 2.2, r2=11.7)
    sphere("glass", (-7.2, -11.2, z + 18), 3.3)                 # window
    sphere("glass", (7.2, -11.2, z + 18), 3.3)
    box("dark", (0, -15.2, z + 14.5), (5, 0.8, 6.5), (rad(-29), 0, 0))   # hatch
    cyl("metal", (0, 0, z + 31.5), 7.6, 3)                      # docking ring
    cyl("dark", (0, 0, z + 33.1), 5.6, 0.4)
    cyl("chrome", (0, 0, z + 34), 2, 2.2, verts=10)
    sphere("light", (11, 2, z + 30.6), 1.2, segs=8)


def m_hga(z=ZD):
    begin()
    strut("metal", (0, 0, z), (0, 0, z + 21), 1.7)
    strut("metal", (0, 0, z + 10), (0, 0, z + 12), 2.6)
    cyl("jet", (0, 0, z + 1), 4.2, 2, verts=12)
    box("metal", (0, 0, z + 22), (7, 6, 5))
    cyl("chrome", (0, 0, z + 22), 2.2, 9, rot=(0, rad(90), 0), verts=10)
    dish("paint", (0, 0, z + 24.5), 29, 9, 22, 14, feed="red")


def m_ka():
    begin()
    box("jet", (36.5, 0, 17), (4, 5, 5))
    strut("metal", (36, 0, 17), (58, 0, 43), 1.4)
    strut("metal", (44, 0, 18), (50, 0, 33), 0.8)
    box("metal", (58, 0, 44), (5, 5, 4))
    dish("kadish", (58, 0, 46), 17, 6, 26, 24, rim="gold", feed="chrome", sub_r=3.4)


def m_mga():
    begin()
    b = (-27, -3, ZD)
    cyl("jet", (b[0], b[1], b[2] + 1), 3.4, 2, verts=12)
    strut("metal", b, (b[0], b[1], b[2] + 7), 1.3)
    dish("paint", (b[0], b[1], b[2] + 7.5), 9.5, 4, 30, -20, feed="red", r0=2.2)


def m_lga():
    begin()
    b = (-10, -27, ZD)
    box("jet", (b[0], b[1], b[2] + 1), (4, 4, 2))
    strut("metal", b, (b[0], b[1], b[2] + 12), 0.9)
    cyl("paint", (b[0], b[1], b[2] + 14), 3.2, 5, r2=0.9, verts=12)
    cyl("red", (b[0], b[1], b[2] + 11.6), 3.3, 0.9, verts=12)


def m_chute():
    begin()
    b = (27, -3, ZD)
    cyl("metal", (b[0], b[1], b[2] + 3.5), 6.9, 7)             # can (wider than the straps inside it)
    cyl("dark", (b[0], b[1], b[2] + 1), 7.1, 0.9)
    cyl("dark", (b[0], b[1], b[2] + 6.6), 7.1, 0.9)
    sphere("orange", (b[0], b[1], b[2] + 7), 6.5)
    for a in (0, 60, 120):
        cyl("paint", (b[0], b[1], b[2] + 7), 6.75, 1.7, rot=(0, rad(90), rad(a)))
    sphere("red", (b[0], b[1], b[2] + 13.6), 1.5, segs=8)


def m_mag(icon=False):
    begin()
    a = Vector((-34, 0, 17))
    b = Vector((-64, 0, 27)) if icon else Vector((-120, 0, 45.7))
    box("jet", a, (5, 5, 5))
    strut("metal", a, b, 1.0)
    for f in (0.25, 0.5, 0.75):
        p = a.lerp(b, f)
        box("dark", p, (1.6, 2.6, 3.4))
    box("metal", a.lerp(b, 0.6) + Vector((0, 0, -2.5)), (5, 4, 4))
    box("paint", b, (7, 5, 5))
    box("red", b + Vector((-4, 0, 0)), (1.5, 5.2, 5.2))


def m_drill():
    begin()
    rz = (rad(90), 0, rad(45))
    fbox("metal", 45, -4, -3, 8, 8, 1.0)
    cyl("chrome", face(45, -4, -3, 3), 3, 3, rot=rz, verts=12)             # shoulder
    strut("metal", face(45, -4, -3, 3.5), face(45, -8.5, -16.5, 3.5), 1.6)  # upper arm, folded down
    cyl("chrome", face(45, -8.5, -16.5, 3.5), 2.5, 3.4, rot=rz, verts=12)  # elbow
    strut("paint", face(45, -8.5, -16.5, 5), face(45, 6, -1, 5), 1.5)      # forearm, folded back up
    cyl("chrome", face(45, 6, -1, 5), 2.3, 3.4, rot=rz, verts=12)          # wrist
    x, y, z = face(45, 8.5, -8, 6)
    cyl("jet", (x, y, z), 3.6, 10, verts=12)                               # drill motor
    cyl("red", (x, y, z + 2.5), 3.9, 1.6, verts=12)
    cyl("orange", (x, y, z - 9), 0.4, 8, r2=2.4, verts=10)                 # bit
    cyl("chrome", (x, y, z - 5.6), 2.8, 1.2, verts=10)


def m_camera():
    begin()
    fbox("paint", -45, 0, 10.5, 13, 9.5, 6)
    fbox("jet", -45, 0, 15.8, 14, 1.2, 7.5)                                # sun visor
    fcyl("jet", -45, 1.5, 10, 9, 3.9, 6)
    fcyl("metal", -45, 1.5, 10, 12, 4.2, 1.0)
    fcyl("glass", -45, 1.5, 10, 12.6, 3.0, 0.6)
    fbox("red", -45, -5, 13, 1.6, 1.6, 0.5, out=6)


def m_spectro():
    begin()
    fbox("paint", 0, 0, 10.5, 21, 10, 6)
    fbox("jet", 0, -2.5, 9.8, 13, 5.4, 0.6, out=6)                          # aperture
    fbox("glass", 0, -2.5, 9.8, 11, 2.6, 0.5, out=6.5)
    box("red", face(0, 0, 16.2, 4), (22, 9, 1.5))                           # radiator
    fbox("light", 0, 7.5, 12.2, 1.6, 1.6, 0.5, out=6)
    fbox("dark", 0, 7.5, 8.2, 3, 2.4, 0.5, out=6)


def m_dust():
    begin()
    fbox("metal", 45, 0, 8, 7, 6, 2.5)
    rot = (rad(90 - 38), 0, rad(45))
    ax = Euler(rot).to_matrix() @ Vector((0, 0, 1))
    c = Vector(face(45, 0, 10.5, 6.5))
    cyl("jet", c, 5.4, 9, rot=rot, verts=16)
    cyl("orange", c - ax * 1.5, 5.7, 1.6, rot=rot, verts=16)
    cyl("metal", c + ax * 4.2, 5.9, 1.0, rot=rot, verts=16)
    cyl("gold", c + ax * 4.6, 4.5, 0.6, rot=rot, verts=16)
    cyl("dark", c + ax * 4.8, 1.6, 0.5, rot=rot, verts=10)


def m_recorder(i):
    begin()
    u = -5.8 + 11.6 * (i % 2)
    z = -3.4 - 10.2 * (i // 2)
    fbox("jet", -45, u, z, 9.6, 8.2, 3)
    fbox("paint", -45, u - 1.2, z + 2, 5.6, 1.7, 0.4, out=3)
    fbox("green", -45, u + 3, z - 2, 1.8, 1.8, 0.4, out=3)
    fbox("metal", -45, u - 2.5, z - 2, 3.5, 1.2, 0.4, out=3)


def m_battery(j, hi):
    begin()
    u = -11.25 + 4.5 * (j % 6)
    z = -3.6 - 10.2 * (j // 6)
    if hi:
        fbox("jet", 0, u, z - 0.6, 3.6, 7.6, 3.4)
        fbox("orange", 0, u, z + 4, 3.6, 1.7, 3.6)
        fbox("gold", 0, u, z - 1.4, 3.7, 1.3, 3.5)
    else:
        fbox("paint", 0, u, z - 0.6, 3.6, 7.6, 3)
        fbox("green", 0, u, z + 4, 3.6, 1.7, 3.2)


def m_rtg():
    begin()
    z = -19
    ry = (0, rad(90), 0)
    strut("metal", (34, 0, z), (47, 0, z), 1.3)
    box("jet", (36.5, 0, z), (3, 4, 4))
    cyl("jet", (57, 0, z), 5, 20, rot=ry, verts=16)
    for k in range(8):
        a = rad(k * 45)
        box("hub", (57, 6.5 * math.sin(a), z + 6.5 * math.cos(a)), (17, 1.0, 4.2), (-a, 0, 0))
    cyl("metal", (46.6, 0, z), 5.8, 1.6, rot=ry, verts=16)
    cyl("metal", (67.4, 0, z), 5.8, 1.6, rot=ry, verts=16)
    cyl("orange", (68.6, 0, z), 3.2, 1.2, rot=ry, verts=12)
    box("light", (52, -5.2, z), (3, 0.6, 3))


def m_legs(icon=False):
    begin()
    for a in ((25, 155) if icon else (25, 155, 205, 335)):
        if icon:
            a = 0 if a == 25 else 180
        ca, sa = math.cos(rad(a)), math.sin(rad(a))
        hip = Vector((27 * ca, 27 * sa, ZB + 22))
        knee = Vector((27 * ca, 27 * sa, ZB + 3))
        foot = Vector((66 * ca, 66 * sa, ZB - 19.5))
        strut("metal", hip, foot, 1.7)
        strut("gold", hip, hip.lerp(foot, 0.42), 2.5)
        strut("chrome", knee, hip.lerp(foot, 0.62), 1.1)
        box("jet", hip, (5, 5, 5), (0, 0, rad(a)))
        box("jet", knee, (4, 4, 4), (0, 0, rad(a)))
        cyl("metal", (66 * ca, 66 * sa, ZB - 20.6), 6.6, 2.2, verts=16)
        cyl("dark", (66 * ca, 66 * sa, ZB - 19.4), 3.2, 0.5, verts=10)
        sphere("chrome", foot, 1.8, segs=8)


def m_airbags():
    begin()
    k = 0
    for k in range(8):
        a = rad(k * 45 + 22.5)
        z = ZB - 12 + (3 if k % 2 else -2)
        c = (33 * math.cos(a), 33 * math.sin(a), z)
        sphere("bag", c, 13)
        torus("seam", c, 13.05, 0.45, rot=(rad(90), 0, a))
        torus("seam", c, 13.05, 0.45, rot=(rad(20), 0, a))
    for k in range(4):
        a = rad(k * 90 + 45)
        c = (15 * math.cos(a), 15 * math.sin(a), ZB - 23)
        sphere("bag", c, 11.5)
        torus("seam", c, 11.55, 0.45, rot=(rad(90), 0, a + 0.7))


def m_heatshield():
    begin()
    zr = ZB - 30                                              # rim plane
    cyl("tps", (0, 0, zr - 11), 24, 22, r2=62, caps=False, verts=40)
    cyl("tps", (0, 0, zr - 23.5), 13, 3, r2=24, verts=40)
    cyl("hsin", (0, 0, zr - 9.6), 22, 18, r2=59.5, caps=False, verts=40)
    cyl("hsin", (0, 0, zr - 18.4), 22.4, 0.6, verts=24)
    cyl("metal", (0, 0, zr - 0.4), 61.2, 1.6, r2=62.3, caps=False, verts=40)   # rim band
    for k in range(12):
        a = rad(k * 30 + 15)
        ca, sa = math.cos(a), math.sin(a)
        strut("jet", (22 * ca, 22 * sa, zr - 17.8), (59 * ca, 59 * sa, zr - 0.8), 0.8)
    cyl("tps", (0, 0, zr - 8), 40.6, 0.9, r2=42.2, caps=False, verts=40)       # tile rows
    cyl("tps", (0, 0, zr - 15), 29.4, 0.9, r2=31, caps=False, verts=40)


def wheel(x, y, z, r, w, side, spokes=True):
    rx = rad(90)
    cyl("tyre", (x, y, z), r, w, rot=(rx, 0, 0), verts=20)
    for k in range(10):
        a = k * math.tau / 10
        box("dark", (x + math.cos(a) * r, y, z + math.sin(a) * r), (0.7, w * 1.02, 0.7), (0, -a, 0))
    cyl("chrome", (x, y + side * (w / 2), z), r * 0.62, 0.4, rot=(rx, 0, 0), verts=16)
    cyl("hub", (x, y + side * (w / 2 + 0.3), z), r * 0.24, 0.5, rot=(rx, 0, 0), verts=8)


def m_rover():
    """Small rover, stowed under the right side of the bus."""
    begin()
    x0 = 30
    zt = ZB - 6
    strut("metal", (x0 - 3, 0, zt), (x0 + 27, 0, zt), 1.0)             # rail it hangs from
    for x in (x0 + 5, x0 + 21):
        strut("metal", (x, 0, zt), (x, 0, zt - 4), 0.9)
    box("paint", (x0 + 13, 0, zt - 7.5), (23, 13, 6))                  # chassis
    box("dark", (x0 + 13, -6.6, zt - 8.6), (21, 0.4, 0.7))
    box("cell", (x0 + 13, 0, zt - 4), (24, 14, 1.2))                   # solar deck
    for k in range(4):
        box("metal", (x0 + 4 + k * 6, 0, zt - 3.5), (0.7, 14, 0.5))
    box("gold", (x0 + 13, 0, zt - 10.8), (19, 10, 1))
    for x in (x0 + 4.5, x0 + 13, x0 + 21.5):
        for sy in (-1, 1):
            wheel(x, sy * 7.5, zt - 12.5, 3.7, 3, sy)
    box("glass", (x0 + 24.8, -3, zt - 6.6), (0.6, 4.5, 2.4))            # eyes
    box("light", (x0 + 24.8, 3.5, zt - 7.5), (0.6, 2, 2))
    strut("metal", (x0 + 21, -3, zt - 3), (x0 + 9, -3, zt - 1.6), 0.8)  # folded mast
    box("paint", (x0 + 7.5, -3, zt - 1.6), (4.5, 3.5, 2.6))


def m_rover_big(x_in=-30.0):
    """Big rover (the model of tools/blender/ships.py) hanging under the left side, facing out."""
    begin()
    zt = ZB - 6
    strut("metal", (x_in + 3, 0, zt), (x_in - 40, 0, zt), 1.1)
    for x in (x_in - 9, x_in - 30):
        strut("metal", (x, 0, zt), (x, 0, zt - 5), 1.0)
    k = 1.32
    sub((x_in - 20, 0, zt - 34.5), scale=(-k, k, k))
    box("paint", (0, 0, 10), (20, 11.5, 5))
    box("dark", (0, -5.8, 9.2), (18, 0.3, 0.6))
    box("dark", (-4, -5.8, 10), (0.5, 0.3, 4.2))
    box("dark", (4.5, -5.8, 10), (0.5, 0.3, 4.2))
    for j in range(4):
        box("jet", (-8.5 + j, -5.8, 10.8), (0.5, 0.3, 1.8))
    box("cell", (1, 0, 12.8), (18, 12, 0.6))
    for j in range(5):
        box("metal", (-7 + j * 4, 0, 13.1), (0.3, 12, 0.3))
    box("gold", (-2, 0, 7.2), (14, 9, 0.8))
    cyl("jet", (-12, 0, 12.5), 2.2, 6, rot=(0, rad(-40), 0), verts=12)
    for j in range(4):
        box("hub", (-12, 0, 12.5), (0.6, 6.2, 0.6), (j * math.pi / 4, rad(-40), 0))
    strut("metal", (7.5, -2, 13), (7.5, -2, 20.5), 0.55)
    box("paint", (7.8, -2, 21.5), (3.6, 5.2, 2.2))
    box("glass", (9.7, -3.3, 21.6), (0.3, 1.2, 1.0))
    box("glass", (9.7, -0.7, 21.6), (0.3, 1.2, 1.0))
    box("red", (7.8, -4.7, 22), (0.6, 0.3, 0.6))
    cyl("paint", (-4.5, 2.5, 16.2), 3.2, 0.6, rot=(rad(-20), rad(30), 0), r2=0.6)
    strut("metal", (-4.5, 2.5, 13), (-4.5, 2.5, 16), 0.4)
    box("light", (10.1, -4, 10.5), (0.3, 1.4, 1.0))
    box("light", (10.1, 4, 10.5), (0.3, 1.4, 1.0))
    strut("metal", (10, -3.5, 9.5), (13.5, -3.5, 7.5), 0.5)
    strut("metal", (13.5, -3.5, 7.5), (13.5, -3.5, 11.5), 0.45)
    box("metal", (13.8, -3.5, 12.2), (1.8, 1.8, 1.8))
    for side in (-7.5, 7.5):
        s = -1 if side < 0 else 1
        strut("metal", (2, side, 9.5), (9.5, side, 4.2), 0.5)
        strut("metal", (2, side, 9.5), (-4.5, side, 6.2), 0.5)
        strut("metal", (-4.5, side, 6.2), (0, side, 4.2), 0.45)
        strut("metal", (-4.5, side, 6.2), (-9.5, side, 4.2), 0.45)
        for x in (-9.5, 0.0, 9.5):
            wheel(x, side, 3.6, 3.6, 3.0, s)


def m_drone(x_in=-30.0):
    """Ring-sampling drone (the model of ships.py) docked under the left side."""
    begin()
    zt = ZB - 6
    strut("metal", (x_in + 3, 0, zt), (x_in - 30, 0, zt), 1.1)
    strut("metal", (x_in - 16, 0, zt), (x_in - 16, 0, zt - 6), 1.2)
    k = 1.25
    sub((x_in - 16, 0, zt - 22), scale=(k, k, k), rotz=25)
    sphere("paint", (0, 0, 5), 7, (1.0, 1.0, 0.55))
    cyl("dark", (0, 0, 6.2), 7.05, 0.3)
    cyl("gold", (0, 0, 3.2), 7.5, 2.2)
    sphere("glass", (5.5, -2.2, 4.5), 1.8)
    sphere("light", (6, -2.6, 5), 0.5, segs=8)
    for i in range(4):
        a = rad(45 + 90 * i)
        x, y = math.cos(a) * 9.5, math.sin(a) * 9.5
        strut("metal", (x * 0.6, y * 0.6, 4), (x, y, 4), 0.5)
        cyl("jet", (x, y, 3.8), 2, 2.8, r2=1.2)
        cyl("red", (x, y, 5.5), 0.7, 0.5)
    cyl("nozzle", (0, 0, 0), 2.8, 3, r2=1.6)
    box("metal", (2, -4, 1.5), (2, 1, 1.2))


def m_engine():
    begin()
    cyl("jet", (0, 0, ZB - 1.5), 8, 3, verts=16)
    cyl("nozzle", (0, 0, ZB - 10), 12.5, 14, r2=5)
    cyl("chrome", (0, 0, ZB - 6.5), 7.3, 0.9, r2=6.8)
    cyl("chrome", (0, 0, ZB - 11.5), 10, 0.9, r2=9.5)
    cyl("orange", (0, 0, ZB - 16.4), 12.6, 1.0, r2=12.3)       # hot rim
    for sx in (-1, 1):
        strut("metal", (sx * 7, -2, ZB - 0.5), (sx * 9, -2, ZB - 9), 0.7)


def m_core(k):
    """Core propellant tank holding k units (1..8): 3 px of barrel per unit."""
    begin()
    L = 3.0 * k
    zt = ZB - 5
    sphere("tdome", (0, 0, zt), 28, (1, 1, 5 / 28))
    sphere("tdome", (0, 0, zt - L), 28, (1, 1, 5 / 28))
    cyl("paint", (0, 0, zt - L / 2), 28, L, verts=32)
    cyl("metal", (0, 0, zt - 0.5), 28.3, 1.0, verts=32)
    cyl("dark", (0, 0, zt - L + 0.5), 28.3, 1.0, verts=32)
    if k > 4:
        cyl("dark", (0, 0, zt - 12), 28.15, 0.7, verts=32)
    if k >= 2:
        cyl("red", (0, 0, zt - 3.2), 28.15, 1.6, verts=32)
    a = rad(-115)
    rx, ry = 28.6 * math.cos(a), 28.6 * math.sin(a)
    box("metal", (rx, ry, zt - L / 2), (2.4, 2.4, L), (0, 0, a))          # feed line with a tick per unit
    for j in range(k):
        box("dark", (rx * 1.03, ry * 1.03, zt - 3 * j - 2.6), (2.6, 2.6, 0.7), (0, 0, a))
    a = rad(-55)
    box("jet", (28.4 * math.cos(a), 28.4 * math.sin(a), zt - min(L - 1.5, 7)), (4, 2, 2.6), (0, 0, a + rad(90)))


def m_side(k):
    """Radial side tank holding k units (1..28), with its own nose cone and small engine."""
    begin()
    L = 3.0 * k
    x = 40
    zt = ZB
    cyl("red", (x, 0, zt - 4), 10.6, 8, r2=2.6)
    sphere("red", (x, 0, zt - 0.9), 2.7, segs=10)
    cyl("paint", (x, 0, zt - 8 - L / 2), 11, L)
    cyl("dark", (x, 0, zt - 8.4), 11.2, 0.8)
    for j in range(8, k, 8):
        cyl("dark", (x, 0, zt - 8 - 3 * j), 11.15, 0.7)
    sphere("tdome", (x, 0, zt - 8 - L), 11, (1, 1, 3 / 11))
    cyl("jet", (x, 0, zt - 8 - L - 3.4), 3.4, 1.6, verts=12)
    cyl("nozzle", (x, 0, zt - 8 - L - 7), 5.6, 6, r2=2.6, verts=16)
    strut("metal", (x - 9, 0, zt - 10), (x - 14, 0, zt - 10), 1.1)          # clamps to the core
    if k >= 4:
        strut("metal", (x - 9, 0, zt - 8 - L + 2), (x - 14, 0, zt - 8 - L + 2), 1.1)
    box("metal", (x + 3.5, -10.6, zt - 8 - L / 2), (1.6, 1.6, L))            # raceway


# ------------------------------------------------------------------ launch vehicles (pure side view)

def _core(x, y, h, r=7.0, legs=True, fins=True, nose=None):
    """One kerosene booster core standing on z = 0, h px tall."""
    for i, dx in enumerate((-3.6, 0.0, 3.6)):
        cyl("nozzle", (x + dx, y + (-1 if i == 1 else 1), 3.2), 2.6, 6.4, r2=1.3, verts=12)
    cyl("jet", (x, y, 9.5), r + 0.3, 7)
    box("dark", (x, y, 6.6), (r * 2.1, r * 2.1, 1.0))
    cyl("paint", (x, y, 13 + (h - 13) / 2), r, h - 13)
    z = 30.0
    while z < h - 8:
        cyl("dark", (x, y, z), r + 0.06, 0.6)
        z += 24
    box("metal", (x + 1, y - r - 0.1, 13 + (h - 13) / 2), (1.0, 0.6, h - 20))
    if legs:
        for i in range(4):
            a = rad(45 + 90 * i)
            ca, sa = math.cos(a), math.sin(a)
            strut("jet", (x + ca * (r + 0.6), y + sa * (r + 0.6), 8), (x + ca * (r + 1.0), y + sa * (r + 1.0), 42), 1.1)
    if fins:
        for i in range(4):
            a = rad(45 + 90 * i)
            box("dark", (x + math.cos(a) * (r + 2), y + math.sin(a) * (r + 2), h - 5), (4.2, 0.8, 5), (0, 0, a))
    if nose:
        cyl("paint", (x, y, h + nose / 2), r, nose, r2=1.6)
        cyl("dark", (x, y, h), r + 0.06, 0.6)


def _upper(x, z, r, h2, rf, hf):
    """Interstage, second stage and fairing on top of a core that ends at z."""
    cyl("jet", (x, 0, z + 5.5), r + 0.15, 11)
    cyl("paint", (x, 0, z + 11 + h2 / 2), r, h2)
    cyl("dark", (x, 0, z + 11.3), r + 0.06, 0.6)
    zf = z + 11 + h2
    cyl("paint", (x, 0, zf + 2), r, 4, r2=rf)
    cyl("paint", (x, 0, zf + 4 + hf / 2), rf, hf)
    box("dark", (x, -rf - 0.1, zf + 4 + hf / 2), (0.5, 0.5, hf))
    cyl("paint", (x, 0, zf + 4 + hf + rf * 0.9), rf, rf * 1.8, r2=1.4)
    cyl("dark", (x, 0, zf + 4.2), rf + 0.06, 0.6)
    return zf + 4 + hf + rf * 1.8


def m_lv_falcon9():
    begin(20, 0)
    _core(0, 0, 118)
    _upper(0, 118, 7, 26, 9.5, 20)


def m_lv_heavy():
    begin(0, 0)
    for sx in (-1, 1):
        _core(sx * 15.5, 0, 112, nose=16)
        box("jet", (sx * 7.8, 0, 30), (2.5, 3, 3))
        box("jet", (sx * 7.8, 0, 100), (2.5, 3, 3))
    _core(0, -1, 118)
    _upper(0, 118, 7, 26, 9.5, 20)


def m_lv_electron():
    begin(20, 0)
    for dx in (-2, 0, 2):
        cyl("nozzle", (dx, -1 if dx == 0 else 1, 2), 1.5, 4, r2=0.8, verts=10)
    cyl("metal", (0, 0, 5.5), 4.1, 3, verts=16)
    cyl("jet", (0, 0, 24), 3.9, 34, verts=16)                  # carbon first stage
    cyl("paint", (0, 0, 16), 3.96, 1.2, verts=16)
    cyl("metal", (0, 0, 42), 3.96, 2, verts=16)
    cyl("jet", (0, 0, 49), 3.9, 12, verts=16)                  # second stage
    cyl("paint", (0, 0, 55.5), 3.96, 1.2, verts=16)
    cyl("jet", (0, 0, 59), 4.4, 8, verts=16)                   # fairing
    cyl("jet", (0, 0, 66), 4.4, 6, r2=1.0, verts=16)
    cyl("red", (0, 0, 36), 3.96, 1.2, verts=16)
    box("metal", (1, -3.9, 24), (0.7, 0.5, 30))


def m_lv_vulcan():
    begin(20, 0)
    for dx in (-4, 4):
        cyl("nozzle", (dx, 0, 4), 3.4, 8, r2=1.6, verts=12)
    cyl("jet", (0, 0, 11), 9.3, 6)
    cyl("orange", (0, 0, 52), 9, 76)                           # core in bare insulation
    for z in (30, 56, 82):
        cyl("dark", (0, 0, z), 9.06, 0.6)
    cyl("paint", (0, 0, 97), 9, 14)                            # interstage and upper stage
    cyl("dark", (0, 0, 90.2), 9.06, 0.6)
    cyl("red", (0, 0, 96), 9.06, 2)
    cyl("paint", (0, 0, 106), 9, 4, r2=10.6)
    cyl("paint", (0, 0, 128), 10.6, 40)
    box("dark", (0, -10.7, 128), (0.5, 0.5, 40))
    cyl("paint", (0, 0, 157), 10.6, 18, r2=1.6)
    cyl("dark", (0, 0, 108.2), 10.66, 0.6)
    box("metal", (2, -9.1, 52), (1.2, 0.6, 72))
    for a in (200, 255, 305, 345):                             # strap-on solid boosters
        ca, sa = math.cos(rad(a)), math.sin(rad(a))
        bx, by = ca * 12.6, sa * 12.6
        cyl("nozzle", (bx, by, 2.5), 3.0, 5, r2=1.6, verts=12)
        cyl("paint", (bx, by, 33), 3.6, 56, verts=16)
        cyl("dark", (bx, by, 20), 3.66, 0.6, verts=16)
        cyl("dark", (bx, by, 44), 3.66, 0.6, verts=16)
        cyl("paint", (bx, by, 65), 3.6, 8, r2=0.7, verts=16)


# ------------------------------------------------------------------ what to render

def sprites():
    """name -> (model, canvas x0, y0, w, h, mirror)."""
    out = {
        "bus": (m_bus, -46, -34, 92, 68, False),
        "shield": (m_shield, -48, -36, 96, 72, False),
        "ascent": (m_ascent, -30, -66, 60, 52, False),
        "hga": (m_hga, -40, -84, 80, 68, False),
        "ka": (m_ka, 28, -84, 60, 72, False),
        "mga": (m_mga, -44, -50, 36, 34, False),
        "lga": (m_lga, -22, -40, 24, 30, False),
        "chute": (m_chute, 14, -44, 28, 30, False),
        "mag": (m_mag, -130, -56, 100, 48, False),
        "drill": (m_drill, 10, -10, 40, 44, False),
        "camera": (m_camera, -46, -26, 34, 28, False),
        "spectro": (m_spectro, -16, -24, 32, 32, False),
        "dust": (m_dust, 12, -30, 40, 36, False),
        "rtg": (m_rtg, 30, 6, 46, 26, True),
        "legs": (m_legs, -80, -6, 160, 66, False),
        "airbags": (m_airbags, -56, 8, 112, 60, False),
        "heatshield": (m_heatshield, -70, 36, 140, 52, False),
        "rover": (m_rover, 22, 22, 42, 30, False),
        "rover_big": (m_rover_big, -80, 22, 60, 50, False),
        "drone": (m_drone, -70, 22, 48, 36, False),
        "engine": (m_engine, -18, 18, 36, 30, False),
    }
    for i in range(4):
        out["recorder_%d" % i] = (lambda i=i: m_recorder(i), -40, -8, 30, 36, False)
    for j in range(12):
        out["battery_%d" % j] = (lambda j=j: m_battery(j, False), -20, -4, 40, 32, False)
        out["battery_hi_%d" % j] = (lambda j=j: m_battery(j, True), -20, -4, 40, 32, False)
    for k in range(1, 9):
        out["core_%d" % k] = (lambda k=k: m_core(k), -34, 14, 68, 52, False)
    for k in range(1, 29):
        out["side_%d" % k] = (lambda k=k: m_side(k), 22, 16, 36, 20 + 3 * k + 8, True)
    for n, fn in (("electron", m_lv_electron), ("falcon9", m_lv_falcon9), ("vulcan", m_lv_vulcan), ("heavy", m_lv_heavy)):
        out["lv_" + n] = (fn, -30, -200, 60, 200, False)
    return out


def icons():
    return {
        "bus": m_bus, "rtg": m_rtg, "battery": lambda: m_battery(0, False), "battery_hi": lambda: m_battery(0, True),
        "lga": m_lga, "mga": m_mga, "hga": m_hga, "ka": m_ka, "recorder": lambda: m_recorder(0),
        "camera": m_camera, "spectro": m_spectro, "mag": lambda: m_mag(True), "dust": m_dust, "drill": m_drill,
        "legs": lambda: m_legs(True), "airbags": m_airbags, "heatshield": m_heatshield, "chute": m_chute,
        "rover": m_rover, "rover_big": m_rover_big, "drone": m_drone, "ascent": m_ascent,
        "prop": lambda: m_core(5), "shield": m_shield,
    }


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    meta_path = os.path.join(OUT, "sprites.json")
    if want and os.path.exists(meta_path):
        with open(meta_path) as fh:
            META.update(json.load(fh))

    def wanted(n):
        return not want or any(n.startswith(w) for w in want)

    for name, (model, x0, y0, w, h, mirror) in sprites().items():
        if wanted(name):
            model()
            shoot(name, x0, y0, w, h, mirror)
    for name, model in icons().items():
        if wanted("icon_" + name):
            shoot_icon(name, model)
    with open(meta_path, "w") as fh:
        json.dump(META, fh, indent=0)
    meta = {n: {"id": list(v[0]), "ramp": v[1], "order": v[2]} for n, v in PARTS.items()}
    with open(os.path.join(OUT, "parts.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print("PARTS DONE", len(META))
