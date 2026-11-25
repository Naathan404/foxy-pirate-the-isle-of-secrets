"""Paints the Tide Grapple mooring post sprite (assets/sprites/biomes/coral_valley/grapple_post.png).

Usage (from the project root):
    python .claude/skills/coral-valley-room-art/scripts/make_grapple_post.py

A bleached driftwood bollard with an iron cap, rope wraps and a turquoise glass float, drawn in
the Coral Valley palette with the same dark ink outline as the other props. The float is the
player's cue that the post can be hooked. The base of the post sits on the bottom edge of the
image, so the sprite can pivot at its base.
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = "assets/sprites/biomes/coral_valley/grapple_post.png"
W, H = 256, 512
S = 2  # supersampling

INK = (54, 34, 38, 255)
WOOD_DARK = (69, 51, 48, 255)
WOOD_MID = (168, 133, 107, 255)
WOOD_LIGHT = (230, 204, 173, 255)
IRON = (74, 78, 86, 255)
IRON_LIGHT = (128, 136, 146, 255)
ROPE = (206, 170, 120, 255)
ROPE_DARK = (150, 116, 78, 255)
GLASS = (36, 150, 150, 255)
GLASS_LIGHT = (158, 242, 224, 255)
OUTLINE = 5 * S


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def main():
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = W * S // 2
    half = 58 * S
    top, bottom = 120 * S, (H - 18) * S
    cap_h = 34 * S

    # Body: outline first, then a left-lit wooden cylinder.
    d.rounded_rectangle([cx - half - OUTLINE, top - OUTLINE, cx + half + OUTLINE, bottom + OUTLINE],
                        radius=18 * S, fill=INK)
    for x in range(cx - half, cx + half):
        t = (x - (cx - half)) / (2 * half)
        light = math.cos((t - 0.32) * math.pi) * 0.5 + 0.5
        color = lerp(WOOD_DARK, WOOD_LIGHT, 0.25 + 0.6 * light)
        d.line([(x, top), (x, bottom)], fill=color)
    grain = np.random.default_rng(7)
    for _ in range(14):
        x = cx - half + int(grain.random() * 2 * half)
        y0 = top + int(grain.random() * (bottom - top) * 0.6)
        length = int((0.2 + grain.random() * 0.5) * (bottom - top))
        points = [(x + int(4 * S * math.sin(k / 9.0 + x)), y0 + k * 4 * S)
                  for k in range(length // (4 * S)) if y0 + k * 4 * S < bottom - 30 * S]
        if len(points) > 1:
            d.line(points, fill=lerp(WOOD_DARK, WOOD_MID, 0.4), width=2 * S)

    # Iron cap with a rounded top.
    d.ellipse([cx - half - OUTLINE, top - cap_h - OUTLINE, cx + half + OUTLINE, top + cap_h + OUTLINE],
              fill=INK)
    d.ellipse([cx - half, top - cap_h, cx + half, top + cap_h], fill=IRON)
    d.ellipse([cx - half + 10 * S, top - cap_h + 6 * S, cx + 10 * S, top + 2 * S], fill=IRON_LIGHT)
    d.rectangle([cx - half, top + 8 * S, cx + half, top + 30 * S], fill=IRON)
    d.line([(cx - half, top + 31 * S), (cx + half, top + 31 * S)], fill=INK, width=3 * S)
    for k in range(5):
        rx = cx - half + 14 * S + k * 22 * S
        d.ellipse([rx - 4 * S, top + 16 * S, rx + 4 * S, top + 24 * S], fill=IRON_LIGHT)

    # Rope: three diagonal wraps around the middle of the post.
    for k in range(3):
        y = int(top + (bottom - top) * (0.42 + k * 0.1))
        d.line([(cx - half - 4 * S, y + 12 * S), (cx + half + 4 * S, y - 12 * S)], fill=INK,
               width=24 * S)
        d.line([(cx - half - 2 * S, y + 12 * S), (cx + half + 2 * S, y - 12 * S)], fill=ROPE,
               width=16 * S)
        for j in range(8):
            sx = cx - half + j * (2 * half) // 8
            d.line([(sx, y + 10 * S - j * 3 * S), (sx + 8 * S, y + 2 * S - j * 3 * S)],
                   fill=ROPE_DARK, width=3 * S)

    # Glass float hanging from the rope on the right: the "you can hook this" cue.
    fx, fy, fr = cx + half + 16 * S, int(top + (bottom - top) * 0.62), 30 * S
    d.line([(cx + half - 6 * S, int(top + (bottom - top) * 0.5)), (fx, fy - fr)], fill=INK,
           width=8 * S)
    d.line([(cx + half - 6 * S, int(top + (bottom - top) * 0.5)), (fx, fy - fr)], fill=ROPE,
           width=4 * S)
    d.ellipse([fx - fr - OUTLINE, fy - fr - OUTLINE, fx + fr + OUTLINE, fy + fr + OUTLINE], fill=INK)
    d.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=GLASS)
    d.ellipse([fx - fr + 8 * S, fy - fr + 8 * S, fx - 2 * S, fy - 4 * S], fill=GLASS_LIGHT)
    for k in range(-1, 2):
        d.arc([fx - fr, fy - fr + k * 14 * S, fx + fr, fy + fr + k * 14 * S], 200, 340, fill=ROPE_DARK,
              width=3 * S)

    # Damp foot where the post meets the sand.
    d.rectangle([cx - half, bottom - 26 * S, cx + half, bottom], fill=lerp(WOOD_DARK, WOOD_MID, 0.3))
    d.line([(cx - half, bottom - 26 * S), (cx + half, bottom - 26 * S)], fill=INK, width=3 * S)

    img = img.resize((W, H), Image.LANCZOS)
    alpha = img.getchannel("A").filter(ImageFilter.MaxFilter(1))
    img.putalpha(alpha)
    img.save(OUT, optimize=True)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
