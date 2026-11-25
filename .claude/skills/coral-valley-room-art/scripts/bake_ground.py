"""Bakes a Coral Valley room's sand ground and its shore distance field from a layout JSON.

Usage (from the project root):
    python .claude/skills/coral-valley-room-art/scripts/bake_ground.py <layout.json>

The ground keeps the alpha (silhouette) of `source`, so the shared floor collision still matches.
Everything is placed in world metres (x right, z toward the camera). `ground_rect` is the world
rect of the ground sprite; get it with scripts/godot/probe_room.gd. See layouts/room_00.json.

Optional keys: "ground_style" (one of STYLES, default "ripple"), "wrack_line" (bool),
"slab_count" (rock_shelf), "fallen_fronds", "coconuts", "ripple_angle_degrees",
"painted_water" ({"shallow", "pool", "pool_light", "glint"} RGB lists: water drawn on the sand
for rooms whose sea has a wonder palette).

Split ground (wonder rooms): "islands" is a list of convex polygons in world metres; their union
replaces the silhouette of `source`, so the pieces are separated by real water. "channels" is a
list of [[x1, z1], [x2, z2], half_width] strips of shallow water painted across land where two
pieces overlap. "canvas_size" (pixels) bakes on a blank square canvas instead of `source`,
for rooms whose ground is larger than the shared art. "out_islands" names a JSON file that receives the smoothed outline of every
island, which the room's floor collision must use (one ConvexPolygonShape3D per island).
"""

import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

# Palette (docs/art/coral_valley_art_direction.md, section "Bảng màu").
SAND_LIGHT = (244, 216, 190)
SAND_MID = (233, 194, 168)
SAND_DARK = (218, 174, 152)
SAND_WET = (160, 128, 128)
SALT = (238, 226, 210)
TROD = (206, 164, 144)
TROD_EDGE = (176, 132, 120)
SCORCH = (150, 104, 96)
INK = (54, 34, 38)
SPECKLES = [(250, 240, 228, 230), (244, 186, 186, 230), (236, 140, 112, 220), (210, 200, 230, 200)]
SHALLOW_WATER = (88, 152, 150)
POOL_DEEP = (58, 140, 142)
POOL_LIGHT = (92, 178, 172)
POOL_GLINT = (214, 240, 232)
SLAB_LIGHT = (196, 164, 150)
SLAB_DARK = (158, 126, 118)
RUBBLE = [(246, 222, 212, 255), (240, 176, 172, 255), (232, 140, 112, 255), (252, 244, 232, 255)]
WRACK = [(92, 82, 52, 255), (118, 98, 60, 255), (74, 66, 46, 255)]

# Ground styles (AD section 3, "Kiểu nền"). Every style keeps the palette, the inked edge, the
# wet rim and the path; it only changes tone, surface marks and one detail layer. "ripple" is the
# original look and must stay byte-identical, so its values are the historical defaults.
STYLES = {
    # Soft dune tones and wind ripples in patches.
    "ripple": {"tone_shift": 0.0, "ripple_wavelength": 1.7, "ripple_coverage": 0.55,
               "ripple_strength": 1.0, "wet_width": 1.6},
    # Low tide: wide wet sand, dense parallel ripples, shallow puddles left behind.
    "tide_flats": {"tone_shift": -0.2, "ripple_wavelength": 0.9, "ripple_coverage": 0.3,
                   "ripple_strength": 1.5, "wet_width": 3.2},
    # Dry dunes: lighter sand, long dune bands along the wind, wind streaks, thin wet rim.
    "dunes": {"tone_shift": 0.42, "ripple_wavelength": 1.7, "ripple_coverage": 0.72,
              "ripple_strength": 0.6, "wet_width": 0.9},
    # Coral rubble: pinker sand strewn with broken coral and shell, denser toward the water.
    "coral_rubble": {"tone_shift": 0.0, "ripple_wavelength": 1.7, "ripple_coverage": 0.7,
                     "ripple_strength": 0.6, "wet_width": 1.4},
    # Rock shelf: flat sandstone slabs flush with the sand, barnacles, pools in the rock.
    "rock_shelf": {"tone_shift": -0.08, "ripple_wavelength": 1.7, "ripple_coverage": 0.65,
                   "ripple_strength": 0.7, "wet_width": 1.6},
}


def island_outline(points, iterations=2):
    """Chaikin-smoothed closed outline; stays convex when the input is convex."""
    pts = [tuple(map(float, p)) for p in points]
    for _ in range(iterations):
        out = []
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        pts = out
    return pts


