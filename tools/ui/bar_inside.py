"""Makes the inside of a hollow bar frame into two images the same size as the frame:

    blender --background --factory-startup --python tools/ui/bar_inside.py -- FRAME.png OUT_BACK.png OUT_FILL.png

OUT_BACK is the inside filled black (the empty bar behind the fill) and OUT_FILL is the inside filled white (tint it
in-engine and clip its width to show how full the bar is). The inside is the transparent region connected to the
frame's centre pixel.
"""

import sys
from collections import deque

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, out_back, out_fill = args[0], args[1], args[2]
img = bpy.data.images.load(src)
w, h = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
bpy.data.images.remove(img)

open_ = px[..., 3] < 0.5
inside = np.zeros((h, w), dtype=bool)
seed = (h // 2, w // 2)
assert open_[seed], "the frame's centre is not transparent"
q = deque([seed])
inside[seed] = True
while q:
    y, x = q.popleft()
    for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
        if 0 <= ny < h and 0 <= nx < w and open_[ny, nx] and not inside[ny, nx]:
            inside[ny, nx] = True
            q.append((ny, nx))
# grow by 2 px so the fill tucks under the outline's anti-aliased edge
for _ in range(2):
    grown = inside.copy()
    grown[1:, :] |= inside[:-1, :]
    grown[:-1, :] |= inside[1:, :]
    grown[:, 1:] |= inside[:, :-1]
    grown[:, :-1] |= inside[:, 1:]
    inside = grown


def save(color, path):
    out = np.zeros((h, w, 4), dtype=np.float32)
    out[inside] = color
    o = bpy.data.images.new("o", w, h, alpha=True)
    o.pixels[:] = out.ravel().tolist()
    o.filepath_raw = path
    o.file_format = "PNG"
    o.save()
    bpy.data.images.remove(o)


save((0.04, 0.04, 0.04, 1.0), out_back)
save((1.0, 1.0, 1.0, 1.0), out_fill)
print("[bar] inside pixels:", int(inside.sum()), "of", w * h)
