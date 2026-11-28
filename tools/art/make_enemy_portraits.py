"""Builds the bestiary portraits from the Spine poses rendered by render_enemy_poses.gd.

Usage (from the project root):
    godot --path . -s tools/art/render_enemy_poses.gd -- <poses_dir>
    python tools/art/make_enemy_portraits.py <poses_dir>

Writes assets/sprites/enemies/portraits/<id>.png and elite_<id>.png. A normal portrait is the
Spine pose itself. An elite portrait adds the marks that set it apart: a crimson-and-gold
sunburst behind it, a glowing gold outline round its body, a jewelled gold crown above its
head and a few glints.
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT_DIR = "assets/sprites/enemies/portraits/"
SIZE = 512
# The body's share of the canvas; elites sit smaller and lower to leave room for the crown.
BODY_SHARE = 0.94
ELITE_BODY_SHARE = 0.76
ELITE_BOTTOM_MARGIN = 20
# Where each elite's crown sits, as a share of its body's box: (x centre, y of the crown's
# base), its width and tilt in degrees (positive leans right).
CROWNS = {
    "crab": (0.50, 0.17, 0.27, -6),
    "hermit_crab": (0.74, 0.40, 0.30, 15),
    "barrel": (0.66, 0.17, 0.36, 16),
}
INK = (45, 20, 26, 255)
GOLD = (255, 196, 48, 255)
GOLD_LIGHT = (255, 234, 140, 255)
GOLD_DARK = (196, 128, 24, 255)
RUBY = (214, 40, 58, 255)
RUBY_LIGHT = (255, 130, 130, 255)
GLOW_GOLD = (255, 190, 40)
RAY_RED = (196, 36, 44)
RAY_GOLD = (255, 176, 48)


def load_body(path):
    image = Image.open(path).convert("RGBA")
    return image.crop(image.getbbox())


def place(body, share, bottom_margin=None):
    """The body scaled into the canvas: centred, or resting `bottom_margin` above the bottom."""
    room = int(SIZE * share)
    scale = min(room / body.width, room / body.height)
    size = (round(body.width * scale), round(body.height * scale))
    resized = body.resize(size, Image.LANCZOS)
    x = (SIZE - size[0]) // 2
    y = (SIZE - size[1]) // 2 if bottom_margin is None else SIZE - bottom_margin - size[1]
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (x, y))
    return canvas, (x, y, size[0], size[1])


def grow(alpha, pixels):
    return alpha.filter(ImageFilter.MaxFilter(pixels * 2 + 1))


def tinted(alpha, colour, opacity=1.0):
    layer = Image.new("RGBA", alpha.size, colour + (0,))
    layer.putalpha(alpha.point(lambda a: int(a * opacity)))
    return layer


def sunburst(centre):
    """Soft rays alternating crimson and gold, fading out towards the edge."""
    scale = 2
    size = SIZE * scale
    rays = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(rays)
    cx, cy = centre[0] * scale, centre[1] * scale
    count = 16
    for index in range(count):
        a0 = 2 * math.pi * index / count
        a1 = a0 + math.pi / count * (1.15 if index % 2 == 0 else 0.7)
        reach = size * (0.62 if index % 2 == 0 else 0.5)
        colour = RAY_RED if index % 2 == 0 else RAY_GOLD
        draw.polygon(
            [(cx, cy),
             (cx + math.cos(a0) * reach, cy + math.sin(a0) * reach),
             (cx + math.cos(a1) * reach, cy + math.sin(a1) * reach)],
            fill=colour + (230,),
        )
    rays = rays.resize((SIZE, SIZE), Image.LANCZOS)
    fade = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(fade).ellipse(
        [centre[0] - 210, centre[1] - 210, centre[0] + 210, centre[1] + 210], fill=255
    )
    fade = fade.filter(ImageFilter.GaussianBlur(34))
    rays.putalpha(ImageChops.multiply(rays.getchannel("A"), fade))
    halo = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(halo).ellipse(
        [centre[0] - 150, centre[1] - 150, centre[0] + 150, centre[1] + 150], fill=210
    )
    halo = halo.filter(ImageFilter.GaussianBlur(40))
    base = tinted(halo, (232, 70, 44))
    base.alpha_composite(rays)
    # Nothing may be cut square at the canvas edge.
    edge = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(edge).ellipse([10, 10, SIZE - 10, SIZE - 10], fill=255)
    edge = edge.filter(ImageFilter.GaussianBlur(10))
    base.putalpha(ImageChops.multiply(base.getchannel("A"), edge))
    return base


def aura(body_layer):
    """A soft gold glow, then a crisp gold line and an ink edge hugging the silhouette."""
    alpha = body_layer.getchannel("A").point(lambda a: 255 if a > 90 else 0)
    glow = grow(alpha, 11).filter(ImageFilter.GaussianBlur(11))
    layer = tinted(glow, GLOW_GOLD, 0.95)
    for pixels, colour in ((8, INK[:3]), (6, GOLD[:3]), (2, GOLD_LIGHT[:3])):
        layer.alpha_composite(tinted(grow(alpha, pixels).filter(ImageFilter.GaussianBlur(0.8)),
                                     colour))
    return layer


def crown(width):
    """A three-point pirate-king crown with a ruby, drawn with the props' ink outline."""
    s = 4
    image = Image.new("RGBA", (200 * s, 150 * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def scaled(points):
        return [(x * s, y * s) for x, y in points]

    outline = scaled([(24, 128), (14, 40), (62, 76), (100, 14), (138, 76), (186, 40), (176, 128)])
    draw.polygon(outline, fill=GOLD)
    # Lit left half and a shaded band at the base.
    draw.polygon(scaled([(28, 118), (22, 56), (62, 88), (100, 30), (100, 118)]), fill=GOLD_LIGHT)
    draw.polygon(scaled([(24, 104), (176, 104), (176, 128), (24, 128)]), fill=GOLD_DARK)
    draw.line(outline + [outline[0]], fill=INK, width=11 * s, joint="curve")
    draw.line(scaled([(24, 103), (176, 103)]), fill=INK, width=6 * s)
    for x, y, r in [(14, 38, 12), (100, 15, 13), (186, 38, 12)]:
        draw.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s], fill=GOLD_LIGHT,
                     outline=INK, width=7 * s)
    gem = scaled([(100, 58), (121, 82), (100, 104), (79, 82)])
    draw.polygon(gem, fill=RUBY)
    draw.polygon(scaled([(100, 64), (87, 80), (100, 82)]), fill=RUBY_LIGHT)
    draw.line(gem + [gem[0]], fill=INK, width=6 * s, joint="curve")
    for x in (50, 150):
        draw.ellipse([(x - 9) * s, 108 * s, (x + 9) * s, 124 * s], fill=RUBY, outline=INK,
                     width=4 * s)
    return image.resize((width, round(width * 150 / 200)), Image.LANCZOS)


