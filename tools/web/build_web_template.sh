#!/usr/bin/env bash
# Builds the Godot Web export template (GDExtension support, no threads) with the patches in
# tools/web/godot_patches applied. Stock 4.7.2 never uploads mesh indices on WebGL2, which
# breaks spine-godot meshes (https://github.com/godotengine/godot/issues/124726).
#
# Needs git, python3 with SCons, and an active Emscripten SDK (4.0.11 matches Godot 4.7.2).
#
# Usage: tools/web/build_web_template.sh <godot-tag> <output-zip> [work-dir]
# Example: tools/web/build_web_template.sh 4.7.2-stable build/web_template.zip
set -euo pipefail

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <godot-tag> <output-zip> [work-dir]" >&2
	exit 2
fi

GODOT_TAG="$1"
OUTPUT_ZIP="$(realpath -m "$2")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/godot_patches"
WORK_DIR="$(realpath -m "${3:-$(mktemp -d)}")"

command -v emcc > /dev/null || { echo "emcc not found: activate the Emscripten SDK first." >&2; exit 1; }
command -v scons > /dev/null || { echo "scons not found: pip install scons" >&2; exit 1; }

SOURCE_DIR="$WORK_DIR/godot"
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
	git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"
git reset --hard "$GODOT_TAG" > /dev/null
for patch in "$PATCH_DIR"/*.patch; do
	echo "Applying $(basename "$patch")"
	git apply --check "$patch"
	git apply "$patch"
done

scons platform=web target=template_release dlink_enabled=yes threads=no arch=wasm32 \
	production=yes debug_symbols=no

mkdir -p "$(dirname "$OUTPUT_ZIP")"
# SCons names the zip after the build options (…wasm32.nothreads.dlink.zip); match by pattern.
built_zips=(bin/godot.web.template_release.*.zip)
if [[ ${#built_zips[@]} -ne 1 || ! -f "${built_zips[0]}" ]]; then
	echo "Expected exactly one template zip in bin/, found: ${built_zips[*]}" >&2
	exit 1
fi
cp "${built_zips[0]}" "$OUTPUT_ZIP"
ls -la "$OUTPUT_ZIP"
