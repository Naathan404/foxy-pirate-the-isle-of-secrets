"""Fit native Spine poses into transparent inventory portraits.

Usage (from the project root):
    godot --path . -s tools/art/render_enemy_poses.gd -- <poses_dir>
    python tools/art/make_enemy_portraits.py <poses_dir>

Normal and elite portraits share the game's original ink and colours. Elite combat
poses come from the renderer; no crowns, outlines or backgrounds are added here.
"""

import sys
from pathlib import Path

from PIL import Image

OUT_DIR = Path("assets/sprites/enemies/portraits")
SIZE_PIXELS = 512
BODY_SHARE = 0.94
PORTRAIT_IDS = (
    "crab",
    "hermit_crab",
    "barrel",
    "elite_crab",
    "elite_hermit_crab",
    "elite_barrel",
)


def fit_portrait(path: Path) -> Image.Image:
    """Keep a consistent silhouette size and transparent margin in inventory cells."""
    with Image.open(path) as source:
        body = source.convert("RGBA")
    bounds = body.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Empty portrait pose: {path}")
    body = body.crop(bounds)
    room = int(SIZE_PIXELS * BODY_SHARE)
    scale = min(room / body.width, room / body.height)
    size = (round(body.width * scale), round(body.height * scale))
    body = body.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (SIZE_PIXELS, SIZE_PIXELS))
    offset = ((SIZE_PIXELS - size[0]) // 2, (SIZE_PIXELS - size[1]) // 2)
    canvas.alpha_composite(body, offset)
    return canvas


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    poses = Path(sys.argv[1])
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for portrait_id in PORTRAIT_IDS:
        fit_portrait(poses / f"{portrait_id}.png").save(
            OUT_DIR / f"{portrait_id}.png", optimize=True
        )
        print("wrote", portrait_id)


if __name__ == "__main__":
    main()