def glint(draw, x, y, r):
    points = []
    for index in range(8):
        angle = math.pi * index / 4 - math.pi / 2
        reach = r if index % 2 == 0 else r * 0.28
        points.append((x + math.cos(angle) * reach, y + math.sin(angle) * reach))
    draw.polygon(points, fill=GOLD_LIGHT, outline=INK)


def elite(body, key):
    layer, (x, y, w, h) = place(body, ELITE_BODY_SHARE, ELITE_BOTTOM_MARGIN)
    canvas = sunburst((x + w // 2, y + int(h * 0.48)))
    canvas.alpha_composite(aura(layer))
    canvas.alpha_composite(layer)
    cx_share, base_share, width_share, tilt = CROWNS[key]
    art = crown(round(w * width_share))
    # PIL turns anticlockwise for positive angles.
    turned = art.rotate(-tilt, resample=Image.BICUBIC, expand=True)
    left = round(x + w * cx_share - turned.width / 2)
    top = round(y + h * base_share - turned.height * 0.82)
    left = min(max(left, 6), SIZE - turned.width - 6)
    top = max(top, 6)
    shadow_alpha = turned.getchannel("A").filter(ImageFilter.GaussianBlur(7))
    canvas.alpha_composite(tinted(shadow_alpha, (40, 8, 12), 0.7), (left + 4, top + 9))
    canvas.alpha_composite(turned, (left, top))
    draw = ImageDraw.Draw(canvas)
    for gx, gy, r in [(64, 150, 24), (446, 214, 19), (418, 96, 13), (86, 372, 14)]:
        glint(draw, gx, gy, r)
    return canvas


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    poses = sys.argv[1].rstrip("/\\") + "/"
    os.makedirs(OUT_DIR, exist_ok=True)
    for key in CROWNS:
        body = load_body(poses + key + ".png")
        place(body, BODY_SHARE)[0].save(OUT_DIR + key + ".png", optimize=True)
        elite(body, key).save(OUT_DIR + "elite_" + key + ".png", optimize=True)
        print("wrote", key, "and elite_" + key)


if __name__ == "__main__":
    main()
