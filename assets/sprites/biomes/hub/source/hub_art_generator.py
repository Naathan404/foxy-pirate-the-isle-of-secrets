"""Procedural source for the Castaway Cove (Hub) ground textures.

Run from the repository root:
    python assets/sprites/biomes/hub/source/hub_art_generator.py

Outputs (overwritten on every run, same seed gives the same images):
    assets/sprites/biomes/hub/ground/hub_grass_ground.png   seamless, no plants painted in
    assets/sprites/biomes/hub/ground/hub_stone_ground.png   seamless paving slabs

These are original procedural textures in a flat, outlined style. Replace either PNG with
painted art of the same name and the Hub picks it up unchanged. Foliage sprites are painted
by hand and live in assets/sprites/biomes/hub/foliage/; this script does not touch them.
"""

from __future__ import annotations

import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SEED = 7319
GROUND_SIZE_PX = 1024
SUPERSAMPLE = 2

ROOT = Path(__file__).resolve().parents[1]
GROUND_DIR = ROOT / "ground"

OUTLINE = (43, 30, 22, 255)

# The island is cursed: muted olive grass going grey, with withered straw-brown patches.
GRASS_TONES = [
	(62, 70, 46),
	(80, 88, 56),
	(98, 104, 64),
	(116, 116, 72),
]
WITHERED_TONE = (118, 102, 66)
SPECK_LIGHT = (196, 190, 150)
SPECK_DARK = (52, 58, 40)

STONE_BASE = (132, 126, 122)
STONE_MORTAR = (50, 46, 42)
STONE_MOSS = (74, 86, 50)
STONE_DIRT = (66, 56, 44)
# Chance per slab of each kind of damage.
SLAB_MISSING_CHANCE = 0.07
SLAB_CRACK_CHANCE = 0.75
SLAB_SPLIT_CHANCE = 0.22
SLAB_CHIP_CHANCE = 0.5
SLAB_MOSS_CHANCE = 0.5


# --------------------------------------------------------------------------- noise


def periodic_noise(rng: np.random.Generator, size: int, falloff: float) -> np.ndarray:
	"""Tileable noise in [0, 1]: white noise shaped by 1/f^falloff in frequency space."""
	white = rng.standard_normal((size, size))
	spectrum = np.fft.fft2(white)
	fy = np.fft.fftfreq(size)[:, None]
	fx = np.fft.fftfreq(size)[None, :]
	radius = np.sqrt(fx * fx + fy * fy)
	radius[0, 0] = 1.0
	shaped = np.real(np.fft.ifft2(spectrum / radius**falloff))
	shaped -= shaped.min()
	return shaped / shaped.max()


def soft_bands(value: np.ndarray, count: int, softness: float) -> np.ndarray:
	"""Posterize to `count` bands with soft transitions, like flat painted tones."""
	scaled = value * count
	band = np.floor(scaled)
	fraction = scaled - band
	blend = np.clip((fraction - (1.0 - softness)) / softness, 0.0, 1.0)
	return np.clip(band + blend, 0, count - 1)


def palette_lookup(index: np.ndarray, tones: list[tuple[int, int, int]]) -> np.ndarray:
	tones_array = np.array(tones, dtype=np.float64)
	low = np.floor(index).astype(int)
	high = np.clip(low + 1, 0, len(tones) - 1)
	t = (index - low)[..., None]
	return tones_array[low] * (1.0 - t) + tones_array[high] * t


def wrapped_ellipse(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], size: int,
		fill: tuple[int, ...]) -> None:
	"""Draw an ellipse and its copies across the tile edges so the texture stays seamless."""
	for dx in (-size, 0, size):
		for dy in (-size, 0, size):
			draw.ellipse((box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy), fill=fill)


# --------------------------------------------------------------------------- ground


def make_grass_ground(rng: np.random.Generator, prng: random.Random) -> Image.Image:
	size = GROUND_SIZE_PX
	blotches = periodic_noise(rng, size, 1.9)
	detail = periodic_noise(rng, size, 1.4)
	grain = periodic_noise(rng, size, 0.6)
	value = 0.62 * blotches + 0.28 * detail + 0.10 * grain
	value = (value - value.min()) / (value.max() - value.min())
	rgb = palette_lookup(soft_bands(value, len(GRASS_TONES), 0.35), GRASS_TONES)
	# Withered patches: a separate low-frequency field turns parts of the grass to straw.
	withered = periodic_noise(rng, size, 2.1)
	withered_mask = np.clip((withered - 0.62) / 0.08, 0.0, 1.0)[..., None]
	straw = np.array(WITHERED_TONE) * (0.85 + 0.3 * detail)[..., None]
	rgb = rgb * (1.0 - withered_mask * 0.8) + straw * withered_mask * 0.8
	rgb *= (0.97 + 0.06 * grain)[..., None]
	image = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")

	draw = ImageDraw.Draw(image)
	# Pale dew/pebble dots in small clusters and a few dark specks; never blades or leaves.
	for _cluster in range(70):
		cx, cy = prng.uniform(0, size), prng.uniform(0, size)
		for _dot in range(prng.randint(2, 4)):
			x = cx + prng.uniform(-14, 14)
			y = cy + prng.uniform(-6, 6)
			rx, ry = prng.uniform(3.0, 5.0), prng.uniform(1.8, 2.8)
			wrapped_ellipse(draw, (x - rx, y - ry, x + rx, y + ry), size, SPECK_LIGHT)
	for _speck in range(260):
		x, y = prng.uniform(0, size), prng.uniform(0, size)
		r = prng.uniform(1.2, 2.6)
		wrapped_ellipse(draw, (x - r, y - r * 0.6, x + r, y + r * 0.6), size, SPECK_DARK)
	return image


