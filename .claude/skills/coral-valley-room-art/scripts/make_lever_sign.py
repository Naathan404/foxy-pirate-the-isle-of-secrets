"""Paints the small plank signs that tell what a route lever does (room_04 orbit puzzle).

Usage (from the project root):
    python .claude/skills/coral-valley-room-art/scripts/make_lever_sign.py

Writes lever_sign_plus3.png (orange clockwise arrow) and lever_sign_minus2.png (teal
counterclockwise arrow) under assets/sprites/biomes/coral_valley/. "Clockwise" is as seen from
the gameplay camera, the order the orbit platform's stops follow (E, SE, S, SW, W, NW, N, NE).
The step count is written by hand in Patrick Hand; the two arrow colours keep the levers apart
even before the number is read.
"""

import math

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = "assets/sprites/biomes/coral_valley/"
FONT = "assets/fonts/PatrickHand-Regular.ttf"
W, H = 256, 160
S = 3

INK = (54, 34, 38, 255)
PLANK = (214, 180, 140, 255)
PLANK_LIGHT = (238, 214, 180, 255)
PLANK_DARK = (160, 122, 94, 255)
ROPE = (214, 178, 124, 255)
SIGNS = [
    ("lever_sign_plus3.png", "+3", True, (238, 138, 52, 255)),
    ("lever_sign_minus2.png", "−2", False, (54, 168, 164, 255)),
]


def arrow(d, cx, cy, r, clockwise, color):
    """A three-quarter ring with a head, drawn ink first then colour."""
    start, end = (200, 470) if clockwise else (70, 340)
    box = [cx - r, cy - r, cx + r, cy + r]
    tip_angle = math.radians(end if clockwise else start)
    tangent = 1 if clockwise else -1
    tx, ty = cx + math.cos(tip_angle) * r, cy + math.sin(tip_angle) * r
    # Direction of travel at the tip (screen y grows downwards).
    dx, dy = -math.sin(tip_angle) * tangent, math.cos(tip_angle) * tangent
    nx, ny = -dy, dx
    head = [(tx + dx * 16 * S, ty + dy * 16 * S), (tx + nx * 14 * S, ty + ny * 14 * S),
            (tx - nx * 14 * S, ty - ny * 14 * S)]
    for width, fill in ((17 * S, INK), (9 * S, color)):
        d.arc(box, start, end, fill=fill, width=width)
    grown = [(tx + (x - tx) * 1.45, ty + (y - ty) * 1.45) for x, y in head]
    d.polygon(grown, fill=INK)
    d.polygon(head, fill=color)


def sign(name, text, clockwise, color):
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Hanging rope loops.
    for x in (70 * S, 186 * S):
        d.line([(x, 34 * S), (x + 10 * S, 6 * S)], fill=INK, width=9 * S)
        d.line([(x, 34 * S), (x + 10 * S, 6 * S)], fill=ROPE, width=4 * S)
    # Plank with an ink outline and two boards.
    body = [12 * S, 28 * S, (W - 12) * S, (H - 10) * S]
    d.rounded_rectangle([body[0] - 6 * S, body[1] - 6 * S, body[2] + 6 * S, body[3] + 6 * S],
                        radius=18 * S, fill=INK)
    d.rounded_rectangle(body, radius=14 * S, fill=PLANK)
    mid = (body[1] + body[3]) // 2
    d.line([(body[0], mid), (body[2], mid)], fill=PLANK_DARK, width=4 * S)
    d.line([(body[0] + 14 * S, body[1] + 10 * S), (body[2] - 30 * S, body[1] + 10 * S)],
           fill=PLANK_LIGHT, width=4 * S)
    for x, y in ((body[0] + 16 * S, body[1] + 16 * S), (body[2] - 16 * S, body[3] - 16 * S)):
        d.ellipse([x - 5 * S, y - 5 * S, x + 5 * S, y + 5 * S], fill=INK)
    font = ImageFont.truetype(FONT, 104 * S)
    d.text((40 * S, mid + 4 * S), text, font=font, fill=INK, anchor="lm")
    arrow(d, (W - 62) * S, mid + 2 * S, 34 * S, clockwise, color)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT_DIR + name, optimize=True)
    print("wrote", OUT_DIR + name, img.size)


def main():
    for entry in SIGNS:
        sign(*entry)


if __name__ == "__main__":
    main()
