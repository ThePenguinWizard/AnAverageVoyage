"""Cuts a UI sheet (art on a transparent or plain white background) into one transparent PNG per element.

Runs inside Blender's bundled Python (it has numpy and can read .webp); no other installs needed:

    blender --background --factory-startup --python tools/ui/cut_sheet.py -- SHEET OUT_DIR [--min 40] [--gap 6] [--clean 0.6]

Each separate piece of art (pixels that are not near-white, grouped when they are closer than --gap pixels)
becomes OUT_DIR/<sheet>_<n>.png, cropped to its bounds with a small margin. The white around and between the
art becomes transparent: only white that connects to the crop's edge is removed, so white or cream inside the
art stays. A contact sheet of the crops' boxes is printed so they can be matched up by position.
"""

import os
import sys
from collections import deque

import bpy
import numpy as np


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    px = px[::-1]  # Blender stores rows bottom-up
    bpy.data.images.remove(img)
    return px


def save(px, path):
    h, w = px.shape[:2]
    img = bpy.data.images.new("out", w, h, alpha=True)
    img.pixels[:] = px[::-1].ravel().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def whiteish(px):
    rgb = px[..., :3]
    return (rgb.min(axis=2) > 0.90) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 0.06)


def components(mask, gap):
    """Bounding boxes of groups of True pixels, merged when closer than `gap` (works on a downscaled grid)."""
    s = max(1, gap)
    h, w = mask.shape
    gh, gw = (h + s - 1) // s, (w + s - 1) // s
    grid = np.zeros((gh, gw), dtype=bool)
    ys, xs = np.nonzero(mask)
    grid[ys // s, xs // s] = True
    seen = np.zeros_like(grid)
    boxes = []
    for y0 in range(gh):
        for x0 in range(gw):
            if not grid[y0, x0] or seen[y0, x0]:
                continue
            q = deque([(y0, x0)])
            seen[y0, x0] = True
            y1 = y2 = y0
            x1 = x2 = x0
            while q:
                y, x = q.popleft()
                y1, y2, x1, x2 = min(y1, y), max(y2, y), min(x1, x), max(x2, x)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < gh and 0 <= nx < gw and grid[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
            boxes.append((y1 * s, min(h, (y2 + 1) * s), x1 * s, min(w, (x2 + 1) * s)))
    return boxes


def clear_outside_white(crop):
    """Makes the near-white region connected to the crop's border transparent."""
    h, w = crop.shape[:2]
    white = whiteish(crop)
    out = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white[y, x] and not out[y, x]:
                out[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if white[y, x] and not out[y, x]:
                out[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    crop = crop.copy()
    crop[out, 3] = 0.0
    # soften the cut: pixels next to removed white that are light keep partial alpha
    edge = np.zeros_like(out)
    edge[1:, :] |= out[:-1, :]
    edge[:-1, :] |= out[1:, :]
    edge[:, 1:] |= out[:, :-1]
    edge[:, :-1] |= out[:, 1:]
    edge &= ~out
    light = crop[..., :3].min(axis=2)
    soft = edge & (light > 0.75)
    crop[soft, 3] = np.clip((1.0 - light[soft]) / 0.25, 0.2, 1.0)
    return crop


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    sheet, out_dir = args[0], args[1]
    min_size = int(args[args.index("--min") + 1]) if "--min" in args else 40
    gap = int(args[args.index("--gap") + 1]) if "--gap" in args else 6
    os.makedirs(out_dir, exist_ok=True)
    px = load(sheet)
    if "--clean" in args:
        # Drop the faint glow / haze some generated sheets leave around their pieces: anything fainter than
        # this alpha becomes fully transparent.
        cutoff = float(args[args.index("--clean") + 1])
        faint = px[..., 3] < cutoff
        px[faint] = 0.0
    h, w = px.shape[:2]
    # A sheet that already has a transparent background is split on alpha alone (so white art is kept); art on a
    # plain white background is split on "not near-white".
    transparent_sheet = float((px[..., 3] < 0.1).mean()) > 0.2
    mask = (px[..., 3] > 0.1) if transparent_sheet else ~whiteish(px)
    stem = os.path.splitext(os.path.basename(sheet))[0]
    boxes = [b for b in components(mask, gap) if (b[1] - b[0]) >= min_size and (b[3] - b[2]) >= min_size]
    boxes.sort(key=lambda b: (b[0] // 60, b[2]))
    for i, (y1, y2, x1, x2) in enumerate(boxes, 1):
        m = 4
        y1, y2, x1, x2 = max(0, y1 - m), min(h, y2 + m), max(0, x1 - m), min(w, x2 + m)
        crop = px[y1:y2, x1:x2] if transparent_sheet else clear_outside_white(px[y1:y2, x1:x2])
        name = "%s_%02d.png" % (stem, i)
        save(crop, os.path.join(out_dir, name))
        print("[cut] %s  x=%d y=%d  %dx%d" % (name, x1, y1, x2 - x1, y2 - y1))
    print("[cut] %d pieces from %dx%d sheet" % (len(boxes), w, h))


main()