def make_stone_ground(rng: np.random.Generator, prng: random.Random) -> Image.Image:
	size = GROUND_SIZE_PX
	scale = SUPERSAMPLE
	big = size * scale
	mottling = periodic_noise(rng, size, 1.5)
	base = np.empty((size, size, 3))
	base[:] = STONE_MORTAR
	canvas = Image.fromarray(base.astype(np.uint8), "RGB").resize((big, big))
	draw = ImageDraw.Draw(canvas)

	row_heights = _split_length(prng, size, 5, 150, 260)
	gap = 7
	y = 0
	for height in row_heights:
		offset = prng.uniform(0, size)
		for width in _split_length(prng, size, 3, 150, 320):
			# One look per slab; a slab crossing the tile edge is drawn twice with it.
			style_seed = prng.random()
			for dx in (0, -size):
				_draw_slab(draw, random.Random(style_seed),
					(offset + dx, y, offset + dx + width, y + height), gap, scale, size)
			offset = (offset + width) % size
		y += height
	image = canvas.resize((size, size), Image.Resampling.LANCZOS)

	rgb = np.asarray(image, dtype=np.float64)
	rgb *= (0.78 + 0.3 * mottling)[..., None]
	return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def _split_length(prng: random.Random, total: int, minimum_parts: int, low: int,
		high: int) -> list[int]:
	"""Random part lengths in [low, high] that add up to `total` exactly."""
	while True:
		parts: list[int] = []
		remaining = total
		while remaining > high:
			part = prng.randint(low, high)
			parts.append(part)
			remaining -= part
		if remaining >= low and len(parts) + 1 >= minimum_parts:
			parts.append(remaining)
			return parts


def _draw_slab(draw: ImageDraw.ImageDraw, prng: random.Random,
		rect: tuple[float, float, float, float], gap: float, scale: int, size: int) -> None:
	left, top, right, bottom = rect
	shade = prng.uniform(0.74, 1.06)
	tint = prng.uniform(-6, 10)
	color = tuple(int(np.clip(c * shade + tint * (i == 2), 0, 255)) for i, c in enumerate(STONE_BASE))
	light = tuple(min(255, int(c * 1.12)) for c in color)
	dark = tuple(int(c * 0.76) for c in color)
	radius = 14 * scale
	# Decide the damage once so both wrapped copies of a slab look the same.
	damage = {
		"missing": prng.random() < SLAB_MISSING_CHANCE,
		"cracks": prng.randint(1, 2) if prng.random() < SLAB_CRACK_CHANCE else 0,
		"split": prng.random() < SLAB_SPLIT_CHANCE,
		"chips": [prng.randint(0, 3) for _ in range(prng.randint(1, 2))]
		if prng.random() < SLAB_CHIP_CHANCE else [],
		"moss": prng.random() < SLAB_MOSS_CHANCE,
		"seed": prng.random(),
	}
	for dy in (0, size, -size):
		box = [(left + gap) * scale, (top + gap + dy) * scale,
			(right - gap) * scale, (bottom - gap + dy) * scale]
		if box[2] - box[0] < radius * 2 or box[3] - box[1] < radius * 2:
			continue
		if dy != 0 and (box[1] > size * scale or box[3] < 0):
			continue
		detail = random.Random(damage["seed"])
		if damage["missing"]:
			_draw_missing_slab(draw, detail, box, radius, scale)
			continue
		draw.rounded_rectangle(box, radius, fill=OUTLINE[:3])
		inner = [box[0] + 3 * scale, box[1] + 3 * scale, box[2] - 3 * scale, box[3] - 3 * scale]
		draw.rounded_rectangle(inner, radius - 3 * scale, fill=dark)
		draw.rounded_rectangle([inner[0], inner[1], inner[2] - 5 * scale, inner[3] - 6 * scale],
			radius - 4 * scale, fill=light)
		draw.rounded_rectangle([inner[0] + 4 * scale, inner[1] + 4 * scale,
			inner[2] - 6 * scale, inner[3] - 7 * scale], radius - 6 * scale, fill=color)
		for corner in damage["chips"]:
			_draw_chip(draw, detail, box, corner, scale)
		if damage["split"]:
			_draw_split(draw, detail, inner, scale)
		for _crack in range(damage["cracks"]):
			_draw_crack(draw, detail, inner, scale)
		if damage["moss"]:
			_draw_moss(draw, detail, box, scale)


