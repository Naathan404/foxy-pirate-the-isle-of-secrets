"""Builds the sand-dust puff atlas used by Foxy's running dust (run_dust_effect.tscn).

Usage (from the project root):
    python tools/vfx/make_run_dust_puffs.py

The four hand-drawn smoke puffs in assets/sprites/effects/smoke/ are dark brown with an ink
outline. Vertex colour can only darken a texture, so this repaints them in light sand-dust
colours (the outline kept, but softened to warm brown so the dust stays light on sand) and
shrinks them into one 4-frame strip. Each puff sits on the bottom edge of its frame: the
particle quad pivots there, so the dust rises from the ground instead of being cut by it.
"""

from PIL import Image

SMOKE = "assets/sprites/effects/smoke/smoke_0{}.png"
# (source, mirrored). smoke_03 is a tall column that reads as a spike at dust size, so the
# round smoke_04 is used twice instead, once mirrored.
SOURCES = [(SMOKE.format(1), False), (SMOKE.format(2), False), (SMOKE.format(4), True),
           (SMOKE.format(4), False)]
OUTPUT = "assets/sprites/effects/run_dust_puffs.png"
FRAME = 128
# Free space kept around each puff inside its frame, in output pixels.
MARGIN = 4

# Source luminance: ink outline below OUTLINE_LUMA, painted body from BODY_DARK to BODY_LIGHT.
OUTLINE_LUMA = 33.0
BODY_DARK = 38.0
BODY_LIGHT = 95.0

OUTLINE = (156, 122, 96)
SHADOW = (214, 184, 148)
MID = (238, 220, 190)
LIGHT = (253, 246, 230)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def body_colour(t):
    return lerp(SHADOW, MID, t * 2.0) if t < 0.5 else lerp(MID, LIGHT, (t - 0.5) * 2.0)


def repaint(image):
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            luma = 0.3 * r + 0.59 * g + 0.11 * b
            if luma < OUTLINE_LUMA:
                colour = OUTLINE
            else:
                t = min(max((luma - BODY_DARK) / (BODY_LIGHT - BODY_DARK), 0.0), 1.0)
                colour = body_colour(t)
            pixels[x, y] = colour + (a,)
    return image


def fit_to_frame(image):
    image = image.crop(image.getbbox())
    room = FRAME - 2 * MARGIN
    scale = room / max(image.size)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    # Shrink first: repainting the full-size source would take far longer for the same result.
    image = image.resize(size, Image.LANCZOS)
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.alpha_composite(image, ((FRAME - size[0]) // 2, FRAME - MARGIN - size[1]))
    return frame


def main():
    strip = Image.new("RGBA", (FRAME * len(SOURCES), FRAME), (0, 0, 0, 0))
    for index, (path, mirrored) in enumerate(SOURCES):
        frame = repaint(fit_to_frame(Image.open(path)))
        if mirrored:
            frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
        strip.alpha_composite(frame, (index * FRAME, 0))
    strip.save(OUTPUT, optimize=True)
    print("wrote", OUTPUT, strip.size)


if __name__ == "__main__":
    main()