def col(rgb):
    return np.array(rgb[:3], np.float32) / 255.0


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1.0 - t) + b * t


def bezier(ctrl, n=80):
    p0, p1, p2, p3 = (np.array(c, np.float32) for c in ctrl)
    t = np.linspace(0, 1, n)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3


def _island_alpha(cfg, islands, W, H):
    """Union of the island polygons, drawn at 2x with a gently wobbling shore."""
    gx0, gz0, gw, gd = cfg["ground_rect"]
    scale = 2
    canvas = Image.new("L", (W * scale, H * scale), 0)
    draw = ImageDraw.Draw(canvas)
    wobble_rng = np.random.default_rng(cfg.get("seed", 1207) + 913)
    for poly in islands:
        outline = island_outline(poly, 3)
        cx = sum(p[0] for p in outline) / len(outline)
        cz = sum(p[1] for p in outline) / len(outline)
        phase = wobble_rng.random(3) * math.tau
        pixels = []
        for i, (x, z) in enumerate(outline):
            t = i / len(outline) * math.tau
            # Small bumps along the shore so pieces read as hand-drawn islands, not polygons.
            bump = (0.18 * math.sin(t * 5 + phase[0]) + 0.12 * math.sin(t * 9 + phase[1])
                    + 0.08 * math.sin(t * 15 + phase[2]))
            dx, dz = x - cx, z - cz
            length = max(math.hypot(dx, dz), 0.001)
            x, z = x + dx / length * bump, z + dz / length * bump
            pixels.append(((x - gx0) / gw * W * scale, (z - gz0) / gd * H * scale))
        draw.polygon(pixels, fill=255)
    return np.asarray(canvas.resize((W, H), Image.LANCZOS), np.float32) / 255.0


def _paint_channels(channels, color, X, Z, noise, along_wind):
    """Shallow water across land: walkable, slower (ShallowWaterArea in the scene)."""
    if not channels:
        return color
    depth = np.zeros(X.shape, np.float32)
    ragged = noise(2.0, 37, 2) - 0.5
    for (x1, z1), (x2, z2), half in channels:
        ax, az = X - x1, Z - z1
        bx, bz = x2 - x1, z2 - z1
        t = np.clip((ax * bx + az * bz) / max(bx * bx + bz * bz, 1e-6), 0.0, 1.0)
        d = np.sqrt((ax - bx * t) ** 2 + (az - bz * t) ** 2)
        width = half + ragged * 0.6
        depth = np.maximum(depth, 1.0 - smoothstep(width - 0.35, width + 0.35, d))
    wet = smoothstep(0.0, 0.25, depth)
    water = smoothstep(0.35, 0.6, depth)
    color = mix(color, col(SAND_WET), wet * 0.8)
    rim = smoothstep(0.28, 0.36, depth) * (1.0 - water)
    color = mix(color, col(INK), rim * 0.35)
    shallow = mix(col(SHALLOW_WATER), col(SHALLOW_WATER) * 1.2, smoothstep(0.6, 1.0, depth))
    color = mix(color, shallow, water * 0.82)
    ripple = smoothstep(0.92, 0.99, np.sin(along_wind * 6.0 + ragged * 4.0)) * water
    return mix(color, col(SALT), ripple * 0.35)


def _style_surface(style_name, color, X, Z, along_wind, noise, shore_d, trod, mid):
    """Per-style marks painted into the sand before the path goes on top."""
    if style_name == "tide_flats":
        # Damp hollows left inland by the tide, with shallow puddles in the deepest ones.
        hollow = noise(5.0, 50, 2)
        free = (1.0 - trod) * smoothstep(1.0, 2.0, shore_d)
        damp = smoothstep(0.52, 0.62, hollow) * free
        color = mix(color, col(SAND_WET), damp * 0.45)
        puddle = smoothstep(0.69, 0.72, hollow) * free
        rim = smoothstep(0.66, 0.69, hollow) * (1.0 - puddle) * free
        color = mix(color, col(INK), rim * 0.3)
        water = mix(col(SHALLOW_WATER), col(SHALLOW_WATER) * 1.25, smoothstep(0.72, 0.8, hollow))
        color = mix(color, water, puddle * 0.85)
        glint = smoothstep(0.9, 0.98, np.sin(along_wind * 9.0 + mid * 6.0)) * puddle
        color = mix(color, col(SALT), glint * 0.5)
    elif style_name == "dunes":
        # Long dune bands across the wind, then thin streaks of blown sand along it.
        warp = noise(8.0, 60, 2) * 3.0
        band = np.sin(along_wind * (2 * math.pi / 6.0) + warp)
        free = 1.0 - trod
        color = mix(color, col(SAND_LIGHT) * 1.05, smoothstep(0.2, 0.85, band) * free * 0.55)
        color = mix(color, col(SAND_DARK) * 0.94, smoothstep(-0.4, -0.95, band) * free * 0.45)
        across = -X * math.sin(math.radians(62.0)) + Z * math.cos(math.radians(62.0))
        streak = smoothstep(0.9, 0.99, np.sin(across * (2 * math.pi / 0.6) + noise(1.5, 61) * 7))
        streak *= smoothstep(0.55, 0.7, noise(4.0, 62, 2)) * free * smoothstep(1.0, 2.0, shore_d)
        color = mix(color, col(SALT), streak * 0.6)
    elif style_name == "coral_rubble":
        # Crushed coral tints the sand pinker toward the water.
        pink = (1.0 - smoothstep(1.5, 9.0, shore_d)) * (1.0 - trod)
        color = mix(color, col((236, 188, 176)), pink * 0.25)
    return color