def _draw_missing_slab(draw: ImageDraw.ImageDraw, prng: random.Random, box: list[float],
		radius: float, scale: int) -> None:
	"""A slab that has broken away: bare dirt, a few loose pebbles and some moss."""
	draw.rounded_rectangle(box, radius, fill=STONE_DIRT)
	for _pebble in range(prng.randint(3, 6)):
		x = prng.uniform(box[0] + 16 * scale, box[2] - 16 * scale)
		y = prng.uniform(box[1] + 12 * scale, box[3] - 12 * scale)
		r = prng.uniform(14, 26) * scale
		draw.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=(104, 98, 92),
			outline=OUTLINE[:3], width=2 * scale)
	_draw_moss(draw, prng, box, scale)


def _draw_chip(draw: ImageDraw.ImageDraw, prng: random.Random, box: list[float], corner: int,
		scale: int) -> None:
	"""Knock a jagged piece out of one corner, exposing the dark joint underneath."""
	x = box[0] if corner in (0, 3) else box[2]
	y = box[1] if corner in (0, 1) else box[3]
	sx = 1 if corner in (0, 3) else -1
	sy = 1 if corner in (0, 1) else -1
	reach_x = prng.uniform(50, 95) * scale
	reach_y = prng.uniform(40, 80) * scale
	jag = [(x + sx * reach_x, y - sy * 4 * scale)]
	for step in range(1, 4):
		t = step / 4
		jag.append((x + sx * reach_x * (1 - t) + sx * prng.uniform(-6, 10) * scale,
			y + sy * reach_y * t + sy * prng.uniform(-6, 10) * scale))
	jag.append((x - sx * 4 * scale, y + sy * reach_y))
	draw.polygon([(x - sx * 4 * scale, y - sy * 4 * scale)] + jag, fill=STONE_MORTAR)
	draw.line(jag, fill=OUTLINE[:3], width=3 * scale, joint="curve")


def _draw_crack(draw: ImageDraw.ImageDraw, prng: random.Random, box: list[float],
		scale: int) -> None:
	x = prng.uniform(box[0] + 20 * scale, box[2] - 20 * scale)
	y = box[1] + 6 * scale
	points = [(x, y)]
	for _step in range(prng.randint(3, 6)):
		x += prng.uniform(-18, 18) * scale
		y += prng.uniform(12, 26) * scale
		if y > box[3] - 8 * scale:
			break
		x = min(max(x, box[0] + 8 * scale), box[2] - 8 * scale)
		points.append((x, y))
	if len(points) > 1:
		draw.line(points, fill=OUTLINE[:3], width=3 * scale, joint="curve")
		# A short side branch makes the crack read as brittle stone rather than a scratch.
		bx, by = points[len(points) // 2]
		draw.line([(bx, by), (bx + prng.uniform(-24, 24) * scale, by + prng.uniform(8, 18) * scale)],
			fill=OUTLINE[:3], width=2 * scale)


def _draw_split(draw: ImageDraw.ImageDraw, prng: random.Random, box: list[float],
		scale: int) -> None:
	"""A break running right through the slab, with a sunken dark gap."""
	x = prng.uniform(box[0] + 0.3 * (box[2] - box[0]), box[0] + 0.7 * (box[2] - box[0]))
	points = [(x, box[1])]
	steps = 4
	for step in range(1, steps + 1):
		x += prng.uniform(-14, 14) * scale
		x = min(max(x, box[0] + 10 * scale), box[2] - 10 * scale)
		points.append((x, box[1] + (box[3] - box[1]) * step / steps))
	draw.line(points, fill=STONE_MORTAR, width=9 * scale, joint="curve")
	draw.line(points, fill=OUTLINE[:3], width=4 * scale, joint="curve")


def _draw_moss(draw: ImageDraw.ImageDraw, prng: random.Random, box: list[float],
		scale: int) -> None:
	corner_x = box[0] if prng.random() < 0.5 else box[2]
	corner_y = box[3]
	for _blob in range(prng.randint(3, 6)):
		x = corner_x + prng.uniform(-22, 22) * scale
		y = corner_y + prng.uniform(-16, 4) * scale
		r = prng.uniform(5, 11) * scale
		draw.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=STONE_MOSS)


# --------------------------------------------------------------------------- entry point


def main() -> None:
	rng = np.random.default_rng(SEED)
	prng = random.Random(SEED)
	GROUND_DIR.mkdir(parents=True, exist_ok=True)
	make_grass_ground(rng, prng).save(GROUND_DIR / "hub_grass_ground.png", optimize=True)
	make_stone_ground(rng, prng).save(GROUND_DIR / "hub_stone_ground.png", optimize=True)
	print("Wrote", GROUND_DIR)


if __name__ == "__main__":
	main()
