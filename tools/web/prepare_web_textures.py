"""Shrinks texture imports for the Web export so every file fits the itch.io limit.

Run only in a throwaway checkout (CI) after the Windows export: it rewrites `.import` files,
and Godot must import again before the Web export. The Windows build keeps the original
settings.

- Lossless textures (compress/mode=0) become lossy WebP.
- VRAM-compressed textures (compress/mode=2, S3TC on the Web) become Basis Universal, which
  stays compressed on the GPU and takes far less space in the pack.
- Basis Universal textures (compress/mode=4) get rate-distortion optimisation (RDO), which
  makes them compress better.
- Data textures stay lossless: lossy noise would move the shoreline in the water shader.

Usage: python tools/web/prepare_web_textures.py [project_dir]
"""
import pathlib
import re
import sys

LOSSY_QUALITY = "0.85"
BASIS_RDO_QUALITY_LOSS = "2.0"
# Distance fields read by shaders as data.
KEEP_LOSSLESS_SUFFIXES = ("_shore.png",)
RASTER_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp")


def _set_param(text: str, key: str, value: str) -> str:
    pattern = re.compile(r"^" + re.escape(key) + r"=.*$", re.MULTILINE)
    if pattern.search(text):
        return pattern.sub(key + "=" + value, text)
    return text.rstrip("\n") + "\n" + key + "=" + value + "\n"


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    lossy = basis = 0
    for path in root.rglob("*.import"):
        if ".godot" in path.parts or ".git" in path.parts:
            continue
        source = path.name[: -len(".import")].lower()
        text = path.read_text(encoding="utf-8")
        if 'importer="texture"' not in text:
            continue
        if "compress/mode=0" in text:
            if not source.endswith(RASTER_SUFFIXES) or source.endswith(KEEP_LOSSLESS_SUFFIXES):
                continue
            text = _set_param(text, "compress/mode", "1")
            text = _set_param(text, "compress/lossy_quality", LOSSY_QUALITY)
            lossy += 1
        elif "compress/mode=2" in text or "compress/mode=4" in text:
            text = _set_param(text, "compress/mode", "4")
            text = _set_param(text, "compress/rdo_quality_loss", BASIS_RDO_QUALITY_LOSS)
            basis += 1
        else:
            continue
        path.write_text(text, encoding="utf-8", newline="\n")
    print("Web textures: %d lossless -> lossy WebP, %d Basis Universal with RDO" % (lossy, basis))


if __name__ == "__main__":
    main()
