"""Paints the Coral Valley rope-fence art used by RoomEdgeFence.

Usage (from the project root):
    python .claude/skills/coral-valley-room-art/scripts/make_fence_post.py

Writes three driftwood stake variants (fence_post_1..3.png) and a tiling twisted-rope texture
(fence_rope.png) under assets/sprites/biomes/coral_valley/. The stakes use the prop palette and
dark ink outline of the grapple post and the wood log, but no glass float: a float is the cue for a
hookable post. The foot of each stake sits on the bottom edge so the sprite pivots there; the rope
lashing sits at TIE_RATIO of the image height from the bottom, the height RoomEdgeFence ties its
ropes to (keep the two in sync).
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = "assets/sprites/biomes/coral_valley/"
W, H = 192, 448
S = 3  # supersampling
TIE_RATIO = 0.66

INK = (54, 34, 38)
WOOD_SHADOW = (104, 74, 62)
WOOD_DARK = (150, 112, 88)
WOOD_MID = (196, 160, 124)
WOOD_LIGHT = (238, 216, 184)
END_GRAIN = (226, 196, 152)
END_RING = (178, 136, 98)
WOOD_WET = (110, 82, 70)
ROPE = (214, 178, 124)
ROPE_DARK = (150, 114, 76)
ROPE_LIGHT = (242, 218, 170)
BARNACLE = (222, 220, 208)
BARNACLE_DARK = (138, 136, 130)
ALGAE = (94, 138, 74)
ALGAE_LIGHT = (146, 184, 96)
SHELL = (246, 166, 146)
SHELL_LIGHT = (255, 224, 206)
OUTLINE = 6 * S

# Per variant: height share, half width at foot / top, lean (px), top cut slope.
VARIANTS = [
    {"height": 0.93, "foot": 46, "top": 38, "lean": 6, "slope": 0.18, "seed": 4},
    {"height": 0.90, "foot": 48, "top": 41, "lean": -7, "slope": -0.12, "seed": 11},
    {"height": 0.87, "foot": 44, "top": 37, "lean": 3, "slope": 0.28, "seed": 23},
]


def ink(draw_fn, img, width):
    """Draws a shape twice: a wider ink pass, then the colour pass from the caller."""
    d = ImageDraw.Draw(img)
    draw_fn(d, INK + (255,), width + OUTLINE)


def stake(variant):
    v = VARIANTS[variant]
    rng = np.random.default_rng(v["seed"])
    size = (W * S, H * S)
    cx = W * S / 2
    bottom = H * S - 4 * S
    top = bottom - (bottom - 24 * S) * v["height"]
    foot_half, top_half, lean = v["foot"] * S, v["top"] * S, v["lean"] * S

    # Row edges of a slightly crooked, tapering stake.
    rows = np.arange(size[1])
    t = np.clip((rows - top) / (bottom - top), 0.0, 1.0)
    wobble = np.interp(rows, np.linspace(0, size[1], 9), rng.normal(0, 1.4 * S, 9))
    center = cx + lean * np.sin((1.0 - t) * math.pi * 0.8) + wobble
    half = top_half + (foot_half - top_half) * t
    xs = np.arange(size[0])[None, :]
    left, right = (center - half)[:, None], (center + half)[:, None]
    # Sloped, slightly jagged top cut.
    cut = top + v["slope"] * (xs - cx) + 2.5 * S * np.sin(xs / (5.0 * S))
    body = (xs >= left) & (xs <= right) & (rows[:, None] >= cut) & (rows[:, None] <= bottom)

    # Three-tone, left-lit cylinder shading.
    u = np.clip((xs - left) / np.maximum(right - left, 1), 0, 1)
    light = np.cos((u - 0.3) * math.pi) * 0.5 + 0.5
    tones = np.array([WOOD_SHADOW, WOOD_DARK, WOOD_MID, WOOD_LIGHT], float)
    level = np.clip(light * 2.75, 0, 2.999)
    lo = np.floor(level).astype(int)
    frac = (level - lo)[..., None]
    frac = np.clip((frac - 0.35) * 3.0, 0, 1)  # hard cel steps with a short blend
    color = tones[lo] * (1 - frac) + tones[np.minimum(lo + 1, 3)] * frac
    rgba = np.zeros(size[::-1] + (4,), np.uint8)
    rgba[..., :3] = color.astype(np.uint8)
    rgba[..., 3] = np.where(body, 255, 0)
    img = Image.fromarray(rgba, "RGBA")
    body_mask = Image.fromarray((body * 255).astype(np.uint8), "L")

    # Grain, darker bands and a knot, clipped to the body.
    detail = Image.new("RGBA", size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(detail)
    span = bottom - top
    for _ in range(11):
        gx = cx + rng.uniform(-0.75, 0.75) * foot_half
        y0 = top + rng.uniform(0.05, 0.6) * span
        length = rng.uniform(0.18, 0.45) * span
        pts = [(gx + 3 * S * math.sin(k * 0.6 + gx), y0 + k * 7 * S) for k in range(int(length // (7 * S)))]
        if len(pts) > 1:
            dd.line(pts, fill=WOOD_SHADOW + (200,), width=2 * S)
    for k in range(2):
        by = top + span * (0.32 + 0.38 * k) + rng.uniform(-10, 10) * S
        dd.line([(0, by), (size[0], by - 6 * S)], fill=WOOD_DARK + (140,), width=7 * S)
    kx, ky = cx + rng.uniform(-0.3, 0.1) * foot_half, top + span * rng.uniform(0.45, 0.55)
    dd.ellipse([kx - 9 * S, ky - 6 * S, kx + 9 * S, ky + 6 * S], fill=INK + (255,))
    dd.ellipse([kx - 5 * S, ky - 3 * S, kx + 5 * S, ky + 3 * S], fill=WOOD_SHADOW + (255,))
    dd.line([(cx - foot_half * 0.5, top + 26 * S), (cx - foot_half * 0.56, bottom - 70 * S)],
            fill=WOOD_LIGHT + (230,), width=5 * S)
    # Damp foot.
    dd.rectangle([0, bottom - 30 * S, size[0], bottom], fill=WOOD_WET + (255,))
    dd.line([(0, bottom - 30 * S), (size[0], bottom - 34 * S)], fill=INK + (255,), width=3 * S)
    img.paste(detail, (0, 0), Image.composite(detail.getchannel("A"), Image.new("L", size, 0), body_mask))

    # End grain on the cut, visible from the tilted camera.
    face = Image.new("RGBA", size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(face)
    ftop = float(np.min(cut[0, int(cx - top_half):int(cx + top_half)]))
    fcx = float(center[int(top)])
    fd.ellipse([fcx - top_half, ftop - 10 * S, fcx + top_half, ftop + 22 * S], fill=END_GRAIN + (255,))
    for r in (0.65, 0.35):
        fd.ellipse([fcx - top_half * r, ftop + 6 * S - 16 * S * r, fcx + top_half * r, ftop + 6 * S + 16 * S * r],
                   outline=END_RING + (255,), width=2 * S)
    fd.line([(fcx - 4 * S, ftop), (fcx + 8 * S, ftop + 16 * S)], fill=INK + (255,), width=2 * S)
    img.alpha_composite(face)
    body_mask = Image.fromarray(np.maximum(np.array(body_mask), np.array(face.getchannel("A"))), "L")

    # Ink outline: the silhouette grown by OUTLINE, under everything.
    outline = body_mask.filter(ImageFilter.MaxFilter(OUTLINE * 2 + 1))
    base = Image.new("RGBA", size, INK + (0,))
    base.putalpha(outline)
    base.alpha_composite(img)
    img = base
    d = ImageDraw.Draw(img)

    if variant == 1:
        # Barnacles and an algae patch near the foot.
        for _ in range(8):
            bx = cx + rng.uniform(-0.85, 0.85) * foot_half
            by = bottom - rng.uniform(12, 64) * S
            r = rng.uniform(6, 11) * S
            d.ellipse([bx - r - 3 * S, by - r - 3 * S, bx + r + 3 * S, by + r + 3 * S], fill=INK)
            d.ellipse([bx - r, by - r, bx + r, by + r], fill=BARNACLE)
            d.ellipse([bx - r * 0.4, by - r * 0.5, bx + r * 0.4, by + r * 0.3], fill=BARNACLE_DARK)
        for _ in range(5):
            ax = cx + rng.uniform(-0.8, 0.6) * foot_half
            ay = bottom - rng.uniform(40, 110) * S
            d.ellipse([ax - 10 * S, ay - 6 * S, ax + 10 * S, ay + 6 * S], fill=ALGAE)
            d.ellipse([ax - 5 * S, ay - 4 * S, ax + 3 * S, ay], fill=ALGAE_LIGHT)

    # Rope lashing: two diagonal wraps and a frayed loose end.
    tie_y = H * S * (1.0 - TIE_RATIO)
    tcx = float(center[int(tie_y)])
    reach = float(half[int(tie_y)]) + 7 * S
    for k in (-1, 1):
        y = tie_y + k * 11 * S
        a, b = (tcx - reach, y + 9 * S), (tcx + reach, y - 9 * S)
        d.line([a, b], fill=INK, width=22 * S)
        d.line([a, b], fill=ROPE, width=13 * S)
        for j in range(10):
            sx = a[0] + (b[0] - a[0]) * (j + 0.5) / 10
            sy = a[1] + (b[1] - a[1]) * (j + 0.5) / 10
            d.line([(sx - 3 * S, sy + 5 * S), (sx + 4 * S, sy - 5 * S)], fill=ROPE_DARK, width=3 * S)
        d.line([(a[0] + 10 * S, a[1] - 4 * S), (b[0] - 10 * S, b[1] - 4 * S)], fill=ROPE_LIGHT, width=2 * S)
    end = [(tcx + reach - 6 * S, tie_y + 8 * S), (tcx + reach + 8 * S, tie_y + 40 * S),
           (tcx + reach + 2 * S, tie_y + 66 * S)]
    d.line(end, fill=INK, width=13 * S, joint="curve")
    d.line(end, fill=ROPE, width=6 * S, joint="curve")
    for k in range(3):
        fx = end[-1][0] + (k - 1) * 4 * S
        d.line([(fx, end[-1][1]), (fx + (k - 1) * 3 * S, end[-1][1] + 12 * S)], fill=INK, width=3 * S)

    if variant == 2:
        # A pink scallop tied under the lashing.
        sx, sy, r = tcx - reach * 0.35, tie_y + 50 * S, 19 * S
        d.line([(sx, tie_y + 12 * S), (sx, sy - r * 0.6)], fill=INK, width=7 * S)
        d.line([(sx, tie_y + 12 * S), (sx, sy - r * 0.6)], fill=ROPE, width=3 * S)
        fan = [(sx, sy + r * 0.85)] + [
            (sx - math.cos(math.pi * (0.12 + 0.76 * k / 8)) * r, sy - math.sin(math.pi * (0.12 + 0.76 * k / 8)) * r)
            for k in range(9)
        ]
        d.polygon(fan, fill=INK)
        d.polygon([(sx + (x - sx) * 0.8, sy + (y - sy) * 0.8 + 2 * S) for x, y in fan], fill=SHELL)
        for k in range(5):
            ang = math.pi * (0.22 + 0.56 * k / 4)
            d.line([(sx, sy + r * 0.6), (sx - math.cos(ang) * r * 0.7, sy - math.sin(ang) * r * 0.7)],
                   fill=SHELL_LIGHT, width=2 * S)

    img = img.resize((W, H), Image.LANCZOS)
    alpha = np.array(img.getchannel("A"))
    img.putalpha(Image.fromarray(np.where(alpha > 96, 255, 0).astype(np.uint8)))
    path = OUT_DIR + "fence_post_%d.png" % (variant + 1)
    img.save(path, optimize=True)
    print("wrote", path, img.size)


def rope():
    """Tiling twisted-rope strip: u runs along the rope, v around it."""
    w, h = 128, 32
    img = Image.new("RGBA", (w * S, h * S), ROPE + (255,))
    d = ImageDraw.Draw(img)
    for k in range(-4, 12):
        x = k * 16 * S
        d.polygon([(x, h * S), (x + 9 * S, h * S), (x + 25 * S, 0), (x + 16 * S, 0)], fill=ROPE_DARK)
        d.line([(x + 12 * S, h * S), (x + 28 * S, 0)], fill=ROPE_LIGHT, width=2 * S)
    img = img.resize((w, h), Image.LANCZOS)
    path = OUT_DIR + "fence_rope.png"
    img.save(path, optimize=True)
    print("wrote", path, img.size)


def main():
    for variant in range(len(VARIANTS)):
        stake(variant)
    rope()


if __name__ == "__main__":
    main()