def _draw_slabs(cfg, draw, P, blob, ellipse, on_free_sand, gx0, gz0, gw, gd, half, segments):
    """Flat sandstone slabs flush with the sand, kept off the path and the shore."""
    rng = np.random.default_rng(cfg.get("seed", 1207) + 71)
    ink = INK + (255,)
    placed = []
    for attempt in range(400):
        if len(placed) >= cfg.get("slab_count", 9):
            break
        x, z = gx0 + rng.random() * gw, gz0 + rng.random() * gd
        rx, rz = rng.uniform(1.2, 2.6), rng.uniform(0.8, 1.7)
        if not all(on_free_sand(x + dx * rx, z + dz * rz, 1.3)
                   for dx, dz in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        if segments and min(np.hypot(*(np.concatenate(segments) - [x, z]).T)) < half + max(rx, rz):
            continue
        if any(math.hypot(x - px, z - pz) < max(rx, rz) + pr + 0.6 for px, pz, pr in placed):
            continue
        if any(math.hypot(x - px, z - pz) < max(rx, rz) + max(prx, prz) + 0.8
               for px, pz, prx, prz in cfg.get("tide_pools", [])):
            continue
        placed.append((x, z, max(rx, rz)))
        seed = 900 + attempt
        draw.polygon(blob(x + 0.12, z + 0.12, rx, rz, seed, jitter=0.16), fill=(120, 84, 84, 120))
        draw.polygon(blob(x, z, rx, rz, seed, jitter=0.16), fill=SLAB_DARK + (255,), outline=ink,
                     width=4)
        draw.polygon(blob(x - rx * 0.08, z - rz * 0.1, rx * 0.86, rz * 0.8, seed, jitter=0.16),
                     fill=SLAB_LIGHT + (255,))
        # A crack or two, and barnacles along the rim.
        for _ in range(rng.integers(1, 3)):
            a = rng.uniform(0, math.pi)
            p0 = (x + math.cos(a) * rx * 0.6, z + math.sin(a) * rz * 0.6)
            p1 = (x - math.cos(a) * rx * 0.2, z - math.sin(a) * rz * 0.2 + rng.normal(0, 0.1))
            draw.line([P(*p0), P(*p1)], fill=(110, 84, 82, 255), width=3)
        for _ in range(rng.integers(4, 9)):
            a = rng.uniform(0, 2 * math.pi)
            ellipse(x + math.cos(a) * rx * 0.85, z + math.sin(a) * rz * 0.85, 0.07, 0.06,
                    (224, 214, 204, 255))
        # Some slabs hold a rock pool.
        if rng.random() < 0.4:
            draw.polygon(blob(x, z, rx * 0.38, rz * 0.34, seed + 3), fill=POOL_DEEP + (255,),
                         outline=ink, width=3)


def _draw_rubble(draw, P, ellipse, on_free_sand, shore_d, gx0, gz0, gw, gd, px_x, px_z, W, H):
    """Broken coral twigs and shell bits, denser toward the water."""
    rng = np.random.default_rng(510)
    ink = INK + (255,)
    for _ in range(2000):
        x, z = gx0 + rng.random() * gw, gz0 + rng.random() * gd
        if not on_free_sand(x, z, 0.5):
            continue
        iu, iv = min(int((x - gx0) * px_x), W - 1), min(int((z - gz0) * px_z), H - 1)
        if rng.random() > 0.15 + 0.85 * math.exp(-shore_d[iv, iu] / 4.0):
            continue
        colour = RUBBLE[rng.integers(0, len(RUBBLE))]
        if rng.random() < 0.6:
            # A coral twig: two or three short joined segments.
            pts = [(x, z)]
            a = rng.uniform(0, 2 * math.pi)
            for _ in range(rng.integers(2, 4)):
                a += rng.normal(0, 0.7)
                step = rng.uniform(0.14, 0.26)
                pts.append((pts[-1][0] + math.cos(a) * step, pts[-1][1] + math.sin(a) * step))
            line = [P(*p) for p in pts]
            draw.line(line, fill=ink, width=14, joint="curve")
            draw.line(line, fill=colour, width=8, joint="curve")
        else:
            s = rng.uniform(0.08, 0.14)
            ellipse(x, z, s * 1.2 + 0.025, s + 0.025, ink)
            ellipse(x, z, s * 1.2, s, colour)


def _draw_wrack(draw, P, ellipse, on_free_sand, shore_d, wet_width, gx0, gz0, gw, gd, px_x, px_z,
                W, H):
    """Dried seaweed, shell bits and sticks along the high-tide line, just above the wet sand."""
    rng = np.random.default_rng(620)
    line_at = wet_width + 0.9
    clump_grid = (np.random.default_rng(621).random((int(gd / 2.5) + 3, int(gw / 2.5) + 3)) * 255)
    clumps = np.asarray(Image.fromarray(clump_grid.astype(np.uint8), "L").resize((W, H),
                        Image.BICUBIC), np.float32) / 255
    for _ in range(9000):
        x, z = gx0 + rng.random() * gw, gz0 + rng.random() * gd
        iu, iv = min(int((x - gx0) * px_x), W - 1), min(int((z - gz0) * px_z), H - 1)
        if abs(shore_d[iv, iu] - line_at) > 0.35 or not on_free_sand(x, z, 0.5):
            continue
        # The wrack line is broken: dense clumps with bare gaps between them.
        if clumps[iv, iu] < 0.42 or rng.random() > 0.65:
            continue
        kind = rng.random()
        if kind < 0.7:
            a = rng.uniform(0, 2 * math.pi)
            pts = [(x, z)]
            for _ in range(4):
                a += rng.normal(0, 0.6)
                pts.append((pts[-1][0] + math.cos(a) * 0.2, pts[-1][1] + math.sin(a) * 0.2))
            line = [P(*p) for p in pts]
            draw.line(line, fill=INK + (255,), width=13, joint="curve")
            draw.line(line, fill=WRACK[rng.integers(0, len(WRACK))], width=8, joint="curve")
        elif kind < 0.9:
            ellipse(x, z, 0.12, 0.1, INK + (255,))
            ellipse(x, z, 0.1, 0.08, RUBBLE[rng.integers(0, len(RUBBLE))])
        else:
            a = rng.uniform(0, math.pi)
            p0 = (x - math.cos(a) * 0.25, z - math.sin(a) * 0.25)
            p1 = (x + math.cos(a) * 0.25, z + math.sin(a) * 0.25)
            draw.line([P(*p0), P(*p1)], fill=INK + (255,), width=8)
            draw.line([P(*p0), P(*p1)], fill=(176, 140, 104, 255), width=4)


def _apply_water_palette(cfg):
    """Wonder rooms with a coloured sea repaint the water drawn on the sand to match it."""
    global SHALLOW_WATER, POOL_DEEP, POOL_LIGHT, POOL_GLINT
    water = cfg.get("painted_water")
    if not water:
        return
    SHALLOW_WATER = tuple(water["shallow"])
    POOL_DEEP = tuple(water["pool"])
    POOL_LIGHT = tuple(water["pool_light"])
    POOL_GLINT = tuple(water["glint"])


def main(layout_path: str) -> None:
    cfg = json.load(open(layout_path, encoding="utf8"))
    _apply_water_palette(cfg)
    gx0, gz0, gw, gd = cfg["ground_rect"]
    islands = cfg.get("islands")
    if islands and cfg.get("canvas_size"):
        # Islands replace the silhouette, so a larger room can bake on a bigger, blank canvas.
        src = Image.new("RGBA", (cfg["canvas_size"], cfg["canvas_size"]), (0, 0, 0, 0))
    else:
        src = Image.open(cfg["source"]).convert("RGBA")
    W, H = src.size
    alpha = np.asarray(src)[:, :, 3].astype(np.float32) / 255.0
    if islands:
        alpha = _island_alpha(cfg, islands, W, H)
    inside = alpha > 0.5
    rng = np.random.default_rng(cfg.get("seed", 1207))
    # Shifts every noise field by the room's seed, so rooms do not share the same sand patches,
    # dunes and puddles. room_00 (seed 1207) keeps an offset of 0 and stays byte-identical.
    noise_offset = cfg.get("seed", 1207) - 1207
    px_x, px_z = W / gw, H / gd
    X = (gx0 + (np.arange(W, dtype=np.float32) + 0.5) / W * gw)[None, :].repeat(H, 0)
    Z = (gz0 + (np.arange(H, dtype=np.float32) + 0.5) / H * gd)[:, None].repeat(W, 1)

    def noise(scale_m, seed, octaves=1):
        total = np.zeros((H, W), np.float32)
        amp, norm, scale = 1.0, 0.0, scale_m
        local = np.random.default_rng(seed + noise_offset)
        for _ in range(octaves):
            grid = (local.random((int(gd / scale) + 3, int(gw / scale) + 3)) * 255).astype(np.uint8)
            img = Image.fromarray(grid, "L").resize((W, H), Image.BICUBIC)
            total += np.asarray(img, np.float32) / 255.0 * amp
            norm += amp
            amp *= 0.5
            scale *= 0.5
        return np.clip(total / norm, 0.0, 1.0)

    def dist_to(points, qx, qz, chunk=4096):
        q = np.stack([qx.ravel(), qz.ravel()], 1)
        out = np.empty(len(q), np.float32)
        for i in range(0, len(q), chunk):
            d = q[i:i + chunk, None, :] - points[None, :, :]
            out[i:i + chunk] = np.sqrt((d * d).sum(-1)).min(1)
        return out.reshape(qx.shape)

    def upsample(small):
        return np.asarray(Image.fromarray(small).resize((W, H), Image.BILINEAR), np.float32)

    # Distance to the shore, from the silhouette's edge pixels.
    edge = inside & ~(np.roll(inside, 1, 0) & np.roll(inside, -1, 0)
                      & np.roll(inside, 1, 1) & np.roll(inside, -1, 1))
    ey, ex = np.nonzero(edge)
    shore_pts = np.stack([gx0 + (ex + 0.5) / W * gw, gz0 + (ey + 0.5) / H * gd], 1)[::3]
    shore_d = upsample(dist_to(shore_pts, X[::4, ::4], Z[::4, ::4]))

    # Path (one cubic Bézier per segment, between doors) and the optional plaza.
    segments = [bezier(s) for s in cfg.get("paths", [])]
    wobble = noise(2.5, 11, 2) - 0.5
    trod = np.zeros((H, W), np.float32)
    trod_edge = np.zeros((H, W), np.float32)
    half = cfg.get("path_half_width", 1.75)
    if segments:
        path_d = upsample(dist_to(np.concatenate(segments), X[::2, ::2], Z[::2, ::2]))
        path_half = half + wobble * 0.7
        path_m = 1.0 - smoothstep(path_half - 0.2, path_half + 0.2, path_d)
        trod = path_m
        trod_edge = smoothstep(path_half - 0.55, path_half - 0.1, path_d) * path_m
    plaza = cfg.get("plaza")
    plaza_d = None
    if plaza:
        cx, cz = plaza["center"]
        radius = plaza["radius"]
        plaza_d = np.sqrt((X - cx) ** 2 + (Z - cz) ** 2)
        plaza_m = 1.0 - smoothstep(radius - 0.25 + wobble * 0.6, radius + 0.25 + wobble * 0.6,
                                   plaza_d)
        plaza_edge = smoothstep(radius - 0.6, radius - 0.1, plaza_d + wobble * 0.6) * plaza_m
        trod_edge = np.maximum(trod_edge * (1.0 - plaza_m), plaza_edge * (1.0 - trod))
        trod_edge = np.where(plaza_d < radius - 0.7, 0.0, trod_edge)
        trod = np.maximum(trod, plaza_m)

    # Sand: painted dune tones, wind ripples, trodden ground, wet rim, ink edge.
    style_name = cfg.get("ground_style", "ripple")
    style = STYLES[style_name]
    low = noise(9.0, 1, 3)
    mid = noise(3.0, 2, 2)
    tone = smoothstep(0.36, 0.5, low) * 0.5 + smoothstep(0.56, 0.7, low) * 0.5
    color = mix(mix(col(SAND_DARK), col(SAND_MID), smoothstep(0.0, 0.5, tone)), col(SAND_LIGHT),
                smoothstep(0.5, 1.0, tone))
    if style["tone_shift"] > 0:
        color = mix(color, col(SAND_LIGHT), style["tone_shift"])
    elif style["tone_shift"] < 0:
        color = mix(color, col(SAND_DARK), -style["tone_shift"])
    angle = math.radians(cfg.get("ripple_angle_degrees", 62.0))
    along_wind = X * math.cos(angle) + Z * math.sin(angle)
    phase = along_wind * (2 * math.pi / style["ripple_wavelength"]) + noise(4.0, 3, 2) * 14
    coverage = style["ripple_coverage"]
    patch = smoothstep(coverage, coverage + 0.15, noise(7.0, 4, 2)) * (1.0 - trod) \
        * smoothstep(1.8, 3.0, shore_d)
    strength = style["ripple_strength"]
    color = mix(color, col(SAND_LIGHT) * 1.04,
                np.minimum(smoothstep(0.86, 0.98, np.sin(phase)) * patch * 0.4 * strength, 0.9))
    color = mix(color, col(SAND_DARK) * 0.96,
                np.minimum(smoothstep(0.5, 0.95, np.sin(phase - 0.9)) * patch * 0.3 * strength, 0.9))
    color = _style_surface(style_name, color, X, Z, along_wind, noise, shore_d, trod, mid)
    color = mix(color, col(TROD) * (0.96 + mid[..., None] * 0.08), trod * 0.92)
    color = mix(color, col(TROD_EDGE), trod_edge * 0.55)
    if plaza and plaza.get("scorch", True):
        scorch = 1.0 - smoothstep(1.4, 2.9, plaza_d + (mid - 0.5) * 0.9)
        color = mix(color, col(SCORCH), scorch * 0.55)
    wet_edge = style["wet_width"] + (mid - 0.5)
    color = mix(color, col(SAND_WET), (1.0 - smoothstep(wet_edge - 0.5, wet_edge, shore_d)) * 0.75)
    color = mix(color, col(SALT), smoothstep(0.18, 0.0, np.abs(shore_d - wet_edge - 0.08)) * 0.6)
    # After the wet rim, so a channel that reaches the coast stays water all the way to the sea.
    color = _paint_channels(cfg.get("channels", []), color, X, Z, noise, along_wind)
    color *= 1.0 + (rng.random((H, W)).astype(np.float32)[..., None] - 0.5) * 0.045
    outline = 1.0 - smoothstep(0.08, 0.16, shore_d)
    color = mix(color, col(INK), outline)
    color = mix(color, color * 0.8, (1.0 - smoothstep(0.16, 0.5, shore_d)) * (1 - outline))
    img = Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")

    # Flat details at 2x, then downsampled. Only things that lie on the ground (rule 5).
    ss = 2
    layer = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    ink = INK + (255,)

    def P(x, z):
        return ((x - gx0) * px_x * ss, (z - gz0) * px_z * ss)

    def ellipse(x, z, rx, rz, fill):
        cx, cz = P(x, z)
        draw.ellipse([cx - rx * px_x * ss, cz - rz * px_z * ss, cx + rx * px_x * ss,
                      cz + rz * px_z * ss], fill=fill)

    def blob(x, z, rx, rz, seed, n=28, jitter=0.12):
        offs = np.random.default_rng(seed).normal(0, jitter, n)
        offs = np.convolve(np.concatenate([offs[-2:], offs, offs[:2]]), np.ones(5) / 5, "valid")
        return [P(x + math.cos(a) * rx * (1 + o), z + math.sin(a) * rz * (1 + o))
                for a, o in zip(np.linspace(0, 2 * math.pi, n, endpoint=False), offs)]

    def on_free_sand(x, z, margin):
        """True if (x, z) is sand at least `margin` m from the shore and off the path."""
        iu, iv = int((x - gx0) * px_x), int((z - gz0) * px_z)
        if not (0 <= iu < W and 0 <= iv < H) or not inside[iv, iu]:
            return False
        return shore_d[iv, iu] > margin and trod[iv, iu] < 0.05

    if style_name == "rock_shelf":
        _draw_slabs(cfg, draw, P, blob, ellipse, on_free_sand, gx0, gz0, gw, gd, half, segments)

    for i, (x, z, rx, rz) in enumerate(cfg.get("tide_pools", [])):
        seed = 5 + i
        draw.polygon(blob(x, z, rx * 1.35, rz * 1.4, seed), fill=(168, 134, 132, 150))
        draw.polygon(blob(x, z, rx, rz, seed), fill=POOL_DEEP + (255,), outline=ink, width=4)
        draw.polygon(blob(x - rx * 0.1, z - rz * 0.08, rx * 0.72, rz * 0.62, seed + 50),
                     fill=POOL_LIGHT + (255,))
        hx, hz = P(x - rx * 0.35, z - rz * 0.35)
        draw.arc([hx - rx * px_x * 0.6, hz - rz * px_z * 0.35, hx + rx * px_x * 0.6,
                  hz + rz * px_z * 0.35], 200, 320, fill=POOL_GLINT + (255,), width=5)

    for x, z, r, rot, rgb in cfg.get("starfish", []):
        pts = []
        for i in range(10):
            a = rot + i * math.pi / 5
            rr = r if i % 2 == 0 else r * 0.45
            pts.append(P(x + math.cos(a) * rr, z + math.sin(a) * rr * 0.85))
        draw.polygon(pts, fill=tuple(rgb) + (255,), outline=ink, width=4)
        for i in range(5):
            a = rot + i * 2 * math.pi / 5
            for k in (0.35, 0.6):
                ellipse(x + math.cos(a) * r * k, z + math.sin(a) * r * k * 0.85, 0.035, 0.035,
                        (250, 214, 180, 255))

    # Palm grove litter: fallen fronds and coconuts lying flat on the sand. Only things that sit
    # almost flat (under ~0.2 m) belong here; anything taller is a 3D prop (rule 4).
    for i, (x, z, length, angle_deg) in enumerate(cfg.get("fallen_fronds", [])):
        frond_rng = np.random.default_rng(400 + i)
        heading = math.radians(angle_deg)
        forward = np.array([math.cos(heading), math.sin(heading)])
        side = np.array([-forward[1], forward[0]])
        bend = frond_rng.uniform(-0.25, 0.25) * length
        dried = frond_rng.random()
        leaf = tuple(int(a + (b - a) * dried) for a, b in ((118, 196), (128, 164), (62, 104))) + (255,)
        vein = (96, 78, 52, 255)
        spine = []
        steps = 14
        for s in range(steps + 1):
            t = s / steps
            spine.append(np.array([x, z]) + forward * t * length + side * bend * t * t)
        for s in range(1, steps):
            t = s / steps
            p = spine[s]
            along = spine[s + 1] - spine[s - 1]
            along /= np.linalg.norm(along) + 1e-6
            across = np.array([-along[1], along[0]])
            reach = length * 0.32 * math.sin(math.pi * min(1.0, t * 1.15))
            for flip in (-1, 1):
                tip = p + (across * flip * 0.82 - along * 0.55) * reach
                base_a = p - along * 0.06
                base_b = p + along * 0.06
                draw.polygon([P(*base_a), P(*tip), P(*base_b)], fill=leaf, outline=ink)
        line = [P(*q) for q in spine]
        draw.line(line, fill=ink, width=9, joint="curve")
        draw.line(line, fill=vein, width=4, joint="curve")

    for x, z in cfg.get("coconuts", []):
        ellipse(x + 0.07, z + 0.06, 0.2, 0.15, (110, 70, 64, 110))
        cx, cz = P(x, z)
        rx, rz = 0.17 * px_x * ss, 0.15 * px_z * ss
        draw.ellipse([cx - rx, cz - rz, cx + rx, cz + rz], fill=(122, 78, 46, 255), outline=ink,
                     width=4)
        ellipse(x - 0.05, z - 0.05, 0.05, 0.035, (196, 150, 104, 255))

    if style_name == "coral_rubble":
        _draw_rubble(draw, P, ellipse, on_free_sand, shore_d, gx0, gz0, gw, gd, px_x, px_z, W, H)
    if cfg.get("wrack_line", False):
        _draw_wrack(draw, P, ellipse, on_free_sand, shore_d, style["wet_width"], gx0, gz0, gw, gd,
                    px_x, px_z, W, H)

    detail_rng = np.random.default_rng(21)
    if plaza and plaza.get("stone_ring", True):
        gaps = plaza.get("ring_gaps_degrees", [])
        for a in np.linspace(0, 2 * math.pi, 26, endpoint=False):
            deg = math.degrees(a) % 360
            if any((lo <= deg <= hi) if lo <= hi else (deg >= lo or deg <= hi) for lo, hi in gaps):
                continue
            r = plaza["radius"] + 0.35 + detail_rng.normal(0, 0.12)
            x, z = plaza["center"][0] + math.cos(a) * r, plaza["center"][1] + math.sin(a) * r
            size = 0.26 + detail_rng.random() * 0.14
            fill = [(236, 222, 206, 255), (224, 196, 190, 255), (214, 206, 198, 255)][
                detail_rng.integers(0, 3)]
            ellipse(x + 0.05, z + 0.06, size * 1.1, size * 0.8, (120, 84, 84, 110))
            draw.polygon(blob(x, z, size * 1.1, size * 0.75, int(a * 100)), fill=fill,
                         outline=ink, width=3)

    paw = (180, 132, 118, 170)
    for seg in segments:
        for i in range(3, len(seg) - 3, 5):
            p, q = seg[i], seg[i + 1]
            n = np.array([-(q - p)[1], (q - p)[0]]) / (np.linalg.norm(q - p) + 1e-6)
            side = 1 if detail_rng.random() < 0.5 else -1
            c = p + n * side * (half + 0.2 + detail_rng.random() * 0.4)
            s = 0.1 + detail_rng.random() * 0.1
            draw.polygon(blob(c[0], c[1], s * 1.2, s, int(i * 7 + side)),
                         fill=(196, 176, 172, 255), outline=ink, width=2)
        if cfg.get("paw_prints", True):
            for i in range(4, len(seg) - 4, 4):
                p, q = seg[i], seg[i + 2]
                t = (q - p) / (np.linalg.norm(q - p) + 1e-6)
                n = np.array([-t[1], t[0]])
                c = p + n * (0.22 if (i // 4) % 2 else -0.22)
                ellipse(c[0], c[1], 0.09, 0.08, paw)
                for k in (-1, 0, 1):
                    toe = c + t * 0.14 + n * k * 0.075
                    ellipse(toe[0], toe[1], 0.035, 0.035, paw)

    speck_rng = np.random.default_rng(33)
    for _ in range(cfg.get("speckle_count", 2600)):
        x, z = gx0 + speck_rng.random() * gw, gz0 + speck_rng.random() * gd
        iu, iv = min(int((x - gx0) * px_x), W - 1), min(int((z - gz0) * px_z), H - 1)
        d = shore_d[iv, iu]
        if not inside[iv, iu] or d < 0.3:
            continue
        keep = (0.25 + 0.75 * math.exp(-d / 4.0)) * (0.25 if trod[iv, iu] > 0.5 else 1.0)
        if speck_rng.random() > keep:
            continue
        s = 0.03 + speck_rng.random() * 0.05
        ellipse(x, z, s * 1.3, s, SPECKLES[speck_rng.integers(0, len(SPECKLES))])

    img = Image.alpha_composite(img, layer.resize((W, H), Image.LANCZOS))
    arr = np.asarray(img).copy()
    arr[:, :, 3] = (alpha * 255).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(cfg["out_ground"], optimize=True)

    # Shore distance field for coral_lagoon.gdshader: 0 at the sand edge, 1 at `margin` metres.
    margin, size = cfg.get("shore_margin_meters", 8.0), cfg.get("shore_size", 512)
    sx0, sz0, sw, sd = gx0 - margin, gz0 - margin, gw + margin * 2, gd + margin * 2
    su = (np.arange(size, dtype=np.float32) + 0.5) / size
    field = dist_to(shore_pts, (sx0 + su * sw)[None, :].repeat(size, 0),
                    (sz0 + su * sd)[:, None].repeat(size, 1))
    small = np.asarray(Image.fromarray((inside * 255).astype(np.uint8)).resize(
        (int(gw / sw * size), int(gd / sd * size)), Image.BILINEAR), np.float32) / 255.0
    island = np.zeros((size, size), np.float32)
    ox, oz = int(round(margin / sw * size)), int(round(margin / sd * size))
    island[oz:oz + small.shape[0], ox:ox + small.shape[1]] = small
    field = np.clip(np.where(island > 0.5, 0.0, field) / margin, 0.0, 1.0)
    Image.fromarray((field * 255).astype(np.uint8), "L").save(cfg["out_shore"], optimize=True)

    if islands and cfg.get("out_islands"):
        outlines = [[[round(x, 3), round(z, 3)] for x, z in island_outline(poly)] for poly in islands]
        json.dump(outlines, open(cfg["out_islands"], "w", encoding="utf-8"), indent=1)
        print("wrote", cfg["out_islands"])
    print("wrote", cfg["out_ground"], "and", cfg["out_shore"])
    print("shore_rect for the lagoon material: Vector4(%g, %g, %g, %g)" % (sx0, sz0, sw, sd))


if __name__ == "__main__":
    main(sys.argv[1])
