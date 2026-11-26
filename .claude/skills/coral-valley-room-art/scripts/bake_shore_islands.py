"""Bakes one shore distance field covering several islands of a room (paired Quiz rooms).

coral_lagoon.gdshader reads a single shore texture, so a room with two islands needs one field
around both. Run bake_ground.py for each island layout first (each writes its ground), then:

    python .claude/skills/coral-valley-room-art/scripts/bake_shore_islands.py \
        <out_shore.png> <island_a.json> <island_b.json> [...]

It prints the shore_rect for the lagoon material. Values match bake_ground.py: 0 at the sand
edge, 1 at `shore_margin_meters` (8 m) or further.
"""

import json
import sys

import numpy as np
from PIL import Image

MARGIN_METERS = 8.0
WIDTH_PIXELS = 1024
CHUNK = 4096


def island_mask(cfg, qx, qz):
    # The baked ground keeps the silhouette, including split islands, so it is the truth here.
    alpha = np.asarray(Image.open(cfg["out_ground"]).convert("RGBA"))[..., 3] >= 128
    h, w = alpha.shape
    x0, z0, gw, gd = cfg["ground_rect"]
    i = ((qx - x0) / gw * w).astype(int)
    j = ((qz - z0) / gd * h).astype(int)
    inside = (i >= 0) & (i < w) & (j >= 0) & (j < h)
    out = np.zeros(qx.shape, bool)
    out[inside] = alpha[j[inside], i[inside]]
    return out


def main(out_path, layout_paths):
    cfgs = [json.load(open(p, encoding="utf-8")) for p in layout_paths]
    x0 = min(c["ground_rect"][0] for c in cfgs) - MARGIN_METERS
    z0 = min(c["ground_rect"][1] for c in cfgs) - MARGIN_METERS
    x1 = max(c["ground_rect"][0] + c["ground_rect"][2] for c in cfgs) + MARGIN_METERS
    z1 = max(c["ground_rect"][1] + c["ground_rect"][3] for c in cfgs) + MARGIN_METERS
    sw, sd = x1 - x0, z1 - z0
    width = WIDTH_PIXELS
    height = int(round(width * sd / sw))
    qx = (x0 + (np.arange(width, dtype=np.float32) + 0.5) / width * sw)[None, :].repeat(height, 0)
    qz = (z0 + (np.arange(height, dtype=np.float32) + 0.5) / height * sd)[:, None].repeat(width, 1)

    land = np.zeros((height, width), bool)
    for cfg in cfgs:
        land |= island_mask(cfg, qx, qz)
    edge = land & ~(np.roll(land, 1, 0) & np.roll(land, -1, 0)
                    & np.roll(land, 1, 1) & np.roll(land, -1, 1))
    ey, ex = np.nonzero(edge)
    points = np.stack([qx[ey, ex], qz[ey, ex]], 1)

    flat = np.stack([qx.ravel(), qz.ravel()], 1)
    dist = np.empty(len(flat), np.float32)
    for start in range(0, len(flat), CHUNK):
        d = flat[start:start + CHUNK, None, :] - points[None, :, :]
        dist[start:start + CHUNK] = np.sqrt((d * d).sum(-1)).min(1)
    field = np.clip(np.where(land, 0.0, dist.reshape(height, width)) / MARGIN_METERS, 0.0, 1.0)
    Image.fromarray((field * 255).astype(np.uint8), "L").save(out_path, optimize=True)
    print("wrote", out_path, "(%dx%d)" % (width, height))
    print("shore_rect for the lagoon material: Vector4(%g, %g, %g, %g)" % (x0, z0, sw, sd))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
