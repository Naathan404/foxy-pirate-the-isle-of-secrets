"""Bakes the awash reef rocks around a wonder room's island(s) for coral_lagoon.gdshader.

Usage (from the project root), after bake_ground.py (it reads the shore field it wrote):
    python .claude/skills/coral-valley-room-art/scripts/bake_reef_rocks.py <layout.json>

Layout keys:
    "reef_rocks": {
        "out": "assets/sprites/biomes/coral_valley/coral_valley_room_XX_rocks.png",
        "count": 60,                # rocks to try to place, grouped in clusters
        "clusters": 12,             # cluster centres along the band (a few become big outcrops)
        "near_meters": 2.5,         # closest a rock may sit to the sand edge
        "far_meters": 7.5,          # furthest (the shore field ends at 8 m)
        "size_meters": [0.5, 1.6],  # rock radius range
        "keep_clear": [[x, z, r]],  # circles left free, e.g. in front of the piers
        "anchors": [[x, z, r]]      # rocks placed exactly, e.g. under pillars standing in the water
    }
The mask covers the same rect as the shore field, so the material needs no extra uniform.
"""

import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
MARGIN = 8.0
FALLOFF_PIXELS = 7


def main(layout_path):
    cfg = json.load(open(layout_path, encoding="utf-8"))
    rocks = cfg["reef_rocks"]
    gx0, gz0, gw, gd = cfg["ground_rect"]
    sx0, sz0, sw, sd = gx0 - MARGIN, gz0 - MARGIN, gw + MARGIN * 2, gd + MARGIN * 2
    shore = np.asarray(Image.open(cfg["out_shore"]).convert("L"), np.float32) / 255.0 * MARGIN
    sh, sw_px = shore.shape
    rng = np.random.default_rng(cfg.get("seed", 1207) + 4242)
    near, far = rocks.get("near_meters", 2.5), rocks.get("far_meters", 7.5)
    small, big = rocks.get("size_meters", [0.5, 1.6])
    clear = rocks.get("keep_clear", [])

    def shore_at(x, z):
        u = int((x - sx0) / sw * sw_px)
        v = int((z - sz0) / sd * sh)
        if not (0 <= u < sw_px and 0 <= v < sh):
            return MARGIN
        return shore[v, u]

    def free(x, z, r):
        d = shore_at(x, z)
        if not (near + r * 0.5 <= d <= far):
            return False
        if any(math.hypot(x - cx, z - cz) < cr + r for cx, cz, cr in clear):
            return False
        return all(math.hypot(x - px, z - pz) >= (r + pr) * 1.1 for px, pz, pr in placed)

    # Rocks gather in clusters around a few centres, the way a reef breaks the surface; a third
    # of the clusters get one big outcrop at their heart.
    placed = [tuple(anchor) for anchor in rocks.get("anchors", [])]
    centres = []
    for _ in range(4000):
        if len(centres) >= rocks.get("clusters", 12):
            break
        x, z = sx0 + rng.random() * sw, sz0 + rng.random() * sd
        if near + 1.0 <= shore_at(x, z) <= far - 0.5 and all(
            math.hypot(x - cx, z - cz) > 6.0 for cx, cz in centres
        ) and not any(math.hypot(x - kx, z - kz) < kr + 2.0 for kx, kz, kr in clear):
            centres.append((x, z))
    for index, (cx, cz) in enumerate(centres):
        if index % 3 == 0 and free(cx, cz, big * 1.6):
            placed.append((cx, cz, big * 1.6))
    for _ in range(rocks.get("count", 60) * 60):
        if len(placed) >= rocks.get("count", 60) or not centres:
            break
        cx, cz = centres[rng.integers(0, len(centres))]
        spread = 1.0 + rng.random() * 3.2
        angle = rng.random() * math.tau
        x, z = cx + math.cos(angle) * spread, cz + math.sin(angle) * spread
        r = small + (big - small) * rng.random() ** 2.2
        if free(x, z, r):
            placed.append((x, z, r))

    scale = SIZE / sw
    height = int(round(SIZE * sd / sw))
    mask = Image.new("L", (SIZE, height), 0)
    draw = ImageDraw.Draw(mask)
    for x, z, r in placed:
        cx, cz = (x - sx0) * scale, (z - sz0) * scale
        n = 14
        phase = rng.random() * math.tau
        stretch = 0.6 + rng.random() * 0.5
        lumps = rng.random(3) * math.tau
        points = []
        for i in range(n):
            t = phase + i / n * math.tau
            k = r * scale * (0.82 + 0.16 * math.sin(t * 2 + lumps[0])
                             + 0.1 * math.sin(t * 3 + lumps[1]) + 0.08 * rng.random())
            points.append((cx + math.cos(t) * k, cz + math.sin(t) * k * stretch))
        draw.polygon(points, fill=255)
    # Soft falloff outside each rock: the shader reads it as the foam collar and ink edge.
    halo = mask.filter(ImageFilter.GaussianBlur(FALLOFF_PIXELS))
    body = np.asarray(mask, np.float32) / 255.0
    soft = np.asarray(halo, np.float32) / 255.0
    field = np.maximum(body * 0.75 + 0.25 * soft, np.minimum(soft * 1.6, 0.6))
    field = np.where(body > 0.5, np.maximum(field, 0.7), field)
    Image.fromarray((np.clip(field, 0, 1) * 255).astype(np.uint8), "L").save(rocks["out"],
                                                                             optimize=True)
    print("wrote", rocks["out"], "with", len(placed), "rocks")


if __name__ == "__main__":
    main(sys.argv[1])
