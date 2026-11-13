"""Turns Blender ID + normal passes into palette pixel art.

For each output pixel (a block of `factor` x `factor` render pixels):
  - coverage below `alpha_cut` -> transparent
  - the part is the majority ID in the block, its normal the block average
  - light = toon bands of dot(normal, LIGHT) mapped onto the part's ramp
Parts that sit behind a nearer part get a darker rim where they meet
(separation lines), and the silhouette gets a 1px outline (outline=2: two,
the inner ring selective, for a figure drawn at double detail so its edge
stays as bold as the world's).
"""
import json

import numpy as np
from PIL import Image

from palette import P

LIGHT = np.array([-0.55, 0.6, 0.58])  # view space: x right, y up, z toward camera
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def srgb(c):
    """Linear 0..1 -> sRGB 0..255, how Blender writes material colors."""
    c = np.asarray(c, dtype=np.float64)
    out = np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)
    return np.clip(out * 255.0, 0, 255)


def load_pass(path):
    return np.array(Image.open(path).convert("RGBA")).astype(np.int32)


def compose(id_png, n_png, parts, factor=4, alpha_cut=0.38, outline=True, bands=None, selective=False, normals_out=None):
    """parts: {name: {"id": [r,g,b] (linear 0..255 as given to Blender),
                      "ramp": [colors darkest..lightest], "order": int}}"""
    ids = load_pass(id_png)
    nrm = load_pass(n_png)
    h, w = ids.shape[0] // factor, ids.shape[1] // factor
    names = list(parts)
    expected = np.array([srgb(np.array(parts[n]["id"]) / 255.0) for n in names])
    # Label every render pixel with its part index (-1 = empty).
    rgb = ids[..., :3].astype(np.float64)
    d = np.linalg.norm(rgb[:, :, None, :] - expected[None, None, :, :], axis=-1)
    label = np.argmin(d, axis=-1)
    label[ids[..., 3] < 128] = -1
    label[np.min(d, axis=-1) > 40] = -1
    normal = nrm[..., :3] / 255.0 * 2.0 - 1.0

    out_part = -np.ones((h, w), dtype=np.int32)
    out_light = np.zeros((h, w))
    out_n = np.zeros((h, w, 3))
    out_n[..., 2] = 1.0
    for y in range(h):
        for x in range(w):
            blk = label[y * factor:(y + 1) * factor, x * factor:(x + 1) * factor]
            opaque = blk[blk >= 0]
            if opaque.size < alpha_cut * factor * factor:
                continue
            vals, counts = np.unique(opaque, return_counts=True)
            # Ties go to the nearer part so thin front limbs survive.
            best = max(zip(counts, [parts[names[v]]["order"] for v in vals], vals))[2]
            mask = blk == best
            nb = normal[y * factor:(y + 1) * factor, x * factor:(x + 1) * factor][mask]
            n = nb.mean(axis=0)
            n = n / (np.linalg.norm(n) + 1e-9)
            out_part[y, x] = best
            out_n[y, x] = n
            out_light[y, x] = float(np.dot(n, LIGHT))

    img = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            pi = out_part[y, x]
            if pi < 0:
                continue
            spec = parts[names[pi]]
            ramp = spec["ramp"]
            th = spec.get("bands") or bands or _default_bands(len(ramp))
            level = int(np.searchsorted(th, out_light[y, x]))
            # Separation: darken where a nearer part is right next to this one.
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and out_part[yy, xx] >= 0 and out_part[yy, xx] != pi:
                    if parts[names[out_part[yy, xx]]]["order"] > spec["order"] + spec.get("sep", 0):
                        level = max(0, level - 1)
                        break
            img[y, x] = ramp[min(level, len(ramp) - 1)]
    tools = {i for i, n in enumerate(names) if parts[n].get("tool")}
    if tools:
        img = _tool_shade(img, out_part, names, parts, tools)
    if outline:
        img = _outline(img, P["ol"], selective)
        if outline == 2:
            img = _outline(img, P["ol"], False)
    if normals_out is not None:
        # The normal map the game lights it with (view space, encoded *0.5+0.5;
        # the outline faces the camera).
        nm = np.zeros((h, w, 4), dtype=np.uint8)
        nm[..., :3] = np.clip((out_n * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
        nm[..., 3] = img[..., 3]
        normals_out.append(nm)
    return img, out_part, names



def _tool_shade(img, part, names, parts, tools):
    """Held tools shaded as their icons are (tools/art/gen_icons.py), not as
    the render's flat faces: each part lit along its upper left edges and
    shaded along its lower right. A metal head (a four-tone part) is drawn a
    tone brighter, its lit edges in its brightest: it catches the light, so
    it reads against dark ground and the wreck without an outline (there's
    none round him either: the user)."""
    out = img.copy()
    h, w = part.shape

    def edge(y, x, p):
        """The tool's own silhouette: where it meets empty space or him (not
        where one of its parts meets another: a honed strip along a blade is
        shaded with it, or a small head came out as rings of lines)."""
        return not (0 <= y < h and 0 <= x < w) or part[y, x] not in tools

    for y in range(h):
        for x in range(w):
            p = part[y, x]
            if p not in tools:
                continue
            ramp = parts[names[p]]["ramp"]
            n = len(ramp)
            # (a metal head's shaded edge only a tone down: the darkest round a
            # head three or four pixels across left a hollow ring)
            lit, body, shade = (n - 1, n - 2, 1) if n >= 4 else (n - 1, min(1, n - 1), 0)
            if edge(y - 1, x, p) or edge(y, x - 1, p):
                out[y, x] = ramp[lit]
            elif edge(y + 1, x, p) or edge(y, x + 1, p):
                out[y, x] = ramp[shade]
            else:
                out[y, x] = ramp[body]
    return out


def _default_bands(n):
    """Light thresholds for an n-color ramp (darkest first)."""
    return {2: [0.2], 3: [0.0, 0.5], 4: [-0.15, 0.25, 0.65], 5: [-0.25, 0.1, 0.4, 0.72]}.get(n, list(np.linspace(-0.4, 0.8, n - 1)))


def _outline(img, color, selective=False, keep=0.42):
    """1px outline. Selective: each edge pixel is a deep shade of the colour
    it borders (softer, more painterly than a flat near-black line); `keep`
    is how much of that colour stays."""
    h, w = img.shape[:2]
    a = img[..., 3] > 0
    out = img.copy()
    ol = np.array(color[:3], dtype=np.float64)
    for y in range(h):
        for x in range(w):
            if a[y, x]:
                continue
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and a[yy, xx]:
                    if selective:
                        rgb = img[yy, xx, :3].astype(np.float64) * keep + ol * (1.0 - keep)
                        out[y, x] = (*rgb.astype(np.uint8), 255)
                    else:
                        out[y, x] = color
                    break
    return out


def save_sheet(frames, path, cols=None):
    """frames: list of HxWx4 arrays (same size) -> horizontal strip or grid."""
    fh, fw = frames[0].shape[:2]
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = np.zeros((rows * fh, cols * fw, 4), dtype=np.uint8)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        sheet[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw] = f
    Image.fromarray(sheet).save(path)


def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
